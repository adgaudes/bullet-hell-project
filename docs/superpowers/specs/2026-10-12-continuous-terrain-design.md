# Terreno continuo: dalle celle al rilievo scolpibile (tappa A, quartiere)

**Data:** 12 ottobre 2026. **Stato:** specifica approvata a voce dal proprietario sezione per sezione, in attesa della sua revisione scritta. **Decisioni collegate:** D-063 (direzione del rilievo continuo), D-082 (celle visibili scartate, migrazione scelta), D-085 (base tecnica: Terrain3D, collisione a chunk nostra, Jolt). **Mappa di partenza:** `docs/TERRAIN_MIGRATION_MAP.md` (API, consumatori, suite e scene della griglia). **Spike:** branch `spike/terrain3d`, commit `c407d59`, scena `scenes/spikes/terrain3d_spike.tscn` (usa e getta).

## 1. Obiettivo

Sostituire la griglia a celle da 2,4 m (Raised / Normal / Lowered) con un **rilievo continuo** che il giocatore scolpisce a mano libera, senza scacchiera visibile e con un suolo ricco e mosso. Il gioco resta lo stesso: orda lenta, rottami contesi, Demolitore e barricate, lampioni, terremoto, piazzola di estrazione, mappa di fine livello. Cambia il modo in cui queste regole leggono e modificano il terreno: quote e pendenze al posto di stati di cella.

Questa specifica copre la **tappa A: il quartiere** (`arena_run.tscn`). La ferrovia (treno, Trivella, vagoni, saltatori) è la tappa B, con una specifica propria che riusa questa; la griglia a celle resta nel progetto solo per la ferrovia finché B non chiude, poi viene eliminata.

### Cosa il proprietario ha deciso (12 ottobre 2026)

1. **Pennello continuo**: tieni premuto e il terreno si alza o si abbassa in modo fluido (raggio circa 2,4 m), come nello spike D-063.
2. **Terra conservata**: quello che scavi lo puoi rialzare; un serbatoio di terra che si riempie scavando e si svuota alzando. I rottami restano per Officina, lampioni e upgrade.
3. **Pendenza massima** come regola unica: chi cammina sale solo sotto una pendenza; un argine ripido ferma, uno dolce rallenta. Il Demolitore spiana, la Trivella sfonda e si stordisce.
4. **Vene di rottami sepolte**: i depositi sono cumuli di macerie con rottami dentro, che escono scavando.
5. **Ordine**: quartiere, poi ferrovia, poi via la griglia. Un solo sistema di terreno alla fine.
6. **Base tecnica**: addon **Terrain3D** (MIT), verificato con lo spike su Godot 4.7.2 (D-085).
7. Il serbatoio è uno **zainetto** sul modello dell'ingegnere, con l'indicatore di riempimento sullo zaino stesso ("vediamo come viene").
8. Il suolo attuale è **"troppo spoglio e liscio"**: il rilievo nuovo deve nascere mosso e il suolo deve essere ricco (strati, detriti, sassi, crepe, pozzanghere).

## 2. Architettura

### 2.1 `TerrainField` (`scripts/terrain/terrain_field.gd`, `Node3D`)

Avvolge il nodo `Terrain3D`. **Nessun altro script parla con Terrain3D direttamente**: tutto passa da qui, così il resto del gioco non dipende dall'addon e, se un giorno cambiasse, cambia un solo file.

