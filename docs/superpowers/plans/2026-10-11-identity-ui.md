# Identità e interfaccia, piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dare al gioco il nome "Dwarmageddon: Dig or Die", un logo vettoriale, un tema UI unico applicato a tutte le schermate, un HUD ridisegnato e un'intro all'avvio saltabile con aggancio per una vignetta futura; catture prima/dopo per il giudizio del proprietario.

**Architecture:** Un modulo `UiPalette` (RefCounted, costanti e `build_theme()`) costruisce a runtime un `Theme` con varianti di tipo; un autoload `UiTheme` lo applica a `root.theme` prima di ogni scena, così le schermate usano `theme_type_variation` e smettono di colorarsi da sole. Il logo è una scena `GameLogo` (Label per lettera più `_draw()` per chiodo, crepa, zolla ed erba) con metodi di progresso che l'intro `BootIntro` anima con tween; `BootIntro` è la nuova `main_scene` e passa subito al menu quando la riga di comando chiede un livello o il motore è headless.

**Tech Stack:** Godot 4.7.2 (GDScript, canvas_item shader), font OFL da `github.com/google/fonts`, gate `tools/godot/Invoke-GodotChecks.ps1`, Git LFS per i `.png`.

**Spec:** `docs/superpowers/specs/2026-10-11-identity-ui-design.md`

## Global Constraints

