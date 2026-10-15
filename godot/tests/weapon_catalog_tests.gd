extends SceneTree
## Dati delle armi e delle classi (spec D-092, par. 3-5). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/weapon_catalog_tests.gd

var _failures := 0


func _initialize() -> void:
	_test_nailgun_stats()
	_test_branches()
	_test_classes()
	_test_common_kit()
	_test_upgrade_decks()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _test_nailgun_stats() -> void:
	print("nailgun stats")
	_check(not WeaponCatalog.find(&"nailgun").is_empty(), "la chiodatrice e nel catalogo")
	_check(is_equal_approx(WeaponCatalog.stat(&"nailgun", &"fire_interval", 1, {}), 0.5), "liv. 1: un colpo ogni 0,5 s")
	_check(is_equal_approx(WeaponCatalog.stat(&"nailgun", &"fire_interval", 2, {}), 0.4), "liv. 2: cadenza +25%")
	_check(WeaponCatalog.stat(&"nailgun", &"pierce", 4, {3: &"a"}) == 1.0, "liv. 4: +1 trapassato")
	_check(WeaponCatalog.stat(&"nailgun", &"damage", 1, {}) == 1.0, "1 danno")
	_check(WeaponCatalog.stat(&"nailgun", &"bounces", 5, {3: &"a", 5: &"a"}) == 1.0, "Rimbalzanti al 5: un rimbalzo")
	_check(WeaponCatalog.stat(&"nailgun", &"bounces", 5, {3: &"a", 5: &"b"}) == 0.0, "Incandescenti al 5: nessun rimbalzo")
	_check(WeaponCatalog.stat(&"missing", &"damage", 1, {}) == 0.0, "arma sconosciuta: 0")
	# Review I-2: stat() gira a ogni passo, il catalogo non va ricostruito a ogni chiamata.
	_check(is_same(WeaponCatalog.find(&"nailgun"), WeaponCatalog.find(&"nailgun")), "il catalogo e costruito una volta sola")


func _test_branches() -> void:
	print("branches")
	var options := WeaponCatalog.branch_options(&"nailgun", 3)
	_check(options.size() == 2, "due opzioni al livello 3")
	_check(is_equal_approx(WeaponCatalog.stat(&"nailgun", &"fire_interval", 3, {3: &"a"}), 0.2), "Raffica: cadenza x2 sopra il liv. 2")
	_check(is_equal_approx(WeaponCatalog.stat(&"nailgun", &"fire_interval", 3, {3: &"b"}), 0.7), "Chiodi da ponte: un colpo ogni 0,7 s")
	_check(WeaponCatalog.stat(&"nailgun", &"damage", 3, {3: &"b"}) == 2.0, "Chiodi da ponte: 2 danni")
	_check(WeaponCatalog.branch_options(&"nailgun", 2).is_empty(), "nessun bivio al livello 2")
	_check(WeaponCatalog.branch_options(&"seismic_stake", 5).size() == 2, "il picchetto ha il bivio al 5")
	for entry in WeaponCatalog.all():
		if entry.slot == &"fusion":
			continue
		for at in WeaponCatalog.BRANCH_LEVELS:
			_check(WeaponCatalog.branch_options(entry.id, at).size() == 2, "%s: due bivi al %d" % [entry.id, at])


## Piano 2: kit comune (spec par. 4.5) e fusioni comuni.
func _test_common_kit() -> void:
	print("common kit")
	for id in [&"site_blade", &"jackhammer", &"ram", &"cement_mixer"]:
		var entry := WeaponCatalog.find(id)
		_check(not entry.is_empty() and entry.deck == &"common" and int(entry.unlock_cost) > 0, "%s: comune, da sbloccare" % id)
	_check(WeaponCatalog.find(&"site_blade").slot == &"auto" and WeaponCatalog.find(&"ram").slot == &"active", "Lama automatica, Ariete attiva")
	_check(WeaponCatalog.find(&"site_blade").partner == &"ram" and WeaponCatalog.find(&"jackhammer").partner == &"cement_mixer", "coppie di fusione")
	_check(WeaponCatalog.fusion_of(&"site_blade") == &"disc_dozer" and WeaponCatalog.fusion_of(&"jackhammer") == &"compactor", "fusioni delle automatiche")
	_check(WeaponCatalog.fusion_of(&"ram") == &"" and WeaponCatalog.fusion_of(&"missing") == &"", "solo le automatiche hanno una fusione")
	_check(WeaponCatalog.find(&"disc_dozer").slot == &"fusion" and WeaponCatalog.find(&"compactor").parts == [&"jackhammer", &"cement_mixer"], "voci delle fusioni")
	_check(is_equal_approx(WeaponCatalog.stat(&"site_blade", &"disc_radius", 3, {3: &"b"}), 0.64), "Lama dentata: raggio x1,6")
	_check(is_equal_approx(WeaponCatalog.stat(&"jackhammer", &"wave_radius", 2, {}), 3.5), "Martello liv. 2: onda 3,5 m")
	_check(WeaponCatalog.stat(&"ram", &"charge_distance", 3, {3: &"a"}) == 12.0, "Rincorsa: 12 m")
	_check(WeaponCatalog.stat(&"cement_mixer", &"block_seconds", 4, {3: &"a"}) == 4.0, "Betoniera liv. 4: blocco 4 s")


func _test_classes() -> void:
	print("classes")
	_check(ClassCatalog.all().size() == 4, "quattro classi")
	_check(ClassCatalog.start_weapons(&"engineer") == ([&"nailgun", &"seismic_stake"] as Array[StringName]), "kit dell'Ingegnere")
	_check(ClassCatalog.start_weapons(&"sapper").is_empty(), "kit del Guastatore non ancora implementato: vuoto")
	_check(ClassCatalog.find(&"nobody").is_empty(), "classe sconosciuta: vuota")


func _test_upgrade_decks() -> void:
	print("upgrade decks")
	var ids := UpgradeCatalog.all().map(func(u: Dictionary) -> StringName: return u.id)
	_check(not ids.has(&"nail_rate") and not ids.has(&"nail_pierce") and not ids.has(&"nail_spread"), "carte nail_* tolte")
	var valid := [&"common", &"engineer", &"sapper", &"mechanic", &"weeder"]
	_check(UpgradeCatalog.all().all(func(u: Dictionary) -> bool: return valid.has(u.get(&"deck", &""))), "ogni carta ha un mazzo valido")
	var engineer := UpgradeCatalog.all().filter(func(u: Dictionary) -> bool: return u.get(&"deck") == &"engineer")
	_check(engineer.size() == 2, "mazzo Ingegnere: Pala larga e Argini spinati")
	var mechanic := UpgradeCatalog.all().filter(func(u: Dictionary) -> bool: return u.get(&"deck") == &"mechanic")
	_check(mechanic.size() == 2, "mazzo Meccanico: Torretta e Faro")
	var sapper := UpgradeCatalog.all().filter(func(u: Dictionary) -> bool: return u.get(&"deck") == &"sapper")
	_check(sapper.size() == 1, "mazzo Guastatore: Scavo esplosivo")
