class_name RunHud
extends CanvasLayer
## HUD della run (D-038): barra esperienza in alto, livello, vita, tempo e
## rottamatori abbattuti; annuncio del boss con freccia di direzione e barra
## della sua vita (D-043). Solo lettura: mai focus ne input.

const HEALTH_ON := UiPalette.DANGER
const HEALTH_OFF := Color(0.18, 0.12, 0.12, 0.8)
const XP_COLOR := UiPalette.XP
const BOSS_COLOR := Color(0.95, 0.6, 0.08)
const DAY_COLOR := Color(1.0, 0.9, 0.55)
const NIGHT_COLOR := Color(0.6, 0.65, 1.0)
const TRAIN_COLOR := Color(1.0, 0.45, 0.3)
const QUAKE_COLOR := Color(0.9, 0.62, 0.32)
const EXTRACTION_COLOR := Color(0.35, 0.9, 0.6)
const TITLE_COLOR := UiPalette.TEXT
## Distanza della freccia di direzione dal centro dello schermo, in frazione del lato corto.
const ARROW_RADIUS_RATIO := 0.36
## Ingombro di una scritta degli indicatori, per non sovrapporle.
const MARKER_LABEL_SIZE := Vector2(120.0, 20.0)

var _xp_bar: ProgressBar
var _level_label: Label
var _time_label: Label
var _day_label: Label
var _day_dial: DayDial
var _dusk_total := -1.0
var _tool_label: Label
var _kills_label: Label
var _day_phase_shown := -1
var _day_second_shown := -1
var _night_notice_left := 0.0
var _night_notice_text := ""
var _health_row: HealthBolts
var _boss_warning: Label
var _warning_plate: PanelContainer
var _boss_name_label: Label
var _boss_arrow: Polygon2D
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _root: Control
var _controls: ButtonPrompts
## Indicatori a bordo schermo (punti di interesse, boss): freccia e distanza, riusati.
var _marker_arrows: Array[Polygon2D] = []
var _marker_labels: Array[Label] = []
var _markers_shown := 0
## Ultimi valori scritti nelle etichette: la stringa si rifa solo quando cambiano (U-06).
var _time_shown := -1
var _boss_seconds_shown := -1
var _boss_direction_shown := ""


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_xp_bar.offset_top = -8
	_xp_bar.offset_bottom = 0
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = XP_COLOR
	_xp_bar.add_theme_stylebox_override(&"fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	_xp_bar.add_theme_stylebox_override(&"background", background)
	root.add_child(_xp_bar)
	for side in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]:
		var cap := ColorRect.new()
		cap.color = UiPalette.BORDER
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(cap)
		cap.set_anchors_and_offsets_preset(side)
		cap.offset_top = -14
		cap.offset_bottom = 0
		if side == Control.PRESET_BOTTOM_LEFT:
			cap.offset_right = 6
		else:
			cap.offset_left = -6

	# Riga superiore: livello a sinistra, tempo al centro, abbattuti a destra.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 16
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_level_label = _label(top, HORIZONTAL_ALIGNMENT_LEFT)
	_level_label.add_theme_font_size_override(&"font_size", 22)
	_time_label = _label(top, HORIZONTAL_ALIGNMENT_CENTER)
	_time_label.add_theme_font_size_override(&"font_size", 28)
	var day_box := HBoxContainer.new()
	day_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_box.alignment = BoxContainer.ALIGNMENT_CENTER
	day_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_box.add_theme_constant_override(&"separation", 8)
	top.add_child(day_box)
	_day_dial = DayDial.new()
	_day_dial.hide()
	day_box.add_child(_day_dial)
	_day_label = _label(day_box, HORIZONTAL_ALIGNMENT_LEFT)
	_day_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_day_label.add_theme_font_size_override(&"font_size", 22)
	_day_label.add_theme_color_override(&"font_color", DAY_COLOR)
	_day_label.hide()
	_kills_label = _label(top, HORIZONTAL_ALIGNMENT_RIGHT)
	_kills_label.add_theme_font_size_override(&"font_size", 22)

	_health_row = HealthBolts.new()
	_health_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_health_row.offset_left = 24
	_health_row.offset_top = 58
	# Modalita del tool quando non e la solita (lampione: costo e contatore).
	_tool_label = Label.new()
	_tool_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tool_label.offset_left = 24
	_tool_label.offset_top = 90
	_tool_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_label.theme_type_variation = &"HudLabel"
	_tool_label.add_theme_font_size_override(&"font_size", 18)
	_tool_label.hide()
	root.add_child(_tool_label)
	root.add_child(_health_row)

	# Annuncio del boss: scritta sotto la riga superiore e freccia verso la direzione di arrivo.
	_warning_plate = PanelContainer.new()
	_warning_plate.add_theme_stylebox_override(&"panel", UiPalette.panel_box(true))
	_warning_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_plate.hide()
	root.add_child(_warning_plate)
	_warning_plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 96)
	_warning_plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warning_plate.rotation_degrees = -1.5
	_boss_warning = Label.new()
	_boss_warning.theme_type_variation = &"HudLabel"
	_boss_warning.add_theme_font_size_override(&"font_size", 28)
	_boss_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_warning.add_theme_color_override(&"font_color", BOSS_COLOR)
	_boss_warning.hide()
	_warning_plate.add_child(_boss_warning)
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
	_boss_box.offset_top = -96
	_boss_box.offset_bottom = -46
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.hide()
	root.add_child(_boss_box)
	_boss_name_label = _label(_boss_box, HORIZONTAL_ALIGNMENT_CENTER)
	_boss_name_label.text = "IL DEMOLITORE"
	_boss_name_label.add_theme_font_size_override(&"font_size", 20)
	_boss_name_label.add_theme_color_override(&"font_color", BOSS_COLOR)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(520, 14)
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = BOSS_COLOR
	_boss_bar.add_theme_stylebox_override(&"fill", boss_fill)
	var boss_background := StyleBoxFlat.new()
	boss_background.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	_boss_bar.add_theme_stylebox_override(&"background", boss_background)
	_boss_box.add_child(_boss_bar)

	# Comandi di gioco, in basso a sinistra.
	_controls = ButtonPrompts.create([[&"dash", "Scatto"], [&"terrain_tool", "Scava o rialza"],
		[&"terrain_mode", "Cambia modo"], [&"camera_zoom_cycle", "Distanza camera"], [&"pause", "Pausa"]], true)
	_controls.modulate.a = 0.85
	root.add_child(_controls)
	_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	_controls.grow_vertical = Control.GROW_DIRECTION_BEGIN

	set_xp(0, 1, 1)
	set_time(0.0)
	set_kills(0)


