extends SceneTree
## Suite del terremoto del quartiere (D-075): programmazione, preavviso con faglia vicina
## al giocatore, scossa che rialza le celle Normal e riempie le trincee risparmiando
## giocatore e compagno, rottamatori travolti, lampioni caduti, rottami riportati in
## superficie, intervallo successivo, opzione di avvio.
##   godot_console --headless --path godot --script res://tests/quake_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")
const RailwayScene := preload("res://scenes/main/railway_run.tscn")
const NORMAL := TerrainState.CellState.NORMAL
const RAISED := TerrainState.CellState.RAISED
const LOWERED := TerrainState.CellState.LOWERED

var _failures := 0
var _scene: Node3D
var _run: ArenaRun
var _quake: QuakeEvent
var _grid: TerrainGrid
var _player: PlayerCharacter
var _companion: Companion
var _director: EnemyDirector
var _weapon: AutoWeapon
var _hud: RunHud
var _lamps: LampField
var _scrap: ScrapField
var _audio: RunAudio


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_run = _scene.get_node(^"Run")
	_quake = _scene.get_node(^"QuakeEvent")
	_grid = _scene.get_node(^"TerrainGrid")
	_player = _scene.get_node(^"Player")
	_companion = _scene.get_node(^"Companion")
	_director = _scene.get_node(^"EnemyDirector")
	_weapon = _scene.get_node(^"PlayerWeapon")
	_hud = _scene.get_node(^"RunHud")
	_lamps = _scene.get_node(^"LampField")
	_scrap = _scene.get_node(^"ScrapField")
	_audio = _scene.get_node(^"RunAudio")
	_director.spawning = false
	await _frames(5)
	_weapon.set_physics_process(false)
	_test_setup()
	await _test_warning()
	await _test_shake()
	_test_options()
	await _test_railway_has_no_quake()
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


func _place(body: Node3D, at: Vector3, y: float) -> void:
	body.global_position = Vector3(at.x, y, at.z)
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	body.reset_physics_interpolation()


func _test_setup() -> void:
	print("setup")
	_check(_run.quake_event == _quake and _quake.is_enabled(), "il terremoto e collegato alla regia")
	_check(is_equal_approx(_quake.next_at, _run.tuning.quake_first_seconds), "primo terremoto a %.0f s" % _quake.next_at)
	_check(_quake.state == QuakeEvent.State.IDLE and not _hud.is_boss_warning_visible(), "all'inizio nessun terremoto e nessun annuncio")
	_check(_audio.has_sound(&"quake_rumble"), "il brontolio esiste nella libreria")


func _test_warning() -> void:
	print("warning")
	_place(_player, Vector3(0.0, 0.0, 0.0), 0.88)
	# Faglia deterministica: il seme della run e casuale, quello dell'evento qui no.
	_quake.rng.seed = 20261010
	_quake.warning_seconds = 3.0
	_quake.next_at = _run.elapsed + 3.5
	await _frames(40)
	_check(_quake.state == QuakeEvent.State.WARNING, "entro il preavviso il terremoto e annunciato")
	var cells := _quake.fault_cells.size()
	_check(cells >= _quake.length_cells - 3 and cells <= _quake.length_cells, "faglia di %d celle" % cells)
	var distance := Vector2(_quake.fault_center.x, _quake.fault_center.z).length()
	_check(distance >= _quake.distance_min - 0.01 and distance <= _quake.distance_max + 0.01,
		"centro della faglia a %.1f m dal giocatore" % distance)
	var all_valid := true
	for cell in _quake.fault_cells:
		all_valid = all_valid and _grid.state.is_valid(cell)
	_check(all_valid, "tutte le celle della faglia sono nella griglia")
	_check(_hud.is_boss_warning_visible() and _hud.event_warning_text().begins_with("TERREMOTO"), "annuncio a schermo: %s" % _hud.event_warning_text())
	_check(_audio.play_count(&"quake_rumble") >= 1, "brontolio al preavviso")


