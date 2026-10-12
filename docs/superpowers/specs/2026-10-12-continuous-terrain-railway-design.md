# Terreno continuo, tappa B: la ferrovia sul rilievo e addio alla griglia

**Data:** 12 ottobre 2026. **Stato:** specifica scritta dall'agente in autonomia (CLAUDE.md, "Autonomia"), da giudicare dal proprietario sul risultato; le scelte di design sono registrate in `DECISIONS.md` (D-087). **Riusa:** `2026-10-12-continuous-terrain-design.md` (tappa A: architettura, `TerrainField`, `TerrainCollision`, Jolt, pennello, zainetto, vene, Demolitore, lampioni, eventi, mappa). **Decisioni collegate:** D-063, D-082, D-085, D-086, D-067 (livello 2), D-066 (campagna). **Inventario di partenza:** esplorazione del 12 ottobre 2026 (sezione 8 di questo documento riassume i consumatori residui della griglia).

## 1. Obiettivo

Portare il livello 2 (`railway_run.tscn`: corridoio ferroviario, treno, vagoni, saltatori, Trivella) sul rilievo continuo con le stesse regole della tappa A, portare le scene minori sullo stesso sistema, poi **eliminare la griglia a celle** (`TerrainGrid`, `TerrainState`, shader, tuning, suite, rami `if grid != null`). Alla fine del lavoro nel progetto esiste un solo sistema di terreno. Il gioco della ferrovia resta quello di `RAILWAY_LEVEL_SPEC.md` (ritmo del treno, saltatori, Trivella che carica e si stordisce, campagna): cambia solo il modo in cui legge e modifica il terreno.

Fuori scope: bilanciamento (resta dopo il playtest), terzo livello, Steam Deck, audio.

## 2. `TerrainField` rettangolare

Oggi il campo e quadrato (`size_m: float`, regioni 2 x 2 fisse). La ferrovia e 319,2 x 122,4 m.

- `size_m` diventa **`size_m: Vector2`** (X, Z); `resolution_x`, `resolution_z`; `half_extents() -> Vector2`; `half_extent()` resta come comodita e ritorna il semilato X (chi confronta scale usa `half_extents()`). Indice dei vertici `iz * resolution_x + ix`; tutte le funzioni interne (`_index`, `_vertex_world`, `_disc_indices`, `_mirror`, `region_changed` globale) usano le due dimensioni.
- **Regioni Terrain3D**: `ceil(half.x / 128) * 2` per `ceil(half.z / 128) * 2`, centrate sull'origine (quartiere 2 x 2 come oggi; ferrovia 4 x 2, cioe 512 x 256 m di regioni per un campo di 320 x 123 m: fuori dall'area giocabile il rilievo e solo rumore di base e serve come sfondo oltre il perimetro).
- **Chunk di collisione**: `TerrainCollision` copre `half_extents()` piu un chunk di margine per asse (quartiere 14 x 14 = 196 come oggi; ferrovia 22 x 9 = 198).
- **Salvataggio** (`save_base`/`load_base`): versione **3** con `size_m.x`, `size_m.y`, `resolution_x`, `resolution_z`, seme; la versione 2 non si legge piu (il file del quartiere viene ricotto). Percorso per livello: `res://levels/<level_id>/base.bin` (`ArenaRun.base_relief_path()` da `level_id`); `bake_terrain_base.gd -- --level=<id>` cuoce il livello chiesto (default `district`), entrambi versionati in LFS ed esportati (`include_filter` gia `levels/*/*.bin`).
- Nuova scrittura **`reset_to_base(center: Vector3, half_size: Vector2) -> float`**: riporta alla quota di base tutti i vertici del rettangolo (XZ), ignorando le aree protette, aggiorna specchio e collisione e ritorna il volume assoluto spostato (`Σ |Δh| · 0,25`). E la pennellata del treno. Emette `region_changed` sull'AABB del rettangolo.
- Nuova lettura **`bump_along(from: Vector3, to: Vector3, min_delta: float) -> Variant`**: primo punto lungo il segmento (campionato ogni `SPACING`) con `delta_at >= min_delta`, oppure null. Serve alla Trivella (argine sulla rotta) e al bot.
- `tint` accetta anche un rettangolo: `tint_rect(center, half_size, color, strength)` per la fascia dei binari; `clear_tint` sul rettangolo = `strength 0`.

