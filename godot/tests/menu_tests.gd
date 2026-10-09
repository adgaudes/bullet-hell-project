extends SceneTree
## Test del menu iniziale (D-051) e della mappa di fine livello (D-052). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/menu_tests.gd

const MenuScene := preload("res://scenes/main/main_menu.tscn")
const RunScene := preload("res://scenes/main/arena_run.tscn")
const LOWERED := TerrainState.CellState.LOWERED
const NORMAL := TerrainState.CellState.NORMAL
const RAISED := TerrainState.CellState.RAISED

var _failures := 0


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_test_autostart_arguments()
	await _test_menu()
	_test_map_rules()
	await _test_run_map()
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


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(1)


func _press_escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _test_autostart_arguments() -> void:
	print("autostart")
	_check(not MainMenu.wants_autostart(PackedStringArray()), "senza argomenti ci si ferma al menu")
	_check(MainMenu.wants_autostart(PackedStringArray(["--autostart"])), "--autostart salta il menu")
	_check(MainMenu.wants_autostart(PackedStringArray(["--seed=42"])) and MainMenu.wants_autostart(PackedStringArray(["--boss-at=60"])),
		"--seed e --boss-at saltano il menu")
	_check(MainMenu.wants_autostart(PackedStringArray(["--capture=a.png"])), "--capture salta il menu")
	_check(not MainMenu.wants_autostart(PackedStringArray(["--out=x"])), "un argomento qualunque no")


func _test_menu() -> void:
	print("menu")
	var profile := root.get_node("PlayerProfile") as PlayerProfileService
	profile.reset()
	profile.scrap = 12
	var pause := root.get_node("PauseMenu")
	var menu: MainMenu = MenuScene.instantiate()
	root.add_child(menu)
	await _frames(3)
	var focus := menu.focused_control() as Button
	_check(focus != null and focus.text == "Gioca", "il fuoco parte su Gioca")
	_check((menu._scrap_label.text as String).contains("Rottami in Officina: 12"), "mostra i rottami del profilo")
	_check(not pause.get(&"enabled"), "nel menu la pausa e disattivata")
	await _press(&"pause")
	_check(not paused and not pause.call(&"is_open"), "il tasto pausa nel menu non fa nulla")

	var workshop: WorkshopPanel = menu.get_node(^"WorkshopPanel")
	menu.open_workshop()
	_check(workshop.is_open and not menu._column.visible, "Officina aperta dal menu, prima di qualunque run")
	workshop.press(&"base_health")
	_check(profile.level_of(&"base_health") == 1 and profile.scrap == 12 - 4, "si compra dal menu")
	await _press(&"ui_cancel")
	focus = menu.focused_control() as Button
	_check(not workshop.is_open and menu._column.visible and focus != null and focus.text == "Officina",
		"B chiude l'Officina e il fuoco torna sul suo pulsante")
	_check((menu._scrap_label.text as String).contains("Rottami in Officina: 8"), "il totale si aggiorna")

	menu.open_settings()
	await _frames(2)
	_check(pause.call(&"is_open") and not paused and not menu._column.visible, "Impostazioni aperte senza mettere in pausa")
	await _press(&"ui_cancel")
	focus = menu.focused_control() as Button
	_check(not pause.call(&"is_open") and menu._column.visible and focus != null and focus.text == "Impostazioni",
		"B chiude le Impostazioni e il fuoco torna sul suo pulsante")
	# R-13: Esc fisico e insieme `pause` (spenta nel menu) e `ui_cancel`: deve chiudere come B.
	menu.open_settings()
	await _frames(2)
	await _press_escape()
	focus = menu.focused_control() as Button
	_check(not pause.call(&"is_open") and not paused and menu._column.visible and focus != null and focus.text == "Impostazioni",
		"Esc chiude le Impostazioni nel menu iniziale")

	var column := (pause.get(&"_resume_button") as Button).get_parent()
	var texts: Array = column.get_children().filter(func(n: Node) -> bool: return n is Button).map(func(b: Button) -> String: return b.text)
	_check(texts == ["Riprendi", "Impostazioni", "Torna al menu", "Esci"], "menu di pausa: %s" % [texts])
	root.remove_child(menu)
	menu.queue_free()
	await _frames(2)
	_check(pause.get(&"enabled"), "uscendo dal menu la pausa torna attiva")
	profile.reset()