- Dati: passo dei vertici **0,5 m**, `region_size` 256 (128 m per regione), quattro regioni centrate sull'origine per il quartiere (256 x 256 m, l'arena è 204 x 204 m). Quote fra −2,5 e +4 m (`MIN_HEIGHT`, `MAX_HEIGHT`, clamp nel pennello).
- **Rilievo di base** (`_base`, un `PackedFloat32Array` per vertice): la quota "naturale" del livello, fissata con `commit_base()` dopo la generazione. Serve al Demolitore (cerca ciò che sporge dalla base), alla mappa di fine livello (delta), alle vene (volume asportato sotto la base del cumulo) e allo shader (tinta di scavato / alzato).
- API di lettura: `height_at(point) -> float` (bilineare), `normal_at(point)`, `base_height_at(point)`, `delta_at(point)` (attuale − base), `grade_between(a, b) -> float` (dislivello / distanza, positivo in salita), `can_step(from, to, max_grade)` (in discesa sempre; in salita se `grade <= max_grade`), `slope_at(point)` (pendenza locale in m/m dal gradiente), `is_flat(center, radius, tolerance)` (max − min delle quote nel disco), `is_protected(point)`.
- API di scrittura: `sculpt(center, radius, amount) -> float` (pennello a campana `(1 − d²)²`; `amount` in metri al centro, negativo scava; ritorna il volume firmato in m³, `Σ Δh · 0,25`), `level(center, radius, target, strength) -> float` (porta le quote verso `target`, ritorna il volume firmato), `set_region_protected(center, radius, on)`, `commit_base()`, `tint(center, radius, color, strength)` (pittura sul color map di Terrain3D: strada, piazza, cumuli, barricate).
- Scrittura effettiva: i pixel del pennello si scrivono con `Terrain3DData.set_height` (il pennello copre circa 80 pixel a raggio 2,4 m; misurato 0,05 ms), la regione toccata va marcata `edited = true`, poi `update_maps(TYPE_HEIGHT, false)` (0,15 ms). Per le pennellate di generazione (centinaia) si scrive direttamente l'`Image` della regione e si chiama `update_maps` una volta sola.
- Segnale unico: **`region_changed(aabb: AABB)`** dopo ogni pennellata (anche di boss ed eventi). Chi vuole reagire a un cambio del terreno si collega qui: collisione, campo di percorso, lampioni, rottami, impronte, audio. Non esiste più la distinzione fra `cell_changed` e `command_applied`: il **tool del giocatore** emette un secondo segnale `player_sculpted(center, radius, volume, mode)` per ciò che oggi dipende da `command_applied` (rottami, suono, dig blast, contatori, impronte).
- Persistenza: il rilievo di base di ogni livello si genera da codice la prima volta e si salva nella cartella dati di Terrain3D (`res://levels/<nome>/terrain/`, file `.res` delle regioni, versionati in Git LFS); all'avvio si carica. Il terreno **modificato durante una run non si salva** (come oggi).
- Headless: Terrain3D ha bisogno del renderer; in `--headless` la mesh non esiste ma i dati sì (`Terrain3DData` funziona: lo spike lo mostra con il calcolo delle quote). Le suite girano headless come oggi; se qualcosa in Terrain3D richiedesse la finestra, `TerrainField` tiene una copia delle quote in un `PackedFloat32Array` e risponde da lì (è già necessario per `_base`).

### 2.2 `TerrainCollision` (`scripts/terrain/terrain_collision.gd`)

La collisione di Terrain3D non va bene per il gioco (misure in D-085: il modo dinamico copre solo un raggio attorno alla camera e `update(true)` costa 3-35 ms; il modo pieno ricalcola tutto il terreno a ogni aggiornamento, 5-20 ms). Quindi:

- un solo `StaticBody3D` figlio di `TerrainField`, layer 1 (come le celle Raised oggi: nemici, chiodi, raggi e compagno non cambiano maschere);
- **chunk di 32 x 32 celle (16 m)** con un `HeightMapShape3D` da 33 x 33 quote ciascuno, scala (0,5, 1, 0,5), centrati sul proprio rettangolo; 196 chunk per 224 m (misurati: costruzione 97 ms, aggiornamento 0,65 ms a pennellata, massimo 2,1 ms);
- `region_changed(aabb)` → rigenera i soli chunk che intersecano l'AABB, nello stesso passo fisico (nessun ritardo: un nemico non deve attraversare un argine appena alzato);
- `active_chunk_count()` per il benchmark.
- I consumatori che oggi riconoscono "è una cella" con `collider.get_parent() == grid` (campo di percorso, muro chiodato, Demolitore, Trivella) riconoscono "è il terreno" con `collider == terrain_field.collision_body`.

