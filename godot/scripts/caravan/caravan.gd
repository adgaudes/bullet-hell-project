class_name Caravan
extends Node3D
## Carovana di macchine (spec D-093, Sezioni 1, 4 e 5): possiede le Machine (figlie di questo
## nodo) e il pool dei rottami dei Cassoni, e tiene la firma di fornitura del compagno di oggi
## (`carried`, `carried_changed`, `can_supply`, `spend`, `can_supply_count`, `spend_count`):
## lampioni e audio non cambiano chiamata. Le macchine tengono un posto del grappolo attorno
## al giocatore; la direzione "dietro" e quella del compagno, applicata al capofila.

signal carried_changed(carried: int)
## Macchine, moduli (aggiunti, livelli, accesi o spenti), capienza o stato di una macchina
## (guasta, in ritirata, di nuovo in ordine) cambiati: HUD e luci dei Faro.
signal changed
signal machine_added(machine: Machine)

const MACHINE_SCENE_PATH := "res://scenes/caravan/machine.tscn"
## Altezza dell'origine della macchina sul suolo (meta del box di collisione).
const GROUND_CLEARANCE := 0.3
## Rotazioni (gradi) provate attorno al giocatore per un posto o una ritirata non percorribili.
const SLOT_SEARCH_DEGREES: Array[float] = [0.0, 30.0, -30.0, 60.0, -60.0]

@export var tuning: CaravanTuning
@export var player: PlayerCharacter
@export var scrap_field: ScrapField
## Opzionale: per raggiungere il giocatore aggirando mura e terrapieni (D-038).
@export var path_field: PathField

var machines: Array[Machine] = []
## Moltiplicatore della velocita massima: le macchine lo leggono a ogni passo, quindi vale
## per tutte, anche per quelle aggiunte dopo.
var speed_scale := 1.0
## Rottami di tutti i Cassoni, guasti compresi. Assegnarlo ridistribuisce il totale dal
## capofila in poi (una notifica sola).
var carried: int:
	get:
		var total := 0
		for module in modules_of(&"cargo"):
			total += (module as CargoModule).carried
		return total
	set(value):
		_begin_cargo_change()
		var left := maxi(value, 0)
		for module in modules_of(&"cargo"):
			var cargo := module as CargoModule
			var put := mini(left, cargo.capacity)
			cargo.carried = put
			left -= put
		_end_cargo_change()
var capacity: int:
	get:
		var total := 0
		for module in modules_of(&"cargo"):
			total += (module as CargoModule).capacity
		return total

## Servizi di `configure`, passati a ogni modulo (anche futuro) che ha una proprieta col nome.
var _services: Dictionary[StringName, Variant] = {}
## Livello di ogni tipo di modulo (carte di livello) e capienza in piu dei Cassoni: valgono
## anche per i moduli aggiunti dopo.
var _levels: Dictionary[StringName, int] = {}
var _cargo_bonus := 0
var _machine_scene: PackedScene
var _machine_serial := 0
## Notifiche dei rottami raggruppate: una sola `carried_changed` per operazione pubblica.
var _cargo_batch := 0
var _last_carried := 0
## Ultimo punto chiesto a `can_supply_count`: `spend_count` preleva dal Cassone piu vicino.
var _supply_point := Vector3.INF


func _ready() -> void:
	if tuning == null:
		tuning = CaravanTuning.new()
	_add_machine(&"cargo", global_position, tuning.starting_scrap)
	print("PROTOTYPE01_CARAVAN_READY machines=%d carried=%d" % [machines.size(), carried])


## Servizi della run (`director`, `terrain_field`, `write_queue`, `xp_field`, `light_field`,
## `run_tuning`, e altri dei task successivi): li salva e li passa ai moduli, presenti e futuri.
## I moduli gia presenti rifanno `apply_level`: chi e nato prima dei servizi (Torretta,
## Calamita, Faro) si registra ora.
func configure(services: Dictionary) -> void:
	for key: Variant in services:
		_services[StringName(key)] = services[key]
	for machine in machines:
		for module in machine.modules:
			_give_services(module)
			module.apply_level(module.level)
		_track_body(machine)
	var director: Object = _services.get(&"director")
	if director != null and &"caravan" in director:
		director.set(&"caravan", self)