## 3. `RailwayDistrict` a pennellate

`RailwayDistrict extends RuinsDistrict` continua a usare i mattoni del quartiere (rovine, oggetti, perimetro, cortili, depositi, trincee come **pennellate** `terrain_strokes`), con pianta rettangolare `play_half_extents` (159,6 x 61,2).

- **Fascia dei binari**: `track_half_width()` = **3,6 m** attorno a z = 0 per tutta la lunghezza (era tre righe di celle); `is_on_tracks(point)` = `abs(z) <= 3,6`. Nel **rilievo di base** la fascia e piatta a quota 0 con un raccordo morbido di 2 m ai lati (il rumore a tre ottave viene attenuato a zero nella fascia, `apply_base_relief` della ferrovia lo fa prima di `commit_base`); nessuna rovina, oggetto o protezione nella fascia. Rotaie e traversine restano mesh senza collisione a z = ±2,4 (quota 0). La fascia e dipinta con lo strato **asfalto** (`paint_layer`) e tinta ghiaia scura (`tint_rect`).
- **Cortile di partenza**: anello di argini +1,4 m di raggio 4 pennelli attorno all'origine, **senza i tratti che cadono nella fascia** (`_ring_points` scartando `abs(z) <= 3,6 + 1,2`): i varchi est e ovest coincidono con i binari, come oggi.
- **Vagoni**: cinque **cumuli con vena** sulla fascia (`sculpt(center, 3,0, +1,5)`, tinta ruggine, vena `scrap_left 8`, `base_height` = quota dopo la base = 0), stesse posizioni di oggi (seme D-065). Il treno li spiana con `reset_to_base` e **azzera `scrap_left`** della vena senza far uscire rottami (`ScrapField.exhaust_veins_in_rect`): chi li vuole scava prima del treno. Il marker "ROTTAMI" del vagone si spegne con la vena.
- **Trincee**: solchi −0,8 m paralleli ai binari (stesse linee di oggi) con `_add_stroke` negativo; i **canali di scolo** non toccano la fascia.
- **Scali, magazzini, depositi, cortili secondari, perimetro, portali**: come oggi via `RuinsDistrict`; i portali di galleria alle estremita ricevono un disco protetto come le rovine.
- `track_cells(grid)` sparisce; al suo posto `track_rect() -> Rect2` (centro 0, 0; semilati `play_half_extents.x`, 3,6) usato da treno, test e bot.
- Base cotta: `levels/railway/base.bin`; `RailwayDistrict.apply_base_relief` chiama quella del quartiere e poi spiana la fascia.

## 4. Il treno sul rilievo (`TrainEvent`)

- Avanza come oggi (18 m/s, preavviso, direzione alternata, binario a caso). Ogni passo fisico, per il tratto percorso dal muso in quel passo, chiama `field.reset_to_base(center_del_tratto, Vector2(tratto / 2 + 0,6, 3,6))`: argini, barricate, cumuli dei vagoni spariscono, le trincee si riempiono. **Contatore**: `volume_flattened` (m3) al posto di `cells_flattened`; **detriti**: una zolla ogni 2 m3 spianati (al piu 4 a passo).
- Vene nel rettangolo spianato: `scrap_field.exhaust_veins_in_rect(rect)` (nessun rottame); rottami a terra: `scrap_field.take_near` nel rettangolo come oggi; lampioni: `lamp_field.knock_down_in_rect`.
- Rottamatori, giocatore, compagno, boss nella fascia (`abs(z) <= 3,6`, davanti al muso entro il tratto): come oggi (uccisi/2 danni/spinta/30 al boss).
- **Spinta fuori** (`_push_out`): verso il lato piu vicino, a passi di 1,2 m dal bordo della fascia, il primo punto con `delta_at < 0,5` e `slope_at <= max_grade` (prima: cella non Raised), al massimo 6 passi; se nessuno va bene, l'ultimo.
- Marker invariati: `PROTOTYPE01_TRAIN_WARNING`, `PROTOTYPE01_TRAIN_PASS` (con `volume=` al posto di `cells=`), `PROTOTYPE01_TRAIN_HIT`.

