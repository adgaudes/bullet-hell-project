extends SceneTree
## Test del campo di percorso a finestra e della comparsa ad anello (D-039).
## Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/path_field_tests.gd
##
## Arena sintetica 240x240 m (half_extent 120) con un muro statico e un
## bersaglio mosso a mano; nessuna scena di gioco.

const PlayerScene := preload("res://scenes/player/player.tscn")

const HALF_EXTENT := 120.0
const WINDOW := 32

var _failures := 0
var _world: Node3D
var _target: Node3D
var _field: PathField


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_world = Node3D.new()
	root.add_child(_world)
	_target = Node3D.new()
	_target.name = "Target"
	_world.add_child(_target)
	_target.position = Vector3(0.0, 0.0, 0.0)
	# Muro statico lungo 12 m a est del centro, sul layer world_static.
	_add_wall(Vector3(6.0, 0.5, 0.0), Vector3(0.6, 1.0, 12.0))
	# Muro lontano, nella zona nord-ovest, fuori dalla finestra iniziale.
	_add_wall(Vector3(-80.0, 0.5, -80.0), Vector3(12.0, 1.0, 0.6))
	_field = PathField.new()
	_field.name = "PathField"
	_field.target = _target
	_field.half_extent = HALF_EXTENT
	_field.window_cells = WINDOW
	_field.recenter_margin_cells = 4
	_field.min_solve_interval = 0.0
	_world.add_child(_field)
	await _frames(4)
	_test_window_geometry()
	_test_static_wall_in_window()
	await _test_recenter_follows_target()
	await _test_recenter_solves_at_once()
	_test_chunk_cache()
	await _test_far_wall_after_recenter()
	_test_walkable_outside_window()
	await _test_full_field_mode_unchanged()
	await _test_spawn_ring_and_leash()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _add_wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_world.add_child(body)
	body.position = center


func _test_window_geometry() -> void:
	print("geometry")
	_check(_field.is_ready(), "campo pronto")
	_check(_field.world_columns == 200, "arena di 200 celle per lato (%d)" % _field.world_columns)
	_check(_field.columns == WINDOW, "finestra di %d celle (%d)" % [WINDOW, _field.columns])
	_check(_field.costs.size() == WINDOW * WINDOW, "costi solo per la finestra")
	var cell := _field.cell_of(_target.global_position)
	_check(cell == Vector2i(WINDOW / 2, WINDOW / 2), "bersaglio al centro della finestra %s" % cell)
	_check(_field.cost_at(_target.global_position) == 0.0, "costo zero sul bersaglio")
	var back := _field.cell_center(cell)
	_check(_field.cell_of(back) == cell, "cell_center e cell_of coerenti")
	var far := Vector3(100.0, 0.0, 100.0)
	_check(not _field.is_inside(_field.cell_of(far)), "un punto lontano e fuori finestra")
	_check(_field.cost_at(far) == PathField.UNREACHABLE, "fuori finestra: irraggiungibile")
	_check(_field.next_waypoint(far) == null, "fuori finestra: nessun waypoint (si punta dritto)")


func _test_static_wall_in_window() -> void:
	print("static wall")
	_check(not _field.is_walkable(Vector3(6.0, 0.0, 0.0)), "il muro a est blocca")
	_check(_field.is_walkable(Vector3(6.0, 0.0, 8.0)), "oltre il muro si passa")
	# Da dietro il muro il waypoint non attraversa il muro.
	var behind := Vector3(8.0, 0.0, 0.0)
	var wp: Variant = _field.next_waypoint(behind)
	_check(wp != null, "da dietro il muro c'e un waypoint")
	if wp != null:
		_check(absf(wp.z) > 0.5 or wp.x > behind.x, "il waypoint aggira il muro: %s" % wp)
	var cost_behind := _field.cost_at(behind)
	var cost_open := _field.cost_at(Vector3(0.0, 0.0, 8.0))
	_check(cost_behind > cost_open, "aggirare costa piu di andare dritto (%0.1f > %0.1f)" % [cost_behind, cost_open])


