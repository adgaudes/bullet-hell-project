# Interfaccia "fatta a mano": passata di qualità su tema, menu, HUD, logo e feedback

**Data:** 11 ottobre 2026, sera. **Stato:** richiesta del proprietario ("deve sembrare handmade, di qualità come un tripla A"), scelte dell'agente registrate come D-081. **Estende** `2026-10-11-identity-ui-design.md`: stessi vincoli (niente asset esterni, niente AI, font OFL, controller prioritario, Steam Deck 1280x800, costo zero).

## 1. Obiettivo

L'interfaccia di oggi è corretta ma piatta: rettangoli con bordo, nessuna materia, nessun feedback. Deve sembrare costruita da un artista: superfici con materia (cuoio, lamiera di rame, pergamena), bordi lavorati con rivetti e usura, ornamenti disegnati, icone, un cursore fisico, micro-animazioni e suoni a ogni azione, transizioni fra le scene. Tutto resta prodotto dalla pipeline nostra: le texture le genera uno script Godot in PNG versionati, le icone e gli ornamenti sono poligoni disegnati in codice.

## 2. Materia: texture generate (`tests/tools/build_ui_textures.gd` → `assets/textures/ui/`)

Script Godot headless che scrive PNG con `Image` (rumore `FastNoiseLite`, gradienti, usura ai bordi, rivetti con luce e ombra, bisello). Tutti 9-slice, 96x96 con margini 28 px salvo dove indicato:

| File | Aspetto | Dove |
|---|---|---|
| `plate_panel.png` | cuoio scuro con grana, cornice di rame battuto con bisello, un rivetto in ogni angolo, usura chiara sugli spigoli | pannelli (pausa, Impostazioni, fine livello, targhetta, targa degli avvisi) |
| `plate_button.png` / `plate_button_hover.png` / `plate_button_pressed.png` | lamiera di rame scuro in rilievo (luce in alto, ombra in basso), bordo rame; hover più chiaro; premuto incassato (luce e ombra invertite) | pulsanti, OptionButton, CheckButton |
| `plate_button_focus.png` | come il normale ma con bordo turchese e alone esterno | focus |
| `plate_card.png` | pergamena crema con grana, bordi bruciacchiati, un'ombra interna | carte del level-up, righe dell'Officina, carte della campagna |
| `plate_card_focus.png` | pergamena con bordo turchese e alone | focus delle carte |
| `ribbon.png` | nastro bianco con pieghe alle estremità (da tingere con `modulate_color`) | fascia della rarità |
| `rule.png` (256x12, 3-slice) | linea di rame disegnata a mano, spessore irregolare, un nodo al centro | sotto le intestazioni |
| `gauge.png` / `gauge_fill.png` (64x24, 3-slice) | tubo di metallo con terminali; riempimento con bagliore | barra esperienza, barra del boss, slider |
| `strip.png` (96x48) | striscia di lamiera scura con due rivetti | dietro vita, tempo, rottamati nell'HUD |

Il tema (`UiPalette.build_theme()`) usa `StyleBoxTexture` con questi PNG; i colori di testo restano i token. `build_theme.gd` resta il generatore del `.tres`; `build_ui_textures.gd` va rilanciato dopo ogni modifica al generatore (i PNG sono in LFS e versionati).

## 3. Ornamenti e icone (`scripts/ui/ui_icon.gd`, `class_name UiIcon extends Control`)

Pittogrammi disegnati con poligoni, in due toni (riempimento crema o rame, outline scuro), scalabili: `nail` (arma), `shovel` (tool terreno), `boot` (personaggio), `wrench` (compagno), `scrap` (rottami: tre frammenti), `bolt` (vita), `skull` (abbattuti), `clock` (tempo), `lamp` (lampione), `arrow_right` (cursore), `check` (completato), `lock` (bloccato). `@export var kind: StringName`, `@export var tint: Color`, dimensione da `custom_minimum_size`. Usati: carte del level-up (icona della categoria), righe dell'Officina (icona per id), campagna (check/lock), HUD (bolt, skull, clock, scrap), targhetta del menu (scrap), cursore.