### 2.3 Motore fisico: Jolt

`physics/3d/physics_engine = "Jolt Physics"` nel progetto. Con Godot Physics 40 corpi su heightmap costano 17 ms a passo (8 fps); con Jolt 2,7 ms. Il gate completo (36 suite più smoke test) è già stato fatto girare sotto Jolt nel worktree dello spike il 12 ottobre 2026: **verde**. Restano da ricontrollare in gioco: `floor_max_angle` dei `CharacterBody3D`, lo scivolamento sui pendii, i raggi dei chiodi contro un argine, le aree dei pickup.

### 2.4 `PathField` (`scripts/navigation/path_field.gd`)

Resta a 1,2 m con la finestra di U-02. Cambia solo la calpestabilità:

- un arco fra due celle vicine è percorribile se `terrain_field.can_step(a, b, max_grade)` con `max_grade` 0,8 (controllato nel verso di marcia: in discesa sempre, in salita solo sotto la soglia); la regola è quella dello spike D-063, già verificata in `height_terrain_tests.gd` (campionamento vertice per vertice lungo l'arco, non solo gli estremi);
- `is_walkable(cell)` non esiste più come proprietà della sola cella: diventa `is_reachable_from(cell, neighbor)`; per i chiamanti che chiedono solo "qui si può stare" (spawn, guinzaglio, mira della Trivella) resta `is_walkable(cell)` = pendenza locale sotto la soglia e nessun ostacolo statico;
- gli ostacoli statici (rovine, torri, auto, vagoni) si leggono dalla fisica come oggi, escludendo il corpo del terreno;
- **costo di marcia**: salita e discesa non cambiano il costo del campo (resta Dijkstra sui passi); il rallentamento in salita lo applicano i movers (2.5);
- `region_changed` marca sporchi i chunk del campo che intersecano l'AABB; ricalcolo come oggi (al più ogni 0,25 s).

### 2.5 Movers (giocatore, rottamatori, compagno, boss)

- `floor_max_angle = atan(0,8)` su tutti i `CharacterBody3D`; un argine più ripido è un muro, uno meno ripido si sale.
- **Rallentamento in salita** al posto delle celle Lowered: velocità × `lerp(1, 0.5, clamp(grade / 0.8, 0, 1))` quando `grade > 0` nel verso del movimento; in discesa velocità piena. Letto da `terrain_field.grade_between(pos, pos + dir)`. I saltatori (`ignores_lowered` oggi) ignorano la pendenza fino a 1,2 m/m: `max_grade` per nemico (`enemy.max_grade`, default 0,8).
- **Rottamatori che scavano**: un rottamatore fermo contro il terreno (`is_on_wall()` con il corpo del terreno, o avanzamento sotto 0,2 m in 2 s) entra in `GNAWING`: ogni secondo `sculpt(punto davanti, 1,2, −0,6)`; esce quando torna a muoversi. Così un argine tiene in proporzione alla sua altezza, non per sempre. Valori in `EnemyTuning` (`gnaw_delay_s`, `gnaw_depth_m`, `gnaw_radius_m`).

### 2.6 Griglia a celle

In tappa A `arena_run.tscn` non istanzia più `TerrainGrid`; `TerrainGrid`, `TerrainState`, `terrain_cell.gdshader`, `terrain_district.tres` e le suite della griglia restano nel progetto per la ferrovia e vengono eliminati alla fine della tappa B. `TerrainTuning` (risorsa) diventa il tuning del pennello (2.7); i campi delle celle sono rimossi in B.

### 2.7 Tuning (`resources/tuning/terrain_default.tres`, classe `TerrainTuning`)

| Campo | Default | Note |
|---|---|---|
| `brush_radius_m` | 2,4 | pennello del giocatore |
| `sculpt_rate_m_s` | 2,2 | spostamento al centro per secondo |
| `level_rate` | 5,0 | forza della livella |
| `max_grade` | 0,8 | pendenza massima di marcia |
| `pack_capacity_m3` | 60 | zainetto |
| `pack_start_m3` | 20 | all'avvio del livello |
| `tool_range_m` | 3,6 | distanza del bersaglio davanti al giocatore (era 480 cm = 2 celle) |
| `protected_radius_m` | 1,5 | attorno alle fondamenta degli ostacoli statici |
| `start_protected_radius_m` | 6 | cortile di partenza nei primi 10 s |

## 3. Tool del giocatore e zainetto

- **Modi**: Scava → Alza → Livella → Lampione (il Lampione resta in `LampField`). `TerrainState.ToolMode` diventa `TerrainField.ToolMode { DIG, RAISE, LEVEL, LAMP }`; l'HUD mostra il modo con la stessa targhetta di oggi; `ui_theme_tests` e `button_prompts_tests` aggiornati.
- **Azione continua**: finché il tasto è premuto, ogni passo fisico applica `sculpt(target, radius, ±rate · delta)` (o `level`). Niente più "un colpo per pressione"; `input_events_tests` cambia: un impulso di 0,1 s produce un volume proporzionale, due pressioni separate due pennellate.
- **Bersaglio**: controller, punto a `tool_range_m` (+ bonus di `tool_reach`) davanti al giocatore, sulla quota del rilievo; mouse, intersezione del raggio del cursore col rilievo (`Terrain3D.get_intersection`, o raggio fisico sul corpo del terreno), limitata alla portata massima (`tool_range_m` × 2,2).
- **Anteprima**: un anello di luce proiettato sul rilievo (un `Decal` con texture ad anello, raggio = raggio del pennello), colore per modo: ciano scava, giallo alza, bianco livella, rosso se rifiutato (zaino vuoto in Alza, area protetta, fuori portata). Sostituisce il box `Preview`; `terrain_tool_tests` legge il colore del decal.
- **Zainetto** (`scripts/player/soil_pack.gd`, risorsa del giocatore): `capacity`, `amount`, `take(m3)`, `give(m3)`. Scavare riempie (il volume negativo ritornato da `sculpt`); alzare chiede `take`: con zaino vuoto `sculpt` non si chiama e l'anello è rosso; a zaino pieno scavare continua e la terra in eccesso si perde (nessun blocco). Livella scambia terra nei due versi. Upgrade: `pack_size` (+20 m³ per livello, Officina), `brush_size` (+0,4 m di raggio, carta del level-up), `tool_reach` resta (+1,2 m per livello).
- **Sul modello**: una sacca di tela sulla schiena dell'ingegnere (pezzo nuovo in `build_character_assets.py`, cotto con la stessa pipeline), con una striscia-indicatore verticale sul fianco visibile dai tre quarti alti; lo shader `actor_paint` riceve `pack_fill` 0..1 e riempie la striscia di terra scura; sopra 0,9 la sacca si gonfia leggermente (blend shape o scala del pezzo del 12 %). Nell'HUD solo il numero `12/60` accanto ai comandi: lo zaino è la lettura principale. **Da giudicare dal proprietario sulle catture** ("vediamo come viene"): se non si legge, l'HUD prende il ruolo principale.
- **Pendenza per il giocatore**: vale la stessa soglia 0,8; un argine troppo ripido non si sale, si scavalca scavando o livellando.
- **Aree protette**: dischi attorno a rovine, torri, auto e lampioni (`protected_radius_m`), il cortile di partenza nei primi 10 s; `sculpt` dentro un'area protetta non fa nulla (il pennello taglia i pixel protetti, non l'intera pennellata), l'anello è rosso se il centro è protetto.
- **Audio**: `player_sculpted` → `terrain_dig` / `terrain_raise` in loop finché si scava (stream continuo, non più un colpo), con il volume proporzionale al volume spostato; a zaino vuoto `tool_reject`.

