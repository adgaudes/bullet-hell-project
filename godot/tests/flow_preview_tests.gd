extends SceneTree
## Test delle impronte dell'orda (FlowPreview). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/flow_preview_tests.gd
##
## Scena sintetica: griglia 21x21 celle (50,4 m), cortile di raggio 4 celle con un
## varco per lato come quello di partenza, bersaglio fermo al centro, campo intero.
## In headless i colori del MultiMesh non si leggono: si verificano posizioni e conteggi.

const GRID_CELLS := 21
const HALF_EXTENT := 25.2
const RING := 4
const WALL_DISTANCE := 9.6
const NORTH := Vector3(0.0, 0.0, -WALL_DISTANCE)
const SOUTH := Vector3(0.0, 0.0, WALL_DISTANCE)
const EAST := Vector3(WALL_DISTANCE, 0.0, 0.0)
const WEST := Vector3(-WALL_DISTANCE, 0.0, 0.0)

var _failures := 0
var _world: Node3D
var _target: Node3D
var _grid: TerrainGrid
var _field: PathField
var _flow: FlowPreview


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_world = Node3D.new()
	root.add_child(_world)
	_target = Node3D.new()
	_target.name = "Target"
	_world.add_child(_target)
	var tuning := TerrainTuning.new()
	tuning.grid_width = GRID_CELLS
	tuning.grid_height = GRID_CELLS
	_grid = TerrainGrid.new()
	_grid.name = "TerrainGrid"
	_grid.tuning = tuning
	_world.add_child(_grid)
	# La griglia prende le dimensioni nel suo _ready, al primo frame.
	await _frames(2)
	_build_courtyard()
	_check(_grid.active_collision_count() == RING * 8 - 4, "cortile costruito (%d celle Raised)" % _grid.active_collision_count())
	_field = PathField.new()
	_field.name = "PathField"
	_field.target = _target
	_field.grid = _grid
	_field.half_extent = HALF_EXTENT
	_field.window_cells = 0
	_world.add_child(_field)
	_flow = FlowPreview.new()
	_flow.name = "FlowPreview"
	_flow.path_field = _field
	_flow.grid = _grid
	_world.add_child(_flow)
	await _frames(20)
	await _test_idle_before_command()
	await _test_trails_after_command()
	_test_marks_follow_field()
	await _test_closing_gate_moves_trails()
	await _test_forced_changes_do_not_trigger()
	await _test_sealed_courtyard()
	await _test_duration_and_retrigger()
	await _test_manual_only()
	_test_mark_cap()
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


func _seconds(seconds: float) -> void:
	await _frames(int(round(seconds * 60.0)))


## Anello di celle Raised con un varco al centro di ogni lato (come ArenaRun).
func _build_courtyard() -> void:
	var center := Vector2i(GRID_CELLS / 2, GRID_CELLS / 2)
	var cells: Array[Vector2i] = []
	for dy in range(-RING, RING + 1):
		for dx in range(-RING, RING + 1):
			if maxi(absi(dx), absi(dy)) == RING and dx != 0 and dy != 0:
				cells.append(center + Vector2i(dx, dy))
	_grid.set_cell_states(cells, TerrainState.CellState.RAISED)


func _command(world: Vector3, mode: TerrainState.ToolMode) -> bool:
	return _grid.apply_command_at(world, mode)


## Impronte dentro la cella terreno che contiene [param world].
func _marks_in_cell(world: Vector3) -> int:
	var cell := _grid.cell_at(world)
	var count := 0
	for mark in _flow.marks:
		if _grid.cell_at(mark) == cell:
			count += 1
	return count


## Impronte dentro il cortile (oltre le mura verso il centro).
func _marks_inside_courtyard() -> int:
	var count := 0
	var inner := WALL_DISTANCE - 1.2
	for mark in _flow.marks:
		if maxf(absf(mark.x), absf(mark.z)) < inner:
			count += 1
	return count


func _marks_on_raised() -> int:
	var count := 0
	for mark in _flow.marks:
		if _grid.cell_state_at(mark) == TerrainState.CellState.RAISED:
			count += 1
	return count