## 4. Feedback (`scripts/ui/ui_fx.gd`, autoload `UiFx`, CanvasLayer 110)

- **Cursore**: un chiodo (`UiIcon` `arrow_right`, rame) che si sposta con un tween di 90 ms accanto al Control con il focus (`viewport.gui_focus_changed`), con un leggero bob; nascosto quando nessun Control ha il focus o quando il focus è nell'HUD.
- **Suoni**: `ui_move` (tic secco di metallo), `ui_confirm` (clink di rame), `ui_back` (tock più basso), `ui_open` (lamiera che scorre), sintetizzati in `SfxLibrary` come gli altri; `UiFx` li suona su cambio di focus, `pressed` dei Button (collegato automaticamente a ogni Button che entra nell'albero tramite `node_added`), `ui_cancel` nei pannelli, apertura dei pannelli.
- **Micro-animazioni**: pulsante premuto scala a 0,97 e torna in 80 ms; `UiFx.pop_in(control)` per i pannelli che si aprono (scala 0,96→1 e alpha 0→1 in 150 ms, anche a gioco fermo); `UiFx.pulse(control)` per il bagliore del focus (modulate che respira).
- **Transizioni**: `UiFx.fade_to_scene(path)` e `UiFx.fade_reload()`: velo del colore di fondo in 0,25 s, cambio scena, velo che si apre in 0,35 s. Usati da menu → livello, pausa → menu, fine livello → Officina/ricomincia/menu/prossimo livello. L'intro usa lo stesso velo.

## 5. Schermate

- **Menu**: dietro i pulsanti uno sfondo a strati disegnato (`scripts/ui/menu_backdrop.gd`): cielo dipinto con bande di nuvole, sole; in lontananza silhouette di torri in rovina e di un viadotto spezzato; colline con erba a ciuffi e un terrapieno in primo piano; braci e polvere; i tre strati scorrono piano in parallasse. La targhetta del profilo con icone (rottami, run, livelli). I pulsanti con il cursore a chiodo.
- **Pausa e Impostazioni**: pannello di cuoio con rivetti, intestazioni con `rule.png`, slider su `gauge.png` con pomello a rivetto, OptionButton su lamiera.
- **Level-up**: carte di pergamena con nastro della rarità in alto (tinto), icona della categoria grande sotto il nastro, nome in slab, descrizione; la carta con il focus si alza e brilla; entrata sfalsata.
- **Officina**: righe di pergamena con icona a sinistra, nome, pallini del livello, costo a destra; totale rottami con icona.
- **Campagna**: carte con numero del livello in un cerchio di rame, icona check/lock, linea rame fra le carte.
- **Fine livello**: pannello di cuoio, tabella con icone, mappa in cornice di rame.
- **HUD**: vita su una striscia di lamiera con l'icona `bolt`; tempo su una striscia con `clock`; rottamati con `skull`; barra esperienza come tubo (`gauge`) con terminali; barra del boss uguale, con il nome in slab e i terminali; targa degli avvisi di cuoio con rivetti; modo lampione con icona.
- **Logo**: lettere con bisello (shader: luce sul bordo alto, ombra sul bordo basso campionando il glifo), ombra portata, graffi leggeri; zolla con sassi e radici; erba più varia; chiodo con riflesso.

## 6. Verifica

- `tests/ui_theme_tests.gd`: i PNG esistono; `Button` `normal/hover/pressed/focus` e `PanelContainer` `panel` sono `StyleBoxTexture` con la texture giusta; `UiIcon` disegna ogni `kind` senza errori; `UiFx` sposta il cursore sul Control con il focus e suona `ui_move`; `pop_in` finisce a scala 1; `fade_to_scene` cambia scena una sola volta.
- Suite esistenti verdi; `SfxLibrary` con 28 id (`audio_tests` conta?) da adattare se conta gli id.
- Catture rifatte in `output/identity/`; misura del menu ≤ 2 ms su PC.
- Gate verde, build riesportate, smoke test.

## 7. Fuori scope

Arena 3D viva nel menu, musica, vignetta dell'intro, localizzazione, rinomina delle build.