func _test_shake() -> void:
	print("shake")
	var fault := _quake.fault_cells
	# Sulla faglia: una trincea, un lampione, un rottame, un rottamatore, il giocatore, il compagno.
	# Il compagno segue il giocatore: tutti e due in fondo alla faglia, lontani dal
	# rottamatore, cosi il compagno non finisce sulla sua cella (che verrebbe risparmiata).
	var trench := fault[0]
	var enemy_cell := fault[2]
	var lamp_cell := fault[4]
	var scrap_cell := fault[6]
	var player_cell := fault[fault.size() - 2]
	var companion_cell := fault[fault.size() - 1]
	_grid.set_cell_states([trench], LOWERED)
	_companion.add_capacity(0, 3)
	_place(_companion, _cell_world(lamp_cell) + Vector3(1.0, 0.0, 1.0), 0.3)
	if not _lamps.place_at(_cell_world(lamp_cell)):
		lamp_cell = fault[5]
		_lamps.place_at(_cell_world(lamp_cell))
	_check(_lamps.count() == 1, "lampione piazzato sulla faglia")
	_scrap.spawn_on_ground(_cell_world(scrap_cell))
	var scrap_before := _scrap.count()
	# Rottamatori fermi (speed_scale 0): il test misura la scossa, non la camminata.
	var enemy := _director.spawn_at(_cell_world(enemy_cell))
	enemy.speed_scale = 0.0
	var kills_before := _director.kills
	var far := _quake.fault_center + Vector3(25.0, 0.0, 0.0)
	if fault.has(_grid.cell_at(far)):
		far = _quake.fault_center + Vector3(0.0, 0.0, 25.0)
	var bystander := _director.spawn_at(far)
	bystander.speed_scale = 0.0
	# Celle della faglia che erano Normal (le mura del cortile sono gia Raised).
	var normal_before: Array[Vector2i] = []
	for cell in fault:
		if _grid.state.get_state(cell) == NORMAL:
			normal_before.append(cell)
	_place(_player, _cell_world(player_cell), 0.88)
	_player._invulnerable_left = 0.0
	var health_before := _player.health
	_place(_companion, _cell_world(companion_cell), 0.3)
	var next_before := _quake.next_at
	var started := [false]
	_quake.quake_started.connect(func(_center: Vector3) -> void: started[0] = true)
	# Preavviso restante (circa 3 s) piu scossa (16 celle a 14 al secondo): fino a 10 s.
	for i in 600:
		await physics_frame
		if _quake.quakes == 1:
			break
	_check(started[0] and _quake.quakes == 1 and _quake.state == QuakeEvent.State.IDLE, "la scossa e avvenuta e finita")
	_check(not _hud.is_boss_warning_visible(), "annuncio tolto alla scossa")
	_check(_grid.state.get_state(trench) == NORMAL and _quake.cells_filled >= 1, "la trincea sulla faglia si e riempita")
	var raised := 0
	for cell in normal_before:
		if _grid.state.get_state(cell) == RAISED:
			raised += 1
	# Giocatore e compagno (che lo segue) risparmiano la propria cella e quelle a meno di
	# una cella da loro: fino a quattro celle non rialzate.
	var most := normal_before.size() - 1
	_check(raised >= most - 3 and raised <= most and _quake.cells_raised == raised,
		"celle rialzate lungo la faglia: %d su %d Normal" % [raised, normal_before.size()])
	_check(_grid.state.get_state(player_cell) == NORMAL, "la cella del giocatore e risparmiata")
	_check(_player.health == health_before - _run.tuning.quake_player_damage and _quake.player_hits == 1,
		"giocatore sulla faglia colpito: %d -> %d" % [health_before, _player.health])
	_check(_grid.state.get_state(_grid.cell_at(_companion.global_position)) != RAISED, "la cella del compagno e risparmiata")
	_check((not is_instance_valid(enemy) or enemy.is_dead) and _director.kills == kills_before + 1 and _quake.enemies_hit == 1,
		"rottamatore sulla faglia travolto e contato")
	_check(is_instance_valid(bystander) and not bystander.is_dead, "rottamatore lontano illeso")
	_check(_lamps.count() == 0, "lampione sulla faglia caduto")
	var buried := 0
	for position in _scrap.positions_near(_cell_world(scrap_cell), 6.0):
		if _grid.state.get_state(_grid.cell_at(position)) == RAISED:
			buried += 1
	_check(_scrap.count() >= scrap_before and buried == 0, "rottami in superficie, nessuno sepolto (%d)" % _scrap.count())
	_check(is_equal_approx(_quake.next_at, next_before + _quake.interval_seconds), "prossimo terremoto fra %.0f s" % _quake.interval_seconds)
	_check(_audio.play_count(&"quake_rumble") >= 2, "brontolio anche alla scossa")


func _test_options() -> void:
	print("options")
	_check(is_equal_approx(RunLaunchOptions.quake_seconds(120.0, ["--quake-at=5"]), 5.0), "--quake-at=5 anticipa il terremoto")
	_check(is_equal_approx(RunLaunchOptions.quake_seconds(120.0, ["--seed=3"]), 120.0), "senza opzione vale il tuning")
	_quake.first_seconds = 0.0
	_check(not _quake.is_enabled(), "con 0 secondi il terremoto e spento")


func _test_railway_has_no_quake() -> void:
	print("railway")
	root.remove_child(_scene)
	_scene.queue_free()
	await _frames(2)
	var railway: Node3D = RailwayScene.instantiate()
	root.add_child(railway)
	(railway.get_node(^"EnemyDirector") as EnemyDirector).spawning = false
	await _frames(3)
	_check(railway.get_node_or_null(^"QuakeEvent") == null and (railway.get_node(^"Run") as ArenaRun).quake_event == null,
		"la ferrovia ha il treno, non il terremoto")
	root.remove_child(railway)
	railway.queue_free()
