extends SceneTree
## Test del prototipo della promessa A (D-038). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/arena_run_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")

var _failures := 0
var _scene: Node3D
var _run: ArenaRun
var _grid: TerrainGrid
var _player: PlayerCharacter
var _companion: Companion
var _director: EnemyDirector
var _weapon: AutoWeapon
var _path: PathField
var _xp: XpField
var _menu: LevelUpMenu


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_run = _scene.get_node(^"Run")
	_grid = _scene.get_node(^"TerrainGrid")
	_player = _scene.get_node(^"Player")
	_companion = _scene.get_node(^"Companion")
	_director = _scene.get_node(^"EnemyDirector")
	_weapon = _scene.get_node(^"PlayerWeapon")
	_path = _scene.get_node(^"PathField")
	_xp = _scene.get_node(^"XpField")
	_menu = _scene.get_node(^"LevelUpMenu")
	_director.spawning = false
	await _frames(5)
	# Dopo il _ready della scena, che riattiverebbe il passo fisico.
	_weapon.set_physics_process(false)
	_test_courtyard_walls()
	_test_path_uses_gates()
	await _test_sealed_courtyard()
	await _test_contact_damage()
	await _test_weapon_kills_and_drops_xp()
	await _test_wall_blocks_line_of_fire()
	await _test_lowered_cell_slows_enemies()
	await _test_level_up_flow()
	_test_companion_upgrades()
	await _test_death_ends_run()
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


func _clear_enemies() -> void:
	for enemy in _director.enemies:
		enemy.queue_free()
	_director.enemies.clear()


func _place_player(at: Vector3) -> void:
	_player.global_position = Vector3(at.x, 0.88, at.z)
	_player.velocity = Vector3.ZERO
	_path.solve()


func _cell_world(cell: Vector2i) -> Vector3:
	var p := _grid.to_global(_grid.cell_local_position(cell, TerrainState.CellState.NORMAL))
	return Vector3(p.x, 0.0, p.z)


func _gates() -> Array[Vector2i]:
	var c := Vector2i(_grid.state.width / 2, _grid.state.height / 2)
	var r := _run.tuning.wall_ring_radius
	return [c + Vector2i(r, 0), c + Vector2i(-r, 0), c + Vector2i(0, r), c + Vector2i(0, -r)]


func _test_courtyard_walls() -> void:
	print("courtyard")
	# Il cortile di partenza e l'anello attorno alla cella centrale; nell'arena grande
	# (D-042) ci sono anche altri punti di interesse Raised, piu lontani.
	var c := Vector2i(_grid.state.width / 2, _grid.state.height / 2)
	var r := _run.tuning.wall_ring_radius
	var ring := 0
	var raised := 0
	for y in _grid.state.height:
		for x in _grid.state.width:
			if _grid.state.get_state(Vector2i(x, y)) != TerrainState.CellState.RAISED:
				continue
			raised += 1
			if maxi(absi(x - c.x), absi(y - c.y)) == r:
				ring += 1
	_check(ring == 28, "28 celle di mura nel cortile di partenza (trovate %d)" % ring)
	_check(raised > ring, "altri punti di interesse Raised oltre il cortile (%d in tutto)" % raised)
	var clear := true
	for y in range(c.y - r + 1, c.y + r):
		for x in range(c.x - r + 1, c.x + r):
			clear = clear and _grid.state.get_state(Vector2i(x, y)) == TerrainState.CellState.NORMAL
	_check(clear, "dentro il cortile tutte le celle sono Normal")
	var gates_open := true
	for gate in _gates():
		gates_open = gates_open and _grid.state.get_state(gate) == TerrainState.CellState.NORMAL
	_check(gates_open, "quattro varchi aperti")
	_check(_path.is_ready(), "campo di percorso pronto")


## Da fuori le mura il percorso attraversa l'anello solo nei varchi.
func _test_path_uses_gates() -> void:
	print("path")
	_place_player(Vector3.ZERO)
	var ring := _run.tuning.wall_ring_radius * 2.4
	var start := Vector3(6.0, 0.0, -15.0)
	var point := start
	var reached := false
	var through_wall := false
	for i in 80:
		var next: Variant = _path.next_waypoint(point)
		if next == null:
			break
		point = next
		var outer := maxf(absf(point.x), absf(point.z))
		if outer > ring - 1.2 and outer < ring + 1.2 and minf(absf(point.x), absf(point.z)) > 1.2:
			through_wall = true
		if _path.cell_of(point) == _path.cell_of(_player.global_position):
			reached = true
			break
	_check(reached, "il percorso arriva al giocatore dal nord-est esterno")
	_check(not through_wall, "il percorso passa solo dai varchi")


func _test_sealed_courtyard() -> void:
	print("sealed")
	_grid.set_cell_states(_gates(), TerrainState.CellState.RAISED)
	_path.solve()
	var outside := Vector3(6.0, 0.0, -15.0)
	_check(_path.cost_at(outside) == PathField.UNREACHABLE, "cortile chiuso: da fuori il giocatore e irraggiungibile")
	_check(_path.next_waypoint(outside) == null, "nessun waypoint: i nemici puntano dritto contro le mura")
	_grid.set_cell_states(_gates(), TerrainState.CellState.NORMAL)
	await _frames(2)
	_path.solve()
	_check(_path.cost_at(outside) < PathField.UNREACHABLE, "varchi riaperti: di nuovo raggiungibile")


