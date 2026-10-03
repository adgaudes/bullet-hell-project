extends SceneTree
## Test di impostazioni, pausa, focus e inversione dello stick destro.

const GameSettingsScript := preload("res://scripts/services/game_settings.gd")
const PlayerScene := preload("res://scenes/player/player.tscn")

var _failures := 0


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_test_defaults()
	_test_apply()
	_test_persistence()
	await _test_pause_and_focus()
	await _test_aim_inversion()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _test_defaults() -> void:
	print("settings defaults")
	var settings := GameSettingsScript.new()
	_check(settings.fps_cap == 120, "limite predefinito 120 fps")
	_check(settings.vsync_mode == DisplayServer.VSYNC_MAILBOX, "VSync predefinita Mailbox")
	_check(settings.msaa_3d == Viewport.MSAA_4X, "MSAA 3D predefinito 4x")
	_check(is_equal_approx(settings.render_scale, 1.0), "scala rendering predefinita 100%")
	_check(not settings.invert_aim_x and not settings.invert_aim_y, "assi mira non invertiti")
	settings.free()


func _test_apply() -> void:
	print("settings apply")
	var settings := GameSettingsScript.new()
	settings.fps_cap = 90
	settings.msaa_3d = Viewport.MSAA_2X
	settings.render_scale = 0.7
	settings.apply_settings(root)
	_check(Engine.max_fps == 90, "applica Engine.max_fps")
	_check(root.msaa_3d == Viewport.MSAA_2X, "applica MSAA al viewport")
	_check(is_equal_approx(root.scaling_3d_scale, 0.7), "applica scala 3D al viewport")
	GameSettings.apply_settings(root)
	settings.free()


func _test_persistence() -> void:
	print("settings persistence")
	var temp_path := "user://settings_test_%d.cfg" % Time.get_ticks_usec()
	var saved := GameSettingsScript.new()
	saved.fps_cap = 144
	saved.vsync_mode = DisplayServer.VSYNC_DISABLED
	saved.msaa_3d = Viewport.MSAA_8X
	saved.render_scale = 0.6
	saved.window_mode = GameSettingsScript.WindowModeChoice.BORDERLESS_FULLSCREEN
	saved.invert_aim_x = true
	saved.invert_aim_y = true
	_check(saved.save_settings(temp_path) == OK, "salva in un file temporaneo")
	var loaded := GameSettingsScript.new()
	_check(loaded.load_settings(temp_path) == OK, "ricarica il file temporaneo")
	_check(loaded.fps_cap == 144, "round trip limite fps")
	_check(loaded.vsync_mode == DisplayServer.VSYNC_DISABLED, "round trip VSync")
	_check(loaded.msaa_3d == Viewport.MSAA_8X, "round trip MSAA")
	_check(is_equal_approx(loaded.render_scale, 0.6), "round trip scala rendering")
	_check(loaded.window_mode == GameSettingsScript.WindowModeChoice.BORDERLESS_FULLSCREEN, "round trip modalita finestra")
	_check(loaded.invert_aim_x and loaded.invert_aim_y, "round trip inversione assi")
	var absolute_path := ProjectSettings.globalize_path(temp_path)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(absolute_path)
	saved.free()
	loaded.free()


func _test_pause_and_focus() -> void:
	print("pause and focus")
	var pause_menu := root.get_node("PauseMenu")
	if pause_menu.is_open():
		pause_menu.resume_game()
	_send_pause_key()
	await process_frame
	_check(paused and pause_menu.is_open(), "Esc apre il menu e mette in pausa")
	var focused: Control = pause_menu.focused_control()
	_check(focused != null and focused.name == &"ResumeButton", "focus su Riprendi all'apertura")
	pause_menu.open_settings()
	await process_frame
	focused = pause_menu.focused_control()
	_check(focused != null and focused.name == &"FpsOption", "focus sulla prima impostazione")
	_send_pause_joypad()
	await process_frame
	_check(not paused and not pause_menu.is_open(), "Start chiude il menu e riprende")

	# A e Spazio condividono ui_accept con il dash: il Control deve consumare l'evento.
	var player: PlayerCharacter = PlayerScene.instantiate()
	root.add_child(player)
	pause_menu.pause_game()
	await process_frame
	_send_joypad_button(JOY_BUTTON_A, true)
	_send_joypad_button(JOY_BUTTON_A, false)
	await process_frame
	await physics_frame
	_check(not paused and not player.is_dashing, "A su Riprendi non attiva il dash")
	player.queue_free()
	await process_frame


func _test_aim_inversion() -> void:
	print("aim inversion")
	var player: PlayerCharacter = PlayerScene.instantiate()
	root.add_child(player)
	GameSettings.invert_aim_x = false
	GameSettings.invert_aim_y = false
	_send_joypad_axis(JOY_AXIS_RIGHT_X, 0.8)
	await process_frame
	var normal_x: Vector2 = player.call("_raw_aim_input")
	GameSettings.invert_aim_x = true
	var inverted_x: Vector2 = player.call("_raw_aim_input")
	_check(normal_x.x > 0.0 and is_equal_approx(inverted_x.x, -normal_x.x), "inversione X ribalta lo stick destro")
	_send_joypad_axis(JOY_AXIS_RIGHT_X, 0.0)
	_send_joypad_axis(JOY_AXIS_RIGHT_Y, 0.8)
	await process_frame
	GameSettings.invert_aim_y = false
	var normal_y: Vector2 = player.call("_raw_aim_input")
	GameSettings.invert_aim_y = true
	var inverted_y: Vector2 = player.call("_raw_aim_input")
	_check(normal_y.y > 0.0 and is_equal_approx(inverted_y.y, -normal_y.y), "inversione Y ribalta lo stick destro")
	_send_joypad_axis(JOY_AXIS_RIGHT_Y, 0.0)
	GameSettings.invert_aim_x = false
	GameSettings.invert_aim_y = false
	player.queue_free()
	await process_frame


func _send_pause_key() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)


func _send_pause_joypad() -> void:
	_send_joypad_button(JOY_BUTTON_START, true)
	_send_joypad_button(JOY_BUTTON_START, false)


func _send_joypad_button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	event.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _send_joypad_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
