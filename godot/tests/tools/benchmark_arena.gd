extends SceneTree
## Benchmark dell'arena grande (D-042), non e una suite. Misura costruzione e
## costo per frame con l'orda al massimo. In --headless misura solo CPU
## (script e fisica); con finestra anche il frame completo e le draw call:
##   godot_console --path godot --resolution 1280x800 --script res://tests/tools/benchmark_arena.gd -- --enemies=70
## `--enemies=N` (default: max_alive del tuning) per isolare il costo dell'orda; `--level=railway` misura il livello 2.
## `--no-motion` spegne il movimento procedurale degli attori (ActorMotion) per confronto;
## `--motion-ab` misura nello stesso processo il passo del direttore con e senza (riga `motion_ab`).
## `--preset=deck|low|medium|high|max` (restyling 2026-10-11) applica il preset grafico prima di
## costruire l'arena; il limite di fps viene tolto, cosi il frame misurato e il costo reale.
## Sul rilievo continuo (D-085) misura anche la base (`apply_base_relief`), 100 pennellate
## casuali del giocatore e l'aggiornamento dei chunk di collisione (riga `terrain`); poi una
## corsa di 6 s con il costo massimo del ricentro del campo di percorso (riga `run`).
## Marker: PROTOTYPE01_ARENA_BENCH ...

const WARMUP_FRAMES := 120
const MEASURE_FRAMES := 600
const PRESET_ARGS := {"deck": GameSettingsService.Preset.STEAM_DECK, "low": GameSettingsService.Preset.LOW,
	"medium": GameSettingsService.Preset.MEDIUM, "high": GameSettingsService.Preset.HIGH, "max": GameSettingsService.Preset.MAX}


## Bivi del caso peggiore per le armi di classe (i piu pesanti: piu colpi, piu oggetti a terra).
const HEAVY_PICKS := {
	&"nailgun": [&"a", &"b"], &"seismic_stake": [&"b", &"a"],
	&"scrap_launcher": [&"a", &"a"], &"dig_charge": [&"a", &"b"],
	&"welder": [&"a", &"a"], &"crane_magnet": [&"b", &"a"],
	&"scythe": [&"a", &"b"], &"bramble": [&"a", &"a"],
}


## Caso peggiore delle armi (D-092, budget 1,0 ms per passo), per la classe di `--class=`:
## cinque slot pieni al livello 5, kit della classe coi bivi di HEAVY_PICKS, Ruspa a dischi
## (Lama fusa con l'Ariete), Martello e Betoniera; attive appena usate; si misura il passo di
## tutte le armi del loadout e della coda delle scritture (riga `weapons`). Poi la classe si
## fonde e si rimisura (riga `weapons_fused`).
func _bench_loadout(scene: Node, step: float) -> void:
	var run: ArenaRun = scene.get_node(^"Run")
	var loadout := run.loadout
	var kit := ClassCatalog.start_weapons(run.class_id)
	if loadout == null or kit.size() < 2:
		return
	for id in kit:
		var picks: Array = HEAVY_PICKS.get(id, [&"a", &"a"])
		loadout.level_up(id)
		loadout.choose_branch(id, picks[0])
		loadout.level_up(id)
		loadout.choose_branch(id, picks[1])
	for id in [&"site_blade", &"jackhammer", &"ram"]:
		loadout.add(id)
		_max_out(loadout, id)
	loadout.fuse(&"site_blade")
	loadout.add(&"cement_mixer")
	_max_out(loadout, &"cement_mixer")
	# L'orda nasce oltre la portata: per il caso peggiore 20 nemici robusti entro 6 m.
	var player: Node3D = scene.get_node(^"Player")
	for i in 20:
		var angle := TAU * i / 20.0
		var enemy := run.director.spawn_at(player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * (3.0 + 3.0 * (i % 2)))
		enemy.health = 1000
		enemy.max_health = 1000
	loadout.trigger_active(0)
	loadout.trigger_active(1)
	for i in 120:
		await physics_frame
	var weapons_ms := _time_weapons(run, step)
	var auto_id := kit[0]
	var fused_ms := -1.0
	if loadout.fuse(auto_id):
		# Il Fortino alza la prima torretta dopo 10 s.
		for i in int(12.0 * Engine.physics_ticks_per_second):
			await physics_frame
		fused_ms = _time_weapons(run, step)
	print("PROTOTYPE01_ARENA_BENCH weapons_fused class=%s worst_ms=%.3f slots=%s"
		% [run.class_id, fused_ms, ",".join(PackedStringArray(loadout.all_ids()))])
	_bench_writes(run, player, step, weapons_ms)


