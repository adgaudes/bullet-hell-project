extends SceneTree
## Coda delle scritture delle armi sul terreno (spec D-092, par. 8-9). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/terrain_write_queue_tests.gd

var _failures := 0


func _initialize() -> void:
	var field := TerrainField.new()
	field.render = false
	field.size_m = Vector2(40.0, 40.0)
	get_root().add_child(field)
	var queue := TerrainWriteQueue.new()
	queue.terrain_field = field
	get_root().add_child(queue)
	await process_frame

	print("una scrittura per passo")
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		queue.push_level(Vector3(x, 0.0, 0.0), 1.0, 1.0)
	_check(queue.pending() == 5, "cinque scritture in coda")
	# `physics_frame` arriva prima del passo dei nodi: il primo passo si vede al secondo segnale.
	await physics_frame
	await physics_frame
	_check(queue.pending() == 4, "dopo un passo ne restano quattro (%d)" % queue.pending())
	for i in 4:
		await physics_frame
	_check(queue.pending() == 0, "dopo cinque passi la coda e vuota")
	var reached := true
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		reached = reached and is_equal_approx(field.height_at(Vector3(x, 0.0, 0.0)), 1.0)
	_check(reached, "ogni disco arriva alla quota chiesta al centro")

	print("punti scartati")
	field.set_protected(Vector3(0.0, 0.0, 10.0), 2.0, true)
	queue.push_level(Vector3(0.0, 0.0, 10.0), 1.0, 1.0)
	queue.push_level(Vector3(100.0, 0.0, 0.0), 1.0, 1.0)
	_check(queue.pending() == 0, "punto protetto e punto fuori campo non entrano in coda")

	print("raggio limitato")
	queue.push_level(Vector3(0.0, 0.0, -10.0), 6.0, 1.0)
	await physics_frame
	await physics_frame
	_check(is_equal_approx(field.height_at(Vector3(0.0, 0.0, -10.0)), 1.0), "il centro sale")
	_check(is_zero_approx(field.height_at(Vector3(0.0, 0.0, -14.0))), "a 4 m dal centro non cambia: raggio ridotto a 2,5 m")

	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)
