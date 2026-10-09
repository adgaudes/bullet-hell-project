extends SceneTree
## Test del primo boss, il Demolitore (D-043). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/boss_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")
const RAISED := TerrainState.CellState.RAISED
const NORMAL := TerrainState.CellState.NORMAL
const LOWERED := TerrainState.CellState.LOWERED
## Frame entro cui il boss ricontrolla bersagli e rottamatori (Demolisher.RETARGET_SECONDS).
const RETARGET_FRAMES := 30

var _failures := 0
var _scene: Node3D
var _run: ArenaRun
var _grid: TerrainGrid
var _player: PlayerCharacter
var _director: EnemyDirector
var _weapon: AutoWeapon
var _path: PathField
var _hud: RunHud
var _scrap: ScrapField
var _boss: Demolisher


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_run = _scene.get_node(^"Run")
	_grid = _scene.get_node(^"TerrainGrid")
	_player = _scene.get_node(^"Player")
	_director = _scene.get_node(^"EnemyDirector")
	_weapon = _scene.get_node(^"PlayerWeapon")
	_path = _scene.get_node(^"PathField")
	_hud = _scene.get_node(^"RunHud")
	_scrap = _scene.get_node(^"ScrapField")
	_director.spawning = false
	await _frames(5)
	_weapon.set_physics_process(false)
	await _test_call_and_arrival()
	await _test_walls_attract_and_feed_barricades()
	await _test_digging_a_barricade()
	await _test_scrap_is_not_buried()
	await _test_own_barricade_in_the_way()
	await _test_abandons_unreachable_wall()
	await _test_no_carrier_without_route()
	await _test_spawn_point_is_walkable()
	await _test_companion_ignores_sealed_scrap()
	await _test_site_moves_when_occupied()
	await _test_carrier_waits_without_site()
	await _test_trench_slows()
	await _test_contact_damage()
	await _test_weapon_hits_boss()
	await _test_defeat_completes_level()
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


func _place_player(at: Vector3) -> void:
	_player.global_position = Vector3(at.x, 0.88, at.z)
	_player.velocity = Vector3.ZERO
	_player._invulnerable_left = 0.0
	_path.solve()


func _place_boss(at: Vector3) -> void:
	_boss.global_position = Vector3(at.x, Demolisher.boss_spawn_height(), at.z)
	_boss.velocity = Vector3.ZERO
	_boss.demolish_cell = Vector2i(-1, -1)
	_boss._retarget_left = 0.0
	_boss._wall_target = Vector2i(-1, -1)


func _cell_world(cell: Vector2i) -> Vector3:
	var p := _grid.to_global(_grid.cell_local_position(cell, NORMAL))
	return Vector3(p.x, 0.0, p.z)


func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _test_call_and_arrival() -> void:
	print("call and arrival")
	_check(is_equal_approx(_run.boss_call_at, _run.tuning.boss_call_seconds), "chiamata a %.0f s dal tuning" % _run.boss_call_at)
	_check(_run.boss_phase == ArenaRun.BossPhase.WAITING and not _hud.is_boss_warning_visible(), "prima della chiamata nessun annuncio")
	_place_player(Vector3.ZERO)
	_run.boss_call_at = _run.elapsed + 0.05
	await _frames(6)
	_check(_run.boss_phase == ArenaRun.BossPhase.WARNING, "a tempo scaduto il boss e annunciato")
	_check(_hud.is_boss_warning_visible() and not _hud.is_boss_bar_visible(), "annuncio visibile, barra vita non ancora")
	var names := ["NORD", "EST", "SUD", "OVEST"]
	_check(names.has(_run.boss_direction_name) and is_equal_approx(_run.boss_direction.length(), 1.0),
		"direzione annunciata: %s" % _run.boss_direction_name)
	_check(_run.boss == null and _run._boss_warning_left > _run.tuning.boss_warning_seconds - 1.0,
		"preavviso di %.0f s prima dell'arrivo" % _run.tuning.boss_warning_seconds)
	_run._boss_warning_left = 0.05
	await _frames(6)
	_boss = _run.boss as Demolisher
	_check(_run.boss_phase == ArenaRun.BossPhase.ACTIVE and _boss != null, "finito il preavviso il Demolitore entra in campo")
	if _boss == null:
		return
	_check(_director.enemies.has(_boss), "registrato fra i nemici: armi e scavo esplosivo lo vedono")
	var offset := _boss.global_position - _player.global_position
	offset.y = 0.0
	_check(offset.normalized().dot(_run.boss_direction) > 0.9, "arriva dalla direzione annunciata")
	_check(absf(offset.length() - _run.tuning.boss_spawn_distance) < 12.0, "a circa %.0f m (%.1f)" % [_run.tuning.boss_spawn_distance, offset.length()])
	_check(_hud.is_boss_bar_visible() and not _hud.is_boss_warning_visible(), "barra vita visibile, annuncio sparito")
	_check(_boss.health == _run.tuning.boss_health, "vita %d" % _boss.health)