## Annuncio dell'arrivo del boss: [param direction] e nel mondo (-Z = alto dello schermo).
func set_boss_warning(boss_name: String, direction_name: String, direction: Vector3, seconds_left: float) -> void:
	set_event_warning("%s ARRIVA DA %s" % [boss_name, direction_name], direction, seconds_left, BOSS_COLOR)


## Nome sopra la barra vita del boss.
func set_boss_name(boss_name: String) -> void:
	_boss_name_label.text = boss_name


func boss_name_text() -> String:
	return _boss_name_label.text


## Annuncio con conto alla rovescia e freccia a bordo schermo verso [param direction]
## (nel mondo): boss in arrivo, treno in arrivo (livello 2).
func set_event_warning(text: String, direction: Vector3, seconds_left: float, color: Color, with_arrow := true) -> void:
	var seconds := int(ceil(maxf(seconds_left, 0.0)))
	if seconds != _boss_seconds_shown or text != _boss_direction_shown:
		_boss_seconds_shown = seconds
		_boss_direction_shown = text
		_boss_warning.text = "%s  -  %d" % [text, seconds]
		_boss_warning.add_theme_color_override(&"font_color", color)
		_night_notice_left = 0.0
	_boss_warning.show()
	_warning_plate.show()
	_warning_plate.pivot_offset = _warning_plate.size * 0.5
	if not with_arrow:
		_boss_arrow.hide()
		return
	var size := _root.size
	var screen_direction := Vector2(direction.x, direction.z).normalized()
	_boss_arrow.position = size * 0.5 + screen_direction * minf(size.x, size.y) * ARROW_RADIUS_RATIO
	_boss_arrow.rotation = screen_direction.angle() + PI * 0.5
	# Lampeggio lento: si nota senza coprire il campo.
	_boss_arrow.modulate.a = 0.55 + 0.45 * absf(sin(seconds_left * 4.0))
	_boss_arrow.show()


## Indicatori a bordo schermo. Ogni voce: { direction: Vector2 (schermo, x destra e
## y basso), distance: float (metri), color: Color, text: String }.
func set_markers(markers: Array[Dictionary]) -> void:
	while _marker_arrows.size() < markers.size():
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([Vector2(0, -16), Vector2(12, 10), Vector2(0, 4), Vector2(-12, 10)])
		_root.add_child(arrow)
		_marker_arrows.append(arrow)
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override(&"font_size", 15)
		label.add_theme_color_override(&"font_outline_color", Color.BLACK)
		label.add_theme_constant_override(&"outline_size", 5)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(120, 0)
		_root.add_child(label)
		_marker_labels.append(label)
	var size := _root.size
	var center := size * 0.5
	# Margini: in alto e in basso ci sono le righe dell'HUD e la barra del boss.
	var half := Vector2(maxf(center.x - 70.0, 10.0), maxf(center.y - 160.0, 10.0))
	var placed: Array[Rect2] = []
	for i in _marker_arrows.size():
		var shown := i < markers.size()
		_marker_arrows[i].visible = shown
		_marker_labels[i].visible = shown
		if not shown:
			continue
		var marker := markers[i]
		var direction: Vector2 = marker.direction
		if direction.is_zero_approx():
			direction = Vector2.UP
		direction = direction.normalized()
		var reach := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
		var spot := center + direction * reach
		_marker_arrows[i].position = spot
		_marker_arrows[i].rotation = direction.angle() + PI * 0.5
		_marker_arrows[i].color = marker.color
		var label := _marker_labels[i]
		label.text = "%s %d m" % [marker.text, int(round(marker.distance))]
		label.add_theme_color_override(&"font_color", marker.color)
		# Due punti nella stessa direzione: le scritte si impilano verso il centro
		# invece di sovrapporsi.
		var rect := Rect2(spot - direction * 30.0 - Vector2(60.0, 11.0), MARKER_LABEL_SIZE)
		var stack_step := MARKER_LABEL_SIZE.y if spot.y < center.y else -MARKER_LABEL_SIZE.y
		for attempt in markers.size():
			if not placed.any(func(other: Rect2) -> bool: return other.intersects(rect)):
				break
			rect.position.y += stack_step
		placed.append(rect)
		label.position = rect.position
	_markers_shown = markers.size()


