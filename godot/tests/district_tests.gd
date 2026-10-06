extends SceneTree
## Test dell'arena grande (D-042): quartiere in rovina con griglia 85x85 e punti
## di interesse del terreno. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/district_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")
const RAISED := TerrainState.CellState.RAISED
const LOWERED := TerrainState.CellState.LOWERED
const NORMAL := TerrainState.CellState.NORMAL

var _failures := 0
var _scene: Node3D
var _district: RuinsDistrict
var _grid: TerrainGrid
var _path: PathField
var _player: PlayerCharacter
var _director: EnemyDirector


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_district = _scene.get_node(^"District")
	_grid = _scene.get_node(^"TerrainGrid")
	_path = _scene.get_node(^"PathField")
	_player = _scene.get_node(^"Player")
	_director = _scene.get_node(^"EnemyDirector")
	_director.spawning = false
	await _frames(5)
	_test_scale()
	_test_features()
	_test_features_applied_to_grid()
	_test_determinism()
	_test_blocks_are_low_and_inside()
	_test_start_area_is_clear()
	await _test_far_path_and_spawn()
	await _test_window_follows_player()
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


func _test_scale() -> void:
	print("scale")
	_check(_district.play_half_extent >= 100.0, "area giocabile di almeno 200 m di lato (%.0f)" % (_district.play_half_extent * 2.0))
	var extent_m := _grid.width_extent_cm() / 100.0
	_check(_grid.state.width == 85 and _grid.state.height == 85, "griglia 85x85")
	_check(absf(extent_m - _district.play_half_extent * 2.0) <= 2.4, "la griglia copre l'arena (%.1f m)" % extent_m)
	_check(_grid.presented_cell_count() == _grid.state.cell_count(), "tutte le %d celle presentate" % _grid.state.cell_count())
	var batches := 0
	for child in _grid.get_children():
		if child is MultiMeshInstance3D:
			batches += 1
	_check(batches == 3, "tre lotti MultiMesh, uno per stato")
	_check(is_equal_approx(_path.half_extent, _district.play_half_extent), "campo di percorso esteso all'arena")
	_check(is_equal_approx(_grid.plaza_radius, _district.plaza_radius()), "raggio della piazza condiviso fra suolo e celle")


func _test_features() -> void:
	print("features")
	var features := _district.terrain_features
	var kinds := {}
	for f: Dictionary in features:
		kinds[f.kind] = kinds.get(f.kind, 0) + 1
	_check(kinds.get(&"start", 0) == 1, "un cortile di partenza")
	var courtyards := features.filter(func(f: Dictionary) -> bool: return f.state == RAISED and not f.gates.is_empty())
	_check(courtyards.size() >= 4, "almeno quattro cortili con varchi (%d)" % courtyards.size())
	_check(kinds.get(&"deposit", 0) >= 6, "almeno sei depositi di rottami (%d)" % kinds.get(&"deposit", 0))
	_check(kinds.get(&"trench", 0) >= 2, "almeno due trincee (%d)" % kinds.get(&"trench", 0))
	var start: Dictionary = features[0]
	_check(start.kind == &"start" and start.center == Vector2.ZERO and start.offsets.size() == 28 and start.gates.size() == 4,
		"partenza: 28 celle di mura e quattro varchi all'origine")

	var far_apart := true
	var away_from_start := true
	var variants := {}
	for i in courtyards.size():
		var a: Dictionary = courtyards[i]
		if a.kind != &"start":
			variants[a.kind] = true
			away_from_start = away_from_start and a.center.length() >= _district.start_clear_radius
		for j in range(i + 1, courtyards.size()):
			var b: Dictionary = courtyards[j]
			if a.kind != &"start" and b.kind != &"start" and a.center.distance_to(b.center) < 40.0:
				far_apart = false
	_check(far_apart, "cortili secondari ad almeno 40 m l'uno dall'altro")
	_check(away_from_start, "cortili secondari fuori dall'area di partenza")
	_check(variants.size() >= 3, "almeno tre varianti di cortile %s" % [variants.keys()])

	var all_valid := true
	var snapped := true
	for f: Dictionary in features:
		snapped = snapped and f.center.is_equal_approx(RuinsDistrict.snap_to_cell(f.center))
		var center := _grid.cell_at(Vector3(f.center.x, 0.0, f.center.y))
		for offset: Vector2i in f.offsets:
			all_valid = all_valid and _grid.state.is_valid(center + offset)
	_check(snapped, "centri dei punti di interesse al centro di una cella")
	_check(all_valid, "tutte le celle dei punti di interesse sono dentro la griglia")


