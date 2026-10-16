extends SceneTree
## Test della logica di progressione (PROGRESSION_SPEC, regole 1-4). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/run_progression_tests.gd

var _failures := 0


func _initialize() -> void:
	_test_xp_curve()
	_test_offer_is_distinct_and_varied()
	_test_seed_is_reproducible()
	_test_pity_guarantee()
	_test_maxed_upgrades_disappear()
	_test_caravan_cards_need_caravan()
	_test_module_requirements()
	_test_rarity_weights()
	_test_class_decks()
	_test_weapon_card_first()
	_test_owned_card_of_other_deck()
	_test_fusion_card_wins()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _new(run_seed: int) -> RunProgression:
	var progression := RunProgression.new()
	progression.setup(run_seed)
	return progression


func _ids(offer: Array[Dictionary]) -> String:
	return ",".join(PackedStringArray(offer.map(func(u: Dictionary) -> String: return str(u.id))))


## D-092: con una classe compaiono solo le carte comuni e quelle del suo mazzo.
func _test_class_decks() -> void:
	print("class decks")
	var p := _new(21)
	p.class_id = &"engineer"
	var foreign := 0
	var own := 0
	for i in 500:
		for u in p.roll_offer():
			if u.deck != &"common" and u.deck != &"engineer":
				foreign += 1
			if u.deck == &"engineer":
				own += 1
	_check(foreign == 0, "nessuna carta di un'altra classe in 500 offerte")
	_check(own > 0, "le carte dell'Ingegnere compaiono")


## D-092: se ci sono carte arma la prima carta e un'arma; le altre restano carte normali.
func _test_weapon_card_first() -> void:
	print("weapon card first")
	var p := _new(22)
	p.class_id = &"engineer"
	var card := {id = &"w:level:nailgun", name = "Chiodatrice", category = &"weapon", rarity = UpgradeCatalog.Rarity.COMMON,
		max_level = 0, requires = "", deck = &"engineer", text = "", weapon_id = &"nailgun", kind = &"level", shown_level = 1}
	p.weapon_cards = func() -> Array[Dictionary]: return [card] as Array[Dictionary]
	var first := true
	var others_plain := true
	for i in 200:
		var offer := p.roll_offer()
		first = first and offer.size() == 3 and offer[0].id == &"w:level:nailgun"
		others_plain = others_plain and not offer.slice(1).any(func(u: Dictionary) -> bool: return String(u.id).begins_with("w:"))
	_check(first, "la carta arma e sempre la prima")
	_check(others_plain, "le altre due non sono carte arma")
	var none := _new(23)
	none.weapon_cards = func() -> Array[Dictionary]: return [] as Array[Dictionary]
	_check(none.roll_offer().size() == 3, "senza carte arma restano tre carte normali")


## Review: una carta gia posseduta resta potenziabile anche se e del mazzo di un'altra classe
## (prima la Torretta fissa dell'Officina, che dal task 4 di D-093 e una macchina: qui lo Scavo
## esplosivo del Guastatore, senza requisiti).
func _test_owned_card_of_other_deck() -> void:
	print("owned card of other deck")
	var blast: Array[Dictionary] = UpgradeCatalog.all().filter(func(u: Dictionary) -> bool: return u.id == &"dig_blast")
	_check(blast.size() == 1 and blast[0].deck == &"sapper" and blast[0].requires == "" and blast[0].max_level > 1,
		"lo Scavo esplosivo e del mazzo del Guastatore, senza requisiti")
	var p := _new(24)
	p.class_id = &"engineer"
	var unseen := true
	for i in 300:
		for u in p.roll_offer():
			unseen = unseen and u.id != &"dig_blast"
	_check(unseen, "non posseduto, l'Ingegnere non lo vede")
	p.levels[&"dig_blast"] = 1
	var seen := false
	for i in 300:
		for u in p.roll_offer():
			seen = seen or u.id == &"dig_blast"
	_check(seen, "lo Scavo esplosivo gia posseduto si potenzia anche da Ingegnere")


