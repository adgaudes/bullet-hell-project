class_name GameOverPanel
extends CanvasLayer
## Fine run (D-038): riepilogo e ripartenza. L'estrazione arrivera dopo.

signal restart_requested

const INPUT_GRACE_SECONDS := 0.8

var is_open := false
var _overlay: ColorRect
var _summary: Label
var _restart: Button
var _quit: Button


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color = Color(0.05, 0.01, 0.01, 0.85)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(440, 0)
	column.add_theme_constant_override(&"separation", 18)
	center.add_child(column)
	var title := Label.new()
	title.text = "ROTTAMATO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 44)
	column.add_child(title)
	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_font_size_override(&"font_size", 22)
	column.add_child(_summary)
	_restart = _button(column, "Ricomincia")
	_restart.pressed.connect(func() -> void: restart_requested.emit())
	_quit = _button(column, "Esci")
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_overlay.hide()


func open(seconds: float, level: int, kills: int) -> void:
	is_open = true
	_summary.text = "Tempo %s\nLivello %d\nRottamatori abbattuti %d" % [RunHud.format_time(seconds), level, kills]
	get_tree().paused = true
	_overlay.show()
	_restart.disabled = true
	_quit.disabled = true
	get_tree().create_timer(INPUT_GRACE_SECONDS, true).timeout.connect(func() -> void:
		_restart.disabled = false
		_quit.disabled = false
		_restart.grab_focus())


func _button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override(&"font_size", 20)
	parent.add_child(button)
	return button