## 5. La Trivella sul rilievo (`Driller`)

Regola invariata: **carica in linea retta e scava un solco; un argine la ferma.**

- **Mira** (`_aim_direction`): la linea verso il giocatore e buona se ogni campione (passo 1,2 m) e `path_field.is_walkable` **oppure** `field.delta_at >= wall_min_delta` (0,8 m: un argine, che sfondera); altrimenti devia via campo di percorso come oggi.
- **Carica** (`_tick_charge`): ogni passo, davanti alla punta (`tip = pos + dir · (BODY_RADIUS + 0,6)`):
  - se `field.delta_at(tip) >= 0,8` (**argine**): `_break_wall(tip)`: `field.level(tip, 2,4, base_height_at(tip), 1,0)` (il varco; la terra tolta si perde: la Trivella la polverizza), `last_wall = tip` (Vector3), segnale `wall_broken(point)`, stordita 3 s con danno x2, carica finita. **Niente rottame dal varco** (D-056 e tappa A: rottami solo dalle vene; se il tip sta in una vena, `ScrapField` fa uscire i rottami per volume come per il Demolitore). Il "muro a sacrificio" ora costa terra dello zainetto, non rottami.
  - altrimenti **solco**: `field.level(tip, 1,2, base_height_at(tip) − furrow_depth_m, 1,0)` con `furrow_depth_m` 0,8 (idempotente: una seconda carica sullo stesso punto non scava oltre), `furrow_length_m += passo`, segnale `furrowed(point)` al posto di `cell_drilled(cell)`.
- La Trivella **ignora la pendenza** (`max_grade` 10: nessun rallentamento in salita, nessun blocco del campo) ma il corpo resta un `CharacterBody3D` con `floor_max_angle = atan(0,8)`: non deve mai dover salire, perche sfonda tutto cio che sporge 0,8 m; sotto 0,8 m sale (argini bassi non la fermano, come le celle Normal di oggi).
- Rovine: deviazione via campo come oggi (`collider != terrain_field.collision_body`). Lampioni: abbattuti a contatto. Riposo 3 s, 180 punti vita, chiamata a 12 minuti: invariati. `EnemyTuning`: `furrow_depth_m`, `wall_min_delta_m`.

## 6. Saltatori e direttore

- `ignores_lowered` sparisce. Il saltatore e gia `max_grade 1,2`: sale argini piu ripidi e, nel rallentamento in salita (`lerp(1, uphill_min_speed, grade / max_grade)`), rallenta meno dei rottamatori a parita di pendenza. **Un solco della Trivella (0,8 m su 1,2 m di raggio) non lo rallenta** in modo sensibile: e la lettura di "salta i fossati".
- Il ramo `grid` del direttore, del guinzaglio, del muro chiodato e dello spawn viene tolto; i saltatori nascono come oggi (dal minuto 2, fino al 25 %).

## 7. Scene minori

