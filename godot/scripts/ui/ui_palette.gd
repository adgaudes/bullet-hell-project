class_name UiPalette
extends RefCounted
## Palette, font e tema dell'interfaccia (D-080). Un solo posto: le schermate usano le
## varianti di tipo (`theme_type_variation`) e non colorano piu i nodi uno a uno.
## `tests/tools/build_theme.gd` salva `build_theme()` in `resources/ui/theme.tres`, il tema di
## progetto (`gui/theme/custom`): va rilanciato dopo ogni modifica qui.

const BG := Color("17110d")
const PANEL := Color(0.165, 0.122, 0.094, 0.94)
const PANEL_RAISED := Color("38291f")
const BORDER := Color("b5652d")
const BORDER_LIGHT := Color("e0a060")
const TEXT := Color("f2e6cf")
const TEXT_MUTED := Color("c9a25f")
const FOCUS := Color("3fc1b5")
const DANGER := Color("e3553f")
const SUCCESS := Color("7fc24f")
const SCRAP := Color("f28a2e")
const XP := Color("1ad9a6")
const OUTLINE := Color("130d0a")

const TITLE_FONT_PATH := "res://assets/fonts/AlfaSlabOne-Regular.ttf"
const TEXT_FONT_PATH := "res://assets/fonts/Rubik[wght].ttf"

const SIZE_TITLE := 40
const SIZE_SECTION := 24
const SIZE_BUTTON := 22
const SIZE_TEXT := 18
const SIZE_SMALL := 16

static var _title_font: Font
static var _text_fonts: Dictionary = {}


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load(TITLE_FONT_PATH) as Font
		if _title_font == null:
			push_warning("UiPalette: font dei titoli mancante, uso il predefinito")
			_title_font = ThemeDB.fallback_font
	return _title_font


## Rubik al peso dato (400, 500, 700): una FontVariation per peso, condivisa.
static func text_font(weight := 400) -> Font:
	if not _text_fonts.has(weight):
		var base := load(TEXT_FONT_PATH) as Font
		if base == null:
			push_warning("UiPalette: font di testo mancante, uso il predefinito")
			_text_fonts[weight] = ThemeDB.fallback_font
		else:
			var variation := FontVariation.new()
			variation.base_font = base
			variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): float(weight)}
			_text_fonts[weight] = variation
	return _text_fonts[weight]


static func panel_box(raised := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_RAISED if raised else PANEL
	box.border_color = BORDER
	box.set_border_width_all(2)
	box.border_width_top = 3
	box.set_corner_radius_all(6)
	box.set_content_margin_all(16)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 3)
	return box


