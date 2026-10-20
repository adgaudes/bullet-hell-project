extends SceneTree
## Colosso pilotato, eventi e relitti (D-093, piano C): valori di partenza in CaravanTuning e forza
## a bordo in MachineFusion. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/colossus_tests.gd

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
		_test_tuning()
		_test_power()
		# Sezioni dei task 2-7, in ordine: _test_caravan, _test_relics, _test_events,
		# _test_pilot, _test_mechanic, _test_workshop (tutte con await).
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


func _test_tuning() -> void:
	print("tuning")
	_check(is_equal_approx(t.pilot_hold_seconds, 0.5) and is_equal_approx(t.pilot_mount_range, 2.5), "tenuta e portata della salita")
	_check(is_equal_approx(t.pilot_power_bonus, 0.5) and is_equal_approx(t.pilot_speed_factor, 0.7), "+50% ai moduli, -30% di velocita")
	_check(is_equal_approx(t.pilot_fuel_interval, 10.0) and t.pilot_fuel_cost == 1 and is_equal_approx(t.pilot_eject_below, 0.3), "carburante e sbalzo")
	_check(t.pilot_trample_damage == 2 and is_equal_approx(t.pilot_aim_reach, 3.0) and is_equal_approx(t.pilot_forced_retreat_seconds, 6.0), "travolgere, mira, ritirata forzata")
	_check(t.quake_detach_count == 1 and t.train_detach_count == 1 and is_equal_approx(t.train_throw_min, 6.0) and is_equal_approx(t.train_throw_max, 8.0), "eventi")
	_check(is_equal_approx(t.relic_pickup_range, 2.0) and t.module_limit == 6, "relitto a 2 m; il limite del tuning resta 6")


func _test_power() -> void:
	print("power")
	_check(is_equal_approx(MachineFusion.power_of(6, t), 1.75) and is_equal_approx(MachineFusion.power_of(6, t, true), 2.625), "forza del colosso: 1,75 autonomo, 2,625 pilotato")
	_check(is_equal_approx(MachineFusion.power_of(1, t, true), 1.5), "una piccola pilotata (solo logica) varrebbe 1,5")
	_check(is_equal_approx(MachineFusion.pilot_speed(6.0, t), 4.2), "6 m/s a piedi: 4,2 a bordo")
