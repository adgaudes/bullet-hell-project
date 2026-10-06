# Stato della migrazione — leggere per primo

> **File vivo.** Va aggiornato a ogni avanzamento. Chi apre una nuova sessione legge questo e sa esattamente dove siamo e cosa fare.

**Ultimo aggiornamento:** 6 ottobre 2026: **primo boss e fine del livello** (D-043, il Demolitore: chiamata a 12 minuti, smonta i terrapieni, alza barricate, vittoria alla sua morte; valori non bilanciati), poi **rifiniture in attesa del playtest**: rottamatori che portano i rottami al cantiere della barricata (D-045), rovine sventrate e terrapieni a strati (D-046), frammenti sui colpi (D-047), primo audio sintetizzato (D-048); 15 suite verdi: **il livello completo e pronto per il playtest del proprietario**. Lo stesso giorno: **arena grande giocabile** (D-042): `arena_run.tscn` e un quartiere in rovina di 204x204 m con griglia terreno unica 85x85 a lotti, cortile di partenza, cortili secondari, depositi e trincee; 13 suite verdi, misure su PC registrate, Steam Deck non misurato. Prima: prototipo della promessa A (D-038), struttura a campagne, arene grandi e boss (D-040, D-041, specifica di campagna in attesa delle risposte del proprietario). Stesso giorno: **specifica del ciclo giorno/notte approvata** (D-058, `docs/DAY_NIGHT_SPEC.md`), solo documento. **Il prossimo passo di prodotto e nella roadmap** (`docs/PROJECT_ROADMAP.md`, "Stato operativo"): il playtest del proprietario. Questo file resta il diario della migrazione.
**Engine:** Godot 4.7.2 stable, edizione standard/GDScript
**Fase corrente:** 10 quasi chiusa (codice Unreal rimosso, tag `unreal-prototype-final`); **in attesa del proprietario**: playtest di parita (feel, Test A, Steam Deck), poi eliminazione di `LocalBuilds/Prototype01-TerrainGrid-Win64-v1`
**Branch di lavoro:** `feature/arena-run` (dal 5 ottobre 2026; `main` resta al prototipo della promessa A, da unire quando il livello con boss supera il playtest)

## In una frase

Stiamo migrando a Godot un micro-prototipo Unreal gia validato da un playtest, **a parita di funzionalita**, senza aggiungere feature nuove e senza distruggere il progetto originale.

## Avanzamento

| Fase | Contenuto | Stato |
|---:|---|---|
| 0 | Mettere in sicurezza il lavoro, installare la toolchain | **fatta** |
| 1 | Analisi del progetto ereditato | **fatta** → `GODOT_MIGRATION_ANALYSIS.md` |
| 2 | Architettura: conversione unita e assi, struttura | **fatta**: conversione in `UnrealSpace` (D-023), tuning come `Resource` tipizzate in `.tres` (D-024) |
| 3 | Scheletro: progetto, mappa input, scena avviabile | **fatta** |
| 4 | Arena, illuminazione, camera isometrica | **fatta** |
| 5 | Personaggio: movimento, mira, cambio dispositivo, dash | **fatta nel codice**, playtest del proprietario da fare |
| 6 | Griglia terreno: stato, presentazione, collisioni | **fatta** |
| 7 | Tool e anteprima | **fatta nel codice**, Test A manuale del proprietario da fare |
| 8 | Slice B: penalita velocita, hazard | **fatta** |
| 9 | Verifica di parita, export, smoke test Steam Deck | **fatta** salvo Steam Deck → `GODOT_PARITY_CHECKLIST.md` |
| 10 | Pulizia documentale, destino del progetto Unreal | **in corso**: documenti fatti, decisione Unreal del proprietario |

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

## Fase 5 — com'e stata chiusa

