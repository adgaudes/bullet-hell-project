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

Trappola verificata (9 ottobre 2026): in headless la finestra e 64x64 con stretch `canvas_items`, quindi `InputEventMouseMotion.relative` arriva ai nodi **moltiplicato per 20** circa. Un test che simula il mouse deve dividere per `root.get_final_transform().get_scale()` (vedi `_mouse_motion` in `tests/input_events_tests.gd`).

```bash
godot_console --headless --path godot --fixed-fps 60 --script res://tests/player_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/live_rebuild_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/input_events_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/caravan_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/run_progression_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/arena_run_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/path_field_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/audio_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/workshop_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/menu_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/flow_preview_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/actor_motion_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/economy_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/day_night_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/lamp_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/height_terrain_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/railway_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/train_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/driller_tests.gd
godot_console --headless --path godot --fixed-fps 60 --script res://tests/campaign_tests.gd
```

Al 17 ottobre 2026 le suite in `godot/tests/` sono 58 (il gate le trova da solo; `terrain_tests`, `terrain_tool_tests` e `slice_b_tests` sono sparite con la griglia, D-087). Dal 9 ottobre il gate **fallisce anche se una suite stampa `SCRIPT ERROR` o `ERROR:`** (allowlist **per suite** in `Invoke-GodotChecks.ps1` dal 14 ottobre 2026: `settings_tests` ammette `Parameter "material" is null` del renderer fittizio e il parse error del file illeggibile provocato apposta, `workshop_tests` il parse error del profilo illeggibile; negli smoke test nessuna eccezione): un errore runtime provocato apposta da un test va stampato come marker, non con `push_error`. Regola dal 9 ottobre 2026 (T-12): una suite che ha fatto `queue_free()` di una scena attende due `physics_frame` prima di `quit()`, altrimenti il motore segnala istanze ObjectDB perse all'uscita.

Piu semplice: `tools/godot/Invoke-GodotChecks.ps1` esegue tutte le suite presenti in `godot/tests/`.

`--fixed-fps 60` rende ogni frame un passo fisico da 1/60 s, ma **il seme della run e casuale** se non si passa `-- --seed=N` o la variabile `PROTOTYPE01_SEED` (letta da `RunLaunchOptions.run_seed`; il gate la imposta per tutte le suite, `-Seed` per cambiarla, e stampa il seme di una suita fallita con il log intero in `output/gate/`). Il seme compare nella riga `PROTOTYPE01_RUN_START`: un rosso si riproduce con quello (audit K-01, D-01; caso reale: `quake_tests` con il seme 1026822462). Esito su stdout (`PROTOTYPE01_TESTS PASS|FAIL`) ed exit code 0/1. Trappola verificata: in headless la posizione del cursore del viewport non segue gli eventi mouse simulati; testare la logica sulla posizione schermo esplicita.

Trappola verificata: `CollisionShape3D.set_deferred("disabled", ...)` lascia la forma attiva per un frame; se applicato in costruzione spinge via i corpi sovrapposti. In costruzione impostarlo direttamente, a runtime differito.

Trappola verificata: `InputEvent.is_action_pressed()` e vero per **ogni** `InputEventJoypadMotion` sopra la dead zone, e un grilletto analogico ne invia uno a ogni variazione. Per azioni "una volta per pressione" serve il rilevamento del fronte (vedi `PlayerCharacter.STARTED_ACTIONS`). Il terzo argomento `exact_match = true` blocca l'azione se e premuto un modificatore. I test che usano solo `InputEventAction` o `Input.action_press` non vedono questi casi: `tests/input_events_tests.gd` usa eventi joypad e tasti reali.

Trappola verificata: nella numerazione Godot dei pulsanti joypad il **4 e Back/View**, non il dorsale sinistro (che e il 9, `JOY_BUTTON_LEFT_SHOULDER`). Usare le costanti `JOY_BUTTON_*` per controllare `project.godot`.

Trappola: il progetto usa 120 passi fisici al secondo; i test fissano `Engine.physics_ticks_per_second = 60` in `_initialize` perche i valori attesi sono calcolati a 60 Hz.

Trappola verificata: **il nome globale di un autoload non esiste** in `--check-only` ne nei test con `--script` (le scene precaricate dallo script di test si compilano prima che gli autoload siano registrati). Uno script che scrive `GameSettings.x` non compila e il test resta appeso senza `quit()`. Raggiungere l'autoload a runtime con `get_node("/root/GameSettings")`, tipizzato con la `class_name` `GameSettingsService`.

Trappola verificata: in Godot 4.7 le azioni predefinite **`ui_accept` e `ui_cancel` non hanno pulsanti joypad**. Il progetto le ridefinisce con A e B: senza, i menu non si confermano col controller.

Trappola verificata (9 ottobre 2026): in `--headless` `get_instance_transform` di un MultiMesh restituisce la sola origine, con base identita: le scale per istanza (lotto piatto della griglia, T-07) si verificano solo con finestra. Trappola verificata (6 ottobre 2026): in `--headless` il renderer fittizio **non conserva colori e dati custom dei MultiMesh** (`get_instance_color` e `get_instance_custom_data` restituiscono zero; le trasformazioni si). Un test headless puo verificare `use_colors`, `use_custom_data` e i conteggi, non i valori: per quelli serve una cattura con finestra.

Trappola verificata (6 ottobre 2026): un `CPUParticles3D` creato da codice va **posizionato prima di `add_child`** (`top_level = true` e `position`): con `global_position` impostata dopo l'ingresso nell'albero i frammenti di un'emissione `one_shot` partono dall'origine. Nessun test headless lo vede: l'ha mostrato una cattura.

Trappola verificata (14 ottobre 2026): una risorsa caricata **da percorso** e tenuta in una variabile `static` (cache di `SfxLibrary`) resta viva fino allo scaricamento dello script, dopo il controllo d'uscita del motore: `ERROR: N resources still in use at exit`, che il gate conta come errore runtime. Caricarla con `ResourceLoader.CACHE_MODE_IGNORE` (anche in `load_threaded_request`) e farla servire dalla cache della classe. Le risorse create con `new()`, senza percorso, non danno il problema.

Effetti sonori (D-084): `python -I tools/audio/build_sfx.py [--only=id1,id2] [--preview]` rigenera `godot/assets/audio/sfx/*.ogg` dalle ricette in testa al file (sorgenti estratti dagli zip Sonniss in `Videogame-assets/sonniss-cache/`, fuori repo; serve `ffmpeg` nel PATH); `--preview` scrive `output/audio/sfx_preview.wav` con tutti i suoni in fila. Dopo un file **nuovo** importare con `godot_console --headless --path godot --editor --quit`. Il `drawtext` di ffmpeg va in crash su questa macchina (fontconfig): per gli spettrogrammi di controllo usare `showspectrumpic` senza testo.

