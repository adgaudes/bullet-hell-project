extends SceneTree
## Test della Slice B (Fase 8): penalita di velocita e hazard. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/slice_b_tests.gd

const SmokeTestScene := preload("res://scenes/main/smoke_test.tscn")
const DT := 1.0 / 60.0

var _failures := 0
var _player: PlayerCharacter
var _grid: TerrainGrid
var _hazard: TerrainHazard


func _initialize() -> void:
	# I valori attesi sono calcolati a 60 passi fisici al secondo; il progetto ne usa 120.
	Engine.physics_ticks_per_second = 60
	await _load_scene()
	await _test_speed_penalty()
	await _reload_scene()
	await _test_hazard_lane()
	await _reload_scene()
	await _test_hazard_blocked_by_player_raise()
	await _reload_scene()
	await _test_lane_follows_grid()
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


func _test_speed_penalty() -> void:
	print("speed penalty")
	# Striscia Lowered verso destra (+X Godot = Y Unreal): celle (3,3), (3,4), (3,5).
	for x in [0.0, 2.4, 4.8]:
		_grid.apply_command_at(Vector3(x, 0, 0), TerrainState.ToolMode.DIG, _player)
	await _frames(2)
	Input.action_press(&"move_right")
	await _frames(60)
	_check(is_equal_approx(_player.speed_multiplier, 0.5), "moltiplicatore 0,5 sopra Lowered (got %.2f)" % _player.speed_multiplier)
	_check(absf(_player.velocity.x - 3.0) < 0.01, "velocita 3 m/s sopra Lowered (got %.3f)" % _player.velocity.x)
	await _frames(120)
	Input.action_release(&"move_right")
	_check(_player.global_position.x > 6.0, "uscito dalla striscia (x=%.2f)" % _player.global_position.x)
	_check(is_equal_approx(_player.speed_multiplier, 1.0), "moltiplicatore 1 fuori da Lowered")
	_check(absf(_player.velocity.x - 6.0) < 0.01, "di nuovo 6 m/s fuori da Lowered (got %.3f)" % _player.velocity.x)


func _test_hazard_lane() -> void:
	print("hazard lane")
	# Corsia: 7 * 240 / 2 + 260 = 1100 cm per lato, a 50 cm d'altezza, lungo X Unreal (-Z Godot).
	_check(_hazard.lane_start.is_equal_approx(Vector3(0, 0.5, 11.0)), "inizio corsia (0; 0,5; 11) (got %s)" % _hazard.lane_start)
	_check(_hazard.lane_direction.is_equal_approx(Vector3(0, 0, -1)), "direzione -Z (got %s)" % _hazard.lane_direction)
	_check(is_equal_approx(_hazard.lane_length, 22.0), "lunghezza 22 m (got %.2f)" % _hazard.lane_length)

	var player_start := _player.global_position
	var events := {&"blocked": 0, &"reached": 0}
	_hazard.blocked.connect(func(): events[&"blocked"] += 1)
	_hazard.reached.connect(func(): events[&"reached"] += 1)
	var z0 := _hazard.global_position.z
	await _frames(120)
	_check(absf((z0 - _hazard.global_position.z) - 7.0) < 0.06, "3,5 m/s: 7 m in 2 s (got %.3f)" % (z0 - _hazard.global_position.z))

	# 22 m a 3,5 m/s = 6,29 s: attraversa il personaggio senza fermarsi ne spingerlo.
	await _wait_until(func(): return events[&"reached"] > 0, 600)
	_check(events[&"reached"] == 1 and events[&"blocked"] == 0, "arriva in fondo attraversando il personaggio")
	_check(_player.global_position.is_equal_approx(player_start), "il personaggio non viene spinto")
	_check(_hazard.is_resting and not (_hazard.get_node("Mesh") as Node3D).visible, "in pausa e nascosto dopo l'arrivo")
	await _frames(61)
	_check(not _hazard.is_resting and _hazard.global_position.distance_to(_hazard.lane_start) < 0.1,
		"riparte dall'inizio dopo 1 s")


func _test_hazard_blocked_by_player_raise() -> void:
	print("hazard blocked by player raise")
	# Il personaggio all'origine guarda -Z: il bersaglio del tool e la cella (5,3), sulla corsia.
	await _send(&"terrain_mode")
	await _send(&"terrain_tool")
	_check(_grid.state.get_state(Vector2i(5, 3)) == TerrainState.CellState.RAISED, "il giocatore rialza la cella (5,3) sulla corsia")

	var blocked := [0]
	_hazard.blocked.connect(func(): blocked[0] += 1)
	await _wait_until(func(): return blocked[0] > 0, 900)
	# Bordo vicino della cella: -4,8 + 1,14 = -3,66; centro sfera a -3,66 + 0,45 = -3,21.
	_check(blocked[0] == 1, "l'hazard si ferma sul terrapieno")
	_check(absf(_hazard.global_position.z + 3.21) < 0.02, "fermo a contatto del bordo (z=%.3f)" % _hazard.global_position.z)
	_check(_hazard.is_resting, "in pausa dopo il blocco")

	await _wait_until(func(): return blocked[0] > 1, 900)
	_check(blocked[0] == 2, "al ciclo successivo si ferma di nuovo")

	# Riabbassata la cella, la corsia torna libera.
	_grid.apply_command_at(Vector3(0, 0, -4.8), TerrainState.ToolMode.DIG, _player)
	var reached := [0]
	_hazard.reached.connect(func(): reached[0] += 1)
	await _wait_until(func(): return reached[0] > 0, 1200)
	_check(reached[0] == 1 and blocked[0] == 2, "cella tornata Normal: l'hazard arriva in fondo")


func _test_lane_follows_grid() -> void:
	print("lane follows grid")
	# Griglia ricostruita 5x7: corsia 5 * 2,4 + 2 * 2,6 = 17,2 m.
	_grid.tuning = _grid.tuning.duplicate()
	_grid.tuning.grid_width = 5
	await _frames(2)
	_check(is_equal_approx(_hazard.lane_length, 17.2), "corsia ricalcolata dopo la ricostruzione (got %.2f)" % _hazard.lane_length)
	_check(_hazard.lane_start.is_equal_approx(Vector3(0, 0.5, 8.6)), "nuovo inizio corsia (got %s)" % _hazard.lane_start)
	# Griglia scalata 2x: la lunghezza segue gli estremi in spazio mondo.
	_grid.scale = Vector3(2, 2, 2)
	_hazard.configure_lane_from_grid(_grid)
	_check(is_equal_approx(_hazard.lane_length, 34.4), "corsia su griglia scalata (got %.2f)" % _hazard.lane_length)


func _load_scene() -> void:
	var scene := SmokeTestScene.instantiate()
	scene.name = "Scene"
	root.add_child(scene)
	_player = scene.get_node("Player")
	_grid = scene.get_node("TerrainGrid")
	_hazard = scene.get_node("TerrainHazard")
	_use_reference_tuning(_player)
	await _frames(2)


func _reload_scene() -> void:
	root.get_node("Scene").free()
	await _load_scene()


func _send(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	await _frames(2)


func _wait_until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await physics_frame


## I valori attesi sono quelli del riferimento Unreal, non del preset di default.
func _use_reference_tuning(player: PlayerCharacter) -> void:
	player.apply_tuning(load("res://resources/tuning/player_default.tres"))


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
