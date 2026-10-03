extends SceneTree
## Test con eventi di input reali (joypad, tasti con modificatori), non azioni
## simulate: coprono i percorsi che Input.action_press non attraversa.
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/input_events_tests.gd

const SmokeTestScene := preload("res://scenes/main/smoke_test.tscn")
const TRIGGER_RIGHT := JOY_AXIS_TRIGGER_RIGHT
const LEFT_X := JOY_AXIS_LEFT_X

var _failures := 0
var _player: PlayerCharacter
var _grid: TerrainGrid


func _initialize() -> void:
	await _load_scene()
	await _test_trigger_fires_once_per_pull()
	await _reload_scene()
	await _test_actions_ignore_modifiers()
	await _reload_scene()
	await _test_move_actuation_threshold()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


## Un grilletto analogico invia un evento a ogni variazione: il tool deve
## scattare una sola volta per pressione, come il trigger Started di Unreal.
func _test_trigger_fires_once_per_pull() -> void:
	print("right trigger")
	# Cella bersaglio (5,3) Lowered e modalita Raise: una pressione ripetuta
	# la porterebbe a Raised in due passi, una corretta solo a Normal.
	var cell := Vector2i(5, 3)
	_grid.apply_command_at(_player.terrain_target, TerrainState.ToolMode.DIG)
	_player.terrain_tool_mode = TerrainState.ToolMode.RAISE
	var changes := [0]
	_grid.cell_changed.connect(func(_c, _s): changes[0] += 1)
	for value in [0.3, 0.6, 0.8, 1.0, 0.9]:
		_joy_motion(TRIGGER_RIGHT, value)
		await _frames(1)
	_check(changes[0] == 1, "una pressione del grilletto = un comando (got %d)" % changes[0])
	_check(_grid.state.get_state(cell) == TerrainState.CellState.NORMAL, "Lowered -> Normal, un solo passo")
	_joy_motion(TRIGGER_RIGHT, 0.2)
	await _frames(1)
	_joy_motion(TRIGGER_RIGHT, 1.0)
	await _frames(2)
	_check(changes[0] == 2 and _grid.state.get_state(cell) == TerrainState.CellState.RAISED,
		"rilascio e nuova pressione: secondo passo (got %d)" % changes[0])
	_joy_motion(TRIGGER_RIGHT, 0.0)
	await _frames(1)


## In Unreal MapKey ignora i modificatori: Shift+Spazio fa comunque il dash.
func _test_actions_ignore_modifiers() -> void:
	print("modifiers")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.shift_pressed = true
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check(_player.is_dashing, "Shift+Spazio avvia il dash")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(1)

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.ctrl_pressed = true
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(2)
	_check(_player.terrain_tool_mode == TerrainState.ToolMode.RAISE, "Ctrl+clic destro cambia modalita")
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await _frames(1)


## IA_Move ha un UInputTriggerDown (soglia 0,5 sul modulo): sotto non ci si
## muove, sopra la velocita segue il modulo grezzo dello stick.
func _test_move_actuation_threshold() -> void:
	print("move threshold")
	_joy_motion(LEFT_X, 0.4)
	await _frames(60)
	_check(Vector2(_player.velocity.x, _player.velocity.z).is_zero_approx(), "stick a 0,4: fermo")
	_joy_motion(LEFT_X, 0.6)
	await _frames(60)
	_check(absf(_player.velocity.x - 3.6) < 0.01, "stick a 0,6: 3,6 m/s (got %.3f)" % _player.velocity.x)
	_joy_motion(LEFT_X, 1.0)
	await _frames(60)
	_check(absf(_player.velocity.x - 6.0) < 0.01, "stick a 1,0: 6 m/s (got %.3f)" % _player.velocity.x)
	_joy_motion(LEFT_X, 0.0)
	await _frames(10)


func _joy_motion(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _load_scene() -> void:
	var scene := SmokeTestScene.instantiate()
	scene.name = "Scene"
	root.add_child(scene)
	_player = scene.get_node("Player")
	_grid = scene.get_node("TerrainGrid")
	await _frames(2)


func _reload_scene() -> void:
	root.get_node("Scene").free()
	await _load_scene()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