## Un terrapieno entro il raggio lo attira piu del giocatore; ogni muro smontato
## lascia un rottame, che i rottamatori portano al cantiere: ogni due nasce una
## barricata fra lui e il giocatore (D-045).
func _test_walls_attract_and_feed_barricades() -> void:
	print("walls and barricades")
	var companion: Companion = _scene.get_node(^"Companion")
	companion.set_physics_process(false)
	_place_player(Vector3.ZERO)
	_place_boss(Vector3(4.8, 0.0, -17.0))
	var raised_before := _count(RAISED)
	var first_frame := -1
	var first_cell := Vector2i(-1, -1)
	for i in 900:
		await physics_frame
		if _boss.is_demolishing() and first_cell.x < 0:
			first_cell = _boss.demolish_cell
		if _boss.walls_demolished >= 1:
			first_frame = i
			break
	_check(first_frame >= 0, "raggiunge un terrapieno del cortile e lo smonta (frame %d)" % first_frame)
	_check(first_cell.x >= 0 and _grid.state.get_state(first_cell) == NORMAL, "la cella smontata torna Normal")
	_check(_boss.barricades.is_empty(), "un solo muro non basta per una barricata")
	_check(_scrap.count() == 1, "il muro smontato lascia un rottame a terra")
	for i in 900:
		await physics_frame
		if _boss.walls_demolished >= 2:
			break
	# Fermo dov'e: i controlli che seguono riguardano solo i rottamatori.
	_boss.speed = 0.0
	_boss.velocity = Vector3.ZERO
	_boss.wall_attraction_radius = 0.0
	_check(_boss.walls_demolished == 2, "smonta un secondo muro")
	_check(_scrap.count() == 2 and _boss.barricades.is_empty() and _boss.crew_size() == 0,
		"senza rottamatori i rottami restano a terra e non nasce nessuna barricata")

	var scraps := _scrap.positions_near(_boss.global_position, _boss.carrier_scrap_radius)
	_check(scraps.size() == 2, "i due rottami sono alla portata dei suoi rottamatori")
	if scraps.size() < 2:
		return
	# I rottamatori consegnano e poi tornano dal giocatore: qui non deve morire.
	_player._invulnerable_left = 600.0
	var first := _director.spawn_at(scraps[0] + Vector3(0.7, 0.0, 0.7))
	await _frames(RETARGET_FRAMES)
	_check(first.has_errand and _boss.crew_size() == 1, "un rottamatore vicino lascia il giocatore e va al rottame")
	for i in 600:
		await physics_frame
		if first.carrying_scrap:
			break
	_check(first.carrying_scrap and _scrap.count() == 1, "lo raccoglie e lo porta addosso")
	var site := _boss.site_cell()
	_check(site.x >= 0 and _grid.state.get_state(site) == NORMAL, "il boss sceglie un cantiere su una cella Normal")
	first.take_damage(first.health)
	await _frames(2)
	_check(_scrap.count() == 2 and _boss.crew_size() == 0, "abbattuto mentre e carico, lascia cadere il rottame")

	var haulers: Array[Enemy] = []
	for position in _scrap.positions_near(_boss.global_position, _boss.carrier_scrap_radius):
		haulers.append(_director.spawn_at(position + Vector3(0.7, 0.0, 0.7)))
	for i in 1500:
		await physics_frame
		if _boss.barricades.size() >= 1:
			break
	_check(_boss.barricades.size() == 1, "due rottami consegnati al cantiere: una barricata (%d)" % _boss.barricades.size())
	_check(_scrap.count() == 0 and _boss.site_scrap() == 0, "i rottami sono finiti nella barricata")
	var audio: RunAudio = _scene.get_node(^"RunAudio")
	_check(audio.play_count(&"boss_spawn") == 1 and audio.play_count(&"boss_demolish") == 2
		and audio.play_count(&"carrier_pickup") >= 2 and audio.play_count(&"boss_barricade") == 1,
		"si sentono arrivo, muri smontati, rottami raccolti e barricata")
	_check(haulers.all(func(e: Enemy) -> bool: return not e.has_errand and not e.carrying_scrap),
		"consegnato il rottame, tornano a inseguire il giocatore")
	for hauler in haulers:
		_director.enemies.erase(hauler)
		hauler.queue_free()
	_boss.speed = _run.tuning.boss_speed
	_boss.wall_attraction_radius = _run.tuning.boss_wall_attraction_radius
	companion.set_physics_process(true)
	_player._invulnerable_left = 0.0
	if _boss.barricades.size() == 1:
		var cell: Vector2i = _boss.barricades.keys()[0]
		var center := _cell_world(cell)
		_check(_grid.state.get_state(cell) == RAISED, "la barricata e una cella Raised")
		_check(_planar_distance(center, _player.global_position) < _planar_distance(_boss.global_position, _player.global_position),
			"sta fra il boss e il giocatore")
		_check(_planar_distance(center, _player.global_position) > 2.0, "non nasce addosso al giocatore")
		_check(_count(RAISED) == raised_before - 2 + 1, "bilancio delle celle: due mura in meno, una barricata in piu")
		# Il boss non considera le proprie barricate come bersaglio.
		_boss._retarget_left = 0.0
		await _frames(2)
		_check(_boss._wall_target != cell, "le proprie barricate non lo attirano")