- **`smoke_test.tscn`** resta (parita Unreal, `player_tests`, `input_events_tests`, `terrain_tool_tests`): `Arena` + `TerrainField` 128 x 128 m senza resa pesante (`render` vero ma campo piccolo: 2 x 2 regioni, 81 chunk) + `Player` + `CameraRig` + `TuningSwitcher`. `TerrainHazard` e `hazard_tuning.gd`/`hazard_default.tres` **eliminati** (la corsia del pericolo era la Slice B della griglia, D-012; non esiste nel gioco).
- **`companion_slice.tscn`** **eliminata** con l'assistenza del compagno contro il pericolo (`Companion._assist_against_hazard`, `hazard`); i controlli ancora validi di `companion_tests` (offset e tetto dei rottami, `can_supply`) passano su `ruins_arena.tscn`.
- **`ruins_arena.tscn`** resta per `ruins_arena_tests` e `capture_arena.gd`: `OvergrownArena` + `TerrainField` 128 x 128 + `Player` + `Companion` + `ScrapField`, senza pericolo.
- Suite: `terrain_tests` (regole della griglia) e `slice_b_tests` **eliminate**; `live_rebuild_tests` perde `_test_terrain_grid` e tiene arena e camera; `terrain_tool_tests` e `input_events_tests` tengono solo i controlli sul rilievo (gia presenti dalla tappa A) e perdono quelli su `cell_changed`; `player_tests` invariata nella sostanza.

## 8. Rimozione della griglia

Si eliminano: `scripts/terrain/terrain_grid.gd`, `terrain_state.gd`, `terrain_hazard.gd`, `hazard_tuning.gd`, `resources/materials/terrain_cell.gdshader`, `resources/tuning/hazard_default.tres`, `scenes/main/companion_slice.tscn`, `tests/terrain_tests.gd`, `tests/slice_b_tests.gd`, `tests/companion_tests.gd` (riscritta), piu `OvergrownArena._build_ground` e `TerrainGrid.apply_ground_tiles` (il pavimento piatto: ogni scena ha un rilievo) e `ruins_ground.gdshader` se non ha altri usi.