func _multimesh() -> MultiMesh:
	return (_flow.get_node(^"Marks") as MultiMeshInstance3D).multimesh


func _test_idle_before_command() -> void:
	print("idle")
	_check(not _flow.is_showing(), "all'avvio nessuna impronta")
	_check(_flow.mark_count() == 0 and _flow.marks.is_empty(), "nessuna istanza visibile")
	_check(_flow.trace_count == 0, "nessun tracciamento senza comando (%d)" % _flow.trace_count)
	_check(not _flow.is_processing(), "a riposo _process e spento")
	_check(not (_flow.get_node(^"Marks") as MultiMeshInstance3D).visible, "il MultiMesh e nascosto")
	# Il bersaglio che si muove fa ricalcolare il campo, ma senza comando niente impronte.
	_target.global_position = Vector3(1.5, 0.0, 0.0)
	await _frames(20)
	_check(not _flow.is_showing() and _flow.trace_count == 0, "il campo ricalcolato da solo non mostra nulla")
	_target.global_position = Vector3.ZERO
	await _frames(20)


func _test_trails_after_command() -> void:
	print("trails after a tool command")
	_check(_command(Vector3(2.4, 0.0, 2.4), TerrainState.ToolMode.DIG), "scavo applicato dal tool")
	_check(not _flow.is_showing(), "nello stesso istante il campo e ancora vecchio: si aspetta")
	await _frames(20)
	_check(_flow.is_showing(), "dopo il ricalcolo del campo le impronte ci sono")
	_check(_flow.trace_count == 1, "un solo tracciamento (%d)" % _flow.trace_count)
	_check(_flow.mark_count() > 20, "impronte posate (%d)" % _flow.mark_count())
	_check(_flow.mark_count() == _flow.marks.size() and _multimesh().visible_instance_count == _flow.marks.size(),
		"istanze visibili = impronte")
	_check(_flow.mark_count() <= _flow.max_marks, "sotto il tetto (%d <= %d)" % [_flow.mark_count(), _flow.max_marks])
	_check(_flow.trail_count == _flow.sample_count, "una scia per campione (%d)" % _flow.trail_count)
	_check(_flow.reached_trails == _flow.trail_count and _flow.blocked_trails == 0 and not _flow.is_blocked(),
		"cortile aperto: tutte le scie arrivano")
	_check((_flow.get_node(^"Marks") as MultiMeshInstance3D).visible, "il MultiMesh e visibile")
	_check(_multimesh().use_colors and _multimesh().use_custom_data, "colore e dati per istanza attivi")
	print("  info trace_ms=%.3f marks=%d" % [_flow.last_trace_usec / 1000.0, _flow.mark_count()])


func _test_marks_follow_field() -> void:
	print("marks follow the field")
	var monotonic := true
	var walkable := true
	var last_trail := -1
	var last_cost := INF
	var far_start := 0
	for i in _flow.marks.size():
		var mark := _flow.marks[i]
		var cost := _field.cost_at(mark)
		if not _field.is_walkable(mark) or cost == PathField.UNREACHABLE:
			walkable = false
		if _flow.mark_trails[i] != last_trail:
			last_trail = _flow.mark_trails[i]
			if Vector2(mark.x, mark.z).length() > _flow.ring_radius - 4.0:
				far_start += 1
		elif cost > last_cost + 0.001:
			monotonic = false
		last_cost = cost
	_check(walkable, "ogni impronta sta su una cella percorribile e raggiungibile")
	_check(monotonic, "lungo ogni scia il costo verso il giocatore non cresce mai")
	_check(far_start == _flow.trail_count, "ogni scia parte dall'anello (%d)" % far_start)
	_check(_marks_on_raised() == 0, "nessuna impronta su una cella Raised")
	for gate: Array in [["nord", NORTH], ["sud", SOUTH], ["est", EAST], ["ovest", WEST]]:
		var count := _marks_in_cell(gate[1])
		_check(count > 0, "le scie passano dal varco %s (%d impronte)" % [gate[0], count])
	_check(_marks_inside_courtyard() > 8, "le scie entrano nel cortile (%d)" % _marks_inside_courtyard())
	var near := INF
	for mark in _flow.marks:
		near = minf(near, Vector2(mark.x, mark.z).length())
	_check(near >= _flow.stop_radius - 0.9 and near < _flow.stop_radius + 2.0,
		"le scie si fermano attorno al giocatore (%.2f m)" % near)


