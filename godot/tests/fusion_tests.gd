extends SceneTree
## Fusione delle macchine (D-093, piano B): taglie, vita, velocita, forza, costi, anteprime di
## fusione e sgancio, sei combinazioni e valori di partenza in CaravanTuning; poi, sulla carovana
## della scena `ruins_arena` (task 2), macchine a piu moduli, `fuse`, `detach` e `remove_machine`
## e la regola del capofila. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/fusion_tests.gd

const TUNING_PATH := "res://resources/tuning/caravan_default.tres"
const ArenaScene := preload("res://scenes/main/ruins_arena.tscn")
## Posizione del pezzo della Torretta sulla macchina (TurretModule.build_part).
const TURRET_PART_POSITION := Vector3(0.0, 0.42, -0.25)

var _failures := 0
var t: CaravanTuning
var _scene: Node3D
var _player: PlayerCharacter
var _field: TerrainField
var _caravan: Caravan
var _queue: TerrainWriteQueue
var _xp: XpField
## Combinazioni ricevute da `combo_formed` e macchine da `machine_removed`.
var _combos_formed: Array[StringName] = []
var _removed: Array[Machine] = []


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	if not OS.get_environment("PROTOTYPE01_SEED").is_valid_int():
		OS.set_environment("PROTOTYPE01_SEED", "20261014")
	t = load(TUNING_PATH) as CaravanTuning
	_check(t != null, "caravan_default.tres si carica come CaravanTuning")
	if t != null:
		_test_sizes()
		_test_costs()
		_test_combos()
		_test_preview()
		_test_tuning()
		await _test_caravan()
	await _frames(2)
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _test_sizes() -> void:
	print("sizes")
	var sizes := [0, 1, 1, 2, 2, 3]; var health := [6, 15, 23, 36, 45, 63]
	var speed := [5.0, 4.5, 4.5, 4.0, 4.0, 3.5]; var power := [1.0, 1.15, 1.30, 1.45, 1.60, 1.75]
	for n in range(1, 7):
		_check(MachineFusion.size_of(n, t) == sizes[n - 1], "taglia di %d moduli" % n)
		_check(MachineFusion.max_health_of(n, t) == health[n - 1], "vita di %d moduli" % n)
		_check(is_equal_approx(t.max_speed * MachineFusion.speed_factor_of(n, t), speed[n - 1]), "velocita di %d" % n)
		_check(is_equal_approx(MachineFusion.power_of(n, t), power[n - 1]), "forza di %d" % n)
	_check(MachineFusion.SIZE_NAMES[3] == "Colosso", "nomi delle taglie")
	var scales := [1.0, 1.25, 1.25, 1.5, 1.5, 1.8]
	for n in range(1, 7):
		_check(is_equal_approx(MachineFusion.model_scale_of(n, t), scales[n - 1]), "scala del modello di %d moduli" % n)


func _test_costs() -> void:
	print("costs")
	_check(MachineFusion.fuse_cost(1, t) == 1 and MachineFusion.fuse_cost(3, t) == 3 and MachineFusion.detach_cost(t) == 1, "costi")
	var total := 0
	for i in 5: total += MachineFusion.fuse_cost(1, t)
	_check(total == 5, "sei piccole in un colosso: 5 rottami")


func _test_combos() -> void:
	print("combos")
	_check(MachineCatalog.COMBOS.size() == 6 and MachineCatalog.find_combo(&"dozer").name == "Ruspa", "sei combinazioni coi nomi della spec")
	_check(MachineCatalog.find_combo(&"extractor").parts == [&"drill", &"magnet"], "parti dell'Estrattore")
	_check(MachineCatalog.combos_of([&"magnet", &"drill"]) == [&"extractor"], "l'ordine dei moduli non conta")
	_check(MachineCatalog.combos_of([&"turret", &"beacon", &"siren"]) == [&"reflector", &"trap"], "due combinazioni in una macchina")
	_check(MachineCatalog.combos_of([&"drill", &"shovel", &"cargo"]) == [&"mobile_mixer", &"dozer"], "Betoniera e Ruspa")
	_check(MachineCatalog.combos_of([&"turret", &"turret"]).is_empty() and MachineCatalog.find_combo(&"nope").is_empty(), "nessuna")
	var ids: Array[StringName] = []
	for combo in MachineCatalog.combos():
		ids.append(combo.id)
	_check(ids == MachineCatalog.COMBOS and is_same(MachineCatalog.combos(), MachineCatalog.combos()), "voci nell'ordine di COMBOS, costruite una volta")
	_check(MachineCatalog.find_combo(&"trap").text == "Chi e attirato prende doppio danno dalla Torretta.", "testo della Trappola")
	_check(MachineCatalog.combos_of([&"drill", &"magnet", &"magnet"]) == [&"extractor"], "un modulo doppio non ripete la combinazione")


