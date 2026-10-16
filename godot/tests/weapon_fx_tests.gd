extends SceneTree
## Effetti delle armi (D-092, piano 5, task 4): per ogni arma e fusione, con nemici davanti,
## nasce almeno un effetto nel gruppo `weapon_fx`; spenta l'arma, dopo 2 s non ne resta nessuno.
## Le fusioni devono mostrare anche un effetto proprio (meta `fx_fusion`). Il tetto di WeaponFx
## regge a molte armi insieme.
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/weapon_fx_tests.gd

const SmokeTestScene := preload("res://scenes/main/smoke_test.tscn")

var _failures := 0
var _scene: Node3D
var _player: PlayerCharacter
var _director: EnemyDirector
var _field: TerrainField
var _queue: TerrainWriteQueue


func _initialize() -> void:
	_scene = SmokeTestScene.instantiate()
	root.add_child(_scene)
	_player = _scene.get_node(^"Player")
	_field = _scene.get_node(^"TerrainField")
	_director = EnemyDirector.new()
	_director.spawning = false
	_director.terrain_field = _field
	_director.tuning = RunTuning.new()
	_director.tuning.gnaw_delay_s = 999.0
	_scene.add_child(_director)
	_queue = TerrainWriteQueue.new()
	_queue.terrain_field = _field
	_scene.add_child(_queue)
	await _seconds(0.6)
	for case in _cases():
		await _test_case(case)
	await _test_cap()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _seconds(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _fx_count() -> int:
	return _director.get_tree().get_node_count_in_group(WeaponFx.GROUP)


## Giocatore fermo al centro rivolto verso -Z, terreno alla base, nemici fermi e robusti: un
## anello a 2,2 m (le falci, l'onda) e un gruppo a 4-5 m davanti (le attive, i lanci).
func _reset() -> void:
	_queue.clear()
	_field.begin_batch()
	_field.reset_to_base(Vector3.ZERO, Vector2(30.0, 30.0))
	_field.end_batch()
	_director.player = null
	_player.global_position = Vector3(0.0, _field.height_at(Vector3.ZERO) + 1.0, 0.0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.set_max_health(1000)
	await _seconds(0.3)
	for i in 8:
		var a := TAU * i / 8.0
		_enemy(Vector3(cos(a), 0.0, sin(a)) * 2.2)
	for p: Vector3 in [Vector3(0, 0, -4), Vector3(0.6, 0, -4.4), Vector3(-0.6, 0, -4.2), Vector3(0.2, 0, -5), Vector3(-0.3, 0, -4.8)]:
		_enemy(p)


func _enemy(offset: Vector3) -> Enemy:
	var enemy := _director.spawn_at(_player.global_position + offset)
	enemy.health = 5000
	enemy.max_health = 5000
	enemy.speed_scale = 0.0
	return enemy


func _setup(w: Weapon, id: StringName, fusion: StringName) -> Weapon:
	w.weapon_id = id
	w.shooter = _player
	w.director = _director
	w.terrain_field = _field
	if &"write_queue" in w:
		w.set(&"write_queue", _queue)
	_scene.add_child(w)
	if fusion != &"":
		w.fusion_id = fusion
		w.set_level(WeaponCatalog.MAX_LEVEL)
	return w


## Armi e fusioni: {id, fusion, make (Callable -> Weapon), active}. Le fusioni anticipano il
## proprio colpo speciale, che di serie arriva dopo 4-10 s.
func _cases() -> Array[Dictionary]:
	return [
		{id = &"nailgun", make = func() -> Weapon: return _setup(AutoWeapon.new(), &"nailgun", &"")},
		{id = &"seismic_stake", active = true, make = func() -> Weapon: return _setup(SeismicStake.new(), &"seismic_stake", &"")},
		{id = &"fort", fusion = &"fort", make = func() -> Weapon:
			var w: Weapon = _setup(AutoWeapon.new(), &"nailgun", &"fort")
			w.set(&"_fort_left", 0.0)
			return w},
		{id = &"scrap_launcher", make = func() -> Weapon: return _setup(ScrapLauncher.new(), &"scrap_launcher", &"")},
		{id = &"dig_charge", active = true, make = func() -> Weapon: return _setup(DigCharge.new(), &"dig_charge", &"")},
		{id = &"mortar", fusion = &"mortar", make = func() -> Weapon:
			var w: ScrapLauncher = _setup(ScrapLauncher.new(), &"scrap_launcher", &"mortar")
			w.shots = 3
			return w},
		{id = &"welder", make = func() -> Weapon: return _setup(Welder.new(), &"welder", &"")},
		{id = &"crane_magnet", active = true, make = func() -> Weapon: return _setup(CraneMagnet.new(), &"crane_magnet", &"")},
		{id = &"tesla_coil", fusion = &"tesla_coil", make = func() -> Weapon: return _setup(Welder.new(), &"welder", &"tesla_coil")},
		{id = &"scythe", make = func() -> Weapon: return _setup(Scythe.new(), &"scythe", &"")},
		{id = &"bramble", active = true, make = func() -> Weapon: return _setup(Bramble.new(), &"bramble", &"")},
		{id = &"scythe_bramble", fusion = &"scythe_bramble", make = func() -> Weapon: return _setup(Scythe.new(), &"scythe", &"scythe_bramble")},
		{id = &"site_blade", make = func() -> Weapon: return _setup(SiteBlade.new(), &"site_blade", &"")},
		{id = &"ram", active = true, make = func() -> Weapon: return _setup(Ram.new(), &"ram", &"")},
		{id = &"disc_dozer", fusion = &"disc_dozer", make = func() -> Weapon:
			var w: Weapon = _setup(SiteBlade.new(), &"site_blade", &"disc_dozer")
			w.set(&"_big_left", 0.1)
			return w},
		{id = &"jackhammer", make = func() -> Weapon: return _setup(Jackhammer.new(), &"jackhammer", &"")},
		{id = &"cement_mixer", active = true, make = func() -> Weapon: return _setup(CementMixer.new(), &"cement_mixer", &"")},
		{id = &"compactor", fusion = &"compactor", make = func() -> Weapon:
			var w: Jackhammer = _setup(Jackhammer.new(), &"jackhammer", &"compactor")
			w.waves = 2
			return w},
	]


func _test_case(case: Dictionary) -> void:
	await _reset()
	var weapon: Weapon = (case.make as Callable).call()
	var fusion: StringName = case.get(&"fusion", &"")
	var most := 0
	var fusion_fx := false
	for frame in int(4.0 * Engine.physics_ticks_per_second):
		if case.get(&"active", false) and frame % 30 == 0:
			(weapon as ActiveWeapon).cooldown_left = 0.0
			(weapon as ActiveWeapon).trigger()
		await physics_frame
		most = maxi(most, _fx_count())
		if fusion != &"" and not fusion_fx:
			for node in get_nodes_in_group(WeaponFx.GROUP):
				if node.get_meta(&"fx_fusion", &"") == fusion:
					fusion_fx = true
					break
	_check(most > 0, "%s: nasce un effetto (al piu %d insieme)" % [case.id, most])
	if fusion != &"":
		_check(fusion_fx, "%s: c'e un effetto proprio della fusione" % case.id)
	weapon.process_mode = Node.PROCESS_MODE_DISABLED
	await _seconds(2.0)
	_check(_fx_count() == 0, "%s: dopo 2 s nessun effetto resta (%d)" % [case.id, _fx_count()])
	weapon.queue_free()
	_director.clear_horde()
	await _seconds(0.2)


## Molte richieste insieme: mai oltre il tetto di nodi vivi.
func _test_cap() -> void:
	for i in WeaponFx.MAX_LIVE + 20:
		WeaponFx.burst(_director, Vector3(i * 0.1, 0.5, 0.0), WeaponFx.RUST)
	_check(_fx_count() <= WeaponFx.MAX_LIVE, "tetto: %d effetti vivi su %d chiesti" % [_fx_count(), WeaponFx.MAX_LIVE + 20])
	await _seconds(2.0)
	_check(_fx_count() == 0, "tetto: tutti liberati")
