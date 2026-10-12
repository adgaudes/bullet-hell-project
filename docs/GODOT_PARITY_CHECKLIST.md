# Checklist di parita Unreal → Godot (Fase 9)

> **Nota del 12 ottobre 2026 (tappa B del terreno continuo, D-087):** la griglia a celle, la Slice B (penalita delle celle Lowered, corsia del pericolo `TerrainHazard`) e il Companion Slice non esistono piu: il terreno e un rilievo continuo (`TerrainField`) in ogni scena. Le righe sotto che citano celle, hazard o Slice B sono storiche: valgono come prova della parita raggiunta il 3 ottobre 2026, non come descrizione del codice attuale.

Verifica funzione per funzione della sezione 2 di `GODOT_MIGRATION_ANALYSIS.md`. Data: 3 ottobre 2026. Build di riferimento Godot: export Windows di `feature/godot-migration-foundation`.

Legenda evidenza: **T** test automatico (`godot/tests/`), **C** cattura visiva ispezionata, **S** smoke test con marker, **P** playtest del proprietario. "Da fare" significa che quella evidenza manca ancora.

## Personaggio

| Funzione Unreal | Godot | Evidenza |
|---|---|---|
| Movimento planare analogico 600 u/s, accelerazione e frenata 2048 | `PlanarMovement`, porta letterale di `CalcVelocity` | T: 0→6 m/s in 18 frame, frenata in 6 frame, stick 0,5 → 3 m/s |
| Soglia di attuazione dello stick di movimento (trigger `Down` di `IA_Move`, 0,5 sul modulo, poi modulo grezzo) | `move_actuation_threshold` in `PlayerTuning` | T con eventi joypad reali: 0,4 fermo, 0,6 → 3,6 m/s. **Non verificata**: l'eventuale dead zone per asse delle impostazioni input Unreal, non leggibile dal sorgente del progetto |
| Orientamento twin-stick con stick destro (dead zone 0,2, sensibilita, interpolazione) | `PlayerCharacter._apply_facing_rotation` | T: quattro direzioni, risposta lenta con stick leggero, nessuna rotazione sotto dead zone |
| Mira mouse per deproiezione sul piano del personaggio | `aim_direction_at_screen` | T: deproiezione esatta. **P da fare**: feel con mouse reale |
| Commutazione automatica del dispositivo | `_set_aim_device`, marker `PROTOTYPE01_AIM_DEVICE` | T: mouse → stick → mouse |
| Dash 3000 u/s × 0,18 s, cooldown 1,2 s dall'attivazione, ultima direzione valida | eventi `dash`, timer dall'attivazione | T: 3,97 m in 11 frame (come Unreal a 60 fps), pronto a 1,200 s |
| Feedback dash solo visivo: 1,15×, ciano / grigio / arancione | `_set_body_color`, scala del corpo | C parziale (arancione). Ciano e grigio verificati solo dal codice |
| Cubo con indicatore frontale ciano | `player.tscn` | C |
| **Parita di feel complessiva** | | **P da fare** (criterio della Fase 5) |

## Camera

| Funzione Unreal | Godot | Evidenza |
|---|---|---|
| Isometrica fissa, braccio 1500, pitch −55°, rotazione assoluta, nessuna collisione | `IsometricCameraRig`, `top_level` | S + C: scala cella ≈ 120 px come nella build Unreal |
| FOV 90° orizzontale (default Unreal) | `keep_aspect = KEEP_WIDTH` | C |

## Terreno a celle

