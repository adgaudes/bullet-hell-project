extends SceneTree
## Test dei lampioni (D-058, tappa 2; `docs/DAY_NIGHT_SPEC.md` sezione 7). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/lamp_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")
const NORMAL := TerrainState.CellState.NORMAL
const RAISED := TerrainState.CellState.RAISED
const LOWERED := TerrainState.CellState.LOWERED

var _failures := 0
var _scene: Node3D
var _run: ArenaRun
var _grid: TerrainGrid
var _player: PlayerCharacter
var _companion: Companion
var _director: EnemyDirector
var _lamps: LampField
var _hud: RunHud


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_run = _scene.get_node(^"Run")
	_grid = _scene.get_node(^"TerrainGrid")
	_player = _scene.get_node(^"Player")
	_companion = _scene.get_node(^"Companion")
	_director = _scene.get_node(^"EnemyDirector")
	_lamps = _scene.get_node(^"LampField")
	_hud = _scene.get_node(^"RunHud")
	_director.spawning = false
	_companion.set_physics_process(false)
	(_scene.get_node(^"PlayerWeapon") as AutoWeapon).set_physics_process(false)
	await _frames(5)
	await _test_mode_cycle()
	_test_rules()
	_test_cost()
	_test_light_and_loss()
	await _test_boss_knocks_down()
	_test_map()
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


