extends SceneTree
## Test del profilo permanente e dell'Officina (D-049). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/workshop_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")
const ProfileScript := preload("res://scripts/services/player_profile.gd")
const TEMP_PATH := "user://test_profile.cfg"

var _failures := 0


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_test_catalog()
	_test_profile_rules()
	_test_persistence()
	await _test_new_profile_changes_nothing()
	await _test_permanent_upgrades_apply()
	await _test_banking_and_workshop_flow()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
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


## Autoload a runtime: nel test runner il nome globale non esiste in compilazione.
func _profile() -> PlayerProfileService:
	return root.get_node("PlayerProfile") as PlayerProfileService


func _start_run() -> Node3D:
	var scene: Node3D = RunScene.instantiate()
	root.add_child(scene)
	(scene.get_node(^"EnemyDirector") as EnemyDirector).spawning = false
	return scene


func _end_run(scene: Node3D) -> void:
	paused = false
	root.remove_child(scene)
	scene.queue_free()
	await _frames(2)


func _test_catalog() -> void:
	print("catalog")
	var ids := {}
	var sane := true
	for entry in PermanentCatalog.all():
		ids[entry.id] = true
		var costs: Array = entry.costs
		sane = sane and not costs.is_empty() and not String(entry.name).is_empty() and not String(entry.text).is_empty()
		for i in costs.size():
			sane = sane and costs[i] > 0 and (i == 0 or costs[i] > costs[i - 1])
	_check(PermanentCatalog.all().size() >= 6 and ids.size() == PermanentCatalog.all().size(), "almeno 6 upgrade permanenti con id distinti (%d)" % ids.size())
	_check(sane, "ogni upgrade ha nome, testo e costi crescenti")
	_check(PermanentCatalog.max_level(&"base_health") == 3 and PermanentCatalog.max_level(&"nope") == 0, "livello massimo dal numero di costi")


func _test_profile_rules() -> void:
	print("profile rules")
	var profile: PlayerProfileService = ProfileScript.new()
	profile.profile_path = ""
	_check(profile.scrap == 0 and profile.levels.is_empty() and profile.levels_unlocked == 1, "profilo nuovo: niente rottami, niente upgrade")
	_check(not profile.buy(&"base_health") and profile.level_of(&"base_health") == 0, "senza rottami non si compra")
	profile.bank_run(7, false)
	_check(profile.scrap == 7 and profile.runs == 1 and profile.victories == 0 and profile.levels_unlocked == 1, "una sconfitta incassa i rottami e conta la run")
	_check(profile.cost_of(&"base_health") == 4 and profile.buy(&"base_health"), "primo livello di Telaio rinforzato: 4 rottami")
	_check(profile.scrap == 3 and profile.level_of(&"base_health") == 1 and profile.cost_of(&"base_health") == 8, "rottami scalati, il livello successivo costa 8")
	_check(not profile.can_buy(&"base_health"), "3 rottami non bastano per il secondo livello")
	profile.bank_run(40, true)
	_check(profile.victories == 1 and profile.levels_unlocked == 2, "una vittoria sblocca il livello successivo")
	_check(profile.buy(&"base_health") and profile.buy(&"base_health"), "con i rottami si arriva al massimo")
	_check(profile.cost_of(&"base_health") == -1 and not profile.buy(&"base_health"), "al massimo non si compra oltre")
	_check(not profile.buy(&"nope"), "un id sconosciuto non si compra")
	profile.free()