func _test_map_rules() -> void:
	print("map rules")
	_check(RunMap.cell_color(NORMAL, NORMAL, false) == RunMap.GROUND, "terreno intatto")
	_check(RunMap.cell_color(RAISED, RAISED, false) == RunMap.WALL_INITIAL, "muro che c'era gia")
	_check(RunMap.cell_color(RAISED, NORMAL, false) == RunMap.WALL_NEW, "terrapieno nuovo")
	_check(RunMap.cell_color(LOWERED, NORMAL, false) == RunMap.TRENCH_NEW, "fossato nuovo")
	_check(RunMap.cell_color(NORMAL, RAISED, false) == RunMap.BREACH, "breccia in un muro")
	_check(RunMap.cell_color(LOWERED, LOWERED, false) == RunMap.TRENCH_INITIAL, "trincea che c'era gia")
	_check(RunMap.cell_color(RAISED, NORMAL, true) == RunMap.BARRICADE, "barricata del boss")
	var size := Vector2i(85, 85)
	var small := RunMap.view_rect(size, [Vector2i(42, 42)])
	_check(small.size == Vector2i(RunMap.MIN_SIDE_CELLS, RunMap.MIN_SIDE_CELLS) and small.has_point(Vector2i(42, 42)), "vista minima attorno a un solo punto")
	var corner := RunMap.view_rect(size, [Vector2i(0, 0), Vector2i(3, 2)])
	_check(corner.position == Vector2i.ZERO and corner.end.x <= 85, "in un angolo la vista resta dentro la mappa")
	var wide := RunMap.view_rect(size, [Vector2i(5, 40), Vector2i(80, 44)])
	_check(wide.size.x == wide.size.y and wide.size.x >= 84 and wide.end.x <= 85 and wide.end.y <= 85
		and wide.has_point(Vector2i(5, 40)) and wide.has_point(Vector2i(80, 44)), "vista quadrata che contiene tutto, dentro la mappa")
	var state := TerrainState.new()
	state.resize(5, 5)
	var before := RunMap.snapshot(state)
	_check(before.size() == 25 and RunMap.changed_cells(state, before).is_empty(), "fotografia iniziale: nessuna cella cambiata")
	state.apply(Vector2i(3, 1), TerrainState.ToolMode.DIG)
	_check(RunMap.changed_cells(state, before) == [Vector2i(3, 1)], "una cella scavata risulta cambiata")


func _test_run_map() -> void:
	print("run map")
	var scene: Node3D = RunScene.instantiate()
	root.add_child(scene)
	(scene.get_node(^"EnemyDirector") as EnemyDirector).spawning = false
	await _frames(3)
	var run: ArenaRun = scene.get_node(^"Run")
	var player: PlayerCharacter = scene.get_node(^"Player")
	var grid: TerrainGrid = scene.get_node(^"TerrainGrid")
	var panel: GameOverPanel = scene.get_node(^"GameOverPanel")
	# Un fossato a nord e un terrapieno a est del giocatore.
	_check(grid.apply_command_at(Vector3(0.0, 0.0, -7.2), TerrainState.ToolMode.DIG, player), "scavo a nord")
	_check(grid.apply_command_at(Vector3(4.8, 0.0, 0.0), TerrainState.ToolMode.RAISE, player), "rialzo a est")
	_check(run.cells_dug == 1 and run.cells_raised == 1, "conteggi del tool: 1 scavata, 1 rialzata")
	_check(not panel.has_map(), "nessuna mappa prima della fine")
	player._invulnerable_left = 0.0
	player.take_damage(player.health)
	await _frames(2)
	_check(panel.is_open and panel.has_map(), "a fine livello la schermata ha la mappa")
	_check((panel._map_caption.text as String).contains("Celle scavate 1   rialzate 1"), "sotto la mappa i conteggi")
	var image := panel._map_image
	_check(image.get_width() == image.get_height() and image.get_width() >= 100 and image.get_width() <= 400,
		"mappa quadrata di %d px" % image.get_width())
	var trench := _centroid(image, RunMap.TRENCH_NEW)
	var wall := _centroid(image, RunMap.WALL_NEW)
	_check(trench.z > 0.0 and wall.z > 0.0, "fossato e terrapieno nuovi sono sulla mappa")
	_check(_centroid(image, RunMap.WALL_INITIAL).z > 0.0, "le mura del cortile ci sono, in un altro colore")
	_check(trench.y < wall.y and wall.x > trench.x, "nord in alto, est a destra")
	_check(_centroid(image, RunMap.BREACH).z == 0.0 and _centroid(image, RunMap.BARRICADE).z == 0.0, "nessuna breccia e nessuna barricata inventata")
	var path := panel.save_map()
	_check(not path.is_empty() and FileAccess.file_exists(path), "Salva mappa scrive un PNG (%s)" % path)
	if not path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var texts: Array = [panel._workshop, panel._restart, panel._menu, panel._quit].map(func(b: Button) -> String: return b.text)
	_check(texts == ["Officina", "Ricomincia", "Menu", "Esci"], "pulsanti di fine livello: %s" % [texts])
	paused = false
	root.remove_child(scene)
	scene.queue_free()
	await _frames(2)
	(root.get_node("PlayerProfile") as PlayerProfileService).reset()


## Baricentro (x, y) dei pixel di quel colore e, in z, quanti sono.
func _centroid(image: Image, color: Color) -> Vector3:
	var sum := Vector2.ZERO
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if RunMap.same_color(image.get_pixel(x, y), color):
				sum += Vector2(x, y)
				count += 1
	if count == 0:
		return Vector3.ZERO
	return Vector3(sum.x / count, sum.y / count, count)
