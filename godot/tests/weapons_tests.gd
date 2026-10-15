extends SceneTree
## Armi (spec D-092): danno, valori per livello, bivi che cambiano davvero il comportamento.
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/weapons_tests.gd

var _failures := 0
var _root: Node3D
var _director: EnemyDirector
var _field: TerrainField
var _queue: TerrainWriteQueue


func _initialize() -> void:
	_root = Node3D.new()
	get_root().add_child(_root)
	_director = EnemyDirector.new()
	_director.spawning = false
	_root.add_child(_director)
	_field = TerrainField.new()
	_field.render = false
	_field.size_m = Vector2(40.0, 40.0)
	get_root().add_child(_field)
	_queue = TerrainWriteQueue.new()
	_queue.terrain_field = _field
	get_root().add_child(_queue)
	await process_frame
	await _test_nailgun_base()
	await _test_nailgun_levels()
	await _test_bridge_pierces_all()
	await _test_ricochet()
	await _test_incendiary()
	await _test_legacy_turret()
	await _test_no_node_per_nail()
	await _test_stake_cooldown()
	await _test_stake_ring()
	await _test_stake_permanent()
	await _test_stake_shock()
	await _test_stake_spiked()
	await _test_active_auto_aim()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _enemy_at(p: Vector3, hp := 50) -> Enemy:
	var enemy := _director.spawn_at(p)
	enemy.health = hp
	enemy.max_health = hp
	enemy.global_position = p
	return enemy


func _shooter(at: Vector3) -> Node3D:
	var shooter := Node3D.new()
	_root.add_child(shooter)
	shooter.global_position = at
	return shooter


func _nailgun(at := Vector3.ZERO) -> AutoWeapon:
	var weapon := AutoWeapon.new()
	weapon.weapon_id = &"nailgun"
	weapon.shooter = _shooter(at)
	weapon.director = _director
	_root.add_child(weapon)
	return weapon