func marker_count() -> int:
	return _markers_shown


func clear_boss_warning() -> void:
	clear_event_warning()


func clear_event_warning() -> void:
	_boss_warning.hide()
	_warning_plate.hide()
	_boss_arrow.hide()
	_boss_seconds_shown = -1
	_boss_direction_shown = ""


func event_warning_text() -> String:
	return _boss_warning.text if _boss_warning.visible else ""


## Un annuncio con la freccia (boss o treno) e a schermo; gli avvisi semplici
## (notte, titolo del livello) non contano.
func is_boss_warning_visible() -> bool:
	return _boss_warning.visible and _boss_arrow.visible


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


## Bulloni esagonali, ridisegnati solo quando cambiano i valori (U-07).
func set_health(health: int, max_health: int) -> void:
	_health_row.set_health(health, max_health)


## Modalita del tool: visibile solo in LAMP, con costo e contatore (specifica, sezione 9).
func set_tool_mode(mode: int, lamps: int, max_lamps: int, cost: int) -> void:
	if mode != TerrainState.ToolMode.LAMP:
		_tool_label.hide()
		return
	_tool_label.text = "LAMPIONE  %d rottami  %d/%d" % [cost, lamps, max_lamps]
	_tool_label.add_theme_color_override(&"font_color", TerrainGrid.LAMP_PREVIEW_COLOR.linear_to_srgb())
	_tool_label.show()


## Indicatore sole/luna nella riga superiore: tempo al tramonto di giorno, poi la fase.
## Con ciclo spento (`seconds_to_dusk` infinito) resta nascosto.
func set_day_phase(phase: int, seconds_to_dusk: float) -> void:
	if not is_finite(seconds_to_dusk):
		_day_label.hide()
		_day_dial.hide()
		_dusk_total = -1.0
		return
	if _dusk_total < 0.0:
		_dusk_total = maxf(seconds_to_dusk, 1.0)
	_day_dial.set_phase(phase, 1.0 - clampf(seconds_to_dusk / _dusk_total, 0.0, 1.0) if phase == DayNightCycle.Phase.DAY else 1.0)
	_day_dial.show()
	var second := int(ceil(seconds_to_dusk))
	if phase == _day_phase_shown and (phase != DayNightCycle.Phase.DAY or second == _day_second_shown):
		return
	_day_phase_shown = phase
	_day_second_shown = second
	match phase:
		DayNightCycle.Phase.DAY:
			_day_label.text = "SOLE %s" % format_time(seconds_to_dusk)
			_day_label.add_theme_color_override(&"font_color", DAY_COLOR)
		DayNightCycle.Phase.DUSK:
			_day_label.text = "TRAMONTO"
			_day_label.add_theme_color_override(&"font_color", DAY_COLOR)
		_:
			_day_label.text = "NOTTE"
			_day_label.add_theme_color_override(&"font_color", NIGHT_COLOR)
	_day_label.show()


## Avviso del tramonto o della notte, nello spazio dell'annuncio del boss, che ha la precedenza.
func show_night_notice(text: String, seconds: float) -> void:
	show_notice(text, seconds, NIGHT_COLOR)


## Avviso semplice senza freccia (notte, titolo del livello), nel colore dato.
func show_notice(text: String, seconds: float, color: Color) -> void:
	# Solo l'annuncio del boss (quello con la freccia) ha la precedenza; un avviso
	# precedente viene sostituito.
	if _boss_arrow.visible:
		return
	_night_notice_text = text
	_night_notice_left = seconds
	_boss_warning.text = text
	_boss_warning.add_theme_color_override(&"font_color", color)
	_boss_warning.show()
	_warning_plate.show()
	_warning_plate.pivot_offset = _warning_plate.size * 0.5


func is_night_notice_visible() -> bool:
	return _night_notice_left > 0.0 and _boss_warning.visible and _boss_warning.text == _night_notice_text


func _process(delta: float) -> void:
	if _night_notice_left <= 0.0:
		return
	_night_notice_left -= delta
	if _night_notice_left <= 0.0 and _boss_warning.text == _night_notice_text:
		_boss_warning.hide()
		_warning_plate.hide()
		_boss_warning.add_theme_color_override(&"font_color", BOSS_COLOR)


func set_time(seconds: float) -> void:
	var total := int(seconds)
	if total == _time_shown:
		return
	_time_shown = total
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
	label.theme_type_variation = &"HudLabel"
	parent.add_child(label)
	return label