## D-092: la carta fusione, quando c'e, e sempre la carta arma dell'offerta.
func _test_fusion_card_wins() -> void:
	print("fusion card wins")
	var p := _new(25)
	var level := {id = &"w:level:jackhammer", name = "Martello", category = &"weapon", rarity = UpgradeCatalog.Rarity.COMMON,
		max_level = 0, requires = "", deck = &"common", text = "", weapon_id = &"jackhammer", kind = &"level", shown_level = 2}
	var fusion := {id = &"w:fusion:site_blade", name = "Ruspa a dischi", category = &"weapon", rarity = UpgradeCatalog.Rarity.LEGENDARY,
		max_level = 0, requires = "", deck = &"common", text = "", weapon_id = &"site_blade", kind = &"fusion", shown_level = 5}
	p.weapon_cards = func() -> Array[Dictionary]: return [level, fusion] as Array[Dictionary]
	var always := true
	for i in 100:
		always = always and p.roll_offer()[0].id == &"w:fusion:site_blade"
	_check(always, "la fusione e sempre la prima carta")


func _test_xp_curve() -> void:
	print("xp curve")
	var p := _new(1)
	_check(p.xp_to_next() == 5, "primo livello a 5 esperienza")
	_check(p.add_xp(5) == 1 and p.level == 2 and p.xp == 0, "5 esperienza: livello 2")
	_check(p.add_xp(20) == 2 and p.level == 4 and p.xp == 1, "20 esperienza: due livelli, resto 1 (livello %d, xp %d)" % [p.level, p.xp])


func _test_offer_is_distinct_and_varied() -> void:
	print("offer")
	var p := _new(7)
	var ok_distinct := true
	var ok_categories := true
	for i in 200:
		var offer := p.roll_offer()
		var ids := {}
		var categories := {}
		for u in offer:
			ids[u.id] = true
			categories[u.category] = true
		ok_distinct = ok_distinct and offer.size() == 3 and ids.size() == 3
		ok_categories = ok_categories and categories.size() == 3
	_check(ok_distinct, "sempre tre carte diverse")
	_check(ok_categories, "sempre tre categorie diverse (regola 3)")


func _test_seed_is_reproducible() -> void:
	print("seed")
	var a := _new(12345)
	var b := _new(12345)
	var c := _new(54321)
	var same := true
	var different := false
	for i in 20:
		var ia := _ids(a.roll_offer())
		same = same and ia == _ids(b.roll_offer())
		different = different or ia != _ids(c.roll_offer())
	_check(same, "stesso seed, stesse carte")
	_check(different, "seed diverso, carte diverse")


func _test_pity_guarantee() -> void:
	print("pity")
	var longest := 0
	for run_seed in 30:
		var p := _new(run_seed)
		var streak := 0
		for i in 60:
			var offer := p.roll_offer()
			if offer.any(func(u: Dictionary) -> bool: return u.rarity >= UpgradeCatalog.Rarity.RARE):
				streak = 0
			else:
				streak += 1
				longest = maxi(longest, streak)
	_check(longest <= 4, "mai piu di 4 scelte di fila senza Rari (massimo %d)" % longest)


func _test_maxed_upgrades_disappear() -> void:
	print("max level")
	var p := _new(3)
	p.levels[&"reach"] = 3
	var seen := false
	for i in 200:
		for u in p.roll_offer():
			seen = seen or u.id == &"reach"
	_check(not seen, "upgrade al massimo mai offerto (regola 2)")
	_check(p.choose(&"boots") == 1 and p.choose(&"boots") == 2, "choose incrementa il livello")
	# R-15: i testi delle carte nascono dai valori, nessun segnaposto resta vuoto.
	var unresolved := 0
	for entry in UpgradeCatalog.all():
		var text := UpgradeCatalog.describe(entry)
		if text.contains("{") or text.contains("}"):
			unresolved += 1
	_check(unresolved == 0 and UpgradeCatalog.describe(UpgradeCatalog.all().filter(func(u: Dictionary) -> bool: return u.id == &"boots")[0]).contains("10%"),
		"testi delle carte formattati dai valori del catalogo (%d non risolti)" % unresolved)
	_check(is_equal_approx(UpgradeCatalog.value(&"dig_blast", &"radius"), 2.4) and UpgradeCatalog.value(&"inesistente", &"x", 3.0) == 3.0,
		"UpgradeCatalog.value legge i valori e ha un default")


