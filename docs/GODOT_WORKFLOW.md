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
godot_console --headless --path godot --fixed-fps 60 --script res://tests/live_rebuild_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/input_events_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/companion_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/run_progression_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/arena_run_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/path_field_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/audio_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/workshop_tests.gd
```

Piu semplice: `tools/godot/Invoke-GodotChecks.ps1` esegue tutte le suite presenti in `godot/tests/`.

`--fixed-fps 60` rende ogni frame un passo fisico da 1/60 s: risultati deterministici. Esito su stdout (`PROTOTYPE01_TESTS PASS|FAIL`) ed exit code 0/1. Trappola verificata: in headless la posizione del cursore del viewport non segue gli eventi mouse simulati; testare la logica sulla posizione schermo esplicita.

Trappola verificata: `CollisionShape3D.set_deferred("disabled", ...)` lascia la forma attiva per un frame; se applicato in costruzione spinge via i corpi sovrapposti. In costruzione impostarlo direttamente, a runtime differito.

Trappola verificata: `InputEvent.is_action_pressed()` e vero per **ogni** `InputEventJoypadMotion` sopra la dead zone, e un grilletto analogico ne invia uno a ogni variazione. Per azioni "una volta per pressione" serve il rilevamento del fronte (vedi `PlayerCharacter.STARTED_ACTIONS`). Il terzo argomento `exact_match = true` blocca l'azione se e premuto un modificatore. I test che usano solo `InputEventAction` o `Input.action_press` non vedono questi casi: `tests/input_events_tests.gd` usa eventi joypad e tasti reali.

Trappola verificata: nella numerazione Godot dei pulsanti joypad il **4 e Back/View**, non il dorsale sinistro (che e il 9, `JOY_BUTTON_LEFT_SHOULDER`). Usare le costanti `JOY_BUTTON_*` per controllare `project.godot`.

Trappola: il progetto usa 120 passi fisici al secondo; i test fissano `Engine.physics_ticks_per_second = 60` in `_initialize` perche i valori attesi sono calcolati a 60 Hz.

Trappola verificata: **il nome globale di un autoload non esiste** in `--check-only` ne nei test con `--script` (le scene precaricate dallo script di test si compilano prima che gli autoload siano registrati). Uno script che scrive `GameSettings.x` non compila e il test resta appeso senza `quit()`. Raggiungere l'autoload a runtime con `get_node("/root/GameSettings")`, tipizzato con la `class_name` `GameSettingsService`.

Trappola verificata: in Godot 4.7 le azioni predefinite **`ui_accept` e `ui_cancel` non hanno pulsanti joypad**. Il progetto le ridefinisce con A e B: senza, i menu non si confermano col controller.

Trappola verificata (6 ottobre 2026): in `--headless` il renderer fittizio **non conserva colori e dati custom dei MultiMesh** (`get_instance_color` e `get_instance_custom_data` restituiscono zero; le trasformazioni si). Un test headless puo verificare `use_colors`, `use_custom_data` e i conteggi, non i valori: per quelli serve una cattura con finestra.

Trappola verificata (6 ottobre 2026): un `CPUParticles3D` creato da codice va **posizionato prima di `add_child`** (`top_level = true` e `position`): con `global_position` impostata dopo l'ingresso nell'albero i frammenti di un'emissione `one_shot` partono dall'origine. Nessun test headless lo vede: l'ha mostrato una cattura.

Trappola verificata (6 ottobre 2026): in un **worktree nuovo** i modelli `.glb` sono puntatori Git LFS: il primo `--editor --quit` fallisce l'import e scrive `valid=false` nei `.glb.import`. Prima `git lfs checkout`, poi l'import; se i `.import` sono stati sporcati, ripristinarli da Git. In headless l'audio usa un driver fittizio: i test contano le riproduzioni (`RunAudio.play_counts`), non possono ascoltarle.

Trappola verificata (4 ottobre 2026): una **nuova `class_name`** non e visibile a `--check-only` ne ai test finche la cache delle classi globali non e aggiornata (`Could not find type ...`). Aggiornarla con `godot_console --headless --path godot --editor --quit`, oppure aprendo l'editor una volta.

Asset Blender (D-037): `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_arena_assets.py -- [nome ...]`, poi `godot_console --headless --path godot --editor --quit` per importare i `.glb` (genera i `.import`, da versionare). Le righe `ASSET_EXPORTED` riportano misure e triangoli.

Catture multiple dell'arena (vista di gioco, panoramica, nord, ovest, nord-est), con finestra reale: `godot_console --path godot --resolution 1280x800 --script res://tests/tools/capture_arena.gd -- --out=../output/arena`. Gli script in `tests/tools/` non sono suite: il gate non li esegue.

