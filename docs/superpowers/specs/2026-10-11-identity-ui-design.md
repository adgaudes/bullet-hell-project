# Identità e interfaccia: nome, logo, tema UI, HUD, intro

**Data:** 11 ottobre 2026. **Stato:** specifica scritta su decisioni prese a voce dal proprietario, in attesa della sua revisione scritta. **Decisione collegata:** da registrare in `docs/DECISIONS.md` come D-079 (nome e identità) e D-080 (tema UI e intro) al primo commit di implementazione. **Rapporto con il restyling (D-077):** è un piano parallelo al piano 2 (Ingegnere); non tocca modelli, shader del mondo, luce o preset grafici.

## 1. Obiettivo

Far sembrare menu, HUD e avvio dello stesso gioco dell'ambiente restylato: un tema unico applicato a tutte le schermate, un HUD ridisegnato, un logo che tiene la palette calda e il tono comico, e un'intro all'avvio breve e saltabile. Oggi tutto è costruito in codice sul tema predefinito di Godot, con font di sistema, pannelli grigi e bordo bianco sul focus; il titolo è "PROTOTYPE 01".

### Cosa il proprietario ha deciso (11 ottobre 2026)

1. **Nome del gioco: "Dwarmageddon: Dig or Die"** (gioco di parole Dwarf + Armageddon; sottotitolo che dice la firma del gioco). I personaggi del roster sono quindi **nani**: resta valido il divieto di D-077 sull'archetipo steampunk con ingranaggi d'ottone; cambia solo la parola con cui li chiamiamo.
2. Restyling **completo** di menu iniziale, pausa, Impostazioni, level-up, Officina, mappa di campagna, fine livello e HUD.
3. **Logo** nel tema del gioco, prodotto dalla pipeline nostra (niente AI, niente asset esterni: D-077 punto 2).
4. **Intro all'avvio, opzione 3**: adesso la rivelazione del logo (3-5 s), costruita come scena con un punto d'aggancio per una vignetta animata con i personaggi nuovi dopo il piano 2 del restyling.
5. Esito: catture prima/dopo e giudizio del proprietario (Continua / Modifica / Scarta), come per l'ambiente.

### Vincoli ereditati

- Hades II come riferimento di resa; palette calda di `ART_DIRECTION.md` (terracotta, rame, ocra, crema sporco) con turchese e corallo come accenti di gameplay.
- Controller e tastiera/mouse equivalenti, controller prioritario; focus sempre visibile; D-pad e stick navigano ogni schermata.
- Steam Deck: 1280x800 leggibile, testo mai sotto 12 px, bordi sicuri (`docs/PLATFORM_AND_INPUT.md`).
- Costo zero; font con licenza libera registrati in `docs/TOOLS_AND_LICENSES.md`.
- I marcatori che il gate e lo smoke test leggono (`PROTOTYPE01_MENU_READY`, `PROTOTYPE01_TESTS`) **non cambiano**: sono identificatori tecnici, non testo mostrato.

## 2. Identità

- `project.godot`: `config/name="Dwarmageddon"`, titolo della finestra "Dwarmageddon: Dig or Die", `config/icon` sull'icona generata (§3). Le cartelle di build e i nomi degli eseguibili restano `Prototype01` finché il proprietario non chiede di rinominarli (gli export e `LocalBuilds/` dipendono da quei nomi).
- `docs/ART_DIRECTION.md`: nota in testa al roster che i quattro personaggi sono nani di questo mondo (tozzi, testa e mani grandi, baricentro basso, come già descritto); nessuna modifica alle schede.
- Nessuna pubblicazione: il nome su Steam lo verifica e lo registra il proprietario.

## 3. Logo

**Forma.** Wordmark su due componenti:

- **"DWARMAGEDDON"** in un carattere slab pesantissimo, lettere leggermente compresse, linea di base con un lieve arco verso l'alto (le lettere centrali salgono di qualche pixel: la parola "spinge" come un terrapieno). Riempimento a gradiente verticale rame → ocra chiara in alto, contorno scuro spesso (marrone-nero), ombra portata verso il basso a destra, un filo di luce crema sul bordo superiore delle lettere.
- **"DIG OR DIE"** sotto, più piccolo, nel carattere dei titoli dell'interfaccia, maiuscolo spaziato, crema su una **fascia scura inclinata** di un paio di gradi, come una targa di lamiera.

