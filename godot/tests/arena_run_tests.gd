extends SceneTree
## Test del prototipo della promessa A (D-038). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/arena_run_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")

var _failures := 0
var _scene: Node3D
var _run: ArenaRun
var _field: TerrainField
var _district: RuinsDistrict
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
	_field = _scene.get_node(^"TerrainField")
	_district = _scene.get_node(^"District")
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
	await _test_uphill_slows_enemies()
	await _test_dig_debris_throttled()
	await _test_level_up_flow()
	_test_companion_upgrades()
	await _test_death_ends_run()
	# T-12: i nodi messi in coda con queue_free vanno liberati prima di uscire, o
	# il motore segnala istanze ObjectDB perse all'uscita.
	await _frames(2)
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


## Raggio in metri dell'anello del cortile di partenza.
func _ring_radius() -> float:
	return _run.tuning.wall_ring_radius * RuinsDistrict.CELL


## Chiude un varco come farebbe l'argine: tre pennellate lungo l'anello, cosi fra il tappo
## e le pennellate vicine non resta una sella calpestabile.
func _seal_gate(gate: Vector3) -> void:
	var tangent := Vector3(-gate.z, 0.0, gate.x).normalized()
	for k in [-1, 0, 1]:
		_field.sculpt(gate + tangent * 1.6 * k, 2.0, 1.4)


## I quattro varchi del cortile di partenza, sui lati dell'anello (XZ).
func _gates() -> Array[Vector3]:
	var r := _ring_radius()
	return [Vector3(0.0, 0.0, -r), Vector3(0.0, 0.0, r), Vector3(r, 0.0, 0.0), Vector3(-r, 0.0, 0.0)]


## Il cortile di partenza e un anello di argini sul rilievo con quattro varchi piani.
func _test_courtyard_walls() -> void:
	print("courtyard")
	var ring_radius := _ring_radius()
	var start: Dictionary = _district.terrain_strokes[0]
	_check(start.kind == &"start" and is_equal_approx(start.radius, ring_radius), "il cortile di partenza e un anello di %.1f m" % ring_radius)
	var high := 0
	for p: Vector2 in start.points:
		if _field.height_at(Vector3(p.x, 0.0, p.y)) > 1.0:
			high += 1
	_check(high == start.points.size(), "l'argine supera 1 m su tutte le pennellate (%d/%d)" % [high, start.points.size()])
	var flat := true
	for i in 16:
		var angle := TAU * i / 16.0
		var p := Vector3(cos(angle), 0.0, sin(angle)) * ring_radius * 0.5
		flat = flat and absf(_field.height_at(p)) < 0.3
	_check(flat, "dentro il cortile il suolo e quasi piano")
	var gates_open := true
	for gate in _gates():
		gates_open = gates_open and absf(_field.height_at(gate)) < 0.3
	_check(gates_open, "quattro varchi aperti")
	_check(_path.is_ready(), "campo di percorso pronto")


## Da fuori gli argini il percorso attraversa l'anello solo nei varchi.
func _test_path_uses_gates() -> void:
	print("path")
	_place_player(Vector3.ZERO)
	var ring := _ring_radius()
	var start := Vector3(6.0, 0.0, -15.0)
	var point := start
	var reached := false
	var through_wall := false
	for i in 80:
		var next: Variant = _path.next_waypoint(point)
		if next == null:
			break
		point = next
		var distance := Vector2(point.x, point.z).length()
		if distance > ring - 1.2 and distance < ring + 1.2 and minf(absf(point.x), absf(point.z)) > 2.0:
			through_wall = true
		if _path.cell_of(point) == _path.cell_of(_player.global_position):
			reached = true
			break
	_check(reached, "il percorso arriva al giocatore dal nord-est esterno")
	_check(not through_wall, "il percorso passa solo dai varchi")


func _test_sealed_courtyard() -> void:
	print("sealed")
	for gate in _gates():
		_seal_gate(gate)
	await _frames(2)
	_path.solve()
	var outside := Vector3(6.0, 0.0, -15.0)
	_check(_path.cost_at(outside) == PathField.UNREACHABLE, "cortile chiuso: da fuori il giocatore e irraggiungibile")
	_check(_path.next_waypoint(outside) == null, "nessun waypoint: i nemici puntano dritto contro gli argini")
	for gate in _gates():
		_field.level(gate, 4.0, _field.base_height_at(gate), 1.0)
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
	# Frammenti a perdere (D-047): nascono dove muore e si liberano da soli.
	var victim := _director.spawn_at(Vector3(-6.0, 0.0, 3.0))
	victim.take_damage(victim.health)
	var bursts := _director.get_children().filter(func(n: Node) -> bool:
		return n is CPUParticles3D and (n as CPUParticles3D).global_position.distance_to(Vector3(-6.0, 0.5, 3.0)) < 0.6)
	_check(bursts.size() == 1, "un rottamatore abbattuto schizza frammenti nel punto in cui muore")
	await _frames(90)
	_check(bursts.all(func(n: Variant) -> bool: return not is_instance_valid(n)), "i frammenti si liberano da soli")
	_director.set_physics_process(true)
	await _frames(2)
	_clear_enemies()