func _test_caravan_cards_need_caravan() -> void:
	print("requires")
	var p := _new(4)
	p.has_caravan = false
	p.module_count = func(_id: StringName) -> int: return 1
	var seen := false
	for i in 200:
		for u in p.roll_offer():
			seen = seen or u.category == &"companion"
	_check(not seen, "senza carovana nessuna carta della carovana (regola 2), nemmeno coi moduli contati")
	p.has_caravan = true
	for i in 200:
		for u in p.roll_offer():
			seen = seen or u.category == &"companion"
	_check(seen, "con la carovana e i suoi moduli le carte della carovana compaiono")


## Task 4 di D-093: `requires` e "", "caravan" o "module:<id>"; una carta di un modulo compare
## solo se la carovana ha almeno una macchina con quel modulo (`module_count`).
func _test_module_requirements() -> void:
	print("module requirements")
	var malformed := UpgradeCatalog.all().filter(func(u: Dictionary) -> bool:
		var requires: String = u.requires
		return not (requires == "" or requires == "caravan"
			or (requires.begins_with("module:") and MachineCatalog.MODULES.has(StringName(requires.trim_prefix("module:"))))))
	_check(malformed.is_empty(), "ogni requires del catalogo e valido (%s)" % [malformed.map(func(u: Dictionary) -> StringName: return u.id)])
	var module_cards: Array[StringName] = [&"turret_rate", &"magnet_range", &"beacon_range", &"companion_cargo"]
	var p := _new(5)
	var ids := func() -> Array: return p.eligible().map(func(u: Dictionary) -> StringName: return u.id)
	var none_of := func(list: Array) -> bool: return module_cards.all(func(id: StringName) -> bool: return not list.has(id))
	_check(none_of.call(ids.call()) and ids.call().has(&"tuned_engine"),
		"module_count non impostata: nessuna carta di modulo, Motore truccato (requires caravan) si")
	p.module_count = func(_id: StringName) -> int: return 0
	_check(none_of.call(ids.call()), "zero macchine col modulo: nessuna carta di modulo")
	p.module_count = func(id: StringName) -> int: return 1 if id == &"turret" else 0
	var with_turret: Array = ids.call()
	_check(with_turret.has(&"turret_rate") and not with_turret.has(&"magnet_range") and not with_turret.has(&"beacon_range")
		and not with_turret.has(&"companion_cargo"), "una Torretta: Torretta veloce si, le carte degli altri moduli no")
	var asked: Array[StringName] = []
	p.module_count = func(id: StringName) -> int:
		asked.append(id)
		return 1
	var all_modules: Array = ids.call()
	_check(module_cards.all(func(id: StringName) -> bool: return all_modules.has(id)) and asked.has(&"turret") and asked.has(&"cargo"),
		"un modulo per tipo: tutte le carte di modulo, chiesti per id (%s)" % [asked])
	_check(p.fillers().any(func(u: Dictionary) -> bool: return u.id == &"lucky_scrap"), "e il Rottame di fortuna fra le ripetibili")
	p.has_caravan = false
	_check(none_of.call(ids.call()) and not ids.call().has(&"tuned_engine") and not p.fillers().any(func(u: Dictionary) -> bool: return u.id == &"lucky_scrap"),
		"senza carovana nessuna carta della carovana, anche coi moduli contati")
	p.has_caravan = true
	p.module_count = func(id: StringName) -> int: return 1 if id == &"turret" else 0
	p.levels[&"turret_rate"] = 2
	_check(not ids.call().has(&"turret_rate"), "Torretta veloce al livello 2 (il massimo) esce")


## Regola 1 sulla prima carta, con la garanzia spenta: circa 60/27/10 rinormalizzati
## sulle tre rarita presenti (60/97, 27/97, 10/97).
func _test_rarity_weights() -> void:
	print("weights")
	var p := _new(99)
	p.pity_level_ups = 1000000
	var counts := [0, 0, 0, 0]
	var total := 6000
	for i in total:
		counts[p.roll_offer()[0].rarity] += 1
	var common := float(counts[0]) / total
	var rare := float(counts[2]) / total
	_check(absf(common - 60.0 / 97.0) < 0.03, "comuni %.3f (atteso %.3f)" % [common, 60.0 / 97.0])
	_check(absf(rare - 10.0 / 97.0) < 0.02, "rari %.3f (atteso %.3f)" % [rare, 10.0 / 97.0])