func _test_persistence() -> void:
	print("persistence")
	_check(_profile().profile_path.is_empty(), "sotto i test il profilo reale non viene letto ne scritto")
	var profile: PlayerProfileService = ProfileScript.new()
	profile.profile_path = TEMP_PATH
	profile.bank_run(30, true)
	profile.buy(&"tool_reach")
	profile.buy(&"cargo")
	profile.buy(&"cargo")
	var scrap_left := profile.scrap
	var loaded: PlayerProfileService = ProfileScript.new()
	_check(loaded.load_profile(TEMP_PATH) == OK, "il profilo salvato si ricarica")
	_check(loaded.scrap == scrap_left and loaded.runs == 1 and loaded.victories == 1 and loaded.levels_unlocked == 2, "rottami e conteggi tornano uguali")
	_check(loaded.level_of(&"tool_reach") == 1 and loaded.level_of(&"cargo") == 2 and loaded.level_of(&"stock") == 0, "upgrade comprati tornano uguali")
	var config := ConfigFile.new()
	config.set_value("profile", "scrap", -50)
	config.set_value("profile", "runs", "molte")
	config.set_value("upgrades", "base_health", 99)
	config.set_value("upgrades", "inventato", 3)
	config.save(TEMP_PATH)
	_check(loaded.load_profile(TEMP_PATH) == OK and loaded.scrap == 0 and loaded.runs == 0, "valori non validi diventano zero")
	_check(loaded.level_of(&"base_health") == 3 and not loaded.levels.has(&"inventato"), "livelli oltre il massimo ridotti, id sconosciuti non applicati")
	# R-19: l'id sconosciuto sopravvive a un salvataggio e il file porta la versione.
	loaded.scrap = 7
	_check(loaded.save_profile() == OK and loaded.last_save_error == OK, "salvataggio atomico riuscito")
	var reread := ConfigFile.new()
	_check(reread.load(TEMP_PATH) == OK and reread.get_value("upgrades", "inventato", 0) == 3
		and reread.get_value("profile", "version", 0) == PlayerProfileService.VERSION and reread.get_value("profile", "scrap", 0) == 7,
		"id sconosciuto conservato e versione scritta")
	_check(not FileAccess.file_exists(TEMP_PATH + ".tmp"), "nessun file temporaneo lasciato in giro")
	# R-18: percorso non scrivibile: errore riportato, non ignorato.
	var broken: PlayerProfileService = ProfileScript.new()
	broken.profile_path = "user://non_esiste_dir/sub/profile.cfg"
	broken.scrap = 1
	_check(broken.save_profile() != OK and broken.last_save_error != OK, "salvataggio impossibile: errore riportato in last_save_error")
	broken.free()
	loaded.load_profile("user://non_esiste_profile.cfg")
	_check(loaded.scrap == 0 and loaded.levels.is_empty(), "file assente: profilo nuovo")
	profile.free()
	loaded.free()


func _test_new_profile_changes_nothing() -> void:
	print("new profile")
	_profile().reset()
	var scene := _start_run()
	await _frames(3)
	var run: ArenaRun = scene.get_node(^"Run")
	var player: PlayerCharacter = scene.get_node(^"Player")
	var companion: Companion = scene.get_node(^"Companion")
	_check(player.max_health == run.tuning.player_max_health and is_zero_approx(player.tool_range_bonus_m), "vita e portata del tool come da tuning")
	_check(companion.capacity == companion.tuning.capacity and companion.carried == companion.tuning.starting_scrap, "cassone come da tuning")
	_check(run.companion_weapon == null and run.progression.level_of(&"companion_turret") == 0, "nessuna torretta")
	await _end_run(scene)


func _test_permanent_upgrades_apply() -> void:
	print("permanent upgrades")
	var profile := _profile()
	profile.reset()
	profile.levels = {&"tool_reach": 1, &"base_health": 2, &"reflexes": 1, &"cargo": 1, &"stock": 1, &"fixed_turret": 1, &"salvage": 1, &"pack_size": 1}
	var scene := _start_run()
	await _frames(3)
	var run: ArenaRun = scene.get_node(^"Run")
	var player: PlayerCharacter = scene.get_node(^"Player")
	var companion: Companion = scene.get_node(^"Companion")
	var field: TerrainField = scene.get_node(^"TerrainField")
	_check(player.max_health == run.tuning.player_max_health + 2 and player.health == player.max_health, "Telaio rinforzato 2: vita %d" % player.max_health)
	_check(is_equal_approx(player.invulnerability_seconds, run.tuning.player_invulnerability + 0.2), "Riflessi: invulnerabilita %.1f s" % player.invulnerability_seconds)
	var reach := Vector2(player.terrain_target.x - player.global_position.x, player.terrain_target.z - player.global_position.z).length()
	_check(is_equal_approx(player.tool_range_bonus_m, 1.2) and absf(reach - (field.tuning.tool_range_m + 1.2)) < 0.05, "Prolunga: il tool arriva a %.1f m" % reach)
	_check(is_equal_approx(player.pack.capacity, field.tuning.pack_capacity_m3 + 20.0), "Zainetto largo: capacita %.0f m3" % player.pack.capacity)
	_check(companion.capacity == companion.tuning.capacity + 2, "Cassone saldato: capacita %d" % companion.capacity)
	_check(companion.carried == companion.tuning.starting_scrap + 2, "Scorta: parte con %d rottami" % companion.carried)
	_check(run.companion_weapon != null and run.companion_weapon.is_inside_tree() and companion.has_node(^"TurretPart"),
		"Torretta fissa: montata e in funzione dall'inizio")
	_check(run.progression.level_of(&"companion_turret") == 1, "la carta Torretta parte dal livello 1")
	_check(run.scrap_out(false) == int(floor(companion.carried * 0.75)), "Paracadute: morendo si salvano tre quarti (%d)" % run.scrap_out(false))
	await _end_run(scene)