## 4. Orda, campo di percorso, boss

- **Direttore dei nemici**: spawn e guinzaglio usano `path_field.is_walkable` come oggi; penalità in salita per nemico (2.5); il muro chiodato danneggia chi è in contatto con il corpo del terreno **mentre il terreno sotto di lui sporge dalla base** (`delta_at > 0,3`), così la spina vale per gli argini e non per il suolo naturale.
- **Demolitore** (`demolisher.gd`): `_nearest_wall` → `terrain_field.highest_bump(center, radius, min_delta)`: il punto entro `wall_attraction_radius` con il maggior `delta_at` sopra 0,8 m (campionato sulla griglia a 1,2 m del campo), escluse le proprie barricate. Arrivato a contatto (distanza ≤ `BODY_RADIUS + 1,2`) entra in demolizione: ogni colpo di martello `level(punto, 3,6, base, forza)` per 3 m/s di abbassamento; la terra tolta **ricade attorno** (il volume livellato viene aggiunto con `sculpt` positivo in un anello esterno al raggio, così la terra si conserva) e, se il punto sta in una vena (5.1), i rottami escono. **Cantiere**: un punto a 1-3 pennelli davanti con `is_flat(p, 2,4, 0,35)`; i portatori consegnano come oggi; `_raise_barricade` → `sculpt(p, 2,4, +1,5)` in 1 s e `tint(p, 2,4, BARRICADE_COLOR)`; `barricades: Array[Vector3]` (centri). Una barricata "cade" quando `delta_at(centro)` scende sotto 0,5 m (`region_changed` nel suo AABB → controllo), la tinta si toglie.
- **Trivella**: tappa B (ferrovia). Qui si definisce solo l'API che userà: `grade_between` sulla punta e `sculpt` per il varco e il solco.
- **Compagno**: `can_supply` resta per i lampioni (rottami); l'assistenza contro il pericolo (solo scene Companion Slice) viene **eliminata** con quelle scene in tappa B; in A `companion_slice.tscn`, `smoke_test.tscn` e `ruins_arena.tscn` restano com'è (griglia) finché esistono.

