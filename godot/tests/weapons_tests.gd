extends SceneTree
## Armi (spec D-092): danno, valori per livello, bivi che cambiano davvero il comportamento.
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/weapons_tests.gd

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
	await _test_nailgun_base()
	await _test_nailgun_levels()
	await _test_bridge_pierces_all()
	await _test_ricochet()
	await _test_incendiary()
	await _test_legacy_turret()
	await _test_no_node_per_nail()
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
