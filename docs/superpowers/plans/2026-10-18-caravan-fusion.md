# Carovana, piano B: fusione — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la carovana del piano A impara a fondersi (spec D-093, Sezione 2 e le parti delle Sezioni 1, 5, 6 che la Sezione 7 assegna al piano B): piazzola di fusione a meta della chiamata del boss, banco in pausa per fondere e sganciare coi rottami dei Cassoni, taglie (piccola, media, grande, colosso) con vita, velocita e forza, travolgere, le sei combinazioni, la sezione Combinazioni del Ricettario e il profilo versione 3.

**Architecture:** la logica pura delle taglie, dei costi e dell'anteprima sta in `MachineFusion` (nuova, `RefCounted`); i dati delle combinazioni in `MachineCatalog`. `Caravan` guadagna `fuse`, `detach` e `remove_machine` (il debito del piano A); `Machine` diventa multi-modulo (pezzi impilati, scala del modello, vita e velocita per taglia, `power` ai moduli). `FusionPad` (nodo creato da `ArenaRun`, nessuna scena toccata) arriva, si annuncia, atterra, chiede il banco e si richiude alla chiamata del boss; `FusionBench` (CanvasLayer creato da `ArenaRun`) ferma il gioco come il level-up e si apre solo a fine passo dalla coda `_open_next_level_up`. Il profilo v3 aggiunge la sezione `[machines]`; il Ricettario dell'Officina la mostra sotto le fusioni delle armi.

**Tech Stack:** Godot 4.7.2, GDScript, suite headless (`extends SceneTree`), gate `tools/godot/Invoke-GodotChecks.ps1`.

**Spec:** `docs/superpowers/specs/2026-10-15-caravan-machines-design.md` (Sezione 2; Sezione 1 per taglie e combinazioni; Sezione 5 per Ricettario e profilo v3; Sezione 6 per HUD, prestazioni e bot; "Valori di partenza"; "Verifica"). Modello di formato e convenzioni: `docs/superpowers/plans/2026-10-16-caravan-machines.md` (piano A, fatto). Righe del codice citate a HEAD `f400c19`: riverificarle prima di toccarle.

**Stato:** fatto il 19 ottobre 2026.

## Global Constraints

