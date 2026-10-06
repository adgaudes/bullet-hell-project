extends CanvasLayer
## Pausa globale con accesso alle impostazioni, ritorno al menu e uscita dal gioco.
## Il menu iniziale (D-051) la disattiva e ne riusa il pannello Impostazioni.

## Il pannello Impostazioni aperto da solo (dal menu iniziale) e stato chiuso.
signal settings_closed

const MAIN_MENU_SCENE := "res://scenes/main/main_menu.tscn"

## Falso nel menu iniziale: il tasto pausa non fa nulla.
var enabled := true
var _settings_only := false
var _menu_button: Button

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
	_menu_button = Button.new()
	_menu_button.name = "MenuButton"
	_menu_button.text = "Torna al menu"
	_menu_button.custom_minimum_size = _settings_button.custom_minimum_size
	_menu_button.pressed.connect(return_to_menu)
	_quit_button.add_sibling(_menu_button)
	_menu_button.get_parent().move_child(_menu_button, _quit_button.get_index())
	_settings_panel.back_requested.connect(_show_pause_panel)
	var prompts := ButtonPrompts.create([[&"ui_accept", "Conferma"], [&"ui_cancel", "Indietro"]])
	_overlay.add_child(prompts)
	prompts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 28)
	prompts.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"pause"):
		if not enabled:
			return
		# Gioco fermato da altro (level-up, fine run): la pausa non lo riattiva.
		if get_tree().paused and not is_open():
			return
		get_viewport().set_input_as_handled()
		if is_open():
			resume_game()
		else:
			pause_game()
	elif _overlay.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _settings_panel.visible:
			_show_pause_panel()
		elif not _settings_only:
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


## Solo le Impostazioni, senza mettere in pausa: usato dal menu iniziale.
## Alla chiusura emette `settings_closed`.
func open_settings_only() -> void:
	_settings_only = true
	_overlay.show()
	open_settings()


## Abbandona il livello in corso e torna al menu iniziale.
func return_to_menu() -> void:
	_overlay.hide()
	get_viewport().gui_release_focus()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func focused_control() -> Control:
	return get_viewport().gui_get_focus_owner()


func _show_pause_panel() -> void:
	_settings_panel.hide()
	if _settings_only:
		_settings_only = false
		_overlay.hide()
		settings_closed.emit()
		return
	_pause_panel.show()
	_resume_button.grab_focus()
