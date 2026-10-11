# Interfaccia "fatta a mano", piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dare materia, ornamenti, icone, cursore, suoni, micro-animazioni e transizioni a tutta l'interfaccia, restando sulla pipeline nostra (texture generate da script, icone a poligoni).

**Architecture:** `build_ui_textures.gd` genera i PNG 9-slice in `assets/textures/ui/`; `UiPalette.build_theme()` li monta in `StyleBoxTexture`; `UiIcon` disegna i pittogrammi; l'autoload `UiFx` (CanvasLayer) gestisce cursore, suoni, pop-in e transizioni di scena per tutte le schermate; `MenuBackdrop` disegna lo sfondo a strati del menu; il logo prende bisello e ombra via shader.

**Tech Stack:** Godot 4.7.2 GDScript, `Image`/`FastNoiseLite`, `StyleBoxTexture`, `SfxLibrary` (sintesi), Git LFS per i PNG, gate `tools/godot/Invoke-GodotChecks.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-11-ui-handmade-polish-design.md`

## Global Constraints

- Nessun asset esterno, nessuna AI: PNG generati da `tests/tools/build_ui_textures.gd`, icone a poligoni.
- Dopo ogni modifica a `ui_palette.gd` rigenerare `resources/ui/theme.tres` (`build_theme.gd`); dopo ogni modifica al generatore rigenerare i PNG; `ui_theme_tests` controlla l'allineamento del `.tres`.
- Contratti dei test esistenti conservati (nomi dei nodi `%`, testi dei pulsanti, `_summary.text` con tab, `_day_label`, `_tool_label`, marcatori `PROTOTYPE01_*`).
- Testo mai sotto 14 px; focus sempre distinguibile; nessun percorso solo mouse.
- Catture mai in headless; `--out=` relativo; gate verde prima di ogni commit; `--check-only` sugli script toccati; commit in italiano chiusi da `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Con l'editor aperto: scene toccate `pause_menu.tscn` (solo stili), `main_menu.tscn` no.

## Review Focus

1. **Focus che cambia mentre il cursore è in tween** (D-pad tenuto premuto): il cursore deve seguire l'ultimo Control, senza code di tween. Test in Task 3.
2. **Button liberato mentre `UiFx` lo osserva** (carte del level-up ricreate a ogni apertura): nessun errore "previously freed". Test in Task 3.
3. **Fade di scena chiamato due volte** (doppio A su "Gioca"): una sola transizione. Test in Task 3.
4. **PNG mancanti o puntatori LFS** (checkout senza `git lfs checkout`): `build_theme()` non deve lanciare; ripiega su `StyleBoxFlat` e il test lo segnala. Test in Task 1.
5. **Deck 1280x800**: le texture 9-slice non si deformano sui pulsanti alti 56 e sulle righe alte 58 (margini 28 ≤ metà altezza). Verifica sulle catture in Task 8.

---

### Task 1: Texture generate e tema a texture

**Files:** Create `godot/tests/tools/build_ui_textures.gd`, `godot/assets/textures/ui/*.png`; Modify `godot/scripts/ui/ui_palette.gd`, `godot/resources/ui/theme.tres` (rigenerato); Test `godot/tests/ui_theme_tests.gd`.

**Interfaces:** `UiPalette.TEXTURE_DIR := "res://assets/textures/ui/"`; `static func plate(name: String, margin := 28, modulate := Color.WHITE) -> StyleBox` (StyleBoxTexture se il PNG si carica, altrimenti `panel_box()`/`button_box()` di riserva, con `push_warning`); `static func has_textures() -> bool`. Tema: `Button` e `OptionButton` e `CheckButton` su `plate_button*`; `PanelContainer` su `plate_panel`; `CardButton` su `plate_card`/`plate_card_focus`; `HSlider` slider su `gauge`, grabber_area su `gauge_fill`; `ProgressBar` background/fill su `gauge`/`gauge_fill`.

- [ ] Test (RED): `_test_textures()`: ogni nome della spec esiste come `.png` in `assets/textures/ui/` e si carica come `Texture2D` 96x96 (rule 256x12, gauge 64x24, strip 96x48); `theme.get_stylebox("normal","Button") is StyleBoxTexture` con `texture.resource_path` che finisce in `plate_button.png`; idem `focus` → `plate_button_focus.png`, `PanelContainer/panel` → `plate_panel.png`, `CardButton/normal` → `plate_card.png`; `UiPalette.has_textures()`.
- [ ] Generatore: funzioni `_noise(seed, freq)`, `_fill_grain(img, base, grain_amp)`, `_bevel(img, inset, light, shadow)`, `_frame(img, width, color, wear)`, `_rivet(img, pos, radius)`, `_burn_edges(img, depth)`, `_glow_rim(img, color, width)`; una funzione per file; `save_png`. Palette dai token (cuoio `#2a1f18`, rame `#b5652d`/`#e0a060`, pergamena `#e9d9b8`).
- [ ] Eseguire: `godot_console --headless --path godot --script res://tests/tools/build_ui_textures.gd` → stampa `UI_TEXTURE <path>` per file; poi `--editor --quit` per importare (`.import` con mipmap off, filtro lineare, compressione lossless).
- [ ] `ui_palette.gd`: `plate()`, `has_textures()`, tema a texture; rigenerare `theme.tres`; test verde; catture di menu e Impostazioni; gate; commit.

### Task 2: Icone `UiIcon` e suoni di interfaccia

**Files:** Create `godot/scripts/ui/ui_icon.gd`; Modify `godot/scripts/audio/sfx_library.gd` (IDS + 4 sintesi); Test `ui_theme_tests.gd`, `audio_tests.gd` (se conta gli id).

**Interfaces:** `class_name UiIcon extends Control`, `const KINDS: Array[StringName] = [&"nail", &"shovel", &"boot", &"wrench", &"scrap", &"bolt", &"skull", &"clock", &"lamp", &"arrow_right", &"check", &"lock"]`, `@export var kind: StringName`, `@export var tint := UiPalette.TEXT`, `static func make(kind: StringName, size: float, tint := UiPalette.TEXT) -> UiIcon`, `static func for_category(category: StringName) -> StringName` (weapon→nail, terrain→shovel, character→boot, companion→wrench), `static func for_permanent(id: StringName) -> StringName`. `SfxLibrary.IDS` + `ui_move`, `ui_confirm`, `ui_back`, `ui_open`.

- [ ] Test (RED): ogni `kind` istanziato, aggiunto, `await` 1 frame, nessun errore; `for_category(&"weapon") == &"nail"`; `SfxLibrary.build(&"ui_move") != null` e durata < 0,15 s per i quattro.
- [ ] Implementare; `grep -n "IDS.size\|24" godot/tests/audio_tests.gd` e adattare il conteggio se serve; gate; commit.

### Task 3: `UiFx`: cursore, suoni, pop-in, transizioni

**Files:** Create `godot/scripts/ui/ui_fx.gd`; Modify `godot/project.godot` ([autoload] `UiFx` dopo `PauseMenu`), `main_menu.gd:start_level`, `pause_menu.gd:return_to_menu`, `arena_run.gd:595-609`, `boot_intro.gd` (velo via UiFx), aperture dei pannelli (`pause_menu.gd`, `level_up_menu.gd`, `workshop_panel.gd`, `campaign_map_panel.gd`, `game_over_panel.gd`: `UiFx.pop_in(panel)`); Test `godot/tests/ui_fx_tests.gd`.

**Interfaces:** autoload `UiFx` (`extends CanvasLayer`, layer 110, PROCESS_MODE_ALWAYS): `func pop_in(control: Control) -> void`, `func fade_to_scene(path: String) -> void`, `func fade_reload() -> void`, `func play(id: StringName) -> void`, `var cursor_enabled := true`, `func cursor_target() -> Control`, `var is_transitioning: bool`. Collega `get_tree().node_added` → per ogni `BaseButton` connette `pressed` a `_on_button_pressed` (suono + scala 0,97→1) e `focus_entered` al cursore; `get_viewport().gui_focus_changed` sposta il cursore; `ui_cancel` premuto con un pannello aperto suona `ui_back` (ascolta `_unhandled_input`? no: i pannelli consumano l'evento; esporre `UiFx.play(&"ui_back")` e chiamarlo da `close()` dei pannelli).

- [ ] Test (RED): focus su un Button → dopo 10 frame `cursor_target() == button` e cursore visibile a sinistra del pulsante; cambiare focus 5 volte in 5 frame → l'ultimo vince, nessun errore; liberare il pulsante → cursore nascosto, nessun errore; `pop_in` → dopo 12 frame scala 1 e alpha 1; `fade_to_scene` due volte di fila → `is_transitioning` e una sola `change_scene` (contare con un flag `_scene_changes`).
- [ ] Implementare; integrare nelle schermate; `menu_tests`, `settings_tests`, `workshop_tests`, `campaign_tests`, `arena_run_tests`, `intro_tests` verdi; gate; commit.

### Task 4: Menu con sfondo a strati

**Files:** Create `godot/scripts/ui/menu_backdrop.gd`; Modify `main_menu.gd`.

**Interfaces:** `class_name MenuBackdrop extends Control`: tre figli `Control` (`Far`, `Mid`, `Near`) con `_draw` di silhouette (torri a gradoni e viadotto spezzato; colline con noise; terrapieno con erba a ciuffi); `_process` sposta gli strati di `drift * delta` (0,6 / 1,5 / 3 px/s) con wrap; `@export var seed := 7`.

- [ ] Test (RED): `menu.get_node("Backdrop") is MenuBackdrop` con 3 strati; dopo 60 frame gli strati si sono mossi (`position.x` cambiato); la silhouette non copre la colonna (strati con `mouse_filter` IGNORE).
- [ ] Implementare; targhetta con icone (`UiIcon.make(&"scrap", 18, SCRAP)` + testo invariato in `_scrap_label`); cattura `menu.png`; `MENU_FRAME_MS` ≤ 2; gate; commit.

### Task 5: Carte, Officina, campagna, fine livello con texture e icone

**Files:** Modify `level_up_menu.gd`, `workshop_panel.gd`, `campaign_map_panel.gd`, `game_over_panel.gd`.

- [ ] Test (RED): carta del level-up ha un `UiIcon` con `kind == UiIcon.for_category(upgrade.category)` e la fascia usa `StyleBoxTexture` `ribbon.png` con `modulate_color` = colore di rarità; riga dell'Officina ha un `UiIcon`; carta della campagna completata ha `check`, bloccata `lock`; fine livello: `_summary` invariato, tabella con 4 `UiIcon`.
- [ ] Implementare; catture; gate; commit.

### Task 6: HUD con strisce, tubo e icone

**Files:** Modify `run_hud.gd`.

- [ ] Test (RED): `_health_row` dentro un `PanelContainer` con `strip.png`; `_xp_bar` con `StyleBoxTexture` `gauge_fill.png`; `_kills_label` preceduto da `UiIcon` `skull`; `_time_label` da `clock`; contratti `_day_label`, `_tool_label` invariati.
- [ ] Implementare; `day_night_tests`, `lamp_tests`, `boss_tests`, `quake_tests`, `train_tests`, `extraction_tests`, `campaign_tests` verdi; catture `combat`, `hud_boss`; gate; commit.

### Task 7: Logo con bisello e ombra

**Files:** Modify `logo_letters.gdshader`, `game_logo.gd`.

- [ ] Test (RED): `GameLogo` espone `shadow_offset` e il materiale ha i parametri `bevel_px`, `shadow_px`; `set_all(1.0)` resta completo.
- [ ] Shader: campiona `TEXTURE` a `UV ± bevel_px * TEXTURE_PIXEL_SIZE` per luce (alto-sinistra) e ombra (basso-destra) dentro il glifo; ombra portata disegnata da una copia delle Label (modulate scuro) spostata di `shadow_offset`; zolla con sassi (ellissi) e radici (polilinee), erba in 3 toni; chiodo con riflesso. Esportare con `capture_logo.gd`, guardare, copiare `icon.png`; gate; commit.

### Task 8: Catture, misure, documenti, build

- [ ] `capture_ui.gd` + script esistenti in `output/identity/`; guardare tutte le catture; correggere.
- [ ] `docs/DECISIONS.md` D-081; `docs/ART_DIRECTION.md` (materia e icone); `docs/GODOT_WORKFLOW.md` (`build_ui_textures.gd`, UiFx, trappole); `docs/INDEX.md`; `docs/PROJECT_ROADMAP.md` (0c aggiornato); `docs/MIGRATION_STATUS.md`.
- [ ] Export Windows e Linux, smoke test; commit.
