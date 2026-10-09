class_name Companion
extends CharacterBody3D
## Primo compagno macchina (Companion Slice, D-032; specifica in
## docs/COMPANION_SLICE_SPEC.md). Autonomo e non pilotabile: segue il giocatore,
## raccoglie i rottami prodotti scavando, li fornisce per i rialzi e, quando la
## sfera hazard punta verso il giocatore, alza da solo una cella sulla corsia.

signal carried_changed(carried: int)

## Lineari: carrozzeria chiara, striscia gialla anteriore, rottami color ruggine.
const BODY_COLOR := Color(0.75, 0.75, 0.68)
const STRIPE_COLOR := Color(1.0, 0.78, 0.05)
const CARGO_SIZE := 0.22

# --- Movimento procedurale (ActorMotion): un "telaio" calcolato a ogni passo e applicato
# a modello, cubetti e pezzi montati (restano figli diretti: chi li cerca per nome li trova).
## Punto d'appoggio a terra del telaio, nello spazio del compagno (origine al centro del box).
const RIG_GROUND := Vector3(0.0, -0.3, 0.0)
## Mezzo passo e mezza carreggiata (m): inclinandosi il telaio si alza di |angolo| x braccio.
const WHEEL_HALF_LENGTH := 0.42
const WHEEL_HALF_WIDTH := 0.4
## Inclinazione (rad) per ogni m/s^2 di accelerazione: muso in su partendo, giu frenando,
## rollio verso l'esterno quando scarta di lato. Limite in rad.
const TILT_PER_ACCELERATION := 0.005
const TILT_MAX := 0.12
## Rollio in curva (rad) per ogni rad/s di sterzata a piena velocita.
const TURN_ROLL := 0.02
## Velocita (1/s) con cui l'inclinazione insegue il bersaglio.
const TILT_RATE := 9.0
## Sospensioni: molla (rigidezza 1/s^2, smorzamento 1/s). Il telaio salta in su di
## BOUNCE_KICK_* (m/s) quando cambia il carico o la velocita cambia di colpo; non scende sotto il riposo.
const BOUNCE_STIFFNESS := 180.0
const BOUNCE_DAMPING := 11.0
const BOUNCE_KICK_CARGO := 0.75
const BOUNCE_KICK_PER_SPEED_CHANGE := 0.2
const BOUNCE_MAX := 0.08
## Sobbalzi della strada in marcia: radianti per metro e altezza (m) a piena velocita.
const ROAD_RADIANS_PER_METER := 7.0
const ROAD_BUMP := 0.015
## Tremito del motore da fermo: frequenza (Hz), rollio (rad) e sobbalzo (m). Sparisce in marcia.
const SHIVER_HZ := 13.0
const SHIVER_ROLL := 0.014
const SHIVER_HEIGHT := 0.008
## Cubetti che ballano quando il carico cambia: durata (s), frequenza (Hz), salto (m), rotazione (rad).
const CARGO_WOBBLE_SECONDS := 0.5
const CARGO_WOBBLE_HZ := 4.5
const CARGO_WOBBLE_HOP := 0.07
const CARGO_WOBBLE_TWIST := 0.3

@export var tuning: CompanionTuning
@export var player: PlayerCharacter
@export var grid: TerrainGrid
@export var hazard: TerrainHazard
@export var scrap_field: ScrapField
## Opzionale: per raggiungere il giocatore aggirando mura e terrapieni (D-038).
@export var path_field: PathField

var carried := 0
## Copia della capacita del tuning: gli upgrade la aumentano senza toccare la risorsa.
var capacity := 0
var _assist_cooldown := 0.0
var _cargo: Array[MeshInstance3D] = []
var _cargo_mesh: BoxMesh
var _cargo_material: StandardMaterial3D
## Stato del movimento procedurale (vedi le costanti RIG_*, TILT_*, BOUNCE_*, SHIVER_*, CARGO_WOBBLE_*).
var _cargo_rest: Array[Vector3] = []
var _parts: Array[Node3D] = []
var _part_rest: Array[Transform3D] = []
var _model_rest := Transform3D.IDENTITY
var _motion_time := 0.0
var _road_phase := 0.0
var _last_local_velocity := Vector3.ZERO
var _last_yaw := 0.0
var _tilt_pitch := 0.0
var _tilt_roll := 0.0
## Sospensioni: (altezza, velocita verticale).
var _bounce := Vector2.ZERO
## 1 appena il carico cambia, scende a 0 in CARGO_WOBBLE_SECONDS.
var _cargo_wobble := 0.0
var _shown_carried := -1
var _motion_at_rest := true

