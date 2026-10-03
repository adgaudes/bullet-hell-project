extends SceneTree
## Test della griglia terreno (Fase 6). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/terrain_tests.gd

const TerrainStateScript := preload("res://scripts/terrain/terrain_state.gd")
const TerrainGridScript := preload("res://scripts/terrain/terrain_grid.gd")
const PlayerScene := preload("res://scenes/player/player.tscn")
const SmokeTestScene := preload("res://scenes/main/smoke_test.tscn")

const LOWERED := TerrainState.CellState.LOWERED
const NORMAL := TerrainState.CellState.NORMAL
const RAISED := TerrainState.CellState.RAISED
const DIG := TerrainState.ToolMode.DIG
const RAISE := TerrainState.ToolMode.RAISE

var _failures := 0


func _initialize() -> void:
	_test_state_rules()
	await _test_grid_structure()
	await _test_collisions_and_overlap()
	await _test_player_blocked_by_raised_cell()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _test_state_rules() -> void:
	print("state rules")
	var s: TerrainState = TerrainStateScript.new()
	s.resize(7, 7)
	_check(s.cell_count() == 49, "7x7 = 49 celle")
	var c := Vector2i(3, 3)
	_check(s.get_state(c) == NORMAL, "stato iniziale Normal")

	# Transizioni di un livello per passo.
	_check(s.can_apply(c, DIG) and s.apply(c, DIG) == LOWERED, "Normal -Dig-> Lowered")
	_check(not s.can_apply(c, DIG), "Lowered -Dig-> rifiutato")
	_check(s.apply(c, RAISE) == NORMAL, "Lowered -Raise-> Normal")
	_check(s.apply(c, RAISE) == RAISED, "Normal -Raise-> Raised")
	_check(not s.can_apply(c, RAISE), "Raised -Raise-> rifiutato")
	_check(s.apply(c, DIG) == NORMAL, "Raised -Dig-> Normal")

	# Cella protetta e coordinate fuori griglia.
	_check(not s.can_apply(Vector2i(0, 0), DIG) and not s.can_apply(Vector2i(0, 0), RAISE), "cella protetta (0,0) immodificabile")
	_check(not s.can_apply(Vector2i(7, 3), DIG) and not s.can_apply(Vector2i(-1, 0), RAISE), "fuori griglia rifiutato")

	# Anti-intrappolamento: solo il rialzo e bloccato, con log dedicato.
	_check(not s.can_apply(c, RAISE, true), "rialzo bloccato se occupato")
	_check(s.can_apply(c, DIG, true), "scavo ammesso anche se occupato")
	_check(s.is_occupied_rejection(c, RAISE, true), "rifiuto classificato come occupazione")
	_check(not s.is_occupied_rejection(Vector2i(0, 0), RAISE, true), "protetta non classificata come occupazione")

	# Ricostruzione: stato conservato a parita di celle, azzerato altrimenti.
	s.apply(c, DIG)
	s.resize(7, 7)
	_check(s.get_state(c) == LOWERED, "resize uguale conserva lo stato")
	s.resize(5, 5)
	_check(s.get_state(Vector2i(2, 2)) == NORMAL and s.cell_count() == 25, "resize diverso azzera lo stato")


func _test_grid_structure() -> void:
	print("grid structure")
	var grid: TerrainGrid = TerrainGridScript.new()
	root.add_child(grid)
	await process_frame
	_check(_cell_children(grid) == 49, "49 celle generate (got %d)" % _cell_children(grid))

	for i in 3:
		grid.rebuild()
	await process_frame
	_check(_cell_children(grid) == 49, "nessun duplicato dopo 3 ricostruzioni (got %d)" % _cell_children(grid))

	# Mappatura mondo -> cella con gli assi Unreal (X avanti = -Z, Y destra = +X).
	_check(grid.cell_at(Vector3.ZERO) == Vector2i(3, 3), "origine -> cella centrale (3,3)")
	_check(grid.cell_at(Vector3(0, 0, -2.4)) == Vector2i(4, 3), "2,4 m avanti -> (4,3)")
	_check(grid.cell_at(Vector3(2.4, 0, 0)) == Vector2i(3, 4), "2,4 m a destra -> (3,4)")
	_check(grid.cell_at(Vector3(-7.2, 0, 7.2)) == Vector2i(0, 0), "angolo dietro-sinistra -> (0,0)")
	_check(grid.cell_at(Vector3(0, 0, -1.2)) == Vector2i(4, 3), "mezza cella arrotonda come RoundToInt")
	_check(not grid.state.is_valid(grid.cell_at(Vector3(0, 0, -9.0))), "oltre il bordo -> fuori griglia")

	# Altezze e posizioni delle celle come in Unreal.
	var center: Vector3 = grid.cell_local_position(Vector2i(4, 3), RAISED)
	_check(center.is_equal_approx(Vector3(0, 0.6, -2.4)), "cella Raised alta 1,2 m (got %s)" % center)
	grid.queue_free()
	await process_frame


