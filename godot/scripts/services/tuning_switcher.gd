class_name TuningSwitcher
extends CanvasLayer
## Strumento di playtest: alterna preset di PlayerTuning a caldo con l'azione
## `debug_next_tuning` (Tab, croce destra) e mostra il nome per qualche secondo.
## Serve a scegliere il feel provando invece che descrivendo. Non e UI di gioco.

@export var player: PlayerCharacter
## Il primo e il riferimento Unreal; l'ordine e quello di rotazione.
@export var presets: Array[PlayerTuning] = []
@export var label_seconds := 2.5

var current_index := 0

var _label: Label
var _label_left := 0.0


func _ready() -> void:
	_label = Label.new()
	_label.name = "PresetLabel"
	# Mai interattiva: non deve rubare focus o input al gioco (vedi ui_accept).
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.focus_mode = Control.FOCUS_NONE
	_label.position = Vector2(24, 20)
	_label.add_theme_font_size_override(&"font_size", 22)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.visible = false
	add_child(_label)
	if player != null and not presets.is_empty():
		current_index = maxi(presets.find(player.tuning), 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_next_tuning") and not presets.is_empty() and player != null:
		select(posmod(current_index + 1, presets.size()))


func select(index: int) -> void:
	current_index = index
	var preset := presets[index]
	player.apply_tuning(preset)
	_label.text = "Feel: %s  (%d/%d)   Tab / croce destra" % [preset.display_name, index + 1, presets.size()]
	_label.visible = true
	_label_left = label_seconds
	print("PROTOTYPE01_TUNING %s" % preset.display_name)


func _process(delta: float) -> void:
	if _label_left > 0.0:
		_label_left -= delta
		if _label_left <= 0.0:
			_label.visible = false