func _test_digging_a_barricade() -> void:
	print("dig barricade")
	if _boss.barricades.is_empty():
		_check(false, "nessuna barricata da scavare")
		return
	var cell: Vector2i = _boss.barricades.keys()[0]
	_director.set_physics_process(false)
	var scraps := _scrap.count()
	_check(_grid.apply_command_at(_cell_world(cell), TerrainState.ToolMode.DIG, _player), "il giocatore scava la barricata")
	_check(not _boss.barricades.has(cell) and _grid.state.get_state(cell) == NORMAL, "la barricata crolla")
	_check(_scrap.count() == scraps + 1, "e restituisce un rottame")
	_director.set_physics_process(true)


## R-02: una cella che si alza (barricata o terrapieno) non seppellisce un rottame, e il
## boss non sceglie per la barricata una cella con un rottame sopra.
func _test_scrap_is_not_buried() -> void:
	print("scrap under a raised cell")
	_place_player(Vector3.ZERO)
	var cell := _grid.cell_at(_player.global_position + Vector3(0.0, 0.0, 6.0))
	if _grid.state.get_state(cell) != NORMAL:
		_grid.force_cell_state(cell, NORMAL)
	var before := _scrap.count()
	_scrap.spawn_on_cell(cell, NORMAL)
	_check(_scrap.count_on_cell(cell) == 1, "rottame posato su una cella Normal")
	_check(not _boss._cell_is_free(cell), "il boss non ci costruisce sopra una barricata")
	_grid.force_cell_state(cell, RAISED)
	_check(_scrap.count() == before + 1 and _scrap.count_on_cell(cell) == 0, "la cella si alza: il rottame non e sepolto")
	var moved: Array[Vector3] = _scrap.positions_near(_cell_world(cell), _grid.cell_size_m() * 1.6)
	_check(moved.size() == 1 and _grid.cell_state_at(moved[0]) == NORMAL, "e sta su una vicina Normal")
	_grid.force_cell_state(cell, NORMAL)
	_scrap.take_near(_cell_world(cell), _grid.cell_size_m() * 2.0, 1)


## R-06: una propria barricata sulla linea verso il giocatore non va smontata.
func _test_own_barricade_in_the_way() -> void:
	print("own barricade in the way")
	_place_player(Vector3.ZERO)
	var cell := _grid.cell_at(Vector3(0.0, 0.0, -6.0))
	_boss._raise_barricade(cell)
	var center := _cell_world(cell)
	_place_boss(center + Vector3(0.0, 0.0, -1.9))
	var radius := _boss.wall_attraction_radius
	_boss.wall_attraction_radius = 0.0
	var touched := false
	for i in 90:
		await physics_frame
		if _boss.demolish_cell == cell:
			touched = true
			break
	_check(not touched and _boss.barricades.has(cell), "spingendo contro la propria barricata non la smonta")
	_boss.wall_attraction_radius = radius
	_grid.apply_command_at(center, TerrainState.ToolMode.DIG, _player)
	_scrap.take_near(center, _grid.cell_size_m() * 2.0, 1)