func _test_closing_gate_moves_trails() -> void:
	print("closing the north gate")
	var east_before := _marks_in_cell(EAST) + _marks_in_cell(WEST)
	await _seconds(1.0)
	_check(_command(NORTH, TerrainState.ToolMode.RAISE), "varco nord chiuso dal tool")
	await _frames(20)
	_check(_flow.is_showing() and _flow.trace_count == 2, "le impronte sono state ritracciate (%d)" % _flow.trace_count)
	_check(_marks_in_cell(NORTH) == 0, "nessuna impronta sul varco chiuso")
	_check(_marks_on_raised() == 0, "nessuna impronta sulle mura")
	_check(_marks_in_cell(SOUTH) > 0 and _marks_in_cell(EAST) > 0 and _marks_in_cell(WEST) > 0,
		"le scie passano dagli altri tre varchi")
	_check(_marks_in_cell(EAST) + _marks_in_cell(WEST) >= east_before, "est e ovest non perdono impronte")
	_check(_flow.reached_trails == _flow.trail_count, "tutte le scie arrivano ancora")
	var north_inside := 0
	for mark in _flow.marks:
		if mark.z < -4.0 and absf(mark.x) < 1.3 and mark.z > -WALL_DISTANCE:
			north_inside += 1
	_check(north_inside == 0, "nessuna scia scende piu da nord dentro il cortile")
	# Il comando ha fatto ripartire il tempo: dopo 2,5 s (3,5 dal primo) si vedono ancora.
	await _seconds(2.5)
	_check(_flow.is_showing(), "il nuovo comando ha fatto ripartire la durata")
	await _seconds(0.8)
	_check(not _flow.is_showing(), "poi spariscono")


func _test_forced_changes_do_not_trigger() -> void:
	print("boss changes")
	var traces := _flow.trace_count
	var center := Vector2i(GRID_CELLS / 2, GRID_CELLS / 2)
	_check(_grid.force_cell_state(center + Vector2i(RING, 2), TerrainState.CellState.NORMAL), "il boss smonta un muro")
	await _frames(30)
	_check(not _flow.is_showing() and _flow.trace_count == traces, "force_cell_state non mostra le impronte")
	_check(_grid.force_cell_state(center + Vector2i(RING, 2), TerrainState.CellState.RAISED), "il boss alza una barricata")
	await _frames(30)
	_check(not _flow.is_showing() and _flow.trace_count == traces, "nemmeno la barricata")


func _test_sealed_courtyard() -> void:
	print("sealed courtyard")
	var center := Vector2i(GRID_CELLS / 2, GRID_CELLS / 2)
	_grid.force_cell_state(_grid.cell_at(EAST), TerrainState.CellState.RAISED)
	_grid.force_cell_state(_grid.cell_at(WEST), TerrainState.CellState.RAISED)
	_check(_command(SOUTH, TerrainState.ToolMode.RAISE), "ultimo varco chiuso dal tool")
	await _frames(20)
	_check(_flow.is_showing(), "le impronte compaiono anche senza strada")
	_check(_field.cost_at(Vector3(0.0, 0.0, -15.0)) == PathField.UNREACHABLE, "il campo non ha strada da fuori")
	_check(_flow.is_blocked(), "esito: orda chiusa fuori")
	_check(_flow.reached_trails == 0 and _flow.blocked_trails == _flow.trail_count and _flow.trail_count > 0,
		"tutte le scie sono bloccate (%d di %d)" % [_flow.blocked_trails, _flow.trail_count])
	_check(_marks_inside_courtyard() == 0, "nessuna impronta dentro il cortile")
	_check(_marks_on_raised() == 0, "nessuna impronta sulle mura")
	var bars := 0
	var bars_at_wall := true
	var closer := true
	var last_trail := -1
	var last_distance := INF
	for i in _flow.marks.size():
		var mark := _flow.marks[i]
		var distance := Vector2(mark.x, mark.z).length()
		if _flow.mark_trails[i] == last_trail and distance > last_distance + 0.001:
			closer = false
		last_trail = _flow.mark_trails[i]
		last_distance = distance
		if _flow.mark_kinds[i] == FlowPreview.KIND_BLOCKED:
			bars += 1
			# La sbarra sta nella cella del campo che tocca il muro.
			if maxf(absf(mark.x), absf(mark.z)) > WALL_DISTANCE + 1.2 + 1.3:
				bars_at_wall = false
	_check(closer, "le scie puntano dritte al giocatore, come i nemici")
	_check(bars > 0 and bars <= _flow.trail_count, "sbarre di strada chiusa (%d)" % bars)
	_check(bars_at_wall, "ogni sbarra e contro le mura")
	_check(center == _grid.cell_at(Vector3.ZERO), "il giocatore e al centro della griglia")