func _test_features_applied_to_grid() -> void:
	print("grid layout")
	var expected := {}
	for f: Dictionary in _district.terrain_features:
		var center := _grid.cell_at(Vector3(f.center.x, 0.0, f.center.y))
		for offset: Vector2i in f.offsets:
			expected[center + offset] = f.state
	var matching := true
	for cell: Vector2i in expected:
		matching = matching and _grid.state.get_state(cell) == expected[cell]
	_check(matching, "ogni cella dei punti di interesse ha lo stato previsto (%d celle)" % expected.size())
	var changed := 0
	for y in _grid.state.height:
		for x in _grid.state.width:
			if _grid.state.get_state(Vector2i(x, y)) != NORMAL:
				changed += 1
	_check(changed == expected.size(), "nessun'altra cella modificata (%d)" % changed)
	_check(_grid.active_collision_count() == expected.values().count(RAISED), "una collisione attiva per cella Raised (%d)" % _grid.active_collision_count())
	# Il centro del cortile di partenza e sulla cella centrale, come nell'arena piccola.
	var cell_world := _grid.to_global(_grid.cell_local_position(Vector2i(42, 42), NORMAL))
	_check(Vector2(cell_world.x, cell_world.z).is_zero_approx(), "cella (42,42) all'origine")


func _test_determinism() -> void:
	print("determinism")
	var before := _district.terrain_features.duplicate(true)
	var stats_before: Dictionary = _district.stats.duplicate()
	_district.rebuild()
	_check(_district.terrain_features == before, "stessi punti di interesse dopo la ricostruzione")
	_check(_district.stats == stats_before, "stesse statistiche dopo la ricostruzione %s" % [_district.stats])
	var other := RuinsDistrict.new()
	other.layout_seed = _district.layout_seed + 1
	other.grass_tufts = 0
	other.flowers = 0
	root.add_child(other)
	_check(other.terrain_features != before and other.terrain_features.size() >= 10, "un altro seme produce un altro quartiere")
	other.queue_free()


func _test_blocks_are_low_and_inside() -> void:
	print("blocks")
	var e := _district.play_half_extent
	var low := true
	var inside := true
	var blocks := 0
	for child in _district.get_children():
		if not (child is StaticBody3D) or not child.name.begins_with("Block"):
			continue
		blocks += 1
		var body := child as StaticBody3D
		var mesh: BoxMesh = (body.get_child(0) as MeshInstance3D).mesh
		low = low and mesh.size.y <= 4.5
		inside = inside and absf(body.position.x) + mesh.size.x * 0.5 <= e and absf(body.position.z) + mesh.size.z * 0.5 <= e
	_check(blocks >= 20, "almeno 20 rovine basse dentro il perimetro (%d)" % blocks)
	_check(low, "nessuna rovina interna piu alta di 4,5 m: non coprono il giocatore")
	_check(inside, "tutte le rovine interne dentro l'area giocabile")


func _test_start_area_is_clear() -> void:
	print("start area")
	var space := _district.get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	var r := _district.start_clear_radius - 0.5
	shape.size = Vector3(r * 2.0, 2.0, r * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), Vector3(0.0, 1.0, 0.0))
	query.collision_mask = 1
	var foreign := 0
	for hit in space.intersect_shape(query, 64):
		var collider: Node = hit.collider
		if collider.get_parent() != _grid:
			foreign += 1
	_check(foreign == 0, "nessun ostacolo statico nell'area di partenza (%d)" % foreign)


## Un nemico nato sull'anello attorno al giocatore trova la strada; il campo
## copre il giocatore ovunque si trovi.
func _test_far_path_and_spawn() -> void:
	print("path and spawn")
	var spot: Variant = _director._find_spawn_point()
	_check(spot != null, "punto di comparsa trovato sull'anello")
	if spot != null:
		var distance := Vector2(spot.x, spot.z).length()
		_check(distance >= _director.tuning.spawn_ring_min - 0.01 and distance <= _director.tuning.spawn_ring_max + 1.5,
			"a %.1f m dal giocatore" % distance)
		_check(_path.cost_at(spot) < PathField.UNREACHABLE, "il giocatore e raggiungibile da li")
	var enemy := _director.spawn_at(Vector3(0.0, 0.0, -14.0))
	await _frames(90)
	_check(enemy.global_position.z > -11.5, "il rottamatore avanza verso il cortile (z=%.1f)" % enemy.global_position.z)
	enemy.queue_free()
	_director.enemies.clear()


func _test_window_follows_player() -> void:
	print("window")
	var recenters := _path.recenter_count
	_player.global_position = Vector3(70.0, 0.88, 60.0)
	_player.velocity = Vector3.ZERO
	await _frames(3)
	_check(_path.recenter_count > recenters, "finestra ricentrata dopo il salto a 70,60")
	var cell := _path.cell_of(_player.global_position)
	_check(_path.is_inside(cell), "il giocatore e dentro la finestra")
	_check(_path.cost_at(_player.global_position) == 0.0, "costo zero sulla cella del giocatore")
	_player.global_position = Vector3(0.0, 0.88, 0.0)
	await _frames(3)
