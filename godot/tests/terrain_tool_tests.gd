extends SceneTree
## Test del tool terreno e dell'anteprima (Fase 7), sui passi 5-9 del Test A
## di docs/PLAYTESTS/TERRAIN_GRID_SLICE_A_2026-09-22.md. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/terrain_tool_tests.gd

const SmokeTestScene := preload("res://scenes/main/smoke_test.tscn")
const LOWERED := TerrainState.CellState.LOWERED
const NORMAL := TerrainState.CellState.NORMAL
const RAISED := TerrainState.CellState.RAISED

var _failures := 0
var _player: PlayerCharacter
var _grid: TerrainGrid


func _initialize() -> void:
	var scene := SmokeTestScene.instantiate()
	root.add_child(scene)
	_player = scene.get_node("Player")
	_grid = scene.get_node("TerrainGrid")
	await _frames(2)

	print("target and preview")
	_check(_player.terrain_tool_mode == TerrainState.ToolMode.DIG, "modalita iniziale Dig")
	# Personaggio all'origine, rivolto verso -Z (X Unreal): bersaglio a 4,8 m -> cella (5,3).
	_check(_grid.preview_cell == Vector2i(5, 3), "bersaglio a 4,8 m davanti -> cella (5,3) (got %s)" % _grid.preview_cell)
	_check(_preview_color() == TerrainGrid.DIG_PREVIEW_COLOR, "anteprima ciano in Dig")
	var preview := _grid.get_node("Preview") as MeshInstance3D
	_check(preview.visible and absf(preview.position.y - 0.165) < 0.001, "anteprima sopra la cella Normal (y=%.3f)" % preview.position.y)

	# Mira a destra: il bersaglio segue l'orientamento -> cella (3,5).
	Input.action_press(&"aim_right", 1.0)
	await _frames(60)
	Input.action_release(&"aim_right")
	_check(_grid.preview_cell == Vector2i(3, 5), "mira a destra -> cella (3,5) (got %s)" % _grid.preview_cell)
	Input.action_press(&"aim_up", 1.0)
	await _frames(60)
	Input.action_release(&"aim_up")

	print("Test A steps 5-7")
	var cell := Vector2i(5, 3)
	await _send(&"terrain_tool")
	_check(_grid.state.get_state(cell) == LOWERED, "passo 5: Normal -> Lowered")
	_check(_preview_color() == TerrainGrid.INVALID_PREVIEW_COLOR, "anteprima rossa: Dig su Lowered impossibile")
	await _send(&"terrain_mode")
	_check(_player.terrain_tool_mode == TerrainState.ToolMode.RAISE, "passo 6: cambio modalita -> Raise")
	_check(_preview_color() == TerrainGrid.RAISE_PREVIEW_COLOR, "anteprima gialla in Raise")
	await _send(&"terrain_tool")
	_check(_grid.state.get_state(cell) == NORMAL, "Lowered -> Normal")
	await _send(&"terrain_tool")
	_check(_grid.state.get_state(cell) == RAISED, "Normal -> Raised")
	_check(_preview_color() == TerrainGrid.INVALID_PREVIEW_COLOR, "passo 7: oltre il limite -> anteprima rossa")
	await _send(&"terrain_tool")
	_check(_grid.state.get_state(cell) == RAISED, "comando oltre il limite non cambia lo stato")
	var raised_preview_y := (_grid.get_node("Preview") as Node3D).position.y
	_check(absf(raised_preview_y - 1.245) < 0.001, "anteprima sopra la cella Raised (y=%.3f)" % raised_preview_y)

	print("Test A step 8: protected cell")
	# Cella protetta (0,0) al centro (-7,2; 7,2): ci si mette 4,8 m dietro, rivolti a -Z.
	_teleport(Vector3(-7.2, 0.88, 12.0))
	await _frames(2)
	_check(_grid.preview_cell == Vector2i(0, 0), "bersaglio sulla cella protetta (got %s)" % _grid.preview_cell)
	_check(_preview_color() == TerrainGrid.INVALID_PREVIEW_COLOR, "cella protetta -> anteprima rossa")
	await _send(&"terrain_tool")
	await _send(&"terrain_mode")
	await _send(&"terrain_tool")
	_check(_grid.state.get_state(Vector2i(0, 0)) == NORMAL, "cella protetta invariata con Dig e Raise")

	print("outside grid")
	_teleport(Vector3(0, 0.88, -20.0))
	await _frames(2)
	_check(not preview.visible and _grid.preview_cell == Vector2i(-1, -1), "fuori griglia -> anteprima nascosta")

	print("Test A step 9: rapid edits")
	_teleport(Vector3(0, 0.88, 4.8))
	await _frames(2)
	var target := _grid.preview_cell
	var changes := [0]
	_grid.cell_changed.connect(func(_c, _s): changes[0] += 1)
	for i in 12:
		await _send(&"terrain_mode" if i % 3 == 2 else &"terrain_tool")
	_check(changes[0] >= 6, "modifiche rapide con cambi di modalita applicate (%d)" % changes[0])
	_check(_count_cells() == 49, "sempre 49 celle")

	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _preview_color() -> Color:
	var preview := _grid.get_node("Preview") as MeshInstance3D
	var srgb: Color = preview.get_instance_shader_parameter(&"cell_color")
	for c in [TerrainGrid.DIG_PREVIEW_COLOR, TerrainGrid.RAISE_PREVIEW_COLOR, TerrainGrid.INVALID_PREVIEW_COLOR]:
		if srgb.is_equal_approx(c.linear_to_srgb()):
			return c
	return Color.BLACK


func _teleport(position: Vector3) -> void:
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()


## Pressione e rilascio come eventi reali.
func _send(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	await _frames(2)


func _count_cells() -> int:
	var count := 0
	for child in _grid.get_children():
		if child is StaticBody3D:
			count += 1
	return count


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