func _test_collisions_and_overlap() -> void:
	print("collisions and overlap")
	var grid: TerrainGrid = TerrainGridScript.new()
	root.add_child(grid)
	var player: PlayerCharacter = PlayerScene.instantiate()
	root.add_child(player)
	player.global_position = Vector3(0, 0.88, -2.4)  # sopra la cella (4,3)
	await physics_frame
	await physics_frame

	_check(_ray_hit_y(grid, Vector3(2.4, 5, 0)) < 0.0, "cella Normal senza collisione")
	_check(grid.apply_command_at(Vector3(2.4, 0, 0), RAISE, player), "rialzo cella libera (3,4)")
	await physics_frame
	await physics_frame
	var hit_y := _ray_hit_y(grid, Vector3(2.4, 5, 0))
	_check(absf(hit_y - 1.2) < 0.01, "cella Raised collide a 1,2 m (got %.3f)" % hit_y)
	_check(grid.apply_command_at(Vector3(2.4, 0, 0), DIG, player), "riabbassamento a Normal")
	await physics_frame
	await physics_frame
	_check(_ray_hit_y(grid, Vector3(2.4, 5, 0)) < 0.0, "collisione rimossa tornando Normal")

	_check(not grid.apply_command_at(player.global_position, RAISE, player), "rialzo sotto il personaggio rifiutato")
	_check(grid.cell_state_at(player.global_position) == NORMAL, "stato invariato dopo il rifiuto")
	_check(grid.apply_command_at(player.global_position, DIG, player), "scavo sotto il personaggio ammesso")
	_check(not grid.apply_command_at(Vector3(-7.2, 0, 7.2), DIG, player), "cella protetta rifiutata in scena")
	grid.queue_free()
	player.queue_free()
	await physics_frame


func _test_player_blocked_by_raised_cell() -> void:
	print("player vs raised cell")
	var scene := SmokeTestScene.instantiate()
	root.add_child(scene)
	var player: PlayerCharacter = scene.get_node("Player")
	var grid: TerrainGrid = scene.get_node("TerrainGrid")
	await physics_frame
	_check(grid.apply_command_at(Vector3(2.4, 0, 0), RAISE, player), "rialzo della cella a destra")
	Input.action_press(&"move_right")
	for i in 60:
		await physics_frame
	Input.action_release(&"move_right")
	# Bordo cella a 2,4 - 1,14 = 1,26 m, raggio capsula 0,34 -> fermo a ~0,92 m.
	_check(absf(player.global_position.x - 0.92) < 0.03, "il personaggio si ferma contro la cella Raised (x=%.3f)" % player.global_position.x)

	grid.apply_command_at(Vector3(2.4, 0, 0), DIG, player)
	await physics_frame
	await physics_frame
	Input.action_press(&"move_right")
	for i in 30:
		await physics_frame
	Input.action_release(&"move_right")
	_check(player.global_position.x > 2.0, "attraversa la cella tornata Normal (x=%.3f)" % player.global_position.x)
	scene.queue_free()
	await physics_frame


func _cell_children(grid: Node) -> int:
	var count := 0
	for child in grid.get_children():
		if child is StaticBody3D and not child.is_queued_for_deletion():
			count += 1
	return count


## Altezza del primo impatto di un raggio verticale, -1 se nessuno.
func _ray_hit_y(node: Node3D, from: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 10.0)
	var hit := node.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if hit else -1.0
