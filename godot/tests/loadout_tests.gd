extends SceneTree
## Slot delle armi (spec D-092, par. 3 e 8): kit di classe, livelli, bivi, attive su tasto.
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/loadout_tests.gd

var _failures := 0
var _root: Node3D
var _director: EnemyDirector


func _initialize() -> void:
	_root = Node3D.new()
	get_root().add_child(_root)
	_director = EnemyDirector.new()
	_director.spawning = false
	_root.add_child(_director)
	await process_frame
	await _test_engineer_kit()
	await _test_class_without_weapons()
	await _test_levels_and_branches()
	await _test_actives()
	await _test_manual_aim()
	_test_class_option()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


## Loadout con la chiodatrice "di scena" adottata, come fa ArenaRun.
func _loadout(class_id: StringName) -> WeaponLoadout:
	var shooter := Node3D.new()
	_root.add_child(shooter)
	var scene_weapon := AutoWeapon.new()
	scene_weapon.shooter = shooter
	scene_weapon.director = _director
	_root.add_child(scene_weapon)
	var loadout := WeaponLoadout.new()
	loadout.player = shooter
	loadout.director = _director
	_root.add_child(loadout)
	loadout.adopt(scene_weapon)
	loadout.setup_class(class_id)
	await process_frame
	return loadout


func _clear() -> void:
	for child in _root.get_children():
		if child != _director:
			child.queue_free()
	await process_frame


func _test_engineer_kit() -> void:
	print("kit dell'Ingegnere")
	var loadout := await _loadout(&"engineer")
	_check(loadout.has_weapon(&"nailgun") and loadout.has_weapon(&"seismic_stake"), "chiodatrice e picchetto")
	_check(loadout.free_slots(&"auto") == 2 and loadout.free_slots(&"active") == 1, "liberi 2 slot automatici e 1 attivo")
	_check(loadout.weapon(&"nailgun") == loadout.adopted, "la chiodatrice e quella della scena, non una copia")
	_check(loadout.autos().size() == 1 and loadout.actives().size() == 1, "una automatica e una attiva")
	_check(loadout.level_of(&"nailgun") == 1 and loadout.level_of(&"welder") == 0, "livelli: 1 posseduta, 0 assente")
	await _clear()


func _test_class_without_weapons() -> void:
	print("classe senza armi implementate")
	var loadout := await _loadout(&"sapper")
	_check(loadout.autos().is_empty() and loadout.actives().is_empty(), "nessuna arma")
	_check(loadout.adopted.process_mode == Node.PROCESS_MODE_DISABLED and not loadout.adopted.visible, "la chiodatrice della scena e spenta")
	_check(loadout.add(&"missing") == null, "un'arma sconosciuta non si aggiunge")
	await _clear()


func _test_levels_and_branches() -> void:
	print("livelli e bivi")
	var loadout := await _loadout(&"engineer")
	_check(loadout.level_up(&"nailgun") == 2, "liv. 2")
	_check(loadout.needs_branch(&"nailgun"), "il prossimo livello e un bivio")
	_check(loadout.level_up(&"nailgun") == 2, "un bivio non si salta con un livello semplice")
	loadout.choose_branch(&"nailgun", &"a")
	var nailgun := loadout.weapon(&"nailgun")
	_check(nailgun.level == 3 and nailgun.branches.get(3) == &"a", "bivio scelto: liv. 3, trasformazione A")
	_check(loadout.level_up(&"nailgun") == 4, "liv. 4")
	loadout.choose_branch(&"nailgun", &"b")
	_check(nailgun.level == 5 and nailgun.branches.get(5) == &"b", "liv. 5, trasformazione B")
	_check(loadout.level_up(&"nailgun") == 5 and not loadout.needs_branch(&"nailgun"), "oltre il 5 non sale")
	await _clear()


func _test_actives() -> void:
	print("attive")
	var loadout := await _loadout(&"engineer")
	var fired: Array[int] = []
	loadout.active_triggered.connect(func(slot: int, _at: Vector3) -> void: fired.append(slot))
	_check(loadout.trigger_active(0), "slot 1 carico: parte")
	_check(not loadout.trigger_active(0), "subito dopo e scarico")
	_check(not loadout.trigger_active(1), "slot 2 vuoto: niente")
	_check(fired == ([0] as Array[int]), "segnale solo per il colpo partito")
	var stake := loadout.actives()[0]
	stake.cooldown_left = 0.0
	paused = true
	_check(not loadout.trigger_active(0) and stake.cooldown_left == 0.0, "in pausa non parte e non consuma la ricarica")
	paused = false
	await _clear()


func _test_class_option() -> void:
	print("riga di comando")
	_check(RunLaunchOptions.class_id(PackedStringArray(["--class=sapper"])) == &"sapper", "--class=sapper sceglie il Guastatore")
	_check(RunLaunchOptions.class_id(PackedStringArray([])) == &"", "senza opzione: vuoto")
	_check(RunLaunchOptions.wants_autostart(PackedStringArray(["--class=weeder"])), "--class= avvia subito il livello")


func _test_manual_aim() -> void:
	print("mira")
	var loadout := await _loadout(&"engineer")
	loadout.set_manual_aim(true)
	_check(loadout.autos().all(func(w: Weapon) -> bool: return w.manual_aim) and loadout.actives().all(func(w: Weapon) -> bool: return w.manual_aim),
		"la mira manuale arriva a tutte le armi")
	var added := loadout.add(&"nailgun")
	_check(added == null, "un'arma gia posseduta non si aggiunge due volte")
	await _clear()