## Passo medio (ms) di tutte le armi del loadout e della coda delle scritture, su 240 passi.
func _time_weapons(run: ArenaRun, step: float) -> float:
	var loadout := run.loadout
	# Anche i figli che hanno un passo proprio: torrette del Fortino, rovi del Roveto e della Falciarovi.
	var nodes: Array[Node] = []
	for weapon: Node in loadout.autos() + loadout.actives():
		nodes.append(weapon)
		for child in weapon.find_children("*", "", true, false):
			if child.is_physics_processing():
				nodes.append(child)
	nodes.append(run.write_queue)
	for node in nodes:
		node.set_physics_process(false)
	var t0 := Time.get_ticks_usec()
	for i in 240:
		for node in nodes:
			node._physics_process(step)
	var ms := (Time.get_ticks_usec() - t0) / 240000.0
	for node in nodes:
		node.set_physics_process(true)
	return ms


## Anello che sale e indurimento della Betoniera, poi la riga `weapons`.
func _bench_writes(run: ArenaRun, player: Node3D, step: float, weapons_ms: float) -> void:
	var loadout := run.loadout
	var t0 := 0
	# Un anello che sale: una pennellata del picchetto (con collisione e segnale) per passo.
	var queue := run.write_queue
	queue.set_physics_process(false)
	var center := player.global_position + Vector3(0.0, 0.0, -10.0)
	for i in 40:
		var angle := TAU * i / 40.0
		var p := center + Vector3(cos(angle), 0.0, sin(angle)) * 3.0
		queue.push_level(p, 0.9, run.terrain_field.base_height_at(p) + 1.2)
	var jobs := queue.pending()
	t0 = Time.get_ticks_usec()
	while queue.pending() > 0:
		queue._physics_process(step)
	var raise_ms := (Time.get_ticks_usec() - t0) / 1000.0 / maxf(jobs, 1.0)
	# Indurimento della Betoniera (review I5): la pittura dello strato e sincrona su Terrain3D
	# (con finestra); le sue pennellate passano poi dalla coda, misurata sopra.
	var mixer := loadout.weapon(&"cement_mixer") as CementMixer
	var harden_ms := -1.0
	if mixer != null:
		t0 = Time.get_ticks_usec()
		mixer._harden({center = center + Vector3(6.0, 0.0, 0.0), radius = 3.0, stuck = []})
		harden_ms = (Time.get_ticks_usec() - t0) / 1000.0
		queue.clear()
	queue.set_physics_process(true)
	print("PROTOTYPE01_ARENA_BENCH weapons_harden ms=%.3f (una volta per pozza)" % harden_ms)
	print("PROTOTYPE01_ARENA_BENCH weapons class=%s worst_ms=%.3f ring_write_ms=%.3f"
		% [run.class_id, weapons_ms, raise_ms])


static func _max_out(loadout: WeaponLoadout, id: StringName) -> void:
	while loadout.level_of(id) > 0 and loadout.level_of(id) < WeaponCatalog.MAX_LEVEL:
		if loadout.needs_branch(id):
			loadout.choose_branch(id, &"a")
		else:
			loadout.level_up(id)