- `scenes/player/player.tscn` + `scripts/player/player_character.gd` (`PlayerCharacter`, `CharacterBody3D`): capsula 0,34/1,76 m, origine al centro capsula, graybox 0,45×0,9×0,9 con indicatore frontale ciano, senza ombre.
- `scripts/player/planar_movement.gd` (`PlanarMovement`): porta letterale di `CalcVelocity` + `ApplyVelocityBraking` di Unreal (Walking). Anche il dash passa per la frenata, come in Unreal: velocita nominale 30 m/s, effettiva 21,66 m/s a 60 fps, ~3,97 m in 11 frame.
- `scripts/player/player_tuning.gd` + `resources/tuning/player_default.tres`: tuning in unita Unreal (D-024).
- Mira: stick destro con dead zone 0,2 e risposta proporzionale, oppure mouse deproiettato sul piano del personaggio; commutazione automatica (`PROTOTYPE01_AIM_DEVICE`). Stick in alto = sguardo verso l'alto dello schermo, come nella build Unreal dopo la correzione di playtest.
- Dash a eventi (come il trigger `Started`), direzione dell'ultimo movimento valido, colori ciano/grigio/arancio, scala 1,15; durata e cooldown misurati dall'attivazione.
- Interpolazione fisica attiva nel progetto; il rig camera legge la posizione interpolata.
- Test automatici: `tests/player_tests.gd`, 24 controlli, tutti verdi.

Non verificato da un agente: **il feel con controller e mouse reali**. Va playtestato dal proprietario: aprire il progetto ed eseguire (F5), provare movimento, mira con stick e mouse, cambio dispositivo, dash e cooldown, possibilmente confrontando con la build Unreal di riferimento.