**Due decorazioni, non di più** (il logo deve restare leggibile a 231x87, la capsula piccola di Steam):

1. un **chiodo della chiodatrice** piantato di sbieco nella prima "O" di "DWARMAGEDDON", con una crepa che parte dal foro: è l'arma e il tono comico;
2. una **zolla di terra** con tre ciuffi d'erba sotto la parola, che le fa da base: è il terreno, la firma del gioco.

**Due impaginazioni**: `wide` (una riga, per menu e intro) e `stacked` (nome su due righe "DWARMA / GEDDON" con il chiodo nella "O" della seconda riga, per icona e formati quadrati).

**Come si costruisce.** Una scena `scenes/ui/game_logo.tscn` con script `scripts/ui/game_logo.gd` (`class_name GameLogo extends Control`): Label con il font slab e outline/shadow del tema, un `ShaderMaterial` 2D per il gradiente e il bordo di luce, chiodo, crepa, zolla ed erba disegnati in `_draw()` con poligoni. Parametri esportati: `layout` (`wide`/`stacked`), `scale_factor`, `show_subtitle`. Il logo è quindi vettoriale e si ridisegna a qualsiasi risoluzione, non c'è un PNG da mantenere.

**Esportazione.** Uno script di cattura `tests/tools/capture_logo.gd` salva in `output/identity/` `logo_wide.png` (2048 di larghezza, sfondo trasparente), `logo_stacked.png` (1024x1024, trasparente) e `icon.png` (256x256, su fondo terracotta); `icon.png` viene copiato in `godot/icon.png` come icona del progetto e della build. Sono gli unici PNG versionati del logo (LFS, come gli altri `.png`).

## 4. Tema dell'interfaccia

### 4.1 Font

Due famiglie, entrambe SIL Open Font License 1.1, scaricate da `github.com/google/fonts` nella cartella `godot/assets/fonts/` con il rispettivo `OFL.txt`:

