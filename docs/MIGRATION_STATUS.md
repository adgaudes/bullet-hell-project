# Stato della migrazione — leggere per primo

> **File vivo.** Va aggiornato a ogni avanzamento. Chi apre una nuova sessione legge questo e sa esattamente dove siamo e cosa fare.

**Ultimo aggiornamento:** 3 ottobre 2026
**Engine:** Godot 4.7.2 stable, edizione standard/GDScript
**Fase corrente:** 7 completata nel codice; **playtest del proprietario in sospeso** per Fase 5 (feel) e Fase 7 (Test A manuale) → prossima: Fase 8
**Branch di lavoro:** `feature/godot-migration-foundation` (non ancora integrato in `main`)

## In una frase

Stiamo migrando a Godot un micro-prototipo Unreal gia validato da un playtest, **a parita di funzionalita**, senza aggiungere feature nuove e senza distruggere il progetto originale.

## Avanzamento

| Fase | Contenuto | Stato |
|---:|---|---|
| 0 | Mettere in sicurezza il lavoro, installare la toolchain | **fatta** |
| 1 | Analisi del progetto ereditato | **fatta** → `GODOT_MIGRATION_ANALYSIS.md` |
| 2 | Architettura: conversione unita e assi, struttura | **fatta**: conversione in `UnrealSpace` (D-023), tuning come `Resource` tipizzate in `.tres` (D-024) |
| 3 | Scheletro: progetto, mappa input, scena avviabile | **fatta** |
| 4 | Arena, illuminazione, camera isometrica | **fatta** |
| 5 | Personaggio: movimento, mira, cambio dispositivo, dash | **fatta nel codice**, playtest del proprietario da fare |
| 6 | Griglia terreno: stato, presentazione, collisioni | **fatta** |
| 7 | Tool e anteprima | **fatta nel codice**, Test A manuale del proprietario da fare |
| 8 | Slice B: penalita velocita, hazard | **prossima** |
| 9 | Verifica di parita, export, smoke test Steam Deck | da fare |
| 10 | Pulizia documentale, destino del progetto Unreal | da fare |

Dettaglio completo di ogni fase e criteri di uscita: `GODOT_MIGRATION_ANALYSIS.md`, sezione 9.

## Fatto finora

- Godot 4.7.2 installato via winget; CLI verificata (validazione statica, run headless, cattura visiva, apertura editor).
- Canale di lavoro deciso e documentato: filesystem + CLI, nessun MCP. Vedi `GODOT_WORKFLOW.md`.
- Documentazione di governance riscritta: `AGENTS.md`, `CLAUDE.md`, decisioni D-019…D-022.
- Terrain Slice B del progetto Unreal **committato** e messo in sicurezza.
- Progetto Godot in `godot/`: 12 azioni input con parita controller e tastiera/mouse, scena `smoke_test` apribile, sonda di verifica.
- Rimossi circa 7,6 GB di artefatti Unreal rigenerabili.

## Fase 4 — com'e stata chiusa

- `scripts/core/unreal_space.gd` (`UnrealSpace`): unico punto di conversione cm→m e assi (UE X→Godot −Z, UE Y→+X, UE Z→+Y).
- `scripts/arena/arena.gd` (`Arena`, `@tool`): costruisce pavimento con griglia mondo, 4 pilastri colorati, landmark, sole, cielo procedurale, auto-esposizione spenta, collisioni statiche. Parametri esportati in centimetri Unreal.
- `scripts/camera/isometric_camera_rig.gd` (`IsometricCameraRig`): rig `top_level`, braccio 15 m, pitch −55°, FOV orizzontale 90° (default Unreal), segue la posizione del bersaglio.
- `smoke_test.tscn` usa arena e rig; il segnaposto del giocatore sta al centro capsula (0,88 m, default ACharacter).
- La sonda accetta `-- --capture=<file.png>` per la cattura visiva.

Verificato: `--check-only` su tutti gli script, run headless con marker `PROTOTYPE01_ARENA_READY` e `PROTOTYPE01_CAMERA_READY`, cattura 1280x800 dalla camera di gioco (scala: cella da 2,4 m ≈ 120 px, coerente con la build Unreal) e cattura dall'alto temporanea che conferma posizione e colore di pilastri e landmark e direzione delle ombre.

