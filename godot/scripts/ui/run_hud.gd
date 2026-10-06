class_name RunHud
extends CanvasLayer
## HUD della run (D-038): barra esperienza in alto, livello, vita, tempo e
## rottamatori abbattuti; annuncio del boss con freccia di direzione e barra
## della sua vita (D-043). Solo lettura: mai focus ne input.

const HEALTH_ON := Color(0.95, 0.25, 0.15)
const HEALTH_OFF := Color(0.18, 0.12, 0.12, 0.8)
const XP_COLOR := Color(0.1, 0.85, 0.65)
const BOSS_COLOR := Color(0.95, 0.6, 0.08)
## Distanza della freccia di direzione dal centro dello schermo, in frazione del lato corto.
const ARROW_RADIUS_RATIO := 0.36

var _xp_bar: ProgressBar
var _level_label: Label
var _time_label: Label
var _kills_label: Label
var _health_row: HBoxContainer
var _boss_warning: Label
var _boss_arrow: Polygon2D
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _root: Control


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

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

	# Annuncio del boss: scritta sotto la riga superiore e freccia verso la direzione di arrivo.
	_boss_warning = Label.new()
	_boss_warning.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_warning.offset_top = 96
	_boss_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_warning.add_theme_font_size_override(&"font_size", 30)
	_boss_warning.add_theme_color_override(&"font_color", BOSS_COLOR)
	_boss_warning.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_boss_warning.add_theme_constant_override(&"outline_size", 8)
	_boss_warning.hide()
	root.add_child(_boss_warning)
	_boss_arrow = Polygon2D.new()
	_boss_arrow.polygon = PackedVector2Array([Vector2(0, -34), Vector2(26, 22), Vector2(0, 8), Vector2(-26, 22)])
	_boss_arrow.color = BOSS_COLOR
	_boss_arrow.hide()
	root.add_child(_boss_arrow)

	# Barra della vita del boss, in basso al centro.
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.offset_left = -260
	_boss_box.offset_right = 260
	_boss_box.offset_top = -78
	_boss_box.offset_bottom = -28
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.hide()
	root.add_child(_boss_box)
	var boss_name := _label(_boss_box, HORIZONTAL_ALIGNMENT_CENTER)
	boss_name.text = "IL DEMOLITORE"
	boss_name.add_theme_font_size_override(&"font_size", 20)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(520, 16)
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = BOSS_COLOR
	_boss_bar.add_theme_stylebox_override(&"fill", boss_fill)
	var boss_background := StyleBoxFlat.new()
	boss_background.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	_boss_bar.add_theme_stylebox_override(&"background", boss_background)
	_boss_box.add_child(_boss_bar)

	set_xp(0, 1, 1)
	set_time(0.0)
	set_kills(0)


## Annuncio dell'arrivo: [param direction] e nel mondo (-Z = alto dello schermo).
func set_boss_warning(direction_name: String, direction: Vector3, seconds_left: float) -> void:
	_boss_warning.text = "IL DEMOLITORE ARRIVA DA %s  -  %d" % [direction_name, int(ceil(maxf(seconds_left, 0.0)))]
	_boss_warning.show()
	var size := _root.size
	var screen_direction := Vector2(direction.x, direction.z).normalized()
	_boss_arrow.position = size * 0.5 + screen_direction * minf(size.x, size.y) * ARROW_RADIUS_RATIO
	_boss_arrow.rotation = screen_direction.angle() + PI * 0.5
	# Lampeggio lento: si nota senza coprire il campo.
	_boss_arrow.modulate.a = 0.55 + 0.45 * absf(sin(seconds_left * 4.0))
	_boss_arrow.show()


func clear_boss_warning() -> void:
	_boss_warning.hide()
	_boss_arrow.hide()


func is_boss_warning_visible() -> bool:
	return _boss_warning.visible


func set_boss_health(health: int, max_health: int) -> void:
	_boss_bar.max_value = maxi(max_health, 1)
	_boss_bar.value = maxi(health, 0)
	_boss_box.show()


func clear_boss() -> void:
	clear_boss_warning()
	_boss_box.hide()


func is_boss_bar_visible() -> bool:
	return _boss_box.visible


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
