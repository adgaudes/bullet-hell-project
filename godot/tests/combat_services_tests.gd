extends SceneTree
## Servizi delle armi (D-092, piano 2): stordimento dei nemici e carica del giocatore (Ariete).
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/combat_services_tests.gd

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
	_director = EnemyDirector.new()
	_director.spawning = false
	_director.player = _player
	_field = _scene.get_node(^"TerrainField")
	_director.terrain_field = _field
	_scene.add_child(_director)
	_queue = TerrainWriteQueue.new()
	_queue.terrain_field = _field
	_scene.add_child(_queue)
	await _seconds(0.5)
	await _test_stun()
	await _test_charge()
	await _test_charge_blocked()
	await _test_charge_into_wall()
	await _test_ram_base()
	await _test_ram_trench_and_blast()
	await _test_ram_blocked()
	await _test_ram_ploughs_bank()
	await _test_ram_ploughs_with_busy_queue()
	await _test_stunned_do_not_gnaw()
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


# --- Ariete (piano 2) --------------------------------------------------------------------

func _ram(level := 1, picks: Dictionary = {}) -> Ram:
	var ram := Ram.new()
	ram.weapon_id = &"ram"
	ram.shooter = _player
	ram.director = _director
	ram.terrain_field = _field
	ram.write_queue = _queue
	ram.manual_aim = true
	_scene.add_child(ram)
	ram.set_level(level)
	for at: int in picks:
		ram.choose_branch(at, picks[at])
	return ram


## Giocatore fermo al centro, rivolto verso -Z, terreno alla base.
func _reset_player() -> void:
	_queue.clear()
	_field.begin_batch()
	_field.reset_to_base(Vector3.ZERO, Vector2(30.0, 30.0))
	_field.end_batch()
	_player.global_position = Vector3(0.0, _field.height_at(Vector3.ZERO) + 1.0, 6.0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.set_max_health(10)
	await _seconds(0.5)


func _test_ram_base() -> void:
	print("Ariete: carica")
	await _reset_player()
	var start := _player.global_position
	_field.sculpt(start + Vector3(0.0, 0.0, -4.0), 2.0, 0.5)
	var a := _director.spawn_at(start + Vector3(0.0, 0.0, -3.0))
	var b := _director.spawn_at(start + Vector3(0.3, 0.0, -6.0))
	a.health = 50
	b.health = 50
	var ram := _ram()
	await physics_frame
	_check(ram.trigger(), "parte")
	await _seconds(1.0)
	_check(a.health == 47 and b.health == 47, "travolge chi sta sul percorso, 3 danni (%d, %d)" % [a.health, b.health])
	_check(start.z - _player.global_position.z > 6.0, "il giocatore carica in avanti (%.2f m)" % (start.z - _player.global_position.z))
	_check(_field.height_at(start + Vector3(0.0, 0.0, -4.0)) < 0.3, "spiana il dosso sul percorso (%.2f m)" % _field.height_at(start + Vector3(0.0, 0.0, -4.0)))
	ram.queue_free()
	_director.clear_horde()


func _test_ram_trench_and_blast() -> void:
	print("Ariete: Trincea, Scudo e Botto")
	await _reset_player()
	var start := _player.global_position
	var ram := _ram(5, {3: &"b", 5: &"a"})
	await physics_frame
	ram.trigger()
	await _seconds(1.0)
	_check(_field.height_at(start + Vector3(0.0, 0.0, -4.0)) < -0.3, "Trincea scava lungo la carica (%.2f m)" % _field.height_at(start + Vector3(0.0, 0.0, -4.0)))
	_check(_player._invulnerable_left > 0.9, "Scudo: intoccabile dopo l'arrivo")
	ram.queue_free()
	await _reset_player()
	start = _player.global_position
	var side := _director.spawn_at(start + Vector3(2.0, 0.0, -8.0))
	side.health = 50
	ram = _ram(5, {3: &"b", 5: &"b"})
	await physics_frame
	ram.trigger()
	await _seconds(1.0)
	_check(side.health == 47, "Botto: 3 danni all'arrivo a chi e vicino (%d)" % side.health)
	ram.queue_free()
	_director.clear_horde()


func _test_ram_blocked() -> void:
	print("Ariete: non parte")
	await _reset_player()
	var ram := _ram()
	await physics_frame
	_player._start_dash()
	_check(not ram.trigger() and is_zero_approx(ram.cooldown_left), "durante lo scatto non parte e non consuma la ricarica")
	ram.queue_free()
	await _seconds(1.5)


## La carica spiana davanti a se: un argine basso sul percorso non la ferma (cattura del 15
## ottobre: l'Ariete restava fermo contro il bordo del cortile).
func _test_ram_ploughs_bank() -> void:
	print("Ariete contro un argine")
	await _reset_player()
	var start := _player.global_position
	for x in range(-3, 4):
		_field.level(start + Vector3(x, 0.0, -2.5), 0.9, 1.0, 1.0)
	var ram := _ram()
	await physics_frame
	ram.trigger()
	await _seconds(1.2)
	_check(start.z - _player.global_position.z > 5.0, "attraversa l'argine spianandolo (%.2f m)" % (start.z - _player.global_position.z))
	ram.queue_free()
	await _seconds(0.5)


## Review I4: la spianata dell'Ariete passa davanti a una coda piena (anello, pozza).
func _test_ram_ploughs_with_busy_queue() -> void:
	print("Ariete con la coda piena")
	await _reset_player()
	var start := _player.global_position
	for x in range(-3, 4):
		_field.level(start + Vector3(x, 0.0, -2.5), 0.9, 1.0, 1.0)
	for i in 60:
		_queue.push_level(Vector3(-20.0 + i * 0.5, 0.0, -20.0), 0.5, 0.3)
	var ram := _ram()
	await physics_frame
	ram.trigger()
	await _seconds(1.2)
	_check(start.z - _player.global_position.z > 5.0, "attraversa l'argine anche con 60 scritture in coda (%.2f m)" % (start.z - _player.global_position.z))
	ram.queue_free()
	_queue.clear()
	await _seconds(0.5)


## Review I6: un nemico stordito contro un argine non lo rosicchia.
func _test_stunned_do_not_gnaw() -> void:
	print("storditi non rosicchiano")
	await _reset_player()
	var start := _player.global_position
	for x in range(-3, 4):
		_field.level(start + Vector3(x, 0.0, -3.0), 0.9, 1.6, 1.0)
	var enemy := _director.spawn_at(start + Vector3(0.0, 0.0, -4.4))
	enemy.health = 50
	await _seconds(2.6)
	var before := _director.gnaws
	enemy.stun(4.0)
	await _seconds(3.8)
	_check(_director.gnaws == before, "nessun morso mentre e stordito (%d)" % (_director.gnaws - before))
	_director.clear_horde()
	await _seconds(0.3)


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