Benchmark del campo di percorso su un'arena sintetica grande (D-039): `godot_console --headless --path godot --fixed-fps 60 --script res://tests/tools/benchmark_path_field.gd -- --extent=240 --walls=400 --window=64` (righe `BENCH`; con `extent` fino a 240 confronta anche il campo intero).

Catture della run (combattimento e level-up): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_run.gd -- --out=../output/run`.

Catture dell'arena grande (D-042: partenza, panoramica dall'alto di tutta l'arena senza nebbia, combattimento dopo un minuto): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_district.gd -- --out=../output/district`. Con `--visit=x,z` (ripetibile) salva anche la vista di gioco col giocatore in quel punto (`visit_0.png`, ...) ed esce senza la cattura del combattimento: utile per guardare da vicino rovine e oggetti.

Catture dell'Officina (fine livello col pulsante, catalogo): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_workshop.gd -- --out=../output/workshop`. Sotto `--script` l'autoload `PlayerProfile` non legge ne scrive `user://profile.cfg`: test e catture impostano il profilo in memoria.

Trappola verificata (6 ottobre 2026): `add_child()` su un nodo fratello **durante il `_ready` della scena** fallisce ("Parent node is busy setting up children") e il nodo resta fuori dall'albero senza altri sintomi. Usare `add_child.call_deferred()`.

Catture del boss (annuncio, rottamatore carico e cantiere, Demolitore con barricata, vittoria): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_boss.gd -- --out=../output/boss`. Per giocare subito il boss: `godot --path godot -- --boss-at=60`.

Benchmark dell'arena grande (costruzione, celle e collisioni, costo per passo del direttore dei nemici e dell'arma, draw call con finestra): `godot_console --path godot --resolution 1280x800 --script res://tests/tools/benchmark_arena.gd -- --enemies=70` (righe `PROTOTYPE01_ARENA_BENCH`). In `--headless` il monitor `TIME_PHYSICS_PROCESS` include l'attesa del loop e non e attendibile: fidarsi delle misure dirette `director_ms`, `weapon_ms`, `solve_ms`.

Trappola verificata (5 ottobre 2026): in un test `extends SceneTree`, la scena aggiunta in `_initialize` riceve `_ready` solo al primo frame, e `_ready` riattiva il passo fisico dei nodi che definiscono `_physics_process`. Un `set_physics_process(false)` va quindi chiamato **dopo** aver atteso almeno un frame.

Il gate (`Invoke-GodotChecks.ps1`) ha un timeout di 300 s per processo: un test appeso risulta FAIL con exit 124 invece di bloccare tutto.

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

### Export

Verificato il 3 ottobre 2026. Template in `%APPDATA%\Godot\export_templates\4.7.2.stable\` (installati solo Windows e Linux x86_64 dal `.tpz` ufficiale, SHA-512 verificato). Preset in `godot/export_presets.cfg`.

```bash
godot_console --headless --path godot --export-release "Windows Desktop" ../LocalBuilds/Prototype01-Godot-Win64/Prototype01.exe
godot_console --headless --path godot --export-release "Linux" ../LocalBuilds/Prototype01-Godot-Linux/Prototype01.x86_64
```

La cartella di destinazione deve esistere. La build Windows scrive i `print()` su stdout anche senza wrapper console: lo smoke test della build funziona (`Invoke-GodotChecks.ps1 -Executable`).

## Non ancora verificato

Da confermare quando servira, senza darlo per acquisito:

- `--import` (reimport headless degli asset);
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
