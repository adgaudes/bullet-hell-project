# Carovana, piano C: colosso pilotato, eventi, Meccanico, Officina — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la carovana dei piani A e B si completa con le parti che la Sezione 7 della spec D-093 assegna al piano C: il colosso (6 moduli) si pilota tenendo Interagisci (armi e attrezzo spenti, moduli +50%, carburante dai Cassoni, sbalzo fuori sotto il 30% di vita o senza rottami); terremoto e treno staccano un modulo dalle macchine fuse e il modulo staccato resta a terra come relitto che Interagisci riprende gratis; il Meccanico parte con due macchine, ha la carta di classe "Officina mobile" (7 moduli) e le sue armi seguono la macchina col Cassone piu vicina; l'Officina ha la scheda "Macchine" per sbloccare Trivella, Pala, Saldatore e Sirena, e le carte "Nuova macchina" e i relitti offrono solo i moduli sbloccati.

**Architecture:** il pilotaggio vive in un nodo nuovo `ColossusPilot` (`caravan/colossus_pilot.gd`, creato da `ArenaRun` nel codice, nessuna scena toccata) che tiene la tenuta di Interagisci, il carburante e lo sbalzo; `Machine` guadagna lo stato `piloted` (passo guidato dall'input del giocatore, forza x1,5, travolgere piu forte, punto di mira per Trivella e Pala); `PlayerCharacter` guadagna `pilot` (siede sul colosso, niente movimento proprio, scatto, attrezzo ne danni: li prende il colosso); `WeaponLoadout` si sospende. I moduli staccati dagli eventi stanno in `ModuleRelics` (`caravan/module_relics.gd`, sul modello dei luccichii di `BuriedCaches` ma in superficie, presi con Interagisci). `Caravan` guadagna `detach_random`, `module_limit()` con posti in piu e `nearest_cargo_machine`. Le pressioni di Interagisci passano da un unico smistatore in `ArenaRun` (`_on_interact_pressed`: relitto, poi banco) invece della connessione diretta alla pedana. L'Officina legge gli sblocchi dei moduli come quelli delle armi (voci `unlock_module_<id>` di `PermanentCatalog`): il profilo resta alla versione 3 senza chiavi nuove.

**Tech Stack:** Godot 4.7.2, GDScript, suite headless (`extends SceneTree`), gate `tools/godot/Invoke-GodotChecks.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-15-caravan-machines-design.md` (Sezione 3; Sezione 4 per gli eventi e il modulo staccato; Sezione 5 per Meccanico e Officina; Sezione 6 per comandi e HUD; "Valori di partenza"; "Verifica"). Modello di formato e convenzioni: `docs/superpowers/plans/2026-10-18-caravan-fusion.md` (piano B, fatto). Righe del codice citate a HEAD `e2a3f27`: riverificarle prima di toccarle.

## Global Constraints

- Valori di partenza della spec in `CaravanTuning` (`godot/resources/tuning/caravan_default.tres`); i nodi copiano i valori e non modificano la risorsa (`machine_catalog_tests` controlla `module_limit` 6 nel `.tres`: i posti in piu dell'Officina mobile stanno nella carovana, non nel tuning). Tutti i valori nuovi del piano C nascono nel task 1, coi default scritti li e nel `.tres`.
- Interagisci = azione `interact` (X del controller, R della tastiera), una sola azione per tutto. Precedenza fissa, decisa in `ArenaRun` e nella carovana: (1) tenuto vicino a una macchina guasta ripara; (2) tenuto 0,5 s vicino al colosso sale, tenuto 0,5 s a bordo scende; (3) premuto vicino a un modulo staccato lo riprende; (4) premuto sulla pedana chiede il banco. A bordo non si ripara e non si chiede il banco. Controller e tastiera/mouse equivalenti, controller prima; ogni test del pilotaggio manda eventi di input veri di entrambi (come `fusion_tests._send_joypad_button` e `_send_key`).
- Macchine sul layer 8 con maschera 1; contatti e travolgere restano nei secchi di `EnemyDirector` (mai un secondo giro su tutti i nemici). Il giocatore a bordo ha collisione spenta (`collision_layer = 0`, `collision_mask = 0`) e la riaccende scendendo.
- Ogni scrittura sul terreno dei moduli passa da `TerrainWriteQueue` e da `clear_spot`; a bordo cambia solo il punto scelto, non la regola.
- Nessun menu a meta passo fisico: tutto cio che apre menu resta in `ArenaRun._open_next_level_up`. Il pilotaggio non apre menu.
- Tempi in `delta`, mai in passi (gioco a 120 Hz, suite a 60 Hz); ogni teletrasporto (sbalzo, salita, discesa, lancio di un modulo) chiama `reset_physics_interpolation()`.
- Uno script non nomina il proprio `class_name`. Dopo ogni `class_name` nuova (`ColossusPilot`, `ModuleRelics`): `godot_console --headless --path godot --editor --quit`, poi `git diff godot/project.godot` e annullare solo il riordino dell'editor (`[physics]`); controllare che i pulsanti di `ui_accept`/`ui_cancel` e l'azione `interact` siano rimasti.
- Suite una alla volta (processi Godot rimasti scrivono sullo stesso log: ucciderli prima); `--check-only` su ogni script toccato; la suite nuova `colossus_tests.gd` segue lo scheletro di `tests/fusion_tests.gd` (`_check`, `_frames`, seme `PROTOTYPE01_SEED` 20261014 se manca, due `physics_frame` prima di `quit`, marker `PROTOTYPE01_TESTS`). Le suite adattate restano forti quanto prima: si cambia il soggetto, non si toglie un controllo senza dirlo nel commit.
- `PlayerProfileService.VERSION` resta 3: nessuna chiave nuova nel profilo (gli sblocchi dei moduli sono voci di `[upgrades]` come quelli delle armi). I test del profilo di `fusion_tests` e `workshop_tests` restano verdi senza modifiche.
- Il piano C non tocca scene `.tscn` ne `project.godot`. Se un esecutore ne avesse bisogno: `tasklist | grep -i godot` vuoto prima, altrimenti avvisare il proprietario e non toccare.
- Testi del gioco in italiano senza accenti tipografici; identificatori in inglese. Budget: carovana 0,5 ms per passo sul preset Deck, anche col colosso pilotato in moto.
- Benchmark: le righe `frame`, `run` e `path` sono misurate ad albero fermo (debito del piano A): non usarle; valgono le righe `caravan*`.

## Scelte di questo piano (da registrare in D-093)

1. **Salire e scendere.** Il colosso si pilota se non e guasto, il giocatore e entro `pilot_mount_range` 2,5 m dal suo centro e nessuna macchina guasta e entro `repair_range` (la riparazione vince). Si tiene Interagisci `pilot_hold_seconds` 0,5 s; il rilascio prima azzera. A bordo la stessa tenuta fa scendere, accanto al colosso sul primo punto aperto (`walkable_near_player` a 1,5 m, altrimenti il centro del colosso piu 1,5 m avanti).
2. **A bordo.** Il giocatore siede sul colosso: `global_position` = centro del colosso + `PILOT_SEAT_HEIGHT` 0,9 m x scala, collisione spenta, modello nascosto, `velocity` copiata dal colosso (camera e animatore). Lo stick sinistro guida il colosso (`pilot_input`), lo stick destro o il mouse danno la direzione di mira (`pilot_facing`, da `facing_direction()`), che il colosso usa per Trivella e Pala. Scatto, attrezzo e armi attive non rispondono; le armi (automatiche e attive) sono sospese (`process_mode` DISABLED e nascoste, come `WeaponLoadout._set_enabled`) e tornano scendendo coi loro livelli. Il giocatore non prende danni: `take_damage` li passa a `pilot.take_hit` (un colpo solo, con l'immunita della macchina).
3. **Colosso pilotato.** Velocita massima = velocita a piedi del giocatore x `pilot_speed_factor` 0,7 x `caravan.speed_scale` (Olio buono e Motore truccato valgono anche qui), accelerazione `acceleration` del tuning, niente campo di percorso ne meta dei moduli (il Cassone raccoglie solo cio che tocca); niente guinzaglio, incastro, ritirata ne ritorno al posto finche e pilotato. Forza dei moduli x (1 + `pilot_power_bonus` 0,5) sopra quella della taglia (1,75 x 1,5 = 2,625 con 6 moduli). Travolge con `pilot_trample_damage` 2 (anche i rottamatori "medi", cioe con 2 PV) invece di `trample_damage` 1, con la stessa attesa di 0,5 s.
4. **Trivella e Pala a bordo.** Il punto di scrittura e `pilot_aim_reach` 3 m davanti al colosso lungo la direzione di mira (`Machine.pilot_spot(distance)`), non il nemico piu vicino; le altre condizioni (`clear_spot`, piano entro `drill_flat_tolerance`, suolo sotto l'argine, rottami della Pala) non cambiano. La Ruspa segue la scia come oggi.
5. **Carburante e sbalzo.** A bordo ogni `pilot_fuel_interval` 10 s la carovana paga `pilot_fuel_cost` 1 rottame dai Cassoni funzionanti (`pay`); se non puo, o se la vita del colosso scende sotto `pilot_eject_below` 0,3 del massimo, o se il colosso si guasta, il giocatore e sbalzato fuori (stesso punto della discesa, `grant_invulnerability` 1 s) e il colosso resta in ritirata per `pilot_forced_retreat_seconds` 6 s anche sopra il 50% (`Machine.force_retreat`). Autonomo nessun consumo. Finire il livello o morire a bordo fa scendere senza marker di sbalzo.
6. **Eventi.** Terremoto: una pennellata che passa entro `HIT_RADIUS` da una macchina fusa (2 o piu moduli) stacca `quake_detach_count` 1 modulo a caso (una volta per macchina per terremoto; la macchina resta risparmiata dalla cresta come oggi); le piccole non perdono nulla. Treno: la macchina sulla fascia si guasta subito (`Machine.break_down`) e viene spinta fuori come oggi; se fusa, prima dello spinta perde 1 modulo (`train_detach_count`), scagliato a `train_throw_min`-`train_throw_max` 6-8 m oltre il bordo della fascia dal lato della spinta. Boss e rottamatori non staccano nulla. Un evento spento nelle impostazioni non parte e quindi non stacca.
7. **Modulo staccato.** `Caravan.detach_random(machine)` toglie il modulo gratis (fuori dalla pedana, senza rottami; un Cassone staccato lascia i rottami a terra in `ScrapField` se c'e, altrimenti li perde) e conserva la frazione di vita della sorgente; il modulo diventa un relitto di `ModuleRelics`: il pezzo del modulo (`build_part`) poggiato al suolo col luccichio arancione dei relitti sepolti, visibile da `GLINT_RANGE`. Interagisci premuto entro `relic_pickup_range` 2 m lo riprende come macchina piccola, gratis, se la carovana ha posto; senza posto resta a terra (tasto spento). Il treno porta via i relitti sulla fascia; il terremoto li riappoggia sulla quota nuova.
8. **Meccanico.** `ClassCatalog.start_machines(&"mechanic")` = `[&"turret"]`: parte con Cassone e Torretta; Torretta fissa (Officina) aggiunge un'altra Torretta (tre macchine). Carta di classe `mobile_workshop` ("Officina mobile", Rara, 1 livello, `requires = "caravan"`): `Caravan.extra_module_slots` = 1, quindi `module_limit()` = 7. Calamita da gru e Saldatore (armi) seguono `Caravan.nearest_cargo_machine(player)` (la piu vicina col Cassone, guaste comprese; senza Cassoni il capofila).
9. **Officina.** Gruppo nuovo `machines` ("Macchine") dopo l'Erbacciaia e prima del Ricettario, con quattro voci `unlock_module_<id>`: Trivella 15, Pala 18, Saldatore 22, Sirena 25 rottami. `PlayerProfileService.unlocked_modules()` = moduli `unlocked_by_default` piu quelli comprati. In run `_available_modules()` filtra col profilo; senza profilo (suite, catture) restano gli otto con script come oggi. Il simulatore sblocca con `--profile=unlock_module_drill:1`.
10. **Nomi e marker.** Classi `ColossusPilot`, `ModuleRelics`; marker `PILOT_MOUNTED modules= power=`, `PILOT_DISMOUNTED`, `PILOT_EJECTED reason=fuel|health|broken`, `PILOT_FUEL carried=`, `MODULE_DETACHED module= by=quake|train`, `MODULE_RELIC_DROPPED module= x= z=`, `MODULE_RELIC_TAKEN module=`, `MACHINE_BROKEN_BY_TRAIN`, `WORKSHOP_MODULE_UNLOCKED id=` (tutti con prefisso `PROTOTYPE01_`); campi `relics=` e `piloted=` (sempre 0: i bot non pilotano) nella riga `PROTOTYPE01_SIM`; righe `ARENA_BENCH caravan_colossus_piloted`.

## Review Focus

1. Il giocatore muore, finisce il livello, va in pausa o perde il focus mentre e a bordo: scende senza restare invisibile o senza collisione, le armi tornano, nessun marker di sbalzo, il menu di fine livello si apre come oggi. → test nel task 5 (`_test_pilot_end_level`).
2. Il colosso pilotato si guasta (treno, orda) o viene tolto dalla carovana (`remove_machine`) mentre il giocatore e a bordo: sbalzo con motivo `broken`, nessun riferimento a una macchina liberata, la riparazione a mano torna possibile. → test nel task 5 (`_test_eject_on_broken`, `_test_removed_while_mounted`).
3. Terremoto o treno su una macchina con due Cassoni pieni, o sul capofila: i rottami del modulo staccato finiscono a terra o restano, `lead()` resta valido, la macchina sorgente non e mai guasta dal terremoto, il relitto non cade sui binari ne dentro il disco protetto della pedana. → test nei task 2 (`_test_detach_random`) e 4.
4. Relitto a carovana piena, due relitti vicini, relitto sulla pedana e banco chiesto nello stesso passo: il tasto non si accende senza posto, si prende il piu vicino, la pressione che prende un relitto non chiede il banco. → test nel task 3.
5. Profilo con la Trivella comprata e poi un profilo senza: le carte macchina e i relitti offrono solo i moduli sbloccati; una carovana con una Trivella ottenuta altrove (`--caravan=`, relitto di un modulo staccato) la tiene; un profilo v2 e uno con `unlock_module_<id>` sconosciuto si caricano intatti (la chiave resta in `[upgrades]` come upgrade sconosciuto). → test nel task 7 (`_test_profile_unlocked_modules`, con un controllo in piu su `unlock_module_nope = 1`).

## Fuori dal piano C

Bilanciamento (economia dei rottami, carburante, costi dell'Officina), bot che pilotano il colosso, catture del grappolo con 70 nemici sul Deck, musica, modelli 3D della pedana e del colosso. Debito del piano B che resta (D-093): Ruspa in moto non misurata (la riga `caravan_colossus_piloted` di questo piano la copre solo se la Ruspa e nel colosso: il benchmark la include, vedi task 8), chiave dei dettagli dell'Officina condivisa fra combinazioni e permanenti.

Proposta al proprietario (non installare): nessun addon serve. Per l'icona della scheda Macchine e dei relitti si riusano le `UiIcon` dei moduli.

---

### Task 1: valori del piano C in CaravanTuning e la suite nuova

**Files:** Modify `godot/scripts/caravan/caravan_tuning.gd` (tre gruppi nuovi dopo `Combinations`, in coda al file), `godot/resources/tuning/caravan_default.tres` (le stesse chiavi in coda a `[resource]`). Create `godot/tests/colossus_tests.gd`.

**Interfaces — Produces:**
- `CaravanTuning`, `@export_group("Colossus")`: `pilot_hold_seconds := 0.5`, `pilot_mount_range := 2.5`, `pilot_power_bonus := 0.5`, `pilot_speed_factor := 0.7`, `pilot_fuel_interval := 10.0`, `pilot_fuel_cost := 1`, `pilot_eject_below := 0.3`, `pilot_forced_retreat_seconds := 6.0`, `pilot_trample_damage := 2`, `pilot_aim_reach := 3.0`. `@export_group("Events")`: `quake_detach_count := 1`, `train_detach_count := 1`, `train_throw_min := 6.0`, `train_throw_max := 8.0`, `relic_pickup_range := 2.0`.. Il Meccanico non ha valori nuovi nel tuning.
- `MachineFusion.power_of(module_count, tuning, piloted := false) -> float` = `(1 + power_per_extra_module x (n - 1)) x (1 + pilot_power_bonus se piloted)`; `MachineFusion.pilot_speed(player_walk_speed: float, tuning) -> float` = `player_walk_speed x pilot_speed_factor`.
- `colossus_tests.gd`: `extends SceneTree`, `_initialize` con seme e `t = load(TUNING_PATH)`, sezioni chiamate in ordine: `_test_tuning()`, `_test_power()`, poi quelle dei task 2-7 (`await _test_caravan()`, `await _test_relics()`, `await _test_events()`, `await _test_pilot()`, `await _test_mechanic()`, `await _test_workshop()`).

- [ ] **Step 1: test che falliscono** (`colossus_tests.gd`, sezione logica):

```gdscript
func _test_tuning() -> void:
	_check(is_equal_approx(t.pilot_hold_seconds, 0.5) and is_equal_approx(t.pilot_mount_range, 2.5), "tenuta e portata della salita")
	_check(is_equal_approx(t.pilot_power_bonus, 0.5) and is_equal_approx(t.pilot_speed_factor, 0.7), "+50% ai moduli, -30% di velocita")
	_check(is_equal_approx(t.pilot_fuel_interval, 10.0) and t.pilot_fuel_cost == 1 and is_equal_approx(t.pilot_eject_below, 0.3), "carburante e sbalzo")
	_check(t.pilot_trample_damage == 2 and is_equal_approx(t.pilot_aim_reach, 3.0) and is_equal_approx(t.pilot_forced_retreat_seconds, 6.0), "travolgere, mira, ritirata forzata")
	_check(t.quake_detach_count == 1 and t.train_detach_count == 1 and is_equal_approx(t.train_throw_min, 6.0) and is_equal_approx(t.train_throw_max, 8.0), "eventi")
	_check(is_equal_approx(t.relic_pickup_range, 2.0) and t.module_limit == 6, "relitto a 2 m; il limite del tuning resta 6")
func _test_power() -> void:
	_check(is_equal_approx(MachineFusion.power_of(6, t), 1.75) and is_equal_approx(MachineFusion.power_of(6, t, true), 2.625), "forza del colosso: 1,75 autonomo, 2,625 pilotato")
	_check(is_equal_approx(MachineFusion.power_of(1, t, true), 1.5), "una piccola pilotata (solo logica) varrebbe 1,5")
	_check(is_equal_approx(MachineFusion.pilot_speed(6.0, t), 4.2), "6 m/s a piedi: 4,2 a bordo")
```

- [ ] **Step 2:** `godot_console --headless --path godot --fixed-fps 60 --script res://tests/colossus_tests.gd` → FAIL (`pilot_hold_seconds` sconosciuto).
- [ ] **Step 3:** aggiungere i valori al tuning e al `.tres`, il parametro `piloted` a `power_of` (default falso: le chiamate di `fusion_tests` e di `Machine._rebuild` non cambiano) e `pilot_speed`.
- [ ] **Step 4:** `colossus_tests.gd` → `PROTOTYPE01_TESTS PASS failures=0`; `fusion_tests.gd` e `machine_catalog_tests.gd` verdi; `--check-only` sui due script.
- [ ] **Step 5: commit** `Carovana (D-093), piano C: valori del colosso pilotato, degli eventi e dei relitti in CaravanTuning; forza a bordo in MachineFusion; suite colossus_tests`.

### Task 2: Caravan e Machine, le basi del piano C

**Files:** Modify `godot/scripts/caravan/caravan.gd` (`has_room` :132, `lead` :165, dopo `detach` :~250, `repair_target` :~400), `godot/scripts/caravan/machine.gd` (`can_trample` :338, `_update_state` :403, dopo `repair` :366). Test: `colossus_tests.gd`, sezione `_test_caravan` su `ruins_arena.tscn` (come `fusion_tests._test_caravan`: `_reset()`, `_add(id)`, `_break(machine)`).

**Interfaces — Consumes:** task 1. **Produces:**
- `Caravan`: `var extra_module_slots := 0` (posti oltre `tuning.module_limit`); `func module_limit() -> int` = `tuning.module_limit + extra_module_slots`; `has_room` lo usa. `func nearest_cargo_machine(point: Vector3) -> Machine`: la macchina con un Cassone (anche guasta) piu vicina a `point` nel piano; senza Cassoni `lead()`; senza macchine null. `func detach_random(machine: Machine, rng: RandomNumberGenerator) -> StringName`: con 2 o piu moduli toglie un modulo a caso (`rng.randi_range`), gratis, senza pedana e anche da guasta; la sorgente conserva la frazione di vita (`carried_health`); i rottami di un Cassone staccato vanno in `scrap_field.spawn_on_ground` accanto alla macchina (uno per rottame, a 0,8 m l'uno dall'altro) se `scrap_field != null`; marker `PROTOTYPE01_MODULE_DETACHED module=%s by=event`; `changed.emit()`; restituisce l'id del modulo tolto, `&""` se la macchina ha un modulo solo o non e nella carovana. `repair_target()` restituisce null anche se `player.pilot != null` (a bordo non si ripara): il campo nasce qui in `PlayerCharacter` come `var pilot: Node3D = null` (una riga sotto `interact_held`, commento "a bordo di una macchina: la imposta il piano C"); il task 5 lo ritipizza `Machine`.
- `Machine`: `func break_down() -> void` (vita a 0 e stato BROKEN, come un colpo mortale ma senza immunita ne `damaged`; su una gia guasta non fa nulla; marker `PROTOTYPE01_MACHINE_BROKEN_BY_TRAIN` lo stampa il treno, non qui); `func force_retreat(seconds: float) -> void` (`_forced_retreat_left = maxf(...)`; `_update_state` tiene RETREAT finche e > 0 e non guasta, poi la regola della vita riprende; `_tick_health` lo fa scadere); `func trample_damage() -> int` = `pilot_trample_damage` se `piloted` altrimenti `trample_damage` (il campo `piloted` nasce qui come `var piloted := false`, lo usa il task 5). `EnemyDirector._apply_machine_contacts` (:393) legge `machine.trample_damage()` al posto di `caravan.tuning.trample_damage`.

- [ ] **Step 1: test che falliscono** (`_test_caravan`, dopo `_reset()` con il Cassone capofila):

```gdscript
func _test_module_limit() -> void:
	for id in [&"turret", &"drill", &"shovel", &"welder", &"siren"]: _add(id)
	_check(_caravan.module_count() == 6 and not _caravan.has_room() and _caravan.module_limit() == 6, "piena a 6")
	_caravan.extra_module_slots = 1
	_check(_caravan.module_limit() == 7 and _caravan.has_room() and _caravan.add_machine(&"magnet") != null, "Officina mobile: settimo posto")
	_check(not _caravan.has_room() and _caravan.tuning.module_limit == 6, "piena a 7; il tuning condiviso resta 6")
func _test_nearest_cargo() -> void:
	_reset(); var a := _caravan.lead(); var b := _add(&"cargo"); var c := _add(&"turret")
	_place(a, Vector3(10, 0, 0)); _place(b, Vector3(2, 0, 0)); _place(c, Vector3(0, 0, 0))
	_check(_caravan.nearest_cargo_machine(Vector3.ZERO) == b, "il Cassone piu vicino, non il capofila ne la Torretta")
	_break(b)
	_check(_caravan.nearest_cargo_machine(Vector3.ZERO) == b, "anche guasto")
func _test_detach_random() -> void:
	_reset(); var m := _caravan.lead(); _add(&"turret"); _caravan.add_scrap(5)  # fonde turret nel capofila
	_caravan.fuse(m, _caravan.machines[1]); m.health = 10  # 10/15
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var id := _caravan.detach_random(m, rng)
	_check(id == &"turret" or id == &"cargo", "stacca uno dei due")
	_check(m.modules.size() == 1 and m.max_health == 6 and m.health == 4 and _caravan.machines.size() == 1, "sorgente a un modulo, 4/6 (frazione conservata), nessuna macchina nuova")
	_check(_caravan.detach_random(m, rng) == &"" and m.modules.size() == 1, "una piccola non perde nulla")
	# Cassone staccato coi rottami: a terra
	_reset(); m = _caravan.lead(); var t2 := _add(&"turret"); _caravan.add_scrap(5); _caravan.fuse(m, t2)
	var before := _scrap_field.count()  # ScrapField della scena
	while _caravan.detach_random(m, rng) != &"cargo": _reset_fused()  # finche lo staccato e il Cassone
	_check(_caravan.carried == 0 and _scrap_field.count() == before + 4, "4 rottami a terra (5 meno il costo della fusione)")
func _test_break_and_retreat() -> void:
	_reset(); var m := _caravan.lead()
	m.break_down(); _check(m.is_broken() and m.health == 0, "guasta subito")
	m.repair(0.5); m.force_retreat(1.0); await _frames(1)
	_check(m.state == Machine.State.RETREAT, "in ritirata a vita piena")
	await _seconds(1.1); _check(m.state == Machine.State.OK, "scaduta: torna in ordine")
	m.force_retreat(1.0); m.break_down(); _check(m.is_broken(), "guasta vince sulla ritirata forzata")
	_check(m.trample_damage() == 1, "travolgere di base 1")
```

- [ ] **Step 2:** suite → FAIL (`module_limit` sconosciuto).
- [ ] **Step 3:** implementare le interfacce; sostituire `tuning.module_limit` con `module_limit()` in `has_room` e nei due usi fuori dalla carovana (`simulate_runs.gd:490`, `benchmark_arena.gd:555` che oggi scrive nella copia del tuning: passa a `caravan.extra_module_slots = 1`).
- [ ] **Step 4:** `colossus_tests`, `caravan_tests`, `fusion_tests`, `machine_damage_tests` verdi; `--check-only` sui quattro script.
- [ ] **Step 5: commit** `Carovana (D-093), piano C: module_limit con posti in piu, nearest_cargo_machine, detach_random gratuito, break_down e force_retreat; test`.

### Task 3: relitti dei moduli staccati e lo smistatore di Interagisci

**Files:** Create `godot/scripts/caravan/module_relics.gd`. Modify `godot/scripts/run/arena_run.gd` (`_setup_fusion_pad` :853-885: la riga `player.interact_pressed.connect(fusion_pad.request_bench)` :876 diventa lo smistatore; `_tick_caravan_hud` :1527; `_schedule_world_events` o `_build_terrain_relief` per creare i relitti), `godot/scripts/ui/caravan_strip.gd` (`set_prompt` :99), `godot/scripts/ui/run_hud.gd` (`set_caravan_prompt` :269), `godot/scripts/run/train_event.gd` (`_sweep_band` :197-215: `module_relics.discard_in_rect`). Test: `colossus_tests.gd`, sezione `_test_relics` su `arena_run.tscn` (come `fusion_tests._test_bench`: `_run`, `_player`, `_caravan`).

**Interfaces — Consumes:** task 2 (`detach_random`, `module_limit`). **Produces:**
- `class_name ModuleRelics extends Node3D`: `@export var terrain_field: TerrainField`, `@export var player: Node3D`; `const GLINT_RANGE := 3.0`, `const GLINT_COLOR := Color(1.0, 0.45, 0.1)` (quello dei relitti sepolti); `func drop(module_id: StringName, at: Vector3) -> int` (indice; pezzo di `Caravan.module_script_for(module_id).new().build_part()` o un `BoxMesh` 0,4 m del colore del modulo se `build_part` e null, poggiato alla quota del suolo con imbardata da `at` come `MachineWrecks._build_frame`, luccichio come `BuriedCaches` sopra; marker `PROTOTYPE01_MODULE_RELIC_DROPPED module= x= z=`); `func count() -> int` (relitti ancora a terra); `func nearest_index(point: Vector3, range: float) -> int` (-1 se nessuno); `func module_of(index: int) -> StringName`; `func position_of(index: int) -> Vector3`; `func take(index: int) -> StringName` (toglie pezzo e luccichio, marker `MODULE_RELIC_TAKEN module=`); `func discard_in_rect(rect: Rect2) -> int`; `func refresh_heights(aabb: AABB) -> void` (collegato a `terrain_field.region_changed`: i pezzi seguono la quota). Il luccichio si vede solo entro `GLINT_RANGE` dal giocatore (`_process`, spento senza relitti).
- `ArenaRun`: `var module_relics: ModuleRelics` creato in `_build_terrain_relief` dopo `_place_wrecks()` (`name = "ModuleRelics"`, servizi, `train_event.module_relics = module_relics`, `quake_event.module_relics = module_relics`); `func _on_interact_pressed() -> void`: se `is_over` nulla; se `player.pilot != null` nulla (task 5); altrimenti `var index := module_relics.nearest_index(player.global_position, caravan.tuning.relic_pickup_range)`; con `index >= 0 and caravan.has_room()` → `caravan.add_machine(module_relics.take(index))` e ritorno; altrimenti `fusion_pad.request_bench()`. `func relic_available() -> bool` (relitto in portata e posto in carovana) per il tasto del HUD.
- `CaravanStrip.set_prompt(repair: bool, bench := false, relic := false, pilot := "")`: un tasto alla volta, in quest'ordine: "Ripara", poi `pilot` ("Pilota" o "Scendi", task 5), poi "Riprendi" (relic), poi "Banco"; `func relic_prompt_visible() -> bool`, `func pilot_prompt_text() -> String` ("" se spento). `RunHud.set_caravan_prompt` passa i quattro.

- [ ] **Step 1: test che falliscono** (`_test_relics`, run aperta, giocatore vivo):

```gdscript
func _test_relic_pickup() -> void:
	var relics := _run.module_relics
	var at := _player.global_position + Vector3(1.0, 0.0, 0.0)
	var i := relics.drop(&"siren", at)
	_check(relics.count() == 1 and relics.module_of(i) == &"siren" and relics.nearest_index(_player.global_position, 2.0) == i, "relitto a 1 m")
	await _frames(1)
	_check(_run.hud.caravan_strip().relic_prompt_visible(), "tasto Riprendi acceso")
	var machines := _caravan.machines.size()
	_joy(JOY_BUTTON_X); await _frames(2)
	_check(relics.count() == 0 and _caravan.machines.size() == machines + 1 and _caravan.machines[-1].primary_module_id() == &"siren", "X: la Sirena torna macchina piccola")
	_check(not _run.fusion_pad.has_bench_request(), "la pressione che riprende non chiede il banco")
func _test_relic_full_and_nearest() -> void:
	while _caravan.has_room(): _caravan.add_machine(&"turret")
	var relics := _run.module_relics
	relics.drop(&"drill", _player.global_position + Vector3(1.5, 0.0, 0.0))
	relics.drop(&"shovel", _player.global_position + Vector3(0.6, 0.0, 0.0))
	await _frames(1)
	_check(not _run.hud.caravan_strip().relic_prompt_visible() and not _run.relic_available(), "piena: tasto spento")
	_key(KEY_R); await _frames(2)
	_check(relics.count() == 2, "piena: R non prende nulla")
	_caravan.remove_machine(_caravan.machines[-1]); await _frames(1)
	_key(KEY_R); await _frames(2)
	_check(relics.count() == 1 and relics.module_of(relics.nearest_index(_player.global_position, 5.0)) == &"drill", "con posto: R prende la Pala, la piu vicina")
	relics.discard_in_rect(Rect2(-100, -100, 200, 200))
	_check(relics.count() == 0, "discard_in_rect li toglie")
func _test_relic_follows_ground() -> void:
	var relics := _run.module_relics; var at := _player.global_position + Vector3(4.0, 0.0, 0.0)
	var i := relics.drop(&"turret", at); var y0 := relics.position_of(i).y
	_field.sculpt(at, 1.0, 1.0); await _frames(4)
	_check(relics.position_of(i).y > y0 + 0.5, "il pezzo sale col suolo")
```

- [ ] **Step 2:** suite → FAIL (`module_relics` nullo).
- [ ] **Step 3:** implementare `ModuleRelics`, lo smistatore, il tasto "Riprendi" e il collegamento al treno; poi la cache delle classi (Global Constraints).
- [ ] **Step 4:** `colossus_tests`, `fusion_tests` (banco: la richiesta passa ora dallo smistatore, `_test_bench_*` restano verdi), `caravan_hud_tests` (aggiungere un controllo: `set_prompt(false, true, true)` accende solo "Riprendi") verdi; `--check-only` sui cinque script.
- [ ] **Step 5: commit** `Carovana (D-093), piano C: ModuleRelics (moduli staccati a terra, Interagisci li riprende), smistatore delle pressioni di Interagisci in ArenaRun, tasto Riprendi nella striscia; test`.

### Task 4: terremoto e treno staccano moduli

**Files:** Modify `godot/scripts/run/quake_event.gd` (`_shake_point`, il ciclo `for machine in caravan.machines` che oggi ritorna), `godot/scripts/run/train_event.gd` (`_sweep_actors` :241-256, `_push_out` :284), `godot/scripts/run/arena_run.gd` (`_setup_quake` :888, `_setup_train` :832: `rng` e `module_relics`). Test: `colossus_tests.gd`, sezione `_test_events` (terremoto su `arena_run.tscn` con `--quake-at` non serve: si chiama `quake_event.schedule([s])` e si avanza; treno su `railway_run.tscn` come `extraction_tests` o la suite del treno gia esistente: riusarne lo scheletro).

**Interfaces — Consumes:** task 2 (`detach_random`, `break_down`), task 3 (`ModuleRelics.drop`). **Produces:**
- `QuakeEvent`: `var module_relics: ModuleRelics`; `var _detached: Dictionary[Node, bool]` azzerato in `_start_shaking`; in `_shake_point`, per una macchina entro `HIT_RADIUS` con `modules.size() >= 2` e non in `_detached`: `caravan.detach_random(machine, rng)` per `quake_detach_count` volte (al piu finche ha 2 moduli), il relitto in `module_relics.drop(id, point)` con `point` = `at + _fault_side x 2.5` se `terrain_field.is_protected` falso e fuori dai binari, altrimenti `at - _fault_side x 2.5`, altrimenti `at`; `quake_hit.emit(&"module")`; marker `PROTOTYPE01_MODULE_DETACHED module= by=quake`; poi il `return` di oggi (la macchina resta risparmiata). `modules_detached` (contatore per il `_finish`, nel marker `QUAKE_DONE` come `modules=`).
- `TrainEvent`: `var module_relics: ModuleRelics`; in `_sweep_actors`, per la macchina coperta: se `modules.size() >= 2` → `detach_random` per `train_detach_count`, il relitto a `_push_out`-lato della macchina (`side x (TRACK_HALF_WIDTH + rng.randf_range(train_throw_min, train_throw_max))`, stessa x, poggiato col `lift` di `_push_out`); poi `machine.break_down()`, marker `PROTOTYPE01_MACHINE_BROKEN_BY_TRAIN module=`, `_push_out(machine)`, `train_hit.emit(&"companion")`. Il treno sulla fascia porta via i relitti (`module_relics.discard_in_rect(buried_rect)` in `_sweep_band`, task 3).

- [ ] **Step 1: test che falliscono:**

```gdscript
func _test_quake_detaches() -> void:  # run del quartiere, carovana: capofila fuso con turret (2 moduli) e una piccola drill
	var fused := _caravan.lead(); var small := _caravan.machines[1]
	var quake := _run.quake_event; quake.cells_per_second = 1000.0
	_place(fused, fault_point); _place(small, fault_point + along x 2.4)  # due pennellate della faglia (quake.fault_points dopo _start_warning)
	quake.schedule([_run.elapsed + quake.warning_seconds + 0.1]); await _until(func(): return quake.quakes == 1, 12.0)
	_check(fused.modules.size() == 1 and not fused.is_broken() and small.modules.size() == 1, "la fusa perde un modulo, la piccola no, nessuna guasta")
	_check(_run.module_relics.count() == 1 and not RailwayDistrict.is_on_tracks(...) , "un relitto a terra fuori dalla faglia")
	_check(_caravan.lead() != null and _caravan.carried >= 0, "capofila valido")
func _test_quake_once_per_machine() -> void:  # colosso da 6 lungo la faglia: perde esattamente 1 modulo
	...; _check(colossus.modules.size() == 5 and _run.module_relics.count() == 1, "un solo modulo per terremoto")
func _test_train_breaks_and_detaches() -> void:  # railway_run.tscn: macchina fusa (2 moduli) a z = 0, treno programmato
	...; _check(fused.is_broken() and fused.modules.size() == 1, "guasta e con un modulo in meno")
	var p := relics.position_of(0)
	_check(absf(p.z) >= RailwayDistrict.TRACK_HALF_WIDTH + 6.0 - 0.01 and absf(p.z) <= RailwayDistrict.TRACK_HALF_WIDTH + 8.0 + 0.01 and not RailwayDistrict.is_on_tracks(Vector2(p.x, p.z)), "relitto a 6-8 m oltre il bordo, fuori dalla fascia")
	_check(absf(fused.global_position.z) > RailwayDistrict.TRACK_HALF_WIDTH, "spinta fuori come oggi")
func _test_train_small_only_breaks() -> void:
	...; _check(small.is_broken() and small.modules.size() == 1 and relics.count() == 0, "la piccola si guasta e basta")
func _test_train_sweeps_relics() -> void:  # relitto posato sulla fascia prima del passaggio
	...; _check(relics.count() == 0, "il treno porta via il relitto")
```

- [ ] **Step 2:** suite → FAIL (`module_relics` sconosciuto negli eventi).
- [ ] **Step 3:** implementare; `ArenaRun` passa `module_relics` ai due eventi (dopo averli creati nel task 3: l'ordine in `_ready` e `_setup_train`/`_setup_quake` prima di `_build_terrain_layout`, quindi l'assegnazione va dove nasce `module_relics`).
- [ ] **Step 4:** `colossus_tests`, la suite del treno e quella del terremoto esistenti (`arena_run_tests`, `extraction_tests` o dove stanno: `grep -l "quake_event\|train_event" godot/tests/*.gd`) verdi; `--check-only`.
- [ ] **Step 5: commit** `Carovana (D-093), piano C: il terremoto stacca un modulo dalle macchine fuse sulla faglia, il treno guasta la macchina investita e ne scaglia un modulo oltre la fascia; relitti; test`.

### Task 5: il colosso pilotato

**Files:** Create `godot/scripts/caravan/colossus_pilot.gd`. Modify `godot/scripts/caravan/machine.gd` (`_physics_process` :458, `_choose_destination` :508, `_rebuild` :702, `can_trample` :338, `top_speed` :259), `godot/scripts/caravan/machine_module.gd` (dopo `point_toward`), `godot/scripts/caravan/modules/drill_module.gd` (`_drill_hole` :76), `godot/scripts/caravan/modules/shovel_module.gd` (`tick` :15), `godot/scripts/player/player_character.gd` (`_physics_process` :285, `_start_dash` :749, `take_damage` :820, `_notification` :260), `godot/scripts/combat/weapon_loadout.gd` (dopo `_set_enabled` :263, `trigger_active` :247), `godot/scripts/run/arena_run.gd` (`_setup_fusion_pad` o un `_setup_pilot` nuovo chiamato dopo; `_on_interact_pressed`; `_tick_caravan_hud`; `_end_level` :589; `_on_player_died`), `godot/scripts/ui/caravan_strip.gd` (tasti "Pilota"/"Scendi", task 3). Test: `colossus_tests.gd`, sezione `_test_pilot` su `arena_run.tscn` (il colosso si costruisce con `add_machine` x5, `add_cargo_capacity(5)`, `add_scrap(5)` e cinque `caravan.fuse(lead, m)`, come `_bench_colossus`).

Aiuti della suite da scrivere nel task 5 (sul modello di `fusion_tests`): `_place(machine, at)` come `_place_machine`, `_hold_joy(button, seconds)` e `_hold_key(key, seconds)` (pressione, passi per `seconds`, rilascio), `_seconds(s)`, `_until(predicate, timeout_s)`, `_colossus()` (cinque `add_machine`, rottami, cinque `fuse` nel capofila, a 1 m dal giocatore).

**Interfaces — Consumes:** task 1 (valori, `power_of(.., true)`, `pilot_speed`), task 2 (`force_retreat`, `trample_damage()`, `repair_target` a bordo), task 3 (smistatore, `set_prompt(.., pilot)`). **Produces:**
- `class_name ColossusPilot extends Node`: `signal mounted(machine: Machine)`, `signal dismounted(machine: Machine, reason: StringName)` (`&"dismount"`, `&"fuel"`, `&"health"`, `&"broken"`, `&"end"`); `var caravan: Caravan`, `var player: PlayerCharacter`, `var loadout: WeaponLoadout`, `var hud: RunHud`; `var machine: Machine` (a bordo, altrimenti null); `func mount_candidate() -> Machine` (colosso non guasto entro `pilot_mount_range` dal giocatore vivo, nessuna guasta entro `repair_range`, non gia a bordo; il piu vicino); `func hold_progress() -> float` (0..1 della tenuta in corso); `func is_mounted() -> bool`; `func mount(target: Machine) -> bool`; `func dismount(reason: StringName = &"dismount") -> void`; `func fuel_left() -> float`. `_physics_process(delta)` (dopo il giocatore, prima della carovana: `process_physics_priority = -1` sul nodo, o lo chiama `ArenaRun` all'inizio del suo passo: scegliere la chiamata da `ArenaRun._physics_process` subito dopo `_tick_night`, cosi lo sbalzo precede i contatti del direttore): tenuta (`player.interact_held` con un candidato, o a bordo) che accumula fino a `pilot_hold_seconds`, azzerata al rilascio o se il candidato cambia; a bordo carburante e condizioni di sbalzo (`machine.is_broken()` → `broken`; `health / max_health < pilot_eject_below` → `health`; timer scaduto e `not caravan.pay(pilot_fuel_cost)` → `fuel`, altrimenti marker `PILOT_FUEL carried=`). `mount`: `machine.set_piloted(true)`, `player.board(machine)`, `loadout.set_suspended(true)`, `hud.show_notice("AL VOLANTE DEL COLOSSO", 2.0, RunHud.FUSION_COLOR)`, marker `PROTOTYPE01_PILOT_MOUNTED modules=%d power=%.3f`. `dismount`: punto = `caravan.walkable_near_player(forward, 1.5)` o `machine.global_position + forward x 1.5` sul suolo; `player.disembark(point)`; `machine.set_piloted(false)`; `loadout.set_suspended(false)`; per `fuel`/`health`/`broken`: `machine.force_retreat(pilot_forced_retreat_seconds)` (non da guasta), `player.grant_invulnerability(1.0)`, notice "SBALZATO FUORI", marker `PILOT_EJECTED reason=`; per `dismount`/`end` marker `PILOT_DISMOUNTED`. Una macchina tolta dalla carovana (`machine_removed`) mentre e a bordo → `dismount(&"broken")` prima della liberazione (collegare `caravan.machine_removed` in `_ready`).
- `Machine`: `var piloted := false`, `var pilot_input := Vector3.ZERO` (direzione planare, modulo <= 1), `var pilot_facing := Vector3.FORWARD`; `func set_piloted(on: bool) -> void` (imposta, `_rebuild()`, `_reset_stuck()`, azzera `pilot_input`); `_rebuild` usa `MachineFusion.power_of(count, tuning, piloted)`; `func pilot_top_speed() -> float` = `MachineFusion.pilot_speed(UnrealSpace.length(caravan.player.tuning.planar_move_speed_cm), tuning) x caravan.speed_scale`; `func pilot_spot(distance: float) -> Variant` (piloted: centro + `pilot_facing` x distance, y 0; altrimenti null); in `_physics_process`, se `piloted` e non guasta: niente guinzaglio, incastro, minaccia ne moduli come meta: `velocity` planare verso `pilot_input x pilot_top_speed()` con `acceleration`, gravita, `move_and_slide`, rotazione verso la velocita come oggi, poi i moduli fanno `tick` e `_update_motion`; `can_trample` a bordo ignora `trample_min_size` (il colosso lo supera comunque) e il resto non cambia.
- `MachineModule.pilot_spot(distance: float) -> Variant` = `machine.pilot_spot(distance)` se `machine != null` altrimenti null. `DrillModule._drill_hole` e `ShovelModule.tick`: `var spot: Variant = pilot_spot(caravan.tuning.pilot_aim_reach)`; se null la regola di oggi (nemico piu vicino), altrimenti il punto; a bordo la Pala non ha bisogno del nemico.
- `PlayerCharacter`: `var pilot: Machine`; `const PILOT_SEAT_HEIGHT := 0.9`; `func board(machine: Machine) -> void` (pilot, `collision_layer`/`collision_mask` salvati e azzerati, `_model.visible = false`, `is_dashing = false`, `tool_held = false`, `velocity = Vector3.ZERO`); `func disembark(at: Vector3) -> void` (pilot null, collisione e modello ripristinati, `global_position = at`, `reset_physics_interpolation()`); in `_physics_process` con `pilot != null`: `_run_pending_actions()` (dash e attive ignorate: `_start_dash` ritorna se `pilot != null`; `active_weapon_pressed` lo rifiuta il loadout sospeso), dispositivo di mira e `_apply_facing_rotation` come oggi, `pilot.pilot_input = _read_move_direction().limit_length(1.0)`, `pilot.pilot_facing = facing_direction()`, `global_position = pilot.global_position + Vector3(0, PILOT_SEAT_HEIGHT x pilot.model_scale, 0)`, `velocity = pilot.velocity`, poi solo `_update_hit_flash`, `_invulnerable_left`, la rete di sicurezza di `interact_held` e `_update_motion`; niente `move_and_slide`, pennello, scatto, fuga dalla buca. `take_damage(amount)`: con `pilot != null` → `pilot.take_hit(amount)` e ritorna falso (nessun lampo, nessun `damaged`). `_notification` (pausa, focus): invariato (la tenuta si azzera: la salita riparte).
- `WeaponLoadout`: `var suspended := false`; `func set_suspended(on: bool) -> void` (`_set_enabled(w, not on)` su tutte le armi di `_autos` e `_actives`, `changed.emit()`); `trigger_active` ritorna falso se `suspended`; `add` di un'arma mentre e sospeso la crea spenta (`_set_enabled(w, not suspended)` dopo i servizi).
- `ArenaRun`: `var pilot: ColossusPilot` creato in `_setup_pilot()` dopo `_setup_fusion_pad()` (nome "ColossusPilot", servizi); `_on_interact_pressed` esce subito se `pilot.is_mounted()`; `_tick_caravan_hud` passa `pilot_text` = "Scendi" a bordo, "Pilota" se `pilot.mount_candidate() != null`, altrimenti ""; `_end_level` e `_on_player_died` chiamano `pilot.dismount(&"end")` se a bordo (prima di aprire i pannelli).

- [ ] **Step 1: test che falliscono** (`_test_pilot`; `_colossus()` costruisce il colosso e lo mette a 1 m dal giocatore; `_hold_joy(button, seconds)` tiene premuto X per `seconds` secondi di passi):

```gdscript
func _test_mount_controller() -> void:
	var c := _colossus(); var pilot := _run.pilot
	await _frames(1); _check(pilot.mount_candidate() == c and _run.hud.caravan_strip().pilot_prompt_text() == "Pilota", "candidato e tasto Pilota")
	await _hold_joy(JOY_BUTTON_X, 0.3); _check(not pilot.is_mounted() and pilot.hold_progress() > 0.5, "0,3 s: non ancora")
	_send_joypad_button(JOY_BUTTON_X, false); await _frames(1); _check(pilot.hold_progress() == 0.0, "rilascio: da capo")
	await _hold_joy(JOY_BUTTON_X, 0.55); _check(pilot.is_mounted() and pilot.machine == c and c.piloted, "0,5 s: a bordo")
	_check(is_equal_approx(c.power, 2.625) and _player.pilot == c and _player.collision_layer == 0 and not _player._model.visible, "forza 2,625, giocatore seduto e senza collisione")
	_check(_run.loadout.autos().all(func(w: Weapon) -> bool: return w.process_mode == Node.PROCESS_MODE_DISABLED), "armi sospese")
	_check(_run.hud.caravan_strip().pilot_prompt_text() == "Scendi" and _caravan.repair_target() == null, "tasto Scendi; niente riparazione a bordo")
func _test_drive_and_seat() -> void:  # a bordo
	Input.action_press(&"move_right"); await _seconds(1.0); Input.action_release(&"move_right")
	_check(c.global_position.x > x0 + 2.0 and c.velocity.length() <= c.pilot_top_speed() + 0.01, "il colosso avanza allo stick, entro la velocita a bordo")
	_check(is_equal_approx(c.pilot_top_speed(), MachineFusion.pilot_speed(UnrealSpace.length(_player.tuning.planar_move_speed_cm), t)), "velocita = -30% di quella a piedi")
	_check(_player.global_position.distance_to(c.global_position + Vector3(0, 0.9 * c.model_scale, 0)) < 0.05, "il giocatore siede sul colosso")
	_joy(JOY_BUTTON_A)  # scatto
	await _frames(2); _check(not _player.is_dashing, "niente scatto a bordo")
func _test_damage_redirect() -> void:
	var hp := _player.health; var mhp := c.health
	_check(not _player.take_damage(1) and _player.health == hp and c.health == mhp - 1, "il colpo va al colosso")
func _test_drill_aims_at_facing() -> void:  # colosso con la Trivella, nessun nemico
	_player.face_shot(Vector3.RIGHT); var drill := c.module(&"drill") as DrillModule; drill._drill_left = 0.0
	await _frames(6)  # scrittura in coda
	_check(_field.height_at(c.global_position + Vector3(3.0, 0, 0)) < _field.base_height_at(...) - 0.2, "buca a 3 m nella direzione di mira")
func _test_fuel() -> void:
	_caravan.carried = 2; var before := _caravan.carried
	await _seconds(10.05); _check(_caravan.carried == before - 1 and pilot.is_mounted(), "10 s: un rottame")
	_caravan.carried = 0; await _seconds(10.05)
	_check(not pilot.is_mounted() and not c.piloted and _player.pilot == null and _player.collision_layer != 0 and _player._model.visible, "senza rottami: sbalzato, giocatore a terra")
	_check(c.state == Machine.State.RETREAT and is_equal_approx(c.power, 1.75), "colosso in ritirata forzata, forza normale")
	_check(_run.loadout.autos().all(func(w: Weapon) -> bool: return w.process_mode == Node.PROCESS_MODE_INHERIT), "armi tornate")
func _test_eject_on_health() -> void:  # risalito; c.health = 63
	c.health = 18; await _frames(1); _check(not pilot.is_mounted(), "sotto il 30%: sbalzato")
func _test_eject_on_broken() -> void:  # risalito
	c.break_down(); await _frames(1); _check(not pilot.is_mounted() and _player.pilot == null, "guasto: sbalzato, motivo broken")
	c.repair(0.5); _place(c, _player.global_position + Vector3(1, 0, 0)); await _frames(1)
	_check(pilot.mount_candidate() == c, "riparato: di nuovo candidato")
func _test_removed_while_mounted() -> void:  # risalito
	_caravan.remove_machine(c); await _frames(1)
	_check(not pilot.is_mounted() and _player.pilot == null and pilot.machine == null, "macchina tolta: sbalzo broken, nessun riferimento")
	c = _colossus()  # per i test che seguono
func _test_dismount_keyboard() -> void:  # risalito
	await _hold_key(KEY_R, 0.55); _check(not pilot.is_mounted() and _player.global_position.distance_to(c.global_position) < 2.5, "R tenuto: scende accanto")
func _test_mount_refused() -> void:
	var small := _caravan.add_machine(&"turret"); _place(small, _player.global_position + Vector3(1, 0, 0)); _place(c, far)
	await _frames(1); _check(pilot.mount_candidate() == null, "una piccola non si pilota")
	_place(c, near); var broken := _caravan.add_machine(&"magnet"); _place(broken, near2); broken.break_down(); await _frames(1)
	_check(pilot.mount_candidate() == null and _caravan.repair_target() == broken, "con una guasta a 2 m vince la riparazione")
func _test_pilot_end_level() -> void:  # risalito
	_run._end_level(false); await _frames(1)
	_check(not pilot.is_mounted() and _player.pilot == null and _player._model.visible and _run.is_over, "fine livello: a terra, visibile")
func _test_bench_not_from_saddle() -> void:  # risalito, colosso sulla pedana aperta (land_at)
	_joy(JOY_BUTTON_X); await _frames(2); _check(not _run.fusion_pad.has_bench_request() and not _run.fusion_bench.is_open, "a bordo non si chiede il banco")
```

- [ ] **Step 2:** suite → FAIL (`pilot` nullo in `ArenaRun`).
- [ ] **Step 3:** implementare le interfacce; poi la cache delle classi.
- [ ] **Step 4:** `colossus_tests`, `fusion_tests`, `caravan_tests`, `machine_damage_tests`, `machine_modules_tests`, `loadout_tests`, `arena_run_tests`, `input_events_tests` verdi; `--check-only` su tutti gli script toccati.
- [ ] **Step 5: commit** `Carovana (D-093), piano C: colosso pilotato (ColossusPilot: salita e discesa tenendo Interagisci, carburante, sbalzo; Machine guidata dallo stick, +50% ai moduli, mira di Trivella e Pala; giocatore a bordo senza armi, attrezzo, scatto ne danni); test`.

### Task 6: il Meccanico

**Files:** Modify `godot/scripts/progression/class_catalog.gd` (voce `mechanic`: `start_machines`, `text`; `static func start_machines(id)`), `godot/scripts/progression/upgrade_catalog.gd` (carta `mobile_workshop` dopo `field_weld` :91-93), `godot/scripts/progression/class_perks.gd` (`IDS` :9, `apply` :52), `godot/scripts/progression/permanent_catalog.gd` (testo di `fixed_turret`), `godot/scripts/run/arena_run.gd` (`_setup_loadout` ~:1425-1455: le macchine di partenza dopo `loadout.setup_class`), `godot/scripts/combat/weapons/crane_magnet.gd` (`_follow_lead` :170), `godot/scripts/combat/weapons/welder.gd` (`_lead` :190). Test: `colossus_tests.gd`, sezione `_test_mechanic` (run con `class_id = &"mechanic"`: come `classes_tests` imposta la classe prima del `_ready`), e `classes_tests.gd` (il controllo sul kit del Meccanico).

**Interfaces — Consumes:** task 2 (`extra_module_slots`, `nearest_cargo_machine`). **Produces:**
- `ClassCatalog`: voce `mechanic` con `start_machines = [&"turret"]` e `text = "Carovana potenziata: due macchine, archi elettrici e calamite."`; `static func start_machines(id: StringName) -> Array[StringName]` (vuoto per le altre classi).
- `UpgradeCatalog`: `{id = &"mobile_workshop", deck = &"mechanic", name = "Officina mobile", category = &"companion", rarity = Rarity.RARE, max_level = 1, requires = "caravan", values = {modules = 1}, text = "La carovana porta {modules} modulo in piu: un colosso e una macchina piccola."}`.
- `ClassPerks`: `IDS` con `&"mobile_workshop"`; `apply(&"mobile_workshop", level)` → `caravan.extra_module_slots = int(UpgradeCatalog.value(id, &"modules", 1.0)) x level` e `caravan.changed.emit()`.
- `PermanentCatalog`: `fixed_turret.text = "Parti con una macchina in piu, con la Torretta."`.
- `ArenaRun._setup_loadout`: dopo `loadout.setup_class(class_id)` e prima delle carte di partenza: `for module_id in ClassCatalog.start_machines(class_id): caravan.add_machine(module_id)` (se `caravan != null`).
- `CraneMagnet._follow_lead` e `Welder._lead`: `caravan.nearest_cargo_machine(shooter.global_position)` al posto di `caravan.lead()` (il nome dei metodi puo restare).

- [ ] **Step 1: test che falliscono:**

```gdscript
func _test_mechanic_start() -> void:  # run del Meccanico appena pronta
	_check(_caravan.machines.size() == 2 and _caravan.count_of(&"cargo") == 1 and _caravan.count_of(&"turret") == 1, "parte con Cassone e Torretta")
	_check(ClassCatalog.start_machines(&"engineer").is_empty() and ClassCatalog.start_machines(&"mechanic") == [&"turret"], "solo il Meccanico")
func _test_mechanic_fixed_turret() -> void:  # profilo in memoria con fixed_turret = 1, run nuova
	_check(_caravan.machines.size() == 3 and _caravan.count_of(&"turret") == 2, "Torretta fissa: terza macchina")
func _test_mobile_workshop() -> void:
	while _caravan.has_room(): _caravan.add_machine(&"magnet")
	_check(_caravan.module_count() == 6, "piena a 6")
	_run.apply_upgrade(&"mobile_workshop", _run.progression.choose(&"mobile_workshop"))
	_check(_caravan.module_limit() == 7 and _caravan.has_room() and _caravan.add_machine(&"beacon") != null, "Officina mobile: settimo modulo")
	var card := UpgradeCatalog.find(&"mobile_workshop")
	_check(card.deck == &"mechanic" and card.rarity == UpgradeCatalog.Rarity.RARE and card.max_level == 1 and ClassPerks.handles(&"mobile_workshop"), "carta Rara del Meccanico, gestita dai perk")
	_check(MachineOffers.cards(_caravan, &"mechanic", [&"drill"]).is_empty(), "a 7 nessuna carta macchina")
func _test_crane_follows_nearest_cargo() -> void:  # Meccanico con crane_magnet al livello con `mobile` > 0 (set_level o choose_branch come in loadout_tests)
	var far := _caravan.lead(); var near := _caravan.add_machine(&"cargo")
	_place(far, _player.global_position + Vector3(12, 0, 0)); _place(near, _player.global_position + Vector3(2, 0, 0))
	crane._fire(_player.global_position); await _frames(2)
	_check(crane.pull_center().distance_to(near.global_position) < 0.5, "la Calamita da gru segue il Cassone piu vicino")
```

- [ ] **Step 2:** suite → FAIL (`start_machines` sconosciuto).
- [ ] **Step 3:** implementare; aggiornare in `classes_tests.gd` il controllo del testo o del kit del Meccanico se lo cita.
- [ ] **Step 4:** `colossus_tests`, `classes_tests`, `loadout_tests`, `run_progression_tests`, `workshop_tests` (testo di Torretta fissa, se controllato) verdi; `--check-only`.
- [ ] **Step 5: commit** `Carovana (D-093), piano C: il Meccanico parte con due macchine, carta Officina mobile (7 moduli), Calamita da gru e Saldatore sulla macchina col Cassone piu vicina; test`.

### Task 7: scheda Macchine dell'Officina e moduli sbloccati

**Files:** Modify `godot/scripts/progression/permanent_catalog.gd` (`GROUPS` :13, `_build` :28, costanti e funzioni nuove), `godot/scripts/services/player_profile.gd` (dopo `unlocked_weapons` :158), `godot/scripts/ui/workshop_panel.gd` (`TAB_NAMES` :16; le griglie seguono `GROUPS`; `UiIcon.for_permanent` per l'icona del modulo: in `godot/scripts/ui/ui_icon.gd`), `godot/scripts/run/arena_run.gd` (`_available_modules` :1462; `_apply_permanent_upgrades` :616 ignora le voci `unlock_module_`), `godot/scripts/caravan/machine_catalog.gd` (commento d'intestazione: non piu "tutti e otto per prova"). Test: `colossus_tests.gd`, sezione `_test_workshop` (profilo in memoria, `WorkshopPanel` come in `workshop_tests._test_workshop_tabs`), `workshop_tests.gd` (numeri delle schede: 1 → "Ingegnere" resta, l'ultima resta il Ricettario, `PagSu` dalla prima va a 6), `ui_theme_tests.gd` (conteggio delle carte dell'Officina: +4).

**Interfaces — Consumes:** niente dai task precedenti (indipendente). **Produces:**
- `PermanentCatalog`: `GROUPS` con `[&"machines", "Macchine"]` dopo `weeder`; `const MODULE_UNLOCK_PREFIX := "unlock_module_"`; `const MODULE_UNLOCK_COSTS: Dictionary[StringName, int] = {&"drill": 15, &"shovel": 18, &"welder": 22, &"siren": 25}`; in `_build`, per ogni modulo di `MachineCatalog.all()` con `unlocked_by_default` falso: `{id = module_unlock_id(id), group = &"machines", module = id, name = "Sblocca: %s" % name, costs = [MODULE_UNLOCK_COSTS[id]], text = entry.text}`; `static func module_unlock_id(module_id) -> StringName`; `static func module_of(id) -> StringName` (`&""` se non e uno sblocco di modulo).
- `PlayerProfileService.unlocked_modules() -> Array[StringName]`: nell'ordine di `MachineCatalog.MODULES`, i moduli `unlocked_by_default` piu quelli con `level_of(module_unlock_id) >= 1`.
- `WorkshopPanel.TAB_NAMES = ["Comune", "Ingegnere", "Guastatore", "Meccanico", "Erbacciaia", "Macchine", "Ricettario"]`; `UiIcon.for_permanent(id)` restituisce l'icona del modulo per le voci `unlock_module_`.
- `ArenaRun._available_modules()`: con profilo `profile.unlocked_modules()`, senza profilo gli otto con script come oggi. `_apply_permanent_upgrades`: `if PermanentCatalog.module_of(id) != &"": continue` prima del `match` (niente effetto all'avvio, niente riga in `applied`). `buy` di una voce di modulo stampa anche `PROTOTYPE01_WORKSHOP_MODULE_UNLOCKED id=` (in `PlayerProfileService.buy`, se `module_of(id) != &""`).

- [ ] **Step 1: test che falliscono:**

```gdscript
func _test_workshop_catalog() -> void:
	var entry := PermanentCatalog.find(&"unlock_module_drill")
	_check(entry.group == &"machines" and entry.costs == [15] and entry.module == &"drill" and entry.name == "Sblocca: Trivella", "voce della Trivella")
	_check(PermanentCatalog.find(&"unlock_module_siren").costs == [25] and PermanentCatalog.find(&"unlock_module_cargo").is_empty(), "Sirena 25; il Cassone non si compra")
	_check(PermanentCatalog.GROUPS[5][0] == &"machines" and PermanentCatalog.module_of(&"unlock_module_shovel") == &"shovel" and PermanentCatalog.module_of(&"cargo") == &"", "gruppo Macchine e module_of")
func _test_profile_unlocked_modules() -> void:
	var profile := _new_profile()  # in memoria
	_check(profile.unlocked_modules() == [&"cargo", &"turret", &"magnet", &"beacon"], "di serie quattro")
	profile.scrap = 40; _check(profile.buy(&"unlock_module_welder") and profile.unlocked_modules() == [&"cargo", &"turret", &"magnet", &"beacon", &"welder"], "comprato il Saldatore")
	profile.save_profile(PROFILE_PATH); var again := _new_profile(); again.load_profile(PROFILE_PATH)
	_check(again.level_of(&"unlock_module_welder") == 1 and again.loaded_version == 3 and again.unlocked_modules().has(&"welder"), "si risalva in [upgrades], profilo v3")
func _test_workshop_tab() -> void:
	var workshop := _run.workshop  # o uno nuovo come in workshop_tests
	workshop.open(); workshop.show_tab(5)
	_check(WorkshopPanel.TAB_NAMES.size() == 7 and WorkshopPanel.TAB_NAMES[5] == "Macchine" and WorkshopPanel.TAB_NAMES[6] == "Ricettario", "schede")
	_check(workshop._tab_grids[5].get_child_count() == 4 and workshop.row_text(&"unlock_module_drill").begins_with("Sblocca: Trivella"), "quattro carte")
	_check((workshop._buttons[&"unlock_module_drill"].get_node(^"Icon") as UiIcon).kind == &"drill", "icona della Trivella")
	profile.scrap = 15; workshop.press(&"unlock_module_drill")
	_check(profile.level_of(&"unlock_module_drill") == 1 and workshop.row_text(&"unlock_module_drill").contains("1/1"), "comprata")
func _test_run_filters_modules() -> void:  # run con profilo in memoria: solo la Trivella comprata
	_check(_run._available_modules() == [&"cargo", &"turret", &"magnet", &"beacon", &"drill"], "carte e relitti offrono solo i moduli sbloccati")
	var cards := MachineOffers.cards(_caravan, &"engineer", _run._available_modules())
	_check(cards.all(func(c: Dictionary) -> bool: return c.module_id != &"siren"), "nessuna Sirena nelle carte")
	_check(_caravan.add_machine(&"siren") != null, "una Sirena ottenuta altrove resta possibile")
	# senza profilo: tutti e otto (suite e catture)
	_run._profile = null; _check(_run._available_modules().size() == 8, "senza profilo tutti")
```

- [ ] **Step 2:** suite → FAIL (`unlock_module_drill` non trovato).
- [ ] **Step 3:** implementare; aggiornare `workshop_tests` (indici delle schede: "LB dalla prima gira all'ultima" resta `size - 1`; `PagSu` da 0 va a 6; se un controllo cita il numero 5 come Ricettario, diventa 6) e `ui_theme_tests` (conteggio delle carte +4).
- [ ] **Step 4:** `colossus_tests`, `workshop_tests`, `ui_theme_tests`, `fusion_tests` (profilo), `economy_tests`, `campaign_tests` verdi; `--check-only`.
- [ ] **Step 5: commit** `Carovana (D-093), piano C: scheda Macchine dell'Officina (Trivella 15, Pala 18, Saldatore 22, Sirena 25), moduli sbloccati nel profilo come le armi, carte e relitti filtrati in run; test`.

### Task 8: bot, benchmark, catture, documenti, build

**Files:** Modify `godot/tests/tools/simulate_runs.gd` (`_tick_bot` :410, campi della riga `PROTOTYPE01_SIM`, intestazione), `godot/tests/tools/benchmark_arena.gd` (`_bench_colossus` :315: riga nuova `caravan_colossus_piloted`), `godot/tests/tools/capture_caravan.gd` (`_fusion_shots` :301: tre scatti nuovi), `docs/GODOT_WORKFLOW.md` (sezione "Carovana (D-093, piano C)" dopo quella del piano B), `docs/DECISIONS.md` (D-093: paragrafo "Piano C fatto", scelte 1-10 e debito), `docs/superpowers/specs/2026-10-15-caravan-machines-design.md` (intestazione: piano C fatto), `docs/MIGRATION_STATUS.md`, `docs/PROJECT_ROADMAP.md` ("Stato operativo"), `docs/INDEX.md` (questo piano). Nessun test nuovo: la verifica e il gate, i numeri del benchmark e le catture guardate.

**Interfaces — Consumes:** tutti i task. **Produces:**
- Bot: `_tick_relics() -> bool` prima di `_tick_fusion`: con un relitto entro 12 m, posto in carovana e nemico piu vicino oltre `BRUSH_SAFE_M`, il bot ci va e, entro `relic_pickup_range` meno 0,2, preme Interagisci (`interact_pressed.emit()`), una volta per relitto; campo `relics=` (presi dal bot) e `piloted=0` nella riga `PROTOTYPE01_SIM`; `--profile=unlock_module_drill:1` documentato nell'intestazione.
- Benchmark: dopo la riga `caravan_colossus`, `_bench_colossus_piloted`: il giocatore sale (`run.pilot.mount(lead)`), `lead.pilot_input = Vector3.FORWARD` per la finestra (`_caravan_window`), poi `dismount`; riga `PROTOTYPE01_ARENA_BENCH caravan_colossus_piloted preset= modules= step_ms= max_ms= trampled= writes=` (budget 0,5 ms: con la Trivella e la Pala nel colosso la finestra misura anche la Ruspa in moto, debito del piano B). I robusti restano sul grappolo: a bordo il colosso avanza verso di loro e travolge.
- Catture (`output/caravan/`): `colossus_piloted` (giocatore a bordo, tasto "Scendi", colosso in moto), `module_relic` (relitto della Torretta a 1,5 m dal giocatore col luccichio e il tasto "Riprendi"), `workshop_machines` (Officina aperta sulla scheda Macchine; profilo in memoria con 20 rottami); una riga `PROTOTYPE01_CAPTURE_CARAVAN shot=<nome> err=0 ...` per scatto.
- Documenti: sezione del workflow con comandi verificati, marker e trappole del piano C; D-093 con le dieci scelte, i numeri del benchmark e il debito; stato e roadmap con "piano C fatto, prossimo: playtest del proprietario della carovana completa, poi bilanciamento coi bot"; export Windows in `LocalBuilds/Prototype01-Godot-Win64/`.

- [ ] **Step 1:** bot: `simulate_runs.gd -- --bots=scrapper --seeds=1-3 --max-seconds=300 --boss-at=300 --profile=cargo:3,stock:2,unlock_module_drill:1 --caravan=turret,turret,drill,magnet,siren` verde (`fusions=5 colossus=1` nei semi 1 e 3 come nel piano B, `relics=0`); una run con `--quake-at=120` e `--caravan=turret` su un seme in cui la faglia passa sul grappolo mostra `MODULE_DETACHED by=quake` e `relics=1` (se nessun seme fra 1 e 10 la passa, annotarlo come limite, non forzare).
- [ ] **Step 2:** benchmark: `benchmark_arena.gd -- --enemies=70 --preset=deck` (con finestra) → righe `caravan`, `caravan_colossus`, `caravan_colossus_piloted` con `step_ms` sotto 0,5; `--night` invariato. Numeri nel workflow e in D-093.
- [ ] **Step 3:** catture: il comando del piano A, sedici scatti, `err=0`; aprire i tre PNG nuovi e descriverli in una riga ciascuno nello stato (il proprietario giudica).
- [ ] **Step 4:** documenti e `INDEX.md`; `MIGRATION_STATUS.md` sotto 8 KB (il vecchio in `docs/archive/STATUS_LOG_2026-10.md`).
- [ ] **Step 5:** gate completo `powershell -ExecutionPolicy Bypass -File tools/godot/Invoke-GodotChecks.ps1` verde (60 suite); export Windows e avvio con `--autostart` pulito.
- [ ] **Step 6: commit** `Carovana (D-093), piano C chiuso: bot che riprendono i relitti, riga caravan_colossus_piloted del benchmark, catture del colosso pilotato, del relitto e della scheda Macchine; documenti`.

---

## Esecuzione

In sequenza, un esecutore nuovo per task e una revisione prima del successivo: i task condividono `caravan.gd`, `machine.gd` e `arena_run.gd`, e le suite Godot non girano in parallelo. Il task 7 e indipendente e puo andare in qualunque momento. Gate completo dopo i task 3, 5, 7 e 8; negli altri le suite elencate. Nessuna scena toccata: col proprietario nell'editor basta dirgli quali script cambiano. Il risultato di Codex o di un subagente resta non verificato finche il controllore non rilegge diff, suite e gate.

## Stato dell'esecuzione

(da compilare task per task: data, commit, scelte prese, debito lasciato, numeri del benchmark)