## R-01: un muro che non si avvicina (qui: il boss non puo muoversi) viene lasciato perdere
## dopo WALL_STALL_SECONDS, e per un po' non lo attira piu.
func _test_abandons_unreachable_wall() -> void:
	print("abandons an unreachable wall")
	_place_player(Vector3.ZERO)
	_place_boss(Vector3(0.0, 0.0, -14.0))
	var cell := _grid.cell_at(Vector3(0.0, 0.0, -9.0))
	_grid.force_cell_state(cell, RAISED)
	var radius := _boss.wall_attraction_radius
	_boss.wall_attraction_radius = 6.0
	_boss.speed = 0.0
	await _frames(3)
	_check(_boss._wall_target == cell, "il muro lo attira")
	var gave_up := -1
	for i in 240:
		await physics_frame
		if _boss._wall_target != cell:
			gave_up = i
			break
	var expected := int(Demolisher.WALL_STALL_SECONDS * 60.0)
	_check(gave_up >= expected - 5 and gave_up <= expected + 30,
		"senza avvicinarsi per %.0f s lo lascia perdere (frame %d)" % [Demolisher.WALL_STALL_SECONDS, gave_up])
	_check(_boss._ignored_walls.has(cell) and _boss._nearest_wall() != cell, "e per un po' quel muro non lo attira piu")
	_check(not _boss.is_demolishing(), "non e rimasto incastrato a smontare")
	_boss._ignored_walls.clear()
	_boss.speed = _run.tuning.boss_speed
	_boss.wall_attraction_radius = radius
	_grid.force_cell_state(cell, NORMAL)


## E-04: un rottame chiuso dentro un anello di celle Raised non recluta nessuno.
func _test_no_carrier_without_route() -> void:
	print("no carrier without a route")
	_place_player(Vector3.ZERO)
	var scrap_cell := _grid.cell_at(Vector3(0.0, 0.0, 9.6))
	var ring: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dy != 0:
				ring.append(scrap_cell + Vector2i(dx, dy))
	_grid.set_cell_states(ring, RAISED)
	_path.solve()
	_scrap.spawn_on_cell(scrap_cell, NORMAL)
	var scrap_world := _cell_world(scrap_cell)
	_check(_path.cost_at(scrap_world) == PathField.UNREACHABLE, "il rottame e senza strada")
	_place_boss(scrap_world + Vector3(0.0, 0.0, 6.0))
	_boss.speed = 0.0
	var radius := _boss.wall_attraction_radius
	_boss.wall_attraction_radius = 0.0
	var outsider := _director.spawn_at(scrap_world + Vector3(6.0, 0.0, 0.0))
	await _frames(RETARGET_FRAMES)
	_check(not outsider.has_errand and _boss.crew_size() == 0, "nessun rottamatore reclutato verso un rottame irraggiungibile")
	_grid.set_cell_states(ring, NORMAL)
	_path.solve()
	await _frames(RETARGET_FRAMES)
	_check(outsider.has_errand and _boss.crew_size() == 1, "riaperta la strada, viene reclutato")
	# Abbattuto come in gioco: il boss lo toglie dalla squadra da solo.
	outsider.take_damage(outsider.health)
	await _frames(2)
	_scrap.take_near(scrap_world, _grid.cell_size_m() * 3.0, 2)
	_boss.speed = _run.tuning.boss_speed
	_boss.wall_attraction_radius = radius
	await _frames(2)


## T-01: con una rovina sul punto d'ingresso, il boss nasce sulla cella percorribile piu vicina.
func _test_spawn_point_is_walkable() -> void:
	print("spawn point is walkable")
	_place_player(Vector3.ZERO)
	_run.boss_direction = Vector3(0.0, 0.0, -1.0)
	var block := StaticBody3D.new()
	block.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(22.0, 2.0, 16.0)
	shape.shape = box
	block.add_child(shape)
	_scene.add_child(block)
	block.global_position = _run.boss_direction * _run.tuning.boss_spawn_distance + Vector3(0.0, 1.0, 0.0)
	await _frames(2)
	_path.scan_static_obstacles()
	var naive := _run.boss_direction * _run.tuning.boss_spawn_distance
	_check(not _path.is_walkable(naive), "il punto d'ingresso nominale e dentro la rovina")
	var point: Vector3 = _run._boss_spawn_point()
	_check(_path.is_walkable(point), "il boss nasce su una cella percorribile (%s)" % point)
	_check(_planar_distance(point, naive) <= 24.0, "vicino al punto nominale (%.1f m)" % _planar_distance(point, naive))
	_scene.remove_child(block)
	block.free()
	await _frames(2)
	_path.scan_static_obstacles()