Non identico a Unreal, per scelta (R-G1): tonalita della luce e materiale griglia sono approssimati.

## Fase 5 — com'e stata chiusa

- `scenes/player/player.tscn` + `scripts/player/player_character.gd` (`PlayerCharacter`, `CharacterBody3D`): capsula 0,34/1,76 m, origine al centro capsula, graybox 0,45×0,9×0,9 con indicatore frontale ciano, senza ombre.
- `scripts/player/planar_movement.gd` (`PlanarMovement`): porta letterale di `CalcVelocity` + `ApplyVelocityBraking` di Unreal (Walking). Anche il dash passa per la frenata, come in Unreal: velocita nominale 30 m/s, effettiva 21,66 m/s a 60 fps, ~3,97 m in 11 frame.
- `scripts/player/player_tuning.gd` + `resources/tuning/player_default.tres`: tuning in unita Unreal (D-024).
- Mira: stick destro con dead zone 0,2 e risposta proporzionale, oppure mouse deproiettato sul piano del personaggio; commutazione automatica (`PROTOTYPE01_AIM_DEVICE`). Stick in alto = sguardo verso l'alto dello schermo, come nella build Unreal dopo la correzione di playtest.
- Dash a eventi (come il trigger `Started`), direzione dell'ultimo movimento valido, colori ciano/grigio/arancio, scala 1,15; durata e cooldown misurati dall'attivazione.
- Interpolazione fisica attiva nel progetto; il rig camera legge la posizione interpolata.
- Test automatici: `tests/player_tests.gd`, 24 controlli, tutti verdi.

Non verificato da un agente: **il feel con controller e mouse reali**. Va playtestato dal proprietario: aprire il progetto ed eseguire (F5), provare movimento, mira con stick e mouse, cambio dispositivo, dash e cooldown, possibilmente confrontando con la build Unreal di riferimento.