func _send(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	await _frames(2)


func _cell_world(cell: Vector2i) -> Vector3:
	var p := _grid.to_global(_grid.cell_local_position(cell, NORMAL))
	return Vector3(p.x, 0.0, p.z)


func _place_player_facing(cell: Vector2i) -> void:
	# Il giocatore sta una cella a sud del bersaglio e guarda a nord (-Z).
	var target := _cell_world(cell)
	_player.global_position = target + Vector3(0.0, 0.88, _grid.cell_size_m())
	_player.velocity = Vector3.ZERO
	_player.look_at(target + Vector3(0.0, 0.88, 0.0), Vector3.UP)
	_player._update_terrain_target()


func _clear_all() -> void:
	for cell in _lamps.cells():
		_lamps._remove(cell, &"test")


func _test_mode_cycle() -> void:
	print("mode cycle")
	_place_player_facing(_grid.cell_at(Vector3(0.0, 0.0, -4.8)))
	_player.terrain_tool_mode = TerrainState.ToolMode.DIG
	await _send(&"terrain_mode")
	var second := _player.terrain_tool_mode
	await _send(&"terrain_mode")
	var third := _player.terrain_tool_mode
	var lamp_preview := _grid._preview.get_instance_shader_parameter(&"cell_color") as Color
	await _send(&"terrain_mode")
	_check(second == TerrainState.ToolMode.RAISE and third == TerrainState.ToolMode.LAMP and _player.terrain_tool_mode == TerrainState.ToolMode.DIG,
		"il tasto del modo cicla scava -> rialza -> lampione -> scava")
	_check(lamp_preview.is_equal_approx(TerrainGrid.LAMP_PREVIEW_COLOR.linear_to_srgb()) or lamp_preview.is_equal_approx(TerrainGrid.INVALID_PREVIEW_COLOR.linear_to_srgb()),
		"in modo lampione l'anteprima e bianco caldo o rossa")
	_check(_hud._tool_label.visible == false, "indicatore del tool nascosto fuori dal modo lampione")
	_player.terrain_tool_mode = TerrainState.ToolMode.LAMP
	_player.terrain_mode_changed.emit(_player.terrain_tool_mode)
	_check(_hud._tool_label.visible and _hud._tool_label.text.contains("0/%d" % _lamps.max_count) and _hud._tool_label.text.contains("%d rottami" % _lamps.scrap_cost),
		"in modo lampione l'HUD mostra costo e contatore: %s" % _hud._tool_label.text)
	_player.terrain_tool_mode = TerrainState.ToolMode.DIG
	_player.terrain_mode_changed.emit(_player.terrain_tool_mode)


func _test_rules() -> void:
	print("placement rules")
	_companion.add_capacity(20, 20)
	var normal := _grid.cell_at(Vector3(0.0, 0.0, -4.8))
	var raised := _grid.cell_at(Vector3(4.8, 0.0, -4.8))
	var lowered := _grid.cell_at(Vector3(-4.8, 0.0, -4.8))
	_grid.force_cell_state(normal, NORMAL)
	_grid.force_cell_state(raised, RAISED)
	_grid.force_cell_state(lowered, LOWERED)
	_check(_lamps.can_place(normal) and _lamps.can_place(raised), "si piazza su Normal e in cima a Raised")
	_check(not _lamps.can_place(lowered), "non su Lowered")
	_check(not _lamps.can_place(Vector2i(-1, 0)), "non fuori griglia")
	_companion.global_position = _cell_world(normal) + Vector3(0.0, 0.3, 2.0)
	_check(_lamps.place_at(_cell_world(normal)), "lampione piazzato")
	_check(not _lamps.can_place(normal) and not _lamps.place_at(_cell_world(normal)), "non due sulla stessa cella")
	var top := _cell_world(raised)
	_companion.global_position = top + Vector3(0.0, 0.3, 2.0)
	_check(_lamps.place_at(top) and _lamps.count() == 2, "piazzato anche sul terrapieno")
	var lamp_node: Node3D = _lamps._lamps[raised].node
	_check(lamp_node.global_position.y > 1.0, "sul terrapieno il lampione sta in cima (%.2f m)" % lamp_node.global_position.y)
	# Limite: fino a max_count.
	var x := 2
	while _lamps.count() < _lamps.max_count:
		var cell := _grid.cell_at(Vector3(x * 2.4, 0.0, -9.6))
		_grid.force_cell_state(cell, NORMAL)
		_companion.global_position = _cell_world(cell) + Vector3(0.0, 0.3, 2.0)
		_lamps.place_at(_cell_world(cell))
		x += 1
	var extra := _grid.cell_at(Vector3(-9.6, 0.0, -9.6))
	_grid.force_cell_state(extra, NORMAL)
	_companion.global_position = _cell_world(extra) + Vector3(0.0, 0.3, 2.0)
	_check(_lamps.count() == _lamps.max_count and not _lamps.can_place(extra) and not _lamps.place_at(_cell_world(extra)),
		"al massimo (%d) il settimo e rifiutato" % _lamps.max_count)
	_clear_all()
	_grid.force_cell_state(raised, NORMAL)
	_grid.force_cell_state(lowered, NORMAL)
	_check(_lamps.count() == 0, "pulizia")


func _test_cost() -> void:
	print("cost")
	var cell := _grid.cell_at(Vector3(0.0, 0.0, -4.8))
	var world := _cell_world(cell)
	_companion.global_position = world + Vector3(0.0, 0.3, 2.0)
	_companion.carried = _lamps.scrap_cost - 1
	_companion._refresh_cargo()
	var rejected := [0]
	_player.terrain_tool_rejected.connect(func() -> void: rejected[0] += 1)
	_place_player_facing(cell)
	_player.terrain_tool_mode = TerrainState.ToolMode.LAMP
	_player._update_terrain_target()
	_check(not _lamps.can_afford(world) and _grid._preview.get_instance_shader_parameter(&"cell_color") == TerrainGrid.INVALID_PREVIEW_COLOR.linear_to_srgb(),
		"con %d rottami l'anteprima e rossa" % _companion.carried)
	_player._use_terrain_tool()
	_check(rejected[0] == 1 and _lamps.count() == 0, "senza rottami il comando e rifiutato")
	_companion.carried = _lamps.scrap_cost + 1
	_companion._refresh_cargo()
	_player._update_terrain_target()
	_player._use_terrain_tool()
	_check(_lamps.count() == 1 and _companion.carried == 1, "col tool: lampione piazzato e %d rottami spesi" % _lamps.scrap_cost)
	_player.terrain_tool_mode = TerrainState.ToolMode.DIG
	_clear_all()


func _test_light_and_loss() -> void:
	print("light and loss")
	var cell := _grid.cell_at(Vector3(9.6, 0.0, -9.6))
	_grid.force_cell_state(cell, NORMAL)
	var world := _cell_world(cell)
	_companion.add_capacity(0, 6)
	_companion.global_position = world + Vector3(0.0, 0.3, 2.0)
	_lamps.place_at(world)
	# Via il faro del compagno e la torcia: conta solo il lampione.
	_companion.global_position = world + Vector3(60.0, 0.3, 0.0)
	_player.global_position = world + Vector3(-60.0, 0.88, 0.0)
	var field := _run.light_field
	_check(field.is_lit(world + Vector3(_lamps.light_radius - 0.1, 0.0, 0.0)) and not field.is_lit(world + Vector3(_lamps.light_radius + 0.3, 0.0, 0.0)),
		"il lampione illumina entro %.0f m nel campo logico" % _lamps.light_radius)
	var lost := [0]
	_lamps.lamp_lost.connect(func(_cell: Vector2i, _reason: StringName) -> void: lost[0] += 1)
	_grid.apply_command_at(world, TerrainState.ToolMode.DIG, _player)
	_check(lost[0] == 1 and _lamps.count() == 0 and not field.is_lit(world), "scavare la cella perde il lampione e spegne la luce")
	_grid.force_cell_state(cell, NORMAL)
	_companion.global_position = world + Vector3(0.0, 0.3, 2.0)
	_lamps.place_at(world)
	_grid.force_cell_state(cell, RAISED)
	_check(_lamps.count() == 0, "anche un rialzo (barricata, rialzo) lo perde")
	_grid.force_cell_state(cell, NORMAL)


func _test_boss_knocks_down() -> void:
	print("boss knocks down")
	_player.global_position = Vector3(0.0, 0.88, 0.0)
	_player._invulnerable_left = 600.0
	var cell := _grid.cell_at(Vector3(0.0, 0.0, -14.4))
	_grid.force_cell_state(cell, NORMAL)
	var world := _cell_world(cell)
	_companion.global_position = world + Vector3(0.0, 0.3, 2.0)
	_lamps.place_at(world)
	_run.boss_call_at = _run.elapsed + 0.05
	await _frames(6)
	_run._boss_warning_left = 0.05
	await _frames(6)
	var boss := _run.boss as Demolisher
	_check(boss != null and boss.lamp_field == _lamps, "il Demolitore conosce i lampioni")
	if boss != null:
		boss.global_position = world + Vector3(0.5, Demolisher.boss_spawn_height(), 0.0)
		await _frames(3)
		_check(_lamps.count() == 0, "entrando nel raggio di contatto lo abbatte")
	_companion.global_position = Vector3(-3.0, 0.3, 0.0)


func _test_map() -> void:
	print("map")
	var cell := _grid.cell_at(Vector3(4.8, 0.0, 4.8))
	_grid.force_cell_state(cell, NORMAL)
	var world := _cell_world(cell)
	_companion.add_capacity(0, 6)
	_companion.global_position = world + Vector3(0.0, 0.3, 2.0)
	_lamps.place_at(world)
	var image := _run.build_run_map()
	var found := false
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if absf(c.r - RunMap.LAMP_MARK.r) < 0.02 and absf(c.g - RunMap.LAMP_MARK.g) < 0.02 and absf(c.b - RunMap.LAMP_MARK.b) < 0.02:
				found = true
				break
		if found:
			break
	_check(found, "la mappa di fine run segna il lampione")
	_clear_all()
