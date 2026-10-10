extends SceneTree
## Test del livello 2, la ferrovia (D-066): pianta rettangolare, fascia dei binari
## libera, vagoni sui binari, cortile a cavallo della linea. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/railway_tests.gd

const RunScene := preload("res://scenes/main/railway_run.tscn")
const RAISED := TerrainState.CellState.RAISED
const LOWERED := TerrainState.CellState.LOWERED
const NORMAL := TerrainState.CellState.NORMAL

var _failures := 0
var _scene: Node3D
var _district: RailwayDistrict
var _grid: TerrainGrid
var _path: PathField
var _player: PlayerCharacter
var _director: EnemyDirector
var _run: ArenaRun


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_district = _scene.get_node(^"District")
	_grid = _scene.get_node(^"TerrainGrid")
	_path = _scene.get_node(^"PathField")
	_player = _scene.get_node(^"Player")
	_director = _scene.get_node(^"EnemyDirector")
	_run = _scene.get_node(^"Run")
	_director.spawning = false
	await _frames(5)
	_test_scale()
	_test_track_strip()
	_test_start_courtyard_straddles_tracks()
	_test_wagons()
	_test_features_off_tracks()
	_test_blocks_inside_and_off_tracks()
	_test_determinism()
	await _test_spawn_and_path_in_corridor()
	await _test_markers_include_wagons()
	await _test_hoppers()
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


func _cell_world(cell: Vector2i) -> Vector3:
	var p := _grid.to_global(_grid.cell_local_position(cell, NORMAL))
	return Vector3(p.x, 0.0, p.z)


func _test_scale() -> void:
	print("scale")
	_check(_district.half_x() > _district.half_z() * 2.0, "corridoio lungo in X (%.0f x %.0f m)" % [_district.half_x() * 2.0, _district.half_z() * 2.0])
	_check(_grid.state.width == 51 and _grid.state.height == 133, "griglia 51 x 133 (%d x %d)" % [_grid.state.width, _grid.state.height])
	var grid_x := _grid.state.height * _grid.cell_size_m()
	var grid_z := _grid.state.width * _grid.cell_size_m()
	_check(absf(grid_x - _district.half_x() * 2.0) <= 2.4 and absf(grid_z - _district.half_z() * 2.0) <= 2.4,
		"la griglia copre l'arena (%.1f x %.1f m)" % [grid_x, grid_z])
	_check(is_equal_approx(_path.half_extent, _district.half_x()) and is_equal_approx(_path.half_z(), _district.half_z()),
		"campo di percorso esteso all'arena rettangolare")
	_check(_path.world_columns == 266 and _path.world_rows == 102, "campo di 266 x 102 celle (%d x %d)" % [_path.world_columns, _path.world_rows])
	var cell_world := _cell_world(Vector2i(25, 66))
	_check(Vector2(cell_world.x, cell_world.z).is_zero_approx(), "cella (25,66) all'origine")
	_check(_district.get_node_or_null(^"Tracks") != null, "binari costruiti")
	# F-08 (review del 10 ottobre 2026): corone e tondini delle rovine anche nel livello 2.
	_check(_district.get_node_or_null(^"RuinCrowns") != null and _district.get_node_or_null(^"RuinRebar") != null,
		"corone e tondini delle rovine costruiti")
	_check(int(_district.stats.get("crown_pieces", 0)) > 0 and int(_district.stats.get("rebar", 0)) > 0,
		"corone (%d) e tondini (%d) presenti" % [_district.stats.get("crown_pieces", 0), _district.stats.get("rebar", 0)])