## Aggiunge una macchina col modulo [param module_id] nel posto libero piu basso, in
## [param at] o sul suolo del suo posto. Null a carovana piena o per un modulo sconosciuto.
func add_machine(module_id: StringName, at: Variant = null) -> Machine:
	return _add_machine(module_id, at, 0)


func module_count() -> int:
	var total := 0
	for machine in machines:
		total += machine.modules.size()
	return total


func has_room(count := 1) -> bool:
	return module_count() + count <= tuning.module_limit


func count_of(module_id: StringName) -> int:
	return modules_of(module_id).size()


func modules_of(module_id: StringName) -> Array[MachineModule]:
	var result: Array[MachineModule] = []
	for machine in machines:
		for module in machine.modules:
			if module.module_id == module_id:
				result.append(module)
	return result


## Livello delle carte di un tipo di modulo (Torretta veloce, Calamita potente, Faro): vale per
## i moduli presenti e per quelli che arrivano dopo.
func set_module_level(module_id: StringName, level: int) -> void:
	_levels[module_id] = level
	for module in modules_of(module_id):
		module.apply_level(level)
	changed.emit()


func module_level(module_id: StringName) -> int:
	return _levels.get(module_id, 0)


## Luci dei Faro accesi, `{light: OmniLight3D, radius: float}`: ArenaRun vi applica il
## fattore di notte, come alla torcia.
func beacon_lights() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for module in modules_of(&"beacon"):
		var beacon := module as BeaconModule
		if beacon != null and beacon.active:
			result.append({light = beacon.light, radius = beacon.radius()})
	return result


## La macchina col Cassone piu vecchio, altrimenti la prima, altrimenti null.
func lead() -> Machine:
	for machine in machines:
		if machine.has_module(&"cargo"):
			return machine
	return machines[0] if not machines.is_empty() else null


## Le macchine guaste, nell'ordine della carovana (HUD, riparazione).
func broken_machines() -> Array[Machine]:
	var result: Array[Machine] = []
	for machine in machines:
		if machine.is_broken():
			result.append(machine)
	return result


## Il direttore dei nemici passato da `configure`, o null (la ritirata cerca li il nemico piu vicino).
func enemy_director() -> EnemyDirector:
	return _services.get(&"director") as EnemyDirector


# --- Rottami ---------------------------------------------------------------------------------

func room() -> int:
	return capacity - carried


## Riempie i Cassoni dal capofila in poi, guasti compresi; restituisce quanti ne sono entrati.
func add_scrap(amount: int) -> int:
	_begin_cargo_change()
	var left := maxi(amount, 0)
	for module in modules_of(&"cargo"):
		var cargo := module as CargoModule
		var put := mini(left, cargo.room())
		cargo.carried += put
		left -= put
	_end_cargo_change()
	return maxi(amount, 0) - left


## Capienza in piu per ogni Cassone, anche per quelli che arrivano dopo.
func add_cargo_capacity(extra: int) -> void:
	_cargo_bonus += extra
	for module in modules_of(&"cargo"):
		(module as CargoModule).add_capacity(extra)
	changed.emit()


## Puo pagare un rialzo sulla cella che contiene [param world_target]?
func can_supply(world_target: Vector3) -> bool:
	return can_supply_count(world_target, 1)


func spend() -> void:
	spend_count(1)


## I Cassoni funzionanti entro `supply_radius` dal punto hanno almeno [param amount] rottami.
func can_supply_count(world_target: Vector3, amount: int) -> bool:
	_supply_point = world_target
	var available := 0
	for cargo in _working_cargo():
		if Machine.planar_distance(cargo.machine.global_position, world_target) <= tuning.supply_radius:
			available += cargo.carried
	return available >= amount