## Stile di un pulsante per stato: normal, hover, pressed, focus, disabled.
static func button_box(state: StringName, border: Color = BORDER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_RAISED
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	box.set_content_margin_all(10)
	box.content_margin_left = 18
	box.content_margin_right = 18
	match state:
		&"hover":
			box.border_color = BORDER_LIGHT
		&"pressed":
			box.bg_color = PANEL_RAISED.darkened(0.35)
		&"focus":
			box.border_color = FOCUS
			box.set_border_width_all(3)
			box.shadow_color = Color(FOCUS, 0.35)
			box.shadow_size = 6
			box.shadow_offset = Vector2.ZERO
		&"disabled":
			box.bg_color = Color(PANEL_RAISED, 0.6)
			box.border_color = Color(border, 0.3)
	return box


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = text_font()
	theme.default_font_size = SIZE_TEXT
	# Testo.
	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_type_variation(&"TitleLabel", &"Label")
	theme.set_font(&"font", &"TitleLabel", title_font())
	theme.set_font_size(&"font_size", &"TitleLabel", SIZE_TITLE)
	theme.set_color(&"font_color", &"TitleLabel", TEXT)
	theme.set_color(&"font_outline_color", &"TitleLabel", OUTLINE)
	theme.set_constant(&"outline_size", &"TitleLabel", 6)
	theme.set_type_variation(&"SectionLabel", &"Label")
	theme.set_font(&"font", &"SectionLabel", title_font())
	theme.set_font_size(&"font_size", &"SectionLabel", SIZE_SECTION)
	theme.set_color(&"font_color", &"SectionLabel", BORDER_LIGHT)
	theme.set_type_variation(&"MutedLabel", &"Label")
	theme.set_font_size(&"font_size", &"MutedLabel", SIZE_SMALL)
	theme.set_color(&"font_color", &"MutedLabel", TEXT_MUTED)
	theme.set_type_variation(&"ScrapLabel", &"Label")
	theme.set_font(&"font", &"ScrapLabel", text_font(700))
	theme.set_color(&"font_color", &"ScrapLabel", SCRAP)
	theme.set_type_variation(&"PromptLabel", &"Label")
	theme.set_font(&"font", &"PromptLabel", text_font(500))
	theme.set_font_size(&"font_size", &"PromptLabel", 17)
	theme.set_color(&"font_color", &"PromptLabel", TEXT)
	theme.set_color(&"font_outline_color", &"PromptLabel", OUTLINE)
	theme.set_constant(&"outline_size", &"PromptLabel", 4)
	theme.set_type_variation(&"HudLabel", &"Label")
	theme.set_font(&"font", &"HudLabel", title_font())
	theme.set_font_size(&"font_size", &"HudLabel", SIZE_SECTION)
	theme.set_color(&"font_color", &"HudLabel", TEXT)
	theme.set_color(&"font_outline_color", &"HudLabel", OUTLINE)
	theme.set_constant(&"outline_size", &"HudLabel", 6)
	# Pulsanti.
	theme.set_font(&"font", &"Button", text_font(500))
	theme.set_font_size(&"font_size", &"Button", SIZE_BUTTON)
	theme.set_color(&"font_color", &"Button", TEXT)
	theme.set_color(&"font_hover_color", &"Button", TEXT)
	theme.set_color(&"font_focus_color", &"Button", TEXT)
	theme.set_color(&"font_hover_pressed_color", &"Button", TEXT_MUTED)
	theme.set_color(&"font_pressed_color", &"Button", TEXT_MUTED)
	theme.set_color(&"font_disabled_color", &"Button", Color(TEXT, 0.45))
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		theme.set_stylebox(state, &"Button", button_box(state))
		theme.set_stylebox(state, &"OptionButton", button_box(state))
		theme.set_stylebox(state, &"CheckButton", button_box(state))
	theme.set_type_variation(&"MainButton", &"Button")
	theme.set_font(&"font", &"MainButton", text_font(700))
	theme.set_font_size(&"font_size", &"MainButton", SIZE_BUTTON)
	theme.set_type_variation(&"CardButton", &"Button")
	theme.set_font_size(&"font_size", &"CardButton", 17)
	# Pannelli, scorrimento, barre.
	theme.set_stylebox(&"panel", &"PanelContainer", panel_box())
	theme.set_stylebox(&"panel", &"PopupMenu", panel_box(true))
	theme.set_color(&"font_color", &"PopupMenu", TEXT)
	theme.set_color(&"font_hover_color", &"PopupMenu", BORDER_LIGHT)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = BORDER
	grabber.set_corner_radius_all(4)
	theme.set_stylebox(&"grabber", &"VScrollBar", grabber)
	theme.set_stylebox(&"grabber_highlight", &"VScrollBar", grabber)
	theme.set_stylebox(&"grabber_pressed", &"VScrollBar", grabber)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.4)
	theme.set_stylebox(&"scroll", &"VScrollBar", track)
	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = Color(0, 0, 0, 0.5)
	slider_track.border_color = BORDER
	slider_track.set_border_width_all(1)
	slider_track.set_corner_radius_all(3)
	theme.set_stylebox(&"slider", &"HSlider", slider_track)
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = BORDER
	slider_fill.set_corner_radius_all(3)
	theme.set_stylebox(&"grabber_area", &"HSlider", slider_fill)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", slider_fill)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.55)
	bar_bg.border_color = BORDER
	bar_bg.set_border_width_all(1)
	theme.set_stylebox(&"background", &"ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = XP
	theme.set_stylebox(&"fill", &"ProgressBar", bar_fill)
	return theme
