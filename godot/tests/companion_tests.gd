extends SceneTree
## Test del Companion Slice (docs/COMPANION_SLICE_SPEC.md). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/companion_tests.gd

const SliceScene := preload("res://scenes/main/companion_slice.tscn")
const DIG := TerrainState.ToolMode.DIG
const RAISE := TerrainState.ToolMode.RAISE

var _failures := 0
var _player: PlayerCharacter
var _grid: TerrainGrid
var _hazard: TerrainHazard
var _companion: Companion
var _scraps: ScrapField


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	await _load_scene()
	await _test_scrap_loop()
	await _reload_scene()
	await _test_raise_needs_scrap_and_companion()
	await _reload_scene()
	await _test_hazard_assist()
	await _reload_scene()
	await _test_hazard_hits_player()
	await _reload_scene()
	await _test_scrap_field_offset_and_cap()
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


## Scavare produce un rottame; il compagno lo raccoglie; rialzare lo spende.
func _test_scrap_loop() -> void:
	print("scrap loop")
	_check(_player.companion == _companion, "il compagno si registra sul giocatore")
	_check(_companion.carried == 3, "dotazione iniziale 3 rottami")
	_hazard.set_physics_process(false)  # niente interferenze dalla sfera

	await _send(&"terrain_tool")
	_check(_grid.state.get_state(Vector2i(5, 3)) == TerrainState.CellState.LOWERED, "scavo della cella (5,3)")
	_check(_scraps.count() == 1, "lo scavo produce un rottame")
	await _wait_until(func(): return _companion.carried == 4, 300)
	_check(_companion.carried == 4 and _scraps.count() == 0, "il compagno va a prenderlo (carried=%d)" % _companion.carried)

	# Torna vicino al giocatore, poi rialzo: Lowered -> Normal costa 1.
	await _frames(120)
	await _send(&"terrain_mode")
	await _send(&"terrain_tool")
	_check(_grid.state.get_state(Vector2i(5, 3)) == TerrainState.CellState.NORMAL, "rialzo applicato")
	_check(_companion.carried == 3, "il rialzo costa un rottame (carried=%d)" % _companion.carried)


func _test_raise_needs_scrap_and_companion() -> void:
	print("raise requirements")
	_hazard.set_physics_process(false)
	await _send(&"terrain_mode")  # Raise
	_companion.carried = 0
	await _frames(2)
	_check(_preview_is_red(), "senza rottami l'anteprima del rialzo e rossa")
	await _send(&"terrain_tool")
	_check(_grid.state.get_state(Vector2i(5, 3)) == TerrainState.CellState.NORMAL, "senza rottami il rialzo e rifiutato")

	_companion.carried = 3
	_companion.set_physics_process(false)
	_companion.global_position = Vector3(20, 0.3, 20)
	await _frames(2)
	_check(_preview_is_red(), "compagno lontano: anteprima rossa")
	await _send(&"terrain_tool")
	_check(_grid.state.get_state(Vector2i(5, 3)) == TerrainState.CellState.NORMAL and _companion.carried == 3,
		"compagno lontano: rialzo rifiutato, nessun rottame speso")

	_companion.global_position = Vector3(0, 0.3, -2.0)
	await _frames(2)
	_check(not _preview_is_red(), "compagno vicino: anteprima gialla")
	await _send(&"terrain_tool")
	_check(_grid.state.get_state(Vector2i(5, 3)) == TerrainState.CellState.RAISED and _companion.carried == 2,
		"compagno vicino: rialzo applicato e pagato")


## Giocatore nella corsia: il compagno alza una cella e la sfera si ferma;
## al passaggio successivo il terrapieno basta e non spende altro.
func _test_hazard_assist() -> void:
	print("hazard assist")
	var raises := [0]
	var blocks := [0]
	var hits := [0]
	_grid.command_applied.connect(func(_c, mode, _s): if mode == RAISE: raises[0] += 1)
	_hazard.blocked.connect(func(): blocks[0] += 1)
	_hazard.hit_player.connect(func(_b): hits[0] += 1)
	await _wait_until(func(): return blocks[0] >= 1, 600)
	_check(raises[0] == 1 and blocks[0] == 1, "il compagno alza un terrapieno e la sfera si ferma")
	_check(hits[0] == 0, "il giocatore non viene colpito")
	_check(_companion.carried == 2, "l'aiuto costa un rottame (carried=%d)" % _companion.carried)
	await _wait_until(func(): return blocks[0] >= 2, 900)
	_check(blocks[0] == 2 and raises[0] == 1, "secondo passaggio: bloccata dallo stesso terrapieno, nessun nuovo rialzo")


