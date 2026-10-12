# Mappa per la migrazione del terreno: dalle celle al rilievo continuo

> Rilevazione del 12 ottobre 2026 (agente di esplorazione, letto e conservato da Claude) a supporto della spec di migrazione decisa in D-082. Non e un piano: elenca cio che esiste, chi dipende dalla griglia a celle e con quali concetti. Numeri di riga validi al commit `0297fb5`; verificarli prima di usarli.

**Sintesi.** Ogni sistema di gioco fuori da `scripts/terrain/` lavora in coordinate di cella, attraverso una quindicina di chiamate alla griglia e tre segnali. Solo le celle Raised hanno fisica; il pavimento calpestabile e un unico box statico a y = 0. Lo spike non ha nessuno dei concetti di gioco su cui si regge il livello vero: niente collisione fisica, niente ostacoli statici, niente eventi o segnali per modifica, niente stati discreti o protetti.

## 1. API pubbliche

### A. Lo spike (rilievo continuo), non usato dal livello vero

**`HeightTerrain`** (`godot/scripts/spikes/height_terrain.gd`, `Node3D`)
- Segnale `changed`: senza regione, emesso a ogni pennellata e al caricamento.
- Costanti: `CELL := 0.5` m (passo dei vertici), `MIN_HEIGHT -2.0`, `MAX_HEIGHT 3.5`, salvataggio `HTER` versione 1.
- Dati: `size_m` (96, centrato sull'origine), `resolution`, `heights: PackedFloat32Array` pubblico (scritto direttamente da `terrain_spike.gd`), `_base` privato (rilievo "naturale"; lo shader colora la differenza).
- Metodi: `build()` (mesh piana, `Image` RGF, `ImageTexture`, `PlaneMesh` con `custom_aabb`), `half_extent()`, `commit_base()`, `height_at(point)` bilineare, `normal_at(point)`, `sculpt(center, radius, amount)` (pennello `(1-d^2)^2`, negativo scava, ritorna il volume firmato in m3), `level(center, radius, target_height, strength)`, `can_step(from, to, max_grade)` (in discesa sempre, in salita se dislivello <= pendenza x corsa), `slide_move(from, to, max_grade)` (limita ai bordi, prova il passo intero poi gli scorrimenti per asse, ritorna un punto gia sulla superficie), `save_heights(path)` (zstd, `.tmp` + rinomina), `load_heights(path)` (controlla magic, versione, risoluzione, dimensione).
- `_brush` aggiorna l'immagine per pixel ma `_process` ricarica l'intera texture (U-11). **Nessuna forma di collisione.**

**`HeightFlowField`** (`godot/scripts/spikes/height_flow_field.gd`, `RefCounted`)
- `CELL := 1.5`, `SUBSTEPS 3`, costi 10/14. Dati `side`, `next`, `distance` (metri, -1 irraggiungibile).
- `rebuild(terrain, goal, max_grade, window_m)` (Dijkstra a secchi dall'obiettivo, pendenza vertice per vertice con la regola di `slide_move`, finestra opzionale U-02), `cell_of`, `cells_apart`, `center_of`, `direction_at`.
- Nessun ostacolo statico, nessun concetto di "bloccato" oltre la pendenza.

**`TerrainSpike`** (`godot/scripts/spikes/terrain_spike.gd`): `Mode { DIG, RAISE, LEVEL }`; costanti `PLAYER_HEIGHT 0.88`, `MAX_GRADE 0.8`, `BRUSH_RADIUS 2.4`, `SCULPT_RATE 2.2`, `LEVEL_RATE 5.0`, `TOOL_REACH 3.6/8.0`, serbatoio terra `SOIL_CAPACITY 60`/`SOIL_START 20`, `ENEMY_COUNT 40`, `FIELD_INTERVAL 0.25`, `FIELD_WINDOW_M 48`, `FIELD_MOVE_CELLS 2`; `brush_target()` (avanti col controller, raggio del cursore col mouse), `apply_brush` (conservazione della terra), `_ground_player()` (dopo `move_and_slide`, priorita fisica 10), `_move_enemies` (modelli nudi con `slide_move`, non `Enemy`), `_shape_landscape()`, F6/F7 salva e carica, sole con 2 split d'ombra.

**Shader** `height_terrain.gdshader`: uniform `height_map` (R quota, G delta da `_base`), `resolution`, `cell`, colori `grass`, `grass_dry`, `mound`, `pit`, `cliff`; spostamento nel vertex, normali dai texel vicini, strati ogni 40 cm. Non usa `surface_tiles.gdshaderinc` ne `ruins_ground.gdshaderinc`.

### B. La griglia a celle

**`TerrainState`** (`terrain_state.gd`): `CellState { LOWERED, NORMAL, RAISED }`, `ToolMode { DIG, RAISE, LAMP }` (LAMP eseguito da `LampField`); `width`, `height`, `protected_cell` (default (0,0)), indice `y*width+x` in assi Unreal; `resize`, `cell_count`, `is_valid`, `is_protected`, `get_state` (NORMAL fuori griglia), `can_apply(cell, mode, raise_blocked)`, `is_occupied_rejection`, `apply(cell, mode)` (un passo: DIG Raised->Normal->Lowered, RAISE l'inverso), `set_state`, `state_name`.

**`TerrainTuning`** (Resource): `MAX_CELLS 201`, `grid_width/height` dispari, `cell_size_cm 240`, `cell_gap_cm 12`, quote 4/12/120 cm, `lowered_speed_penalty_percent 0.5`; ogni setter emette `changed` (rebuild). Istanze in `resources/tuning/`: default 7x7 gap 12, arena 11x11 gap 12, district 85x85 gap 8, railway 51x133 gap 8.

**`TerrainGrid`** (`terrain_grid.gd`, `@tool`, origine al centro)
- Segnali: `cell_changed(cell, state)` (tool, `set_cell_states`, `force_cell_state`), `command_applied(cell, mode, state)` (solo tool e compagno), `rebuilt`.
- Costanti colore delle anteprime (HUD e test); `apply_ground_tiles(material)` statico, usato anche da `OvergrownArena`.
- Export `tuning`, `natural_ground` (true nei due livelli), `plaza_radius`; `raised_color_override` (muro chiodato), `state` (letto direttamente da quasi tutti), `preview_cell`, `last_rebuild_usec`.
- Metodi: `raised_top_y`, `set_protected_cell`, `rebuild`, `update_preview(world, mode, instigator, blocked)`, `hide_preview`, `cell_at(world)`, `cell_state_at(world, fallback)`, `width_extent_cm`, `cell_size_m`, `lowered_speed_penalty`, `presented_cell_count`, `active_collision_count`, `can_apply_at`, `apply_command_at` (log `PROTOTYPE01_TERRAIN_CHANGED/REJECTED/RAISE_OCCUPIED_REJECTED`), `set_cell_states` (layout iniziale, salta le protette), `force_cell_state` (cambio fuori regole, senza `command_applied` quindi senza rottami), `set_raised_tint`/`clear_raised_tint`, `cell_local_position(cell, state)` (centro a **meta** altezza: i consumatori moltiplicano y per 2), `raise_overlaps(cell, body)`, `_would_raise_overlap` (AABB contro `get_collision_aabb()`).
- Fisica: solo le Raised collidono; corpi per blocco 8x8 (`RaisedCells_x_y`, layer 1, figli diretti della griglia). I consumatori riconoscono "e una cella" con `collider.get_parent() == grid`.
- Resa: due MultiMesh `CellsFlat`/`CellsRaised` con `terrain_cell.gdshader` (instance uniform `cell_color`, `natural`, `state_tint`; uniform `batched`, `plaza_radius`, `raised_top`, `cell_pitch`). `_ready` stampa `PROTOTYPE01_TERRAIN_GRID_READY` (richiesto dal gate).

## 2. Consumatori fuori da `scripts/terrain/`

Fatto condiviso: giocatore, nemici, boss e compagno sono `CharacterBody3D` con `move_and_slide`, mask 1, sul box piatto `Ground` di `OvergrownArena._build_ground()` (cima a y = 0). Lowered e Normal sono solo visive (4 e 12 cm); solo le Raised (1,2 m) bloccano movimento, chiodi, raggi e la sfera del pericolo. `auto_weapon.gd` spara un raggio sul layer 1: una Raised blocca anche i colpi del giocatore. `ruins_district.cover_height()` = 0,12 (l'erba sta sulla cima delle Normal).

- **Tool del giocatore** (`player_character.gd`): segnale `terrain_mode_changed`, export `terrain_grid` e `lamp_field`, `terrain_target`, `tool_range_bonus_cm`; rallentamento in Lowered; `_use_terrain_tool` (un passo discreto per pressione; LAMP -> `lamp_field.place_at`; RAISE richiede `companion.can_supply` poi `apply_command_at` e `companion.spend()`); `_toggle_terrain_mode` DIG->RAISE->LAMP (stampa `PROTOTYPE01_TERRAIN_MODE Dig`, atteso dal gate); `_update_terrain_target` (bersaglio a distanza fissa avanti: `terrain_tool_range_cm` 480 + bonus; calcola `blocked`; `update_preview` con box colorato); `get_collision_aabb()`.
- **Campo di percorso** (`navigation/path_field.gd`): cella 1,2 m = meta della cella terreno, allineata (una Raised blocca 2x2); connette `cell_changed` (dirty) e `rebuilt`; `is_walkable` ripiega su `cell_state_at != RAISED`; `_scan_terrain_chunk` cache l'indice di cella; `_scan_chunk` legge gli ostacoli statici dalla fisica escludendo i figli della griglia; `_refresh_blocked` blocca le celle Raised. API usata da altri: `cell_of`, `cell_center`, `is_inside`, `is_walkable`, `cost_at`, `next_waypoint`, `costs`, `cell_size`, `columns`, `half_extent`, `half_z`, `is_ready`, `target`, segnali `solved`/`recentered`. Le Lowered non sono rappresentate (rallentamento applicato dai movers).
- **Impronte dell'orda** (`flow_preview.gd`, D-053): `command_applied` soltanto (ignora `force_cell_state` di proposito); `_ground_y` = cima della cella.
- **Direttore dei nemici** (`enemy_director.gd`): penalita Lowered per nemico (`ignores_lowered` per i saltatori); muro chiodato danneggia chi scivola su un figlio della griglia; spawn e guinzaglio via `path_field`.
- **Rottamatori** (`enemy.gd`): fisica pura contro le Raised, mask 1, `ignores_lowered`.
- **Demolitore** (`demolisher.gd`, D-043/D-045): `grid` assegnato da `arena_run.gd`; `cell_changed`; `_nearest_wall` (scansione quadrata di Raised non barricate); demolizione a contatto (distanza o collisione con figlio della griglia + `cell_at(punto - normale*0.3)` Raised); `_tick_demolition` -> `force_cell_state(NORMAL)`, `wall_demolished(cell)`, `scrap_field.spawn_on_cell`; cantiere su cella NORMAL, marker `cell_size_m*0.7`; `_pick_barricade_cell` (1-3 celle avanti, +-2 di lato, NORMAL), `_cell_is_free` (`can_apply_at` + rottami sulla cella), `_raise_barricade` (`set_raised_tint` + `force_cell_state(RAISED)`), `barricades: Dictionary[Vector2i, bool]`; segnali con celle `wall_demolished`, `barricade_built`, `scrap_delivered`; portatori con `path_field.cost_at`; abbatte i lampioni via `lamp_field`.
- **Trivella** (`driller.gd`, D-066): `ignores_lowered`; mira con sonde a 3/6/9 m (non calpestabile e non Raised = rovina -> waypoint); carica: `cell_at(punta)` Raised -> `_break_wall` (`force_cell_state(NORMAL)`, rottami, STUN con moltiplicatore di danno), NORMAL -> `force_cell_state(LOWERED)` (solco, `cell_drilled`); la carica finisce su una collisione non-griglia. Segnali `cell_drilled`, `wall_broken`, `last_wall`.
- **Compagno** (`companion.gd`): `can_supply`/`can_supply_count` (distanza planare); assistenza contro il pericolo (solo scene Companion Slice) con `cell_at`, `cell_local_position`, `apply_command_at(RAISE)`; naviga col `path_field`.
- **Depositi / `ScrapField`** (`scrap_field.gd`): `bare_ground_yields_scrap` false (D-056); `command_applied` e `cell_changed`; `count_on_cell`, `spawn_on_cell` (cima + `SCRAP_SIZE`), `spawn_on_ground`; rottami solo su DIG Raised->Normal; disseppellimento verso una NORMAL vicina (8 vicini) quando una cella diventa Raised.
- **Lampioni** (`lamp_field.gd`, D-058): `_lamps: Dictionary[Vector2i, ...]`; `can_place(cell)` (valida, non protetta, non Lowered, libera, sotto il tetto), `place_at(world)`, palo sulla cima; rimossi su `cell_changed` della cella e su `rebuilt`; `knock_down_near` planare; segnali `lamp_placed`/`lamp_lost` con celle; `cells()` per mappa e bot.
- **Pericolo** (`terrain_hazard.gd`): solo smoke test, companion slice, ruins arena; corsia da `width_extent_cm`; bloccato dalle Raised con `cast_motion` sul layer 1.
- **`arena_run.gd`**: `set_protected_cell((-1,-1))`, `_initial_terrain = RunMap.snapshot(grid.state)`, `command_applied` -> `_on_terrain_command` (contatori `cells_dug/raised`, detriti sulla cima, upgrade "dig blast" con raggio 2,4 m + 0,8/livello); marker fuori schermo finche una cella degli `offsets` e Raised; boss creati con `grid`; `_check_scale` (cella = `RuinsDistrict.CELL`, estensioni del campo, meta griglia in assi Unreal scambiati); `tool_reach` = +1 cella per livello; `_build_terrain_layout` (per ogni `terrain_features`: `cell_at(center) + offsets`, `set_cell_states`, tinta; log `PROTOTYPE01_TERRAIN_LAYOUT_READY`); `_build_courtyard_walls` senza quartiere; `build_run_map` (griglia, stato iniziale, barricate, edifici, lampioni) e "Celle scavate %d rialzate %d"; `spiked_wall` -> `raised_color_override`; HUD del modo via `terrain_mode_changed`.
- **Terremoto** (`quake_event.gd`, D-075): `length_cells 18`, `cells_per_second 14`, `fault_cells`; `_choose_fault` a passi di `cell_size_m` con `cell_at`; `_shake_cell` (salta invalide/protette, cella del giocatore = danno, corpi entro `cell_size_m*0.9` risparmiati, boss via `raise_overlaps`; LOWERED->NORMAL, NORMAL->uccide i nemici nella cella e RAISED; lampioni entro 0,6 celle); fine -> `flow_preview.show_now()`.
- **Treno** (`train_event.gd`, D-066): `_sweep_cells` (colonna di testa da `cell_at`, righe `+-TRACK_HALF_ROWS`, ogni cella non NORMAL -> `force_cell_state(NORMAL)` + `clear_raised_tint`, niente rottami; lampioni entro 0,6 e rottami entro 0,75 celle rimossi); `_push_out` cerca un atterraggio entro 4 celle non Raised; `is_on_tracks`/`track_half_width` in celle.
- **Piazzola** (`extraction_pad.gd`, D-076): `radius_cells 1` (3x3), `pad_cells`, `is_flat` = tutte valide e NORMAL (nessuna tolleranza di quota), `advance` con `cell_at(player)`, marker `cell_size_m*(2r+1)-0.1`.
- **Quartiere** (`ruins_district.gd`, `@tool`): `CELL := 2.4` (controllato da `_check_scale`); `terrain_features` `{kind, center (XZ mondo agganciato alla cella), state, offsets (assi Unreal), gates, radius, marker, [tint]}`; `snap_to_cell`, `cell_offset_to_world` (x = -Z, y = +X), `feature_centroid`, `_ring_offsets`, `_add_feature`; cortile di partenza (anello Raised, raggio 4), cortili (varianti `three_gates`, `two_gates`, `broken`, `double`), depositi (blocchi Raised 2x2 o 3x3: scavarli produce rottami), trincee (linee Lowered); mappa di occupazione a 1 m; `cover_height 0.12`; `plaza_radius_m`. Base `OvergrownArena`: box del suolo piatto, `apply_ground_tiles`, muri di confine invisibili.
- **Ferrovia** (`railway_district.gd`): 133x51 celle; `TRACK_HALF_ROWS 1`, `TRACK_Z [-CELL, CELL]`, `track_half_width`, `track_cells(grid)`; cortile senza anello sulla fascia; vagoni Raised 2x3 tinti (depositi); trincee parallele.
- **Mappa di fine livello** (`ui/run_map.gd`, D-052): `snapshot`, `changed_cells`, `cell_color(now, before, is_barricade)` (muro/trincea/breccia dagli stati discreti), `render(...)` un pixel per cella, `_pixel_of/_pixel_at` con `cell_local_position` e `cell_size_m`.
- **HUD** (`run_hud.gd`): `set_tool_mode` (solo in LAMP, colore `LAMP_PREVIEW_COLOR`), prompt "Scava o rialza"/"Cambia modo".
- **Audio** (`run_audio.gd`): `command_applied` -> `terrain_raise`/`terrain_dig` (`sfx_library.gd`).
- **Salvataggi**: profilo e impostazioni non salvano terreno; il terreno della run non e persistito; solo lo spike salva le quote. `export_presets.cfg` esclude `scenes/spikes/*` e `scripts/spikes/*`.
- **Bot e strumenti** (`tests/tools/`): `simulate_runs.gd` (penalizza le Lowered, `_tick_lamps` con `cell_at`/`can_place`/`cell_local_position`, `_tick_digging` con `can_apply_at` preferendo le Raised; i bot non tengono la piazzola), `benchmark_arena.gd` (`rebuild`, `set_cell_states`, `cell_count`, `active_collision_count`), catture `capture_extraction/flow/motion/railway/workshop`, `capture_terrain_spike.gd` (`TERRAIN_SPIKE_BENCH`, `--size=204`).

## 3. Suite che toccano griglia o spike (`godot/tests/`)

| Suite | Scena | Cosa esercita |
|---|---|---|
| `terrain_tests` | griglia propria | regole di stato, struttura, collisioni e sovrapposizione, giocatore bloccato da una Raised |
| `terrain_tool_tests` | `smoke_test` | passi Dig/Raise/Lamp su celle esatte, colori e altezza dell'anteprima, cella protetta (0,0), anteprima nascosta fuori griglia |
| `live_rebuild_tests` | - | rebuild al cambio del tuning |
| `slice_b_tests` | `smoke_test` | penalita Lowered; corsia del pericolo |
| `companion_tests` | `companion_slice` | ciclo dei rottami su DIG, rialzo con rottami, assistenza |
| `input_events_tests` | `smoke_test` | un colpo per pressione via `cell_changed` |
| `arena_run_tests` | `arena_run` | mura del cortile, varchi, cortile sigillato, muro che blocca il tiro, Lowered rallenta |
| `district_tests` | `arena_run` | scala 85x85, feature applicate, marker, `active_collision_count`, `presented_cell_count`, `width_extent_cm`, `plaza_radius` |
| `ruins_arena_tests` | `ruins_arena` | `natural_ground` |
| `restyle_tests` | - | legge `CellsFlat`/`CellsRaised` |
| `boss_tests` | `arena_run` | Demolitore: muri, barricate, disseppellimento, cantiere, trincea |
| `driller_tests` | `railway_run` | muro che ferma e stordisce, solco, rovina via percorso |
| `lamp_tests` | `arena_run` | ciclo dei modi, regole, costo, perdita al cambio cella, abbattimento, mappa |
| `economy_tests` | - | rottami solo dalle Raised |
| `menu_tests` | - | regole e resa di `RunMap` |
| `flow_preview_tests` | griglia 21x21 | i cambi forzati non fanno impronte |
| `quake_tests`, `train_tests`, `railway_tests`, `extraction_tests`, `audio_tests` | - | eventi su celle |
| `workshop_tests` | - | `tool_reach` = 4,8 + `cell_size_m` |
| `ui_theme_tests` | - | `ToolMode.LAMP` |
| `height_terrain_tests` | spike | 36 controlli: pennello, camminata, campo con finestra e lato 100 m, salvataggi corrotti, scena |

Gate `tools/godot/Invoke-GodotChecks.ps1`: `--check-only` su ogni `.gd` (anche `scripts/spikes`), tutte le `tests/*.gd` a 60 fps (fallisce su `SCRIPT ERROR|^ERROR:` salvo `Parameter "material" is null`, P-09), smoke test headless con `--autostart` che richiede `PROTOTYPE01_TERRAIN_GRID_READY`, `PROTOTYPE01_TERRAIN_MODE Dig`, `PROTOTYPE01_PATH_FIELD_READY`.

## 4. Scene

- `main/arena_run.tscn`: `TerrainGrid` (`terrain_district.tres`, `natural_ground`, `plaza_radius 30`) collegato a Player, PathField, ScrapField, Companion, LampField, EnemyDirector, QuakeEvent, ExtractionPad, Run, RunAudio, FlowPreview.
- `main/railway_run.tscn`: idem con `terrain_railway.tres` e `TrainEvent` al posto di `QuakeEvent`.
- `main/smoke_test.tscn` (`terrain_default.tres`, `TerrainHazard`, Player); `main/companion_slice.tscn` (istanzia `smoke_test` come `Base`); `main/ruins_arena.tscn` (`terrain_arena.tres`, `natural_ground`).
- `spikes/terrain_spike.tscn`: un solo nodo radice, tutto in codice, escluso dall'export.

## 5. Documenti e vincoli gia scritti

- `DECISIONS.md`: D-063 (tecnica dello spike, misure, "non deciso" = scopo della migrazione), D-082 (scelta del rilievo continuo; spec con brainstorming prima del piano), D-052/D-053/D-045/D-056/D-058/D-069/D-075/D-076/D-065 (regole oggi espresse in celle).
- `REVIEWS/FULL_CODE_2026-10-09.md`: U-02 (finestra del campo, fatto), U-11 (parziale: upload dell'intera texture e mesh unica senza culling restano per il piano, che deve usare chunk 8x8 con texture per regione), **sei punti di scalabilita per 204 m**: campo a finestra o in thread; mesh e texture a chunk; fisica con `HeightMapShape3D` a chunk aggiornati solo dove tocca il pennello (`set_map_data` non misurato); tutto cio che e stato discreto va ridefinito sui delta di quota (mappa, marker, attrazione del boss, barricate, contatori); determinismo dei bot (D-055) registrando i comandi del pennello; ostacoli statici (rovine, vagoni) assenti nello spike.
- `TERRAIN_SYSTEM.md`: strategie A-D (D = ibrida: rovine, strutture e limiti come geometria controllata), requisiti dello spike, gate e decisioni aperte.
- `PROTOTYPE_01_SPEC.md`: la deformazione continua era fuori scope del prototipo 1.
- `FEATURE_IDEAS.md`: le idee 1-3 e 7-8 sono implementate su celle; 4 e 10 sono formulate in celle.

## Dipendenze trasversali

- **Assi Unreal**: `width` lungo Z e `height` lungo X di Godot (`arena_run.gd`, `ruins_district.gd`); offsets delle feature, `track_cells` e i pixel di `RunMap` assumono questa mappatura.
- **Idiomi ricorrenti**: "cima della cella" = `cell_local_position(...).y * 2` (flow_preview, scrap_field, lamp_field, arena_run, demolisher); "e un collider della griglia" = `collider.get_parent() == grid` (path_field, enemy_director, demolisher, driller).
- **La costante 2,4 m** compare nei `.tres`, in `RuinsDistrict.CELL`, in `PathField.cell_size` 1,2, in `HeightFlowField.CELL` 1,5, nella portata del tool 480 cm, in `tool_reach`, nei raggi di terremoto, piazzola e treno, in `PlayerTuning`.
- **Due canali di cambiamento**: `command_applied` (tool del giocatore e compagno: rottami, audio, impronte, dig blast, contatori) e `cell_changed` (qualsiasi cambio: campo, lampioni, disseppellimento, Demolitore). Boss ed eventi usano di proposito solo il secondo.