func _test_wall_blocks_line_of_fire() -> void:
	print("line of fire")
	_clear_enemies()
	# Un punto dell'argine in diagonale, lontano dai varchi.
	var direction := RuinsDistrict.cell_offset_to_world(Vector2i(_run.tuning.wall_ring_radius, 2)).normalized()
	var outward := Vector3(direction.x, 0.0, direction.y)
	var wall := outward * _ring_radius()
	_place_player(wall - outward * 3.0)
	_director.set_physics_process(false)
	var behind := _director.spawn_at(wall + outward * 2.0)
	behind.global_position.y = _field.height_at(behind.global_position) + Enemy.spawn_height()
	await _frames(2)
	_check(_weapon.find_target() == null, "nessun bersaglio dietro un argine")
	behind.global_position = _player.global_position - outward * 3.0
	behind.global_position.y = _field.height_at(behind.global_position) + Enemy.spawn_height()
	await _frames(1)
	_check(_weapon.find_target() == behind, "lo stesso nemico allo scoperto e un bersaglio")
	_director.set_physics_process(true)
	_clear_enemies()


## In salita il rottamatore rallenta (Task 7): dosso dolce fuori dal cortile.
func _test_uphill_slows_enemies() -> void:
	print("uphill")
	_clear_enemies()
	_place_player(Vector3.ZERO)
	var mound := Vector3(0.0, 0.0, -16.0)
	_field.sculpt(mound, 5.0, 2.0)
	await _frames(2)
	_path.solve()
	var normal_enemy := _director.spawn_at(Vector3(12.0, 0.0, -12.0))
	normal_enemy.global_position.y = _field.height_at(normal_enemy.global_position) + Enemy.spawn_height()
	var slow_enemy := _director.spawn_at(Vector3(0.0, 0.0, -19.5))
	slow_enemy.global_position.y = _field.height_at(slow_enemy.global_position) + Enemy.spawn_height()
	await _frames(20)
	var normal_speed := Vector2(normal_enemy.velocity.x, normal_enemy.velocity.z).length()
	var slow_speed := Vector2(slow_enemy.velocity.x, slow_enemy.velocity.z).length()
	_check(normal_speed > 2.0, "in piano va a piena velocita (%.2f m/s)" % normal_speed)
	_check(slow_speed < normal_speed * 0.85, "in salita rallenta (%.2f m/s)" % slow_speed)
	_field.level(mound, 6.0, _field.base_height_at(mound), 1.0)
	await _frames(2)
	_clear_enemies()


## Review finale: le zolle che saltano mentre si scava sono al piu una ogni 0,2 s, non una
## per passo fisico (120 nodi al secondo).
func _test_dig_debris_throttled() -> void:
	print("dig debris")
	_place_player(Vector3.ZERO)
	_run._start_protect_left = 0.0
	_field.set_protected(Vector3.ZERO, _field.tuning.start_protected_radius_m, false)
	var before := _scene.find_children("*", "CPUParticles3D", false, false).size()
	for i in 24:
		_field.player_sculpt(Vector3(3.0, 0.0, -3.0), 2.4, -0.05, TerrainField.ToolMode.DIG)
		await physics_frame
	var bursts := _scene.find_children("*", "CPUParticles3D", false, false).size() - before
	_check(bursts >= 1 and bursts <= 3, "24 passi di scavo in 0,4 s: da 1 a 3 zolle (%d)" % bursts)
	_field.level(Vector3(3.0, 0.0, -3.0), 3.0, _field.base_height_at(Vector3(3.0, 0.0, -3.0)), 1.0)
	await _frames(2)


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
	# Il level-up precedente sceglie una carta a caso: puo gia essere il cassone.
	var capacity_before := _companion.capacity
	_run.apply_upgrade(&"companion_cargo", 1)
	_check(_companion.capacity == capacity_before + 2, "cassone rinforzato: capacita +2")
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