func _test_banking_and_workshop_flow() -> void:
	print("banking and workshop")
	var profile := _profile()
	profile.reset()
	profile.scrap = 5
	var scene := _start_run()
	await _frames(3)
	var run: ArenaRun = scene.get_node(^"Run")
	var player: PlayerCharacter = scene.get_node(^"Player")
	var panel: GameOverPanel = scene.get_node(^"GameOverPanel")
	var workshop: WorkshopPanel = scene.get_node(^"WorkshopPanel")
	var audio: RunAudio = scene.get_node(^"RunAudio")
	var expected := run.scrap_out(false)
	player._invulnerable_left = 0.0
	player.take_damage(player.health)
	await _frames(2)
	_check(panel.is_open and not panel.is_victory, "rottamato: schermata di fine livello")
	_check(profile.scrap == 5 + expected and profile.runs == 1, "i rottami salvati vanno in Officina (%d + %d)" % [5, expected])
	_check((panel._summary.text as String).contains("Rottami in Officina\t%d" % profile.scrap), "il riepilogo mostra il totale in Officina")
	_check(not workshop.is_open, "l'Officina resta chiusa finche non la si chiede")
	panel.workshop_requested.emit()
	_check(workshop.is_open and workshop.row_text(&"base_health").contains("0/3"), "dal pulsante si apre l'Officina con il catalogo")
	var bought := [0]
	var refused := [0]
	workshop.purchased.connect(func(_id: StringName) -> void: bought[0] += 1)
	workshop.rejected.connect(func(_id: StringName) -> void: refused[0] += 1)
	var before := profile.scrap
	workshop.press(&"base_health")
	_check(bought[0] == 1 and profile.level_of(&"base_health") == 1 and profile.scrap == before - 4, "comprare scala i rottami e alza il livello")
	_check(workshop.row_text(&"base_health").contains("1/3"), "la riga si aggiorna")
	workshop.press(&"fixed_turret")
	_check(refused[0] == 1 and profile.level_of(&"fixed_turret") == 0 and workshop.row_text(&"fixed_turret").contains("ne mancano"), "senza rottami l'acquisto e rifiutato e la riga dice quanti ne mancano")
	_check(audio.play_count(&"upgrade_chosen") >= 1 and audio.play_count(&"tool_reject") >= 1, "acquisto e rifiuto si sentono")
	var closed := [false]
	workshop.closed.connect(func() -> void: closed[0] = true)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await _frames(2)
	_check(closed[0] and not workshop.is_open and panel.is_open, "B chiude l'Officina e torna alla schermata di fine livello")
	await _end_run(scene)
	# R-20: abbandonare dalla pausa incassa la quota di morte.
	scene = _start_run()
	await _frames(3)
	run = scene.get_node(^"Run")
	var companion: Companion = scene.get_node(^"Companion")
	companion.add_capacity(0, 4)
	var abandon_expected := run.scrap_out(false)
	var scrap_before := profile.scrap
	var pause_menu := root.get_node("PauseMenu")
	pause_menu.call(&"pause_game")
	await _frames(1)
	run.abandon_run()
	_check(run.is_over and profile.scrap == scrap_before + abandon_expected and abandon_expected > 0,
		"abbandono: incassata la quota di morte (%d)" % abandon_expected)
	run.abandon_run()
	_check(profile.scrap == scrap_before + abandon_expected, "un secondo abbandono non incassa due volte")
	pause_menu.call(&"resume_game")
	await _end_run(scene)
	# Il livello successivo parte con cio che si e comprato.
	scene = _start_run()
	await _frames(3)
	player = scene.get_node(^"Player")
	run = scene.get_node(^"Run")
	_check(player.max_health == run.tuning.player_max_health + 1, "la run successiva parte con l'upgrade comprato")
	await _end_run(scene)
	profile.reset()