func _test_recenter_follows_target() -> void:
	print("recenter")
	var before := _field.origin
	_target.global_position = Vector3(30.0, 0.0, 0.0)
	await _frames(3)
	_check(_field.recenter_count >= 1, "la finestra si e ricentrata (%d)" % _field.recenter_count)
	_check(_field.origin != before, "origine cambiata %s -> %s" % [before, _field.origin])
	var cell := _field.cell_of(_target.global_position)
	_check(_field.is_inside(cell), "il bersaglio e dentro la nuova finestra")
	_check(_field.cost_at(_target.global_position) == 0.0, "costo zero sul bersaglio dopo il ricentro")
	_check(_field.is_walkable(Vector3(6.0, 0.0, 8.0)), "il vecchio muro: cella libera accanto ancora libera")
	# Piccolo spostamento: nessun ricentro.
	var count := _field.recenter_count
	_target.global_position += Vector3(1.0, 0.0, 0.0)
	await _frames(3)
	_check(_field.recenter_count == count, "spostamento piccolo: nessun ricentro")
	# Bordo dell'arena: la finestra resta dentro.
	_target.global_position = Vector3(HALF_EXTENT - 1.0, 0.0, HALF_EXTENT - 1.0)
	await _frames(3)
	var limit := _field.world_columns - _field.columns
	_check(_field.origin == Vector2i(limit, limit), "al bordo la finestra si ferma sull'angolo %s" % _field.origin)
	_check(_field.cost_at(_target.global_position) == 0.0, "bersaglio nell'angolo: costo zero")


## R-25: con l'intervallo minimo di gioco (0,15 s) il ricentro non deve lasciare i costi
## della vecchia finestra sotto le coordinate nuove nemmeno per un passo fisico.
func _test_recenter_solves_at_once() -> void:
	print("recenter solves at once")
	_field.min_solve_interval = 0.15
	_target.global_position = Vector3.ZERO
	await _frames(12)
	var solves := [0]
	_field.solved.connect(func() -> void: solves[0] += 1)
	var count := _field.recenter_count
	_target.global_position = Vector3(-30.0, 0.0, 0.0)
	await _frames(1)
	_check(_field.recenter_count == count + 1, "spostamento grande: ricentro")
	_check(solves[0] == 1, "risolto nello stesso passo fisico del ricentro (%d)" % solves[0])
	_check(_field.cost_at(_target.global_position) == 0.0, "costo zero sul bersaglio subito")
	var beside := _field.cost_at(_target.global_position + Vector3(2.4, 0.0, 0.0))
	_check(beside > 0.0 and beside < 3.0, "accanto al bersaglio costo piccolo, non quello della finestra vecchia (%.2f)" % beside)
	_field.min_solve_interval = 0.0
	_target.global_position = Vector3.ZERO
	await _frames(3)


func _test_chunk_cache() -> void:
	print("chunk cache")
	var scanned := _field.chunks_scanned
	_target.global_position = Vector3(0.0, 0.0, 0.0)
	_field.recenter(Vector2i(100, 100))
	_check(_field.chunks_scanned == scanned, "tornare al centro non rilegge i chunk (%d)" % _field.chunks_scanned)
	_field.recenter(Vector2i(20, 180))
	_check(_field.chunks_scanned > scanned, "una zona nuova legge chunk nuovi (%d)" % _field.chunks_scanned)
	var expected := (WINDOW / PathField.CHUNK + 1) * (WINDOW / PathField.CHUNK + 1)
	var per_window := _field.chunks_scanned - scanned
	_check(per_window <= expected, "al massimo %d chunk per finestra (%d)" % [expected, per_window])
	_field.recenter(Vector2i(100, 100))


func _test_far_wall_after_recenter() -> void:
	print("far wall")
	_target.global_position = Vector3(-80.0, 0.0, -70.0)
	await _frames(3)
	_check(not _field.is_walkable(Vector3(-80.0, 0.0, -80.0)), "il muro lontano e letto quando la finestra lo copre")
	_check(_field.is_walkable(Vector3(-80.0, 0.0, -84.0)), "accanto al muro lontano si passa")
	var cost_behind := _field.cost_at(Vector3(-80.0, 0.0, -84.0))
	var cost_side := _field.cost_at(Vector3(-70.0, 0.0, -80.0))
	_check(cost_behind < PathField.UNREACHABLE, "dietro il muro lontano si arriva")
	_check(cost_behind > cost_side, "dietro il muro costa di piu (%0.1f > %0.1f)" % [cost_behind, cost_side])
	_target.global_position = Vector3.ZERO
	await _frames(3)