Differenze note rispetto a Unreal: dead zone del movimento radiale 0,2 di Godot invece di quella per asse di Unreal; il passo fisico e fisso a 60 Hz, quindi il dash non varia con il framerate (in Unreal si').

## Fase 6 — com'e stata chiusa

- `scripts/terrain/terrain_state.gd` (`TerrainState`): stato logico puro. Tre stati, transizioni di un livello per passo, cella protetta (0,0), rifiuto per occupazione distinto. Coordinate di cella **come in Unreal** (X avanti, Y destra): i log `PROTOTYPE01_TERRAIN_*` restano confrontabili con il protocollo di playtest Slice A.
- `scripts/terrain/terrain_grid.gd` (`TerrainGrid`, `@tool`): presentazione (una cella = `StaticBody3D` con mesh e collisione), colore per istanza su un solo materiale (`resources/materials/terrain_cell.gdshader`), collisione solo su Raised, controllo anti-intrappolamento sul volume del personaggio (`PlayerCharacter.get_collision_aabb()`), API `cell_at`, `cell_state_at`, `can_apply_at`, `apply_command_at`, `lowered_speed_penalty`.
- `scripts/terrain/terrain_tuning.gd` + `resources/tuning/terrain_default.tres`: 7×7, celle 240 cm, gap 12, altezze 4/12/120, penalita 0,5.
- Il nodo `TerrainGrid` sta in `smoke_test.tscn`, centrato sotto il personaggio.

Verificato: `tests/terrain_tests.gd`, 37 controlli verdi (regole, 49 celle senza duplicati dopo ricostruzioni, mappatura mondo→cella, collisione via raycast, rialzo rifiutato sotto il personaggio, personaggio bloccato da una cella Raised e libero quando torna Normal); `tests/player_tests.gd` sempre verde; cattura visiva con celle nei tre stati.

Limite risolto il 3 ottobre 2026: arena, griglia (anche modificando `terrain_default.tres`) e camera si aggiornano subito quando si cambiano i parametri dall'Inspector (`tests/live_rebuild_tests.gd`).

## Fase 7 — com'e stata chiusa

- `PlayerCharacter`: `terrain_grid` (collegata in `smoke_test.tscn`), `terrain_tool_mode` Dig/Raise, bersaglio a `terrain_tool_range_cm` (480) lungo il forward planare aggiornato a ogni passo fisico; `terrain_tool` applica, `terrain_mode` alterna. Input a eventi come il dash.
- `TerrainGrid.update_preview()` / `hide_preview()`: anteprima 72% della cella, 5 cm, 2 cm sopra la cella; ciano Dig, giallo Raise, rosso impossibile; nascosta fuori griglia. `preview_cell` esposto.
- Log invariati rispetto a Unreal: `PROTOTYPE01_TERRAIN_MODE`, `PROTOTYPE01_TERRAIN_CHANGED`, `PROTOTYPE01_TERRAIN_REJECTED`, `PROTOTYPE01_TERRAIN_RAISE_OCCUPIED_REJECTED`.
- Sonda: rimossi i log `PROTOTYPE01_ACTION *`, sostituiti da quelli reali.

Verificato: `tests/terrain_tool_tests.gd`, 20 controlli verdi che automatizzano i passi 5-9 del Test A (scavo, cambio modalita, Normal/Raised, anteprima rossa oltre il limite, cella protetta, fuori griglia, modifiche rapide); le altre due suite restano verdi; cattura con anteprima ciano.

**Da fare dal proprietario:** Test A di `docs/PLAYTESTS/TERRAIN_GRID_SLICE_A_2026-09-22.md`, passi 2-4 e domande percettive (corrispondenza cella/direzione, leggibilita colori, naturalezza del cambio modalita), con mouse e controller. Si avvia con F5 dall'editor Godot.

## Fase 8 — com'e stata chiusa

- Penalita di velocita: `PlayerCharacter._update_terrain_speed_modifier()` ricalcola `speed_multiplier` a ogni passo (0,5 sopra Lowered, 1 altrove), come `UpdateTerrainSpeedModifier`.
- `scripts/terrain/terrain_hazard.gd` (`TerrainHazard`) + `hazard_tuning.gd` + `resources/tuning/hazard_default.tres`: sfera magenta 45 cm, 3,5 m/s, corsia lungo l'asse X Unreal della griglia (22 m, centro a 50 cm), sweep con `cast_motion` solo sul mondo statico, pausa nascosta di 1 s e ripartenza dallo stesso nodo. Log `PROTOTYPE01_TERRAIN_HAZARD_BLOCKED|REACHED`, `PROTOTYPE01_TERRAIN_SLICE_B_READY`.
- Layer fisici (D-025): 1 `world_static` (arena, celle), 2 `player`, 3 `hazard`. L'hazard interroga solo il layer 1: attraversa il personaggio senza spingerlo, come in Unreal.

Verificato: `tests/slice_b_tests.gd`, 19 controlli verdi, incluso il **criterio di uscita**: il giocatore rialza col tool la cella (5,3) sulla corsia e l'hazard si ferma a contatto del terrapieno (z = −3,21), a ogni ciclo, e torna ad arrivare in fondo quando la cella e riabbassata. Le altre tre suite restano verdi; cattura con l'hazard fermo contro il terrapieno.

## Fase 9 — com'e stata chiusa

- `docs/GODOT_PARITY_CHECKLIST.md`: nessuna funzione della sezione 2 manca; per ognuna c'e l'evidenza o quella che manca.
- Aggiunti i marker Unreal `SMOKE_TEST_OK`, `INPUT_READY`, `EXPOSURE_READY`, citati dai documenti di smoke test.
- `tools/godot/Invoke-GodotChecks.ps1`: **gate unico**: `--check-only` su ogni script, tutte le suite, smoke test con marker. Con `-Executable <build>` verifica una build esportata. Controllo negativo fatto: con un eseguibile sbagliato risponde FAIL.
- Export template 4.7.2 installati (solo Windows e Linux x86_64, SHA-512 verificato). `godot/export_presets.cfg`: preset Windows e Linux, esclusa la cartella `tests/`.
- Build in `LocalBuilds/Prototype01-Godot-Win64/` (109 MB, smoke test e avvio con finestra verificati) e `LocalBuilds/Prototype01-Godot-Linux/` (74 MB, non eseguita).

## Review indipendente del 3 ottobre 2026

Review del codice Godot fatta da un agente separato. Corretto:

- **grilletto destro**: applicava il tool piu volte per pressione (ogni variazione analogica era un nuovo comando); ora una volta per pressione, come `Started`. Bug reale su controller e Deck, invisibile ai test basati su azioni simulate;
- **modificatori**: Shift/Ctrl bloccavano dash e tool; ora ignorati come in Unreal;
- **soglia dello stick di movimento**: 0,5 sul modulo grezzo come il trigger `Down` di `IA_Move` (prima 0,2 con riscalatura);
- comandi del tool eseguiti nel passo fisico; corsia dell'hazard ricalcolata quando la griglia si ricostruisce e corretta su griglia scalata; il rig camera non riscrive piu la propria trasformazione nell'editor.

Nuova suite `tests/input_events_tests.gd`. Build Windows e Linux riesportate dopo le correzioni.

Non corretto, annotato: la mira mouse usa la posizione fisica del personaggio e la camera interpolata (scarto massimo di un passo, simile a Unreal).

## Esito del playtest del feel (3 ottobre 2026)

Feel "quasi uguale" in Godot e Unreal: gate della Fase 5 superato. Leggera preferenza per Unreal su **risposta ai comandi** e **fluidita**, e il feel attuale non e quello definitivo. Interventi: fisica a 120 Hz e MSAA 4x (D-028), dorsale sinistro corretto (era mappato su View/Back), preset di feel alternabili in gioco (D-029, Parte 4 del protocollo di playtest). Build riesportate.

Preset scelto: **Scattante**, ora default (D-030). Per ridurre ancora il ritardo: VSync Mailbox e coda di 1 frame, con F2 o croce sinistra per confrontare in gioco Mailbox, Classico e Off.

## Cosa serve dal proprietario

Protocollo unico con tabelle da compilare: **`docs/PLAYTESTS/GODOT_PARITY_PLAYTEST.md`**.

1. **Feel del personaggio** (Fase 5): F5 dall'editor, oppure la build Windows.
2. **Test A percettivo** (Fase 7): `docs/PLAYTESTS/TERRAIN_GRID_SLICE_A_2026-09-22.md`.
3. **Steam Deck**: scegliere Proton (build Windows) o Linux nativa (`Prototype01.x86_64`, decisione aperta) e ripetere il Test B dello stesso documento.

## Fase 10 — stato

Fatto il 3 ottobre 2026:

- `feature/godot-migration-foundation` integrato in `main` in fast-forward e pubblicato su `origin` su richiesta del proprietario.
- Documenti vivi aggiornati a Godot: `README.md`, `AGENTS.md`, `CLAUDE.md`, `PROJECT_ROADMAP.md` (tabella strumenti), `PLATFORM_AND_INPUT.md` (implementazione input), `PROJECT_BRIEF.md`, `TOOLS_AND_LICENSES.md`, `RISK_REGISTER.md` (R-011), `AI_HANDOFF_PROTOCOL.md`, `TERRAIN_SYSTEM.md`, `ART_DIRECTION.md`. Nota di aggiornamento in `PROTOTYPE_01_SPEC.md` e `BLENDER_UNREAL_ROUNDTRIP_SPEC.md`.
- Lasciati invariati perche storici: `UNREAL_EDITOR_WORKFLOW.md`, `SMOKE_TEST_*.md`, `INPUT_MOVEMENT_SLICE_*.md`, `STORAGE_AUDIT_*.md`, i playtest, `DECISIONS.md` (le decisioni superate restano con il loro stato).

### Decisioni del proprietario sul progetto Unreal (3 ottobre 2026)

- **Codice Unreal rimosso da `main`** (`Source/`, `Content/`, `Config/`, `Prototype01.uproject`, `Scripts/CreateSmokeMap.py`), dopo il tag annotato `unreal-prototype-final` pubblicato su `origin`. Per leggere un sorgente: `git show unreal-prototype-final:Source/Prototype01/Prototype01Character.cpp`.
- **`LocalBuilds/Prototype01-CharacterFeel-Win64-v4` eliminata.** `Prototype01-TerrainGrid-Win64-v1` va eliminata **dopo il playtest di parita**, dove serve da confronto.
- **Unreal Engine resta installato.** Visual Studio Community 2026 disinstallato su richiesta del proprietario.
- **Build Windows primaria** (D-026), anche per Steam Deck via Proton.
- Le regole `.gitignore` per i residui Unreal restano: innocue, e utili finche UE e installato.
- `dev/` e `output/`: risolto il 5 ottobre 2026. `dev/` (copia vagante degli hook LFS) e i documenti Unreal in `output/` eliminati; `output/` resta come cartella delle catture, ignorata da Git.

## Review indipendente del 3 ottobre 2026

Review del codice Godot fatta da un agente separato. Corretto:

- **grilletto destro**: applicava il tool piu volte per pressione (ogni variazione analogica era un nuovo comando); ora una volta per pressione, come `Started`. Bug reale su controller e Deck, invisibile ai test basati su azioni simulate;
- **modificatori**: Shift/Ctrl bloccavano dash e tool; ora ignorati come in Unreal;
- **soglia dello stick di movimento**: 0,5 sul modulo grezzo come il trigger `Down` di `IA_Move` (prima 0,2 con riscalatura);
- comandi del tool eseguiti nel passo fisico; corsia dell'hazard ricalcolata quando la griglia si ricostruisce e corretta su griglia scalata; il rig camera non riscrive piu la propria trasformazione nell'editor.

Nuova suite `tests/input_events_tests.gd`. Build Windows e Linux riesportate dopo le correzioni.

Non corretto, annotato: la mira mouse usa la posizione fisica del personaggio e la camera interpolata (scarto massimo di un passo, simile a Unreal).

## Cosa serve dal proprietario

Protocollo unico con tabelle da compilare: **`docs/PLAYTESTS/GODOT_PARITY_PLAYTEST.md`**.

1. **Feel del personaggio** (Fase 5): F5 dall'editor, oppure la build Windows.
2. **Test A percettivo** (Fase 7): `docs/PLAYTESTS/TERRAIN_GRID_SLICE_A_2026-09-22.md`.
3. **Steam Deck**: scegliere Proton (build Windows) o Linux nativa (`Prototype01.x86_64`, decisione aperta) e ripetere il Test B dello stesso documento.

## Fase 10 — stato

Fatto il 3 ottobre 2026:

- `feature/godot-migration-foundation` integrato in `main` in fast-forward e pubblicato su `origin` su richiesta del proprietario.
- Documenti vivi aggiornati a Godot: `README.md`, `AGENTS.md`, `CLAUDE.md`, `PROJECT_ROADMAP.md` (tabella strumenti), `PLATFORM_AND_INPUT.md` (implementazione input), `PROJECT_BRIEF.md`, `TOOLS_AND_LICENSES.md`, `RISK_REGISTER.md` (R-011), `AI_HANDOFF_PROTOCOL.md`, `TERRAIN_SYSTEM.md`, `ART_DIRECTION.md`. Nota di aggiornamento in `PROTOTYPE_01_SPEC.md` e `BLENDER_UNREAL_ROUNDTRIP_SPEC.md`.
- Lasciati invariati perche storici: `UNREAL_EDITOR_WORKFLOW.md`, `SMOKE_TEST_*.md`, `INPUT_MOVEMENT_SLICE_*.md`, `STORAGE_AUDIT_*.md`, i playtest, `DECISIONS.md` (le decisioni superate restano con il loro stato).

### Proposta sul progetto Unreal (da decidere)

Inventario: `Source/` (94 KB, 15 file), `Content/` (400 KB, la sola mappa), `Config/` (4 file), `Prototype01.uproject`, `Scripts/CreateSmokeMap.py`: meno di 1 MB versionato. Fuori da Git: `LocalBuilds/Prototype01-TerrainGrid-Win64-v1` (872 MB), `LocalBuilds/Prototype01-CharacterFeel-Win64-v4` (871 MB), `Artifacts/Playtests` (274 MB, da conservare comunque).

Raccomandazione, **dopo** i playtest del proprietario:

1. Tag Git `unreal-prototype-final` sul commit corrente: il progetto Unreal resta recuperabile per sempre dalla cronologia.
2. Rimuovere da `main` `Source/`, `Content/`, `Config/`, `Prototype01.uproject`, `Scripts/CreateSmokeMap.py` e le regole `.gitignore` solo-Unreal. Peso irrilevante, ma toglie ambiguita a chi apre il repository.
3. Eliminare `LocalBuilds/Prototype01-CharacterFeel-Win64-v4` (superata). Tenere `Prototype01-TerrainGrid-Win64-v1` finche il proprietario conferma la parita di feel, poi eliminarla: l'archivio con hash in `Artifacts/Playtests` resta come evidenza.
4. Disinstallare UE 5.8.2 e Visual Studio 2026, se non servono ad altro: decisione del proprietario, fuori dal repository.

Nessuno di questi passi e stato eseguito.

## Arena grande (6 ottobre 2026)

- `TerrainGrid` presenta le celle con tre MultiMesh e un solo `StaticBody3D` con una forma per cella Raised (D-042). Le suite che contavano le celle come nodi figli usano ora `presented_cell_count()`; `TerrainTuning` ammette fino a 201 celle per lato.
- `PathField` aggiorna gli ostacoli del terreno una volta per passo (bandiera sporca), non a ogni `cell_changed`: la disposizione iniziale cambia centinaia di celle.
- `OvergrownArena` espone `_compose()` e i parametri del suolo (`plaza_radius()`, `ground_size()`, copertura); `RuinsDistrict` li sovrascrive e produce `terrain_features`, che `ArenaRun` applica alla griglia (`PROTOTYPE01_TERRAIN_LAYOUT_READY`).
- Nuovi strumenti: `tests/district_tests.gd` (suite), `tests/tools/benchmark_arena.gd`, `tests/tools/capture_district.gd`. Catture in `output/district/`.
- Trappola nuova in `GODOT_WORKFLOW.md`: in headless i colori dei MultiMesh non si rileggono.
- **Non fatto:** misura su Steam Deck.

## Boss (6 ottobre 2026)

- `Demolisher` (`scripts/enemies/demolisher.gd`) estende `Enemy` con `self_driven = true`: l'`EnemyDirector` lo tiene in elenco (armi e scavo esplosivo lo colpiscono) ma chiama `drive()` invece di sterzarlo, e non lo riporta sull'anello.
- `ArenaRun` gestisce le fasi `WAITING / WARNING / ACTIVE / DEFEATED`, sceglie la direzione col seme della run (`run_seed + 2`) e chiude il livello; `GameOverPanel.open()` ha la variante vittoria.
- `TerrainGrid.force_cell_state()` cambia una cella a runtime senza regole ne rottami; `set_raised_tint()` colora le barricate.
- Avvio rapido del boss: `-- --boss-at=60`. Catture in `output/boss/`.
- Indicatori a bordo schermo (D-044): `ArenaRun.current_markers()` e `RunHud.set_markers()`.
- Build Windows e Linux riesportate il 6 ottobre 2026 dopo boss e indicatori; smoke test della build Windows superato, Linux non eseguita.
- Rottamatori al lavoro (D-045): `Enemy.set_errand()` / `errand_reached`, seguiti dall'`EnemyDirector` al posto del giocatore; `Demolisher` gestisce squadra (`_crew`), cantiere (`site_cell()`) e consegne; `ScrapField.positions_near()`, `spawn_on_cell()`, `spawn_on_ground()`. Cattura `output/boss/crew.png`.
- Passata artistica (D-046): `RuinsDistrict._ruin_shell()` / `_shell_piece()` (cubo unitario condiviso, collisione a blocco pieno), `vine_reach` in `ruin_overgrown.gdshader`, `raised_top` in `terrain_cell.gdshader`. `capture_district.gd` accetta `--visit=x,z`.
- Frammenti (D-047): `scripts/effects/debris_burst.gd` (`DebrisBurst.spawn()`), chiamato da `EnemyDirector`, `Demolisher` e `ArenaRun`.
- Audio (D-048): `scripts/audio/sfx_library.gd`, `scripts/audio/run_audio.gd` (nodo `RunAudio` in `arena_run.tscn`, `play(id)`), `default_bus_layout.tres`, volumi in `GameSettings` e slider in `pause_menu.tscn`; nuovi segnali `PlayerCharacter.terrain_tool_rejected`, `LevelUpMenu.opened`, `ArenaRun.boss_spawned`, `Demolisher.scrap_taken`. Suite `tests/audio_tests.gd` (15 suite in tutto).
- Build Windows e Linux riesportate il 6 ottobre 2026 dopo D-045...D-048; smoke test della build Windows superato, Linux non eseguita.
- Officina (D-049): autoload `PlayerProfile` (`scripts/services/player_profile.gd`, `user://profile.cfg`), `scripts/progression/permanent_catalog.gd`, `scripts/ui/workshop_panel.gd` (nodo `WorkshopPanel` in `arena_run.tscn`), `ArenaRun._apply_permanent_upgrades()` e `_bank()`, `PlayerCharacter.tool_range_bonus_cm`. Suite `tests/workshop_tests.gd`, catture `tests/tools/capture_workshop.gd`.
- Modelli degli attori (D-050): `tools/blender/build_actor_assets.py`, `assets/models/{player_engineer,companion_cart,scavenger,demolisher,demolisher_blade}.glb`, `resources/materials/actor_paint.gdshader`, `scripts/core/actor_model.gd` (`ActorModel`), `tests/tools/capture_actors.gd`. Build riesportate dopo D-049 e D-050; smoke test della build Windows superato.
- Menu (D-051): `scenes/main/main_menu.tscn` + `scripts/ui/main_menu.gd`, scena principale in `project.godot`; `PauseMenu.enabled`, `open_settings_only()`, `return_to_menu()`; il gate passa `-- --autostart`. Mappa (D-052): `scripts/ui/run_map.gd` (`RunMap`), `GameOverPanel.set_map()` / `save_map()`, `ArenaRun.build_run_map()`. Suite `tests/menu_tests.gd`.
- Impronte (D-053): `scripts/navigation/flow_preview.gd` (nodo `FlowPreview` in `arena_run.tscn`), `resources/materials/flow_mark.gdshader`. Movimento (D-054): `scripts/core/actor_motion.gd` (`ActorMotion.enabled`), `PlayerCharacter.kick()` e `recoil_source`, `Enemy.notify_contact()`, `AutoWeapon.last_fire_direction`. Economia (D-055): `RunTuning.survival_scrap_seconds`, `ArenaRun.survival_scrap()`, `tests/tools/simulate_runs.gd`. Suite nuove: `flow_preview_tests.gd`, `actor_motion_tests.gd` (19 in tutto). Build riesportate dopo D-051...D-055.
- Correzioni D-056: `ScrapField.bare_ground_yields_scrap` (falso in `arena_run.tscn`), `RunTuning.recovery_scrap_levels` e gruppo Runners, `ArenaRun.recovery_scrap()`, `EnemyDirector.spawn_at(world, runner)` e `current_runner_share()`, `Enemy.speed_scale`, `RunProgression.fillers()`, `PlayerCharacter.heal()`, level-up aperto da `ArenaRun._physics_process`. Suite `tests/economy_tests.gd` (20 in tutto). `simulate_runs.gd` ha `--trace=N`. Build riesportate.
- Segnalato e non corretto: `Companion.mount_part` con un nome gia montato lascia il nuovo pezzo con un nome generato (innocuo oggi: ogni pezzo si monta una volta).
- Personaggi animati (D-060): `tools/blender/build_character_assets.py` (scheletro e animazioni CC0 di Quaternius in `tools/blender/third_party/quaternius_ual/`, riproporzionati; pezzi rigidi), `player_engineer.glb` ora con scheletro e 8 animazioni, `scripts/core/character_animator.gd` (`CharacterAnimator.attach(model)`), `scripts/core/hip_twist_modifier.gd`, `PlayerCharacter._animator`; rimosso il saltello procedurale del passo. Suite `tests/character_animator_tests.gd`, catture `tests/tools/capture_character.gd` (`output/character/`). Gate verde; **build non riesportate**; resa in movimento da giudicare dal proprietario.
- Strumenti Blender (D-061): MCP for Blender installato (addon abilitato, server `blender` registrato in Claude Code per questo progetto, telemetria spenta) e Rigify abilitato; Mixamo e un servizio web con account Adobe del proprietario, niente da installare. **Non provato con Blender aperto.**
- **Non fatto:** animazioni dedicate a dash, scavo e tiro, ascolto dell'audio, bilanciamento, Officina e profilo permanente, musica, Steam Deck.

## Addon Godot (6 ottobre 2026)

Installati quattro addon in `godot/addons/` (D-057, elenco e licenze in `TOOLS_AND_LICENSES.md`, uso e trappole in `GODOT_WORKFLOW.md`): Debug Menu (F3), Controller Icons, Debug Draw 3D attivi; SimpleGrassTextured installato ma spento. Nuova suite `addons_tests.gd`; il gate salta `--check-only` in `godot/addons`. Export Windows e Linux riusciti in una cartella temporanea e smoke test della build Windows superato; **le build in `LocalBuilds/` non sono state riesportate**.

**Glifi dei tasti (D-059)**: `scripts/ui/button_prompts.gd` (`ButtonPrompts.create([[azione, testo], ...], in_colonna)`) e usato da menu iniziale, Officina, pausa, level-up, fine livello e HUD. Suite `button_prompts_tests.gd`; viste catture con tastiera e con controller Xbox simulato. Non visti: Steam Deck, controller PlayStation reale.

Prossimi passi possibili: misura su Steam Deck con il Debug Menu; visualizzazione di debug del campo di percorso con Debug Draw 3D.

## Da non dimenticare

- **Non estendere il progetto Unreal.** E materiale di riferimento da leggere, non da far evolvere.
- **Il riferimento Unreal si legge dal codice sorgente**, non avviando editor o build: il proprietario non vuole che si apra Unreal.
- **Il codice Unreal non e piu in `main`**: si legge dal tag `unreal-prototype-final`, non va ripristinato nel working tree.
- **Quando arrivera la UI:** l'azione predefinita `ui_accept` usa Spazio e il pulsante A, gli stessi del dash. I Control di gioco vanno tenuti con `focus_mode = NONE` oppure `ui_accept` va rimappata, o un Control con focus si prendera il dash.
- **Non cancellare `Artifacts/Playtests/`**: unica evidenza con hash del playtest Slice A superato, non ricostruibile dopo la rimozione di Unreal.
- La parita di feel del personaggio (Fase 5) **va playtestata dal proprietario**, non dichiarata da un agente.
- Il rischio aperto piu serio e **R-G1**, la resa grafica senza Lumen e Nanite rispetto a `ART_DIRECTION.md`. Si manifestera alla vertical slice, non adesso.

## Comandi di lavoro

```bash
# validare uno script senza eseguirlo
godot_console --headless --path godot --check-only --script res://percorso.gd

# eseguire e leggere i log
godot_console --headless --path godot --quit-after 120

# gate completo (check-only, test, smoke test); con -Executable verifica una build
powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1

# export
godot_console --headless --path godot --export-release "Windows Desktop" ../LocalBuilds/Prototype01-Godot-Win64/Prototype01.exe

# verifica visiva (serve una finestra reale, mai --headless)
godot_console --path godot --resolution 1280x800 --quit-after 240 res://scena.tscn

# aprire l'editor
godot --path godot --editor
```

Usare sempre `godot_console`, mai `godot`, per i comandi non interattivi: il secondo non scrive su stdout. Passare sempre `--quit-after`. Spiegazione e trappole in `GODOT_WORKFLOW.md`.

## Decisioni aperte

- formato delle risorse di tuning `.tres` (chiusura della Fase 2);
- `LocalBuilds/` Unreal (1,74 GB): da conservare o rimuovere (proposta Fase 10);
- se e quando installare un MCP Godot: trigger in `GODOT_WORKFLOW.md`.

## Ciclo giorno/notte (6 ottobre 2026)

- **Specifica approvata, niente codice:** `docs/DAY_NIGHT_SPEC.md` (D-058). Una notte per livello, nemici piu forti al buio, torcia e faro con upgrade, lampioni piazzabili. Due tappe: (1) notte giocabile, (2) lampioni.
- **Prossimo passo:** revisione della specifica da parte del proprietario, poi piano di implementazione della tappa 1.