func _test_preview() -> void:
	print("preview")
	var p := MachineFusion.preview_fuse([&"drill"], 6, 6, [&"magnet"], 3, 6, t)
	_check(p.size == 1 and p.max_health == 15 and p.health == 11 and is_equal_approx(p.speed, 4.5), "anteprima: media, 11/15, 4,5 m/s")
	_check(p.combos == [&"extractor"] and p.new_combos == [&"extractor"] and p.cost == 1 and p.allowed, "anteprima: combinazione nuova, costo 1")
	var d := MachineFusion.preview_detach([&"turret", &"beacon", &"siren"], 2, 23, 23, t)
	_check(d.source.max_health == 15 and d.source.health == 15 and d.detached.max_health == 6, "sgancio: 15/15 e 6/6")
	_check(d.lost_combos == [&"trap"] and d.source.combos == [&"reflector"] and d.cost == 1, "sgancio: Trappola persa")
	_check(not MachineFusion.preview_detach([&"cargo"], 0, 6, 6, t).allowed, "una piccola non si sgancia")
	_check(not MachineFusion.preview_fuse([&"cargo", &"turret", &"magnet"], 23, 23, [&"drill", &"shovel", &"siren", &"welder"], 36, 36, t).allowed, "oltre 6 moduli no")
	var q := MachineFusion.preview_fuse([&"drill", &"magnet"], 15, 15, [&"shovel"], 6, 6, t)
	_check(q.new_combos == [&"dozer"] and q.combos == [&"extractor", &"dozer"] and q.modules == [&"drill", &"magnet", &"shovel"], "anteprima: solo la Ruspa e nuova, la seconda entra nella prima")


func _test_tuning() -> void:
	print("tuning")
	_check(t.size_min_modules == PackedInt32Array([1, 2, 4, 6]) and is_equal_approx(t.power_per_extra_module, 0.15), "taglie e forza")
	_check(is_equal_approx(t.pad_boss_fraction, 0.5) and t.pad_warning_seconds == 15.0 and t.pad_distance_min == 20.0 and t.pad_distance_max == 30.0 and t.pad_cells == 4, "piazzola")
	_check(t.fuse_cost_per_module == 1 and t.detach_cost_per_module == 1 and t.max_modules_per_machine == 6, "costi e massimo per macchina")


# --- Sezione carovana (task 2) ---------------------------------------------------------------

## La scena con la sua carovana, una coda di scrittura e un campo dei frammenti creati qui e
## passati a `configure`.
func _test_caravan() -> void:
	print("caravan")
	_scene = ArenaScene.instantiate()
	_scene.name = "Scene"
	root.add_child(_scene)
	_player = _scene.get_node(^"Player")
	_field = _scene.get_node(^"TerrainField")
	_caravan = _scene.get_node(^"Caravan")
	_queue = TerrainWriteQueue.new()
	_queue.name = "TerrainWriteQueue"
	_queue.terrain_field = _field
	_scene.add_child(_queue)
	_xp = XpField.new()
	_xp.name = "XpField"
	_xp.player = _player
	_scene.add_child(_xp)
	_caravan.configure({terrain_field = _field, write_queue = _queue, xp_field = _xp})
	_caravan.combo_formed.connect(func(id: StringName) -> void: _combos_formed.append(id))
	_caravan.machine_removed.connect(func(machine: Machine) -> void: _removed.append(machine))
	await _frames(2)
	_check(_queue.bodies.has(_caravan.lead()), "il capofila sta nella coda di scrittura")
	await _test_fuse_two()
	await _test_fuse_rejects()
	await _test_six_into_colossus()
	await _test_detach()
	await _test_remove_machine()
	await _test_lead_rule()
	await _test_combo_signal()
	await _test_duplicates()
	root.remove_child(_scene)
	_scene.queue_free()


## Carovana con il solo Cassone (3 rottami): le macchine di prima escono con `remove_machine`.
func _reset() -> Machine:
	for machine in _caravan.machines.duplicate():
		_caravan.remove_machine(machine)
	await _frames(1)
	var lead := _caravan.add_machine(&"cargo")
	_caravan.carried = 3
	_combos_formed.clear()
	_removed.clear()
	return lead