func _test_duration_and_retrigger() -> void:
	print("duration")
	await _seconds(_flow.duration + 0.3)
	_check(not _flow.is_showing(), "dopo %.1f s le impronte spariscono" % _flow.duration)
	_check(_flow.mark_count() == 0 and _multimesh().visible_instance_count == 0, "nessuna istanza visibile")
	_check(not (_flow.get_node(^"Marks") as MultiMeshInstance3D).visible, "il MultiMesh e nascosto")
	_check(not _flow.is_processing(), "_process torna spento")
	_flow.show_now()
	_check(_flow.is_showing() and _flow.mark_count() > 0, "show_now() le mostra subito")
	await _seconds(2.0)
	_flow.show_now()
	await _seconds(2.0)
	_check(_flow.is_showing(), "show_now() ripetuto fa ripartire la durata")
	await _seconds(1.3)
	_check(not _flow.is_showing(), "poi spariscono")
	# Mentre sono visibili seguono i ricalcoli del campo senza allungare la durata.
	_flow.show_now()
	var traces := _flow.trace_count
	_target.global_position = Vector3(2.5, 0.0, 0.0)
	await _seconds(1.0)
	_check(_flow.trace_count == traces + 1, "un ritracciamento per ricalcolo del campo (%d)" % (_flow.trace_count - traces))
	await _seconds(2.3)
	_check(not _flow.is_showing(), "il ritracciamento non allunga la durata")
	_target.global_position = Vector3.ZERO
	await _frames(20)
	_flow.show_now()
	_flow.hide_now()
	_check(not _flow.is_showing() and _flow.mark_count() == 0, "hide_now() le nasconde subito")


func _test_manual_only() -> void:
	print("manual only")
	_flow.auto_show_on_terrain_change = false
	_check(_command(NORTH, TerrainState.ToolMode.DIG), "varco nord riaperto dal tool")
	await _frames(30)
	_check(not _flow.is_showing(), "con auto_show spento il comando non mostra nulla")
	_flow.show_now()
	_check(_flow.is_showing() and not _flow.is_blocked(), "show_now() funziona comunque e trova la strada")
	_check(_marks_in_cell(NORTH) > 0, "tutte le scie passano dal varco riaperto (%d impronte)" % _marks_in_cell(NORTH))
	_check(_marks_in_cell(SOUTH) == 0, "nessuna dal varco sud chiuso")
	_flow.hide_now()
	_flow.auto_show_on_terrain_change = true


func _test_mark_cap() -> void:
	print("mark cap")
	var samples := _flow.sample_count
	var spacing := _flow.spacing
	_flow.sample_count = 48
	_flow.spacing = 0.4
	_flow.show_now()
	_check(_flow.marks.size() <= _flow.max_marks, "48 scie fitte: sotto il tetto (%d <= %d)" % [_flow.marks.size(), _flow.max_marks])
	_check(_flow.marks.size() > _flow.max_marks / 2, "il tetto e davvero raggiunto o quasi (%d)" % _flow.marks.size())
	_check(_multimesh().instance_count == _flow.max_marks, "il MultiMesh non cresce")
	_flow.hide_now()
	_flow.sample_count = samples
	_flow.spacing = spacing