## R-05: il compagno non punta a un rottame chiuso dentro un anello di celle Raised.
func _test_companion_ignores_sealed_scrap() -> void:
	print("companion ignores sealed scrap")
	_place_player(Vector3.ZERO)
	var companion: Companion = _scene.get_node(^"Companion")
	var scrap_cell := _grid.cell_at(Vector3(4.8, 0.0, 0.0))
	var ring: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dy != 0:
				ring.append(scrap_cell + Vector2i(dx, dy))
	_grid.set_cell_states(ring, RAISED)
	_path.solve()
	var before := _scrap.count()
	_scrap.spawn_on_cell(scrap_cell, NORMAL)
	var sealed := _cell_world(scrap_cell)
	var destination: Vector3 = companion._choose_destination()
	_check(_planar_distance(destination, sealed) > 1.0, "il rottame sigillato non e la destinazione del compagno")
	_grid.set_cell_states(ring, NORMAL)
	_path.solve()
	destination = companion._choose_destination()
	_check(_planar_distance(destination, sealed) < 0.5, "riaperto, il rottame torna a essere la destinazione")
	_scrap.take_near(sealed, 1.0, 1)
	_check(_scrap.count() == before, "pulizia")
	await _frames(2)


## R-03: cantiere occupato dal giocatore con scorta sufficiente: ne sceglie un altro e costruisce.
func _test_site_moves_when_occupied() -> void:
	print("site moves when occupied")
	_place_player(Vector3.ZERO)
	_place_boss(Vector3(0.0, 0.0, -9.6))
	_boss.speed = 0.0
	var radius := _boss.wall_attraction_radius
	_boss.wall_attraction_radius = 0.0
	_boss._choose_site()
	var site := _boss.site_cell()
	_check(site.x >= 0, "cantiere scelto fra boss e giocatore")
	var before := _boss.barricades.size()
	_player.global_position = _cell_world(site) + Vector3(0.0, 0.88, 0.0)
	_player._invulnerable_left = 600.0
	_boss._site_scrap = _boss.walls_per_barricade
	_boss._try_build_at_site()
	_check(_boss.barricades.size() == before + 1 and not _boss.barricades.has(site),
		"col giocatore sul cantiere la barricata nasce altrove (%d)" % _boss.barricades.size())
	for cell: Vector2i in _boss.barricades.keys():
		if not _grid.state.is_valid(cell):
			continue
		_grid.apply_command_at(_cell_world(cell), TerrainState.ToolMode.DIG, _player)
		_scrap.take_near(_cell_world(cell), _grid.cell_size_m() * 2.0, 2)
	_player._invulnerable_left = 0.0
	_boss.speed = _run.tuning.boss_speed
	_boss.wall_attraction_radius = radius
	await _frames(2)


## R-04: un portatore carico senza cantiere valido aspetta accanto al boss senza far
## scadere il tempo (niente ciclo "molla, rireclutato" ogni 10 s).
func _test_carrier_waits_without_site() -> void:
	print("carrier waits without a site")
	_place_boss(Vector3(0.0, 0.0, -12.0))
	# Giocatore addosso al boss: nessuna direzione per il cantiere, nessun cantiere valido.
	_player.global_position = _boss.global_position + Vector3(0.0, 0.88, 0.0)
	_player._invulnerable_left = 600.0
	_boss.speed = 0.0
	_boss._clear_site(false)
	var carrier := _director.spawn_at(_boss.global_position + Vector3(3.0, 0.0, 0.0))
	carrier.set_errand(_boss.global_position)
	carrier.set_carrying(true)
	_boss._crew[carrier] = 1.0
	await _frames(90)
	_check(_boss._crew.has(carrier) and carrier.carrying_scrap and _boss._crew[carrier] >= 0.99,
		"senza cantiere il portatore carico aspetta e il tempo non scorre (%.2f)" % _boss._crew.get(carrier, -1.0))
	carrier.take_damage(carrier.health)
	await _frames(2)
	_scrap.take_near(_boss.global_position, 6.0, 3)
	_player._invulnerable_left = 0.0
	_boss.speed = _run.tuning.boss_speed
	_place_player(Vector3.ZERO)
	await _frames(2)


