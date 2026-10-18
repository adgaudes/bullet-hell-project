extends SceneTree
## Fusione delle macchine (D-093, piano B): taglie, vita, velocita, forza, costi, anteprime di
## fusione e sgancio, sei combinazioni e valori di partenza in CaravanTuning. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/fusion_tests.gd

const TUNING_PATH := "res://resources/tuning/caravan_default.tres"

var _failures := 0
var t: CaravanTuning


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	if not OS.get_environment("PROTOTYPE01_SEED").is_valid_int():
		OS.set_environment("PROTOTYPE01_SEED", "20261014")
	t = load(TUNING_PATH) as CaravanTuning
	_check(t != null, "caravan_default.tres si carica come CaravanTuning")
	if t != null:
		_test_sizes()
		_test_costs()
		_test_combos()
		_test_preview()
		_test_tuning()
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


func _test_sizes() -> void:
	print("sizes")
	var sizes := [0, 1, 1, 2, 2, 3]; var health := [6, 15, 23, 36, 45, 63]
	var speed := [5.0, 4.5, 4.5, 4.0, 4.0, 3.5]; var power := [1.0, 1.15, 1.30, 1.45, 1.60, 1.75]
	for n in range(1, 7):
		_check(MachineFusion.size_of(n, t) == sizes[n - 1], "taglia di %d moduli" % n)
		_check(MachineFusion.max_health_of(n, t) == health[n - 1], "vita di %d moduli" % n)
		_check(is_equal_approx(t.max_speed * MachineFusion.speed_factor_of(n, t), speed[n - 1]), "velocita di %d" % n)
		_check(is_equal_approx(MachineFusion.power_of(n, t), power[n - 1]), "forza di %d" % n)
	_check(MachineFusion.SIZE_NAMES[3] == "Colosso", "nomi delle taglie")
	var scales := [1.0, 1.25, 1.25, 1.5, 1.5, 1.8]
	for n in range(1, 7):
		_check(is_equal_approx(MachineFusion.model_scale_of(n, t), scales[n - 1]), "scala del modello di %d moduli" % n)


func _test_costs() -> void:
	print("costs")
	_check(MachineFusion.fuse_cost(1, t) == 1 and MachineFusion.fuse_cost(3, t) == 3 and MachineFusion.detach_cost(t) == 1, "costi")
	var total := 0
	for i in 5: total += MachineFusion.fuse_cost(1, t)
	_check(total == 5, "sei piccole in un colosso: 5 rottami")


func _test_combos() -> void:
	print("combos")
	_check(MachineCatalog.COMBOS.size() == 6 and MachineCatalog.find_combo(&"dozer").name == "Ruspa", "sei combinazioni coi nomi della spec")
	_check(MachineCatalog.find_combo(&"extractor").parts == [&"drill", &"magnet"], "parti dell'Estrattore")
	_check(MachineCatalog.combos_of([&"magnet", &"drill"]) == [&"extractor"], "l'ordine dei moduli non conta")
	_check(MachineCatalog.combos_of([&"turret", &"beacon", &"siren"]) == [&"reflector", &"trap"], "due combinazioni in una macchina")
	_check(MachineCatalog.combos_of([&"drill", &"shovel", &"cargo"]) == [&"mobile_mixer", &"dozer"], "Betoniera e Ruspa")
	_check(MachineCatalog.combos_of([&"turret", &"turret"]).is_empty() and MachineCatalog.find_combo(&"nope").is_empty(), "nessuna")
	var ids: Array[StringName] = []
	for combo in MachineCatalog.combos():
		ids.append(combo.id)
	_check(ids == MachineCatalog.COMBOS and is_same(MachineCatalog.combos(), MachineCatalog.combos()), "voci nell'ordine di COMBOS, costruite una volta")
	_check(MachineCatalog.find_combo(&"trap").text == "Chi e attirato prende doppio danno dalla Torretta.", "testo della Trappola")
	_check(MachineCatalog.combos_of([&"drill", &"magnet", &"magnet"]) == [&"extractor"], "un modulo doppio non ripete la combinazione")


func _test_preview() -> void:
	print("preview")
	var p := MachineFusion.preview_fuse([&"drill"], 6, 6, [&"magnet"], 3, 6, t)
	_check(p.size == 1 and p.max_health == 15 and p.health == 11 and is_equal_approx(p.speed, 4.5), "anteprima: media, 11/15, 4,5 m/s")
	_check(p.combos == [&"extractor"] and p.new_combos == [&"extractor"] and p.cost == 1 and p.allowed, "anteprima: combinazione nuova, costo 1")
	var d := MachineFusion.preview_detach([&"turret", &"beacon", &"siren"], 2, 23, 23, t)
	_check(d.source.max_health == 15 and d.source.health == 15 and d.detached.max_health == 6, "sgancio: 15/15 e 6/6")
	_check(d.lost_combos == [&"trap"] and d.source.combos == [&"reflector"] and d.cost == 1, "sgancio: Trappola persa")
	_check(not MachineFusion.preview_detach([&"cargo"], 0, 6, 6, t).allowed, "una piccola non si sgancia")
	_check(not MachineFusion.preview_fuse([&"cargo", &"turret", &"magnet"], 23, 23, [&"drill", &"shovel", &"siren", &"welder"], 36, 36, t).allowed, "oltre 6 moduli no")
	var q := MachineFusion.preview_fuse([&"drill", &"magnet"], 15, 15, [&"shovel"], 6, 6, t)
	_check(q.new_combos == [&"dozer"] and q.combos == [&"extractor", &"dozer"] and q.modules == [&"drill", &"magnet", &"shovel"], "anteprima: solo la Ruspa e nuova, la seconda entra nella prima")


func _test_tuning() -> void:
	print("tuning")
	_check(t.size_min_modules == PackedInt32Array([1, 2, 4, 6]) and is_equal_approx(t.power_per_extra_module, 0.15), "taglie e forza")
	_check(is_equal_approx(t.pad_boss_fraction, 0.5) and t.pad_warning_seconds == 15.0 and t.pad_distance_min == 20.0 and t.pad_distance_max == 30.0 and t.pad_cells == 4, "piazzola")
	_check(t.fuse_cost_per_module == 1 and t.detach_cost_per_module == 1 and t.max_modules_per_machine == 6, "costi e massimo per macchina")