func _test_contact_damage() -> void:
	print("contact")
	_clear_enemies()
	_place_player(Vector3.ZERO)
	var start_health := _player.health
	_director.spawn_at(Vector3(3.0, 0.0, 0.0))
	var hit_frame := -1
	for i in 150:
		await physics_frame
		if _player.health < start_health:
			hit_frame = i
			break
	_check(hit_frame >= 0, "il rottamatore raggiunge il giocatore e lo colpisce (frame %d)" % hit_frame)
	await _frames(30)
	_check(_player.health == start_health - 1, "invulnerabilita: un solo colpo in 0,5 s (vita %d)" % _player.health)
	_clear_enemies()
	_player.set_max_health(_run.tuning.player_max_health)


func _test_weapon_kills_and_drops_xp() -> void:
	print("weapon")
	_clear_enemies()
	_place_player(Vector3.ZERO)
	_director.set_physics_process(false)
	var enemy := _director.spawn_at(Vector3(5.0, 0.0, 0.0))
	var kills := _director.kills
	var fragments := _xp.count()
	_weapon.set_physics_process(true)
	await _frames(90)
	_weapon.set_physics_process(false)
	_check(not is_instance_valid(enemy) or enemy.is_dead, "la chiodatrice abbatte un rottamatore a 5 m")
	_check(_director.kills == kills + 1, "uccisione contata")
	_check(_xp.count() == fragments + 1, "rilascia un frammento di esperienza")
	_director.set_physics_process(true)
	await _frames(2)
	_clear_enemies()


func _test_wall_blocks_line_of_fire() -> void:
	print("line of fire")
	_clear_enemies()
	var c := Vector2i(_grid.state.width / 2, _grid.state.height / 2)
	var wall := _cell_world(c + Vector2i(_run.tuning.wall_ring_radius, 2))
	var outward := wall.normalized()
	_place_player(wall - outward * 3.0)
	_director.set_physics_process(false)
	var behind := _director.spawn_at(wall + outward * 2.0)
	await _frames(2)
	_check(_weapon.find_target() == null, "nessun bersaglio dietro una cella rialzata")
	behind.global_position = _player.global_position + Vector3(0.0, 0.0, 0.0) - outward * 3.0
	behind.global_position.y = Enemy.spawn_height()
	await _frames(1)
	_check(_weapon.find_target() == behind, "lo stesso nemico allo scoperto e un bersaglio")
	_director.set_physics_process(true)
	_clear_enemies()


func _test_lowered_cell_slows_enemies() -> void:
	print("lowered")
	_clear_enemies()
	var c := Vector2i(_grid.state.width / 2, _grid.state.height / 2)
	_place_player(_cell_world(c + Vector2i(-3, 0)))
	var normal_enemy := _director.spawn_at(_cell_world(c + Vector2i(1, -2)))
	var dug := c + Vector2i(1, 2)
	_grid.apply_command_at(_cell_world(dug), TerrainState.ToolMode.DIG)
	var slow_enemy := _director.spawn_at(_cell_world(dug))
	await _frames(20)
	var normal_speed := Vector2(normal_enemy.velocity.x, normal_enemy.velocity.z).length()
	var slow_speed := Vector2(slow_enemy.velocity.x, slow_enemy.velocity.z).length()
	_check(normal_speed > 2.0, "su cella Normal va a piena velocita (%.2f m/s)" % normal_speed)
	_check(slow_speed < 1.3, "su cella Lowered rallenta (%.2f m/s)" % slow_speed)
	_clear_enemies()


func _test_level_up_flow() -> void:
	print("level up")
	_place_player(Vector3.ZERO)
	var level := _run.progression.level
	_xp.spawn(_player.global_position + Vector3(1.0, 0.0, 0.0), _run.progression.xp_to_next())
	await _frames(20)
	_check(_run.progression.level == level + 1, "il frammento raccolto fa salire di livello")
	_check(_menu.is_open and paused, "si apre la scelta e il gioco si ferma")
	_check(_menu.card_count() == 3, "tre carte")
	_menu.press(0)
	_check(_menu.is_open, "carte inattive subito dopo l'apertura")
	await create_timer(0.6, true).timeout
	_menu.press(0)
	await _frames(2)
	_check(not _menu.is_open and not paused, "scelta fatta: il gioco riparte")
	_check(_run.progression.levels.size() == 1, "un upgrade acquisito %s" % [_run.progression.levels])


func _test_companion_upgrades() -> void:
	print("companion upgrades")
	var base_capacity := _companion.tuning.capacity
	_run.apply_upgrade(&"companion_cargo", 1)
	_check(_companion.capacity == base_capacity + 2, "cassone rinforzato: capacita +2")
	_check(_companion.tuning.capacity == base_capacity, "la risorsa di tuning non cambia")
	_run.apply_upgrade(&"companion_turret", 1)
	_check(_run.companion_weapon != null and _companion.has_node(^"TurretPart"), "torretta montata e visibile")
	_run.apply_upgrade(&"companion_magnet", 1)
	_check(_companion.has_node(^"MagnetPart") and _xp.attractors.size() == 1, "calamita montata e attiva")


func _test_death_ends_run() -> void:
	print("death")
	_clear_enemies()
	_player.set_max_health(1)
	await _frames(60)
	_player.take_damage(1)
	await _frames(2)
	var game_over: GameOverPanel = _scene.get_node(^"GameOverPanel")
	_check(_run.is_over and game_over.is_open and paused, "vita a zero: fine run e gioco fermo")
	paused = false
