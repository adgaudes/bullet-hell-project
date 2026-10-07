# Ciclo giorno/notte, tappa 1 — piano di implementazione

**Stato:** piano scritto il 7 ottobre 2026 senza Godot a disposizione (solo lettura del codice). Attua la sezione 10 di `DAY_NIGHT_SPEC.md` (D-058) per la tappa 1, "notte giocabile". I lampioni (tappa 2) restano fuori; dove una scelta di oggi li condiziona e segnalato.

Scopo del documento: rendere la sessione che implementa puramente esecutiva. Ogni passo dice file, funzioni, segnali, valori e test. I punti di aggancio citati (nomi di funzioni e righe) sono stati verificati nel codice al commit `ad99f14`.

## 0. Punti di aggancio verificati

| Cosa | Dove | Nota |
|---|---|---|
| Orologio del livello | `ArenaRun.elapsed`, avanzato in `_physics_process` (`arena_run.gd`) | ferma con `is_over` |
| Argomenti da riga di comando | `ArenaRun._boss_call_from_command_line()` (statica, legge `--boss-at=`) | stesso schema per `--night-at=` |
| Tuning della run | `RunTuning` (`run_tuning.gd`), istanza `resources/tuning/run_default.tres` | i nodi copiano i valori, mai scrivere la risorsa |
| Sole e ambiente | `OvergrownArena._add_sun()` crea `DirectionalLight3D` **`SunLight`** (energia 1,4, colore `SUN_COLOR`); `_add_environment()` crea **`WorldEnvironment`** (ambiente: luce ambiente 0,5, cielo procedurale, nebbia di profondita, SSAO, glow) | entrambi figli di `District`, ricreati da `rebuild()`: cercarli dopo `_ready` e di nuovo se il distretto si ricostruisce |
| Movimento dei nemici | `EnemyDirector._move_enemies()`: `speed := tuning.enemy_speed * enemy.speed_scale`, penalita Lowered, salto dei `self_driven` | i nemici in commissione (`has_errand`) seguono un altro ramo, ma lo stesso calcolo di velocita |
| Danno da contatto | `EnemyDirector._apply_contacts()`: `player.take_damage(tuning.contact_damage)` | un solo punto |
| Materiali dell'orda | `EnemyDirector._ready()`: `_base_material` e `_runner_material` da `ActorModel.paint_material(colore, emissione)`; lo shader `actor_paint.gdshader` emette sulle facce con `UV.x = 1` (visiera) | gli "occhi" esistono gia: e la visiera emissiva; di notte basta alzare `emission_energy` |
| Carte di level-up | `UpgradeCatalog.all()`; effetti in `ArenaRun.apply_upgrade()` (`match id`); `RunProgression.has_companion` filtra `requires = "companion"` | ordine e pesi delle rarita in `RunProgression` |
| HUD | `RunHud._ready()` costruisce tutto da codice; riga superiore `HBoxContainer` con livello, tempo, abbattuti; `set_time()` | aggiungere l'indicatore nella riga superiore, non in coordinate fisse |
| Audio | `SfxLibrary.IDS` + `_synthesize(id)`; `RunAudio.SOUND_SETTINGS`; segnali collegati in `RunAudio._connect_signals()` | `boss_warning` e il modello di suono "annuncio" |
| Suite di test | `tests/*_tests.gd`, `extends SceneTree`, `_initialize()` con `Engine.physics_ticks_per_second = 60`, `_check()`, `PROTOTYPE01_TESTS PASS|FAIL` | il gate esegue ogni file in `godot/tests/` |
| Simulatore | `tests/tools/simulate_runs.gd`: legge `--boss-at`, bot `passive/novice/kiter/scrapper`, righe `PROTOTYPE01_SIM` | aggiungere `--no-night` |
| Bagliori gia presenti | `XpField._material` emissivo (1,2); `ScrapField._material` **non** emissivo; `flow_mark.gdshader`; anteprima del tool in `TerrainGrid` (`DIG_PREVIEW_COLOR`...) | sezione 6 della specifica |