Rami e campi da togliere (file e righe nell'inventario del 12 ottobre 2026): `arena_run.gd` (export `grid`, `_build_terrain_layout` a celle, `_build_courtyard_walls`, `_on_terrain_command`, `RunMap.render` a celle, `raised_color_override`, `_check_scale` a celle, bonus `tool_range` in cm), `player_character.gd` (`terrain_grid`, penalita Lowered, tool a celle, anteprima a box), `path_field.gd`, `flow_preview.gd`, `scrap_field.gd` (`spawn_on_cell`, `_on_command_applied`, `_on_cell_changed`), `lamp_field.gd` (`cells()` → `positions()` unico), `extraction_pad.gd`, `run_audio.gd`, `companion.gd`, `demolisher.gd`, `quake_event.gd`, `run_map.gd` (`snapshot`/`render` a celle: restano solo `snapshot_heights`/`render_heights`), `run_hud.gd` (`TerrainState.ToolMode`, `TerrainGrid.LAMP_PREVIEW_COLOR` → colore in `BrushPreview`), `ruins_district.gd` (`terrain_features`, `_add_feature`, `snap_to_cell`, `cell_offset_to_world`, `feature_centroid`, `_ring_offsets` se non servono alle pennellate), `enemy_director.gd`, `enemy.gd` (`ignores_lowered`), `terrain_tuning.gd` (`MAX_CELLS`, `grid_*`, `cell_*`, `*_height_cm`, `lowered_speed_penalty_percent`) e i quattro `.tres`.

Suite da aggiornare: `flow_preview_tests` (solo variante sul rilievo), `menu_tests` (mappa a delta), `district_tests` (pennellate), `economy_tests` (costanti inutili), `ui_theme_tests` e `button_prompts_tests` (`TerrainField.ToolMode`), `railway_tests`, `train_tests`, `driller_tests`, `campaign_tests` (invariata), `ruins_arena_tests`, `companion_tests`. Strumenti: `capture_extraction`, `capture_flow`, `capture_motion`, `capture_workshop` (gia rotti dalla tappa A: cercano `TerrainGrid` in `arena_run`), `capture_railway`, `simulate_runs` (bot della ferrovia: scavano i vagoni prima del treno, alzano un argine sulla rotta della Trivella con `bump_along`), `benchmark_arena -- --level=railway`.

Gate: marker solo `PROTOTYPE01_TERRAIN_FIELD_READY`; la riga in allowlist `Parameter "material" is null` (P-09, "quando TerrainGrid libera la scena") si toglie e si verifica che il gate resti verde; se l'errore ricompare per un'altra causa, si riannota con il motivo nuovo.

Il nome `TerrainTuning` resta (tuning del pennello, sezione 2.7 della tappa A).

## 9. Verifica

- `terrain_field_tests`: campo rettangolare (indici, `height_at` agli angoli, regioni 4 x 2 con finestra, chunk 22 x 9), `reset_to_base` (rettangolo a cavallo di due regioni e di piu chunk, aree protette ignorate, volume), `bump_along`, `tint_rect`, salvataggio versione 3 (rifiuto della 2).
- `railway_tests`: pianta rettangolare, fascia piatta a quota 0 nella base, nessun ostacolo statico nella fascia, cortile a cavallo con varchi sui binari (nessun bump nella fascia), cinque vagoni come cumuli con vena sulla fascia, depositi e trincee fuori fascia, determinismo delle pennellate, saltatori (quota, `max_grade` 1,2, rallentamento minore su un solco).
- `train_tests`: argine, trincea e vagone sulla fascia spianati, argine fuori fascia intatto, `volume_flattened > 0`, vene dei vagoni azzerate senza rottami, lampione abbattuto, nemico travolto, giocatore ferito e spinto su un punto piano, compagno spinto, tinta della fascia rimessa, secondo treno dall'altro lato.
- `driller_tests`: mira dritta, solco (`delta_at` −0,8 dietro la punta, idempotente al secondo passaggio), argine che ferma e stordisce senza rottami (`last_wall`, danno x2), vena sotto l'argine che rende rottami, rovina aggirata via campo, treno che colpisce il boss, sconfitta che chiude il livello.
- Review Focus del piano: (1) treno a cavallo del confine fra regioni (x = 0 e x = ±128) senza cuciture; (2) spinta fuori dalla fascia su un argine alto (il punto scelto deve essere calpestabile); (3) Trivella contro un argine basso (< 0,8 m) lo supera senza stordirsi; (4) seconda carica sullo stesso solco non scava oltre; (5) vagone scavato a meta e poi spianato: la vena si azzera, i rottami gia usciti restano.
- Gate completo verde; `bake_terrain_base.gd -- --level=railway`; catture `capture_railway.gd` rifatte in `output/railway/`; `simulate_runs -- --level=railway` semi 1-3; export Windows con `levels/railway/base.bin`.

## 10. Budget

Come la tappa A (pennellata 1,5 ms media, passo fisico 6 ms con 70 nemici, chunk 150 ms). In piu: `reset_to_base` del treno per passo (tratto di circa 0,3 m x 7,2 m: poche decine di vertici) sotto 0,5 ms; costruzione di 198 chunk sotto 150 ms; campo di quote della ferrovia 640 x 246 vertici (0,6 MB).

## 11. Documenti da aggiornare

`DECISIONS.md` (D-087: ferrovia sul rilievo, varco della Trivella senza rottami, scene minori, griglia eliminata; D-012 e D-067 annotate), `RAILWAY_LEVEL_SPEC.md` (regole in metri), `TERRAIN_SYSTEM.md` (un solo sistema), `TERRAIN_MIGRATION_MAP.md` (archiviato come storico in testa), `GODOT_WORKFLOW.md` (cottura per livello, suite tolte, marker), `GODOT_PARITY_CHECKLIST.md` (Slice B non esiste piu), `PROJECT_ROADMAP.md`, `MIGRATION_STATUS.md`, `INDEX.md`.