## La fascia dei binari e Normal ovunque, salvo i vagoni; e percorribile e libera da ostacoli.
func _test_track_strip() -> void:
	print("track strip")
	var cells := RailwayDistrict.track_cells(_grid)
	_check(cells.size() == 133 * 3, "fascia di %d celle (3 righe per 133)" % cells.size())
	var wagon_cells := {}
	for f: Dictionary in _district.terrain_features:
		if f.kind != &"wagon":
			continue
		var center := _grid.cell_at(Vector3(f.center.x, 0.0, f.center.y))
		for offset: Vector2i in f.offsets:
			wagon_cells[center + offset] = true
	var normal := true
	var on_strip := true
	for cell in cells:
		if wagon_cells.has(cell):
			continue
		normal = normal and _grid.state.get_state(cell) == NORMAL
		on_strip = on_strip and RailwayDistrict.is_on_tracks(Vector2(_cell_world(cell).x, _cell_world(cell).z))
	_check(normal, "fuori dai vagoni la fascia e tutta Normal")
	_check(on_strip, "ogni cella della fascia sta entro %.1f m da z = 0" % RailwayDistrict.track_half_width())
	_check(not RailwayDistrict.is_on_tracks(Vector2(0.0, 4.0)) and RailwayDistrict.is_on_tracks(Vector2(100.0, -3.5)),
		"is_on_tracks distingue dentro e fuori la fascia")
	# Nessun ostacolo statico (rovine, oggetti) sulla fascia: solo celle della griglia.
	var space := _district.get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = Vector3(_district.half_x() * 2.0 - 2.0, 2.0, RailwayDistrict.track_half_width() * 2.0 - 0.2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# Da 0,2 m in su: il piano del suolo (fino a y = 0) non conta.
	query.transform = Transform3D(Basis(), Vector3(0.0, 1.2, 0.0))
	query.collision_mask = 1
	var foreign := 0
	for hit in space.intersect_shape(query, 128):
		var collider: Node = hit.collider
		if collider.get_parent() != _grid:
			foreign += 1
	_check(foreign == 0, "nessun ostacolo statico sulla fascia dei binari (%d)" % foreign)


func _test_start_courtyard_straddles_tracks() -> void:
	print("start courtyard")
	var start: Dictionary = {}
	for f: Dictionary in _district.terrain_features:
		if f.kind == &"start":
			start = f
	_check(not start.is_empty() and start.center == Vector2.ZERO, "cortile di partenza all'origine")
	if start.is_empty():
		return
	var on_strip := 0
	for offset: Vector2i in start.offsets:
		if absi(offset.x) <= RailwayDistrict.TRACK_HALF_ROWS:
			on_strip += 1
	_check(on_strip == 0, "nessuna cella del cortile sulla fascia dei binari")
	_check(start.offsets.size() == 28 - 4, "anello con i varchi est e ovest larghi quanto la fascia (%d celle)" % start.offsets.size())
	var center := _grid.cell_at(Vector3.ZERO)
	var r: int = start.radius
	_check(_grid.state.get_state(center + Vector2i(r, 0)) == NORMAL and _grid.state.get_state(center + Vector2i(-r, 0)) == NORMAL,
		"i varchi nord e sud restano aperti")
	_check(_grid.state.get_state(center + Vector2i(r, 1)) == RAISED and _grid.state.get_state(center + Vector2i(1, r)) == NORMAL,
		"muro a nord in piedi, varco est aperto anche sulla riga del binario")


func _test_wagons() -> void:
	print("wagons")
	var wagons := _district.terrain_features.filter(func(f: Dictionary) -> bool: return f.kind == &"wagon")
	_check(wagons.size() >= 3, "almeno tre vagoni sui binari (%d)" % wagons.size())
	var on_tracks := true
	var raised := true
	var far := true
	var spaced := true
	var tinted := true
	for i in wagons.size():
		var f: Dictionary = wagons[i]
		on_tracks = on_tracks and RailwayDistrict.is_on_tracks(f.center) and f.offsets.size() == 6
		far = far and absf(f.center.x) >= _district.start_clear_radius + 6.0
		var center := _grid.cell_at(Vector3(f.center.x, 0.0, f.center.y))
		for offset: Vector2i in f.offsets:
			raised = raised and _grid.state.get_state(center + offset) == RAISED
			on_tracks = on_tracks and absi(offset.x) <= RailwayDistrict.TRACK_HALF_ROWS
		tinted = tinted and f.has("tint")
		for j in i:
			spaced = spaced and absf(wagons[j].center.x - f.center.x) >= _district.wagon_spacing - 0.01
	_check(on_tracks, "ogni vagone occupa 6 celle della fascia")
	_check(raised, "le celle dei vagoni sono Raised")
	_check(far, "vagoni lontani dalla partenza")
	_check(spaced, "vagoni ad almeno %.0f m l'uno dall'altro" % _district.wagon_spacing)
	_check(tinted, "i vagoni hanno il colore della ruggine")


## Cortili, depositi normali e trincee stanno fuori dalla fascia; le trincee sono parallele ai binari.
func _test_features_off_tracks() -> void:
	print("features")
	var kinds := {}
	var off := true
	var parallel := true
	for f: Dictionary in _district.terrain_features:
		kinds[f.kind] = kinds.get(f.kind, 0) + 1
		if f.kind == &"wagon" or f.kind == &"start":
			continue
		var center := _grid.cell_at(Vector3(f.center.x, 0.0, f.center.y))
		for offset: Vector2i in f.offsets:
			var p := _cell_world(center + offset)
			off = off and not RailwayDistrict.is_on_tracks(Vector2(p.x, p.z))
			if f.kind == &"trench":
				parallel = parallel and offset.x == 0
	_check(kinds.get(&"deposit", 0) >= 4, "almeno quattro depositi fuori dai binari (%d)" % kinds.get(&"deposit", 0))
	_check(kinds.get(&"trench", 0) >= 2, "almeno due trincee (%d)" % kinds.get(&"trench", 0))
	var courtyards := 0
	for kind: StringName in kinds:
		if kind != &"start" and kind != &"deposit" and kind != &"trench" and kind != &"wagon":
			courtyards += kinds[kind]
	_check(courtyards >= 3, "almeno tre cortili secondari (%d)" % courtyards)
	_check(off, "cortili, depositi e trincee fuori dalla fascia dei binari")
	_check(parallel, "le trincee corrono parallele ai binari")


func _test_blocks_inside_and_off_tracks() -> void:
	print("blocks")
	var ex := _district.half_x()
	var ez := _district.half_z()
	var inside := true
	var off := true
	var low := true
	var blocks := 0
	for child in _district.get_children():
		if not (child is StaticBody3D) or not child.name.begins_with("Block"):
			continue
		blocks += 1
		var body := child as StaticBody3D
		var size := Vector3.ZERO
		for part in body.get_children():
			if part is CollisionShape3D:
				size = ((part as CollisionShape3D).shape as BoxShape3D).size
		low = low and size.y > 0.0 and size.y <= 4.5
		inside = inside and absf(body.position.x) + size.x * 0.5 <= ex and absf(body.position.z) + size.z * 0.5 <= ez
		off = off and absf(body.position.z) - size.z * 0.5 >= RailwayDistrict.track_half_width()
	_check(blocks >= 20, "almeno 20 rovine basse (%d)" % blocks)
	_check(low, "nessuna rovina interna piu alta di 4,5 m")
	_check(inside, "tutte le rovine dentro il rettangolo giocabile")
	_check(off, "nessuna rovina sopra la fascia dei binari")


func _test_determinism() -> void:
	print("determinism")
	var before := _district.terrain_features.duplicate(true)
	var stats_before := _district.stats.duplicate()
	_district.rebuild()
	_check(_district.terrain_features == before, "stessi punti di interesse dopo la ricostruzione")
	_check(_district.stats == stats_before, "stesse statistiche dopo la ricostruzione %s" % [_district.stats])


## Lungo il corridoio il campo segue il giocatore e i nemici trovano la strada;
## al bordo stretto la comparsa resta dentro l'arena.
func _test_spawn_and_path_in_corridor() -> void:
	print("corridor")
	_player.global_position = Vector3(100.0, 0.88, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(4)
	_check(_path.is_inside(_path.cell_of(_player.global_position)), "finestra ricentrata a 100 m lungo i binari")
	_check(_path.cost_at(_player.global_position) == 0.0, "costo zero sul giocatore")
	var inside := true
	var reachable := 0
	for i in 20:
		var spot: Variant = _director._find_spawn_point()
		if spot == null:
			inside = false
			continue
		inside = inside and absf(spot.x) <= _district.half_x() and absf(spot.z) <= _district.half_z()
		if _path.cost_at(spot) < PathField.UNREACHABLE:
			reachable += 1
	_check(inside, "punti di comparsa dentro il rettangolo")
	_check(reachable >= 15, "quasi tutti i punti di comparsa raggiungono il giocatore (%d/20)" % reachable)
	_player.global_position = Vector3(100.0, 0.88, 55.0)
	await _frames(4)
	var clamped := true
	for i in 20:
		var spot: Variant = _director._find_spawn_point()
		clamped = clamped and spot != null and absf(spot.z) <= _district.half_z()
	_check(clamped, "al bordo sud i punti restano dentro i 61 m")
	_player.global_position = Vector3(0.0, 0.88, 0.0)
	_player.velocity = Vector3.ZERO
	await _frames(4)


func _test_markers_include_wagons() -> void:
	print("markers")
	var hud: RunHud = _scene.get_node(^"RunHud")
	await _frames(70)
	var markers := _run.current_markers()
	var deposits := markers.filter(func(m: Dictionary) -> bool: return m.text == "ROTTAMI")
	_check(deposits.size() == 2, "due depositi indicati (%d)" % deposits.size())
	_check(hud.marker_count() == markers.size(), "l'HUD mostra gli stessi indicatori (%d)" % hud.marker_count())
	# Il vagone piu vicino alla partenza e fra i candidati: se e il piu vicino in assoluto, e indicato.
	var nearest := INF
	var nearest_kind: StringName = &""
	for f: Dictionary in _district.terrain_features:
		var marker: Vector2 = f.marker
		if (f.kind == &"deposit" or f.kind == &"wagon") and marker.length() >= ArenaRun.MARKER_MIN_DISTANCE and marker.length() < nearest:
			nearest = marker.length()
			nearest_kind = f.kind
	var first: Dictionary = deposits[0] if not deposits.is_empty() else {}
	_check(not first.is_empty() and absf(first.distance - nearest) < 0.1, "il primo indicato e il piu vicino (%s a %.0f m)" % [nearest_kind, nearest])


## Saltatori (D-066): dal tuning del livello 2, con meno vita, di un altro colore,
## non rallentati dai fossati; nel livello 1 non esistono.
func _test_hoppers() -> void:
	print("hoppers")
	var tuning := _director.tuning
	_check(tuning.hopper_share_max > 0.0 and RunTuning.new().hopper_share_max == 0.0, "quota dei saltatori solo nel tuning della ferrovia")
	var elapsed := _director.elapsed
	_director.elapsed = 0.0
	_check(is_zero_approx(_director.current_hopper_share()), "all'inizio nessun saltatore")
	_director.elapsed = tuning.hopper_start_seconds + tuning.hopper_ramp_seconds * 3.0
	_check(is_equal_approx(_director.current_hopper_share(), tuning.hopper_share_max), "a rampa finita la quota massima (%.0f%%)" % (tuning.hopper_share_max * 100.0))
	_director.elapsed = elapsed
	# Un fossato di 6 celle lungo i binari, a sud della fascia: un rottamatore e un saltatore lo attraversano.
	var center := _grid.cell_at(Vector3.ZERO)
	var cells: Array[Vector2i] = []
	for k in range(-3, 3):
		cells.append(Vector2i(center.x - 5, center.y + 12 + k))
	_grid.set_cell_states(cells, LOWERED)
	_player.global_position = Vector3(0.0, 0.88, 12.0)
	_player.velocity = Vector3.ZERO
	await _frames(3)
	var walker := _director.spawn_at(_cell_world(Vector2i(center.x - 5, center.y + 12)))
	var hopper := _director.spawn_kind(_cell_world(Vector2i(center.x - 5, center.y + 13)), &"hopper")
	_check(hopper.kind == &"hopper" and hopper.ignores_lowered and not walker.ignores_lowered, "il saltatore ignora le celle Lowered")
	_check(hopper.health == maxi(ceili(walker.health * tuning.hopper_health_share), 1), "meno vita (%d contro %d)" % [hopper.health, walker.health])
	_check(hopper.paint_material() != walker.paint_material(), "e di un altro colore")
	await _frames(40)
	var walker_speed := Vector2(walker.velocity.x, walker.velocity.z).length()
	var hopper_speed := Vector2(hopper.velocity.x, hopper.velocity.z).length()
	_check(_grid.cell_state_at(walker.global_position) == LOWERED and _grid.cell_state_at(hopper.global_position) == LOWERED,
		"entrambi ancora nel fossato")
	_check(absf(walker_speed - tuning.enemy_speed * (1.0 - _grid.lowered_speed_penalty())) < 0.4, "il rottamatore nel fossato va a %.1f m/s" % walker_speed)
	_check(absf(hopper_speed - tuning.enemy_speed) < 0.4, "il saltatore nel fossato va a %.1f m/s, piena velocita" % hopper_speed)
	for enemy: Enemy in [walker, hopper]:
		enemy.queue_free()
	_director.enemies.clear()
	_grid.set_cell_states(cells, NORMAL)