- Niente asset esterni oltre ai due font OFL; niente immagini generate da AI (spec §1, D-077).
- Identificatori, nomi di file e nodi in inglese; testi mostrati in italiano.
- I marcatori `PROTOTYPE01_MENU_READY`, `PROTOTYPE01_TESTS`, `PROTOTYPE01_LEVEL_CHOSEN` non cambiano.
- Contratti letti dai test esistenti e da conservare: `MainMenu._column`, `_play`, `_scrap_label.text` con "Rottami in Officina: N"; `GameOverPanel._summary.text` con "Rottami in Officina N"; `RunHud._day_label` (`text` con "02:05"/"NOTTE", `visible`), `_tool_label`, `TITLE_COLOR`, `EXTRACTION_COLOR`, `QUAKE_COLOR`, `TRAIN_COLOR`; nodi `%SettingsPanel`, `%PausePanel`, `%BackButton`, `%Content`, `%PresetOption` e gli altri `%` di `pause_menu.tscn`; testi dei pulsanti ("Gioca", "Officina", "Impostazioni", "Esci", "Riprendi", "Torna al menu", "Indietro", "Torna", "Compra").
- Testo mai sotto 14 px a 1280x800; focus sempre distinguibile dall'hover (bordo `FOCUS` + bagliore).
- Catture mai in headless, sempre con `--quit-after`; `--out=` relativo (`../output/...`).
- Gate verde prima di ogni commit: `powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1`; `--check-only` su ogni script toccato: `godot_console --headless --path godot --check-only --script res://scripts/ui/<file>.gd`.
- Nei test headless gli autoload degli addon sono pronti dopo il primo frame; `ControllerIcons.parse_path` va chiamato con tipo controller (`1`).
- Commit piccoli, messaggio in italiano, chiusi da `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Con l'editor Godot aperto dal proprietario: dire quali scene si toccano (`pause_menu.tscn`, `main_menu.tscn`, `boot_intro.tscn`, `game_logo.tscn`).

## Review Focus

1. **Avvio senza argomenti in headless** (gate, smoke test con `--autostart`): `BootIntro` deve passare al menu nello stesso frame senza aspettare 4 s, altrimenti lo smoke test con `--quit-after 180` non vede `PROTOTYPE01_MENU_READY`. Test in Task 8.
2. **Tasto premuto durante la dissolvenza finale dell'intro**: non deve cambiare scena due volte (`change_scene_to_file` doppio = errore e menu duplicato). Test in Task 8.
3. **Pausa premuta durante l'intro**: `PauseMenu.enabled` deve essere falso e tornare vero al menu, altrimenti si apre la pausa sopra il logo. Test in Task 8.
4. **Font mancante o non importato** (checkout senza `.import`, LFS): `UiPalette.build_theme()` non deve lanciare; con font nullo il tema usa il font predefinito e i test lo segnalano. Test in Task 1.
5. **Vita massima che cambia** (upgrade Scarponi/vita): i bulloni esagonali si ricreano solo al cambio di massimo, come oggi le tacche, senza lasciare figli orfani. Test in Task 7.

---

### Task 0: Catture "prima"

**Files:**
- Create: `output/identity/before/*.png` (LFS)

- [ ] **Step 1: Eseguire le catture esistenti verso `output/identity/before`**

```bash
cd /c/Users/adgau/Desktop/Videogame
godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_workshop.gd -- --out=../output/identity/before
godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 600 --script res://tests/tools/capture_settings.gd -- --out=../output/identity/before
godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_run.gd -- --out=../output/identity/before
godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_campaign.gd -- --out=../output/identity/before
```

Atteso: righe `CAPTURE ... err=0`; in `output/identity/before/` i file `menu`, `workshop`, `game_over`, `settings_top`, `settings_bottom`, `combat`, `level_up`, `map_new`, `map_unlocked`, `victory_next`.

- [ ] **Step 2: Commit**

```bash
git add output/identity/before
git commit -m "Catture dell'interfaccia prima del restyling di identita e UI"
```

---

### Task 1: Font, palette e tema applicato alla radice

**Files:**
- Create: `godot/assets/fonts/AlfaSlabOne-Regular.ttf`, `godot/assets/fonts/Rubik[wght].ttf`, `godot/assets/fonts/OFL-AlfaSlabOne.txt`, `godot/assets/fonts/OFL-Rubik.txt`, `godot/assets/fonts/AlfaSlabOne-Regular.ttf.import`
- Create: `godot/scripts/ui/ui_palette.gd`, `godot/scripts/ui/ui_theme.gd`
- Modify: `godot/project.godot` ([autoload]: `UiTheme` prima di `PauseMenu`)
- Test: `godot/tests/ui_theme_tests.gd`

**Interfaces:**
- Produces: `class_name UiPalette extends RefCounted` con costanti `BG, PANEL, PANEL_RAISED, BORDER, BORDER_LIGHT, TEXT, TEXT_MUTED, FOCUS, DANGER, SUCCESS, SCRAP, XP: Color`; `static func title_font() -> Font`; `static func text_font(weight := 400) -> Font`; `static func build_theme() -> Theme`; `static func panel_box(raised := false) -> StyleBoxFlat`; `static func button_box(state: StringName, border: Color = BORDER) -> StyleBoxFlat`; `static func paper_texture() -> Texture2D`. Varianti di tipo nel tema: `TitleLabel`, `SectionLabel`, `MutedLabel`, `HudLabel`, `MenuButton`, `CardButton`, `ScrapLabel`.
- Autoload `UiTheme` (`scripts/ui/ui_theme.gd`, senza class_name): in `_enter_tree` fa `get_tree().root.theme = UiPalette.build_theme()`.

- [ ] **Step 1: Scaricare i font e le licenze**

```bash
cd /c/Users/adgau/Desktop/Videogame/godot/assets && mkdir -p fonts && cd fonts
curl -L -o AlfaSlabOne-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/alfaslabone/AlfaSlabOne-Regular.ttf"
curl -L -o OFL-AlfaSlabOne.txt "https://github.com/google/fonts/raw/main/ofl/alfaslabone/OFL.txt"
curl -L -o "Rubik[wght].ttf" "https://github.com/google/fonts/raw/main/ofl/rubik/Rubik%5Bwght%5D.ttf"
curl -L -o OFL-Rubik.txt "https://github.com/google/fonts/raw/main/ofl/rubik/OFL.txt"
ls -la; head -3 OFL-AlfaSlabOne.txt OFL-Rubik.txt
```

Atteso: due `.ttf` da 100-300 KB; le licenze iniziano con "Copyright ... SIL Open Font License, Version 1.1". Se la riga di licenza non è OFL, fermarsi e sostituire la famiglia (riserve: Bungee, Nunito).

- [ ] **Step 2: Importare con MSDF il font slab**

Scrivere `AlfaSlabOne-Regular.ttf.import` (Godot lo completa al primo `--editor --quit`):

```ini
[remap]

importer="font_data_dynamic"
type="FontFile"
path="res://.godot/imported/AlfaSlabOne-Regular.ttf-PLACEHOLDER.fontdata"

[deps]

source_file="res://assets/fonts/AlfaSlabOne-Regular.ttf"

[params]

Rendering=null
antialiasing=1
generate_mipmaps=false
disable_embedded_bitmaps=true
multichannel_signed_distance_field=true
msdf_pixel_range=12
msdf_size=64
allow_system_fallback=true
force_autohinter=false
hinting=1
subpixel_positioning=1
keep_rounding_remainders=true
oversampling=0.0
Fallbacks=null
fallbacks=[]
Compress=null
compress=true
preload=[]
language_support={}
script_support={}
opentype_features={}
```

Poi: `godot_console --headless --path godot --editor --quit` e verificare che `.godot/imported/` contenga i due `.fontdata` e che l'`.import` di Alfa Slab mantenga `multichannel_signed_distance_field=true` (se l'editor lo riscrive con `path=` corretto va bene; se rimette `false`, cancellare il `.md5` corrispondente in `.godot/imported/` e rilanciare, trappola già nota per le texture).

- [ ] **Step 3: Scrivere il test che fallisce**

`godot/tests/ui_theme_tests.gd`:

```gdscript
extends SceneTree
## Test del tema dell'interfaccia (D-080). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/ui_theme_tests.gd

const MenuScene := preload("res://scenes/main/main_menu.tscn")
const PauseScene := preload("res://scenes/ui/pause_menu.tscn")

var _failures := 0


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	await _frames(1)
	_test_palette()
	_test_theme_on_root()
	await _test_screens_focus()
	await _frames(2)
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _test_palette() -> void:
	_check(UiPalette.title_font() != null and UiPalette.text_font() != null, "i due font si caricano")
	_check(UiPalette.text_font(700) != UiPalette.text_font(400), "il peso 700 e una variazione distinta")
	var theme := UiPalette.build_theme()
	_check(theme.default_font == UiPalette.text_font(), "font di testo predefinito nel tema")
	_check(theme.default_font_size == 18, "testo a 18 px")
	for variation: StringName in [&"TitleLabel", &"SectionLabel", &"MutedLabel", &"HudLabel", &"ScrapLabel"]:
		_check(theme.get_type_variation_base(variation) == &"Label", "variante %s di Label" % variation)
	for variation: StringName in [&"MenuButton", &"CardButton"]:
		_check(theme.get_type_variation_base(variation) == &"Button", "variante %s di Button" % variation)
	_check(theme.get_font_size(&"font_size", &"TitleLabel") == 40, "titolo a 40 px")
	var smallest := 999
	for type_name in theme.get_font_size_type_list():
		for size_name in theme.get_font_size_list(type_name):
			smallest = mini(smallest, theme.get_font_size(size_name, type_name))
	_check(smallest >= 14, "nessuna dimensione sotto 14 px (minima %d)" % smallest)
	var normal := theme.get_stylebox(&"normal", &"Button") as StyleBoxFlat
	var focus := theme.get_stylebox(&"focus", &"Button") as StyleBoxFlat
	var hover := theme.get_stylebox(&"hover", &"Button") as StyleBoxFlat
	_check(normal != null and focus != null and hover != null, "pulsante con stylebox piatti")
	_check(focus.border_color == UiPalette.FOCUS and focus.border_color != hover.border_color, "focus turchese, diverso dall'hover")
	_check(focus.shadow_size > 0 and normal.shadow_size == 0, "bagliore solo sul focus")
	_check(UiPalette.paper_texture() != null and UiPalette.paper_texture() == UiPalette.paper_texture(), "grana di carta generata una volta")


func _test_theme_on_root() -> void:
	_check(root.theme != null and root.theme.default_font == UiPalette.text_font(), "l'autoload UiTheme applica il tema alla radice")


## Ogni pulsante delle schermate eredita dal tema un focus diverso dal normale.
func _test_screens_focus() -> void:
	var menu := MenuScene.instantiate()
	root.add_child(menu)
	await _frames(3)
	var buttons: Array[Button] = []
	_collect_buttons(menu, buttons)
	_check(buttons.size() >= 4, "menu con almeno 4 pulsanti (%d)" % buttons.size())
	var all_distinct := true
	var all_big := true
	for button in buttons:
		if button.get_theme_stylebox(&"focus") == button.get_theme_stylebox(&"normal"):
			all_distinct = false
		if button.get_theme_font_size(&"font_size") < 14:
			all_big = false
	_check(all_distinct, "ogni pulsante del menu ha un focus distinto")
	_check(all_big, "nessun pulsante sotto 14 px")
	_check((menu.get_node_or_null(^"Background") as Control) != null, "menu con sfondo dipinto")
	menu.queue_free()
	await _frames(2)


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	if node is Button:
		out.append(node)
	for child in node.get_children():
		_collect_buttons(child, out)
```

- [ ] **Step 4: Eseguirlo e vederlo fallire**

Run: `godot_console --headless --path godot --fixed-fps 60 --script res://tests/ui_theme_tests.gd`
Atteso: errore di parse `Identifier "UiPalette" not declared`.

- [ ] **Step 5: Scrivere `ui_palette.gd`**

```gdscript
class_name UiPalette
extends RefCounted
## Palette, font e tema dell'interfaccia (D-080). Un solo posto: le schermate usano le
## varianti di tipo (`theme_type_variation`) e non colorano piu i nodi uno a uno.
## L'autoload UiTheme applica `build_theme()` alla radice prima di ogni scena.

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
static var _paper: Texture2D


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
			variation.variation_opentype = {TextServer.name_to_tag("weight"): float(weight)}
			_text_fonts[weight] = variation
	return _text_fonts[weight]


## Grana di carta: rumore a basso contrasto 256x256, ripetibile, generato una volta.
static func paper_texture() -> Texture2D:
	if _paper == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.frequency = 0.08
		noise.seed = 7
		var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		for y in 256:
			for x in 256:
				var v := 0.5 + 0.5 * noise.get_noise_2d(float(x), float(y))
				image.set_pixel(x, y, Color(1.0, 0.92, 0.8, 0.06 * v))
		_paper = ImageTexture.create_from_image(image)
	return _paper


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
	theme.set_color(&"font_pressed_color", &"Button", TEXT_MUTED)
	theme.set_color(&"font_disabled_color", &"Button", Color(TEXT, 0.45))
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		theme.set_stylebox(state, &"Button", button_box(state))
		theme.set_stylebox(state, &"OptionButton", button_box(state))
		theme.set_stylebox(state, &"CheckButton", button_box(state))
	theme.set_type_variation(&"MenuButton", &"Button")
	theme.set_font(&"font", &"MenuButton", text_font(700))
	theme.set_font_size(&"font_size", &"MenuButton", SIZE_BUTTON)
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
```

- [ ] **Step 6: Scrivere l'autoload `ui_theme.gd` e registrarlo**

```gdscript
extends Node
## Autoload UiTheme (D-080): applica il tema di UiPalette alla radice prima che
## qualunque scena (compreso l'autoload PauseMenu) costruisca i suoi Control.


func _enter_tree() -> void:
	get_tree().root.theme = UiPalette.build_theme()
```

In `project.godot`, sezione `[autoload]`, prima di `PauseMenu`:

```ini
UiTheme="*res://scripts/ui/ui_theme.gd"
```

- [ ] **Step 7: Menu con nodo `Background`**

Nel `_build()` di `main_menu.gd` dare al `ColorRect` di sfondo `background.name = "Background"` (il resto del menu cambia nel Task 3; qui basta il nome perché il test passi).

- [ ] **Step 8: Eseguire il test e vederlo passare**

Run: `godot_console --headless --path godot --fixed-fps 60 --script res://tests/ui_theme_tests.gd`
Atteso: `PROTOTYPE01_TESTS PASS failures=0`. Se "il peso 700 e una variazione distinta" fallisce perché `name_to_tag("weight")` non è riconosciuto, usare la chiave `TextServer.name_to_tag("wght")` e annotare la trappola in `GODOT_WORKFLOW.md`.

- [ ] **Step 9: Gate e commit**

```bash
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
git add godot/assets/fonts godot/scripts/ui/ui_palette.gd godot/scripts/ui/ui_theme.gd godot/project.godot godot/tests/ui_theme_tests.gd godot/scripts/ui/main_menu.gd
git commit -m "Tema dell'interfaccia: font Alfa Slab One e Rubik (OFL), palette e varianti di tipo applicate alla radice (D-080)"
```

---

### Task 2: Logo `GameLogo`

**Files:**
- Create: `godot/scripts/ui/game_logo.gd`, `godot/scenes/ui/game_logo.tscn`, `godot/resources/materials/logo_letters.gdshader`
- Create: `godot/tests/tools/capture_logo.gd`
- Test: aggiunte a `godot/tests/ui_theme_tests.gd`

**Interfaces:**
- Produces: `class_name GameLogo extends Control`; `@export_enum("wide", "stacked") var layout := "wide"`; `@export var show_subtitle := true`; `@export var letter_size := 96`; metodi `set_letter_progress(p: float)`, `set_nail_progress(p: float)`, `set_subtitle_progress(p: float)`, `set_grass_progress(p: float)`, `set_all(p: float)`, `letter_count() -> int`; costanti `TITLE := "DWARMAGEDDON"`, `SUBTITLE := "DIG OR DIE"`, `NAIL_LETTER := 9` (indice della prima "O"). La dimensione del Control è fissa in `_ready` (`custom_minimum_size`) e dipende da `layout` e `letter_size`.

- [ ] **Step 1: Aggiungere al test**

In `ui_theme_tests.gd`, nuova funzione chiamata da `_initialize` dopo `_test_theme_on_root()`:

```gdscript
func _test_logo() -> void:
	for layout in ["wide", "stacked"]:
		var logo := GameLogo.new()
		logo.layout = layout
		root.add_child(logo)
		await _frames(1)
		_check(logo.letter_count() == GameLogo.TITLE.length(), "%s: una Label per lettera" % layout)
		_check(logo.custom_minimum_size.x > 300 and logo.custom_minimum_size.y > 80, "%s: dimensione calcolata" % layout)
		for p in [0.0, 0.5, 1.0]:
			logo.set_letter_progress(p)
			logo.set_nail_progress(p)
			logo.set_subtitle_progress(p)
			logo.set_grass_progress(p)
		logo.set_all(1.0)
		_check(logo.is_complete(), "%s: set_all(1) completa il logo" % layout)
		logo.queue_free()
	await _frames(1)
```

Run: `godot_console --headless --path godot --fixed-fps 60 --script res://tests/ui_theme_tests.gd` → atteso errore `GameLogo` non dichiarato.

- [ ] **Step 2: Shader del gradiente delle lettere**

`godot/resources/materials/logo_letters.gdshader`:

```glsl
shader_type canvas_item;
// Gradiente verticale sul riempimento delle lettere: la Label disegna i glifi
// bianchi e l'outline scuro; moltiplicando per il gradiente il bianco prende
// rame -> ocra e l'outline resta scuro. `top_y`/`bottom_y` in pixel locali.
uniform vec3 top_color : source_color = vec3(0.93, 0.70, 0.38);
uniform vec3 bottom_color : source_color = vec3(0.65, 0.33, 0.14);
uniform vec3 rim_color : source_color = vec3(1.0, 0.92, 0.78);
uniform float top_y = 0.0;
uniform float bottom_y = 96.0;

varying float t;

void vertex() {
	t = clamp((VERTEX.y - top_y) / max(bottom_y - top_y, 1.0), 0.0, 1.0);
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV) * COLOR;
	vec3 fill = mix(top_color, bottom_color, t);
	fill = mix(rim_color, fill, smoothstep(0.0, 0.12, t));
	COLOR = vec4(glyph.rgb * fill, glyph.a);
}
```

- [ ] **Step 3: Scrivere `game_logo.gd`**

```gdscript
class_name GameLogo
extends Control
## Logo "Dwarmageddon: Dig or Die" (D-079), vettoriale: una Label per lettera su una
## linea di base ad arco, chiodo piantato nella prima "O" con crepa, zolla con ciuffi
## d'erba sotto, sottotitolo su targa inclinata. I metodi `set_*_progress` (0..1)
## servono all'intro (BootIntro) per animarlo; `set_all(1.0)` lo mostra finito.

const TITLE := "DWARMAGEDDON"
const SUBTITLE := "DIG OR DIE"
const NAIL_LETTER := 9
const ARC_PIXELS := 0.09
const DROP_PIXELS := 1.6
const SUBTITLE_TILT := -2.0

@export_enum("wide", "stacked") var layout := "wide"
@export var show_subtitle := true
@export var letter_size := 96

var _letters: Array[Label] = []
var _rest_positions: Array[Vector2] = []
var _letter_progress := 1.0
var _nail_progress := 1.0
var _subtitle_progress := 1.0
var _grass_progress := 1.0
var _subtitle: Label
var _plate: Control
var _rows: Array[String] = []
var _nail_anchor := Vector2.ZERO
var _ground_rect := Rect2()
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows = [TITLE] if layout == "wide" else [TITLE.substr(0, 6), TITLE.substr(6)]
	_material = ShaderMaterial.new()
	_material.shader = load("res://resources/materials/logo_letters.gdshader")
	_material.set_shader_parameter(&"top_y", 0.0)
	_material.set_shader_parameter(&"bottom_y", float(letter_size))
	_build_letters()
	_build_subtitle()
	queue_redraw()


func letter_count() -> int:
	return _letters.size()


func is_complete() -> bool:
	return _letter_progress >= 1.0 and _nail_progress >= 1.0 and _subtitle_progress >= 1.0 and _grass_progress >= 1.0


func set_all(p: float) -> void:
	set_letter_progress(p)
	set_nail_progress(p)
	set_subtitle_progress(p)
	set_grass_progress(p)


## Le lettere cadono una alla volta: la lettera i parte a i/n e atterra a (i+1)/n.
func set_letter_progress(p: float) -> void:
	_letter_progress = clampf(p, 0.0, 1.0)
	var n := _letters.size()
	for i in n:
		var local := clampf(_letter_progress * n - i, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - local, 3.0)
		var drop := DROP_PIXELS * letter_size * (1.0 - eased)
		_letters[i].position = _rest_positions[i] + Vector2(0, -drop)
		_letters[i].modulate.a = minf(local * 3.0, 1.0)


func set_nail_progress(p: float) -> void:
	_nail_progress = clampf(p, 0.0, 1.0)
	queue_redraw()


func set_subtitle_progress(p: float) -> void:
	_subtitle_progress = clampf(p, 0.0, 1.0)
	if _plate == null:
		return
	var s := lerpf(1.3, 1.0, 1.0 - pow(1.0 - _subtitle_progress, 2.0))
	_plate.scale = Vector2(s, s)
	_plate.modulate.a = minf(_subtitle_progress * 4.0, 1.0)


func set_grass_progress(p: float) -> void:
	_grass_progress = clampf(p, 0.0, 1.0)
	queue_redraw()


func _build_letters() -> void:
	var font := UiPalette.title_font()
	var row_height := float(letter_size) * 1.05
	var widest := 0.0
	var row_widths: Array[float] = []
	for row in _rows:
		var w := 0.0
		for ch in row:
			w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size).x * 0.92
		row_widths.append(w)
		widest = maxf(widest, w)
	var subtitle_height := float(letter_size) * 0.55 if show_subtitle else 0.0
	var ground_height := float(letter_size) * 0.35
	custom_minimum_size = Vector2(widest + letter_size * 0.6, row_height * _rows.size() + subtitle_height + ground_height)
	size = custom_minimum_size
	var y := 0.0
	var index := 0
	for r in _rows.size():
		var row := _rows[r]
		var x := (custom_minimum_size.x - row_widths[r]) * 0.5
		var count := row.length()
		for c in count:
			var label := Label.new()
			label.text = row[c]
			label.theme_type_variation = &"TitleLabel"
			label.add_theme_font_size_override(&"font_size", letter_size)
			label.add_theme_constant_override(&"outline_size", maxi(letter_size / 12, 4))
			label.material = _material
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(label)
			var glyph_w := font.get_string_size(row[c], HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size).x * 0.92
			var t := float(c) / maxf(count - 1, 1)
			var arc := -ARC_PIXELS * letter_size * sin(PI * t)
			var rest := Vector2(x, y + arc)
			_rest_positions.append(rest)
			label.position = rest
			_letters.append(label)
			if index == NAIL_LETTER:
				_nail_anchor = rest + Vector2(glyph_w * 0.5, letter_size * 0.62)
			x += glyph_w
			index += 1
		y += row_height
	_ground_rect = Rect2(letter_size * 0.1, y - letter_size * 0.1, custom_minimum_size.x - letter_size * 0.2, ground_height)


func _build_subtitle() -> void:
	if not show_subtitle:
		return
	_plate = Control.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	var plate_size := Vector2(letter_size * 3.4, letter_size * 0.42)
	_plate.position = Vector2((custom_minimum_size.x - plate_size.x) * 0.5, _ground_rect.position.y + _ground_rect.size.y * 0.25)
	_plate.size = plate_size
	_plate.pivot_offset = plate_size * 0.5
	_plate.rotation_degrees = SUBTITLE_TILT
	var panel := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiPalette.OUTLINE
	box.border_color = UiPalette.BORDER
	box.set_border_width_all(maxi(letter_size / 32, 2))
	box.set_corner_radius_all(3)
	panel.add_theme_stylebox_override(&"panel", box)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(panel)
	_subtitle = Label.new()
	_subtitle.text = SUBTITLE
	_subtitle.theme_type_variation = &"SectionLabel"
	_subtitle.add_theme_font_size_override(&"font_size", int(letter_size * 0.28))
	_subtitle.add_theme_color_override(&"font_color", UiPalette.TEXT)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_subtitle)


func _draw() -> void:
	_draw_ground()
	_draw_grass()
	_draw_nail()


## Zolla: poligono scuro con bordo superiore ondulato e una riga di luce.
func _draw_ground() -> void:
	var r := _ground_rect
	var top: PackedVector2Array = []
	var steps := 12
	for i in steps + 1:
		var t := float(i) / steps
		top.append(Vector2(r.position.x + r.size.x * t, r.position.y + sin(t * 9.0) * r.size.y * 0.12))
	var polygon := PackedVector2Array(top)
	polygon.append(Vector2(r.end.x - r.size.x * 0.03, r.end.y))
	polygon.append(Vector2(r.position.x + r.size.x * 0.03, r.end.y))
	draw_colored_polygon(polygon, Color("3b2718"))
	draw_polyline(top, Color("7a4a2a"), maxf(letter_size / 40.0, 2.0))


## Tre ciuffi d'erba che crescono con il progresso.
func _draw_grass() -> void:
	if _grass_progress <= 0.0:
		return
	var r := _ground_rect
	for k in 3:
		var base := Vector2(r.position.x + r.size.x * (0.18 + 0.32 * k), r.position.y + r.size.y * 0.05)
		var h := letter_size * 0.3 * _grass_progress
		for blade in 3:
			var dx := (blade - 1) * letter_size * 0.06
			var tip := base + Vector2(dx * 1.6, -h * (1.0 - 0.2 * absf(blade - 1)))
			draw_colored_polygon(PackedVector2Array([base + Vector2(dx - 3, 0), tip, base + Vector2(dx + 3, 0)]), Color("7fc24f"))


## Chiodo piantato di sbieco nella prima "O": entra con il progresso, poi la crepa.
func _draw_nail() -> void:
	if _nail_progress <= 0.0:
		return
	var enter := clampf(_nail_progress / 0.6, 0.0, 1.0)
	var length := letter_size * 0.9
	var direction := Vector2(-0.55, 1.0).normalized()
	var head := _nail_anchor - direction * length * (1.0 + (1.0 - enter) * 0.8)
	var tip := _nail_anchor + direction * length * 0.25 * enter
	var width := maxf(letter_size * 0.08, 3.0)
	draw_line(head, tip, UiPalette.OUTLINE, width + 3.0)
	draw_line(head, tip, Color("c9ccd1"), width)
	draw_circle(head, width * 1.4, UiPalette.OUTLINE)
	draw_circle(head, width * 1.1, Color("e8e9ec"))
	if _nail_progress > 0.6:
		var crack := clampf((_nail_progress - 0.6) / 0.4, 0.0, 1.0)
		var points := PackedVector2Array([_nail_anchor])
		var offsets := [Vector2(0.25, 0.3), Vector2(0.45, 0.62), Vector2(0.4, 0.95), Vector2(0.62, 1.2)]
		var shown := int(ceil(crack * offsets.size()))
		for i in shown:
			points.append(_nail_anchor + (offsets[i] as Vector2) * letter_size * 0.35)
		if points.size() > 1:
			draw_polyline(points, UiPalette.OUTLINE, maxf(letter_size / 32.0, 2.0))
```

Scena `game_logo.tscn`: un nodo radice `GameLogo` (Control) con lo script; nessun figlio (li crea `_ready`).

- [ ] **Step 4: Test verde, poi guardare il logo**

Run: `godot_console --headless --path godot --fixed-fps 60 --script res://tests/ui_theme_tests.gd` → `PASS`.

`godot/tests/tools/capture_logo.gd`:

```gdscript
extends SceneTree
## Esporta il logo (D-079) in PNG: `logo_wide` (2048 di larghezza, trasparente),
## `logo_stacked` (1024x1024, trasparente), `icon` (256x256 su fondo terracotta).
## Uso: godot_console --path godot --resolution 1280x800 --quit-after 900 --script res://tests/tools/capture_logo.gd -- --out=../output/identity

var _out := "../output/identity"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	await process_frame
	await _render("logo_wide", "wide", 150, Vector2i(2048, 640), Color(0, 0, 0, 0), true)
	await _render("logo_stacked", "stacked", 150, Vector2i(1024, 1024), Color(0, 0, 0, 0), true)
	await _render("icon", "stacked", 44, Vector2i(256, 256), Color("b5652d"), false)
	quit()


func _render(name: String, layout: String, letter_size: int, size: Vector2i, background: Color, subtitle: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = background.a == 0.0
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	if background.a > 0.0:
		var fill := ColorRect.new()
		fill.color = background
		fill.size = size
		viewport.add_child(fill)
	var logo := GameLogo.new()
	logo.layout = layout
	logo.letter_size = letter_size
	logo.show_subtitle = subtitle
	viewport.add_child(logo)
	await process_frame
	logo.position = (Vector2(size) - logo.custom_minimum_size) * 0.5
	logo.set_all(1.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("%s.png" % name)
	var error := viewport.get_texture().get_image().save_png(path)
	print("CAPTURE %s err=%d" % [path, error])
	viewport.queue_free()
```

Run: `godot_console --path godot --resolution 1280x800 --quit-after 900 --script res://tests/tools/capture_logo.gd -- --out=../output/identity`
Guardare i tre PNG (Read): lettere rame/ocra con outline scuro, arco, chiodo nella "O", crepa, zolla con erba, targa inclinata. Correggere proporzioni e colori finché il logo è leggibile anche a 256 px; copiare `icon.png` in `godot/icon.png`.

- [ ] **Step 5: Icona del progetto e commit**

In `project.godot`, `[application]`: `config/icon="res://icon.png"`. Poi `godot_console --headless --path godot --editor --quit` per importarla.

```bash
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
git add godot/scripts/ui/game_logo.gd godot/scenes/ui/game_logo.tscn godot/resources/materials/logo_letters.gdshader godot/tests/tools/capture_logo.gd godot/tests/ui_theme_tests.gd godot/icon.png godot/icon.png.import godot/project.godot output/identity/logo_wide.png output/identity/logo_stacked.png output/identity/icon.png
git commit -m "Logo vettoriale Dwarmageddon: Dig or Die con chiodo, crepa, zolla e targa; esportazione PNG e icona del progetto (D-079)"
```

---

### Task 3: Menu iniziale

**Files:**
- Modify: `godot/scripts/ui/main_menu.gd:118-164`
- Create: `godot/resources/materials/menu_sky.gdshader`
- Test: `godot/tests/menu_tests.gd` (resta verde), `godot/tests/ui_theme_tests.gd`

**Interfaces:**
- Consumes: `UiPalette`, `GameLogo`.
- Produces: `MainMenu` con nodi `Background` (ColorRect con `ShaderMaterial` del cielo), `Dust` (CPUParticles2D), `Logo` (GameLogo), `_column` (VBoxContainer, ancorato a sinistra), `_scrap_label` (Label `ScrapLabel`, testo invariato), `Version` (Label `MutedLabel`, in basso a destra).

- [ ] **Step 1: Shader del cielo in 2D**

`godot/resources/materials/menu_sky.gdshader` (stessi colori di `sky_painted.gdshader` al tramonto):

```glsl
shader_type canvas_item;
uniform vec3 top_color : source_color = vec3(0.16, 0.14, 0.30);
uniform vec3 horizon_color : source_color = vec3(0.96, 0.60, 0.36);
uniform vec3 ground_color : source_color = vec3(0.09, 0.07, 0.05);
uniform vec3 sun_color : source_color = vec3(1.0, 0.78, 0.45);
uniform vec2 sun_position = vec2(0.72, 0.58);
uniform float drift = 0.004;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float bands = noise(vec2(uv.x * 6.0 + TIME * drift, uv.y * 14.0)) * 0.08;
	float horizon = 0.62;
	vec3 sky = mix(top_color, horizon_color, smoothstep(0.0, horizon, uv.y + bands));
	float sun = exp(-length((uv - sun_position) * vec2(1.6, 1.0)) * 6.0);
	sky += sun_color * sun * 0.9;
	float ground = smoothstep(horizon + 0.02, horizon + 0.08, uv.y);
	vec3 color = mix(sky, ground_color, ground);
	float vignette = smoothstep(1.2, 0.35, length((uv - 0.5) * vec2(1.3, 1.0)));
	COLOR = vec4(color * mix(0.55, 1.0, vignette), 1.0);
}
```

- [ ] **Step 2: Riscrivere `_build()` del menu**

Sostituire `_build()` e `_button()` in `main_menu.gd`:

```gdscript
func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.name = "Background"
	background.color = UiPalette.BG
	background.material = ShaderMaterial.new()
	(background.material as ShaderMaterial).shader = load("res://resources/materials/menu_sky.gdshader")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var dust := CPUParticles2D.new()
	dust.name = "Dust"
	dust.amount = 40
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(700, 60)
	dust.position = Vector2(640, 860)
	dust.direction = Vector2(0, -1)
	dust.spread = 25.0
	dust.initial_velocity_min = 25.0
	dust.initial_velocity_max = 60.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	dust.color = Color(1.0, 0.72, 0.4, 0.55)
	add_child(dust)
	var logo := GameLogo.new()
	logo.name = "Logo"
	logo.letter_size = 44
	logo.position = Vector2(72, 72)
	add_child(logo)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.custom_minimum_size = Vector2(360, 0)
	_column.position = Vector2(80, 330)
	_column.add_theme_constant_override(&"separation", 14)
	add_child(_column)
	_play = _button("Gioca", start_run)
	_workshop_button = _button("Officina", open_workshop)
	_settings = _button("Impostazioni", open_settings)
	_quit = _button("Esci", func() -> void: get_tree().quit())
	var plate := PanelContainer.new()
	plate.name = "ProfilePlate"
	plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 40)
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(plate)
	_scrap_label = Label.new()
	_scrap_label.theme_type_variation = &"ScrapLabel"
	plate.add_child(_scrap_label)
	var version := Label.new()
	version.name = "Version"
	version.theme_type_variation = &"MutedLabel"
	version.text = "v%s  Godot %s" % [ProjectSettings.get_setting("application/config/version", "0"), Engine.get_version_info().string]
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(version)
	_prompts = ButtonPrompts.create([[&"ui_accept", "Conferma"]])
	add_child(_prompts)
	_prompts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 28)
	_prompts.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"MenuButton"
	button.custom_minimum_size = Vector2(0, 56)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	_column.add_child(button)
	return button
```

Togliere la costante `SCRAP_COLOR` e il titolo/sottotitolo; `_refresh()` resta uguale (testo "Rottami in Officina: %d     Run giocate: %d     Livelli completati: %d"). `_set_menu_visible` nasconde anche `Logo`? No: il logo resta visibile sotto i pannelli (sono overlay a 0,96).

- [ ] **Step 3: Test e cattura**

Run: `godot_console --headless --path godot --fixed-fps 60 --script res://tests/menu_tests.gd` e `.../ui_theme_tests.gd` → entrambi `PASS`.
Cattura: `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_workshop.gd -- --out=../output/identity` e guardare `menu.png`: cielo al tramonto, logo in alto a sinistra, colonna sotto, targhetta in basso a sinistra, versione a destra. Aggiustare posizioni finché nulla si sovrappone a 1280x800.

- [ ] **Step 4: Gate e commit**

```bash
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
git add godot/scripts/ui/main_menu.gd godot/resources/materials/menu_sky.gdshader output/identity/menu.png
git commit -m "Menu iniziale con logo, cielo dipinto, polvere, colonna a sinistra e targhetta del profilo (D-080)"
```

---

### Task 4: Pausa e Impostazioni

**Files:**
- Modify: `godot/scenes/ui/pause_menu.tscn` (avvisare: scena toccata), `godot/scripts/ui/pause_menu.gd:30-36`, `godot/scripts/ui/settings_menu.gd` (nessuna logica)
- Test: `godot/tests/settings_tests.gd`, `godot/tests/menu_tests.gd` (restano verdi)

- [ ] **Step 1: Pulire la scena**

In `pause_menu.tscn`:
- `Overlay`: `color = Color(0.09, 0.067, 0.051, 0.88)` (`UiPalette.BG` a 0,88).
- Togliere ogni `theme_override_font_sizes/font_size` dai Button, Label, OptionButton, CheckButton (59 righe `theme_override`: restano solo `theme_override_constants/margin_*` e `separation`).
- `Title` della pausa e delle Impostazioni: `theme_type_variation = &"TitleLabel"`.
- `GraphicsHeader`, `AudioHeader`, `ControllerHeader`: `theme_type_variation = &"SectionLabel"`; sotto ciascuno aggiungere un `HSeparator` con `theme_override_styles/separator` = StyleBoxLine rame? Più semplice: un `ColorRect` alto 2 px, `color = Color("b5652d")`, `custom_minimum_size = Vector2(0, 2)`.
- Etichette delle righe (`Label` dentro ogni `*Row`): `theme_type_variation = &"MutedLabel"`? No: testo a 18 px `TEXT`; lasciare predefinito.
- Etichette dei valori (`%MasterVolumeValue`, `%SfxVolumeValue`): `theme_type_variation = &"MutedLabel"`.
- `ResumeButton`, `SettingsButton`, `QuitButton`, `BackButton`: `theme_type_variation = &"MenuButton"`.
- `SettingsPanel` `custom_minimum_size = Vector2(760, 0)`.

Comando per togliere le dimensioni in blocco (controllare il diff):

```bash
cd /c/Users/adgau/Desktop/Videogame/godot && sed -i '/^theme_override_font_sizes\/font_size = /d' scenes/ui/pause_menu.tscn
```

- [ ] **Step 2: "Torna al menu" come gli altri**

In `pause_menu.gd` `_ready`, dopo `_menu_button.text = ...`: `_menu_button.theme_type_variation = &"MenuButton"`.

- [ ] **Step 3: Test e cattura**

Run: `settings_tests.gd`, `menu_tests.gd`, `ui_theme_tests.gd` headless → `PASS`.
Cattura: `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 600 --script res://tests/tools/capture_settings.gd -- --out=../output/identity` e guardare `settings_top.png`, `settings_bottom.png`; il pannello deve stare nei 800 px (se lo scroll da 620 più margini e titolo sfora, ridurre `Scroll` a 560).

- [ ] **Step 4: Gate e commit**

```bash
git add godot/scenes/ui/pause_menu.tscn godot/scripts/ui/pause_menu.gd output/identity/settings_top.png output/identity/settings_bottom.png
git commit -m "Pausa e Impostazioni sul tema: varianti di tipo, intestazioni con riga rame, pulsanti uniformi (D-080)"
```

---

### Task 5: Level-up, Officina, mappa di campagna

**Files:**
- Modify: `godot/scripts/ui/level_up_menu.gd:19-40,105-123`, `godot/scripts/ui/workshop_panel.gd`, `godot/scripts/ui/campaign_map_panel.gd`
- Test: `godot/tests/workshop_tests.gd`, `godot/tests/campaign_tests.gd`, `godot/tests/upgrade_tests.gd` (se esiste: `ls godot/tests | grep -i upgrade`) restano verdi.

- [ ] **Step 1: Carte del level-up**

In `_ready`: `_overlay.color = Color(UiPalette.BG, 0.82)`; `_title.theme_type_variation = &"TitleLabel"`; sotto il titolo una `Label` `_subtitle` (`MutedLabel`, "scegli un pezzo"); `_title.text = "LIVELLO %d" % player_level` in `open` (il test di campagna legge `event_warning_text`, non questo titolo; `grep -rn "scegli un pezzo" godot/tests` deve essere vuoto, altrimenti conservare il testo).

Sostituire `_make_card` con una carta a contenitore:

```gdscript
func _make_card(upgrade: Dictionary, current_level: int) -> Button:
	var color: Color = UpgradeCatalog.RARITY_COLORS[upgrade.rarity].linear_to_srgb()
	var button := Button.new()
	button.theme_type_variation = &"CardButton"
	button.custom_minimum_size = Vector2(300, 300)
	button.focus_mode = Control.FOCUS_ALL
	button.text = ""
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var box := UiPalette.button_box(state, color)
		box.set_corner_radius_all(8)
		box.set_content_margin_all(0)
		if state == &"focus":
			box.border_color = color
			box.shadow_color = Color(UiPalette.FOCUS, 0.45)
			box.shadow_size = 10
		button.add_theme_stylebox_override(state, box)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 8)
	button.add_child(column)
	var rarity := Label.new()
	rarity.text = UpgradeCatalog.RARITY_NAMES[upgrade.rarity]
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.theme_type_variation = &"SectionLabel"
	rarity.add_theme_font_size_override(&"font_size", 16)
	rarity.add_theme_color_override(&"font_color", UiPalette.OUTLINE)
	var band := StyleBoxFlat.new()
	band.bg_color = color
	band.set_content_margin_all(6)
	band.corner_radius_top_left = 6
	band.corner_radius_top_right = 6
	rarity.add_theme_stylebox_override(&"normal", band)
	column.add_child(rarity)
	var body := MarginContainer.new()
	body.add_theme_constant_override(&"margin_left", 14)
	body.add_theme_constant_override(&"margin_right", 14)
	body.add_theme_constant_override(&"margin_bottom", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var text := VBoxContainer.new()
	text.add_theme_constant_override(&"separation", 6)
	body.add_child(text)
	var name_label := Label.new()
	name_label.text = upgrade.name
	name_label.theme_type_variation = &"SectionLabel"
	name_label.add_theme_color_override(&"font_color", UiPalette.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(name_label)
	var level_text := "NUOVO" if current_level == 0 else "Liv. %d > %d" % [current_level, current_level + 1]
	var kind := Label.new()
	kind.text = "%s  -  %s" % [UpgradeCatalog.CATEGORY_NAMES.get(upgrade.category, ""), level_text]
	kind.theme_type_variation = &"MutedLabel"
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_child(kind)
	var description := Label.new()
	description.text = UpgradeCatalog.describe(upgrade)
	description.add_theme_font_size_override(&"font_size", 17)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_child(description)
	for label: Label in [rarity, name_label, kind, description]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# La carta con il focus si alza: scala 1,04 attorno al centro, 120 ms.
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.focus_entered.connect(func() -> void: create_tween().tween_property(button, "scale", Vector2(1.04, 1.04), 0.12))
	button.focus_exited.connect(func() -> void: create_tween().tween_property(button, "scale", Vector2.ONE, 0.12))
	var id: StringName = upgrade.id
	button.pressed.connect(func() -> void: _on_pressed(id))
	_cards.add_child(button)
	return button
```

Entrata sfalsata in `open`, dopo aver creato le carte:

```gdscript
	for i in _buttons.size():
		_buttons[i].modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.06 * i)
		tween.tween_property(_buttons[i], "modulate:a", 1.0, 0.18)
```

Se un test legge `button.text` delle carte (`grep -n "card\|_buttons\[" godot/tests/*.gd`), aggiungere a `LevelUpMenu` un metodo `card_text(index) -> String` che concatena i testi delle Label e adattare il test.

- [ ] **Step 2: Officina**

In `workshop_panel.gd`: overlay `Color(UiPalette.BG, 0.94)`; titolo `TitleLabel`; `_scrap_label.theme_type_variation = &"ScrapLabel"` con testo invariato; righe `theme_type_variation = &"CardButton"`, altezza 58, allineamento a sinistra; in `_refresh` i colori: `UiPalette.SUCCESS` per "AL MASSIMO", `UiPalette.TEXT` se acquistabile, `UiPalette.DANGER` per il costo mancante; togliere `OWNED_COLOR`, `UNAFFORDABLE_COLOR`, `SCRAP_COLOR` (controllare con `grep -rn "OWNED_COLOR\|UNAFFORDABLE_COLOR" godot` che nessun test li legga). `_back.theme_type_variation = &"MenuButton"`.

- [ ] **Step 3: Mappa di campagna**

In `campaign_map_panel.gd`: overlay `Color(UiPalette.BG, 0.94)`; titolo `TitleLabel`; pulsanti dei livelli `CardButton` con `custom_minimum_size = Vector2(220, 140)`; colori `DONE_COLOR → UiPalette.SUCCESS`, `OPEN_COLOR → UiPalette.BORDER_LIGHT`, `LOCKED_COLOR → Color(UiPalette.TEXT_MUTED, 0.5)` (le costanti restano con i nomi, cambiano i valori); fra una carta e l'altra un `ColorRect` 40x3 rame (`UiPalette.BORDER`) centrato verticalmente, aggiunto nell'HBox; `_detail.theme_type_variation = &"MutedLabel"` con `font_size` 18; `_back` `MenuButton`.

- [ ] **Step 4: Test, catture, gate, commit**

Run headless: `workshop_tests`, `campaign_tests`, `menu_tests`, `ui_theme_tests`, e la suite che copre il level-up (`grep -ln "LevelUpMenu\|level_up" godot/tests/*.gd`).
Catture: `capture_run.gd` (`level_up.png`), `capture_workshop.gd` (`workshop.png`), `capture_campaign.gd` (`map_new`, `map_unlocked`, `victory_next`) con `--out=../output/identity`. Guardarle.

```bash
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
git add godot/scripts/ui/level_up_menu.gd godot/scripts/ui/workshop_panel.gd godot/scripts/ui/campaign_map_panel.gd output/identity/level_up.png output/identity/workshop.png output/identity/map_new.png output/identity/map_unlocked.png
git commit -m "Level-up a carte con fascia di rarita, Officina e mappa di campagna sul tema (D-080)"
```

---

### Task 6: Fine livello

**Files:**
- Modify: `godot/scripts/ui/game_over_panel.gd:37-70,80-120,144-160`
- Test: `godot/tests/workshop_tests.gd:192` resta verde.

- [ ] **Step 1: Layout**

- `_overlay.color` in `open`: `Color("2a0f0c", 0.9)` sconfitta, `Color("0f2416", 0.9)` vittoria.
- La colonna sinistra dentro un `PanelContainer` (tema), larghezza 460.
- `_title.theme_type_variation = &"TitleLabel"`; in `open`: `_title.add_theme_color_override(&"font_color", UiPalette.SUCCESS if victory else UiPalette.DANGER)`.
- `_summary` resta una Label con lo stesso testo (il test legge "Rottami in Officina N"), ma allineata a sinistra, `font_size` 20, dentro un `PanelContainer` con `panel_box(true)`; le righe "Etichetta valore" si allineano aggiungendo tab: `"Tempo\t%s\nLivello\t%d\n..."` e `_summary.tab_stops = PackedFloat32Array([260.0])`.
- Pulsanti `MenuButton`.
- `_map_box`: la mappa in un `PanelContainer`; `_map_caption` `MutedLabel` (14 px, non 13).

- [ ] **Step 2: Test, cattura, commit**

Run: `workshop_tests.gd` → `PASS`. Cattura `capture_workshop.gd` → `game_over.png`, `capture_campaign.gd` → `victory_next.png`, in `output/identity`. Guardarle.

```bash
git add godot/scripts/ui/game_over_panel.gd output/identity/game_over.png output/identity/victory_next.png
git commit -m "Schermata di fine livello sul tema: pannello, tabella allineata, titolo colorato (D-080)"
```

---

### Task 7: HUD

**Files:**
- Create: `godot/scripts/ui/health_bolts.gd`, `godot/scripts/ui/day_dial.gd`
- Modify: `godot/scripts/ui/run_hud.gd`
- Test: `godot/tests/ui_theme_tests.gd` (nuova `_test_hud`), `day_night_tests.gd`, `lamp_tests.gd`, `boss_tests.gd`, `button_prompts_tests.gd` restano verdi.

**Interfaces:**
- Produces: `class_name HealthBolts extends Control` con `set_health(health: int, max_health: int)`, `bolt_count() -> int`, `lit_count() -> int`; `class_name DayDial extends Control` con `set_phase(phase: int, fraction: float)` (0..1 di giorno trascorso) e `phase() -> int`.
- `RunHud`: costanti con gli stessi nomi (`HEALTH_ON = UiPalette.DANGER`, `XP_COLOR = UiPalette.XP`, `TITLE_COLOR = UiPalette.TEXT`, `EXTRACTION_COLOR`, `QUAKE_COLOR`, `TRAIN_COLOR`, `BOSS_COLOR`, `DAY_COLOR`, `NIGHT_COLOR` invariate), `_health_row` diventa un `HealthBolts` (nome del campo invariato), `_day_label` resta una Label accanto al nuovo `DayDial` (il test del ciclo legge testo e visibilità della Label).

- [ ] **Step 1: Test**

In `ui_theme_tests.gd`:

```gdscript
func _test_hud() -> void:
	var hud := RunHud.new()
	root.add_child(hud)
	await _frames(2)
	hud.set_health(3, 5)
	_check(hud._health_row.bolt_count() == 5 and hud._health_row.lit_count() == 3, "cinque bulloni, tre accesi")
	hud.set_health(2, 7)
	_check(hud._health_row.bolt_count() == 7 and hud._health_row.get_child_count() == 0, "al cambio di massimo si ridisegna senza figli")
	hud.set_day_phase(0, 125.0)
	_check(hud._day_label.visible and hud._day_label.text.contains("02:05"), "testo del giorno conservato: %s" % hud._day_label.text)
	_check(hud._level_label.get_theme_font(&"font") == UiPalette.title_font(), "numeri dell'HUD in slab")
	hud.queue_free()
	await _frames(1)
```

Run → fallisce (`bolt_count` inesistente).

- [ ] **Step 2: `health_bolts.gd`**

```gdscript
class_name HealthBolts
extends Control
## Vita come bulloni esagonali (D-080): pieni `DANGER`, vuoti scuri. Si ridisegna
## solo quando cambiano i valori; nessun nodo figlio.

const SIZE := 22.0
const GAP := 6.0

var _health := 0
var _max := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_health(health: int, max_health: int) -> void:
	if health == _health and max_health == _max:
		return
	_health = health
	_max = max_health
	custom_minimum_size = Vector2((SIZE + GAP) * max_health, SIZE)
	queue_redraw()


func bolt_count() -> int:
	return _max


func lit_count() -> int:
	return clampi(_health, 0, _max)


func _draw() -> void:
	for i in _max:
		var center := Vector2(i * (SIZE + GAP) + SIZE * 0.5, SIZE * 0.5)
		var points := PackedVector2Array()
		for k in 6:
			var angle := PI / 6.0 + k * PI / 3.0
			points.append(center + Vector2(cos(angle), sin(angle)) * SIZE * 0.5)
		var lit := i < _health
		draw_colored_polygon(points, UiPalette.DANGER if lit else Color(0.12, 0.08, 0.07, 0.85))
		points.append(points[0])
		draw_polyline(points, UiPalette.OUTLINE, 2.0)
		draw_circle(center, SIZE * 0.16, UiPalette.OUTLINE if lit else Color(0.25, 0.18, 0.15))
```

- [ ] **Step 3: `day_dial.gd`**

```gdscript
class_name DayDial
extends Control
## Quadrante giorno/notte (D-080): un semicerchio con il sole che scende verso
## l'orizzonte di giorno e la luna di notte. Accompagna il testo dell'HUD.

const RADIUS := 16.0

var _phase := 0
var _fraction := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(RADIUS * 2.0 + 4.0, RADIUS + 6.0)


func set_phase(phase: int, fraction: float) -> void:
	if phase == _phase and is_equal_approx(fraction, _fraction):
		return
	_phase = phase
	_fraction = clampf(fraction, 0.0, 1.0)
	queue_redraw()


func phase() -> int:
	return _phase


func _draw() -> void:
	var center := Vector2(RADIUS + 2.0, RADIUS + 2.0)
	draw_arc(center, RADIUS, PI, TAU, 24, UiPalette.OUTLINE, 4.0)
	draw_arc(center, RADIUS, PI, TAU, 24, UiPalette.TEXT_MUTED, 2.0)
	var night := _phase >= 2
	var angle := PI + PI * (0.15 + 0.7 * _fraction)
	var body := center + Vector2(cos(angle), sin(angle)) * RADIUS
	draw_circle(body, 6.0, UiPalette.OUTLINE)
	draw_circle(body, 4.5, Color("9aa3ff") if night else Color("ffd45a"))
	if night:
		draw_circle(body + Vector2(2.0, -1.0), 3.5, UiPalette.OUTLINE)
```

- [ ] **Step 4: Modificare `run_hud.gd`**

- Costanti: `HEALTH_ON := UiPalette.DANGER`, `HEALTH_OFF` invariato, `XP_COLOR := UiPalette.XP`, `TITLE_COLOR := UiPalette.TEXT`; `BOSS_COLOR`, `DAY_COLOR`, `NIGHT_COLOR`, `TRAIN_COLOR`, `QUAKE_COLOR`, `EXTRACTION_COLOR` invariate (gli script del livello le leggono).
- `_label()`: `label.theme_type_variation = &"HudLabel"` e nessun override di font/colore/outline; `_level_label.add_theme_font_size_override(&"font_size", 22)`, `_time_label` 28, `_kills_label` 22.
- XP bar: ancorata in basso (`PRESET_BOTTOM_WIDE`, `offset_top = -8`), fill `XP_COLOR`; due `ColorRect` 6x14 rame alle estremità ("terminali").
- `_health_row: HealthBolts` creato in `_ready` a `offset_left 24, offset_top 56`; `set_health` diventa `_health_row.set_health(health, max_health)`.
- `_day_dial := DayDial.new()` nella riga superiore prima di `_day_label`; in `set_day_phase`: `_day_dial.set_phase(phase, 1.0 - clampf(seconds_to_dusk / maxf(_dusk_total, 1.0), 0.0, 1.0))` con `_dusk_total` = primo valore ricevuto; `_day_dial.visible = _day_label.visible`.
- Avvisi: `_boss_warning` dentro un `PanelContainer` `_warning_plate` con stylebox `panel_box(true)` ruotato di -1,5°, centrato in alto (`offset_top = 96`), `_boss_warning.theme_type_variation = &"HudLabel"`, `font_size` 28; mostrare/nascondere la targa insieme alla label (`show_notice`, `set_event_warning`, `clear_event_warning`, `_process`).
- Boss box: `_boss_name_label` `HudLabel` 20; `_boss_bar` 520x14 con fill `BOSS_COLOR`; `offset_top = -96` (sopra la barra esperienza).
- `_tool_label` `HudLabel` 18.
- `_controls` invariato; i label di `ButtonPrompts` ereditano il font del tema (nessuna modifica in `button_prompts.gd`).

- [ ] **Step 5: Test, catture, gate, commit**

Run headless: `ui_theme_tests`, `day_night_tests`, `lamp_tests`, `boss_tests`, `button_prompts_tests`, `campaign_tests`, `quake_tests`, `train_tests`, `extraction_tests` → tutti `PASS`.
Catture: `capture_run.gd` (`combat.png`), `capture_boss.gd` e `capture_day_night` (vedere `docs/GODOT_WORKFLOW.md` righe 169-173 per i comandi) in `output/identity` → `hud_day`, `hud_night`, `hud_boss` (rinominare i file prodotti). Guardarle.

```bash
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
git add godot/scripts/ui/health_bolts.gd godot/scripts/ui/day_dial.gd godot/scripts/ui/run_hud.gd godot/tests/ui_theme_tests.gd output/identity/combat.png output/identity/hud_*.png
git commit -m "HUD sul tema: bulloni di vita, quadrante giorno/notte, numeri in slab, barra esperienza in basso, avvisi su targa (D-080)"
```

---

### Task 8: Intro all'avvio e nome del gioco

**Files:**
- Create: `godot/scripts/ui/boot_intro.gd`, `godot/scenes/main/boot_intro.tscn`
- Modify: `godot/project.godot` (`run/main_scene`, `config/name`, `boot_splash`), `godot/scripts/core/run_launch_options.gd` (flag `--intro-test`), `README.md` (nome)
- Test: `godot/tests/intro_tests.gd`

**Interfaces:**
- Produces: `class_name BootIntro extends Control`; `signal finished`; `@export var vignette: PackedScene` (aggancio: la scena istanziata deve emettere `finished`); `const MENU_SCENE := "res://scenes/main/main_menu.tscn"`; `static func should_skip(args: PackedStringArray, headless: bool) -> bool`; `func skip()`; `var is_playing: bool`.
- `RunLaunchOptions.wants_intro_test(args) -> bool` per `--intro-test`.

- [ ] **Step 1: Test**

`godot/tests/intro_tests.gd`:

```gdscript
extends SceneTree
## Test dell'intro all'avvio (D-080). Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/intro_tests.gd

const IntroScene := preload("res://scenes/main/boot_intro.tscn")

var _failures := 0


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	await _frames(1)
	_test_skip_rules()
	await _test_sequence_completes()
	await _test_skip_on_input()
	await _frames(2)
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _test_skip_rules() -> void:
	_check(BootIntro.should_skip(PackedStringArray(["--autostart"]), false), "--autostart salta l'intro")
	_check(BootIntro.should_skip(PackedStringArray(["--level=railway"]), false), "--level= salta l'intro")
	_check(BootIntro.should_skip(PackedStringArray([]), true), "headless salta l'intro")
	_check(not BootIntro.should_skip(PackedStringArray([]), false), "avvio normale: intro")
	_check(not BootIntro.should_skip(PackedStringArray(["--intro-test"]), true), "--intro-test la forza anche in headless")


## Con --intro-test la sequenza gira in headless e finisce da sola entro 5 s.
func _test_sequence_completes() -> void:
	var intro := IntroScene.instantiate() as BootIntro
	intro.force_play = true
	intro.change_scene_on_finish = false
	root.add_child(intro)
	await _frames(2)
	var pause := root.get_node("PauseMenu")
	_check(intro.is_playing and pause.get(&"enabled") == false, "intro in corso, pausa disattivata")
	var done := [false]
	intro.finished.connect(func() -> void: done[0] = true)
	await _frames(60 * 5)
	_check(done[0] and not intro.is_playing, "finita entro 5 s")
	_check(pause.get(&"enabled") == true, "pausa riattivata alla fine")
	_check(intro.logo().is_complete(), "logo completo alla fine")
	intro.queue_free()
	await _frames(1)


## Un tasto a meta la chiude prima; un secondo tasto non la chiude due volte.
func _test_skip_on_input() -> void:
	var intro := IntroScene.instantiate() as BootIntro
	intro.force_play = true
	intro.change_scene_on_finish = false
	root.add_child(intro)
	await _frames(30)
	var count := [0]
	intro.finished.connect(func() -> void: count[0] += 1)
	intro.skip()
	intro.skip()
	await _frames(60)
	_check(count[0] == 1 and not intro.is_playing, "salto: una sola fine (%d)" % count[0])
	intro.queue_free()
	await _frames(1)
```

Run → fallisce (`BootIntro` non dichiarato).

- [ ] **Step 2: `run_launch_options.gd`**

Aggiungere:

```gdscript
## `--intro-test`: l'intro gira anche in headless (suite intro_tests).
static func wants_intro_test(args: PackedStringArray = OS.get_cmdline_user_args()) -> bool:
	return args.has("--intro-test")
```

- [ ] **Step 3: `boot_intro.gd`**

```gdscript
class_name BootIntro
extends Control
## Intro all'avvio (D-080): rivelazione del logo in 4 s, saltabile con qualunque
## tasto; poi il menu iniziale. Salta da sola quando la riga di comando chiede un
## livello (`RunLaunchOptions.AUTOSTART_PREFIXES`) o in headless, cosi gate, smoke
## test e catture non la vedono. Aggancio per la vignetta futura: `vignette`, una
## PackedScene che emette `finished`; se impostata, gira prima del logo.

signal finished

const MENU_SCENE := "res://scenes/main/main_menu.tscn"
const TOTAL_SECONDS := 4.0

@export var vignette: PackedScene
## Test: gira anche in headless e non cambia scena alla fine.
var force_play := false
var change_scene_on_finish := true
var is_playing := false

var _logo: GameLogo
var _ground: ColorRect
var _dust: CPUParticles2D
var _tween: Tween
var _audio: AudioStreamPlayer
var _pause_menu: Node
var _ending := false


static func should_skip(args: PackedStringArray, headless: bool) -> bool:
	if RunLaunchOptions.wants_intro_test(args):
		return false
	return headless or RunLaunchOptions.wants_autostart(args)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_menu = get_node_or_null(^"/root/PauseMenu")
	var headless := DisplayServer.get_name() == "headless"
	if not force_play and should_skip(OS.get_cmdline_user_args(), headless):
		_go_to_menu()
		return
	if _pause_menu != null:
		_pause_menu.set(&"enabled", false)
	SfxLibrary.precache_async()
	_build()
	is_playing = true
	if vignette != null:
		var scene := vignette.instantiate()
		add_child(scene)
		await scene.finished
		scene.queue_free()
	_play_logo()


func logo() -> GameLogo:
	return _logo


## Qualunque tasto, pulsante o click salta alla fine.
func _unhandled_input(event: InputEvent) -> void:
	if not is_playing or _ending:
		return
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		skip()


func skip() -> void:
	if not is_playing or _ending:
		return
	if _tween != null:
		_tween.kill()
	_logo.set_all(1.0)
	_finish()


func _build() -> void:
	var background := ColorRect.new()
	background.color = UiPalette.BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_ground = ColorRect.new()
	_ground.color = Color("2a1a10")
	_ground.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_ground.offset_top = 0
	add_child(_ground)
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.amount = 80
	_dust.one_shot = true
	_dust.explosiveness = 0.9
	_dust.lifetime = 1.6
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(420, 10)
	_dust.direction = Vector2(0, -1)
	_dust.spread = 40.0
	_dust.gravity = Vector2(0, 120)
	_dust.initial_velocity_min = 120.0
	_dust.initial_velocity_max = 260.0
	_dust.scale_amount_min = 2.0
	_dust.scale_amount_max = 5.0
	_dust.color = Color(0.85, 0.6, 0.35, 0.7)
	add_child(_dust)
	_logo = GameLogo.new()
	_logo.letter_size = 96
	add_child(_logo)
	_logo.set_all(0.0)
	_audio = AudioStreamPlayer.new()
	_audio.bus = &"SFX"
	add_child(_audio)


func _play_logo() -> void:
	var viewport_size := get_viewport_rect().size
	_logo.position = (viewport_size - _logo.custom_minimum_size) * 0.5 - Vector2(0, 30)
	_dust.position = Vector2(viewport_size.x * 0.5, _logo.position.y + _logo.custom_minimum_size.y)
	_ground.offset_top = 0
	_tween = create_tween()
	_tween.set_parallel(false)
	_tween.tween_callback(_sound.bind(&"quake_rumble", -8.0))
	_tween.tween_property(_ground, "offset_top", -viewport_size.y * 0.3, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_callback(func() -> void: _dust.emitting = true).set_delay(0.3)
	_tween.tween_method(_logo.set_letter_progress, 0.0, 1.0, 1.2)
	_tween.parallel().tween_callback(_sound.bind(&"terrain_raise", -4.0)).set_delay(0.5)
	_tween.tween_callback(_sound.bind(&"nail_shot", 0.0))
	_tween.tween_method(_logo.set_nail_progress, 0.0, 1.0, 0.35)
	_tween.parallel().tween_method(_shake, 1.0, 0.0, 0.35)
	_tween.tween_callback(_sound.bind(&"scrap_pickup", -2.0))
	_tween.tween_method(_logo.set_subtitle_progress, 0.0, 1.0, 0.25)
	_tween.tween_method(_logo.set_grass_progress, 0.0, 1.0, 0.8)
	_tween.tween_interval(0.4)
	_tween.tween_callback(_finish)


func _shake(strength: float) -> void:
	_logo.position += Vector2(randf_range(-6, 6), randf_range(-4, 4)) * strength
	if strength <= 0.0:
		_logo.position = (get_viewport_rect().size - _logo.custom_minimum_size) * 0.5 - Vector2(0, 30)


func _sound(id: StringName, volume_db: float) -> void:
	var stream := SfxLibrary.build(id)
	if stream == null:
		return
	_audio.stream = stream
	_audio.volume_db = volume_db
	_audio.play()


func _finish() -> void:
	if _ending:
		return
	_ending = true
	var fade := create_tween()
	fade.tween_property(self, "modulate", Color(UiPalette.BG, 1.0), 0.5)
	fade.tween_callback(func() -> void:
		is_playing = false
		if _pause_menu != null:
			_pause_menu.set(&"enabled", true)
		finished.emit()
		if change_scene_on_finish:
			_go_to_menu())


func _go_to_menu() -> void:
	if _pause_menu != null:
		_pause_menu.set(&"enabled", true)
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
```

Scena `boot_intro.tscn`: radice `BootIntro` (Control) con lo script, nessun figlio.

- [ ] **Step 4: `project.godot` e README**

```ini
[application]
config/name="Dwarmageddon"
config/description="Dwarmageddon: Dig or Die. Survivor-like 3D isometrico con trasformazione del terreno."
run/main_scene="res://scenes/main/boot_intro.tscn"
boot_splash/show_image=false
boot_splash/bg_color=Color(0.09, 0.067, 0.051, 1)
```

Il titolo della finestra: in `BootIntro._ready` e in `MainMenu._ready`, `DisplayServer.window_set_title("Dwarmageddon: Dig or Die")`.
`README.md`: prima riga con il nome del gioco e la nota che le cartelle di build restano `Prototype01`.

- [ ] **Step 5: Test, smoke, catture, gate, commit**

Run: `intro_tests.gd` → `PASS`; `menu_tests.gd`, `ui_theme_tests.gd` → `PASS`.
Smoke manuale: `godot_console --headless --path godot --fixed-fps 60 --quit-after 180 -- --autostart` deve stampare `PROTOTYPE01_MENU_READY` (l'intro è saltata).
Avvio con finestra: `godot_console --path godot --resolution 1280x800 --quit-after 400` e guardare che l'intro giri e arrivi al menu; catture dell'intro con `capture_ui.gd` (Task 9).

```bash
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
git add godot/scripts/ui/boot_intro.gd godot/scenes/main/boot_intro.tscn godot/scripts/core/run_launch_options.gd godot/project.godot godot/tests/intro_tests.gd README.md
git commit -m "Intro all'avvio con rivelazione del logo, saltabile, con aggancio per la vignetta; nome del gioco Dwarmageddon (D-079, D-080)"
```

---

### Task 9: Catture complete, documenti, build

**Files:**
- Create: `godot/tests/tools/capture_ui.gd`, `output/identity/*.png`
- Modify: `docs/DECISIONS.md`, `docs/ART_DIRECTION.md`, `docs/TOOLS_AND_LICENSES.md`, `docs/GODOT_WORKFLOW.md`, `docs/INDEX.md`, `docs/PROJECT_ROADMAP.md`, `docs/MIGRATION_STATUS.md`

- [ ] **Step 1: `capture_ui.gd`**

```gdscript
extends SceneTree
## Catture dell'identita e dell'interfaccia (D-079, D-080) a 1280x800: intro a tre
## tempi, menu, pausa. Le altre schermate le fanno gli script di cattura esistenti.
## Uso: godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 1200 --script res://tests/tools/capture_ui.gd -- --out=../output/identity

const IntroScene := preload("res://scenes/main/boot_intro.tscn")
const MenuScene := preload("res://scenes/main/main_menu.tscn")
const RunScene := preload("res://scenes/main/arena_run.tscn")

var _out := "../output/identity"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	await process_frame
	var intro := IntroScene.instantiate() as BootIntro
	intro.force_play = true
	intro.change_scene_on_finish = false
	root.add_child(intro)
	await _seconds(0.8)
	await _save("intro_0_8s")
	await _seconds(1.2)
	await _save("intro_2_0s")
	await _seconds(1.0)
	await _save("intro_3_0s")
	intro.queue_free()
	await process_frame
	var menu := MenuScene.instantiate()
	root.add_child(menu)
	await _seconds(0.5)
	await _save("menu")
	menu.queue_free()
	await process_frame
	var run := RunScene.instantiate()
	root.add_child(run)
	run.get_node(^"EnemyDirector").spawning = false
	await _seconds(0.3)
	root.get_node("PauseMenu").pause_game()
	await _seconds(0.2)
	await _save("pause")
	quit()


func _seconds(s: float) -> void:
	for i in int(s * 60):
		await physics_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("%s.png" % name)
	var error := root.get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE %s err=%d" % [path, error])
```

Eseguire e guardare tutte le catture in `output/identity/` (intro x3, menu, pause, settings x2, level_up, workshop, game_over, victory_next, map_new, map_unlocked, combat, hud_day, hud_night, hud_boss). Correggere quello che stona e rifare le catture.

- [ ] **Step 2: Misura del menu**

`godot_console --path godot --resolution 1280x800 --quit-after 600` dal menu con il Debug Menu (F3) oppure leggendo `Performance.get_monitor(Performance.TIME_PROCESS)` in `capture_ui.gd` (stampare `MENU_FRAME_MS`): sotto 2 ms su PC al preset Alto. Annotare il valore in `MIGRATION_STATUS.md`.

- [ ] **Step 3: Documenti**

- `docs/DECISIONS.md`: righe D-079 (nome "Dwarmageddon: Dig or Die", roster di nani, logo vettoriale dalla pipeline nostra, font OFL) e D-080 (tema UI con token e varianti, HUD, intro saltabile con aggancio per la vignetta); nella sezione delle questioni aperte: cartelle di build ancora `Prototype01`, vignetta dopo il piano 2.
- `docs/ART_DIRECTION.md`: sezione "Identità (D-079)": nome, i personaggi sono nani (il divieto resta sull'archetipo steampunk), logo (forma, decorazioni, impaginazioni), palette dell'interfaccia (tabella dei token), font.
- `docs/TOOLS_AND_LICENSES.md`: sezione "Font" con Alfa Slab One e Rubik, OFL 1.1, origine `github.com/google/fonts`, percorso, data.
- `docs/GODOT_WORKFLOW.md`: comandi `capture_logo`, `capture_ui`, flag `--intro-test`, nota che `main_scene` è `boot_intro.tscn` e che `--autostart`/headless la saltano; trappole trovate (MSDF, `name_to_tag`).
- `docs/INDEX.md`: riga del piano; aggiornare la riga della spec se cambia stato.
- `docs/PROJECT_ROADMAP.md`, "Stato operativo": punto 0c "Identità e interfaccia (D-079, D-080) fatte l'11 ottobre 2026: giudizio del proprietario sulle catture `output/identity/` (prima in `output/identity/before/`)"; prossimo passo invariato (giudizio sull'ambiente, poi piano 2).
- `docs/MIGRATION_STATUS.md`: paragrafo "Ultimo aggiornamento" con il riassunto, i file nuovi, le trappole, la misura del menu, cosa resta (vignetta, build folder, Deck).

- [ ] **Step 4: Build Windows riesportata e smoke test**

Seguire `docs/GODOT_WORKFLOW.md`, sezione "Export" (comando verificato lì). Poi lo smoke test della build: eseguire l'eseguibile con `-- --autostart --quit-after 300` e controllare `PROTOTYPE01_MENU_READY` nel log; avviare una volta senza argomenti e vedere l'intro fino al menu.

- [ ] **Step 5: Gate finale e commit**

```bash
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1
git add godot/tests/tools/capture_ui.gd output/identity docs/DECISIONS.md docs/ART_DIRECTION.md docs/TOOLS_AND_LICENSES.md docs/GODOT_WORKFLOW.md docs/INDEX.md docs/PROJECT_ROADMAP.md docs/MIGRATION_STATUS.md
git commit -m "Identita e interfaccia chiuse: catture prima/dopo, D-079 e D-080, font registrati, roadmap e stato della migrazione"
```

---

## Self-review

- **Copertura della spec**: §2 identità (Task 8: nome, titolo finestra, icona in Task 2; `ART_DIRECTION` in Task 9); §3 logo (Task 2); §4.1 font (Task 1); §4.2 token (Task 1); §4.3 stili (Task 1; grana di carta disponibile da `paper_texture()`, applicata ai pannelli in Task 4/6 come `TextureRect` figlio se il tempo lo consente: **non bloccante**); §4.4 schermate (Task 3-7); §5 intro (Task 8); §6 Deck (catture a 1280x800 in ogni task); §7 verifica (suite in Task 1, 2, 7, 8; catture in Task 9; build in Task 9); §9 documenti (Task 9).
- **Deviazioni dichiarate rispetto alla spec**: il quadrante giorno/notte **affianca** il testo invece di sostituirlo (il test del ciclo legge il testo); la tabella di fine livello resta una Label con tab (il test legge `_summary.text`).
- **Coerenza dei nomi**: `UiPalette.button_box(state, border)`, `panel_box(raised)`, `title_font()`, `text_font(weight)`, `paper_texture()`; `GameLogo.set_*_progress`, `set_all`, `is_complete`, `letter_count`, `TITLE`, `NAIL_LETTER`; `BootIntro.should_skip(args, headless)`, `skip()`, `force_play`, `change_scene_on_finish`, `is_playing`, `logo()`, `finished`; `HealthBolts.set_health/bolt_count/lit_count`; `DayDial.set_phase/phase`; `RunLaunchOptions.wants_intro_test`.
- **Review Focus**: 1 e 3 → `intro_tests._test_sequence_completes` e `_test_skip_rules`; 2 → `_test_skip_on_input`; 4 → `ui_theme_tests._test_palette` (font nullo cade sul fallback senza errori: `push_warning`); 5 → `ui_theme_tests._test_hud`.
