extends SceneTree
## Test di UiFx (D-081): cursore a chiodo, suoni, pop-in e transizioni. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/ui_fx_tests.gd

var _failures := 0


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	await _frames(2)
	await _test_cursor_follows_focus()
	await _test_pop_in()
	await _test_fade_once()
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
		await process_frame


func _fx() -> UiFxService:
	return root.get_node("UiFx") as UiFxService


## Il cursore segue l'ultimo Control con il focus; i pulsanti liberati non rompono nulla.
func _test_cursor_follows_focus() -> void:
	var fx := _fx()
	_check(fx != null and fx.cursor_enabled, "autoload UiFx presente con il cursore attivo")
	var column := VBoxContainer.new()
	column.position = Vector2(300, 200)
	root.add_child(column)
	var buttons: Array[Button] = []
	for i in 5:
		var button := Button.new()
		button.text = "Voce %d" % i
		button.custom_minimum_size = Vector2(200, 48)
		column.add_child(button)
		buttons.append(button)
	await _frames(2)
	var moves_before := fx.play_count(&"ui_move")
	buttons[0].grab_focus()
	await _frames(10)
	_check(fx.cursor_target() == buttons[0] and fx.cursor_visible(), "cursore sul primo pulsante")
	var rect := buttons[0].get_global_rect()
	var cursor := fx.cursor_position()
	_check(cursor.x < rect.position.x and absf(cursor.y - (rect.position.y + rect.size.y * 0.5)) < rect.size.y, "cursore a sinistra del pulsante, allineato in verticale")
	for i in 5:
		buttons[i].grab_focus()
		await _frames(1)
	await _frames(10)
	_check(fx.cursor_target() == buttons[4], "cambi rapidi di focus: vince l'ultimo")
	_check(fx.play_count(&"ui_move") > moves_before, "il cursore suona ui_move")
	var confirms := fx.play_count(&"ui_confirm")
	buttons[4].pressed.emit()
	await _frames(12)
	_check(fx.play_count(&"ui_confirm") == confirms + 1 and buttons[4].scale.is_equal_approx(Vector2.ONE), "pressione: ui_confirm e rimbalzo che torna a 1")
	# Il bersaglio si sposta dopo il focus (layout, scroll, pop-in): il cursore lo segue.
	column.position = Vector2(500, 400)
	await _frames(12)
	var moved := buttons[4].get_global_rect()
	var cursor_after := fx.cursor_position()
	_check(cursor_after.x < moved.position.x and absf(cursor_after.x - moved.position.x) < 60.0 and absf(cursor_after.y - (moved.position.y + moved.size.y * 0.5)) < moved.size.y, "il cursore segue il bersaglio spostato (%s vs %s)" % [cursor_after, moved.position])
	buttons[4].queue_free()
	await _frames(3)
	_check(not fx.cursor_visible(), "pulsante liberato: cursore nascosto, nessun errore")
	column.queue_free()
	await _frames(2)


func _test_pop_in() -> void:
	var fx := _fx()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 100)
	root.add_child(panel)
	await _frames(1)
	var opens := fx.play_count(&"ui_open")
	fx.pop_in(panel)
	_check(panel.scale.x < 1.0 and panel.modulate.a < 1.0, "pop-in parte piccolo e trasparente")
	await _frames(14)
	_check(panel.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(panel.modulate.a, 1.0), "pop-in finisce a scala 1 e opaco")
	_check(fx.play_count(&"ui_open") == opens + 1, "pop-in suona ui_open")
	panel.queue_free()
	await _frames(1)


## Due richieste di transizione di fila cambiano scena una volta sola.
func _test_fade_once() -> void:
	var fx := _fx()
	var changes := fx.scene_changes()
	fx.fade_to_scene("res://scenes/main/main_menu.tscn")
	fx.fade_to_scene("res://scenes/main/main_menu.tscn")
	_check(fx.is_transitioning, "transizione in corso")
	await _frames(60)
	_check(fx.scene_changes() == changes + 1, "una sola scena caricata (%d)" % (fx.scene_changes() - changes))
	_check(not fx.is_transitioning and fx.veil_alpha() < 0.01, "velo riaperto alla fine")