@onready var _model: Node3D = $Model


func _ready() -> void:
	if tuning == null:
		tuning = CompanionTuning.new()
	capacity = tuning.capacity
	carried = clampi(tuning.starting_scrap, 0, capacity)
	_build_visuals()
	if player != null:
		player.companion = self
	_refresh_cargo()
	print("PROTOTYPE01_COMPANION_READY carried=%d" % carried)


## Puo pagare un rialzo sulla cella che contiene [param world_target]?
func can_supply(world_target: Vector3) -> bool:
	return carried > 0 and _planar_distance(global_position, world_target) <= tuning.supply_radius


func spend() -> void:
	spend_count(1)


## Ha almeno [param amount] rottami ed e abbastanza vicino al punto.
func can_supply_count(world_target: Vector3, amount: int) -> bool:
	return carried >= amount and _planar_distance(global_position, world_target) <= tuning.supply_radius


func spend_count(amount: int) -> void:
	carried = maxi(carried - amount, 0)
	_refresh_cargo()
	print("PROTOTYPE01_SCRAP_SPENT carried=%d" % carried)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_assist_cooldown = maxf(_assist_cooldown - delta, 0.0)

	var destination := _choose_destination()
	var to_destination := destination - global_position
	to_destination.y = 0.0
	var desired := Vector3.ZERO
	var distance := to_destination.length()
	if distance > tuning.arrive_radius:
		# Rallenta in arrivo per non oscillare attorno al punto.
		desired = to_destination / distance * minf(tuning.max_speed, distance * 3.0)
	var planar := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, tuning.acceleration * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()

	if planar.length() > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(-planar.x, -planar.z), minf(delta * 10.0, 1.0))

	_collect_scrap()
	_assist_against_hazard()
	_update_motion(delta)


## Rottame vicino al giocatore se c'e posto nel cassone, altrimenti il punto
## di inseguimento dietro al giocatore.
func _choose_destination() -> Vector3:
	if scrap_field != null and carried < capacity:
		var scrap: Variant = _nearest_reachable_scrap()
		if scrap != null:
			return scrap
	# Lontano dal giocatore segue il campo di percorso, che aggira le mura.
	if path_field != null and path_field.is_ready() 			and _planar_distance(global_position, player.global_position) > tuning.follow_distance + 1.5:
		var waypoint: Variant = path_field.next_waypoint(global_position)
		if waypoint != null:
			return waypoint
	var back := global_position - player.global_position
	var player_planar := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if player_planar.length() > 1.0:
		back = -player_planar
	back.y = 0.0
	if back.is_zero_approx():
		back = Vector3.BACK
	return player.global_position + back.normalized() * tuning.follow_distance