func _add(module_id: StringName) -> Machine:
	var machine := _caravan.add_machine(module_id)
	_check(machine != null and machine.has_module(module_id), "add_machine(%s)" % module_id)
	return machine


## Guasta subito, senza immunita ne invulnerabilita.
func _break(machine: Machine) -> void:
	machine._hit_cooldown_left = 0.0
	machine._invulnerable_left = 0.0
	machine.take_hit(machine.health)


func _visible_cubes(machine: Machine) -> int:
	return machine._cargo.filter(func(c: MeshInstance3D) -> bool: return c.visible).size()


func _test_fuse_two() -> void:
	print("fuse two")
	var lead := await _reset()
	var turret := _add(&"turret")
	_check(_caravan.can_fuse(lead, turret), "si possono fondere")
	_check(_caravan.fuse(lead, turret), "fusione riuscita")
	_check(_caravan.machines.size() == 1 and lead.module_ids() == [&"cargo", &"turret"] and _caravan.carried == 2,
		"una macchina, 1 rottame speso (%s, %d)" % [lead.module_ids(), _caravan.carried])
	_check(lead.size == MachineFusion.Size.MEDIUM and lead.max_health == 15 and lead.health == 15,
		"media, 15/15 (%d/%d)" % [lead.health, lead.max_health])
	_check(is_equal_approx(lead.model_scale, 1.25) and is_equal_approx(lead.power, 1.15) and is_equal_approx(lead.top_speed(), 4.5)
		and is_equal_approx(lead.contact_reach(), _caravan.tuning.contact_radius * 1.25), "scala 1,25, forza 1,15, 4,5 m/s, contatto in scala")
	_check(lead.modules.all(func(m: MachineModule) -> bool: return is_equal_approx(m.power, 1.15)), "la forza passa a ogni modulo")
	var part := lead.get_node_or_null(^"TurretPart") as Node3D
	var expected := Machine.RIG_GROUND + (TURRET_PART_POSITION + Machine.PART_STACK[1] - Machine.RIG_GROUND) * 1.25
	_check(part != null and part.position.is_equal_approx(expected) and part.scale.is_equal_approx(Vector3.ONE * 1.25),
		"pezzo impilato al posto 1 e in scala attorno al suolo (%s)" % [part.position if part != null else Vector3.INF])
	var ring := lead.get_node(^"GroundRing") as Decal
	_check(ring.size.is_equal_approx(Machine.RING_SIZE * 1.25) and ring.position.is_equal_approx(Machine.RIG_GROUND), "anello in scala, sul suolo")
	_check(not _queue.bodies.has(turret) and _removed == [turret], "assorbita fuori dalla coda, machine_removed")
	await _frames(1)
	_check(lead.get_node_or_null(^"TurretPart") != null and not is_instance_valid(turret), "pezzo montato, assorbita liberata")


func _test_fuse_rejects() -> void:
	print("fuse rejects")
	var lead := await _reset()
	var turret := _add(&"turret")
	var drill := _add(&"drill")
	var before := _caravan.module_count()
	_break(turret)
	_check(turret.is_broken() and not _caravan.can_fuse(lead, turret) and not _caravan.fuse(lead, turret)
		and not _caravan.fuse(turret, lead), "guasta: no")
	_check(not _caravan.fuse(lead, lead), "stessa macchina: no")
	_caravan.carried = 0
	_check(not _caravan.can_fuse(lead, drill) and not _caravan.fuse(lead, drill), "senza rottami: no")
	_caravan.carried = 3
	var stranger := (load(Caravan.MACHINE_SCENE_PATH) as PackedScene).instantiate() as Machine
	_check(not _caravan.can_fuse(lead, stranger) and not _caravan.fuse(lead, stranger) and not _caravan.fuse(stranger, drill),
		"macchina estranea: no")
	stranger.free()
	_check(_caravan.machines.size() == 3 and _caravan.carried == 3 and _caravan.module_count() == before
		and lead.module_ids() == [&"cargo"] and drill.module_ids() == [&"drill"], "niente cambia")
	# Sette moduli in una: la carovana ne ammette 7 solo qui (copia della taratura).
	var tuning := _caravan.tuning
	lead = await _reset()
	_caravan.tuning = tuning.duplicate() as CaravanTuning
	_caravan.tuning.module_limit = 7
	lead.cargo().capacity = 10
	_caravan.carried = 10
	for id: StringName in [&"turret", &"drill", &"shovel", &"siren", &"beacon"]:
		_caravan.fuse(lead, _add(id))
	var magnet := _add(&"magnet")
	_check(lead.modules.size() == 6 and _caravan.working_carried() >= 1, "base da 6 moduli, rottami bastano")
	_check(not _caravan.can_fuse(lead, magnet) and not _caravan.fuse(lead, magnet) and not _caravan.fuse(magnet, lead)
		and lead.modules.size() == 6 and _caravan.carried == 5 and _caravan.machines.size() == 2, "7 moduli in una: no")
	_caravan.tuning = tuning