func _test_walkable_outside_window() -> void:
	print("walkable outside")
	_check(_field.is_walkable(Vector3(90.0, 0.0, 90.0)), "fuori finestra, dentro l'arena: percorribile")
	_check(not _field.is_walkable(Vector3(-80.0, 0.0, -80.0)), "fuori finestra: il muro lontano resta letto dalla cache")
	_check(not _field.is_walkable(Vector3(HALF_EXTENT + 2.0, 0.0, 0.0)), "fuori dall'arena: non percorribile")


func _test_full_field_mode_unchanged() -> void:
	print("full field")
	var full := PathField.new()
	full.target = _target
	full.half_extent = 24.0
	full.window_cells = 0
	full.min_solve_interval = 0.0
	_world.add_child(full)
	await _frames(4)
	_check(full.columns == 40 and full.world_columns == 40, "window_cells=0: tutta l'arena (%d)" % full.columns)
	_check(full.origin == Vector2i.ZERO, "origine a zero")
	_check(full.cell_of(Vector3(-24.0, 0.0, -24.0)) == Vector2i.ZERO, "angolo sud-ovest e la cella 0,0")
	_check(not full.is_walkable(Vector3(6.0, 0.0, 0.0)), "il muro a est blocca anche qui")
	_target.global_position = Vector3(20.0, 0.0, 20.0)
	await _frames(3)
	_check(full.recenter_count == 0, "campo intero: mai ricentrato")
	_check(full.cost_at(_target.global_position) == 0.0, "campo intero: bersaglio seguito")
	_target.global_position = Vector3.ZERO
	full.queue_free()
	await _frames(2)


func _test_spawn_ring_and_leash() -> void:
	print("spawn ring")
	var player: PlayerCharacter = PlayerScene.instantiate()
	player.name = "Player"
	_world.add_child(player)
	player.global_position = Vector3(0.0, 0.88, 0.0)
	var director := EnemyDirector.new()
	director.tuning = RunTuning.new()
	director.player = player
	director.path_field = _field
	director.spawning = false
	director.rng.seed = 7
	_world.add_child(director)
	await _frames(2)
	var ok_ring := true
	var far_enough := true
	for i in 40:
		var point: Variant = director._find_spawn_point()
		if point == null:
			ok_ring = false
			break
		var d: float = Vector3(point.x, 0.0, point.z).length()
		if d < director.tuning.spawn_ring_min - 0.01 or d > director.tuning.spawn_ring_max + 0.01:
			ok_ring = false
		if d < director.tuning.spawn_min_player_distance:
			far_enough = false
	_check(ok_ring, "40 punti di comparsa sull'anello [%0.0f, %0.0f] m" % [director.tuning.spawn_ring_min, director.tuning.spawn_ring_max])
	_check(far_enough, "mai sotto la distanza minima dal giocatore")
	# Vicino al bordo l'anello viene riportato dentro l'arena.
	player.global_position = Vector3(HALF_EXTENT - 2.0, 0.88, 0.0)
	var inside := true
	for i in 20:
		var point: Variant = director._find_spawn_point()
		if point == null or absf(point.x) > HALF_EXTENT or absf(point.z) > HALF_EXTENT:
			inside = false
	_check(inside, "al bordo i punti restano dentro l'arena")
	player.global_position = Vector3(0.0, 0.88, 0.0)
	# Guinzaglio: un nemico a 60 m torna sull'anello.
	var enemy := director.spawn_at(Vector3(60.0, 0.0, 0.0))
	await _frames(2)
	var d := Vector3(enemy.global_position.x, 0.0, enemy.global_position.z).length()
	_check(director.leashed == 1, "nemico a 60 m riportato (%d)" % director.leashed)
	_check(d <= director.tuning.spawn_ring_max + 0.5, "ora sta sull'anello (%0.1f m)" % d)
	var near := director.spawn_at(Vector3(10.0, 0.0, 0.0))
	await _frames(2)
	_check(director.leashed == 1, "nemico a 10 m non toccato")
	var dn := Vector3(near.global_position.x, 0.0, near.global_position.z).length()
	_check(dn < 10.5, "il nemico vicino avanza verso il giocatore (%0.1f m)" % dn)
	_world.remove_child(director)
	director.free()
	_world.remove_child(player)
	player.free()
	await _frames(2)