- **Alfa Slab One** (titoli, logo, numeri grandi dell'HUD): slab pesante, "martellato", comico senza essere fumettistico.
- **Rubik** (testo, pulsanti, opzioni; variabile 300-900, si usano 400, 500 e 700): leggibile a 16 px, angoli arrotondati che richiamano le forme morbide della resa.

Importazione con MSDF attivo per il logo (si scala senza sgranare) e antialiasing normale per il testo piccolo; hinting leggero. Se al download la licenza non risultasse OFL, la famiglia si sostituisce prima di committare (candidati di riserva: Bungee per i titoli, Nunito per il testo).

### 4.2 Token

Un solo file, `scripts/ui/ui_theme.gd` (`class_name UiTheme extends RefCounted`), espone costanti e costruisce il `Theme`:

| Token | Valore | Uso |
|---|---|---|
| `BG` | `#17110d` | fondo del menu iniziale, overlay a 0,88 |
| `PANEL` | `#2a1f18` a 0,94 | pannelli |
| `PANEL_RAISED` | `#38291f` | pulsanti, righe, carte |
| `BORDER` | `#b5652d` (rame) | bordo dei pannelli e dei pulsanti |
| `BORDER_LIGHT` | `#e0a060` | luce sul bordo superiore |
| `TEXT` | `#f2e6cf` (crema) | testo principale |
| `TEXT_MUTED` | `#c9a25f` (ocra) | etichette secondarie, valori |
| `FOCUS` | `#3fc1b5` (turchese) | bordo e bagliore del controllo attivo |
| `DANGER` | `#e3553f` (corallo) | vita, sconfitta, avvisi |
| `SUCCESS` | `#7fc24f` | vittoria, acquistato |
| `SCRAP` | `#f28a2e` | rottami |
| `XP` | `#1ad9a6` | barra esperienza |

Le rarità del level-up continuano a venire da `UpgradeCatalog.RARITY_COLORS`; le costanti di colore di `RunHud` lette da altri script (`TITLE_COLOR`, `EXTRACTION_COLOR`, `QUAKE_COLOR`, `TRAIN_COLOR`) restano con lo stesso nome e puntano ai token.

Dimensioni testo (a 1280x800): titolo di schermata 40 slab; intestazione di sezione 24 slab; pulsante 22; testo 18; secondario 16; mai sotto 14.

### 4.3 Stili

- **Pannello**: `StyleBoxFlat` fondo `PANEL`, bordo 2 px `BORDER`, bordo superiore 3 px `BORDER_LIGHT`, raggio 6, ombra scura 8 px; sopra, una **grana di carta** generata a runtime (texture 256x256 di rumore a basso contrasto, tile, mescolata al 6 %) così i pannelli non sono piatti ma non c'è nessuna immagine da versionare.
- **Pulsante**: normale `PANEL_RAISED` con bordo `BORDER` 2 px; hover bordo `BORDER_LIGHT`; **focus bordo 3 px `FOCUS` più bagliore esterno 6 px turchese a 0,35**; premuto fondo più scuro e testo `TEXT_MUTED`; disabilitato testo a 0,45 e bordo a 0,3. Il focus è sempre distinguibile dall'hover: sul Deck non c'è mouse.
- **OptionButton, CheckButton, HSlider, ScrollBar, ProgressBar**: stessi fondi e bordi; il cursore dello slider e il pomello dello scroll sono rame; la barra di avanzamento ha riempimento `XP` o `DANGER` secondo l'uso.
- **Varianti di tipo** (`theme type variations`): `TitleLabel`, `SectionLabel`, `MutedLabel`, `CardButton` (carta del level-up e dell'Officina), `MenuButton` (menu iniziale e pausa), `HudLabel` (outline scuro 5 px, nessun pannello).
- Il tema si applica una volta sola a `get_tree().root.theme` dall'autoload `UiTheme` (nuovo, prima di `PauseMenu`); ogni schermata usa le varianti e **non** chiama più `add_theme_*_override` per colori, font e dimensioni, salvo i casi dinamici (colore di rarità, colore di un avviso). La scena `pause_menu.tscn` perde i `theme_override_*` e prende le varianti.

### 4.4 Schermate

Layout a 1280x800 come riferimento, `canvas_items` con `expand` come oggi.

- **Menu iniziale**: fondo a tutto schermo con il **cielo dipinto** (`sky_painted.gdshader` riusato in 2D al tramonto, lento scorrimento delle nuvole), vignetta scura ai bordi, polvere e braci che salgono (`CPUParticles2D`, poche decine). Logo `wide` in alto a sinistra a circa 520 px di larghezza; colonna di pulsanti sotto il logo, allineata a sinistra, larghi 360; in basso a sinistra una **targhetta** con rottami, run giocate e livelli completati (icona e numero, `MutedLabel`); in basso a destra la versione e "Godot 4.7"; i suggerimenti dei tasti restano in basso al centro. La possibilità di mettere l'arena 3D viva come sfondo si rimanda: costa una scena intera sul Deck e si valuta dopo il piano 2.
- **Pausa**: overlay `BG` a 0,88; pannello centrale 420 px con "PAUSA" in `TitleLabel`; i quattro pulsanti con la stessa dimensione (oggi "Torna al menu" è diverso dagli altri).
- **Impostazioni**: stesso pannello a 760 px; intestazioni Grafica, Audio, Controller in `SectionLabel` con una riga rame sotto; righe con etichetta a sinistra e controllo a destra, zebra leggera a righe alterne; la barra di scorrimento rame; il pulsante Indietro ancorato in basso fuori dallo scroll.
- **Level-up**: titolo "LIVELLO N" in slab con "scegli un pezzo" sotto in `MutedLabel`; tre **carte** 300x300: fascia superiore con la rarità (testo e colore di `RARITY_COLORS`), nome in slab 24, tipo in `MutedLabel`, descrizione in Rubik 17; bordo nel colore della rarità; la carta con il focus si alza di 8 px e prende il bagliore turchese; le carte entrano dal basso sfalsate di 60 ms.
- **Officina**: titolo, contatore rottami in `SCRAP` con icona; righe di upgrade come `CardButton` basse (nome, livello attuale con pallini, costo a destra); acquistato in `SUCCESS`, non acquistabile con costo in `DANGER`.
- **Mappa di campagna**: livelli come carte 220x140 con nome, stato (completato, aperto, bloccato) e una linea rame che le collega; dettaglio sotto.
- **Fine livello**: titolo "ROTTAMATO" in `DANGER` o "LIVELLO COMPLETATO" in `SUCCESS`; a sinistra una **tabella** (tempo, livello, rottamati, rottami portati fuori) in due colonne allineate; pulsanti sotto; a destra la mappa del campo scolpito con cornice rame e didascalia.
- **HUD**:
  - in alto a sinistra la vita come **bulloni esagonali** (`_draw()`, pieni `DANGER`, vuoti scuri) e sotto il livello "LV 3" in slab 22;
  - in alto al centro il tempo in slab 28 e, a fianco, il quadrante giorno/notte (un semicerchio con il sole o la luna, al posto del testo "SOLE 04:29");
  - in alto a destra i rottamati in slab 22 con etichetta `MutedLabel`;
  - la barra esperienza in basso, 8 px, riempimento `XP`, due terminali rame;
  - il modo del tool in basso a sinistra sopra la colonna dei comandi; la colonna resta com'è (`ButtonPrompts`) con il font del tema;
  - la barra del boss sopra la barra esperienza, 520x14, nome in slab 20;
  - avvisi (boss, treno, terremoto, estrazione) in una **fascia** scura inclinata al centro in alto, testo slab 28 nel colore dell'evento, freccia come oggi;
  - indicatori a bordo schermo: rombo e testo 15 con outline, invariati nella logica.
  - Tutto resta `MOUSE_FILTER_IGNORE`; nessun elemento nuovo copre il centro dello schermo.

## 5. Intro all'avvio

**Scena nuova** `scenes/main/boot_intro.tscn` (`scripts/ui/boot_intro.gd`, `class_name BootIntro`), che diventa la `main_scene` del progetto. Flusso:

1. All'avvio il boot splash di Godot è un fondo `BG` senza immagine (`boot_splash/show_image=false`, `bg_color`).
2. `BootIntro._ready`: se la riga di comando chiede `--autostart`, `--level=`, `--seed=`, `--boss-at=` o `--capture=`, oppure se il motore gira in `--headless`, **passa subito** a `main_menu.tscn` (il menu poi passa al livello come oggi: gate, smoke test e catture non cambiano).
3. **Punto d'aggancio**: `@export var vignette: PackedScene`; se non è nullo, si istanzia e si attende il suo segnale `finished` prima del logo. Oggi è nullo. Il contratto è scritto nel docstring dello script.
4. **Rivelazione del logo**, 4 s in tutto, timer e tween con `process_mode` sempre attivo:
   - 0,0 s: nero; un rombo basso (`quake_rumble` a volume ridotto) e una banda di terra scura che sale dal basso con polvere (`CPUParticles2D`);
   - 0,6 s: le lettere di "DWARMAGEDDON" cadono una alla volta dall'alto (tween `BACK`, 50 ms di scarto), con una scossa leggera della camera 2D a ogni atterraggio e `terrain_raise`;
   - 1,8 s: il chiodo si pianta nella "O" con `nail_shot` e la crepa si disegna in 150 ms; scossa più forte;
   - 2,2 s: la fascia "DIG OR DIE" si stampa con uno scale da 1,3 a 1 e `scrap_pickup`;
   - 2,4-3,4 s: tenuta; ciuffi d'erba spuntano dalla zolla;
   - 3,4-4,0 s: dissolvenza a `BG` e cambio scena su `main_menu.tscn`.
5. **Saltabile**: qualsiasi `ui_accept`, `ui_cancel`, `pause`, click o tasto porta direttamente alla dissolvenza finale. L'intro suona una volta per avvio; tornare al menu da una run non la ripete.
6. Audio: un `AudioStreamPlayer` sul bus `SFX` con i suoni di `SfxLibrary` (`build` è sincrono; `precache_async` parte già qui così il menu li trova pronti).
7. `PauseMenu.enabled = false` finché l'intro è in scena, come fa il menu.

Il logo dell'intro e quello del menu sono la stessa scena `GameLogo`: l'intro ne anima i pezzi attraverso metodi pubblici (`set_letter_progress`, `set_nail_progress`, `set_subtitle_progress`, `set_grass_progress`), così il disegno vive in un solo posto.

## 6. Steam Deck e controller

- Ogni schermata si prova a 1280x800 nelle catture; nessun testo sotto 14 px.
- Il focus iniziale e i vicini di focus restano quelli di oggi (i test li coprono); il tema rende il focus più visibile, non cambia la navigazione.
- Le icone di Controller Icons hanno uno stile proprio: si accettano come sono, con lo shader di schiarimento già in uso.

## 7. Verifica

- **Suite nuova `tests/ui_theme_tests.gd`** (headless, nel gate): il tema è applicato alla radice; i due font si caricano; per ogni schermata istanziata (menu, pausa, Impostazioni, level-up, Officina, campagna, fine livello, HUD) ogni `Button` ha uno `StyleBox` di focus diverso da quello normale; nessuna dimensione di font sotto 14; `GameLogo` si istanzia nelle due impaginazioni; i metodi di progresso accettano 0 e 1 senza errori.
- **Suite nuova `tests/intro_tests.gd`**: in headless `BootIntro` passa subito al menu; con un flag di test (`--intro-test`) la sequenza arriva a `finished` entro 5 s simulati; `ui_accept` a metà la chiude prima; con `--autostart` non si ferma; `PauseMenu.enabled` torna vero dopo.
- **Suite esistenti**: `menu_tests`, `settings_tests`, `workshop_tests`, `campaign_tests`, `button_prompts_tests` devono restare verdi senza cambi di logica; i testi dei pulsanti che controllano non cambiano.
- **Catture** con `tests/tools/capture_ui.gd` in `output/identity/`: `intro_0_8s`, `intro_2_0s`, `intro_3_0s`, `menu`, `pause`, `settings`, `level_up`, `workshop`, `campaign`, `game_over`, `victory`, `hud_day`, `hud_night`, `hud_boss`; il "prima" in `output/identity/before/` catturato **prima** del primo commit con le catture esistenti (`capture_workshop`, `capture_settings`, `capture_run`, `capture_campaign`, `capture_boss`).
- Gate verde (`tools/godot/Invoke-GodotChecks.ps1`) e smoke test della build Windows riesportata (l'intro non deve bloccare `--autostart`).
- Misura: il menu iniziale con cielo e particelle deve stare sotto 2 ms di frame su PC al preset Alto (letto dal Debug Menu); sul Deck, da misurare dal proprietario.

## 8. Rischi

- **Font a dimensioni piccole**: Alfa Slab One sotto 20 px perde leggibilità; per questo non si usa mai per il testo corrente.
- **MSDF e outline**: in Godot l'outline sui font MSDF è disponibile ma costa; se il logo risultasse sfocato o lento si passa a un font bitmap importato a 128 px per il solo logo.
- **Test che leggono testi**: i test confrontano i testi dei pulsanti ("Gioca", "Riprendi", ...), non il titolo; cambiare "PROTOTYPE 01" non li rompe. Lo smoke test legge `PROTOTYPE01_MENU_READY`, che resta.
- **`main_scene` diversa**: strumenti che caricano `main_menu.tscn` direttamente (`capture_workshop`, `menu_tests`) non passano dall'intro e non cambiano; chi lancia il gioco senza argomenti passa dall'intro.
- **Steam Deck**: cielo dipinto a tutto schermo nel menu; se costasse, si sostituisce con un gradiente statico. Da misurare.
- **Nome dei file di build** ancora `Prototype01`: incoerenza visibile solo nei nomi delle cartelle, non nel gioco.

## 9. Documenti da aggiornare

`docs/DECISIONS.md` (D-079, D-080), `docs/ART_DIRECTION.md` (nani, logo, tema), `docs/TOOLS_AND_LICENSES.md` (font), `docs/GODOT_WORKFLOW.md` (catture `capture_ui`, `capture_logo`, flag `--intro-test`, trappole trovate), `docs/INDEX.md`, `docs/PROJECT_ROADMAP.md` (stato operativo), `docs/MIGRATION_STATUS.md`, `README.md` (nome).

## 10. Fuori scope

Vignetta animata con i personaggi (dopo il piano 2 del restyling), arena 3D viva come sfondo del menu, musica, localizzazione, rinomina delle cartelle di build, capsule Steam nei formati ufficiali (si ricavano dai PNG del logo quando servirà la pagina Steam).