func _test_six_into_colossus() -> void:
	print("colossus")
	var lead := await _reset()
	var others: Array[Machine] = []
	for id: StringName in [&"turret", &"turret", &"drill", &"shovel", &"siren"]:
		others.append(_add(id))
	_caravan.carried = 5
	for m in others:
		_check(_caravan.fuse(lead, m), "fusione")
	_check(_caravan.carried == 0 and lead.modules.size() == 6 and lead.size == MachineFusion.Size.COLOSSUS, "colosso per 5 rottami")
	_check(lead.max_health == 63 and is_equal_approx(lead.top_speed(), 3.5) and is_equal_approx(lead.power, 1.75),
		"63 PV, 3,5 m/s, forza 1,75 (%d, %.2f, %.2f)" % [lead.max_health, lead.top_speed(), lead.power])
	_check(lead.get_node_or_null(^"TurretPart2") != null and lead.get_node_or_null(^"TurretModule2") != null and lead.slot == 0,
		"nomi distinti, posto 0")
	_check(lead._parts.size() == 5 and is_equal_approx(lead.model_scale, 1.8), "cinque pezzi, scala 1,8")


func _test_detach() -> void:
	print("detach")
	var m := await _reset()
	_caravan.fuse(m, _add(&"turret"))
	_caravan.fuse(m, _add(&"siren"))
	_caravan.carried = 3
	_check(m.module_ids() == [&"cargo", &"turret", &"siren"] and m.max_health == 23 and m.health == 23, "[cargo, turret, siren] 23/23")
	_check(_caravan.can_detach(m, 2) and not _caravan.can_detach(m, 3), "si sgancia un modulo che c'e")
	var new := _caravan.detach(m, 2)
	_check(new != null and new.module_ids() == [&"siren"] and new.health == 6 and new.max_health == 6 and _queue.bodies.has(new),
		"Sirena piccola e piena")
	_check(m.max_health == 15 and m.health == 15 and _caravan.carried == 2 and new.slot != m.slot,
		"sorgente 15/15, 1 rottame, posto diverso (%d/%d, %d)" % [m.health, m.max_health, _caravan.carried])
	_check(m.get_node_or_null(^"SirenPart") == null and m.get_node_or_null(^"SirenModule") == null and m._parts.size() == 1,
		"pezzo e modulo tolti dalla sorgente")
	_check(_caravan.detach(new, 0) == null and not _caravan.can_detach(new, 0), "una piccola non si sgancia")
	# Il Cassone con 2 rottami: la macchina nuova li porta, il totale scende solo del costo.
	var cargo := _caravan.detach(m, 0)
	_check(cargo != null and cargo.module_ids() == [&"cargo"] and cargo.cargo().carried == 1 and cargo.cargo().capacity == 5
		and _caravan.carried == 1, "il Cassone sganciato porta i suoi rottami (%d)" % _caravan.carried)
	_check(m.module_ids() == [&"turret"] and m.cargo() == null and m.size == MachineFusion.Size.SMALL and m.max_health == 6
		and is_equal_approx(m.model_scale, 1.0), "la sorgente torna piccola")
	_check(_caravan.lead() == cargo, "capofila: la macchina col Cassone")
	_caravan.fuse(cargo, m)
	_caravan.carried = 0
	_check(cargo.modules.size() == 2 and not _caravan.can_detach(cargo, 1) and _caravan.detach(cargo, 1) == null,
		"senza rottami non si sgancia")


