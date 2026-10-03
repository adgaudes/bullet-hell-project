# Playtest di parita Godot — desktop e Steam Deck

## Obiettivo

Confermare che il porting Godot si comporta come il prototipo Unreal gia approvato. Sono le tre evidenze che un agente non puo fornire (vedi `docs/GODOT_PARITY_CHECKLIST.md`):

1. **feel del personaggio** (criterio di uscita della Fase 5);
2. **Test A percettivo** del tool terreno (criterio della Fase 7);
3. **Steam Deck**.

Non e un test di divertimento ne di grafica: la resa e volutamente graybox e la luce e solo simile a Unreal (rischio R-G1).

## Build

| Build | Percorso | Note |
|---|---|---|
| Godot Windows | `LocalBuilds/Prototype01-Godot-Win64/Prototype01.exe` | 109 MB, file unico, smoke test superato |
| Godot Linux | `LocalBuilds/Prototype01-Godot-Linux/Prototype01.x86_64` | 74 MB, file unico, **mai eseguita**: il Deck e il primo sistema Linux |
| Unreal di riferimento | `LocalBuilds/Prototype01-TerrainGrid-Win64-v1/Windows/Prototype01.exe` | per il confronto A/B |

In alternativa alla build: aprire `godot/project.godot` nell'editor e premere F5.

Controlli: identici a Unreal (legenda in `TERRAIN_GRID_SLICE_A_2026-09-22.md`). Novita rispetto alla Slice A: celle Raised solide, rallentamento sulle celle Lowered, sfera magenta che attraversa la colonna centrale e si ferma contro i terrapieni.

## Parte 1 — Feel del personaggio, desktop, 10 minuti

Alternare le due build (Unreal e Godot) per qualche minuto ciascuna, prima con il controller e poi con tastiera e mouse.

| Domanda | Controller | Tastiera/mouse |
|---|---|---|
| Accelerazione e arresto sembrano gli stessi? | | |
| La velocita massima sembra la stessa? | | |
| Con lo stick inclinato poco o a meta, la risposta e la stessa? (punto non verificabile da un agente) | | — |
| La rotazione verso stick o cursore ha la stessa prontezza? | | |
| Il passaggio stick ↔ mouse avviene senza intoppi? | — | |
| Il dash copre la stessa distanza, con lo stesso ritmo di cooldown? | | |
| Inquadratura e scala percepita coincidono? | | |
| Differenze notate (anche piccole) | | |

## Parte 2 — Test A percettivo, desktop, 5-10 minuti

Ripetere i passi 3-9 del Test A di `TERRAIN_GRID_SLICE_A_2026-09-22.md` sulla build Godot. I passi 5-9 sono gia verificati in automatico come logica (`tests/terrain_tool_tests.gd`): qui conta come vengono percepiti.

| Domanda | Esito / nota |
|---|---|
| La cella selezionata coincide con la direzione percepita? | |
| Ciano, giallo e rosso comunicano il significato senza esitazione? | |
| Lowered, Normal e Raised sono distinguibili? | |
| Il cambio modalita e naturale con il controller? | |
| Il cambio modalita e naturale con mouse e tastiera? | |
| Quante modifiche involontarie sono avvenute? | |
| La cella protetta comunica chiaramente il rifiuto? | |
| La sfera magenta che si ferma sul terrapieno si legge come conseguenza della propria azione? | |

## Parte 3 — Steam Deck LCD, 10-15 minuti

Scegliere una delle due strade (la scelta e una decisione aperta: annotare quale si e usata).

- **Linux nativa**: copiare `Prototype01.x86_64` sul Deck (Desktop Mode, chiavetta o rete), renderlo eseguibile (Proprieta → Permessi, oppure `chmod +x`), aggiungerlo a Steam come gioco non Steam e avviarlo in Game Mode **senza** forzare Proton.
- **Windows via Proton**: come per la Slice A, con `Prototype01.exe` e Steam Play attivo.

Per distribuzioni ripetute vale la procedura SteamOS Devkit Client descritta nel documento della Slice A: va installato solo con conferma del proprietario.

Poi ripetere i passi di esecuzione del Test B della Slice A: risoluzione, controlli integrati, frame pacing durante dieci modifiche consecutive, leggibilita, sospensione e ripresa, chiusura e secondo avvio.

| Campo | Esito / nota |
|---|---|
| Strada usata (Linux nativa / Proton) e versione | |
| Versione SteamOS | |
| Risoluzione rilevata | |
| Avvio riuscito | |
| Controller integrato completo | |
| Anteprima e stati leggibili | |
| Frame pacing percepito | |
| Sospensione e ripresa | |
| Chiusura e secondo avvio | |
| Problemi specifici | |

## Esito

| Gate | Continua / Modifica | Nota |
|---|---|---|
| Fase 5 — feel | | |
| Fase 7 — Test A | | |
| Steam Deck | | |

Con tre esiti "Continua" la migrazione e chiusa e si puo eseguire la proposta della Fase 10 sul progetto Unreal (`docs/MIGRATION_STATUS.md`).