## Rottame piu vicino al giocatore che abbia una strada nel campo di percorso (R-05):
## uno oltre un muro chiuso farebbe spingere il compagno contro le mura per sempre.
func _nearest_reachable_scrap() -> Variant:
	var best: Variant = null
	var best_distance := INF
	var routed := path_field != null and path_field.is_ready()
	for position in scrap_field.positions_near(player.global_position, tuning.pickup_radius_from_player):
		if routed and path_field.cost_at(position) == PathField.UNREACHABLE:
			continue
		var distance := _planar_distance(position, player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = position
	return best


func _collect_scrap() -> void:
	if scrap_field == null or carried >= capacity:
		return
	var taken := scrap_field.take_near(global_position, tuning.collect_radius, capacity - carried)
	if taken > 0:
		carried += taken
		_refresh_cargo()
		print("PROTOTYPE01_SCRAP_COLLECTED carried=%d" % carried)


## Se la sfera e diretta verso il giocatore, alza la prima cella Normal della
## corsia nella fascia davanti alla sfera, a portata del compagno.
func _assist_against_hazard() -> void:
	if hazard == null or grid == null or hazard.is_resting or carried <= 0 or _assist_cooldown > 0.0:
		return
	var direction := hazard.lane_direction
	var to_player := player.global_position - hazard.global_position
	to_player.y = 0.0
	var ahead := to_player.dot(direction)
	var lateral := (to_player - direction * ahead).length()
	if ahead <= 0.0 or ahead > tuning.threat_distance or lateral > tuning.lane_half_width:
		return

	var step := 0.4
	# Se un terrapieno sulla corsia protegge gia il giocatore, non spende nulla.
	var probe := 0.5
	while probe < ahead - 0.5:
		var probe_cell := grid.cell_at(hazard.global_position + direction * probe)
		probe += step
		if grid.state.is_valid(probe_cell) and grid.state.get_state(probe_cell) == TerrainState.CellState.RAISED:
			return

	var distance := tuning.block_min_ahead
	var limit := minf(tuning.block_max_ahead, ahead - 1.0)
	var own_cell := grid.cell_at(global_position)
	while distance <= limit:
		var point := hazard.global_position + direction * distance
		distance += step
		var cell := grid.cell_at(point)
		if not grid.state.is_valid(cell) or cell == own_cell:
			continue
		if grid.state.get_state(cell) != TerrainState.CellState.NORMAL:
			continue
		var center := grid.to_global(grid.cell_local_position(cell, TerrainState.CellState.NORMAL))
		# La cella intera deve stare davanti alla sfera, non sopra di essa.
		if (center - hazard.global_position).dot(direction) < tuning.block_min_ahead:
			continue
		if _planar_distance(global_position, center) > tuning.action_radius:
			continue
		if grid.apply_command_at(center, TerrainState.ToolMode.RAISE, player):
			print("PROTOTYPE01_COMPANION_RAISE X=%d Y=%d" % [cell.x, cell.y])
			spend()
			_assist_cooldown = tuning.assist_cooldown
			return


func _build_visuals() -> void:
	_model_rest = _model.transform
	_last_yaw = rotation.y
	# Modello `companion_cart` (tools/blender/build_actor_assets.py): la carrozzeria e
	# "vernice" tinta con BODY_COLOR, la striscia del muso e la superficie `stripe`.
	var body := ActorModel.mesh_instance_of($Model)
	if ActorModel.surface_material(body, "paint") != null:
		# Modello rifinito (D-072): carrozzeria dalla texture cotta, tinta BODY_COLOR.
		ActorModel.dress(body, ActorModel.textured_paint(body.mesh, BODY_COLOR, 2.5))
	else:
		var stripe_material := StandardMaterial3D.new()
		stripe_material.albedo_color = STRIPE_COLOR.linear_to_srgb()
		ActorModel.apply_materials(body, {
			"detail": ActorModel.paint_material(BODY_COLOR, 2.5),
			"stripe": stripe_material,
		})

	var cargo_mesh := BoxMesh.new()
	cargo_mesh.size = Vector3.ONE * CARGO_SIZE
	var cargo_material := StandardMaterial3D.new()
	cargo_material.albedo_color = ScrapField.SCRAP_COLOR.linear_to_srgb()
	_cargo_mesh = cargo_mesh
	_cargo_material = cargo_material
	_add_cargo_slots(capacity)


func _add_cargo_slots(count: int) -> void:
	for n in count:
		var i := _cargo.size()
		var cube := MeshInstance3D.new()
		cube.mesh = _cargo_mesh
		cube.material_override = _cargo_material
		# Due file sul pianale del cassone (0,30 m sopra l'origine nel modello).
		cube.position = Vector3((i % 2) * 0.28 - 0.14, 0.42 + (i / 2) * 0.24, 0.1)
		add_child(cube)
		_cargo.append(cube)
		_cargo_rest.append(cube.position)


## Upgrade Cassone rinforzato: piu capacita, piu cubetti visibili.
func add_capacity(extra: int, bonus_scrap := 0) -> void:
	capacity += extra
	_add_cargo_slots(extra)
	carried = mini(carried + bonus_scrap, capacity)
	_refresh_cargo()


## Monta un pezzo visibile (upgrade): una sola istanza per nome.
func mount_part(part_name: StringName, part: Node3D) -> void:
	var old := get_node_or_null(NodePath(part_name))
	if old != null:
		var index := _parts.find(old as Node3D)
		if index >= 0:
			_parts.remove_at(index)
			_part_rest.remove_at(index)
		# Via dall'albero subito: altrimenti il nuovo pezzo viene rinominato (@TurretPart@N)
		# e dal terzo montaggio dello stesso nome i pezzi si accumulano.
		remove_child(old)
		old.queue_free()
	part.name = part_name
	add_child(part)
	_parts.append(part)
	_part_rest.append(part.transform)


func _refresh_cargo() -> void:
	for i in _cargo.size():
		_cargo[i].visible = i < carried
	if carried != _shown_carried:
		# Solo visivo: i cubetti ballano e le sospensioni rispondono al carico che cambia.
		if _shown_carried >= 0:
			_cargo_wobble = 1.0
			_bounce.y += BOUNCE_KICK_CARGO
		_shown_carried = carried
	carried_changed.emit(carried)


static func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Movimento procedurale ---------------------------------------------------------------

## Sospensioni, inclinazione in accelerazione e in curva, tremito del motore e cubetti
## che ballano: un solo telaio applicato a tutti i visual a partire dalle pose di riposo.
## Legge lo stato di gioco, non lo cambia.
func _update_motion(delta: float) -> void:
	if not ActorMotion.enabled:
		if not _motion_at_rest:
			_apply_rig(Transform3D.IDENTITY, 0.0)
			_motion_at_rest = true
		return
	_motion_time += delta
	var local_velocity := Vector3(velocity.x, 0.0, velocity.z) * global_basis
	var speed := local_velocity.length()
	var speed_ratio := clampf(speed / maxf(tuning.max_speed, 0.01), 0.0, 1.0)
	var change := local_velocity - _last_local_velocity
	_last_local_velocity = local_velocity
	var acceleration := change / maxf(delta, 0.0001)
	var yaw_rate := wrapf(rotation.y - _last_yaw, -PI, PI) / maxf(delta, 0.0001)
	_last_yaw = rotation.y

	# Avanti e -Z: accelerando il muso sale (beccheggio positivo); scartando a destra
	# il telaio si corica a sinistra (rollio positivo), come in curva.
	var target_pitch := clampf(-acceleration.z * TILT_PER_ACCELERATION, -TILT_MAX, TILT_MAX)
	var target_roll := clampf(acceleration.x * TILT_PER_ACCELERATION - yaw_rate * speed_ratio * TURN_ROLL, -TILT_MAX, TILT_MAX)
	_tilt_pitch = ActorMotion.smooth(_tilt_pitch, target_pitch, TILT_RATE, delta)
	_tilt_roll = ActorMotion.smooth(_tilt_roll, target_roll, TILT_RATE, delta)

	_bounce.y += change.length() * BOUNCE_KICK_PER_SPEED_CHANGE
	_bounce = ActorMotion.spring(_bounce, BOUNCE_STIFFNESS, BOUNCE_DAMPING, delta)
	_road_phase = fmod(_road_phase + speed * ROAD_RADIANS_PER_METER * delta, TAU)
	var idle := 1.0 - speed_ratio
	var shiver := sin(_motion_time * TAU * SHIVER_HZ)
	var rise := clampf(_bounce.x, 0.0, BOUNCE_MAX) \
		+ (0.5 + 0.5 * sin(_road_phase)) * ROAD_BUMP * speed_ratio \
		+ (0.5 + 0.5 * shiver) * SHIVER_HEIGHT * idle
	var roll := _tilt_roll + shiver * SHIVER_ROLL * idle

	if _cargo_wobble > 0.0:
		_cargo_wobble = maxf(_cargo_wobble - delta / CARGO_WOBBLE_SECONDS, 0.0)
	var rig := ActorMotion.tilt_on_ground(RIG_GROUND, _tilt_pitch, roll, WHEEL_HALF_LENGTH, WHEEL_HALF_WIDTH)
	rig.origin.y += rise
	_apply_rig(rig, _cargo_wobble * _cargo_wobble)
	_motion_at_rest = false


## Applica il telaio a modello, cubetti visibili e pezzi montati. [param wobble] (0..1)
## fa ballare i cubetti, ognuno con la sua fase.
func _apply_rig(rig: Transform3D, wobble: float) -> void:
	_model.transform = rig * _model_rest
	# Tutti i cubetti, anche quelli nascosti: a interruttore spento tornano a riposo (P-05).
	for i in _cargo.size():
		var pose := Transform3D(Basis.IDENTITY, _cargo_rest[i])
		if wobble > 0.0:
			var beat := _motion_time * TAU * CARGO_WOBBLE_HZ + i * 1.9
			pose.basis = Basis.from_euler(Vector3(0.0, sin(beat) * CARGO_WOBBLE_TWIST * wobble, cos(beat) * CARGO_WOBBLE_TWIST * 0.5 * wobble))
			pose.origin.y += absf(sin(beat)) * CARGO_WOBBLE_HOP * wobble
		_cargo[i].transform = rig * pose
	for i in _parts.size():
		_parts[i].transform = rig * _part_rest[i]