func _seconds(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _clear() -> void:
	for enemy in _director.enemies:
		enemy.queue_free()
	_director.enemies.clear()
	for child in _root.get_children():
		if child != _director:
			child.queue_free()
	await process_frame
	await physics_frame


func _test_nailgun_base() -> void:
	print("chiodatrice liv. 1")
	var enemy := _enemy_at(Vector3(0, 0, -5))
	var weapon := _nailgun()
	_check(is_equal_approx(weapon.fire_interval, 0.5) and weapon.damage == 1, "valori dal catalogo")
	await _seconds(0.65)
	_check(enemy.health == 49, "un chiodo colpisce entro 0,65 s (vita %d)" % enemy.health)
	await _clear()


func _test_nailgun_levels() -> void:
	print("livelli e Raffica")
	var weapon := _nailgun()
	await process_frame
	weapon.set_level(2)
	_check(is_equal_approx(weapon.fire_interval, 0.4), "liv. 2: un colpo ogni 0,4 s")
	weapon.set_level(3)
	weapon.choose_branch(3, &"a")
	_check(is_equal_approx(weapon.fire_interval, 0.2), "Raffica: un colpo ogni 0,2 s")
	_check(weapon.has_branch(&"burst") and not weapon.has_branch(&"bridge"), "has_branch riconosce il bivio preso")
	await _clear()


func _test_bridge_pierces_all() -> void:
	print("Chiodi da ponte")
	var a := _enemy_at(Vector3(0, 0, -3))
	var b := _enemy_at(Vector3(0, 0, -4))
	var c := _enemy_at(Vector3(0, 0, -5))
	var weapon := _nailgun()
	await process_frame
	weapon.set_level(3)
	weapon.choose_branch(3, &"b")
	await _seconds(0.6)
	_check(a.health == 48 and b.health == 48 and c.health == 48,
		"un colpo trapassa tre nemici, 2 danni ciascuno (%d, %d, %d)" % [a.health, b.health, c.health])
	await _clear()


func _wall_at(z: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 3, 0.4)
	shape.shape = box
	body.add_child(shape)
	_root.add_child(body)
	body.global_position = Vector3(0, 0, z)


func _test_ricochet() -> void:
	print("Rimbalzanti")
	_wall_at(-3.0)
	var enemy := _enemy_at(Vector3(0, 0, 2))
	var plain := _nailgun()
	await physics_frame
	plain._cooldown = 1000.0
	plain._fire_toward(Vector3.FORWARD)
	await _seconds(0.8)
	_check(enemy.health == 50, "senza bivio il chiodo si ferma sull'argine")
	plain.queue_free()
	var weapon := _nailgun()
	await physics_frame
	weapon.set_level(5)
	weapon.choose_branch(3, &"a")
	weapon.choose_branch(5, &"a")
	weapon._cooldown = 1000.0
	weapon._fire_toward(Vector3.FORWARD)
	await _seconds(0.8)
	_check(enemy.health == 49, "col bivio rimbalza sull'argine e colpisce dietro (vita %d)" % enemy.health)
	await _clear()


func _test_incendiary() -> void:
	print("Incandescenti")
	var enemy := _enemy_at(Vector3(0, 0, -4))
	var weapon := _nailgun()
	await physics_frame
	weapon.set_level(5)
	weapon.choose_branch(3, &"a")
	weapon.choose_branch(5, &"b")
	weapon._cooldown = 1000.0
	weapon._fire_toward(Vector3.FORWARD)
	await _seconds(0.3)
	_check(weapon.fire_patch_count() == 1, "all'impatto resta una macchia di fuoco")
	await _seconds(2.2)
	_check(enemy.health <= 47, "la macchia brucia chi ci sta dentro (vita %d)" % enemy.health)
	_check(weapon.fire_patch_count() == 0, "dopo 2 s la macchia si spegne")
	await _clear()


func _test_legacy_turret() -> void:
	print("Torretta senza catalogo")
	var weapon := AutoWeapon.new()
	weapon.shooter = _shooter(Vector3.ZERO)
	weapon.director = _director
	weapon.fire_interval = 0.9
	weapon.weapon_range = 8.0
	_root.add_child(weapon)
	await process_frame
	_check(is_equal_approx(weapon.fire_interval, 0.9) and is_equal_approx(weapon.weapon_range, 8.0), "senza weapon_id i valori impostati restano")
	await _clear()


func _test_no_node_per_nail() -> void:
	print("chiodi senza nodi")
	_enemy_at(Vector3(0, 0, -8), 500)
	var weapon := _nailgun()
	await physics_frame
	var children := weapon.get_child_count()
	weapon.set_level(3)
	weapon.choose_branch(3, &"a")
	await _seconds(2.0)
	_check(weapon.get_child_count() == children, "sparando i figli dell'arma restano %d" % children)
	await _clear()


func _stake(level := 1, picks: Dictionary = {}) -> SeismicStake:
	var stake := SeismicStake.new()
	stake.weapon_id = &"seismic_stake"
	stake.shooter = _shooter(Vector3.ZERO)
	stake.director = _director
	stake.terrain_field = _field
	stake.write_queue = _queue
	stake.manual_aim = true
	_root.add_child(stake)
	stake.set_level(level)
	for at: int in picks:
		stake.choose_branch(at, picks[at])
	return stake


func _reset_field() -> void:
	_queue.clear()
	_field.begin_batch()
	_field.reset_to_base(Vector3.ZERO, Vector2(20.0, 20.0))
	_field.end_batch()


## Quota sull'anello del picchetto piantato a 6 m davanti (verso -Z), al punto a est.
func _ring_height(radius := 3.0) -> float:
	return _field.height_at(Vector3(radius, 0.0, -6.0))


func _test_stake_cooldown() -> void:
	print("Picchetto: ricarica")
	var stake := _stake()
	await physics_frame
	_check(stake.can_trigger() and stake.trigger(), "carico: si pianta")
	_check(not stake.can_trigger() and is_equal_approx(stake.cooldown_left, 15.0), "poi ricarica 15 s")
	_check(not stake.trigger(), "scarico: non si pianta")
	await _seconds(15.1)
	_check(stake.can_trigger(), "dopo 15 s e di nuovo carico")
	paused = true
	_check(not stake.can_trigger(), "a gioco in pausa non si usa")
	paused = false
	await _clear()
	_reset_field()


func _test_stake_ring() -> void:
	print("Picchetto: anello")
	var stake := _stake()
	await physics_frame
	stake.trigger()
	await _seconds(1.2)
	_check(_ring_height() > 1.0, "dopo il ritardo l'anello e alto (%.2f m)" % _ring_height())
	_check(_field.height_at(Vector3(0.0, 0.0, -6.0)) < 0.3, "il centro resta basso: chi e dentro e chiuso")
	_check(_field.height_at(Vector3(3.0 * cos(PI / 7.0), 0.0, -6.0 + 3.0 * sin(PI / 7.0))) > 0.9, "l'anello non ha buchi fra un disco e l'altro")
	_check(stake.ring_count() == 1, "un anello vivo")
	await _seconds(12.5)
	_check(_ring_height() < 0.2, "dopo 12 s torna giu (%.2f m)" % _ring_height())
	_check(stake.ring_count() == 0, "nessun anello vivo")
	await _clear()
	_reset_field()


func _test_stake_permanent() -> void:
	print("Picchetto: Argine permanente")
	var stake := _stake(3, {3: &"b"})
	await physics_frame
	stake.trigger()
	await _seconds(14.0)
	_check(_ring_height() > 1.0, "dopo 14 s l'anello e ancora su")
	await _clear()
	_reset_field()


func _test_stake_shock() -> void:
	print("Picchetto: Scossa")
	var enemy := _enemy_at(Vector3(3.0, 0.0, -6.0))
	var stake := _stake(5, {3: &"b", 5: &"b"})
	await physics_frame
	stake.trigger()
	await _seconds(0.8)
	_check(enemy.health == 47, "3 danni a chi sta sull'anello (vita %d)" % enemy.health)
	await _clear()
	_reset_field()


func _test_stake_spiked() -> void:
	print("Picchetto: Argine chiodato")
	var enemy := _enemy_at(Vector3(3.4, 0.0, -6.0))
	var stake := _stake(5, {3: &"b", 5: &"a"})
	await physics_frame
	stake.trigger()
	await _seconds(2.5)
	_check(enemy.health <= 48, "chi sta contro l'anello si fa male (vita %d)" % enemy.health)
	await _clear()
	_reset_field()


func _test_active_auto_aim() -> void:
	print("Attive: mira automatica")
	for offset in [Vector3(-0.3, 0, -0.2), Vector3(0.3, 0, 0.2), Vector3(0.1, 0, -0.1), Vector3(-0.2, 0, 0.25)]:
		_enemy_at(Vector3(5.0, 0.0, 0.6) + offset)
	_enemy_at(Vector3(0.0, 0.0, -4.0))
	var stake := _stake()
	stake.manual_aim = false
	await physics_frame
	var at := stake.aim_point()
	_check(Vector2(at.x, at.z).distance_to(Vector2(5.0, 0.6)) < 0.6, "punta al gruppo piu fitto, non al nemico isolato (%s)" % at)
	await _clear()
	_reset_field()