## Senza rottami il compagno non puo aiutare: la sfera colpisce, senza spingere.
func _test_hazard_hits_player() -> void:
	print("hazard hits player")
	_companion.carried = 0
	var hits := [0]
	_hazard.hit_player.connect(func(_b): hits[0] += 1)
	var start := _player.global_position
	await _wait_until(func(): return hits[0] > 0, 600)
	_check(hits[0] == 1, "senza rottami la sfera colpisce il giocatore")
	_check(_hazard.is_resting, "dopo il colpo la sfera riparte da capo")
	_check(Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length() < 0.01,
		"il giocatore non viene spinto")


## P-03: il bob lavora in coordinate locali, quindi il campo puo stare ovunque.
## R-09: al tetto MAX_SCRAPS uno scavo ricicla il rottame piu lontano, non viene scartato.
func _test_scrap_field_offset_and_cap() -> void:
	print("scrap field offset and cap")
	_hazard.set_physics_process(false)
	_companion.set_physics_process(false)  # nessuna raccolta
	_scraps.position.y = 1.0
	_scraps.spawn(Vector3(3.0, 0.5, 3.0))
	await _frames(3)
	var found: Variant = _scraps.nearest(Vector3(3.0, 0.0, 3.0), 0.1)
	_check(found != null and absf((found as Vector3).y - 0.5) <= ScrapField.BOB_HEIGHT + 0.001,
		"campo a y=1: il rottame resta alla quota mondo chiesta (got %s)" % str(found))
	_check(_scraps.is_processing(), "con rottami a terra il bob gira")

	for i in ScrapField.MAX_SCRAPS - 1:
		_scraps.spawn(Vector3(30.0 + i, 0.5, 30.0))
	_check(_scraps.count() == ScrapField.MAX_SCRAPS and _scraps.capped_count == 0, "al tetto senza riciclo (%d)" % _scraps.count())
	var farthest := Vector3(30.0 + ScrapField.MAX_SCRAPS - 2, 0.5, 30.0)
	_scraps.spawn(Vector3(0.0, 0.5, 0.0))
	await _frames(2)
	_check(_scraps.count() == ScrapField.MAX_SCRAPS and _scraps.capped_count == 1, "oltre il tetto il conteggio resta a MAX_SCRAPS")
	_check(_scraps.nearest(Vector3.ZERO, 0.1) != null, "il nuovo rottame esiste")
	_check(_scraps.nearest(farthest, 0.1) == null and _scraps.nearest(Vector3(3.0, 0.0, 3.0), 0.1) != null,
		"riciclato il piu lontano dal nuovo, non il piu vicino")
	var taken := _scraps.take_near(Vector3(30.0 + ScrapField.MAX_SCRAPS * 0.5, 0.0, 30.0), 100.0, ScrapField.MAX_SCRAPS)
	await _frames(1)
	_check(taken == ScrapField.MAX_SCRAPS and _scraps.count() == 0, "take_near rimuove tutti i rottami nel raggio (%d)" % taken)
	_check(not _scraps.is_processing(), "senza rottami il bob si ferma")


func _preview_is_red() -> bool:
	var preview := _grid.get_node("Preview") as MeshInstance3D
	var srgb: Color = preview.get_instance_shader_parameter(&"cell_color")
	return srgb.is_equal_approx(TerrainGrid.INVALID_PREVIEW_COLOR.linear_to_srgb())


func _load_scene() -> void:
	var scene := SliceScene.instantiate()
	scene.name = "Scene"
	root.add_child(scene)
	_player = scene.get_node("Base/Player")
	_grid = scene.get_node("Base/TerrainGrid")
	_hazard = scene.get_node("Base/TerrainHazard")
	_companion = scene.get_node("Companion")
	_scraps = scene.get_node("ScrapField")
	await _frames(2)


func _reload_scene() -> void:
	root.get_node("Scene").free()
	await _load_scene()


func _send(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	await _frames(2)


func _wait_until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
