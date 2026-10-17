class_name CaravanStrip
extends PanelContainer
## Striscia della carovana del HUD (spec D-093, Sezione 6; scelta 11 del piano A), sopra quella
## delle armi. A sinistra i rottami ("3/5"), poi una casella per macchina: icona del modulo,
## cornice del colore del modulo, tacche di vita, bordo rosso e barra diagonale da guasta, tinta
## da ritirata, spicchio della riparazione dalle 12 in senso orario. In fondo il tasto Interagisci
## ("Ripara"), acceso solo vicino a una macchina guasta: il suo posto resta, le caselle non si
## spostano. Solo lettura: mai focus ne input.
## Voci di `set_machines`: {icon, color, health, max_health, state (Machine.State), repair (0..1)}.

const SLOT_SIZE := 40.0
const ROW_HEIGHT := 52.0

var _slot_row: HBoxContainer
var _slots: Array[CaravanSlot] = []
var _scrap_label: Label
var _prompt: ButtonPrompts
var _prompt_shown := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(&"panel", UiPalette.plate("strip", UiPalette.panel_box(true), 18.0, 0.0, Vector4(14, 6, 14, 6)))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_constant_override(&"separation", 8)
	add_child(row)
	var scrap := UiIcon.make(&"scrap", 24.0, UiPalette.SCRAP)
	scrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(scrap)
	_scrap_label = Label.new()
	_scrap_label.name = "ScrapLabel"
	_scrap_label.theme_type_variation = &"HudLabel"
	_scrap_label.add_theme_font_size_override(&"font_size", 20)
	_scrap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrap_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_scrap_label)
	_slot_row = HBoxContainer.new()
	_slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_row.add_theme_constant_override(&"separation", 4)
	_slot_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_slot_row)
	_prompt = ButtonPrompts.create([[&"interact", "Ripara"]])
	_prompt.icon_size = 24
	_prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prompt.modulate.a = 0.0
	row.add_child(_prompt)


## Una casella per voce: si aggiungono o tolgono solo quando cambia il numero, le altre si
## aggiornano sul posto.
func set_machines(entries: Array) -> void:
	while _slots.size() > entries.size():
		var last: CaravanSlot = _slots.pop_back()
		_slot_row.remove_child(last)
		last.queue_free()
	while _slots.size() < entries.size():
		var slot := CaravanSlot.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		_slot_row.add_child(slot)
		_slots.append(slot)
	for i in entries.size():
		_slots[i].show_entry(entries[i])


func set_scrap(carried: int, capacity: int) -> void:
	var text := "%d/%d" % [carried, capacity]
	if _scrap_label.text != text:
		_scrap_label.text = text


## Tasto "Ripara" acceso o spento; spento tiene il suo posto (trasparente).
func set_prompt(shown: bool) -> void:
	if shown == _prompt_shown:
		return
	_prompt_shown = shown
	_prompt.modulate.a = 1.0 if shown else 0.0


func slot_count() -> int:
	return _slots.size()


func slot_state(index: int) -> int:
	return int(_slots[index].entry.get(&"state", Machine.State.OK))


func slot_health(index: int) -> int:
	return int(_slots[index].entry.get(&"health", 0))


func slot_repair(index: int) -> float:
	return float(_slots[index].entry.get(&"repair", 0.0))


func scrap_text() -> String:
	return _scrap_label.text


func prompt_visible() -> bool:
	return _prompt_shown


class CaravanSlot:
	extends Control

	## Tinta della casella di una macchina in ritirata.
	const RETREAT_TINT := Color(0.95, 0.72, 0.2, 0.45)
	const REPAIR_COLOR := Color(0.5, 0.85, 0.35, 0.55)
	const HEALTH_ON := Color("7fc24f")
	const HEALTH_OFF := Color(0.25, 0.2, 0.16)
	var entry: Dictionary = {}
	var _icon: UiIcon
	## Sopra l'icona: spicchio della riparazione, barra del guasto e tacche di vita.
	var _overlay: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon = UiIcon.make(&"crate", 0.0)
		_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		_icon.offset_left = 5.0
		_icon.offset_top = 3.0
		_icon.offset_right = -5.0
		_icon.offset_bottom = -9.0
		add_child(_icon)
		_overlay = Control.new()
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay.draw.connect(_draw_overlay)
		add_child(_overlay)
		_apply()

	## Ridisegna solo se la voce cambia.
	func show_entry(next: Dictionary) -> void:
		if next == entry:
			return
		entry = next
		_apply()

	func _apply() -> void:
		if _icon == null:
			return
		_icon.kind = entry.get(&"icon", &"crate")
		queue_redraw()
		_overlay.queue_redraw()

	func _state() -> int:
		return int(entry.get(&"state", Machine.State.OK))

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.08, 0.06, 0.05, 0.85))
		if _state() == Machine.State.RETREAT:
			draw_rect(rect, RETREAT_TINT)
		var frame: Color = UiPalette.DANGER if _state() == Machine.State.BROKEN else entry.get(&"color", UiPalette.BORDER)
		draw_rect(rect.grow(-1.0), frame, false, 2.0)

	func _draw_overlay() -> void:
		var repair := float(entry.get(&"repair", 0.0))
		if repair >= 0.005:
			# Spicchio che cresce dalle 12 in senso orario mentre si tiene Interagisci, nel cerchio
			# inscritto: punti tutti distinti (ritagliati al quadrato si sovrapporrebbero sul bordo).
			var center := size * 0.5
			var radius := minf(size.x, size.y) * 0.5 - 2.0
			if repair >= 0.999:
				_overlay.draw_circle(center, radius, REPAIR_COLOR)
			else:
				var steps := maxi(ceili(32.0 * repair), 2)
				var points := PackedVector2Array([center])
				for s in steps + 1:
					var angle := -PI * 0.5 + TAU * repair * float(s) / steps
					points.append(center + Vector2(cos(angle), sin(angle)) * radius)
				_overlay.draw_colored_polygon(points, REPAIR_COLOR)
		if _state() == Machine.State.BROKEN:
			_overlay.draw_line(Vector2(4.0, size.y - 4.0), Vector2(size.x - 4.0, 4.0), UiPalette.DANGER, 4.0, true)
		# Tacche di vita in basso: piene fino ai PV attuali.
		var max_health := maxi(int(entry.get(&"max_health", 0)), 1)
		var health := int(entry.get(&"health", 0))
		var pip_w := (size.x - 8.0) / max_health
		for p in max_health:
			var pip := Rect2(4.0 + p * pip_w + 0.5, size.y - 7.0, pip_w - 1.0, 4.0)
			_overlay.draw_rect(pip, HEALTH_ON if p < health else HEALTH_OFF)
