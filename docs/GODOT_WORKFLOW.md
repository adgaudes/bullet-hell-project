# Flusso di lavoro Godot

Sostituisce `docs/UNREAL_EDITOR_WORKFLOW.md`, conservato come archivio storico.

## Principio

Il canale di lavoro non e un server, un plugin o un controllo remoto dell'editor: **e il filesystem**. Scene, risorse, impostazioni e mappature input di Godot sono file di testo. Un agente li legge, li modifica e li verifica con gli stessi strumenti usati per il codice, e ogni modifica compare come diff leggibile in Git.

Conseguenza diretta: la vecchia regola "non modificare manualmente gli asset" non si applica piu. In Godot modificare un `.tscn` a mano e il flusso normale, non un'eccezione rischiosa.

## Toolchain verificata

| Voce | Valore |
|---|---|
| Engine | Godot **4.7.2 stable** (`4.7.2.stable.official.ed1daf0bf`) |
| Edizione | Standard / GDScript (**non** .NET/Mono) |
| Installazione | `winget install --id GodotEngine.GodotEngine` |
| Binari | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*` |
| Alias | `%LOCALAPPDATA%\Microsoft\WinGet\Links\` |
| Verificato il | 3 ottobre 2026 |

Fonte ufficiale della versione: <https://godotengine.org/download/windows/> (4.7.2 rilasciata il 18 agosto 2026).

### Regola obbligatoria: usare `godot_console`

L'installazione crea due alias. **Non sono equivalenti.**

- `godot` e una applicazione GUI Windows: **non scrive su stdout**. `godot --version` non produce alcun output. Inutilizzabile da riga di comando.
- `godot_console` e la variante console: stampa su stdout ed e l'unica usabile da un agente, da uno script o da una CI.

Usare sempre `godot_console`.

## Comandi verificati

Tutti eseguiti e confermati il 3 ottobre 2026.

### Validare il codice senza eseguirlo

```bash
godot_console --headless --path . --check-only --script res://percorso/script.gd
```

- Script valido: nessun output di errore, **exit 0**.
- Script non valido: errori con file e riga esatti, **exit 1**.

Con la tipizzazione statica di GDScript intercetta anche gli **errori di tipo**, non solo di sintassi. Esempio reale di output:

```
SCRIPT ERROR: Parse Error: Cannot assign a value of type "String" as "int".
   at: GDScript::reload (res://broken.gd:4)
SCRIPT ERROR: Parse Error: Function "undefined_function_call()" not found in base self.
   at: GDScript::reload (res://broken.gd:5)
```

E un gate di qualita utilizzabile subito, senza alcuna dipendenza aggiuntiva.

### Eseguire il progetto e leggere i log

```bash
godot_console --headless --path .
```

La scena principale parte, `print()` arriva su stdout, l'editor non viene mai aperto.

I marker diagnostici gia in uso nel progetto (`PROTOTYPE01_INPUT_READY`, `PROTOTYPE01_TERRAIN_CHANGED`, ...) continuano a funzionare identici: in GDScript sono semplici `print()`. Il protocollo di verifica testuale del prototipo Unreal si trasferisce invariato.

### Test automatici

```bash
godot_console --headless --path godot --fixed-fps 60 --script res://tests/player_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/terrain_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/terrain_tool_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/slice_b_tests.gd
```

`--fixed-fps 60` rende ogni frame un passo fisico da 1/60 s: risultati deterministici. Esito su stdout (`PROTOTYPE01_TESTS PASS|FAIL`) ed exit code 0/1. Trappola verificata: in headless la posizione del cursore del viewport non segue gli eventi mouse simulati; testare la logica sulla posizione schermo esplicita.

Trappola verificata: `CollisionShape3D.set_deferred("disabled", ...)` lascia la forma attiva per un frame; se applicato in costruzione spinge via i corpi sovrapposti. In costruzione impostarlo direttamente, a runtime differito.

Per l'input nei test: `Input.action_press()` per azioni tenute; per azioni a evento (dash) usare `Input.parse_input_event()` con `InputEventAction`, perche `is_action_just_pressed` in `_physics_process` puo perdere una pressione simulata.

### Verifica visiva

Lo script salva un PNG, che l'agente puo poi **aprire e guardare**:

```gdscript
await RenderingServer.frame_post_draw
await RenderingServer.frame_post_draw
var img := get_viewport().get_texture().get_image()
img.save_png("res://capture.png")
```

```bash
godot_console --path . --resolution 1280x800 --quit-after 180 res://scena.tscn
```

Nel progetto e gia pronto: la sonda della scena principale accetta `-- --capture=<file.png>`, salva il frame ed esce.

Verificato: PNG 1280x800 (risoluzione Steam Deck), Vulkan Forward+, `err=0`.

La verifica visiva e quindi **ripetibile, automatizzabile e versionabile**, e non richiede che il proprietario guardi al posto dell'agente.

### Trappola verificata: niente cattura in headless

In `--headless` Godot usa un renderer *dummy*: i frame non vengono mai disegnati, quindi `await RenderingServer.frame_post_draw` **non si risolve mai** e il processo resta appeso a tempo indefinito. Osservato direttamente: due processi bloccati da terminare a mano.

Regole operative che ne derivano:

1. La cattura di screenshot richiede una **finestra reale** (niente `--headless`).
2. Passare **sempre** `--quit-after N` quando si esegue il gioco: e la rete di sicurezza contro il blocco.
3. Aggiungere anche un timeout esterno (`timeout 90 ...`) per i run non interattivi.
4. Se un run resta appeso: `taskkill //F //IM "Godot_v4.7.2-stable_win64_console.exe"` e la variante senza `_console`.

### Flag utili

| Scopo | Flag |
|---|---|
| Senza finestra | `--headless` |
| Progetto da usare | `--path <dir>` |
| Uscita garantita dopo N frame | `--quit-after N` |
| Risoluzione (test Steam Deck) | `--resolution 1280x800` |
| Log dettagliato | `--verbose` |
| Validazione senza esecuzione | `--check-only --script <file>` |

## Non ancora verificato

Da confermare quando servira, senza darlo per acquisito:

- `--import` (reimport headless degli asset);
- `--export-release` / `--export-debug`: richiedono gli **export template**, un download separato non ancora effettuato. Serviranno alla Fase 9 (packaging Windows e valutazione build Linux nativa per Steam Deck);
- framework di test (GUT, GdUnit4): sono addon di terze parti e ricadono sotto la regola delle dipendenze.

## Model Context Protocol: valutato, rimandato

Valutazione del 3 ottobre 2026.

| | IvanMurzak/Godot-MCP | tugcantopaloglu/godot-mcp |
|---|---|---|
| Licenza | Apache-2.0 | MIT |
| Stelle / commit | 265 / 269 | 473 / 33 |
| Godot | 4.3+, **solo edizione .NET/Mono** | 4.4+, testato su 4.7 |
| Editor aperto | richiesto | non richiesto |
| Dipendenze nuove | .NET + NuGet | Node.js + npm |
| Costo / telemetria | nessuno rilevato | nessuno rilevato |

**Decisione: non installare ora.** Motivi:

1. Quasi tutto cio che offrono e gia coperto e verificato: manipolazione scene (modifica del `.tscn`), creazione script, screenshot, log, esecuzione del progetto.
2. Il candidato piu maturo richiede l'edizione .NET/Mono, incompatibile con la scelta GDScript senza rifare la toolchain.
3. 157 tool dichiarati in 33 commit indicano ampiezza non proporzionata alla maturita; include `game_eval`, esecuzione di codice arbitrario nel gioco in esecuzione.
4. La regola di progetto richiede un problema concreto prima di una dipendenza. Oggi non esiste.

**Trigger per riaprire la valutazione** (uno solo e sufficiente):

- serve ispezionare o interrogare lo stato di un **gioco in esecuzione** durante il debug (previsto in Fase 8);
- il proprietario vuole vedere le modifiche comparire **live nel suo editor aperto**;
- compare un task ripetitivo nell'editor che il canale file + CLI non copre.

In quel caso: valutare per primo `tugcantopaloglu/godot-mcp` perche non impone l'edizione .NET, installarlo in un branch isolato, provarlo su operazioni reversibili e misurarne l'affidabilita prima di dichiararlo canale standard.

## L'editor grafico per il proprietario

L'installazione include **l'editor completo**, non una versione solo headless. Il canale testuale usato dagli agenti non lo sostituisce e non lo limita: sono due viste sugli stessi file.

### Aprire il progetto

| Modo | Comando o azione |
|---|---|
| Elenco progetti (project manager) | `godot` senza argomenti |
| Aprire direttamente questo progetto | `godot --path <cartella del progetto> --editor` |
| Dall'esplora file | doppio clic su `project.godot` |

Alla prima apertura il progetto va importato una volta; da quel momento compare nell'elenco del project manager. Verificato il 3 ottobre 2026: apertura, import ed uscita completati senza errori.

### Convivenza con gli agenti

Godot rileva le modifiche esterne ai file e ricarica da solo, quindi l'editor puo restare aperto mentre un agente lavora. Unico vincolo pratico:

> non tenere aperta **e con modifiche non salvate** la stessa scena su cui un agente sta lavorando, per non sovrascrivere il suo lavoro al salvataggio.

Vincolo nettamente piu leggero del precedente "un solo autore per volta sull'Editor" imposto dal flusso Unreal.

Un agente che sta per modificare una scena lo dichiara, cosi il proprietario sa cosa non toccare in quel momento.

### File generati dall'editor

Verificato aprendo il progetto:

- **`.godot/`** — cache di import, shader e editor. **Va ignorata in Git**, e rigenerabile e cambia a ogni apertura.
- **`*.uid`** — identita stabile di script e risorse, generata accanto a ogni file. **Va versionata**: serve a Godot per mantenere i riferimenti quando un file viene spostato o rinominato.

## Ciclo di lavoro predefinito

1. L'agente modifica script, scene o risorse come file di testo.
2. `--check-only` sugli script toccati.
3. Esecuzione headless e lettura dei marker su stdout.
4. Quando il cambiamento e visivo: run con finestra, cattura PNG, ispezione diretta dell'immagine.
5. Diff Git leggibile riga per riga, incluse le scene.
6. Il proprietario valuta il risultato, non il procedimento.
