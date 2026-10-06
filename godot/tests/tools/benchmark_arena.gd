extends SceneTree
## Benchmark dell'arena grande (D-042), non e una suite. Misura costruzione e
## costo per frame con l'orda al massimo. In --headless misura solo CPU
## (script e fisica); con finestra anche il frame completo e le draw call:
##   godot_console --path godot --resolution 1280x800 --script res://tests/tools/benchmark_arena.gd -- --enemies=70
## `--enemies=N` (default: max_alive del tuning) per isolare il costo dell'orda.
## Marker: PROTOTYPE01_ARENA_BENCH ...

const WARMUP_FRAMES := 120
const MEASURE_FRAMES := 600


func _initialize() -> void:
	var start := Time.get_ticks_usec()
	var scene: Node3D = preload("res://scenes/main/arena_run.tscn").instantiate()
	root.add_child(scene)
	var instantiate_usec := Time.get_ticks_usec() - start
	var district: RuinsDistrict = scene.get_node(^"District")
	var grid: TerrainGrid = scene.get_node(^"TerrainGrid")
	var director: EnemyDirector = scene.get_node(^"EnemyDirector")
	var path: PathField = scene.get_node(^"PathField")
	var player: PlayerCharacter = scene.get_node(^"Player")
	var tuning: RunTuning = director.tuning
	var enemy_target := tuning.max_alive
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemies="):
			enemy_target = arg.trim_prefix("--enemies=").to_int()
	director.spawning = false
	# Il campo di percorso legge gli ostacoli dopo due passi fisici.
	for i in 5:
		await physics_frame

	var t := Time.get_ticks_usec()
	district.rebuild()
	var arena_usec := Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	grid.rebuild()
	var grid_usec := Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var cells: Array[Vector2i] = []
	for feature: Dictionary in district.terrain_features:
		var center := grid.cell_at(Vector3(feature.center.x, 0.0, feature.center.y))
		for offset: Vector2i in feature.offsets:
			cells.append(center + offset)
	grid.set_cell_states(cells, TerrainState.CellState.RAISED)
	var layout_usec := Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	path.scan_static_obstacles()
	var scan_usec := Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	path.solve()
	var solve_usec := Time.get_ticks_usec() - t

	print("PROTOTYPE01_ARENA_BENCH build instantiate_ms=%.1f arena_ms=%.1f grid_ms=%.1f layout_ms=%.1f (%d celle) scan_ms=%.1f (%d chunk) solve_ms=%.2f"
		% [instantiate_usec / 1000.0, arena_usec / 1000.0, grid_usec / 1000.0, layout_usec / 1000.0, cells.size(),
			scan_usec / 1000.0, path.chunks_scanned, solve_usec / 1000.0])
	print("PROTOTYPE01_ARENA_BENCH content cells=%d collisions=%d features=%d blocks=%d props=%d trees=%d tufts=%d flowers=%d"
		% [grid.state.cell_count(), grid.active_collision_count(), district.terrain_features.size(),
			district.stats.blocks, district.stats.props, district.stats.trees, district.stats.tufts, district.stats.flowers])

	# Orda piena: tutti i nemici vivi, giocatore invulnerabile.
	for i in WARMUP_FRAMES:
		await physics_frame
	while director.enemies.size() < enemy_target:
		var spot: Variant = director._find_spawn_point()
		if spot == null:
			break
		director.spawn_at(spot)
	# Costo CPU diretto di un passo del direttore (percorsi, separazione, move_and_slide)
	# e di un passo dei frammenti: indipendente dal loop e dal vsync.
	var step := 1.0 / Engine.physics_ticks_per_second
	director.set_physics_process(false)
	var t0 := Time.get_ticks_usec()
	for i in 240:
		director._physics_process(step)
	var director_ms := (Time.get_ticks_usec() - t0) / 240000.0
	director.set_physics_process(true)
	var weapon: AutoWeapon = scene.get_node(^"PlayerWeapon")
	weapon.set_physics_process(false)
	t0 = Time.get_ticks_usec()
	for i in 240:
		weapon._physics_process(step)
	var weapon_ms := (Time.get_ticks_usec() - t0) / 240000.0
	weapon.set_physics_process(true)
	print("PROTOTYPE01_ARENA_BENCH step enemies=%d director_ms=%.2f weapon_ms=%.2f solve_ms=%.2f"
		% [director.enemies.size(), director_ms, weapon_ms, path.last_solve_usec / 1000.0])
	var physics_total := 0.0
	var process_total := 0.0
	var frame_total := 0.0
	var frames := 0
	var last := Time.get_ticks_usec()
	for i in MEASURE_FRAMES:
		player.set_max_health(5)
		player._invulnerable_left = 1.0
		await process_frame
		var now := Time.get_ticks_usec()
		frame_total += (now - last) / 1000.0
		last = now
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		process_total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		frames += 1
	var headless := DisplayServer.get_name() == "headless"
	print("PROTOTYPE01_ARENA_BENCH frame headless=%s enemies=%d frames=%d avg_frame_ms=%.2f avg_physics_ms=%.2f avg_process_ms=%.2f fps=%.0f"
		% [headless, director.enemies.size(), frames, frame_total / frames, physics_total / frames, process_total / frames,
			Performance.get_monitor(Performance.TIME_FPS)])
	if not headless:
		print("PROTOTYPE01_ARENA_BENCH render draw_calls=%d primitives=%d objects=%d video_mem_mb=%.0f"
			% [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	print("PROTOTYPE01_ARENA_BENCH path solve_ms=%.2f recenter_ms=%.2f chunks=%d leashed=%d"
		% [path.last_solve_usec / 1000.0, path.last_recenter_usec / 1000.0, path.chunks_scanned, director.leashed])
	quit()