Differenze note rispetto a Unreal: dead zone del movimento radiale 0,2 di Godot invece di quella per asse di Unreal; il passo fisico e fisso a 60 Hz, quindi il dash non varia con il framerate (in Unreal si').

## Fase 6 — com'e stata chiusa

- `scripts/terrain/terrain_state.gd` (`TerrainState`): stato logico puro. Tre stati, transizioni di un livello per passo, cella protetta (0,0), rifiuto per occupazione distinto. Coordinate di cella **come in Unreal** (X avanti, Y destra): i log `PROTOTYPE01_TERRAIN_*` restano confrontabili con il protocollo di playtest Slice A.
- `scripts/terrain/terrain_grid.gd` (`TerrainGrid`, `@tool`): presentazione (una cella = `StaticBody3D` con mesh e collisione), colore per istanza su un solo materiale (`resources/materials/terrain_cell.gdshader`), collisione solo su Raised, controllo anti-intrappolamento sul volume del personaggio (`PlayerCharacter.get_collision_aabb()`), API `cell_at`, `cell_state_at`, `can_apply_at`, `apply_command_at`, `lowered_speed_penalty`.
- `scripts/terrain/terrain_tuning.gd` + `resources/tuning/terrain_default.tres`: 7×7, celle 240 cm, gap 12, altezze 4/12/120, penalita 0,5.
- Il nodo `TerrainGrid` sta in `smoke_test.tscn`, centrato sotto il personaggio.

Verificato: `tests/terrain_tests.gd`, 37 controlli verdi (regole, 49 celle senza duplicati dopo ricostruzioni, mappatura mondo→cella, collisione via raycast, rialzo rifiutato sotto il personaggio, personaggio bloccato da una cella Raised e libero quando torna Normal); `tests/player_tests.gd` sempre verde; cattura visiva con celle nei tre stati.

Limite noto: modificare i valori dentro `terrain_default.tres` dall'Inspector non ricostruisce la griglia in tempo reale nell'editor; serve riaprire la scena o riassegnare la risorsa.

## Fase 7 — com'e stata chiusa

- `PlayerCharacter`: `terrain_grid` (collegata in `smoke_test.tscn`), `terrain_tool_mode` Dig/Raise, bersaglio a `terrain_tool_range_cm` (480) lungo il forward planare aggiornato a ogni passo fisico; `terrain_tool` applica, `terrain_mode` alterna. Input a eventi come il dash.
- `TerrainGrid.update_preview()` / `hide_preview()`: anteprima 72% della cella, 5 cm, 2 cm sopra la cella; ciano Dig, giallo Raise, rosso impossibile; nascosta fuori griglia. `preview_cell` esposto.
- Log invariati rispetto a Unreal: `PROTOTYPE01_TERRAIN_MODE`, `PROTOTYPE01_TERRAIN_CHANGED`, `PROTOTYPE01_TERRAIN_REJECTED`, `PROTOTYPE01_TERRAIN_RAISE_OCCUPIED_REJECTED`.
- Sonda: rimossi i log `PROTOTYPE01_ACTION *`, sostituiti da quelli reali.

Verificato: `tests/terrain_tool_tests.gd`, 20 controlli verdi che automatizzano i passi 5-9 del Test A (scavo, cambio modalita, Normal/Raised, anteprima rossa oltre il limite, cella protetta, fuori griglia, modifiche rapide); le altre due suite restano verdi; cattura con anteprima ciano.

**Da fare dal proprietario:** Test A di `docs/PLAYTESTS/TERRAIN_GRID_SLICE_A_2026-09-22.md`, passi 2-4 e domande percettive (corrispondenza cella/direzione, leggibilita colori, naturalezza del cambio modalita), con mouse e controller. Si avvia con F5 dall'editor Godot.

## Prossimo passo concreto — Fase 8

**Obiettivo:** Slice B a parita con Unreal: penalita di velocita sulle celle Lowered (`UpdateTerrainSpeedModifier`, usare `PlayerCharacter.speed_multiplier` e `TerrainGrid.lowered_speed_penalty()`), hazard che percorre la corsia lungo l'asse X Unreal della griglia (`Prototype01TerrainHazardActor.cpp`, configurazione corsia in `SmokeTestGameMode.cpp`) e si ferma su un terrapieno Raised. Criterio di uscita: l'hazard si ferma su un terrapieno alzato dal giocatore.

## Da non dimenticare

- **Non estendere il progetto Unreal.** E materiale di riferimento da leggere, non da far evolvere.
- **Il riferimento Unreal si legge dal codice sorgente**, non avviando editor o build: il proprietario non vuole che si apra Unreal.
- **Non cancellare `Source/`, `Content/`, `Config/`, `Prototype01.uproject` prima della Fase 9**: sono la specifica da cui si migra.
- **Non cancellare `Artifacts/Playtests/`**: unica evidenza con hash del playtest Slice A superato, non ricostruibile dopo la rimozione di Unreal.
- La parita di feel del personaggio (Fase 5) **va playtestata dal proprietario**, non dichiarata da un agente.
- Il rischio aperto piu serio e **R-G1**, la resa grafica senza Lumen e Nanite rispetto a `ART_DIRECTION.md`. Si manifestera alla vertical slice, non adesso.

## Comandi di lavoro

```bash
# validare uno script senza eseguirlo
godot_console --headless --path godot --check-only --script res://percorso.gd

# eseguire e leggere i log
godot_console --headless --path godot --quit-after 120

# verifica visiva (serve una finestra reale, mai --headless)
godot_console --path godot --resolution 1280x800 --quit-after 240 res://scena.tscn

# aprire l'editor
godot --path godot --editor
```

Usare sempre `godot_console`, mai `godot`, per i comandi non interattivi: il secondo non scrive su stdout. Passare sempre `--quit-after`. Spiegazione e trappole in `GODOT_WORKFLOW.md`.

## Decisioni aperte

- formato delle risorse di tuning `.tres` (chiusura della Fase 2);
- destino del progetto Unreal dopo la Fase 9: archiviare o rimuovere;
- `LocalBuilds/` (1,8 GB), `dev/` e `output/`: da conservare, ignorare o rimuovere;
- build Linux nativa invece di Proton per Steam Deck, resa possibile dall'export nativo di Godot;
- se e quando installare un MCP Godot: trigger in `GODOT_WORKFLOW.md`.
