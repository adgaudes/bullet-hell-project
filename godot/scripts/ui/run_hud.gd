class_name RunHud
extends CanvasLayer
## HUD della run (D-038): barra esperienza in alto, livello, vita, tempo e
## rottamatori abbattuti. Solo lettura: mai focus ne input.

const HEALTH_ON := Color(0.95, 0.25, 0.15)
const HEALTH_OFF := Color(0.18, 0.12, 0.12, 0.8)
const XP_COLOR := Color(0.1, 0.85, 0.65)

var _xp_bar: ProgressBar
var _level_label: Label
var _time_label: Label
var _kills_label: Label
var _health_row: HBoxContainer


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_xp_bar.offset_bottom = 10
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = XP_COLOR
	_xp_bar.add_theme_stylebox_override(&"fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	_xp_bar.add_theme_stylebox_override(&"background", background)
	root.add_child(_xp_bar)

	# Riga superiore: livello a sinistra, tempo al centro, abbattuti a destra.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 16
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_level_label = _label(top, HORIZONTAL_ALIGNMENT_LEFT)
	_time_label = _label(top, HORIZONTAL_ALIGNMENT_CENTER)
	_kills_label = _label(top, HORIZONTAL_ALIGNMENT_RIGHT)

	_health_row = HBoxContainer.new()
	_health_row.position = Vector2(24, 56)
	_health_row.add_theme_constant_override(&"separation", 6)
	_health_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_health_row)

	set_xp(0, 1, 1)
	set_time(0.0)
	set_kills(0)


func set_xp(xp: int, needed: int, level: int) -> void:
	_xp_bar.max_value = maxi(needed, 1)
	_xp_bar.value = xp
	_level_label.text = "LIVELLO %d" % level


func set_health(health: int, max_health: int) -> void:
	for child in _health_row.get_children():
		child.queue_free()
	for i in max_health:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(22, 22)
		pip.color = HEALTH_ON if i < health else HEALTH_OFF
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_health_row.add_child(pip)


func set_time(seconds: float) -> void:
	_time_label.text = format_time(seconds)


func set_kills(kills: int) -> void:
	_kills_label.text = "ROTTAMATI %d" % kills


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


func _label(parent: Control, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", 24)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	parent.add_child(label)
	return label