- Valori di partenza della spec in `CaravanTuning` (`godot/resources/tuning/caravan_default.tres`); i nodi copiano i valori e non modificano la risorsa. Tutti i valori nuovi del piano B nascono nel task 1, coi default scritti li e nel `.tres`.
- Interagisci = azione `interact` (X del controller, R della tastiera): ripara tenendo premuto vicino a una macchina guasta e, sulla pedana, apre il banco alla pressione. Controller e tastiera/mouse equivalenti, controller prima: il banco si usa tutto col controller (A, B, croce o stick, LB/RB) come le Impostazioni e l'Officina, con Invio, Esc, frecce, PagSu/PagGiu e mouse come equivalenti; focus sempre visibile (`docs/PLATFORM_AND_INPUT.md`).
- Macchine sul layer 8 con maschera 1; contatti e travolgere a distanza, nel codice, riusando i secchi di `EnemyDirector` (mai un secondo giro su tutti i nemici). La pedana non ha collisione.
- Ogni scrittura sul terreno dei moduli passa da `TerrainWriteQueue` (`push_level`, `DigCharge.dig_crater`); ogni macchina sta in `write_queue.bodies` finche esiste e ne esce in `remove_machine` (un `erase` per macchina, mai assegnare liste: `Array[Node3D]` tipizzato). La pedana non scrive il terreno: lo protegge (`set_protected`) finche e aperta.
- Nessun menu a meta passo fisico: il banco si apre solo da `ArenaRun._open_next_level_up` (fine del passo, `process_physics_priority = 100`), dopo casse, relitti e level-up; `fuse` e `detach` girano solo dal banco, ad albero fermo.
- Tempi in `delta`, mai in passi (gioco a 120 Hz, suite a 60 Hz); ogni teletrasporto di una macchina chiama `reset_physics_interpolation()`.
- Uno script non nomina il proprio `class_name`. Dopo ogni `class_name` nuova (`MachineFusion`, `FusionPad`, `FusionBench`): `godot_console --headless --path godot --editor --quit`, poi `git diff godot/project.godot` e annullare solo il riordino dell'editor (`[physics]`); controllare che i pulsanti A/B di `ui_accept`/`ui_cancel` e l'azione `interact` siano rimasti.
- Suite una alla volta (processi Godot rimasti scrivono sullo stesso log: ucciderli prima); `--check-only` su ogni script toccato; la suite nuova `fusion_tests.gd` segue lo scheletro di `tests/machine_wrecks_tests.gd` (`_check`, `_frames`, seme `PROTOTYPE01_SEED` 20261014 se manca, due `physics_frame` prima di `quit`, marker `PROTOTYPE01_TESTS`).
- Profilo invariato fino al task 7; il task 7 porta `PlayerProfileService.VERSION` a 3 e un profilo v2 si carica intatto. Le suite adattate restano forti quanto prima: si cambia il soggetto, non si toglie un controllo senza dirlo nel commit.
- Il piano B non tocca scene `.tscn` ne `project.godot` (piazzola e banco nascono nel codice). Se un esecutore ne avesse bisogno: `tasklist | grep -i godot` vuoto prima, altrimenti avvisare il proprietario e non toccare.
- Una macchina ha al piu `max_modules_per_machine` (6) moduli; il limite della carovana resta `module_limit` (6; 7 con l'Officina mobile del piano C).
- Testi del gioco in italiano senza accenti tipografici; identificatori in inglese. Budget: carovana 0,5 ms per passo sul preset Deck, sia con sei macchine piccole sia col colosso.
- Benchmark: le righe `frame`, `run` e `path` sono misurate ad albero fermo (debito del piano A, D-093): non usarle per giudicare il piano B; valgono le righe `caravan*`.

## Scelte di questo piano (da registrare in D-093)

1. **Pedana.** 4x4 celle da `pad_cell_m` 1,5 m: quadrato di 6 m di lato (la griglia storica aveva celle da circa 2,4 m e la piazzola di estrazione 3x3 e diventata un disco di 3 m). Atterra su un punto a 20-30 m dal giocatore (misurati all'inizio della ricerca) dove il disco circoscritto (raggio 4,24 m) e piano entro `pad_flat_tolerance` 0,35 m, il centro sta entro 0,35 m dalla base (ne cumulo ne buca), e percorribile e raggiungibile (`PathField`), fuori dai binari e senza lampioni sotto. Senza un punto cosi: il candidato raggiungibile piu piano; senza nemmeno quello, il punto di partenza del livello. Da aperta protegge il suo disco (attrezzo, terremoto, moduli non lo scavano). Solo modello: nessuna collisione, nessuna sorgente di `LightField` (la luce e visiva; la logica del buio non cambia).
2. **Verso della fusione.** Si sceglie prima la macchina base, poi quella da assorbire: la seconda entra nella prima, che tiene posto, nome e ordine nella carovana. Costo = `fuse_cost_per_module` x moduli della seconda (l'anteprima lo mostra: scegliere la piu grande come base costa meno).
3. **Vita.** Fondendo e sganciando si conserva la frazione di vita (`carried_health`); la macchina sganciata nasce piena (telaio nuovo). Macchine guaste: non si fondono, non si sganciano, non si scelgono.
4. **Forza** (`power` = 1 + 0,15 per modulo oltre il primo, a tutti i moduli della macchina): Torretta intervallo / power; Calamita, Faro e Sirena raggio x power; Trivella, Pala e Saldatore intervallo / power (il Saldatore anche i 6 s sulle guaste); Cassone raggio di ricerca dei rottami x power (la capienza resta 5: l'economia non cambia).
5. **Taglia nel mondo.** Modello, pezzi, cubetti, anello a terra e raggio di contatto in scala `size_model_scale` [1,0; 1,25; 1,5; 1,8] attorno al punto a terra; collisione invariata. Pezzi dello stesso tipo: `TurretPart`, `TurretPart2`, ...; impilati sul pianale secondo `Machine.PART_STACK`.
6. **Travolgere.** Da media in su, non guasta, in moto a piu di 1 m/s: 1 danno a ogni rottamatore (non i boss) entro il proprio raggio di contatto, al piu ogni `trample_interval` 0,5 s per macchina; anche da immune e in ritirata.
7. **Combinazioni.** Valgono solo coi due moduli nella stessa macchina e a macchina non guasta. Riflettore: nemico entro il raggio del Faro della stessa macchina (di giorno e di notte, domanda per il proprietario). Trappola: nemico entro il raggio della Sirena della stessa macchina mentre attira. I due raddoppi si moltiplicano (x4). Esca blindata: meta danno con resto accumulato (due colpi da 1 tolgono 1 PV). Betoniera mobile: argine gratis e senza riserva. Estrattore: i rottami a terra entro `extractor_radius` 3 m dalla buca (e quello cavato da una vena) vanno nei Cassoni, se c'e posto. Ruspa: ogni 1,5 m percorsi un fossato (raggio 0,8 m, 0,4 m) dietro la macchina oltre `keep_clear` e un argine (raggio 0,8 m, +0,6 m) a lato, gratis, con le regole di `clear_spot`.
8. **Capofila.** `lead()` = la macchina piu vecchia con un Cassone non guasto; altrimenti la piu vecchia con un Cassone; altrimenti la prima; altrimenti null (risponde anche alla domanda di playtest del piano A sul capofila guasto).
9. **Interagisci sulla pedana.** Con una macchina guasta entro 2 m vince la riparazione; altrimenti la pressione chiede il banco. Se nello stesso passo si apre un altro menu (cassa, relitto, level-up), la richiesta si scarta: il banco si riapre con una pressione nuova.
10. **Profilo v3.** `[machines] combinations = PackedStringArray(...)`; chiavi sconosciute di `[machines]` conservate (il piano C vi aggiungera i moduli sbloccati).
11. **HUD.** Casella larga `SLOT_SIZE + 14 x taglia` (40, 54, 68, 82 px), un quadratino del colore di ogni modulo oltre il primo, vita a tacche fino a 12 PV e a barra oltre; tasto "Banco" accanto a "Ripara", acceso sulla pedana.
12. **Nomi e marker.** Classi `MachineFusion`, `FusionPad`, `FusionBench`; marker `MACHINE_FUSED`, `MACHINE_DETACHED`, `MACHINE_REMOVED`, `COMBO_FORMED`, `FUSION_PAD_WARNING`, `FUSION_PAD_LANDED`, `FUSION_PAD_CLOSED`, `FUSION_BENCH_OPENED`, `FUSION_BENCH_CLOSED`, `COMBO_DISCOVERED`, `EXTRACTOR`, `DOZER_TRENCH` (tutti con prefisso `PROTOTYPE01_`).

## Review Focus

1. La pedana cade su una buca scavata, un cumulo, i binari, un punto irraggiungibile, o il terreno cambia sotto di lei dopo l'atterraggio: deve atterrare su un tratto piano raggiungibile (o sul ripiego) e restare intatta finche e aperta. → test nel task 4.
2. Fondere o sganciare il Cassone capofila, una macchina coi rottami a bordo o due moduli dello stesso tipo: i rottami restano (meno il costo), `lead()` resta valido, nessuna macchina liberata resta in `write_queue.bodies`, i pezzi e i nodi hanno nomi distinti, i posti del grappolo restano unici. → test nel task 2.
3. Una macchina guasta o in riparazione al banco: non si sceglie; sulla pedana accanto a una guasta Interagisci ripara invece di aprire il banco; una riparazione in corso su una macchina tolta si azzera senza spendere. → test nei task 2 e 5.
4. Banco e altri menu nello stesso passo (level-up, cassa, relitto, chiamata del boss), Start a banco aperto, l'orda sulla pedana: un menu alla volta, nessuna scelta persa, a banco aperto il tempo e la vita non cambiano, B chiude e toglie la pausa una volta, la pressione che chiude non riapre. → test nel task 5.
5. Profilo v2 (o di una versione futura) con chiavi sconosciute o valori non validi in `[machines]`: si carica intatto, si risalva come v3 (o resta alla versione piu alta), nessuna chiave persa, nessun errore. → test nel task 7.

## Fuori dal piano B

Colosso pilotato (salire e scendere, armi e attrezzo spenti, carburante, sbalzo, +50%, travolgere i medi), eventi che staccano moduli e relitto del modulo staccato, Meccanico (partenza a due, Officina mobile a 7 moduli, armi sulla macchina col Cassone piu vicina), scheda Macchine dell'Officina e moduli sbloccati nel profilo, `colossus_tests`, catture del colosso pilotato e del modulo staccato: piano C. Del colosso il piano B porta solo il minimo per provare la fusione: una macchina da 6 moduli esiste, ha taglia `COLOSSUS`, vita 63, velocita 3,5 m/s e forza 1,75, resta autonoma e non si pilota.

Proposta al proprietario (non installare): pedana e gru dai pacchetti 3D CC0 di Kenney (kenney.nl; verificare quale pacchetto industriale ha una gru), costo zero, nessuna attribuzione dovuta, export Windows/Linux/Deck senza vincoli; oppure un modello dal flusso Blender del progetto come `companion_cart`. In questo piano primitive. Per il banco nessun addon: bastano i Control di Godot e `ButtonPrompts`.

---

### Task 1: taglie, costi, anteprima e combinazioni (logica pura)

**Files:** Create `godot/scripts/caravan/machine_fusion.gd`, `godot/tests/fusion_tests.gd`. Modify `godot/scripts/caravan/caravan_tuning.gd` (gruppo nuovo dopo `Wrecks`, :113), `godot/resources/tuning/caravan_default.tres`, `godot/scripts/caravan/machine_catalog.gd`.

**Interfaces — Produces:**
- `CaravanTuning`, `@export_group("Fusion")`: `size_min_modules := PackedInt32Array([1, 2, 4, 6])`, `max_modules_per_machine := 6`, `power_per_extra_module := 0.15`, `health_bonus_per_size := 0.25`, `speed_malus_per_size := 0.10`, `size_model_scale := PackedFloat32Array([1.0, 1.25, 1.5, 1.8])`, `trample_min_size := 1`, `trample_damage := 1`, `trample_interval := 0.5`, `trample_min_speed := 1.0`, `fuse_cost_per_module := 1`, `detach_cost_per_module := 1`. `@export_group("Fusion pad")`: `pad_boss_fraction := 0.5`, `pad_warning_seconds := 15.0`, `pad_distance_min := 20.0`, `pad_distance_max := 30.0`, `pad_cells := 4`, `pad_cell_m := 1.5`, `pad_flat_tolerance := 0.35`, `pad_candidates_per_step := 10`, `pad_search_lead_seconds := 1.0`, `pad_light_radius := 9.0`. `@export_group("Combinations")`: `combo_damage_scale := 2.0`, `combo_hit_scale := 0.5`, `extractor_radius := 3.0`, `dozer_spacing := 1.5`, `dozer_ditch_radius := 0.8`, `dozer_ditch_depth := 0.4`, `dozer_bank_offset := 1.6`, `dozer_bank_radius := 0.8`, `dozer_bank_height := 0.6`.
- `MachineCatalog`: `const COMBOS: Array[StringName] = [&"extractor", &"reflector", &"mobile_mixer", &"armored_bait", &"dozer", &"trap"]`; `static func combos() -> Array[Dictionary]` (costruito una volta, voci `{id, name, parts: Array[StringName], text}`); `static func find_combo(id: StringName) -> Dictionary` ({} se sconosciuto); `static func combos_of(module_ids: Array[StringName]) -> Array[StringName]` (nell'ordine di `COMBOS`, duplicati ignorati). Voci, testi esatti: Estrattore (drill + magnet, "Le buche risucchiano i rottami vicini nel Cassone."), Riflettore (turret + beacon, "I nemici illuminati prendono doppio danno dalla Torretta."), Betoniera mobile (shovel + cargo, "Gli argini della Pala sono gratis."), Esca blindata (welder + siren, "Mentre attira subisce meta danno."), Ruspa (drill + shovel, "Scava un fossato con un argine a lato dove passa."), Trappola (turret + siren, "Chi e attirato prende doppio danno dalla Torretta.").
- `class_name MachineFusion extends RefCounted`: `enum Size { SMALL, MEDIUM, LARGE, COLOSSUS }`; `const SIZE_NAMES: Array[String] = ["Piccola", "Media", "Grande", "Colosso"]`; `static func size_of(module_count: int, tuning: CaravanTuning) -> int` (indice piu alto con `size_min_modules[i] <= n`); `static func max_health_of(module_count: int, tuning: CaravanTuning) -> int` = `roundi(chassis_health * n * (1 + health_bonus_per_size * size))`; `static func speed_factor_of(module_count: int, tuning: CaravanTuning) -> float` = `1 - speed_malus_per_size * size`; `static func power_of(module_count: int, tuning: CaravanTuning) -> float` = `1 + power_per_extra_module * (n - 1)`; `static func model_scale_of(module_count: int, tuning: CaravanTuning) -> float`; `static func carried_health(health_sum: int, max_sum: int, new_max: int) -> int` = `clampi(roundi(new_max * health_sum / float(max_sum)), 1, new_max)`; `static func fuse_cost(absorbed_modules: int, tuning: CaravanTuning) -> int`; `static func detach_cost(tuning: CaravanTuning) -> int`; `static func preview_fuse(base_ids: Array[StringName], base_health: int, base_max: int, other_ids: Array[StringName], other_health: int, other_max: int, tuning: CaravanTuning) -> Dictionary` = `{modules, size, max_health, health, speed (m/s = max_speed x fattore), power, combos, new_combos (del risultato e di nessuna delle due), cost, allowed (n <= max_modules_per_machine)}`; `static func preview_detach(ids: Array[StringName], index: int, health: int, max_health: int, tuning: CaravanTuning) -> Dictionary` = `{source: {modules, size, max_health, health, speed, combos}, detached: {modules, size, max_health, health, speed}, lost_combos, cost, allowed (ids.size() >= 2)}`.

- [x] **Step 1: test che falliscono** (`fusion_tests.gd`, sezione logica, senza scene):

```gdscript
func _test_sizes() -> void:  # tuning = load("res://resources/tuning/caravan_default.tres")
	var sizes := [0, 1, 1, 2, 2, 3]; var health := [6, 15, 23, 36, 45, 63]
	var speed := [5.0, 4.5, 4.5, 4.0, 4.0, 3.5]; var power := [1.0, 1.15, 1.30, 1.45, 1.60, 1.75]
	for n in range(1, 7):
		_check(MachineFusion.size_of(n, t) == sizes[n - 1], "taglia di %d moduli" % n)
		_check(MachineFusion.max_health_of(n, t) == health[n - 1], "vita di %d moduli" % n)
		_check(is_equal_approx(t.max_speed * MachineFusion.speed_factor_of(n, t), speed[n - 1]), "velocita di %d" % n)
		_check(is_equal_approx(MachineFusion.power_of(n, t), power[n - 1]), "forza di %d" % n)
	_check(MachineFusion.SIZE_NAMES[3] == "Colosso", "nomi delle taglie")
func _test_costs() -> void:
	_check(MachineFusion.fuse_cost(1, t) == 1 and MachineFusion.fuse_cost(3, t) == 3 and MachineFusion.detach_cost(t) == 1, "costi")
	var total := 0
	for i in 5: total += MachineFusion.fuse_cost(1, t)
	_check(total == 5, "sei piccole in un colosso: 5 rottami")
func _test_combos() -> void:
	_check(MachineCatalog.COMBOS.size() == 6 and MachineCatalog.find_combo(&"dozer").name == "Ruspa", "sei combinazioni coi nomi della spec")
	_check(MachineCatalog.find_combo(&"extractor").parts == [&"drill", &"magnet"], "parti dell'Estrattore")
	_check(MachineCatalog.combos_of([&"magnet", &"drill"]) == [&"extractor"], "l'ordine dei moduli non conta")
	_check(MachineCatalog.combos_of([&"turret", &"beacon", &"siren"]) == [&"reflector", &"trap"], "due combinazioni in una macchina")
	_check(MachineCatalog.combos_of([&"drill", &"shovel", &"cargo"]) == [&"mobile_mixer", &"dozer"], "Betoniera e Ruspa")
	_check(MachineCatalog.combos_of([&"turret", &"turret"]).is_empty() and MachineCatalog.find_combo(&"nope").is_empty(), "nessuna")
func _test_preview() -> void:
	var p := MachineFusion.preview_fuse([&"drill"], 6, 6, [&"magnet"], 3, 6, t)
	_check(p.size == 1 and p.max_health == 15 and p.health == 11 and is_equal_approx(p.speed, 4.5), "anteprima: media, 11/15, 4,5 m/s")
	_check(p.combos == [&"extractor"] and p.new_combos == [&"extractor"] and p.cost == 1 and p.allowed, "anteprima: combinazione nuova, costo 1")
	var d := MachineFusion.preview_detach([&"turret", &"beacon", &"siren"], 2, 23, 23, t)
	_check(d.source.max_health == 15 and d.source.health == 15 and d.detached.max_health == 6, "sgancio: 15/15 e 6/6")
	_check(d.lost_combos == [&"trap"] and d.source.combos == [&"reflector"] and d.cost == 1, "sgancio: Trappola persa")
	_check(not MachineFusion.preview_detach([&"cargo"], 0, 6, 6, t).allowed, "una piccola non si sgancia")
	_check(not MachineFusion.preview_fuse([&"cargo", &"turret", &"magnet"], 23, 23, [&"drill", &"shovel", &"siren", &"welder"], 36, 36, t).allowed, "oltre 6 moduli no")
func _test_tuning() -> void:  # valori della spec nel .tres
	_check(t.size_min_modules == PackedInt32Array([1, 2, 4, 6]) and is_equal_approx(t.power_per_extra_module, 0.15), "taglie e forza")
	_check(is_equal_approx(t.pad_boss_fraction, 0.5) and t.pad_warning_seconds == 15.0 and t.pad_distance_min == 20.0 and t.pad_distance_max == 30.0 and t.pad_cells == 4, "piazzola")
	_check(t.fuse_cost_per_module == 1 and t.detach_cost_per_module == 1 and t.max_modules_per_machine == 6, "costi e massimo per macchina")
```

- [x] **Step 2:** `godot_console --headless --path godot --fixed-fps 60 --script res://tests/fusion_tests.gd` → FAIL (`MachineFusion` sconosciuta).
- [x] **Step 3:** implementare le interfacce sopra; poi la cache delle classi (Global Constraints).
- [x] **Step 4:** `fusion_tests.gd` → `PROTOTYPE01_TESTS PASS failures=0`; `machine_catalog_tests.gd` verde; `--check-only` sui tre script.
- [x] **Step 5: commit** `Carovana (D-093), piano B: taglie, costi, anteprima e combinazioni (MachineFusion, MachineCatalog.COMBOS, valori in CaravanTuning); test`.

### Task 2: Machine multi-modulo; fuse, detach e remove_machine nella carovana

**Files:** Modify `godot/scripts/caravan/machine.gd` (`add_module` :165-175, `mount_part` :526-541, `set_cargo_view` :513, velocita :348, `_refresh_ring` :658, `RING_SIZE` :74), `godot/scripts/caravan/caravan.gd` (`lead` :165-169, `_add_machine` :447-486, `_track_body` :511), `godot/scripts/caravan/modules/cargo_module.gd` (setter :13-19), `godot/scripts/caravan/modules/welder_module.gd` (`_broken_elapsed` :14). Test: `godot/tests/fusion_tests.gd` (sezione carovana, `ruins_arena.tscn` come `caravan_tests` con una `TerrainWriteQueue` creata nel test e passata a `configure`), adattare `caravan_tests.gd` solo se un controllo dipende dal capofila guasto.

**Interfaces — Consumes:** task 1. **Produces:**
- `Machine`: `const PART_STACK := PackedVector3Array([Vector3(0, 0, 0), Vector3(0.32, 0.3, 0), Vector3(-0.32, 0.3, 0), Vector3(0.32, 0.6, 0), Vector3(-0.32, 0.6, 0), Vector3(0, 0.9, 0), Vector3(0, 1.2, 0)])` (scarto del pezzo del modulo i-esimo rispetto alla posizione del suo `build_part`); `var size := MachineFusion.Size.SMALL`, `var power := 1.0`, `var speed_factor := 1.0`, `var model_scale := 1.0`; `func module_ids() -> Array[StringName]`; `func combos() -> Array[StringName]` (in cache, rifatta a ogni modulo aggiunto o tolto); `func has_combo(id: StringName) -> bool` (falso da guasta); `func remove_module(module: MachineModule) -> void` (fuori dall'albero subito, pezzo tolto, ricostruzione); `func refresh_cargo_view() -> void` (cubetti = somma di capienza e carico dei suoi Cassoni); `func top_speed() -> float` = `max_speed x caravan.speed_scale x speed_factor`; `func contact_reach() -> float` = `contact_radius x model_scale`. Ricostruzione privata dopo ogni `add_module`/`remove_module`: taglia, forza, fattore di velocita, scala; `max_health = MachineFusion.max_health_of(n)` con `health` limitata al nuovo massimo (la frazione la fissa la carovana); modello, pezzi (`_part_rest`), cubetti, anello (`RING_SIZE x scala`), fumo e punto esclamativo in scala attorno a `RIG_GROUND`. Nomi: primo pezzo di un tipo `TurretPart`, poi `TurretPart2`; moduli `TurretModule`, `TurretModule2`. Con un modulo solo niente cambia rispetto al piano A (6 PV, 5 m/s, scala 1, pezzi dove sono oggi).
- `CargoModule.carried` setter: `machine.refresh_cargo_view()` al posto di `set_cargo_view(capacity, carried)`.
- `WelderModule.forget(machine: Machine) -> void` (toglie la chiave da `_broken_elapsed`).
- `Caravan`: `signal machine_removed(machine: Machine)`, `signal fused(machine: Machine)`, `signal detached(machine: Machine)`, `signal combo_formed(combo_id: StringName)`. `func can_fuse(base: Machine, other: Machine) -> bool` (entrambe nella carovana, diverse, non guaste, moduli insieme <= `max_modules_per_machine`, `working_carried() >= fuse_cost`); `func fuse(base: Machine, other: Machine) -> bool` (frazione di vita calcolata prima; `pay(costo)`; ogni modulo di `other` ricreato su `base` con `_attach_module`, i rottami di un Cassone passano col modulo; `remove_machine(other)`; `base.health = carried_health(...)`; `combo_formed` una volta per combinazione nuova; marker `PROTOTYPE01_MACHINE_FUSED modules=%s size=%s cost=%d machines=%d`; `fused` e `changed`); `func can_detach(machine: Machine, module_index: int) -> bool`; `func detach(machine: Machine, module_index: int) -> Machine` (paga, toglie il modulo, conserva la frazione della sorgente, `_add_machine` del modulo al primo posto libero sul suolo coi suoi rottami, marker `PROTOTYPE01_MACHINE_DETACHED module=%s cost=%d machines=%d`; null se non si puo); `func remove_machine(machine: Machine) -> void` (fuori da `machines` e da `write_queue.bodies`; riparazione azzerata se era sua; `forget` su ogni Saldatore; `remove_child` poi `queue_free`, cosi Calamita e Faro si liberano subito in `_exit_tree`; marker `PROTOTYPE01_MACHINE_REMOVED machines=%d`; `machine_removed` e `changed`). `lead()` con la regola della scelta 8. `_attach_module(machine: Machine, module_id: StringName, scrap: int) -> MachineModule` estratto da `_add_machine` (:473-481) e usato da tutti e tre.

- [x] **Step 1: test che falliscono** (`fusion_tests.gd`, sezione carovana):

```gdscript
func _test_fuse_two() -> void:  # lead Cassone (3 rottami) + add_machine(&"turret")
	_check(_caravan.fuse(lead, turret), "fusione riuscita")
	_check(_caravan.machines.size() == 1 and lead.module_ids() == [&"cargo", &"turret"] and _caravan.carried == 2, "una macchina, 1 rottame speso")
	_check(lead.size == MachineFusion.Size.MEDIUM and lead.max_health == 15 and lead.health == 15, "media, 15/15")
	_check(lead.get_node_or_null(^"TurretPart") != null and not is_instance_valid(turret) and not _queue.bodies.has(turret), "pezzo montato, assorbita liberata e fuori dalla coda")
func _test_fuse_rejects() -> void:  # niente cambia: macchine, rottami, moduli
	# guasta (take_hit fino a 0), stessa macchina, rottami 0, 7 moduli in una, macchina estranea: tutte false
func _test_six_into_colossus() -> void:  # Cassone + turret, turret, drill, shovel, siren; carried 5
	for m in others: _check(_caravan.fuse(lead, m), "fusione")
	_check(_caravan.carried == 0 and lead.modules.size() == 6 and lead.size == MachineFusion.Size.COLOSSUS, "colosso per 5 rottami")
	_check(lead.max_health == 63 and is_equal_approx(lead.top_speed(), 3.5) and is_equal_approx(lead.power, 1.75), "63 PV, 3,5 m/s, forza 1,75")
	_check(lead.get_node_or_null(^"TurretPart2") != null and lead.get_node_or_null(^"TurretModule2") != null and lead.slot == 0, "nomi distinti, posto 0")
func _test_detach() -> void:  # [cargo, turret, siren] 23/23, carried 3
	var new := _caravan.detach(m, 2)
	_check(new != null and new.module_ids() == [&"siren"] and new.health == 6 and _queue.bodies.has(new), "Sirena piccola e piena")
	_check(m.max_health == 15 and m.health == 15 and _caravan.carried == 2 and new.slot != m.slot, "sorgente 15/15, 1 rottame, posto diverso")
	_check(_caravan.detach(new, 0) == null, "una piccola non si sgancia")
	# sganciare il Cassone con 2 rottami: la macchina nuova li porta, il totale scende solo del costo
func _test_remove_machine() -> void:  # Review Focus 2 e 3
	# turret guasta in riparazione (interact_held, giocatore accanto) e chiave nel Saldatore: remove_machine(turret)
	_check(_caravan.repairing_machine() == null and _caravan.repair_progress() == 0.0, "riparazione azzerata, niente speso")
	_check(not welder._broken_elapsed.has(turret) and not _queue.bodies.has(turret), "nessun riferimento rimasto")
	# remove_machine(lead) con un secondo Cassone: lead() e il secondo; carovana vuota: lead() null
func _test_lead_rule() -> void:
	# due Cassoni, il primo guasto: lead() e il secondo; entrambi guasti: il primo; nessun Cassone: la prima macchina
func _test_combo_signal() -> void:
	# fuse(drill, magnet): combo_formed una volta con &"extractor"; fondere poi una Torretta non la riemette
func _test_duplicates() -> void:  # Review Focus 2
	# due Calamite fuse: un solo attrattore per la macchina in xp_field.attractors; due Cassoni fusi: capacity 10,
	# cubetti visibili == carried; dopo il turno di 2 s nessun errore nel log
```

- [x] **Step 2:** `fusion_tests.gd` → FAIL (`fuse` non esiste).
- [x] **Step 3:** implementare. Nota del piano A: `add_machine(at)` non aggiunge `GROUND_CLEARANCE`, quindi `detach` posa la macchina nuova al suo posto (`at = null`). Le fusioni girano ad albero fermo: nessuna macchina e a meta passo.
- [x] **Step 4:** `fusion_tests.gd`, poi `caravan_tests.gd`, `machine_damage_tests.gd`, `machine_modules_tests.gd`, `caravan_hud_tests.gd`, `actor_motion_tests.gd` una alla volta verdi; gate completo verde.
- [x] **Step 5: commit** `Carovana (D-093), piano B: macchine a piu moduli (pezzi impilati, vita e velocita per taglia), fuse, detach e remove_machine, capofila col Cassone funzionante; test`.

### Task 3: la taglia si vede e pesa: forza dei moduli, travolgere, striscia

**Files:** Modify `godot/scripts/caravan/machine_module.gd` (:16-22), `modules/turret_module.gd` (:35), `magnet_module.gd` (:12), `beacon_module.gd` (:30), `drill_module.gd` (:25), `shovel_module.gd` (:17), `welder_module.gd` (:27, :38), `siren_module.gd` (:21), `cargo_module.gd` (ricerca), `godot/scripts/caravan/machine.gd` (`_tick_health` :257), `godot/scripts/enemies/enemy_director.gd` (`_apply_machine_contacts` :390-417), `godot/scripts/ui/caravan_strip.gd` (`CaravanSlot` :105-183), `godot/scripts/run/arena_run.gd` (`_refresh_caravan_hud` :1440). Test: `machine_modules_tests.gd`, `machine_damage_tests.gd`, `caravan_hud_tests.gd`.

**Interfaces — Consumes:** task 2 (`Machine.power`, `size`, `contact_reach()`, ricostruzione). **Produces:**
- `MachineModule`: `var power := 1.0`; `func set_power(value: float) -> void` (imposta e richiama `apply_level(level)`); la `Machine` la chiama nella ricostruzione. Letture per i test: `DrillModule.interval() -> float`, `ShovelModule.interval() -> float`, `WelderModule.heal_interval() -> float`, `WelderModule.broken_seconds() -> float`, `SirenModule.range_m() -> float`, `CargoModule.pickup_radius() -> float`; `MagnetModule.radius()` e `BeaconModule.radius()` includono `power`; la Torretta divide l'intervallo per `power` (scelta 4).
- `Machine`: `var trampled := 0` (contatore per test e benchmark); `func can_trample() -> bool` (taglia >= `trample_min_size`, non guasta, velocita planare >= `trample_min_speed`, `_trample_left <= 0`); `func trample_done() -> void` (`_trample_left = trample_interval`, scalato in `_tick_health`).
- `EnemyDirector._apply_machine_contacts`: raggio `machine.contact_reach()`, secchi in `range(-c, c + 1)` con `c = ceili(raggio)`; prima il travolgere (anche se la macchina non accetta contatti: ogni nemico vivo non `self_driven` in raggio prende `trample_damage`, `trampled += 1`, poi `trample_done()`), poi il contatto di oggi solo se `accepts_contact()`.
- `CaravanStrip`: voci con `size: int` e `extra: Array[Color]` (colori dei moduli oltre il primo); `const SIZE_STEP := 14.0`, `const MAX_PIPS := 12`; `func slot_width(index: int) -> float`, `func slot_size(index: int) -> int`, `func slot_uses_bar(index: int) -> bool`. `ArenaRun._refresh_caravan_hud` passa `size` e `extra`.

- [x] **Step 1: test che falliscono.**

```gdscript
# machine_modules_tests._test_power(): una macchina Torretta + Faro (fuse), power 1.15
_check(is_equal_approx(turret.weapon().fire_interval, 0.9 / 1.15), "Torretta: intervallo / forza")
_check(is_equal_approx(beacon.radius(), _run.tuning.beacon_radius * 1.15), "Faro: raggio x forza")
# lo stesso per Calamita 2.5 x p, Trivella 4 / p, Pala 5 / p, Saldatore 3 / p e 6 / p, Sirena 8 x p, Cassone 6 x p
_check(is_equal_approx(lone_turret.weapon().fire_interval, 0.9), "una piccola resta com'era")
# machine_damage_tests._test_trample(): macchina media col passo spento, velocity (2, 0, 0) a mano, rottamatore con 3 PV a 0,7 m
_check(enemy.health == 2 and machine.trampled == 1, "travolto: 1 danno")
# altri due passi del direttore entro 0,5 s: ancora 2; dopo 0,5 s: 1. Piccola in moto, media ferma, media guasta: nessun danno.
# Boss (Demolisher) a 0,7 m da una media in moto: nessun danno da travolgere.
_check(medium_hit_at_0_9 and not small_hit_at_0_9, "raggio di contatto in scala: 0,9 m colpisce la media (1,0 m), non la piccola (0,8 m)")
# caravan_hud_tests._test_size_slots(): dopo fuse di due piccole
_check(strip.slot_count() == 1 and is_equal_approx(strip.slot_width(0), 54.0) and strip.slot_size(0) == 1, "casella media")
# colosso: larghezza 82, slot_uses_bar(0) vero (63 PV), cinque quadratini; una piccola: tacche come prima
```

- [x] **Step 2:** le tre suite → FAIL.
- [x] **Step 3:** implementare; nessuna allocazione nel giro dei secchi.
- [x] **Step 4:** le tre suite verdi, poi `caravan_tests.gd`, `classes_tests.gd` (Motore truccato travolge ancora), `driller_tests.gd`, `boss_tests.gd`; `--check-only` su ogni script toccato.
- [x] **Step 5: commit** `Carovana (D-093), piano B: forza dei moduli per taglia, travolgere da media in su, contatto in scala, taglia nella striscia del HUD; test`.

### Task 4: piazzola di fusione

**Files:** Create `godot/scripts/caravan/fusion_pad.gd`. Modify `godot/scripts/ui/run_hud.gd` (`WarningPriority` :8, colori :9-16), `godot/scripts/run/arena_run.gd` (`_ready` dopo `_build_terrain_layout` :198-199, `_physics_process` :241-245, `call_boss` :364, `current_markers` :321-343, `_update_game_lights` :940-947). Test: `fusion_tests.gd` (sezione piazzola: `TerrainField` creato nel test come `machine_wrecks_tests._make_field`, 120 x 120 m; poi `arena_run.tscn`).

**Interfaces — Consumes:** task 1 (valori `pad_*`). **Produces:**
- `class_name FusionPad extends Node3D`: `signal warned(center: Vector3)`, `signal landed(center: Vector3)`, `signal closed`; `enum Phase { WAITING, SEARCHING, WARNING, OPEN, CLOSED }`; servizi `terrain_field: TerrainField`, `player: PlayerCharacter`, `hud: RunHud`, `caravan: Caravan`, `path_field: PathField`, `lamp_field: LampField`, `tuning: CaravanTuning`, `on_tracks: Callable` (Vector3 -> bool; non valida = nessun binario), `fallback_point: Vector3`, `rng: RandomNumberGenerator`; `var phase`, `var center`. `func schedule(arrive_at: float) -> void`; `func arrive_at() -> float`; `func warning_at() -> float` (= `arrive_at - pad_warning_seconds`, non sotto 0); `func advance(elapsed: float, delta: float) -> void` (da `pad_search_lead_seconds` prima dell'avviso valuta `pad_candidates_per_step` candidati per passo; all'avviso finisce la ricerca se serve, stampa `PROTOTYPE01_FUSION_PAD_WARNING x= z= at=`; durante l'avviso `hud.set_event_warning("PIAZZOLA DI FUSIONE", verso dal giocatore alla pedana, secondi, RunHud.FUSION_COLOR, true, RunHud.WarningPriority.FUSION)`; all'arrivo discesa del modello in 1,5 s, polvere `DebrisBurst`, `set_protected(center, raggio, true)`, avviso "PIAZZOLA DI FUSIONE ATTERRATA" per 3 s, `PROTOTYPE01_FUSION_PAD_LANDED x= z= flat=`); `func is_open() -> bool`; `func half_size() -> float` (3,0); `func flat_radius() -> float` (`half_size() x sqrt(2)`); `func contains(point: Vector3) -> bool` (quadrato, piano XZ); `func candidate_points(origin: Vector3) -> Array[Vector3]` (raggi 25, 22,5, 27,5, 20, 30 m; 24 angoli ogni 15 gradi da uno scarto casuale di `rng`); `func find_landing_now(origin: Vector3) -> Dictionary` (`{point: Vector3, flat: bool}`, ricerca intera in un passo: test e ripiego); `func land_at(point: Vector3) -> void` (test, catture); `func close() -> void` (in ogni fase: niente avviso, protezione tolta, modello che risale e si nasconde, avviso "LA PIAZZOLA SI RICHIUDE", `PROTOTYPE01_FUSION_PAD_CLOSED`, `closed`); `func light() -> OmniLight3D` (null finche non atterra). Modello a primitive sul layer visivo 2: pianale 6 x 0,12 x 6 m con bordo giallo, gru arancione in un angolo (albero 4,5 m, braccio, cavo, gancio), lampada emissiva in cima con `OmniLight3D` "PadLight" e un fascio verticale trasparente non illuminato, visibile da lontano.
- Candidato buono (scelta 1): dentro il campo con `flat_radius() + 2` m di margine, `terrain_field.is_flat(p, flat_radius(), pad_flat_tolerance)`, `absf(terrain_field.delta_at(p)) <= pad_flat_tolerance`, `path_field` pronto: `is_walkable(p)` e `cost_at(p) != PathField.UNREACHABLE`, centro e quattro angoli non su `on_tracks`, nessun lampione entro `flat_radius()`. Ripiego: il raggiungibile col dislivello minore, poi `fallback_point`.
- `RunHud`: `enum WarningPriority { FUSION, EXTRACTION, BOSS, EVENT }` (FUSION la piu bassa); `const FUSION_COLOR := Color(0.45, 0.8, 1.0)`.
- `ArenaRun`: `var fusion_pad: FusionPad`; `func _setup_fusion_pad() -> void` (solo con carovana e rilievo; servizi; `rng.seed = run_seed + 8`; `fallback_point = _start_position`; `on_tracks` = `RailwayDistrict.is_on_tracks` sul piano solo se `train_event != null`; `schedule(boss_call_at x pad_boss_fraction)` se `boss_call_at > 0`, deciso una volta al `_ready`: i test che cambiano `boss_call_at` dopo non spostano la pedana); `fusion_pad.advance(elapsed, delta)` dopo la piazzola di estrazione e prima di `_tick_boss`; `call_boss` chiama `fusion_pad.close()`; `current_markers` aggiunge `{text = "PIAZZOLA", color = MARKER_FUSION_COLOR}` con la pedana aperta oltre `marker_min_distance()`; `_update_game_lights` accende `fusion_pad.light()` col fattore di notte e raggio `pad_light_radius`; `landed` azzera `_night_factor_applied`.

- [x] **Step 1: test che falliscono** (`fusion_tests.gd`, sezione piazzola):

```gdscript
func _test_pad_landing_flat() -> void:  # campo piano, giocatore all'origine, senza PathField
	var r := pad.find_landing_now(Vector3.ZERO)
	var d := Vector2(r.point.x, r.point.z).length()
	_check(r.flat and d >= 20.0 and d <= 30.0, "piano, a 20-30 m")
func _test_pad_avoids_pit() -> void:  # Review Focus 1
	# sculpt(-1.0, raggio 3) sul primo candidato e un cumulo (+1.0) sul secondo: il punto scelto e un altro,
	# is_flat(scelto, flat_radius(), 0.35) vero e |delta_at| <= 0.35; una buca larga 12 m a fondo piatto non va (delta)
func _test_pad_fallback() -> void:
	# anello 15-35 m tutto a cumuli: flat falso, punto = candidato col dislivello minore; con on_tracks sempre vero: fallback_point
func _test_pad_contains() -> void:
	_check(pad.contains(c + Vector3(2.9, 0, 2.9)) and not pad.contains(c + Vector3(3.1, 0, 0)), "quadrato di 6 m")
func _test_pad_in_run() -> void:  # arena_run.tscn
	_check(is_equal_approx(_run.fusion_pad.arrive_at(), _run.boss_call_at * 0.5) and is_equal_approx(_run.fusion_pad.warning_at(), _run.boss_call_at * 0.5 - 15.0), "a meta della chiamata, 15 s di preavviso")
	_run.fusion_pad.schedule(_run.elapsed + 16.0)
	# dopo 1,2 s: event_warning_text() inizia per "PIAZZOLA DI FUSIONE", is_boss_warning_visible() vero, conto 15
	# hud.set_event_warning("TRENO", ..., EVENT) nello stesso passo vince sulla pedana
	# dopo l'arrivo: is_open(), terrain_field.is_protected(center), light() != null; il giocatore a 25 m vede il marker "PIAZZOLA"
	# un player_sculpt sul centro non cambia la quota; call_boss(): is_open() falso, nessun avviso, centro non protetto
	# pedana programmata e boss chiamato prima dell'avviso: nessun atterraggio, nessun marker WARNING
```

- [x] **Step 2:** `fusion_tests.gd` → FAIL.
- [x] **Step 3:** implementare; cache delle classi.
- [x] **Step 4:** `fusion_tests.gd`, poi `arena_run_tests.gd`, `boss_tests.gd`, `train_tests.gd`, `quake_tests.gd`, `world_event_tests.gd`, `day_night_tests.gd`, `railway_tests.gd` una alla volta; gate completo verde.
- [x] **Step 5: commit** `Carovana (D-093), piano B: piazzola di fusione (arrivo a meta della chiamata del boss, avviso con freccia, atterraggio su un tratto piano raggiungibile, gru e faro, chiusura alla chiamata); test`.

### Task 5: banco di fusione in pausa

**Files:** Create `godot/scripts/ui/fusion_bench.gd`. Modify `godot/scripts/caravan/fusion_pad.gd` (richiesta del banco), `godot/scripts/run/arena_run.gd` (`_ready` :206, `_open_next_level_up` :1035-1050, `_end_level` :577, `_tick_caravan_hud` :1453), `godot/scripts/ui/run_hud.gd` (`set_caravan_prompt` :266), `godot/scripts/ui/caravan_strip.gd` (tasto "Banco" :44-48, :74-78), `docs/PLATFORM_AND_INPUT.md` (Interagisci apre il banco sulla pedana). Test: `fusion_tests.gd` (sezione banco, `arena_run.tscn`, eventi di input veri come `settings_tests._send_joypad_button`), `caravan_hud_tests.gd`.

**Interfaces — Consumes:** task 2 (`can_fuse`, `fuse`, `can_detach`, `detach`), task 1 (`preview_fuse`, `preview_detach`), task 4 (`FusionPad`). **Produces:**
- `FusionPad`: `func bench_available() -> bool` (aperta, giocatore vivo dentro `contains`, `caravan.repair_target() == null`); `func request_bench() -> void` (collegata a `player.interact_pressed`; segna la richiesta solo se `bench_available()`); `func take_bench_request() -> bool`; `func drop_bench_request() -> void`; `close()` scarta la richiesta.
- `class_name FusionBench extends CanvasLayer` (layer 92, `PROCESS_MODE_ALWAYS`): `signal opened`, `signal closed`; `enum Mode { FUSE, DETACH }`, `enum Step { PICK_FIRST, PICK_SECOND }`; `const INPUT_GRACE_SECONDS := 0.4`; `var is_open`, `var caravan: Caravan`, `var combo_known: Callable` (StringName -> bool; di serie sempre falso), `var mode`, `var step`. `func open(target: Caravan) -> void` (ferma l'albero, scheda Fondi, focus sulla prima carta sceglibile dopo la grazia, `PROTOTYPE01_FUSION_BENCH_OPENED machines=%d`); `func close() -> void` (toglie la pausa, `PROTOTYPE01_FUSION_BENCH_CLOSED`); `func set_mode(next: Mode) -> void`; `func select(index: int) -> void` (come premere la carta); `func back() -> void` (dal secondo passo al primo; dal primo chiude); `func fuse(base_index: int, other_index: int) -> bool` e `func detach(machine_index: int, module_index: int) -> bool` (stessa via della conferma; bot e test); letture `card_count()`, `card(index) -> Button`, `card_text(index) -> String`, `preview_text() -> String`, `message_text() -> String`, `title_text() -> String`.
- Contenuto: titolo "BANCO DI FUSIONE"; rottami "Nei Cassoni: N" (`working_carried()`); due schede a interruttore "Fondi" e "Sgancia" (LB/RB e PagSu/PagGiu come l'Officina, clic col mouse); una carta per macchina ("<Taglia> - Cassone + Torretta", "PV a/b"; guaste disattivate con "GUASTA"; in Sgancia disattivate quelle da un modulo); secondo passo: in Fondi le altre macchine (oltre il massimo disattivate), in Sgancia i moduli della scelta. L'anteprima segue il focus: "Diventa: Media (2 moduli)", "PV 11/15  Velocita 4,5 m/s", "Combinazioni: Estrattore (nuova)" o "???" se `combo_known` e falso, "Costo: 1 rottame (nei Cassoni: 3)". A conferma; rottami insufficienti: niente cambia e messaggio "Rottami insufficienti nei Cassoni". Dopo una conferma il banco resta aperto al primo passo, con le carte rifatte. B indietro. Riga `ButtonPrompts` con `ui_accept` "Scegli" e `ui_cancel` "Indietro".
- `ArenaRun`: `var fusion_bench: FusionBench` (creato nel `_ready`, `closed` -> `_open_next_level_up.call_deferred()`); `_open_next_level_up`: esce anche col banco aperto; cassa o relitto aperti, o level-up aperto: `fusion_pad.drop_bench_request()`; nessun menu e `take_bench_request()`: `fusion_bench.open(caravan)`; `_end_level` chiude il banco se aperto. `RunHud.set_caravan_prompt(repair: bool, bench := false)`; `CaravanStrip`: secondo tasto `interact` "Banco" nello stesso posto (uno acceso alla volta, "Ripara" prima), `func bench_prompt_visible() -> bool`.

- [x] **Step 1: test che falliscono** (`fusion_tests.gd`, sezione banco; carovana Cassone + Torretta + Trivella, pedana posata sotto il giocatore con `land_at`):

```gdscript
func _test_bench_opens_paused() -> void:  # X vero (JOY_BUTTON_X), due passi
	_check(_run.fusion_bench.is_open and paused and _run.fusion_bench.title_text() == "BANCO DI FUSIONE", "X sulla pedana apre il banco in pausa")
	# 30 frame: _run.elapsed e player.health invariati con un rottamatore addosso (Review Focus 4)
func _test_bench_controller_fuse() -> void:  # attesa 0,45 s (grazia), poi solo eventi del controller
	# A sceglie la prima carta (capofila); croce a destra: focus sulla Torretta
	_check("Media" in bench.preview_text() and "PV 15/15" in bench.preview_text() and "1 rottame" in bench.preview_text(), "anteprima della fusione")
	# A conferma: machines 2 (Torretta assorbita), carried -1; B, B: banco chiuso, paused falso, una sola ripresa
func _test_bench_keyboard_detach() -> void:  # Invio, frecce, PagGiu, Esc
	# PagGiu: Sgancia; Invio sul capofila fuso; frecce sul modulo Torretta; anteprima "Piccola" e "1 rottame"; Invio: macchina nuova; Esc chiude
func _test_bench_unknown_combo() -> void:  # Trivella + Calamita
	_check("???" in bench.preview_text() and not "Estrattore" in bench.preview_text(), "combinazione mai vista: ???")
	# combo_known = func(_id): return true -> "Estrattore"
func _test_bench_broken_and_short() -> void:  # Review Focus 3
	# carta della macchina guasta disattivata e bench.fuse(0, guasta) falso; con 0 rottami la conferma non cambia nulla
	# e message_text() == "Rottami insufficienti nei Cassoni"
func _test_bench_repair_wins() -> void:  # guasta a 1 m sulla pedana, X tenuto
	_check(not bench.is_open and _caravan.repair_progress() > 0.0 and not hud.caravan_strip().bench_prompt_visible(), "ripara, non apre")
func _test_bench_menu_queue() -> void:  # Review Focus 4
	# _pending_level_ups = 1 e X nello stesso passo: si apre il level-up, non il banco; scelta la carta: banco chiuso
	# richiesta e call_boss() nello stesso passo: pedana chiusa, nessun banco
	# a banco aperto START (pausa): pause_menu.is_open() falso, banco ancora aperto
	# chiuso con B tenendo X: dopo 10 passi il banco resta chiuso (serve una pressione nuova)
func _test_bench_prompt() -> void:  # caravan_hud_tests
	# sulla pedana senza guaste: bench_prompt_visible() vero e prompt_visible() falso; a 10 m: entrambi falsi
```

- [x] **Step 2:** `fusion_tests.gd` → FAIL.
- [x] **Step 3:** implementare; cache delle classi.
- [x] **Step 4:** `fusion_tests.gd`, `caravan_hud_tests.gd`, `input_events_tests.gd`, `button_prompts_tests.gd`, `arena_run_tests.gd`, `machine_wrecks_tests.gd` una alla volta; gate completo verde.
- [x] **Step 5: commit** `Carovana (D-093), piano B: banco di fusione in pausa (fondere e sganciare coi rottami dei Cassoni, anteprima di taglia, vita, velocita e combinazioni, ??? per le nuove), a controller e tastiera; tasto Banco nel HUD; test`.

### Task 6: le sei combinazioni

**Files:** Modify `godot/scripts/combat/auto_weapon.gd` (colpo :238), `godot/scripts/caravan/modules/turret_module.gd`, `drill_module.gd`, `shovel_module.gd` (:34), `godot/scripts/caravan/machine.gd` (`take_hit` :207-218). Test: `machine_modules_tests.gd` (un controllo per combinazione, come chiede la Verifica della spec).

**Interfaces — Consumes:** task 2 (`Machine.has_combo`, `combos()`), task 3 (`BeaconModule.radius()`, `SirenModule.range_m()`, `is_attracting()`). **Produces:**
- `AutoWeapon`: `var damage_scale: Callable` (Enemy -> float; non valida = 1); al colpo `enemy.take_damage(_damage_for(enemy))` con `func _damage_for(enemy: Enemy) -> int` = `damage` se non valida, altrimenti `maxi(roundi(damage x scala), 1)`. Le armi del giocatore non la impostano: nessun cambio per loro.
- `TurretModule`: `apply_level` imposta `_weapon.damage_scale = _combo_scale`; `func _combo_scale(enemy: Enemy) -> float`: x `combo_damage_scale` con Riflettore e il nemico entro il raggio del Faro attivo della stessa macchina; x `combo_damage_scale` con Trappola, Sirena che attira e nemico entro `range_m()`.
- `Machine.take_hit`: `func hit_scale() -> float` (`combo_hit_scale` con Esca blindata e Sirena che attira, altrimenti 1); PV tolti = parte intera di `amount x scala + _damage_carry`, resto in `_damage_carry`; immunita e marker come oggi; `damaged` solo con PV tolti > 0. A scala 1 identico al piano A.
- `ShovelModule`: con Betoniera mobile costo 0 e nessuna riserva.
- `DrillModule`: Estrattore: dopo una buca `scrap_field.take_near(punto, extractor_radius, caravan.room())` e `caravan.add_scrap(n)`; dopo una vena lo stesso sul punto di caduta; marker `PROTOTYPE01_EXTRACTOR scrap=%d`. Ruspa (`_tick_dozer(delta)`): scia delle posizioni; ogni `dozer_spacing` m percorsi, sul punto della scia lontano dalla macchina almeno `keep_clear + dozer_ditch_radius`, fossato `DigCharge.dig_crater(write_queue, terrain_field, p, dozer_ditch_radius, dozer_ditch_depth)` se il suolo e entro `drill_flat_tolerance` dalla base e `clear_spot(p, dozer_ditch_radius)`; argine a `p + lato destro x dozer_bank_offset` con `push_level` a base + `dozer_bank_height` se `clear_spot`, piu basso e senza `highest_bump`; gratis; marker `PROTOTYPE01_DOZER_TRENCH x= z=`.

- [x] **Step 1: test che falliscono** (`machine_modules_tests.gd`, run vera; macchine fuse con `caravan.fuse`):

```gdscript
# _test_combo_reflector: Torretta + Faro, rottamatore entro il raggio del Faro: un chiodo toglie il doppio di quello di una Torretta sola (2 x weapon_damage)
# _test_combo_trap: Torretta + Sirena nella fase attiva, rottamatore attirato a 6 m: doppio danno; fuori fase: danno normale
# _test_combo_both: Torretta + Faro + Sirena, attirato e illuminato: 4 x weapon_damage
# _test_combo_armored_bait: Saldatore + Sirena attiva, due take_hit(1) a 0,9 s: vita -1; Sirena ferma: -2
# _test_combo_mobile_mixer: Pala + Cassone con 0 rottami e un rottamatore a 5 m: SHOVEL_BANK stampato, carried invariato
# _test_combo_extractor: Trivella + Calamita, tre rottami a terra entro 3 m dalla buca: dopo la buca carried +3 (se c'e posto)
# _test_combo_dozer: Trivella + Pala, macchina che percorre 6 m in piano: almeno 2 DOZER_TRENCH, nessuna scrittura entro
#   keep_clear da giocatore e macchine, nessuna sulla pedana protetta
# _test_combo_off_when_broken: macchina guasta: has_combo falso per tutte, la Torretta spenta non spara
```

- [x] **Step 2:** `machine_modules_tests.gd` → FAIL.
- [x] **Step 3:** implementare.
- [x] **Step 4:** `machine_modules_tests.gd`, `machine_damage_tests.gd`, `loadout_tests.gd`, `combat_services_tests.gd` (chiodatrice del giocatore invariata), `fusion_tests.gd` una alla volta; gate completo verde.
- [x] **Step 5: commit** `Carovana (D-093), piano B: le sei combinazioni (Estrattore, Riflettore, Betoniera mobile, Esca blindata, Ruspa, Trappola); test`.

### Task 7: profilo v3, ricettario delle combinazioni, scoperta in partita

**Files:** Modify `godot/scripts/services/player_profile.gd` (`VERSION` :15, `reset` :64, `load_profile` :169-224, `save_profile` :227-256), `godot/scripts/run/arena_run.gd` (`_setup_loadout` :1373-1374), `godot/scripts/ui/workshop_panel.gd` (Ricettario :98-100, `show_tab` :324, `_refresh` :432-438, dettaglio :281). Test: `fusion_tests.gd` (sezione profilo), `profile_v2_tests.gd` (:80 legge 2 a mano: diventa `PlayerProfileService.VERSION`), `workshop_tests.gd`.

**Interfaces — Consumes:** task 1 (`MachineCatalog.combos()`), task 2 (`Caravan.combo_formed`), task 5 (`FusionBench.combo_known`). **Produces:**
- `PlayerProfileService`: `const VERSION := 3`; `var machine_combos: PackedStringArray`; `func discover_combo(id: StringName) -> bool` (vero la prima volta, salva, `changed`, `PROTOTYPE01_COMBO_DISCOVERED id=%s`); `func has_combo(id: StringName) -> bool`; `var _unknown_machine_keys: Dictionary[String, Variant]`. Lettura: `[machines] combinations` (`PackedStringArray` o `Array` di `String`; altro = vuoto, senza errori; id sconosciuti conservati); le altre chiavi di `[machines]` in `_unknown_machine_keys`; `machines` fuori dal giro delle sezioni sconosciute. Scrittura: `combinations` sempre, poi le chiavi sconosciute; versione `maxi(VERSION, loaded_version)`.
- `ArenaRun`: `caravan.combo_formed` -> `profile.discover_combo`; `fusion_bench.combo_known = profile.has_combo` (senza profilo resta il default).
- `WorkshopPanel`: nella scheda Ricettario, sotto la griglia delle fusioni, un `VBoxContainer` "Combos" con l'etichetta "Combinazioni delle macchine" e la griglia `Grid_combos` (non in `_tab_grids`; visibile solo sul Ricettario); carte `Combo_<id>` con testo "???\nTrivella + ?" se ignota e "Estrattore\nTrivella + Calamita" se nota, icona del primo modulo o `lock`; dettaglio come `_show_recipe_detail` ("Si scopre la prima volta che fondi queste due macchine in partita."); `func combo_text(id: StringName) -> String`; altezza minima del corpo ricalcolata con le carte delle combinazioni.

- [x] **Step 1: test che falliscono.**

```gdscript
# fusion_tests._test_profile_v2_loads(): file v2 scritto a mano (scrap 9, recipes mortar, upgrades tool_reach 1,
#   last_class sapper, sezione mystery)
_check(p.scrap == 9 and p.has_recipe(&"mortar") and p.level_of(&"tool_reach") == 1 and p.last_class == &"sapper", "v2 intatto")
_check(p.machine_combos.is_empty() and p.save_profile() == OK, "nessuna combinazione, si salva")
_check(reread.get_value("profile", "version", 0) == 3 and reread.get_value("mystery", "answer", 0) == 42 and reread.has_section("machines"), "salvato v3, sezione sconosciuta intatta")
# _test_profile_v3_round_trip(): discover_combo(&"extractor") vero, poi falso; ricaricato has_combo vero;
#   reread [machines] combinations == PackedStringArray(["extractor"])
# _test_profile_future_machines(): versione 5, combinations ["trap", "laser"], unlocked_modules ["drill"]:
#   has_combo(trap) e has_combo(laser) veri; risalvato: versione 5, unlocked_modules e "laser" ancora li
# _test_profile_junk_machines(): combinations = 42 -> vuoto, nessuna riga "ERROR:"
# _test_discovery_from_fusion(): run vera, fuse Trivella + Calamita dal banco: profilo.has_combo(&"extractor");
#   riaperto il banco, l'anteprima di un'altra Trivella + Calamita dice "Estrattore"
# workshop_tests._test_combinations_book(): Ricettario: sei Combo_<id>; combo_text(&"extractor") == "???\nTrivella + ?";
#   dopo discover_combo: "Estrattore\nTrivella + Calamita"; croce in giu dall'ultima fusione porta il focus su Combo_extractor
```

- [x] **Step 2:** le suite → FAIL.
- [x] **Step 3:** implementare.
- [x] **Step 4:** `fusion_tests.gd`, `profile_v2_tests.gd`, `workshop_tests.gd`, `settings_tests.gd` (non tocca il profilo, controllo di non regressione) una alla volta; gate completo verde.
- [x] **Step 5: commit** `Carovana (D-093), piano B: profilo versione 3 (sezione machines, un v2 si carica intatto), combinazioni scoperte in partita, sezione Combinazioni nel Ricettario dell'Officina; test`.

### Task 8: bot, benchmark col colosso, catture, gate, documenti

**Files:** `godot/tests/tools/simulate_runs.gd` (giro :320-323, `_tick_bot` :375-399, riga `PROTOTYPE01_SIM` :348), `godot/tests/tools/benchmark_arena.gd` (`_bench_caravan` :205-362), `godot/tests/tools/capture_caravan.gd`; documenti `docs/MIGRATION_STATUS.md` (sotto 8192 byte: oggi 7959, sfoltire), `docs/PROJECT_ROADMAP.md` (Stato operativo), `docs/DECISIONS.md` (D-093: piano B fatto, le 12 scelte, le domande), `docs/INDEX.md` (questo piano se manca), `docs/GODOT_WORKFLOW.md` (sezione Carovana: comandi, marker e trappole del piano B), `docs/TOOLS_AND_LICENSES.md` (Kenney proposto, nessun addon per il banco), stato della spec.

**Interfaces — Consumes:** tutti i task precedenti.

- [x] **Bot.** `--caravan=<moduli>` (solo `simulate_runs`: macchine in piu alla partenza, per provare la regola). `_tick_fusion() -> bool` (prima della riparazione nel ritmo di `_tick_bot`): pedana aperta, `module_count() >= module_limit`, piu di una macchina, nessuna guasta, `working_carried()` >= costo di fondere tutto nel capofila, nemico piu vicino oltre `BRUSH_SAFE_M`: va al centro della pedana e, dentro, emette `_player.interact_pressed`. Nel giro, con `_run.fusion_bench.is_open`: `_drive_bench()` fonde una macchina per passo nel capofila con `fusion_bench.fuse(...)`, poi `close()`. Campi nuovi `fusions=` e `colossus=` (0/1) nella riga `PROTOTYPE01_SIM`. Prova: `simulate_runs.gd -- --bots=novice,scrapper --seeds=1-3 --max-seconds=600` senza errori e `--bots=novice --seeds=1 --max-seconds=420 --caravan=turret,turret,drill,shovel,siren` con `colossus=1`; numeri riportati.
- [x] **Benchmark.** Dopo la riga `caravan` di giorno, coi 20 robusti ancora sul grappolo: le sei macchine fuse nel capofila con `caravan.fuse` (rottami aggiunti prima), 60 passi di assestamento, stessa finestra della riga `caravan` (anello dei robusti a 7-9 m, coda vuota, timer dei moduli a zero), riga `PROTOTYPE01_ARENA_BENCH caravan_colossus preset=%s machines=%d modules=%d size=%d enemies=%d step_ms=%.3f max_ms=%.3f trampled=%d`; pulizia: moduli spenti tranne il Cassone del capofila. `benchmark_arena.gd -- --enemies=70 --preset=deck`: `step_ms` <= 0,5 per entrambe le righe; se si sfora, prima gli effetti, poi la frequenza dei moduli. Di notte nessuna riga del colosso (detto nel commit).
- [x] **Catture** (`capture_caravan.gd -- --out=../output/caravan --quake-at=0`, dopo quelle del piano A): `fusion_pad` (pedana atterrata col giocatore sopra e il grappolo, camera di gioco), `fusion_pad_night` (di notte da circa 25 m: faro e fascio visibili), `fusion_bench` (banco aperto, anteprima Trivella + Calamita con "???"), `fused_machine` (macchina grande coi pezzi impilati e la casella larga nel HUD); righe `PROTOTYPE01_CAPTURE_CARAVAN shot=<nome> err=<n> ...`; lette una per una.
- [x] **Gate** completo verde (59 suite); build Windows esportata e avviata col `--autostart` senza errori nel log; `--boss-at=60` (guidato da script, vedi Stato dell'esecuzione): pedana a 30 s, banco, chiusura alla chiamata.
- [x] **Documenti** come da elenco Files; nella sezione Carovana di `GODOT_WORKFLOW.md` i comandi verificati, i marker del piano B e le trappole trovate (fra cui: la pedana e decisa al `_ready`, i test che spostano `boss_call_at` non la spostano).
- [x] **Commit** `Carovana (D-093), piano B chiuso: bot che fondono il colosso, riga caravan_colossus del benchmark, catture della piazzola e del banco; documenti`.

---

## Esecuzione

In sequenza, un esecutore nuovo per task e una revisione prima del successivo: i task condividono `caravan.gd`, `machine.gd` e `arena_run.gd`, e le suite Godot non girano in parallelo. Gate completo dopo i task 2, 4, 5, 6, 7 e 8; negli altri le suite elencate. Nessuna scena toccata: col proprietario nell'editor basta dirgli quali script cambiano. Il risultato di Codex o di un subagente resta non verificato finche il controllore non rilegge diff, suite e gate.

Stato dell'esecuzione (19 ottobre 2026): task 1-8 chiusi, ognuno con revisione (task 4 e 6 con un giro di correzioni e una seconda revisione) e gate verde dopo i task 2, 4, 5, 6, 7 e 8. Le osservazioni minori rimandate e le scelte dell'esecuzione stanno nel registro locale `.superpowers/sdd/2026-10-18-caravan-fusion/progress.md` (ignorato da Git; righe `Minor (deferred)` e `Ruling:`); le scelte (le 7 domande eseguite coi default, `remove_machine` con `queue_free`, forza del Cassone sul solo raggio di ricerca, argine della Ruspa con le condizioni della Pala, `combinations` riscritto vuoto se non e una lista, protezione della pedana fotografata e rimessa) e il debito, una frase per task, sono in D-093. Limite della verifica del task 8: con la regola del piano i bot non fondono nelle run di prova (la carovana non si riempie mai nelle run da 600 s; col comando del colosso il novice muore prima della pedana; a carovana piena bloccano i rottami); il controllo `--boss-at=60` e stato guidato da uno script con input veri e giocatore teletrasportato, non a mano, e nell'exe si e visto solo l'avviso (il primo level-up ferma la partita senza nessuno ai comandi); la regola e provata con lo scrapper, la Calamita, la pedana a 150 s e l'Officina `cargo:3,stock:2` (Colosso in 2 semi su 3).

## Autoverifica (18 ottobre 2026)

1. **Copertura della spec.** Sezione 2: arrivo, avviso, pedana 4x4 con gru e faro, durata e chiusura (task 4); banco in pausa, fondere, sganciare, anteprima, "???" (task 5), costi (task 1, 2, 5), macchine piccole dopo l'arrivo e ritorni illimitati alla pedana (task 5: il banco si riapre a ogni pressione). Sezione 1: taglie, forza, vita, velocita, travolgere (task 1, 2, 3), combinazioni (task 1, 6). Sezione 5: Ricettario Combinazioni e profilo v3 (task 7). Sezione 6: striscia con la taglia (task 3), prestazioni col colosso (task 8), bot (task 8). Verifica: `fusion_tests` (task 1, 2, 4, 5, 7), controllo per combinazione in `machine_modules_tests` (task 6), benchmark col colosso, regola dei bot, catture, controller (task 5, 8). Fuori: tutto il piano C, elencato sopra.
2. **Passi.** Ogni passo di test ha nomi e asserzioni coi valori della spec (6/15/23/36/45/63 PV, 5/4,5/4/3,5 m/s, forza 1,15-1,75, costi 1 e 5, 20-30 m, 15 s); ogni passo di codice ha firme e file; nessun "da definire".
3. **Tipi.** `MachineFusion.Size` (int) in `Machine.size`, `CaravanStrip.slot_size`; `Caravan.fuse(base, other) -> bool`, `detach(machine, module_index) -> Machine`, `remove_machine(machine)` usati cosi nei task 5 e 8; `FusionBench.fuse(base_index, other_index)` e `detach(machine_index, module_index)` coerenti col bot; `combo_known: Callable` del task 5 riempita nel task 7 con `PlayerProfileService.has_combo`; `combo_formed(combo_id)` del task 2 collegato a `discover_combo` nel task 7; `set_caravan_prompt(repair, bench)` del task 5 chiamato da `_tick_caravan_hud`; `WarningPriority.FUSION` del task 4 usato solo da `FusionPad`.
4. **Review Focus.** I cinque casi hanno un test nel task che possiede il codice (4, 2, 2 e 5, 5, 7). Controllati e coperti altrove: moduli doppi (task 2), boss non travolti (task 3), combinazioni spente da guasta (task 6), avviso del treno sopra quello della pedana (task 4).
5. **Proporzione.** Spec circa 19 KB, piano circa 59 KB (il piano A, esecuzione compresa, 78 KB): niente corpi di funzione, il codice e fatto di firme e asserzioni; la lunghezza viene dalle interfacce fra otto task che condividono tre file.