## Preleva dal Cassone funzionante piu vicino all'ultimo punto chiesto, poi dagli altri.
func spend_count(amount: int) -> void:
	var sources := _working_cargo()
	if _supply_point != Vector3.INF:
		var point := _supply_point
		sources.sort_custom(func(a: CargoModule, b: CargoModule) -> bool:
			return Machine.planar_distance(a.machine.global_position, point) < Machine.planar_distance(b.machine.global_position, point))
	_begin_cargo_change()
	_take(sources, amount)
	_end_cargo_change()
	print("PROTOTYPE01_SCRAP_SPENT carried=%d" % carried)


## Paga [param amount] rottami dai Cassoni funzionanti (anche dai guasti con
## [param include_broken]), dal capofila in poi: tutto o niente.
func pay(amount: int, include_broken := false) -> bool:
	var sources := _working_cargo()
	if include_broken:
		sources.clear()
		for module in modules_of(&"cargo"):
			sources.append(module as CargoModule)
	var available := 0
	for cargo in sources:
		available += cargo.carried
	if available < amount:
		return false
	_begin_cargo_change()
	_take(sources, amount)
	_end_cargo_change()
	return true


## Chiamata da un Cassone quando il suo carico cambia: fuori da un'operazione della carovana
## (una raccolta, un'assegnazione diretta) avvisa subito, dentro una sola volta alla fine.
func notify_cargo_changed() -> void:
	if _cargo_batch == 0:
		_emit_carried()


## Vero se [param point] e gia la meta di un Cassone diverso da [param by].
func is_scrap_claimed(point: Vector3, by: MachineModule) -> bool:
	for module in modules_of(&"cargo"):
		if module == by:
			continue
		var claimed: Variant = (module as CargoModule).claimed_scrap()
		if claimed != null and Machine.planar_distance(claimed, point) <= CargoModule.SAME_SCRAP_M:
			return true
	return false


# --- Grappolo --------------------------------------------------------------------------------

## Posto [param index] del grappolo: x = gradi dalla direzione "dietro", y = distanza (m).
## Oltre l'ultimo posto si riusa l'ultimo.
func slot_of(index: int) -> Vector2:
	var slots := tuning.cluster_slots
	if slots.is_empty():
		return Vector2(0.0, 2.5)
	return slots[clampi(index, 0, slots.size() - 1)]


## Punto del posto della macchina attorno al giocatore, sul suolo: il primo percorribile fra il
## posto e lo stesso ruotato di +-30 e +-60 gradi, altrimenti il posto com'e.
func slot_target(machine: Machine) -> Vector3:
	return _slot_point(machine.slot)


## Vero se [param point] e percorribile e da li si raggiunge il giocatore; senza campo di
## percorso (o non ancora pronto) ogni punto va bene.
func is_open_point(point: Vector3) -> bool:
	if path_field == null or not path_field.is_ready():
		return true
	return path_field.is_walkable(point) and path_field.cost_at(point) != PathField.UNREACHABLE


## Primo punto aperto (`is_open_point`) a [param distance] dal giocatore lungo [param direction]
## o la stessa ruotata di +-30 e +-60 gradi, sul suolo; null se nessuno lo e.
func walkable_near_player(direction: Vector3, distance: float) -> Variant:
	for degrees: float in SLOT_SEARCH_DEGREES:
		var point := _on_ground(player.global_position + direction.rotated(Vector3.UP, deg_to_rad(degrees)) * distance)
		if is_open_point(point):
			return point
	return null


func _slot_point(index: int) -> Vector3:
	var place := slot_of(index)
	var direction := _back_direction().rotated(Vector3.UP, deg_to_rad(place.x))
	var open: Variant = walkable_near_player(direction, place.y)
	if open != null:
		return open
	return _on_ground(player.global_position + direction * place.y)


## La regola del compagno di oggi, applicata al capofila: opposta alla velocita del
## giocatore sopra 1 m/s, altrimenti dal giocatore verso il capofila.
func _back_direction() -> Vector3:
	var back := Vector3.ZERO
	var player_planar := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if player_planar.length() > 1.0:
		back = -player_planar
	else:
		var leader := lead()
		if leader != null:
			back = leader.global_position - player.global_position
	back.y = 0.0
	if back.is_zero_approx():
		back = Vector3.BACK
	return back.normalized()


