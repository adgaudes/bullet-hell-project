# Stato della migrazione — leggere per primo

> **File vivo.** Va aggiornato a ogni avanzamento. Chi apre una nuova sessione legge questo e sa esattamente dove siamo e cosa fare.

**Ultimo aggiornamento:** 3 ottobre 2026
**Engine:** Godot 4.7.2 stable, edizione standard/GDScript
**Fase corrente:** 3 completata → **prossima: Fase 4**
**Branch di lavoro:** `feature/godot-migration-foundation` (non ancora integrato in `main`)

## In una frase

Stiamo migrando a Godot un micro-prototipo Unreal gia validato da un playtest, **a parita di funzionalita**, senza aggiungere feature nuove e senza distruggere il progetto originale.

## Avanzamento

| Fase | Contenuto | Stato |
|---:|---|---|
| 0 | Mettere in sicurezza il lavoro, installare la toolchain | **fatta** |
| 1 | Analisi del progetto ereditato | **fatta** → `GODOT_MIGRATION_ANALYSIS.md` |
| 2 | Architettura: conversione unita e assi, struttura | **fatta in parte**: conversione fissata a `1 uu = 0.01 m` e verificata; struttura cartelle creata. Resta da definire il formato delle risorse di tuning `.tres` |
| 3 | Scheletro: progetto, mappa input, scena avviabile | **fatta** |
| 4 | Arena, illuminazione, camera isometrica | **prossima** |
| 5 | Personaggio: movimento, mira, cambio dispositivo, dash | da fare |
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

## Prossimo passo concreto — Fase 4

**Obiettivo:** riprodurre arena, illuminazione e camera isometrica con la stessa scala e la stessa inquadratura del prototipo Unreal.

Riferimento da leggere: `Source/Prototype01/Prototype01ArenaActor.cpp` e la sezione camera di `Prototype01Character.cpp`.

Valori da riprodurre (gia convertiti in metri):

| Parametro | Unreal | Godot |
|---|---:|---:|
| Lato pavimento | 6000 uu | 60 m |
| Spessore pavimento | 40 uu | 0,4 m |
| Altezza pilastri | 500 uu | 5 m |
| Lato pilastri | 150 uu | 1,5 m |
| Rientro pilastri dal bordo | 350 uu | 3,5 m |
| Altezza landmark | 700 uu | 7 m |
| Braccio camera | 1500 uu | 15 m |
| Inclinazione camera | −55° | −55° |

Altri elementi: quattro pilastri angolari di colore diverso (rosso, verde, blu, giallo), landmark viola sul lato +Y, luce direzionale calda inclinata −45°/−30°, cielo procedurale, auto-esposizione disattivata.

**Criterio di uscita:** screenshot a 1280x800 confrontabile con la build Unreal — stessa scala percepita, stessa inquadratura. Oggi l'inquadratura dello scheletro e ancora grezza: il segnaposto appare piccolo e il landmark resta fuori campo.

## Da non dimenticare

- **Non estendere il progetto Unreal.** E materiale di riferimento da leggere, non da far evolvere.
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