func _test_trench_slows() -> void:
	print("trench")
	_boss.wall_attraction_radius = 0.0
	_place_player(Vector3(6.0, 0.0, 2.4))
	_place_boss(Vector3(-6.0, 0.0, 2.4))
	await _frames(40)
	var normal_speed := Vector2(_boss.velocity.x, _boss.velocity.z).length()
	_check(absf(normal_speed - _run.tuning.boss_speed) < 0.15, "su terreno Normal va a %.2f m/s" % normal_speed)
	_grid.force_cell_state(_grid.cell_at(_boss.global_position), LOWERED)
	await _frames(30)
	var slow_speed := Vector2(_boss.velocity.x, _boss.velocity.z).length()
	_check(slow_speed < _run.tuning.boss_speed * 0.6, "in un fossato rallenta (%.2f m/s)" % slow_speed)
	_boss.wall_attraction_radius = _run.tuning.boss_wall_attraction_radius


func _test_contact_damage() -> void:
	print("contact")
	_boss.wall_attraction_radius = 0.0
	_player.set_max_health(_run.tuning.player_max_health)
	_place_boss(Vector3(-2.0, 0.0, -2.4))
	_place_player(Vector3(-0.9, 0.0, -2.4))
	await _frames(3)
	_check(_player.health == _run.tuning.player_max_health - _run.tuning.boss_contact_damage,
		"il contatto toglie %d punti vita (vita %d)" % [_run.tuning.boss_contact_damage, _player.health])
	_player.set_max_health(_run.tuning.player_max_health)
	_boss.wall_attraction_radius = _run.tuning.boss_wall_attraction_radius


func _test_weapon_hits_boss() -> void:
	print("weapon")
	_director.set_physics_process(false)
	_place_player(Vector3(0.0, 0.0, 2.4))
	_place_boss(Vector3(5.0, 0.0, 2.4))
	await _frames(2)
	var before := _boss.health
	_check(_weapon.find_target() == _boss, "la chiodatrice lo prende di mira")
	_weapon.set_physics_process(true)
	await _frames(120)
	_weapon.set_physics_process(false)
	_check(_boss.health < before, "i chiodi lo feriscono (%d -> %d)" % [before, _boss.health])
	_director.set_physics_process(true)


func _test_defeat_completes_level() -> void:
	print("defeat")
	_place_player(Vector3(0.0, 0.0, 2.4))
	_place_boss(Vector3(7.0, 0.0, 2.4))
	for i in 3:
		_director.spawn_at(Vector3(-6.0 + i, 0.0, 5.0))
	var kills := _director.kills
	var completed := [false]
	_run.level_completed.connect(func() -> void: completed[0] = true)
	var carried: int = _scene.get_node(^"Companion").carried
	_boss.take_damage(_boss.health)
	await _frames(2)
	var panel: GameOverPanel = _scene.get_node(^"GameOverPanel")
	_check(completed[0] and _run.is_over and _run.boss_phase == ArenaRun.BossPhase.DEFEATED, "boss abbattuto: livello completato")
	_check(panel.is_open and panel.is_victory and paused, "schermata di vittoria, gioco fermo")
	_check(_director.enemies.is_empty() and not _director.spawning, "l'orda si ritira")
	_check(_run._final_map != null, "la mappa di fine run e catturata prima di congedare l'orda")
	_check(_director.kills == kills + 1, "conta solo il boss fra gli abbattuti")
	carried += _run.recovery_scrap()
	_check(_run.scrap_out(true) == carried + _run.tuning.boss_scrap_bonus, "rottami portati fuori: cassone + premio (%d)" % _run.scrap_out(true))
	_check(_run.scrap_out(false) == int(carried * _run.tuning.death_scrap_share), "morendo se ne salva la meta")
	var before: int = _run.recovery_scrap()
	var elapsed_before := _run.elapsed
	_run.elapsed += 600.0
	_check(_run.recovery_scrap() == before, "aspettare non rende rottami")
	_run.elapsed = elapsed_before
	_run.progression.level += int(3.0 * _run.tuning.recovery_scrap_levels)
	_check(_run.tuning.recovery_scrap_levels > 0.0 and _run.scrap_out(true) == carried + 3 + _run.tuning.boss_scrap_bonus
		and _run.recovery_scrap() == before + 3, "rottami di recupero: uno ogni %.0f livelli guadagnati" % _run.tuning.recovery_scrap_levels)
	_check(not _hud.is_boss_bar_visible(), "barra del boss nascosta")
	paused = false


func _count(cell_state: TerrainState.CellState) -> int:
	var total := 0
	for y in _grid.state.height:
		for x in _grid.state.width:
			if _grid.state.get_state(Vector2i(x, y)) == cell_state:
				total += 1
	return total