Trappola verificata (6 ottobre 2026, estesa l'11 ottobre 2026 alle texture `.png` di `godot/assets/textures/surfaces/` e `godot/assets/models/`, che gli script caricano con `load()` a runtime proprio per non dipendere da LFS a tempo di compilazione; senza `git lfs pull --include="godot/assets/**"` le tile mancano e il suolo resta senza texture): in un **worktree nuovo** i modelli `.glb` sono puntatori Git LFS: il primo `--editor --quit` fallisce l'import e scrive `valid=false` nei `.glb.import`. Prima `git lfs checkout`, poi l'import; se i `.import` sono stati sporcati, ripristinarli da Git. In headless l'audio usa un driver fittizio: i test contano le riproduzioni (`RunAudio.play_counts`), non possono ascoltarle.

Trappola verificata (4 ottobre 2026): una **nuova `class_name`** non e visibile a `--check-only` ne ai test finche la cache delle classi globali non e aggiornata (`Could not find type ...`). Aggiornarla con `godot_console --headless --path godot --editor --quit`, oppure aprendo l'editor una volta.

Asset Blender (D-037): `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_arena_assets.py -- [nome ...]`, poi `godot_console --headless --path godot --editor --quit` per importare i `.glb` (genera i `.import`, da versionare). Le righe `ASSET_EXPORTED` riportano misure e triangoli.

Catture multiple dell'arena (vista di gioco, panoramica, nord, ovest, nord-est), con finestra reale: `godot_console --path godot --resolution 1280x800 --script res://tests/tools/capture_arena.gd -- --out=../output/arena`. Gli script in `tests/tools/` non sono suite: il gate non li esegue.

Luce del quartiere a confronto (playtest del 14 ottobre, O-07): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 4000 --script res://tests/tools/capture_lighting.gd -- --out=../output/lighting --preset=4` cattura la stessa inquadratura con tutto acceso e senza ombre, SSAO, GI e nebbia volumetrica (`p<preset>_*.png`). Trappola verificata: sul preset Massimo la nebbia volumetrica a densita 0,012 velava tutto il campo (la camera guarda attraverso 15-25 m d'aria) e schiariva le ombre; il Massimo rendeva peggio dell'Alto.

Texture CC0 (D-090, 14 ottobre 2026): `python -I tools/textures/fetch_terrain_textures.py` (strati del terreno) e `python -I tools/textures/fetch_wall_textures.py` (fogli `walls` delle rovine) scaricano da Poly Haven e ambientCG in `tools/textures/third_party/` (ignorata da Git) e impacchettano; `--no-download` rifa solo l'impacchettamento. Poi cancellare i `.md5` dei file toccati in `godot/.godot/imported/` e `godot_console --headless --path godot --editor --quit`. Trappole verificate: un PNG da 2048 RGBA pesa circa 11 MB, sette strati per due mappe facevano 154 MB nel repo; a 1024 sono 41 MB e dalla camera (circa 40 px/m) non si vede differenza. ambientCG interrompe a volte il download a meta (`IncompleteRead`): lo script riprova. Lo shader delle rovine e triplanare in coordinate mondo: i moduli generati (`RuinModules`) non hanno UV; le loro facce vanno emesse in senso orario (Godot), altrimenti si vede l'interno nero. **Mai consumare `_rng` in piu nella costruzione del quartiere**: sposta tutta la disposizione successiva (e il rilievo cotto che ne dipende); per le varianti si usa un hash del nome.

Prato a particelle (O-09): `GrassField` (`scripts/terrain/grass_field.gd`) nasce in `ArenaRun._spawn_grass_field` quando Terrain3D e pronto (solo con finestra; in headless restano i ciuffi del MultiMesh, che i test controllano). Trappola verificata: il terreno puo essere gia pronto quando ci si collega a `render_ready` (le pennellate del livello dipingono subito), quindi si controlla anche `terrain3d() != null`. Densita dalla vegetazione (spaziatura 0,55 / 0,42 / 0,32 m). `editor --quit` riordina a volte `[physics]` in `project.godot`: e solo rumore, non committarlo.

Menu 3D (O-12): `MenuDiorama` (`scripts/ui/menu_diorama.gd`) costruisce sotto il menu un `TerrainField` da 96 m e un `MenuDistrict` (sottoclasse di `RuinsDistrict` con `_compose` a mano e luce al tramonto); solo con finestra, in headless restano cielo e sagome 2D (i test le controllano). Catture: `capture_ui.gd`. Trappola verificata: col sole di fronte alla camera il riflesso radente sul terreno sembrava acqua; il sole va spostato di lato. Impostazioni a schede (O-11): le schede le costruisce `SettingsMenu._build_tabs` sopra le righe della scena; una riga nascosta non prende il focus, quindi i test passano prima alla scheda giusta (dorsale destro). Gli script Python di patch con apostrofi vanno passati da file, non da heredoc della shell.

Benchmark del campo di percorso su un'arena sintetica grande (D-039): `godot_console --headless --path godot --fixed-fps 60 --script res://tests/tools/benchmark_path_field.gd -- --extent=240 --walls=400 --window=64` (righe `BENCH`; con `extent` fino a 240 confronta anche il campo intero).

Catture della run (combattimento e level-up): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_run.gd -- --out=../output/run`.

Catture ravvicinate con camera libera (D-068, per giudicare i dettagli che la camera di gioco mostra da lontano): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 3000 --script res://tests/tools/capture_closeup.gd -- --out=../output/district --at=62,1.5,62 --from=50,7,76 --name=ruin_close` (ogni terna `--at/--from/--name` e una cattura; `--scene=railway` per il livello 2).

Catture dell'arena grande (D-042: partenza, panoramica dall'alto di tutta l'arena senza nebbia, combattimento dopo un minuto): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_district.gd -- --out=../output/district`. Con `--visit=x,z` (ripetibile) salva anche la vista di gioco col giocatore in quel punto (`visit_0.png`, ...) ed esce senza la cattura del combattimento: utile per guardare da vicino rovine e oggetti.

Attori rifiniti (D-072): lo stesso comando di D-050 senza nomi costruisce i sei modelli rifiniti con bake (circa un minuto l'uno); `-- scavenger_blocky` ecc. ricostruisce i vecchi. Il costruttore condiviso e `tools/blender/refined.py`. Trappola verificata (9 ottobre 2026): un modello rifinito ha UV vere, quindi lo shader `actor_paint` (che legge gli indicatori nelle UV) non va piu usato su di esso: `ActorModel.textured_paint()` e `dress()` scelgono da soli in base alla presenza della texture. Le copie dei materiali con il contorno vivono come metadato del materiale importato: una cache `static` di materiali resta viva all'uscita e il gate conta i RID persi come errori.

Armi e classi (D-092, piano 1): `-- --class=<id>` (`engineer`, `sapper`, `mechanic`, `weeder`) avvia subito il livello con quella classe (le classi senza armi implementate partono senza armi); il marker `PROTOTYPE01_LOADOUT class=... weapons=...` dice cosa e montato. Catture `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 6000 --script res://tests/tools/capture_weapons.gd -- --out=../output/weapons`; con `--quit-after 3000 ... -- --out=../output/caravan --caravan` la sola cattura `caravan_strip` (carovana D-093: striscia sopra le armi, tasto Ripara, frecce degli indicatori sopra la colonna) e la riga `PROTOTYPE01_CAPTURE_CARAVAN column_top=... marker_y=...`. Il benchmark stampa anche `PROTOTYPE01_ARENA_BENCH weapons worst_ms=...` (chiodatrice e picchetto al 5, anello chiodato alzato; budget 1,0 ms). Trappola verificata: `physics_frame` arriva **prima** del passo fisico dei nodi: un test che aspetta un passo e poi controlla l'effetto deve aspettare due segnali. I dati delle armi stanno in `WeaponCatalog` (valori per livello con chiavi `_mul`/`_add`/`_set`); lo script di un'arma sta in `scripts/combat/weapons/<id>.gd` e `WeaponLoadout.script_for` lo trova dal percorso (piano 3; la chiodatrice e `AutoWeapon`).

Armi, piano 2 (kit comune e fusioni): servizi condivisi `Enemy.stun(s)` (il direttore non muove lo stordito, la velocita si azzera subito ma una spinta data dopo resta; i boss `self_driven` lo ignorano; lo stordito non rosicchia) e `PlayerCharacter.start_charge(dir, m, s)` (carica intoccabile dell'Ariete; falso se morto, in scatto o gia in carica; `grant_invulnerability`). Una fusione non crea un nodo: l'automatica prende `fusion_id` e legge l'effetto con `fusion_stat`, l'attiva compagna esce dagli slot. Trappole verificate: **ogni scrittura delle armi sul terreno passa da `TerrainWriteQueue`**, che dopo un rialzo solleva i nemici sul disco e tiene `bodies` (giocatore, compagno) alla stessa altezza sul suolo: un rialzo secco li incastrerebbe nella heightfield; le scritture che devono arrivare prima del giocatore (la spianata davanti all'Ariete) vanno con `urgent = true`, altrimenti una coda piena (anello, pozza) le fa arrivare tardi; scavi a profondita fissa vanno scritti verso `base - profondita` e solo se il suolo e piu alto, non verso `height_at - profondita`, che a ogni passaggio scava di piu. Nelle catture con finestra le attive mirano al cursore del mouse: forzare `_set_aim_device(GAMEPAD)`; un level-up aperto mette in pausa tutto, quindi alzare `progression.xp_first_level` e azzerare `_pending_level_ups`.

Armi, piano 3 (classi): servizi `Enemy.slow(factor, s)` (vale il piu forte; i boss lo ignorano) ed `Enemy.drift` (m/s planari che il direttore somma e azzera a ogni passo: chi attira la rimette a ogni passo; ignorata da storditi e boss); `EnemyDirector.meadow_slow` e `gnaw_scale`; `MeadowMap` (prato logico a celle da 1 m, riempito da `RuinsDistrict.fill_meadow`: il prato a particelle e solo GPU; una cella vale prato se la quota non si scosta dalla base, salvo quelle segnate `on_relief` da Semi in tasca). Il loadout passa alle armi i servizi `write_queue`, `caravan` (prima `companion`, piano A della carovana), `xp_field`, `scrap_field`, `meadow` se l'arma ha una proprieta con quel nome (`give_services`), **dopo** `add_child`: nel `_ready` dell'arma sono ancora null. Le carte non arma dei mazzi di classe stanno in `ClassPerks` (`ArenaRun.apply_upgrade` passa li le carte che riconosce). Catture e benchmark per classe: `capture_weapons.gd -- --class=<id>` (`<classe>_auto`, `_active`, `_auto5`, `_active5`, `_fusion`; l'Ingegnere aggiunge `fort`) e `benchmark_arena.gd -- --class=<id>` (righe `weapons` e `weapons_fused`). Trappole verificate: `UpgradeCatalog.value` ricostruisce il catalogo a ogni chiamata, quindi i valori delle carte si leggono in `apply` e non a ogni passo; `WeaponCatalog.branch_options` su una fusione restituisce vuoto (le fusioni non hanno `branches`); i test che danno per scontato un kit vuoto devono usare una classe inesistente (`&"nobody"`), perche ora tutte e quattro hanno armi; per i test di movimento (rallentamenti, deriva) il direttore ha bisogno di `player`, altrimenti non muove nessuno. **Uno script che si riferisce al proprio `class_name`** (es. `AutoWeapon.new()` o `Array[AutoWeapon]` dentro `auto_weapon.gd`) tiene vivi gli script all'uscita: le suite passano ma il gate le segna rosse per "resources still in use" e RID persi anche in suite estranee (`button_prompts_tests`, `ui_theme_tests`), e a volte Godot va in crash all'uscita; usare `get_script().new()` e il tipo base.

Armi, piano 4 (casse, Officina, classe): la classe della run viene da `--class=`, altrimenti da `PlayerProfile.last_class` (la sceglie la mappa della campagna); gli sblocchi delle armi comuni sono voci `unlock_<arma>` di `PermanentCatalog` (`profile.unlocked_weapons()`), e sotto `--script` il profilo e vuoto, quindi nei test e nelle catture le armi comuni non compaiono fra le carte finche il test non le sblocca nel profilo. Gli upgrade permanenti di una classe si applicano solo giocandola (`ArenaRun._apply_permanent_upgrades`); le modifiche alle armi passano da `WeaponLoadout.set_weapon_mods` (chiavi dei bivi). Casse sepolte: `BuriedCaches` (marker `PROTOTYPE01_CACHE_PLACED`/`_OPENED`/`_OFFER`), si aprono quando il suolo scende entro 0,1 m dalla base; Relitti sepolti (D-093): `MachineWrecks`, sottoclasse di `BuriedCaches` con luccichio arancione e telaio a vista (marker `PROTOTYPE01_WRECK_PLACED`/`_OPENED`/`_OFFER`/`_CHOSEN`/`_SCRAP`). `ArenaRun` mette in coda casse, relitti e level-up e apre un menu alla volta, in quest'ordine. Trappola verificata: un test che ricarica il rilievo di base (`load_base`) o riporta alla base un cumulo o la fascia dei binari apre casse e relitti e il loro menu mette in pausa il gioco: scartarli prima con `ArenaRun.discard_buried_in_rect(rect)`, come fa il treno. Trappola verificata (17 ottobre 2026): `TerrainField.reset_to_base` arrotonda il rettangolo verso l'esterno alla griglia di 0,5 m e la quota di un punto viene dai vertici della sua cella, quindi una cassa o un relitto fino a 1 m fuori dal rettangolo si apre lo stesso: il treno scarta casse e relitti col rettangolo allargato di due celle.

Armi, piano 5 (effetti): gli effetti delle armi passano da `WeaponFx` (`burst`, `shockwave`, `dust` anche ad anello con `ring`, `sparks`), nascono sotto `Weapon.fx_parent()` (il direttore: un'arma tolta o fusa non tronca l'effetto), stanno nel gruppo `weapon_fx` e si liberano da soli; oltre `MAX_LIVE` (40) l'effetto si salta; gli effetti frequenti si chiedono con `minor = true` (polvere dei dischi, scie dell'Ariete, scintille a raffica) e si fermano `RESERVE` (10) posti prima, cosi onde e crateri delle attive trovano sempre posto. Le armi a raffica passano da `Weapon._fx_ready(key, s)` (al piu uno ogni `s` secondi di gioco); gli effetti di una fusione si marcano con `_fusion_fx(node)` (meta `fx_fusion`, letta da `weapon_fx_tests`). Scie dei rottami e delle falci: copie in una MultiMesh, nessun nodo. Catture: `capture_weapons.gd -- --fx` (una per arma e fusione, `fx_<id>`, scattata quando l'effetto e in scena). Costo: `benchmark_arena.gd -- --class=<id>` stampa `weapons_frame` (frame con le armi del caso peggiore che sparano davvero, effetti vivi); `--no-fx` lo stesso senza effetti (`WeaponFx.enabled`). **Trappole verificate:** la riga `weapons` chiama `_physics_process` a mano e non misura le particelle; dopo i level-up del caso peggiore la corsa riapre il menu e mette in pausa, quindi `weapons_frame` spegne il passo di `ArenaRun` durante la misura; per tenere vivo il giocatore nelle catture usare `grant_invulnerability`, non `set_max_health` alto: `HealthBolts` disegna un fulmine per punto e con 100000 PV esaurisce i RID ("Element limit reached").

Piazzola di estrazione (D-076): catture `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 3000 --script res://tests/tools/capture_extraction.gd -- --out=../output/extraction`; nei test che provano la vittoria diretta: `_run.extraction_pad = null` prima di abbattere il boss. Terremoto (D-075): `godot --path godot -- --quake-at=20` forza un terremoto a 20 s al posto della scelta casuale (D-097; 0 = nessuno). Eventi del mondo (D-097): istanti e tipi li sceglie `WorldEventScheduler` all'avvio (riga `PROTOTYPE01_WORLD_EVENTS`); nei test si forza un evento con `event.next_at = ...` o `event.schedule([...])`, e `schedule([])` lo spegne; sotto i test il servizio delle impostazioni parte dai default, quindi un evento per livello; catture `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 3000 --script res://tests/tools/capture_quake.gd -- --out=../output/quake`. Prop dell'ambiente rifiniti (D-073): `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_arena_assets.py` senza nomi costruisce i cinque modelli rifiniti con bake (`wrecked_car`, `train_carriage`, `overgrown_tree`, `concrete_barrier`, `lamp_post`, circa un minuto l'uno); `-- wrecked_car_blocky` ecc. ricostruisce i vecchi a blocchi; poi `godot_console --headless --path godot --editor --quit`. Catture ravvicinate: posizioni dei prop con `godot_console --headless --path godot --script res://tests/tools/list_props.gd --quit-after 300 [-- --scene=railway]`, poi `capture_closeup.gd`. Superfici, texture e colori di vertice di un `.glb` importato: `godot_console --headless --path godot --script res://tests/tools/inspect_model.gd --quit-after 100 -- --model=overgrown_tree`. Trappola verificata (10 ottobre 2026): **le uniform per istanza (`instance uniform`) di materiali diversi sullo stesso MeshInstance3D condividono gli indici**: se un modello ha una superficie su `env_baked` e una su `foliage`, la tinta deve avere lo stesso nome e lo stesso tipo in entrambi (`tint`), altrimenti `set_instance_shader_parameter` non arriva e la chioma resta bianca, senza errori a log.

Modelli degli attori (D-050): `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_actor_assets.py`, poi `godot_console --headless --path godot --editor --quit`. Catture ravvicinate e dalla camera di gioco: `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_actors.gd -- --out=../output/actors`.

Ingegnere con volto, normal map e pesi (D-074): stesso comando; il bake stampa `BAKED ... normal=True` e Godot estrae anche `player_engineer_PlayerEngineerMesh_normal.png` (`inspect_model.gd` mostra `normal=true` per superficie). Trappole verificate (10 ottobre 2026): la normal map si cuoce con un grafo a parte (BSDF con Bump: l'Emission del bake del colore non ha ingresso Normal) a 4 campioni; un materiale `StandardMaterial3D` creato dal codice **non eredita** la normal map del materiale importato, va copiata (`ActorModel.copy_normal_map`); i pesi sfumati vanno applicati **dopo** la cottura e prima del modificatore Armature. Ingegnere rifinito (D-071): stesso comando di D-060 (senza nomi costruisce `player_engineer`, il rifinito; `-- player_engineer_blocky` il vecchio a blocchi); il bake Cycles su CPU dura circa un minuto e stampa `BAKED`. Trappole verificate (9 ottobre 2026): i nodi Mix di Blender hanno piu prese con lo stesso nome, si prendono per `identifier` (`A_Color`, `Result_Color`); con la texture cotta l'export va fatto **senza** colore di vertice (`export_vertex_color="NONE"`), altrimenti Godot lo moltiplica alla texture; le coordinate `Object` del bake sono quelle dell'oggetto unito, con origine a terra.

Pittore condiviso (restyling 2026-10-11, D-077): `tools/blender/painter.py` cuoce per ogni modello **albedo, normal e ORM** (R occlusione, G roughness, B metallo) a 2048 per default (`RefinedBuilder(bake_size=, bake_normal=, bake_orm=)`); selftest in circa 20 s: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/selftest_painter.py` (stampa `PAINTER_SELFTEST PASS`). Un prop a 2048 cuoce in circa 30 s e il `.glb` pesa 8 MB con le tre texture dentro; Godot le estrae come `<nome>_<Mesh>_{albedo,normal,orm}.png` e `inspect_model.gd` mostra `orm=true ao=true`. L'occlusione passa per il gruppo di nodi `glTF Material Output` (ingresso `Occlusion`): senza, l'esportatore non scrive `occlusionTexture`. **Trappola**: le texture estratte nascono con `compress/mode=0` (senza compressione VRAM); vanno portate a `compress/mode=2` (e `compress/normal_map=1` per le normal) negli `.import`, ma un `.import` modificato a mano **non si reimporta** finche non si cancella il suo `.md5` (e il `.ctex`) in `godot/.godot/imported/`; poi `godot_console --headless --path godot --editor --quit`. Il flag `"vram_texture": true` nell'`.import` conferma l'esito.

Tile di superficie (restyling 2026-10-11): `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_surface_tiles.py -- [ground|walls|plants]` cuoce le tile ripetibili (coordinate toroidali nel rumore 4D) e scrive in `godot/assets/textures/surfaces/` tre PNG verticali per gruppo (`<gruppo>_{albedo,normal,orm}.png`, strati impilati con lo strato 0 in alto) **e i loro `.import`** con `importer="2d_array_texture"`, `compress/mode=2` e `slices/vertical=<strati>`: senza l'`.import` scritto prima, Godot importerebbe un `Texture2D` singolo. Tutti e tre i gruppi in circa 3 minuti; poi `godot_console --headless --path godot --editor --quit`. In Godot la risorsa e una `CompressedTexture2DArray`, che deriva da `TextureLayered` e **non** da `Texture2DArray`: nei test si controlla `get_layered_type()`. Verifica: `tests/restyle_tests.gd`.

Prato e vento (D-083): la texture dei fili e lo strato 0 di `plants` (`build_surface_tiles.py -- plants`, circa un minuto con Blender 5.2; dopo la cottura `godot_console --headless --path godot --editor --quit` reimporta e genera gli `.uid` dei nuovi include). **Trappola**: `grass_tufts` e `flowers` sono fissati anche nelle scene `arena_run.tscn` e `railway_run.tscn` (la proprieta esportata vince su `_init` di `RuinsDistrict`): alzare il valore nello script non cambia nulla finche non si tocca la scena. Il campionamento stratificato di `_build_ground_cover` genera `wanted * 3.5` candidati: se `stats.tufts` resta sotto il bersaglio, le zone verdi hanno esaurito i candidati, non le istanze. Il vento e in `resources/materials/wind.gdshaderinc` (`wind_offset(origin_xz, height01, strength, seed, TIME)`): uno shader che lo include deve passare l'altezza normalizzata della mesh (`blade_height`, `plant_height`); i vecchi parametri `sway`/`sway_speed` non esistono piu. Il movimento non si vede nelle catture: va giudicato in gioco.

Personaggi con scheletro (D-060): `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_character_assets.py`, poi `godot_console --headless --path godot --import`. Pose animate in fila, da davanti, da dietro e dalla camera di gioco: `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 600 --script res://tests/tools/capture_character.gd -- --out=../output/character`. Trappole verificate (6 ottobre 2026): Godot toglie il suffisso `_Loop` dai nomi delle animazioni importate (`Jog_Fwd_Loop` diventa `Jog_Fwd`, in ciclo); l'export glTF di Blender prende le azioni dalle tracce NLA dell'armatura e ignora la rotazione dell'oggetto armatura (serve un nodo intermedio); le pose finali dopo un `SkeletonModifier3D` si leggono solo nel segnale `skeleton_updated`; `get_skeleton()` di un modificatore appena aggiunto e nullo. Uno script `--script` che va in errore non esce da solo: passare sempre `--quit-after`.

Blender dal vivo (D-061, MCP for Blender): basta aprire Blender: l'addon avvia da solo il server su `localhost:9876` (verificato il 6 ottobre 2026 con `ping` e `get_scene_info`; in caso contrario pannello laterale del viewport, tasto N > **MCP for Blender** > **Start MCP Server**). L'agente puo aprire Blender da solo (`cmd //c start "" "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"`) e parlargli subito via socket, un oggetto JSON `{"type": ..., "params": {...}}` per connessione; gli strumenti nativi `mcp__blender__*` compaiono invece solo in una **nuova** sessione di Claude Code. Stato del server: `claude mcp get blender`. Reinstallare l'addon: `PYTHONIOENCODING=utf-8 uvx mcp-for-blender install-addon` (senza la variabile il comando va in errore di codifica su Windows dopo aver installato). Trappola verificata: da Git Bash `claude mcp add ... -- cmd /c uvx ...` trasforma `/c` in `C:/`; anteporre `MSYS_NO_PATHCONV=1`. La pipeline a script resta la fonte dei `.glb`: cio che si modella a mano va riportato nello script o salvato come `.blend`.

Animazioni Mixamo (D-062): mettere l'FBX in `tools/blender/third_party/mixamo/`, aggiungerlo a `MIXAMO_CLIPS` in `build_character_assets.py` (nome con `_Loop` se ciclica, eventuale intervallo in secondi) e ricostruire. Per scegliere il tratto utile: `capture_character.gd -- "--poses=Dig@0.0,Dig@0.6,..."`. Sequenze in gioco di andature, capriola e scavo: `capture_motion.gd` (`output/motion/player_*_strip.png`). Trappole verificate: l'import FBX porta la scena Blender a 30 fps e, se non si rimette a 24, l'export accelera di un quarto le animazioni della libreria; le corse laterali Mixamo girano i fianchi, quindi senza la correzione del petto di `HipTwistModifier` la mira devia di oltre 60 gradi.

La scena principale e il **menu iniziale** (D-051): un run senza argomenti si ferma li. Per arrivare al livello da riga di comando aggiungere `-- --autostart` (lo fanno il gate e lo smoke test delle build); `--seed=`, `--boss-at=` e `--capture=` lo implicano.

Trappola verificata (6 ottobre 2026): un `Image` RGBA8 arrotonda i colori a 8 bit, quindi `get_pixel(...).is_equal_approx(colore)` e quasi sempre falso. Confrontare con una tolleranza (`RunMap.same_color`).

Impronte dell'orda (cortile aperto, varco nord chiuso, cortile sigillato): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_flow.gd -- --out=../output/flow`. Sequenze di fotogrammi del movimento degli attori: `... --script res://tests/tools/capture_motion.gd -- --out=../output/motion`. Costo del movimento, acceso e spento nello stesso processo: `benchmark_arena.gd -- --enemies=70 --motion-ab`.

Simulazione di run con bot (D-055): `godot_console --headless --path godot --fixed-fps 60 --script res://tests/tools/simulate_runs.gd -- --bots=passive,novice,kiter,scrapper --seeds=1-10 --max-seconds=1200` (righe `PROTOTYPE01_SIM`, `PROTOTYPE01_SIM_SUMMARY`, `PROTOTYPE01_SIM_AFFORD`; `--profile=base_health:2,cargo:1` simula un profilo con acquisti). Una run fino al boss costa 2,5-6 minuti di orologio: per molte run conviene un processo per coppia bot/seme in parallelo. **Mentre girano simulazioni le misure di `benchmark_arena.gd` non sono attendibili** (osservato: tempi quasi doppi). Con `--trace=N` il simulatore stampa lo stato ogni N secondi di gioco (`PROTOTYPE01_SIM_TRACE`): confrontando due tracce si trova il passo in cui due run si separano.

Trappola verificata (6 ottobre 2026): **non mettere in pausa l'albero a meta di un passo fisico** da codice di gioco (`get_tree().paused = true` dentro un `_physics_process` o un segnale emesso da li): i nodi gia elaborati in quel passo e quelli non ancora elaborati restano sfasati. Segnare la richiesta e aprire il menu dall'ultimo nodo del passo (`ArenaRun._physics_process`).

Limite noto (6 ottobre 2026): due run identiche con un numero diverso di passi fisici per frame (`--fixed-fps 60` contro `--fixed-fps 10` a 60 Hz) si separano comunque dopo un po': `move_and_slide` di un nemico che striscia su un muro restituisce posizioni diverse di frazioni di millimetro. E nel motore, non nel gioco: per confronti usare sempre lo stesso `--fixed-fps`.

Identita e interfaccia (D-079, D-080): logo in PNG (`logo_wide` 2048, `logo_stacked` 1024, `icon` 256) con `godot_console --path godot --resolution 1280x800 --quit-after 900 --script res://tests/tools/capture_logo.gd -- --out=../output/identity`; intro a tre tempi, menu (con riga `MENU_FRAME_MS`, tempo reale a vsync spento) e pausa con `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 6000 --script res://tests/tools/capture_ui.gd -- --out=../output/identity`; le altre schermate con gli script esistenti (`capture_run`, `capture_workshop`, `capture_campaign`, `capture_settings`, `capture_night`, `capture_boss`) e `--out=../output/identity`. **Tema di progetto**: dopo ogni modifica a `scripts/ui/ui_palette.gd` rigenerare `resources/ui/theme.tres` con `godot_console --headless --path godot --script res://tests/tools/build_theme.gd` (la suite `ui_theme_tests.gd` segnala se e vecchio). **Avvio**: la `main_scene` e `scenes/main/boot_intro.tscn` (intro di 4 s, poi il menu); `--autostart`, `--level=` e gli altri prefissi di `RunLaunchOptions.AUTOSTART_PREFIXES` la saltano, come l'headless; `--intro-test` la forza anche in headless (suite `intro_tests.gd`).

Interfaccia "fatta a mano" (D-081): dopo ogni modifica a `tests/tools/build_ui_textures.gd` rigenerare i PNG con `godot_console --headless --path godot --script res://tests/tools/build_ui_textures.gd`, poi `--editor --quit` e `build_theme.gd` (il tema li referenzia); `ui_theme_tests` controlla presenza e misure. `UiFx` e un autoload (`UiFxService`): gli script lo raggiungono con `get_node_or_null(^"/root/UiFx") as UiFxService` (il nome dell'autoload non compila in `--check-only`); `fade_to_scene`/`fade_reload` per i cambi di scena (con `--autostart` il menu cambia scena senza velo), `pop_in(control)` all'apertura dei pannelli, `play(&"ui_back")` alla chiusura. Trappole: un `StyleBoxTexture` con `expand_margin` disegna fuori dal rettangolo (usato per l'alone del focus); i Control dentro un `SubViewport` non ricevono il tema di progetto; `Image.set_pixel` su 96x96 e economico, ma il generatore va tenuto fuori dal gioco.

Catture di Officina, mappa di fine livello e menu iniziale: `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_workshop.gd -- --out=../output/workshop`. Sotto `--script` l'autoload `PlayerProfile` non legge ne scrive `user://profile.cfg`: test e catture impostano il profilo in memoria.

Trappola verificata (6 ottobre 2026): `add_child()` su un nodo fratello **durante il `_ready` della scena** fallisce ("Parent node is busy setting up children") e il nodo resta fuori dall'albero senza altri sintomi. Usare `add_child.call_deferred()`.

Catture del ciclo giorno/notte (D-058: giorno con indicatore, tramonto a meta, notte nel faro, notte al buio con 20 rottamatori, Torcia e Faro al massimo): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 3000 --script res://tests/tools/capture_night.gd -- --out=../output/night`. Per giocare subito la notte: `godot --path godot -- --night-at=5`; `--night-at=0` la spegne (anche nel simulatore). Costo del direttore di notte con sei lampioni: `benchmark_arena.gd -- --enemies=70 --night`. In gioco il tool cicla scava → rialza → lampione con lo stesso tasto del modo.

Livello 2, la ferrovia (D-067): per giocarlo `godot --path godot -- --level=railway` (`--level=` salta il menu come `--autostart`; `--boss-at=60` anticipa la Trivella). Catture: `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 6000 --script res://tests/tools/capture_railway.gd -- --out=../output/railway` (annuncio del treno, treno che passa, fascia spianata, Trivella in mira, in carica e stordita) e `capture_district.gd -- --scene=railway --out=../output/railway` (panoramica dall'alto, `--visit=x,z`). Mappa di campagna e schermata di vittoria con "Prossimo livello": `... --quit-after 900 --script res://tests/tools/capture_campaign.gd -- --out=../output/campaign`. Simulazioni sulla ferrovia: `simulate_runs.gd -- --level=railway ...`. Trappola verificata (9 ottobre 2026): in uno script di cattura **con finestra la fisica e a 120 Hz**, non a 60 come nei test: `_boss_warning_left = 0.05` e sei `physics_frame` non bastano a far entrare il boss; chiamare `run.call_boss()` e attendere dodici passi con `_boss_warning_left = 0.01`. Trappola della sessione: un heredoc bash che contiene backtick non viene eseguito dallo strumento Bash di Claude Code; gli script di patch in Python vanno scritti in un file e lanciati con `python -I`.

Catture del boss (annuncio, rottamatore carico e cantiere, Demolitore con barricata, vittoria): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_boss.gd -- --out=../output/boss`. Per giocare subito il boss: `godot --path godot -- --boss-at=60`.

Catture e misure dello spike del terreno a rilievo continuo (D-063: cumulo, trincea curva, argine e rampa, piazzola, rottamatori in marcia; riga `TERRAIN_SPIKE_BENCH` con costo di pennello e campo di percorso): `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 3000 --script res://tests/tools/capture_terrain_spike.gd -- --out=../output/terrain_spike`. Per giocarlo: `godot --path godot res://scenes/spikes/terrain_spike.tscn`. La suite e `tests/height_terrain_tests.gd` (nel gate).

Benchmark dell'arena grande (costruzione, celle e collisioni, costo per passo del direttore dei nemici e dell'arma, draw call con finestra): `godot_console --path godot --resolution 1280x800 --script res://tests/tools/benchmark_arena.gd -- --enemies=70` (righe `PROTOTYPE01_ARENA_BENCH`). In `--headless` il monitor `TIME_PHYSICS_PROCESS` include l'attesa del loop e non e attendibile: fidarsi delle misure dirette `director_ms`, `weapon_ms`, `solve_ms`.

Benchmark per preset grafico (restyling 2026-10-11): `... benchmark_arena.gd -- --enemies=70 --preset=high|max|deck|medium|low` applica il preset prima di costruire l'arena e **toglie il limite di fps** (default 60 dal restyling: senza, la riga `frame` misura il cap, 16,6 ms). Misure dell'11 ottobre 2026 sul PC del proprietario, arena_run con 70 nemici, a fine fetta dell'ambiente: **Alto** 4,06 ms (254 fps), 206 draw call, 1,28 M primitive, 348 MB; **Massimo** 5,67 ms (177 fps), 357 draw call, 1,86 M primitive, 750 MB (SDFGI e nebbia volumetrica); **Steam Deck** (preset, misurato sul PC) 3,70 ms, 230 draw call, 1,06 M primitive, 319 MB. Prima del restyling (commit f862ee4, preset implicito): 8,32 ms con il cap a 120, 344 draw call, 1,96 M primitive, 318 MB. `video_mem_mb` e `RENDER_VIDEO_MEM_USED`: include i buffer, non e la sola memoria texture.

Trappola verificata (5 ottobre 2026): in un test `extends SceneTree`, la scena aggiunta in `_initialize` riceve `_ready` solo al primo frame, e `_ready` riattiva il passo fisico dei nodi che definiscono `_physics_process`. Un `set_physics_process(false)` va quindi chiamato **dopo** aver atteso almeno un frame.

Il gate (`Invoke-GodotChecks.ps1`) ha un timeout di 300 s per processo: un test appeso risulta FAIL con exit 124 invece di bloccare tutto.

Trappola verificata (16 ottobre 2026): una suite puo stampare `PROTOTYPE01_TESTS PASS` e poi non chiudersi (exit 124, processo fermo a 0 % di CPU). Capita alle suite che chiamano `quit()` direttamente da `_initialize` (`weapon_catalog_tests`, `machine_catalog_tests`, `run_progression_tests`, `profile_v2_tests`), circa 1 volta su 13, anche sul codice di prima della carovana; due frame d'attesa prima di `quit()` non bastano, e si blocca anche una suite di prova che stampa PASS e chiude subito: e Godot, non il gioco. Il gate ora rilancia da solo, una volta, la suite che ha stampato PASS senza errori runtime e non si e chiusa entro il timeout, e la giudica sul secondo run; il log del primo resta in `output/gate/<suite>.exit-hang.log` e prima della riga finale una nota dice quante suite sono state rilanciate e con quali log. Nessun altro rosso si rilancia (FAIL, PASS mancante, errori runtime, altri exit code). Se anche il rilancio resta appeso il gate resta FAIL: puo essere ancora il blocco noto (circa 1 volta su 100-170 per suite) o un blocco vero; rilanciare la suite da sola e guardare entrambi i log. Un rilancio su una suite fuori da queste quattro, o una nota che torna spesso, non e il blocco noto: va guardato.

Per l'input nei test: `Input.action_press()` per azioni tenute; per azioni a evento (dash) usare `Input.parse_input_event()` con `InputEventAction`, perche `is_action_just_pressed` in `_physics_process` puo perdere una pressione simulata.

Trappole verificate (11 ottobre 2026, interfaccia):

- Un `Theme` assegnato a `root.theme` **non raggiunge** i Control dentro un `CanvasLayer` (pausa, HUD, level-up, Officina, campagna, fine livello): Godot risale solo per Control e Window. Serve il tema di progetto (`gui/theme/custom`), e `ThemeDB` non ha un setter a runtime: per questo il tema e un `.tres` generato.
- `MenuButton` e una classe built-in: `set_type_variation("MenuButton", "Button")` fallisce con "cannot be marked as a variation". La variante si chiama `MainButton`.
- `TextServer.name_to_tag` non e statico: `TextServerManager.get_primary_interface().name_to_tag("weight")` per l'asse `wght` di una `FontVariation`.
- Un `ShaderMaterial` su una Label con font **MSDF** campiona il campo di distanza, non il glifo: colori casuali. Il font slab e importato senza MSDF.
- Dentro un `SubViewport` il tema della radice non arriva: `GameLogo` imposta i font direttamente (`add_theme_font_override`).
- `Performance.TIME_PROCESS` include l'attesa del vsync: per misurare una schermata usare il tempo reale per frame con `window_set_vsync_mode(VSYNC_DISABLED)` e `Engine.max_fps = 0` (`capture_ui.gd`).
- I tick fisici sono 120 al secondo: in uno script di cattura "un secondo" sono 60 `process_frame` con `--fixed-fps 60`, non 60 `physics_frame`.
- Dopo un `class_name` nuovo, `--script` fallisce con "Identifier not declared" finche non si esegue `--editor --quit` (cache delle classi).

### Terreno continuo (D-085, tappa A, 12 ottobre 2026)

Il quartiere (`arena_run.tscn`) sta su `TerrainField` (campo di quote a 0,5 m, 204 m, sorgente di verita anche in headless) con Terrain3D 1.0.2 per la resa e `TerrainCollision` (196 `HeightMapShape3D` da 16 m, layer 1) per la fisica, con Jolt. Dalla tappa B (D-087) anche la ferrovia (`railway_run.tscn`, campo 319,2 x 122,4 m) e le scene minori (`smoke_test`, `ruins_arena`, campo da 128 m) stanno sul rilievo: la griglia a celle non esiste piu. Comandi:

- rilievo di base cotto: `godot_console --headless --path godot --script res://tests/tools/bake_terrain_base.gd -- --level=<id>` scrive `levels/<id>/base.bin` (LFS, versione 3 con le due dimensioni; `district` senza argomento, `railway` per la ferrovia); se manca o non combacia (seme, dimensioni), `apply_base_relief` lo ricalcola all'avvio (circa 0,6 s);
- tile per Terrain3D: `godot_console --headless --path godot --script res://tests/tools/pack_terrain_tiles.gd` ricava da `assets/textures/surfaces/ground_*.png` i cinque strati `assets/textures/terrain/<nome>_{albedo_height,normal_rough}.png` a 1024 px con gli `.import` VRAM, poi `--editor --quit`;
- shader del rilievo: `resources/materials/terrain_relief.gdshader` e la copia dello shader generato da Terrain3D piu il blocco "Rilievo"; dopo un aggiornamento di Terrain3D si rigenera la copia con `godot_console --path godot --resolution 320x200 --script res://tests/tools/dump_terrain_shader.gd -- --out=<file>` (serve una finestra) e si riporta il blocco;
- catture: `godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 4000 --script res://tests/tools/capture_terrain.gd -- --out=../output/terrain` (argine, solco, vena a meta, barricata, zainetto vuoto e pieno, vista dall'alto); `capture_district.gd` e `capture_night.gd` funzionano come prima;
- benchmark: `benchmark_arena.gd` stampa anche la riga `PROTOTYPE01_ARENA_BENCH terrain` (100 pennellate casuali: media e massimo, chunk aggiornati, base);
- zainetto sul modello: il costruttore dell'ingegnere esporta anche l'oggetto `PackSack`; `capture_character.gd -- --pack=0,0.5,1` mostra i tre riempimenti.

Trappole verificate:

- `Terrain3D` esiste solo con una finestra: in headless `TerrainField.terrain3d()` e null e colori, strati e base dello shader non si applicano (le suite lo sanno); `restyle_tests` gira anche con finestra (320x200) nel passo «con finestra» del gate, che avvia pure il gioco contando gli errori degli shader (`-NoWindow` lo salta; audit K-03);
- `Terrain3D.data` e `collision` nascono un fotogramma dopo `add_child`: `TerrainField` aspetta un `process_frame` e poi emette `render_ready`; chi dipinge strati o colori (il quartiere) lo fa su quel segnale;
- la collisione di Terrain3D resta spenta (`Terrain3DCollision.DISABLED`): i corpi stanno sui chunk nostri; Jolt e obbligatorio (con Godot Physics 40 corpi su heightmap costano 17 ms a passo);
- un rialzo secco sotto un corpo lo incastra nella heightfield: il pennello del giocatore alza 2 cm a passo, il Demolitore posa la barricata solo su un punto libero da corpi, il terremoto riappoggia i nemici sulla nuova quota;
- `update_maps` di Terrain3D aggiorna solo le regioni con `edited = true` (`_mark_regions`) e **non le smarca**: lo fa il suo editor dopo ogni operazione. Lasciate marcate, ogni pennellata ricaricava sulla GPU tutte le regioni del livello (fino a 23 ms sulla ferrovia, 8 regioni; 14 ottobre 2026). In `TerrainField` si passa sempre da `_update_maps`, che aggiorna e poi smarca; il controllo e in `restyle_tests` con finestra; `set_height` non interpola: le quote vanno scritte a vertice;
- il quartiere viene prima del rilievo nella scena: prato, prop e rovine si appoggiano alle quote con `RuinsDistrict.settle_on_relief()` (chiamata da `ArenaRun` dopo il rilievo); il prato usa un generatore proprio cosi il risultato non dipende dall'ordine;
- il disco di partenza (6 m) e protetto nei primi 10 s: nei test che scolpiscono subito vicino all'origine va tolto (`run._start_protect_left = 0; field.set_protected(Vector3.ZERO, 6, false)`);
- l'emissione di un `Decal` ignora l'alfa della texture: l'anello del pennello ha RGB pari all'alfa, altrimenti riempie tutto il quadrato;
- `PathField` senza griglia: `_terrain_index` parte a -1 (prima partiva a 0 e `cost_at` prima del primo passo cercava `grid.state` su null);
- `--editor --quit` riordina `project.godot` (`physics_engine` dopo `physics_ticks_per_second`): non e una modifica da committare.

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

**Banco di prova della luce** (D-094): `tests/tools/lighting_lab.gd` carica un livello una volta e cattura le stesse inquadrature con piu varianti di Environment, sole, riempimento e nuvole lette da un JSON (uso in testa al file). `--night` e `--dusk` portano il ciclo al buio vero o a meta tramonto con torcia e lampioni: la run riconfigura il ciclo dopo il caricamento, quindi il banco lo anticipa a ogni passo. Per confrontare: affiancare i PNG in un foglio unico con Pillow.

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

## Addon di terze parti (D-057)

Stanno in `godot/addons/`; versioni e licenze in `TOOLS_AND_LICENSES.md`. Verificati il 6 ottobre 2026 su Windows; Steam Deck no.

- **Debug Menu**: autoload `DebugMenu`. In gioco **F3** cicla nascosto / compatto / dettagliato. Da codice: `get_node("/root/DebugMenu").style = 2`. Sul Deck F3 non esiste: associarlo a un tasto posteriore con Steam Input, oppure definire l'azione `cycle_debug_menu` in `project.godot` (se esiste, l'addon usa quella).
- **Controller Icons**: autoload `ControllerIcons`. `parse_path("dash")` restituisce la texture del tasto per il dispositivo in uso; `parse_path("steamdeck/a")` un'icona precisa; i nodi `ControllerIconTexture` si aggiornano da soli al cambio di dispositivo. Nel gioco si usa attraverso `ButtonPrompts` (`scripts/ui/button_prompts.gd`, D-059): `ButtonPrompts.create([[&"ui_accept", "Conferma"]])` restituisce una riga "icona + testo" da aggiungere a un contenitore; con secondo argomento `true` una colonna. In headless mostra sempre le icone del controller.
- **Debug Draw 3D**: GDExtension, nessun plugin da attivare. `DebugDraw3D.draw_box(...)`, `draw_sphere(...)`, `draw_line(...)` a ogni frame. Nelle build release le chiamate restano valide ma non disegnano.
- **SimpleGrassTextured**: plugin **non attivo**. Per usarlo: Progetto, Impostazioni, Plugin; poi togliere `addons/simplegrasstextured/*` da `exclude_filter` in `export_presets.cfg` e misurare il costo.

Trappole verificate (6 ottobre 2026):

- Gli script degli addon usano il nome globale del proprio autoload: in `--check-only` non compilano (`Identifier not found: ControllerIcons`). Il gate li salta; non e un errore.
- In `--headless`, `ControllerIcons.parse_path` su un'azione legata a un tasto **fisico** della tastiera stampa `ERROR: Not supported by this display server`. Nei test passare il tipo di input controller (secondo argomento `1`).
- In uno script `--script` gli autoload degli addon sono pronti solo **dopo il primo frame**: attendere `process_frame` prima di usarli.
- Con il plugin dell'erba spento, esportare i suoi shader stampa `SHADER ERROR: L'uniforme globale 'sgt_...' non esiste`: per questo la cartella e esclusa dagli export.
- L'export copia accanto all'eseguibile la libreria `libdd3d.*.template_release.*`: va distribuita insieme alla build.
- Mentre il gate gira non creare ne cancellare cartelle dentro `godot/`: l'elenco degli script fallisce.
- Con l'editor aperto, `--headless --editor --quit` stampa `ERROR: Error copying library ... libdd3d.windows.editor.x86_64.dll`: l'editor tiene bloccata la libreria. La cache delle classi viene aggiornata lo stesso; non e un errore del progetto.
- Gli script di cattura vogliono `--out=` **relativo** al progetto (`../output/...`): un percorso assoluto Windows viene incollato dopo `res://` e il salvataggio fallisce.

## Non ancora verificato

Da confermare quando servira, senza darlo per acquisito:

- `--import` (reimport headless degli asset);
- framework di test (GUT, GdUnit4): valutati il 6 ottobre 2026 e non adottati (le suite proprie e il gate bastano).

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

Trappole verificate (9 ottobre 2026) con gli agenti in **worktree Git** separati: (1) un worktree nuovo ha i modelli `.glb` di `godot/assets/models/` come puntatori LFS da 130 byte finche non si fa `git lfs pull --include="godot/assets/models/*.glb"` e poi `godot_console --headless --path godot --editor --quit` per reimportarli; prima di allora `arena_run_tests` fallisce ("altri punti di interesse Raised"); (2) il worktree puo nascere su `main`: controllare `git log -1` e riallinearlo al branch di lavoro prima di cominciare.

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
