extends CanvasLayer
## Pausa globale con accesso alle impostazioni e uscita dal gioco.

@onready var _overlay: Control = %Overlay
@onready var _pause_panel: PanelContainer = %PausePanel
@onready var _settings_panel: SettingsMenu = %SettingsPanel
@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.hide()
	_resume_button.pressed.connect(resume_game)
	_settings_button.pressed.connect(open_settings)
	_quit_button.pressed.connect(get_tree().quit)
	_settings_panel.back_requested.connect(_show_pause_panel)


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if get_tree().paused:
			resume_game()
		else:
			pause_game()
	elif _overlay.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _settings_panel.visible:
			_show_pause_panel()
		else:
			resume_game()


## Ferma il gioco e porta il focus su Riprendi.
func pause_game() -> void:
	get_tree().paused = true
	_overlay.show()
	_show_pause_panel()


## Nasconde la UI prima di riattivare il gameplay.
func resume_game() -> void:
	_overlay.hide()
	get_viewport().gui_release_focus()
	get_tree().paused = false


func open_settings() -> void:
	_pause_panel.hide()
	_settings_panel.open()


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func focused_control() -> Control:
	return get_viewport().gui_get_focus_owner()


func _show_pause_panel() -> void:
	_settings_panel.hide()
	_pause_panel.show()
	_resume_button.grab_focus()
