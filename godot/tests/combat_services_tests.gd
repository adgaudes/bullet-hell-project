extends SceneTree
## Servizi delle armi (D-092, piano 2): stordimento dei nemici e carica del giocatore (Ariete).
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/combat_services_tests.gd

const SmokeTestScene := preload("res://scenes/main/smoke_test.tscn")

var _failures := 0
var _scene: Node3D
var _player: PlayerCharacter
var _director: EnemyDirector


func _initialize() -> void:
	_scene = SmokeTestScene.instantiate()
	root.add_child(_scene)
	_player = _scene.get_node(^"Player")
	_director = EnemyDirector.new()
	_director.spawning = false
	_director.player = _player
	_director.terrain_field = _scene.get_node(^"TerrainField")
	_scene.add_child(_director)
	await _seconds(0.5)
	await _test_stun()
	await _test_charge()
	await _test_charge_blocked()
	await _test_charge_into_wall()
	await _seconds(0.1)
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


func _planar(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _test_stun() -> void:
	print("stordimento")
	var enemy := _director.spawn_at(_player.global_position + Vector3(6.0, 0.0, 0.0))
	enemy.health = 50
	await _seconds(0.3)
	enemy.stun(0.6)
	var start := _planar(enemy.global_position)
	await _seconds(0.4)
	_check(_planar(enemy.global_position).distance_to(start) < 0.1, "stordito resta fermo (%.2f m)" % _planar(enemy.global_position).distance_to(start))
	await _seconds(0.8)
	_check(_planar(enemy.global_position).distance_to(start) > 0.3, "poi riparte verso il giocatore")
	var boss := Enemy.new()
	boss.self_driven = true
	boss.stun(1.0)
	_check(is_zero_approx(boss.stun_left), "un boss non si stordisce")
	boss.free()
	_director.clear_horde()
	await _seconds(0.4)


func _test_charge() -> void:
	print("carica")
	await _seconds(1.0)
	var start := _planar(_player.global_position)
	var health := _player.health
	_check(_player.start_charge(Vector3.FORWARD, 8.0, 0.5), "la carica parte")
	_check(_player.is_charging(), "in carica")
	_check(not _player.start_charge(Vector3.FORWARD, 8.0, 0.5), "una seconda carica non si sovrappone")
	await _seconds(0.1)
	_player.take_damage(1)
	_check(_player.health == health, "in carica non si prende danno")
	await _seconds(0.6)
	var moved := _planar(_player.global_position).distance_to(start)
	_check(moved > 6.5 and moved < 8.6, "percorre circa 8 m (%.2f)" % moved)
	_check(not _player.is_charging(), "la carica finisce")
	_player.grant_invulnerability(0.5)
	_player.take_damage(1)
	_check(_player.health == health, "intoccabile concesso: nessun danno")
	await _seconds(0.6)


func _test_charge_blocked() -> void:
	print("carica non possibile")
	_player._start_dash()
	_check(_player.is_dashing and not _player.start_charge(Vector3.FORWARD, 8.0, 0.5), "durante lo scatto non parte")
	await _seconds(1.5)


func _test_charge_into_wall() -> void:
	print("carica contro un muro")
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 0.6)
	shape.shape = box
	body.add_child(shape)
	_scene.add_child(body)
	body.global_position = _player.global_position + Vector3(0.0, 1.0, -3.0)
	await _seconds(0.1)
	var start_z := _player.global_position.z
	_player.start_charge(Vector3.FORWARD, 8.0, 0.5)
	await _seconds(0.7)
	_check(not _player.is_charging(), "la carica finisce anche contro il muro")
	_check(_player.global_position.z > start_z - 3.0, "e non lo attraversa (%.2f)" % (_player.global_position.z - start_z))
	body.queue_free()