## 5. Rottami, lampioni, eventi, mappa

### 5.1 Vene di rottami

- Un deposito è un **cumulo** generato con `sculpt(center, 3-4 m, +1,5)` sopra la base, tinta "ruggine" (`tint`) e una vena `{center, radius, scrap_left: 6-10, base_height}` in `ScrapField`.
- `player_sculpted` (e la demolizione del boss) dentro il raggio di una vena: il volume asportato **sotto `base_height` del cumulo** si accumula; ogni 0,8 m³ esce un rottame (`spawn_on_ground` nel punto più basso del pennello) finché `scrap_left` arriva a 0; poi la tinta si spegne (`tint` a zero). Il resto del terreno non dà rottami (D-056 resta vero: niente rottami dal suolo nudo).
- **Rottami a terra**: `spawn_on_ground(point)` li appoggia a `height_at`; su `region_changed` i rottami nell'AABB vengono riappoggiati e, se la quota sotto è salita di oltre 0,5 m rispetto a quando sono stati posati, **rotolano** al vertice più basso entro 2,4 m (sostituisce `_free_neighbor`). I portatori li raccolgono come oggi.
- `economy_tests`: "rottami solo dalle vene" al posto di "solo dalle celle Raised".

### 5.2 Lampioni (`LampField`)

- `can_place(point)`: `is_flat(point, 1, 0,3)`, nessun lampione entro 2 m, non protetto, sotto il tetto; i lampioni sono una lista di `{position, node}`; il palo poggia su `height_at`.
- Su `region_changed` nel loro intorno: se `|height_at(pos) − quota alla posa| > 0,4` il lampione cade (`lamp_lost`). Il Demolitore li abbatte come oggi (`knock_down_near`).
- `cells()` → `positions()` per mappa e bot.

