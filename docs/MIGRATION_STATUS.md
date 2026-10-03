# Stato della migrazione — leggere per primo

> **File vivo.** Va aggiornato a ogni avanzamento. Chi apre una nuova sessione legge questo e sa esattamente dove siamo e cosa fare.

**Ultimo aggiornamento:** 3 ottobre 2026
**Engine:** Godot 4.7.2 stable, edizione standard/GDScript
**Fase corrente:** 4 completata → **prossima: Fase 5**
**Branch di lavoro:** `feature/godot-migration-foundation` (non ancora integrato in `main`)

## In una frase

Stiamo migrando a Godot un micro-prototipo Unreal gia validato da un playtest, **a parita di funzionalita**, senza aggiungere feature nuove e senza distruggere il progetto originale.

## Avanzamento

| Fase | Contenuto | Stato |
|---:|---|---|
| 0 | Mettere in sicurezza il lavoro, installare la toolchain | **fatta** |
| 1 | Analisi del progetto ereditato | **fatta** → `GODOT_MIGRATION_ANALYSIS.md` |
| 2 | Architettura: conversione unita e assi, struttura | **fatta in parte**: conversione unita e assi centralizzata in `UnrealSpace` (D-023) e verificata visivamente; struttura cartelle creata. Resta da definire il formato delle risorse di tuning `.tres` |
| 3 | Scheletro: progetto, mappa input, scena avviabile | **fatta** |
| 4 | Arena, illuminazione, camera isometrica | **fatta** |
| 5 | Personaggio: movimento, mira, cambio dispositivo, dash | **prossima** |
| 6 | Griglia terreno: stato, presentazione, collisioni | da fare |
| 7 | Tool e anteprima | da fare |
| 8 | Slice B: penalita velocita, hazard | da fare |
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

## Prossimo passo concreto — Fase 5

**Obiettivo:** personaggio `CharacterBody3D` con movimento planare, mira (stick destro e deproiezione del mouse), cambio dispositivo e dash, a parita con `Source/Prototype01/Prototype01Character.cpp`.

Note: il personaggio sostituisce `PlayerPlaceholder` come bersaglio del `CameraRig`; il diagnostico di movimento in `skeleton_probe.gd` va rimosso. Mesh graybox Unreal: cubo 0,9 (avanti) × 0,45 (lato) × 0,9 (alto), senza ombre, indicatore frontale. La parita di feel va playtestata dal proprietario.

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