| Funzione Unreal | Godot | Evidenza |
|---|---|---|
| Griglia 7×7, cella 240, gap 12, dimensioni forzate dispari | `TerrainGrid._clamp_from_tuning` | T: 49 celle, nessun duplicato dopo ricostruzioni |
| Stati Lowered 4 / Normal 12 / Raised 120 con colori distinti | `TerrainState`, shader per istanza | T + C |
| Collisione solo su Raised | `CollisionShape3D.disabled` | T: raycast; personaggio bloccato e poi libero |
| Dig/Raise di un passo per volta | `TerrainState.apply` | T: tabella completa delle transizioni |
| Anteprima ciano / gialla / rossa sulla cella bersaglio | `update_preview` | T + C |
| Comandi una volta per pressione (`Started`), anche col grilletto analogico; modificatori ignorati | fronte di pressione in `PlayerCharacter._unhandled_input` | T con eventi joypad e tasti reali (`input_events_tests.gd`) |
| Bersaglio a 480 u davanti al personaggio, non sul cursore | `_update_terrain_target` | T: cella (5,3) all'origine, (3,5) mirando a destra |
| Cella protetta immodificabile | `protected_cell` | T + C |
| Rifiuto del rialzo che intersecherebbe il giocatore | `_would_raise_overlap` | T |
| Penalita 50% su Lowered | `_update_terrain_speed_modifier` | T: 3 m/s sopra, 6 m/s fuori |
| **Test A Slice A, passi percettivi** | | **P da fare** (criterio della Fase 7) |

## Hazard

| Funzione Unreal | Godot | Evidenza |
|---|---|---|
| Sfera su corsia rettilinea a 350 u/s | `TerrainHazard` | T: 7 m in 2 s, corsia 22 m |
| Fermata dalle celle Raised | `cast_motion` sul layer `world_static` | T: si ferma a contatto della cella rialzata col tool. C |
| Ripartenza dopo 1 s riusando lo stesso nodo | `_schedule_restart` | T |
| Ignora il Pawn | layer fisici (D-025) | T: attraversa il personaggio senza spingerlo |

## Arena

| Funzione Unreal | Godot | Evidenza |
|---|---|---|
| Pavimento 6000×6000 con griglia | shader `world_grid` | C |
| Quattro pilastri angolari colorati, landmark +Y | `Arena._build` | C dall'alto: posizioni e colori corretti |
| Luce direzionale calda −45°/−30° con ombre | `DirectionalLight3D` | C: direzione delle ombre corretta |
| Sky light real-time, atmosfera procedurale | `ProceduralSkyMaterial` + ambiente dal cielo | **Simile, non identica** (rischio R-G1 accettato) |
| Auto-esposizione disattivata | `CameraAttributesPractical` | S: `PROTOTYPE01_EXPOSURE_READY` |

## Protocollo diagnostico

Marker Unreal conservati: `SMOKE_TEST_OK`, `INPUT_READY`, `EXPOSURE_READY`, `CHARACTER_READY`, `DASH_STARTED`, `DASH_READY`, `TERRAIN_GRID_READY`, `TERRAIN_MODE`, `TERRAIN_CHANGED`, `TERRAIN_REJECTED`, `TERRAIN_RAISE_OCCUPIED_REJECTED`, `TERRAIN_HAZARD_BLOCKED`, `TERRAIN_HAZARD_REACHED`, `TERRAIN_SLICE_B_READY`. Rinominato `ARENA_PLACED_READY` → `ARENA_READY`.

Non portati di proposito: i marker di fallback e di spawn (`*_FALLBACK_*`, `*_SPAWN_FAILED`, `*_PLACED_READY`, `TERRAIN_CHARACTER_MISSING`, `INPUT_COMPONENT_ERROR`, `EXPOSURE_CVAR_MISSING`). In Godot la scena e composta in modo statico e quei casi non possono verificarsi.

## Build

| Voce | Esito |
|---|---|
| Export template 4.7.2 | installati il 3 ottobre 2026 (solo Windows e Linux x86_64), SHA-512 verificato contro `SHA512-SUMS.txt` ufficiale |
| Export Windows release | `LocalBuilds/Prototype01-Godot-Win64/Prototype01.exe`, 109 MB, pck incorporato |
| Export Linux release | `LocalBuilds/Prototype01-Godot-Linux/Prototype01.x86_64`, 74 MB, **non eseguito**: manca un sistema Linux o il Deck |
| Smoke test della build Windows | S: tutti i marker presenti (`tools/godot/Invoke-GodotChecks.ps1 -Executable ...`) |
| Avvio con finestra a 1280x800 | C: scena identica all'editor |
| Steam Deck | **da fare**, richiede il proprietario e il Deck fisico |

## Esito

Nessuna funzione della sezione 2 risulta mancante. Restano aperte tre evidenze che solo il proprietario puo fornire: feel del personaggio, Test A percettivo, Steam Deck.