### 5.3 Terremoto (`QuakeEvent`)

La faglia è una **polilinea di 18 pennellate** a passo 2,4 m lungo una direzione casuale: per ciascuna, in ordine (14 al secondo come oggi), `sculpt(p, 2,4, +1,2)` sulla cresta e `sculpt(p + lato · 2,4, 1,8, −0,6)` sul solco parallelo; chi sta entro 1,2 m dal punto subisce il danno (giocatore) o muore (rottamatori), il boss è risparmiato, i lampioni entro 1,5 m cadono. Contatori: `volume_moved`. Alla fine `flow_preview.show_now()`. Le aree protette valgono anche per la faglia.

### 5.4 Piazzola di estrazione

"Piano" = `is_flat(center, 3,0, 0,35)` (centro = posizione del giocatore); il marker è un anello (decal) di raggio 3 m sul rilievo; il resto (8 s tenuti, uscita) invariato. Con il pennello il giocatore può spianare un punto per renderlo valido: è il modo previsto per "preparare la piazzola".

### 5.5 Mappa di fine livello (`RunMap`)

- `snapshot` → copia delle quote campionate ogni 2,4 m (85 x 85); `render`: per pixel, `delta = now − initial`: rame se `delta > 0,4` (alzato), blu se `delta < −0,4` (scavato), neutro altrimenti; barricate (centri), lampioni (posizioni), edifici, partenza, uscita, boss come oggi.
- Piè di pagina: "Terra spostata: N m³" (somma dei |volumi| di `player_sculpted`) al posto di "Celle scavate/rialzate"; `cells_dug/raised` → `volume_dug/raised`.

### 5.6 Impronte dell'orda (`FlowPreview`)

Invariate nella logica (campo di percorso); `_ground_y` = `height_at`. Si aggiornano su `player_sculpted`, non su ogni `region_changed` (come oggi ignorano i cambi di boss ed eventi).

### 5.7 Marker fuori schermo, upgrade, HUD, audio