Trappole note da rispettare (da `GODOT_WORKFLOW.md`): nuova `class_name` invisibile a `--check-only` finche non si aggiorna la cache (`godot_console --headless --path godot --editor --quit`); `add_child` su un fratello durante il `_ready` della scena va differito; non mettere in pausa a meta passo fisico; gli autoload non esistono in `--check-only`.

## 1. Tuning (`run_tuning.gd`)

Nuovo gruppo `Night`, valori della specifica:

```gdscript
@export_group("Night")
## Secondi di livello all'inizio del tramonto. 0 = ciclo spento: il livello resta diurno.
@export var night_start_seconds := 270.0
@export var dusk_seconds := 45.0
@export var night_dark_speed_scale := 1.35
@export var night_dark_contact_bonus := 1
@export var torch_radius := 6.0
@export var beacon_radius := 11.0
## Crescita per livello delle carte `torch_range` e `beacon_range`.
@export var torch_radius_per_level := 1.5
@export var beacon_radius_per_level := 2.0
```

`run_default.tres` non cambia (prende i default). Nessun valore numerico nei nodi.

## 2. `LightField` (`scripts/run/light_field.gd`, `RefCounted`, `class_name LightField`)

Logica pura, testabile in headless, senza nodi obbligatori.

```gdscript
func add_source(node: Node3D, radius: float) -> int      # id crescente da 1
func set_radius(id: int, radius: float) -> void
func radius_of(id: int) -> float
func remove_source(id: int) -> void
func is_lit(world: Vector3) -> bool                      # planare: ignora Y
func source_count() -> int
```

- Memorizza `{node, radius}` per id in un `Dictionary[int, Dictionary]`; `is_lit` confronta `distance_squared` planare con `radius * radius`.
- Un `node` non piu nell'albero (`is_instance_valid` falso o `not is_inside_tree()`) conta come spento, senza errori: serve quando il compagno manca (scene senza compagno) o un lampione viene abbattuto (tappa 2).
- Costo: con 3 sorgenti e 70 nemici sono 210 confronti per passo, trascurabile. Non ottimizzare.

## 3. `DayNightCycle` (`scripts/run/day_night_cycle.gd`, `Node`, `class_name DayNightCycle`)

Nodo `DayNightCycle` in `arena_run.tscn`, figlio di `ArenaRun`, **prima** di `Run` nell'ordine dei figli (riceve il tempo da `ArenaRun`, non ha `_physics_process` proprio).

```gdscript
signal phase_changed(phase: Phase)
enum Phase { DAY, DUSK, NIGHT }
@export var district: Node3D                     # OvergrownArena / RuinsDistrict
var phase := Phase.DAY
var night_factor := 0.0                           # 0 giorno, 1 notte
var night_start_seconds := 0.0                    # copiati da ArenaRun dal tuning
var dusk_seconds := 45.0

func advance(elapsed: float) -> void              # chiamato da ArenaRun ogni passo
func seconds_to_dusk(elapsed: float) -> float     # max(0, night_start - elapsed); INF a ciclo spento
func is_enabled() -> bool                         # night_start_seconds > 0
```

- `advance()` calcola la fase dal tempo: `DAY` se `elapsed < night_start`, `DUSK` fino a `night_start + dusk`, poi `NIGHT`. `night_factor = clamp((elapsed - night_start) / dusk, 0, 1)` (0 a ciclo spento). Emette `phase_changed` solo al cambio e stampa `PROTOTYPE01_NIGHT_PHASE DAY|DUSK|NIGHT time=%.1f`.
- Resa: alla prima chiamata con `district` valido cerca `SunLight` e `WorldEnvironment` con `get_node_or_null` e **legge** il profilo giorno dai valori correnti (energia e colore del sole, `ambient_light_energy`, `ambient_light_color`, colori del cielo, `fog_light_color`). Il profilo notte e un insieme di costanti nel file:

| Parametro | Giorno (letto) | Notte |
|---|---|---|
| sole, energia | 1,4 | 0,12 |
| sole, colore | `SUN_COLOR` dorato | `Color(0.55, 0.62, 0.85)` (luna fredda) |
| luce ambiente, energia | 0,5 | 0,16 |
| luce ambiente, colore | caldo | `Color(0.32, 0.36, 0.5)` |
| cielo, `sky_top_color` | azzurro | `Color(0.03, 0.04, 0.09)` |
| cielo, `sky_horizon_color` | chiaro | `Color(0.10, 0.11, 0.18)` |
| nebbia, `fog_light_color` | chiara | `Color(0.08, 0.09, 0.14)` |

  Interpola ogni valore con `lerp(giorno, notte, night_factor)` **solo quando `night_factor` cambia** (confronto con l'ultimo applicato): di giorno e di notte piena non tocca nulla. Non spegne mai le ombre del sole. Le energie restano sopra zero: sezione 6 della specifica, "sagome e forma del terreno".
- Se il distretto si ricostruisce (`rebuild()` ricrea i nodi), i riferimenti cadono: `advance()` li ricerca quando `is_instance_valid` fallisce e riapplica il fattore corrente. Nessun segnale nuovo nel distretto.
- Non conosce nemici, `LightField` ne HUD.

## 4. `ArenaRun` (`arena_run.gd`)

- Nuovi membri: `@export var day_night: DayNightCycle`, `var light_field := LightField.new()`, `var torch_light_id := 0`, `var beacon_light_id := 0`, `var torch_radius := 0.0`, `var beacon_radius := 0.0`, `var _torch: OmniLight3D`, `var _beacon: OmniLight3D`, `signal night_phase_changed(phase)` (rilancio per HUD e audio, cosi non dipendono dal nodo).
- `_ready()`: `day_night.night_start_seconds = _night_start_from_command_line(tuning.night_start_seconds)`; `day_night.dusk_seconds = tuning.dusk_seconds`; `torch_radius = tuning.torch_radius`; `torch_light_id = light_field.add_source(player, torch_radius)`; se `companion != null`, lo stesso per il faro. `director.light_field = light_field`. Collegare `day_night.phase_changed` a `_on_night_phase_changed`, che imposta `director.night_active = (phase == NIGHT)`, aggiorna l'HUD e rilancia il segnale.
- `_physics_process()`: dopo `elapsed += delta`, `day_night.advance(elapsed)`; poi `hud.set_day_phase(day_night.phase, day_night.seconds_to_dusk(elapsed))` (solo quando cambia il secondo intero, come `set_time`); infine `_update_game_lights()`.
- `_update_game_lights()`: crea le due `OmniLight3D` alla prima chiamata (`_torch` figlia di `player`, `_beacon` figlia di `companion`, `add_child.call_deferred` se in `_ready`, altrimenti diretto; posizione `(0, 1.6, 0)`; `shadow_enabled = false` per la torcia, per il faro vero solo se `benchmark_arena.gd` lo consente, default falso); ogni passo `light_energy = 2.2 * night_factor` e `omni_range = raggio logico * 1.15` (bordo percepito sul raggio logico, da tarare in cattura); a `night_factor = 0` le luci sono spente (`visible = false`) e costano zero. I nodi delle luci li possiede `ArenaRun`, non `PlayerCharacter` e `Companion`: le scene `player.tscn` e `companion.tscn` non cambiano.
- `apply_upgrade()`: due rami nuovi:

```gdscript
&"torch_range":
    torch_radius = tuning.torch_radius + tuning.torch_radius_per_level * new_level
    light_field.set_radius(torch_light_id, torch_radius)
&"beacon_range":
    beacon_radius = tuning.beacon_radius + tuning.beacon_radius_per_level * new_level
    light_field.set_radius(beacon_light_id, beacon_radius)
```

- `_night_start_from_command_line(default)`: come `_boss_call_from_command_line` con prefisso `--night-at=`. Il menu iniziale (`main_menu.gd`) considera `--boss-at=` e `--seed=` come `--autostart` implicito: aggiungere `--night-at=` allo stesso elenco.
- `restart()` e `return_to_menu()` non cambiano: le luci sono figlie di nodi della scena e muoiono con lei.

## 5. `EnemyDirector` (`enemy_director.gd`)

- Nuovi membri: `var light_field: LightField`, `var night_active := false`, contatore `var dark_contacts := 0` (per i test e la simulazione).
- Funzione pura `func is_in_dark(world: Vector3) -> bool: return night_active and light_field != null and not light_field.is_lit(world)`.
- `_move_enemies()`: nel ramo dei nemici non `self_driven` e **senza commissione**, dopo `var speed := tuning.enemy_speed * enemy.speed_scale`: `if is_in_dark(pos): speed *= tuning.night_dark_speed_scale`. I nemici in commissione restano come sono (specifica, sezione 5).
- `_apply_contacts()`: `var damage := tuning.contact_damage; if is_in_dark(enemy.global_position): damage += tuning.night_dark_contact_bonus; dark_contacts += 1`. Vale anche per i portatori; il Demolitore non passa di qui (ha il suo contatto in `demolisher.gd`): invariato come richiesto.
- Visiera: `_base_material` e `_runner_material` sono condivisi dall'orda; di notte `set_night(factor)` imposta `emission_energy = lerp(2.0, 6.0, factor)` sul primo e `lerp(3.0, 7.0, factor)` sul secondo, chiamata da `ArenaRun` solo quando `night_factor` cambia. Nessun materiale nuovo, nessun costo per nemico.
- Con `light_field == null` o `night_active == false` tutto resta identico a oggi: e la garanzia di regressione.

## 6. Bagliori (sezione 6 della specifica)

- `ScrapField._material`: `emission_enabled = true`, `emission = SCRAP_COLOR`, `emission_energy_multiplier = 0.6`. Di giorno la differenza e minima (verificare in cattura); in alternativa esporre `set_glow(factor)` e alzarla solo di notte.
- `XpField`: gia emissivo, invariato.
- `flow_mark.gdshader` e anteprima del tool: controllare in cattura notturna; se non si leggono, aggiungere `EMISSION` nello shader delle impronte e un `emission` sul materiale dell'anteprima. Non anticipare la modifica senza la cattura.

## 7. HUD (`run_hud.gd`)

- Nella riga superiore, fra tempo e abbattuti: `_day_label: Label` con testo `"☀ 4:30"` (tempo al tramonto, formato `format_time`) di giorno, `"☀ cala"` al tramonto, `"☾ notte"` di notte. Se il font di progetto non ha i glifi sole e luna, usare `GIORNO`/`NOTTE` e un quadratino colorato: verificare in cattura, non assumere.
- `set_day_phase(phase: int, seconds_to_dusk: float)`; con ciclo spento (`seconds_to_dusk` infinito) la label e nascosta.
- Avviso "CALA LA NOTTE" riusando `_boss_warning` (stessa posizione, colore `Color(0.6, 0.65, 1.0)`) per 4 secondi all'inizio di `DUSK`, poi "E NOTTE" per 3 secondi all'ingresso in `NIGHT`: `show_night_notice(text, seconds)` con un timer interno; se l'annuncio del boss e visibile ha la precedenza e l'avviso notte viene saltato (il boss arriva a 12:00, il tramonto a 4:30: nel livello di oggi non si sovrappongono, ma `--boss-at` e `--night-at` possono farlo).

## 8. Audio (`sfx_library.gd`, `run_audio.gd`)

- Due id nuovi in `IDS`: `&"dusk"` (campana lontana: `Wave.SINE` 220 Hz con decadimento lungo, 1,6 s, piu un'armonica a 440 Hz) e `&"nightfall"` (colpo secco grave: `Wave.SOFT_SQUARE` 70 Hz, 0,35 s, piu rumore breve).
- `SOUND_SETTINGS`: `&"dusk": [-6.0, 0.0, 1.0]`, `&"nightfall": [-4.0, 0.0, 1.0]`.
- `RunAudio._connect_signals()`: `run.night_phase_changed.connect(_on_night_phase)` che suona `dusk` per `DUSK` e `nightfall` per `NIGHT`.
- `audio_tests.gd` conta gia gli id di `SfxLibrary.IDS`: aggiornare il numero atteso se e cablato (verificare).

## 9. Carte (`upgrade_catalog.gd`)

```gdscript
{id = &"torch_range", name = "Torcia", category = &"character", rarity = Rarity.COMMON, max_level = 3,
    requires = "", text = "La tua luce arriva 1,5 metri piu lontano."},
{id = &"beacon_range", name = "Faro", category = &"companion", rarity = Rarity.UNCOMMON, max_level = 3,
    requires = "companion", text = "Il faro del compagno illumina 2 metri piu lontano."},
```

Offerte anche di giorno (specifica, sezione 8). `run_progression_tests.gd` potrebbe contare le carte eleggibili: verificare e aggiornare i numeri attesi.

## 10. Simulatore (`simulate_runs.gd`)

- Nessuna opzione nuova per spegnere la notte: `ArenaRun._ready` legge il tuning subito, quindi il simulatore non puo modificarlo in tempo; si usa `-- --night-at=0`, che `ArenaRun` legge gia. Documentarlo nell'intestazione del file e in `GODOT_WORKFLOW.md`.
- Nella riga `PROTOTYPE01_SIM` aggiungere `night_phase_at_end`, `dark_contacts` (dal direttore) e `seconds_in_dark` (campionato ogni decisione del bot con `director.is_in_dark(player.global_position)`).
- I bot non cercano la luce: il kiter di notte prendera piu danni. E voluto: misura il "primo tentativo troppo duro" del rischio 1. Un bot che resta nel faro e lavoro della tappa 2.

## 11. Test (`tests/day_night_tests.gd`)

Suite nuova, stessa struttura di `boss_tests.gd` (istanzia `arena_run.tscn`, `spawning = false`). Casi:

1. **Fasi e tempi**: con `night_start_seconds = 270` e `dusk_seconds = 45`, `advance(0)` DAY, `advance(269.9)` DAY, `advance(270)` DUSK con `night_factor` 0, `advance(292.5)` 0,5, `advance(315)` NIGHT con 1; `phase_changed` emesso due volte in tutto.
2. **Ciclo spento**: `night_start_seconds = 0` → sempre DAY, `night_factor` 0, `seconds_to_dusk` infinito, nessuna emissione, sole invariato dopo 1000 s.
3. **`--night-at`**: `_night_start_from_command_line(270.0)` senza argomento restituisce 270 (il test non puo passare argomenti: testare la statica con `OS.get_cmdline_user_args()` vuoto e, se il gate lo consente, un secondo processo non serve).
4. **`LightField`**: dentro (5 m con raggio 6), bordo (6,0 dentro, 6,01 fuori), fuori, sorgente che si muove (spostare il nodo e rifare la domanda), `set_radius`, `remove_source`, nodo liberato (`queue_free` + frame) conta come spento.
5. **Velocita al buio**: nemico a 20 m dal giocatore e dal compagno, `night_active = true`: la velocita planare dopo 60 passi e `enemy_speed * 1.35` entro il 3%; stesso nemico a 3 m dal giocatore (dentro la torcia): `enemy_speed`. Di giorno (`night_active = false`) a 20 m: `enemy_speed`.
6. **Danno al buio**: nemico portato a contatto fuori dalla luce di notte: il giocatore perde `contact_damage + 1`; dentro la luce `contact_damage`; di giorno `contact_damage`. Serve `player.invulnerability_seconds = 0` fra i casi o un giocatore nuovo.
7. **Commissione**: nemico con `set_errand()` al buio di notte: velocita invariata (`enemy_speed`), danno con bonus.
8. **Demolitore**: `boss_speed` e `boss_contact_damage` invariati di notte fuori dalla luce (riusare `_place_boss` di `boss_tests.gd`).
9. **Carte**: `apply_upgrade(&"torch_range", 1)` porta `light_field.radius_of(torch_light_id)` a 7,5; `beacon_range` livello 2 a 15; `RunProgression.eligible()` senza compagno non offre `beacon_range`.
10. **Resa**: dopo `advance` in NIGHT, `SunLight.light_energy` e `ambient_light_energy` sotto i valori di giorno e sopra zero; le `OmniLight3D` esistono, sono visibili e con `omni_range` coerente con i raggi; a DAY sono invisibili.
11. **HUD e audio**: `set_day_phase` cambia il testo; `RunAudio.play_counts` contiene `dusk` e `nightfall` una volta ciascuno dopo il ciclo.

Regressione: tutte le suite esistenti restano verdi senza modifiche, perche nessuna supera i 270 s di `elapsed` (verificato: `economy_tests.gd` imposta `_director.elapsed`, non `_run.elapsed`, oltre quel valore; `boss_tests.gd` anticipa `boss_call_at`). Se una suite futura spinge `_run.elapsed` oltre 270 s senza volere la notte, imposta `day_night.night_start_seconds = 0`.

## 12. Catture e misura

- `tests/tools/capture_night.gd`: giorno (0:30), tramonto a meta (`--night-at=5`, dopo 27 s), notte dentro il faro, notte fuori dalla luce con 20 nemici attorno, notte con `torch_range` 3 e `beacon_range` 3. Output `output/night/`. Modello: `capture_boss.gd`.
- `benchmark_arena.gd`: opzione `--night` che porta `elapsed` oltre il tramonto prima della misura; confrontare `director_ms` e, con finestra, i frame al secondo. Soglia: nessun peggioramento oltre il 10% su PC, altrimenti spegnere le ombre del faro.

## 13. Ordine dei commit

1. `RunTuning` + `LightField` + test del `LightField` (verde senza toccare la scena).
2. `DayNightCycle` + nodo in scena + `ArenaRun` (ciclo, luci, `--night-at`) + test fasi e resa.
3. `EnemyDirector` (buio, velocita, danno, visiera) + test 5-8.
4. Carte + HUD + audio + test 9-11.
5. Simulatore, catture, benchmark; aggiornamento di `GODOT_WORKFLOW.md` (comandi), `MIGRATION_STATUS.md`, `PROJECT_ROADMAP.md`, `DECISIONS.md` (stato di D-058 → implementata tappa 1), `INDEX.md`.

Ogni commit passa il gate (`Invoke-GodotChecks.ps1`). Il quarto commit tocca `arena_run.tscn`: avvisare il proprietario prima, come da regola sull'editor aperto.

## 14. Decisioni prese qui (da confermare o ribaltare)

- Le luci visive sono create e possedute da `ArenaRun`, non da `PlayerCharacter` e `Companion`: la specifica le colloca nelle due scene, ma tenerle nel coordinatore evita di insegnare a due attori una cosa che non li riguarda e lascia `player.tscn` e `companion.tscn` intatti. Se il proprietario preferisce vederle nell'editor, si spostano nelle scene con `light_energy = 0` e `ArenaRun` le accende.
- Gli occhi emissivi non sono un materiale nuovo: la visiera del modello `scavenger` e gia emissiva; di notte si alza l'energia dei due materiali condivisi.
- L'indicatore sole/luna sta nella riga superiore dell'HUD, non in un angolo nuovo.
- `--night-at=0` sostituisce un'opzione `--no-night` del simulatore.

## 15. Cosa lascia alla tappa 2

`LampField`, modalita `LAMP` in `TerrainState.ToolMode`, terza anteprima in `TerrainGrid.update_preview()`, abbattimento dal Demolitore, lampioni sulla `RunMap`, bot che li compra. `LightField` e gia pronto a riceverli: `add_source` con un nodo e il raggio `lamp_light_radius`.