func _test_remove_machine() -> void:
	print("remove machine")
	var lead := await _reset()
	var turret := _add(&"turret")
	var welder := _add(&"welder")
	var spot := Vector3(4.0, 0.0, 6.0)
	_player.global_position = Vector3(spot.x, _field.height_at(spot) + 0.88, spot.z)
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	var at := spot + Vector3(1.0, 0.0, 0.0)
	turret.global_position = Vector3(at.x, _field.height_at(at) + Caravan.GROUND_CLEARANCE, at.z)
	turret.reset_physics_interpolation()
	_break(turret)
	# Il Saldatore fermo tiene la chiave della guasta (lo stato del suo `tick` in raggio).
	welder.set_physics_process(false)
	var welding := welder.module(&"welder") as WelderModule
	welding._broken_elapsed[turret] = 1.0
	_player.interact_held = true
	await _frames(20)
	_check(_caravan.repairing_machine() == turret and _caravan.repair_progress() > 0.0, "riparazione della Torretta in corso")
	var carried := _caravan.carried
	_caravan.remove_machine(turret)
	_check(_caravan.repairing_machine() == null and _caravan.repair_progress() == 0.0, "riparazione azzerata")
	_check(not welding._broken_elapsed.has(turret) and not _queue.bodies.has(turret) and not _caravan.machines.has(turret)
		and _removed == [turret], "nessun riferimento rimasto")
	await _frames(int(_caravan.tuning.repair_seconds * 60.0) + 10)
	_check(_caravan.carried == carried and not is_instance_valid(turret), "niente speso, Torretta liberata")
	_player.interact_held = false
	welder.set_physics_process(true)
	var second := _add(&"cargo")
	_caravan.remove_machine(lead)
	_check(_caravan.lead() == second, "tolto il capofila: il secondo Cassone")
	_caravan.remove_machine(second)
	_caravan.remove_machine(welder)
	_check(_caravan.machines.is_empty() and _caravan.lead() == null, "carovana vuota: nessun capofila")
	await _frames(1)


func _test_lead_rule() -> void:
	print("lead rule")
	var first := await _reset()
	var second := _add(&"cargo")
	_check(_caravan.lead() == first, "il Cassone piu vecchio")
	_break(first)
	_check(_caravan.lead() == second, "il primo guasto: il secondo")
	_break(second)
	_check(_caravan.lead() == first, "entrambi guasti: il primo")
	_caravan.remove_machine(first)
	_caravan.remove_machine(second)
	var turret := _add(&"turret")
	_add(&"drill")
	_check(_caravan.lead() == turret, "nessun Cassone: la prima macchina")


func _test_combo_signal() -> void:
	print("combo signal")
	await _reset()
	var drill := _add(&"drill")
	var magnet := _add(&"magnet")
	_check(_caravan.fuse(drill, magnet) and _combos_formed == [&"extractor"], "combo_formed una volta: Estrattore (%s)" % [_combos_formed])
	_check(drill.combos() == [&"extractor"] and drill.has_combo(&"extractor"), "la macchina ha l'Estrattore")
	_check(_caravan.fuse(drill, _add(&"turret")) and _combos_formed == [&"extractor"], "una Torretta non la riemette")
	_break(drill)
	_check(not drill.has_combo(&"extractor") and drill.combos() == [&"extractor"], "da guasta la combinazione non vale")


func _test_duplicates() -> void:
	print("duplicates")
	var lead := await _reset()
	var magnet := _add(&"magnet")
	var other := _add(&"magnet")
	_check(_caravan.fuse(magnet, other), "due Calamite fuse")
	await _frames(1)
	var entries := _xp.attractors.filter(func(e: Dictionary) -> bool: return is_instance_valid(e.node) and e.node == magnet)
	_check(entries.size() == 1 and _xp.attractors.size() == 1, "un solo attrattore per la macchina (%d)" % _xp.attractors.size())
	var second := _add(&"cargo")
	_check(_caravan.fuse(lead, second), "due Cassoni fusi")
	_caravan.carried = 7
	_check(_caravan.capacity == 10 and _visible_cubes(lead) == 7, "capienza 10, cubetti visibili == carried (%d)" % _visible_cubes(lead))
	await _frames(120)
	_check(_visible_cubes(lead) == _caravan.carried and _xp.attractors.size() == 1, "dopo 2 s cubetti e attrattore in ordine")
	# Sganciando una delle due Calamite la gemella che resta tiene il suo attrattore.
	var single := _caravan.detach(magnet, 1)
	await _frames(1)
	var nodes := _xp.attractors.map(func(e: Dictionary) -> Object: return e.node)
	_check(single != null and nodes.size() == 2 and nodes.has(magnet) and nodes.has(single), "sganciata una Calamita: due attrattori, uno per macchina")