- Marker: cortili e depositi restano segnalati finché la loro vena ha rottami (`scrap_left > 0`) o, per i cortili, finché il loro anello sporge (`highest_bump` nell'anello > 0,8).
- Upgrade: `tool_reach` (+1,2 m), `dig_blast` (danno attorno al pennello ogni 0,5 s di scavo continuo, raggio 2,4 + 0,8/livello), `spiked_wall` (4), nuovi `pack_size` e `brush_size` (3). Catalogo e `workshop_tests` aggiornati.
- HUD: modo del tool, `12/60` dello zaino, lampioni come oggi.
- Audio: 3; `audio_tests` aggiornata ai nuovi segnali.

## 6. Resa del suolo e generazione del livello

### 6.1 Rilievo di base del quartiere

Generato da `RuinsDistrict` in `TerrainField` al primo avvio, poi salvato (2.1):

- rumore a tre ottave: gobbe di ±1,2 m su 40 m, ondulazioni di ±0,5 m su 14 m, increspature di ±0,25 m su 6 m; la piazza (raggio `plaza_radius_m`) e il cortile di partenza attenuati al 20 %;
- **cumuli di macerie** attorno alle rovine (anello esterno alle fondamenta, +0,4..0,8 m, raggio 3 m, a tratti) e **solchi delle vecchie strade** (−0,3 m lungo le strade dipinte);
- le `terrain_features` diventano **pennellate**: `{kind, center, radius, height, tint, scrap}`: cortile di partenza = anello di argini +1,4 m (raggio 4 pennelli, varchi dove oggi ci sono i cancelli); cortili secondari idem nelle quattro varianti (`three_gates`, `two_gates`, `broken` con argine più basso in un tratto, `double`); depositi = cumuli con vena (5.1); trincee = solchi −0,8 m lungo le stesse linee. **Stesse posizioni, stessa pianta** (D-065 resta).
- **Ordine**: rumore, cumuli di macerie e solchi delle strade, poi `commit_base()`; **dopo** la base, le pennellate delle feature (argini dei cortili, trincee, cumuli delle vene). Così gli argini generati **sporgono dalla base** e il Demolitore li attacca come oggi attacca le celle Raised del layout; la mappa di fine livello usa invece lo `snapshot` preso dopo le feature (5.5), quindi mostra solo ciò che è cambiato durante la run. `highest_bump` considera `delta_at > 0,8` oppure il centro di una vena con rottami.

### 6.2 Shader del terreno

Terrain3D usa uno shader proprio che si può sostituire (`material.shader_override`): si parte dal suo (clipmap, LOD, autoshader) e si aggiungono i nostri strati:

- cinque strati dalle tile già dipinte in `assets/textures/surfaces/` (terra, lastre, asfalto, terra scavata, fango) come `Terrain3DTextureAsset` (albedo+altezza, normal+rugosità impacchettate dal nostro `build_surface_tiles.py`, nuova uscita `--terrain3d`);
- scelta per **pendenza, quota e delta**: pendenza > 0,5 → terra scavata a strati (fianchi degli argini); delta > 0,3 → terra smossa con orlo chiaro (cime alzate); delta < −0,3 → terra scavata scura, fango e pozzanghere nelle conche sotto −0,6; altrimenti la base dipinta da `RuinsDistrict` (strada = asfalto, piazza = lastre, resto = terra con erba dal color map);
- normal e occlusione piene, crepe nelle lastre, pozzanghere riflettenti nelle conche (rugosità bassa sotto la quota dell'acqua locale);
- `cell_pitch`, orlo per cella, griglia: spariscono.

### 6.3 Vegetazione e detriti

Prato (D-083), fiori, detriti, sassi e cespugli si poggiano sul rilievo (`height_at`) e seguono la normale; densità del prato più alta nelle conche (delta < 0) e assente sopra pendenza 0,6; i detriti si infittiscono vicino alle rovine. L'instancer di Terrain3D non si usa (i nostri MultiMesh restano, con il vento D-083). Su `region_changed` le istanze nell'AABB vengono riappoggiate (ricalcolo del buffer solo in quell'area).

## 7. Verifica

- Nuova suite `tests/terrain_field_tests.gd`: pennello (volume, campana, clamp), livella, zaino (riempimento, vuoto, pieno, upgrade), `can_step` e `grade_between` (casi dello spike D-063 riportati), aree protette, `region_changed` e chunk rigenerati nello stesso passo, `highest_bump`, `is_flat`, vene (rottami per volume, esaurimento), salvataggio e caricamento del rilievo di base.
- Suite esistenti aggiornate (elenco in `TERRAIN_MIGRATION_MAP.md` §3): `terrain_tool_tests` (modi, anteprima a decal, continuo), `arena_run_tests` (argini del cortile, varchi, cortile sigillato con un argine, un argine blocca il tiro), `district_tests` (pennellate applicate, marker), `boss_tests` (spiana, cantiere piano, barricata come cumulo, rottami che rotolano), `lamp_tests` (posa su piano, caduta per dislivello), `economy_tests` (vene), `quake_tests` (cresta e solco), `extraction_tests` (`is_flat`), `menu_tests` (mappa a delta), `flow_preview_tests`, `workshop_tests` (`tool_reach` in metri, `pack_size`), `audio_tests`, `input_events_tests`, `ui_theme_tests`, `button_prompts_tests`. `path_field_tests` con la pendenza. Le suite della sola griglia (`terrain_tests`, `live_rebuild_tests`, `slice_b_tests`, `companion_tests`) restano finché esistono le loro scene (tappa B le toglie).
- Bot (`simulate_runs.gd`): scavano le vene più vicine, alzano un argine davanti al varco più minacciato, livellano la piazzola dopo il boss; i comandi del pennello vengono registrati in un log per seme (determinismo D-055).
- Gate `Invoke-GodotChecks.ps1` verde sotto Jolt; marker `PROTOTYPE01_TERRAIN_FIELD_READY` al posto di `PROTOTYPE01_TERRAIN_GRID_READY` nello smoke test (che in A usa ancora la griglia: il gate accetta entrambi finché B non chiude).
- Catture: `capture_district.gd` e `capture_closeup.gd` invariati; nuova `capture_terrain.gd` (argine alzato, trincea scavata, cumulo con vena a metà, barricata del boss, zainetto pieno e vuoto da dietro) in `output/terrain/`.
- Benchmark `benchmark_arena.gd`: aggiunge pennellata media e massima, chunk aggiornati, VRAM; righe `PROTOTYPE01_ARENA_BENCH terrain ...`.

## 8. Budget e misure

| Misura | Spike (PC, 12 ottobre 2026) | Soglia |
|---|---|---|
| Pennellata (pixel + mappe + chunk) | 0,8 ms media, 2,1 max | 1,5 ms media, 4 max |
| Passo fisico con 40 corpi, Jolt | 2,7 ms | 6 ms con 70 nemici |
| Frame PC preset Alto | n/d (gioco intero) | 12 ms |
| Frame Steam Deck preset Deck | non misurato | 16 ms |
| VRAM | +170 MB (spike nudo) | 450 MB totali (Alto) |
| Costruzione chunk | 97 ms | 150 ms |
| Campo di percorso (finestra) | 2,1 ms oggi | 6 ms |

## 9. Rischi

- **Terrain3D su 4.7.2**: non dichiarato dall'autore; lo spike carica, esporta e gira. Se una futura 4.7.x rompesse l'estensione, si resta sulla versione che funziona o si ricompila (sorgenti MIT). Registrare in `TOOLS_AND_LICENSES.md`.
- **Jolt**: gate verde, ma il feel di movimento (scivolamento sui pendii, scalini) va giudicato nel playtest; `floor_snap_length` e `floor_max_angle` da tarare.
- **Steam Deck**: VRAM e fill rate della clipmap non misurati; il preset Deck può ridurre `mesh_lods`/`mesh_size` di Terrain3D e la densità del prato.
- **Headless**: se qualche chiamata di `Terrain3DData` richiedesse il renderer, `TerrainField` risponde dalla copia delle quote; la suite `terrain_field_tests` deve passare headless prima di tutto il resto.
- **Rottamatori che scavano**: può rendere gli argini inutili se troppo veloce; valori nel tuning e bilanciamento nel playtest.
- **Leggibilità delle difese**: senza celle, capire "dove passa l'orda" dipende dalle impronte (D-053) e dalle tinte di scavato/alzato nello shader; da giudicare sulle catture.
- **Determinismo dei bot**: pennellate registrate; se divergono fra run, la simulazione perde valore (D-055).

## 10. Documenti da aggiornare

`DECISIONS.md` (D-085 → approvata, nuova decisione per lo zainetto e i rottamatori che scavano), `TERRAIN_SYSTEM.md` (strategia scelta: ibrida D con Terrain3D), `TOOLS_AND_LICENSES.md` (Terrain3D 1.0.2 MIT, Jolt), `GODOT_WORKFLOW.md` (comandi di Terrain3D, rigenerazione del rilievo di base, trappole: camera prima della collisione, `update_maps` per regione, Jolt), `ART_DIRECTION.md` (suolo a strati per pendenza e delta, zainetto), `PROGRESSION_SPEC.md` (upgrade `pack_size`, `brush_size`), `FEATURE_IDEAS.md` (idee 4 e 10 riformulate), `PROJECT_ROADMAP.md` e `MIGRATION_STATUS.md`, `INDEX.md` per questa specifica.