func _initialize() -> void:
	var preset_name := "high"
	var settings := root.get_node_or_null("GameSettings") as GameSettingsService
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preset=") and settings != null:
			preset_name = arg.trim_prefix("--preset=")
			settings.set_preset(PRESET_ARGS.get(preset_name, GameSettingsService.Preset.HIGH))
	# Il limite di fps (default 60) coprirebbe il costo reale del frame.
	Engine.max_fps = 0
	var level_id := &"district"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			level_id = StringName(arg.trim_prefix("--level="))
	var start := Time.get_ticks_usec()
	var scene: Node3D = (load(LevelCatalog.scene_of(level_id)) as PackedScene).instantiate()
	root.add_child(scene)
	var instantiate_usec := Time.get_ticks_usec() - start
	var district: RuinsDistrict = scene.get_node(^"District")
	var field: TerrainField = scene.get_node_or_null(^"TerrainField")
	var director: EnemyDirector = scene.get_node(^"EnemyDirector")
	var path: PathField = scene.get_node(^"PathField")
	var player: PlayerCharacter = scene.get_node(^"Player")
	var tuning: RunTuning = director.tuning
	var enemy_target := tuning.max_alive
	var night := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemies="):
			enemy_target = arg.trim_prefix("--enemies=").to_int()
		elif arg == "--no-motion":
			# Senza il movimento procedurale degli attori: misura quanto costa.
			ActorMotion.enabled = false
		elif arg == "--night":
			# Misura di notte: il ciclo e portato oltre il tramonto prima dell'orda.
			night = true
	director.spawning = false
	# Il campo di percorso legge gli ostacoli dopo due passi fisici.
	for i in 5:
		await physics_frame
	# La scena riapplica le impostazioni (e il limite di fps) al suo avvio: si toglie di nuovo.
	Engine.max_fps = 0

	var t := Time.get_ticks_usec()
	district.rebuild()
	var arena_usec := Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	var grid_usec := 0
	var layout_usec := 0
	if field != null:
		# Base del rilievo ricalcolata (come senza `base.bin`), poi le pennellate del quartiere.
		district.apply_base_relief(field)
		grid_usec = Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		district.apply_strokes(field)
		district.settle_on_relief()
		layout_usec = Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	path.scan_static_obstacles()
	var scan_usec := Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	path.solve()
	var solve_usec := Time.get_ticks_usec() - t

	print("PROTOTYPE01_ARENA_BENCH build instantiate_ms=%.1f arena_ms=%.1f base_ms=%.1f layout_ms=%.1f scan_ms=%.1f (%d chunk) solve_ms=%.2f"
		% [instantiate_usec / 1000.0, arena_usec / 1000.0, grid_usec / 1000.0, layout_usec / 1000.0,
			scan_usec / 1000.0, path.chunks_scanned, solve_usec / 1000.0])
	if field != null:
		var collision: TerrainCollision = field.get_node(^"Collision")
		print("PROTOTYPE01_ARENA_BENCH content vertices=%d chunks=%d strokes=%d blocks=%d props=%d trees=%d tufts=%d flowers=%d"
			% [field.resolution_x * field.resolution_z, collision.chunk_count(), district.terrain_strokes.size(),
				district.stats.blocks, district.stats.props, district.stats.trees, district.stats.tufts, district.stats.flowers])
		# Cento pennellate casuali del giocatore (raggio del tuning) fuori dalle aree protette.
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var brush_total := 0
		var brush_max := 0
		var refreshed_before := collision.refreshed_count()
		for i in 100:
			var at := Vector3(rng.randf_range(-80.0, 80.0), 0.0, rng.randf_range(-80.0, 80.0))
			var b0 := Time.get_ticks_usec()
			field.player_sculpt(at, field.tuning.brush_radius_m, -0.03 if i % 2 == 0 else 0.03, TerrainField.ToolMode.DIG if i % 2 == 0 else TerrainField.ToolMode.RAISE)
			var took := Time.get_ticks_usec() - b0
			brush_total += took
			brush_max = maxi(brush_max, took)
		var refreshed := collision.refreshed_count() - refreshed_before
		print("PROTOTYPE01_ARENA_BENCH terrain brush_avg_ms=%.2f brush_max_ms=%.2f chunks=%d chunks_refreshed=%d chunk_refresh_ms=%.3f base_bake_ms=%.1f strokes_ms=%.1f"
			% [brush_total / 100000.0, brush_max / 1000.0, collision.chunk_count(), refreshed,
				(brush_total / 1000.0) / maxi(refreshed, 1), grid_usec / 1000.0, layout_usec / 1000.0])

	if night:
		var run: ArenaRun = scene.get_node(^"Run")
		run.elapsed = run.day_night.night_start_seconds + run.day_night.dusk_seconds + 1.0
		await physics_frame
		# Sei lampioni attorno al giocatore: il massimo di luci logiche della tappa 2.
		var lamps: LampField = scene.get_node(^"LampField")
		var companion: Companion = scene.get_node(^"Companion")
		companion.add_capacity(18, 18)
		for i in 6:
			var world: Vector3 = player.global_position + Vector3(cos(i * TAU / 6.0) * 8.0, 0.0, sin(i * TAU / 6.0) * 8.0)
			companion.global_position = world + Vector3(0.0, 0.3, 1.5)
			lamps.place_at(world)
		companion.global_position = player.global_position + Vector3(3.0, 0.3, 0.0)
		print("PROTOTYPE01_ARENA_BENCH night phase=%s lamps=%d" % [DayNightCycle.PHASE_NAMES[run.day_night.phase], lamps.count()])
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
		print("PROTOTYPE01_ARENA_BENCH render preset=%s draw_calls=%d primitives=%d objects=%d video_mem_mb=%.0f"
			% [preset_name, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	print("PROTOTYPE01_ARENA_BENCH path solve_ms=%.2f recenter_ms=%.2f chunks=%d leashed=%d"
		% [path.last_solve_usec / 1000.0, path.last_recenter_usec / 1000.0, path.chunks_scanned, director.leashed])
	# Corsa (audit PF-02): il ricentro del campo e stato per mesi il passo piu caro del
	# gioco (51-64 ms) senza che il benchmark, a giocatore fermo, lo vedesse.
	var recenter_max := 0.0
	var recenters := path.recenter_count
	for i in 720:
		player._invulnerable_left = 1.0
		player.global_position += Vector3(7.0 / 120.0, 0.0, 0.0) if i < 360 else Vector3(0.0, 0.0, 7.0 / 120.0)
		await physics_frame
		recenter_max = maxf(recenter_max, path.last_recenter_usec / 1000.0)
	print("PROTOTYPE01_ARENA_BENCH run recenters=%d recenter_max_ms=%.2f terrain_chunks_sync=%d"
		% [path.recenter_count - recenters, recenter_max, path.terrain_chunks_sync])
	if OS.get_cmdline_user_args().has("--motion-ab"):
		# Stesso processo, blocchi alternati con e senza movimento procedurale: il
		# rumore della macchina pesa uguale sui due lati.
		director.set_physics_process(false)
		var totals := [0, 0]
		for block in 40:
			ActorMotion.enabled = block % 2 == 0
			var b0 := Time.get_ticks_usec()
			for i in 30:
				director._physics_process(step)
			totals[block % 2] += Time.get_ticks_usec() - b0
		ActorMotion.enabled = true
		print("PROTOTYPE01_ARENA_BENCH motion_ab enemies=%d director_on_ms=%.3f director_off_ms=%.3f delta=%.1f%%"
			% [director.enemies.size(), totals[0] / 600000.0, totals[1] / 600000.0, (float(totals[0]) / totals[1] - 1.0) * 100.0])
	# Ultima: aggiunge nemici e scrive anelli permanenti, non deve sporcare le misure sopra.
	await _bench_loadout(scene, 1.0 / Engine.physics_ticks_per_second)
	quit()