## [param point] alla quota del suolo; senza rilievo alla quota del giocatore.
func _on_ground(point: Vector3) -> Vector3:
	var field := _services.get(&"terrain_field") as TerrainField
	if field != null:
		point.y = field.height_at(point)
	elif player != null:
		point.y = player.global_position.y
	return point


# --- Interni ---------------------------------------------------------------------------------

## Script del modulo di ogni tipo: i tipi senza script (task 8) usano il modulo inerte.
static func module_script_for(module_id: StringName) -> GDScript:
	match module_id:
		&"cargo":
			return CargoModule
		&"turret":
			return TurretModule
		&"magnet":
			return MagnetModule
		&"beacon":
			return BeaconModule
	return MachineModule


func _add_machine(module_id: StringName, at: Variant, scrap: int) -> Machine:
	if not has_room() or not MachineCatalog.MODULES.has(module_id):
		return null
	if _machine_scene == null:
		_machine_scene = load(MACHINE_SCENE_PATH) as PackedScene
	var machine := _machine_scene.instantiate() as Machine
	_machine_serial += 1
	machine.name = "Machine%d" % _machine_serial
	machine.caravan = self
	machine.slot = _free_slot()
	machine.max_health = tuning.chassis_health
	machine.health = machine.max_health
	# Posto calcolato prima di entrare nella lista: la direzione "dietro" viene dal capofila
	# che c'e gia, non dalla macchina nuova ancora senza posizione.
	var place: Vector3
	if at != null:
		place = at
	elif player != null:
		place = _slot_point(machine.slot) + Vector3(0.0, GROUND_CLEARANCE, 0.0)
	else:
		place = global_position
	machine.position = to_local(place)
	add_child(machine)
	machine.reset_physics_interpolation()
	machines.append(machine)

	var module := module_script_for(module_id).new() as MachineModule
	module.module_id = module_id
	machine.add_module(module)
	_give_services(module)
	module.apply_level(module_level(module_id))
	if module is CargoModule:
		var cargo := module as CargoModule
		cargo.capacity = tuning.cargo_capacity + _cargo_bonus
		cargo.carried = scrap
	_track_body(machine)
	print("PROTOTYPE01_MACHINE_ADDED module=%s machines=%d modules=%d" % [module_id, machines.size(), module_count()])
	machine_added.emit(machine)
	changed.emit()
	return machine


## Indice di posto piu basso non occupato.
func _free_slot() -> int:
	var used: Dictionary[int, bool] = {}
	for machine in machines:
		used[machine.slot] = true
	var index := 0
	while used.has(index):
		index += 1
	return index


func _give_services(module: MachineModule) -> void:
	for key: StringName in [&"player", &"scrap_field", &"path_field"]:
		if key in module:
			module.set(key, get(key))
	for key in _services:
		if key in module:
			module.set(key, _services[key])


## Una macchina sta in `write_queue.bodies` finche esiste: resta alla stessa altezza sul suolo
## quando le armi o i moduli alzano il terreno sotto di lei.
func _track_body(machine: Machine) -> void:
	var queue := _services.get(&"write_queue") as TerrainWriteQueue
	if queue != null and not queue.bodies.has(machine):
		queue.bodies.append(machine)


func _working_cargo() -> Array[CargoModule]:
	var result: Array[CargoModule] = []
	for module in modules_of(&"cargo"):
		if not module.machine.is_broken():
			result.append(module as CargoModule)
	return result


## Toglie [param amount] rottami da [param sources], nell'ordine.
func _take(sources: Array[CargoModule], amount: int) -> void:
	var left := maxi(amount, 0)
	for cargo in sources:
		var taken := mini(left, cargo.carried)
		cargo.carried -= taken
		left -= taken


func _begin_cargo_change() -> void:
	_cargo_batch += 1


func _end_cargo_change() -> void:
	_cargo_batch -= 1
	if _cargo_batch == 0:
		_emit_carried()


func _emit_carried() -> void:
	var total := carried
	if total == _last_carried:
		return
	_last_carried = total
	carried_changed.emit(total)
