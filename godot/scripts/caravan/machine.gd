class_name Machine
extends CharacterBody3D
## Macchina della carovana (spec D-093, Sezioni 1 e 4): il carrello del compagno di oggi
## (D-032) con i moduli come nodi figli (uno solo nel piano A). Autonoma e non pilotabile:
## tiene il suo posto nel grappolo attorno al giocatore, o va dove un modulo la chiama
## (il Cassone verso i rottami). Senza carovana o senza giocatore resta ferma.

enum State { OK, RETREAT, BROKEN }

signal state_changed(state: int)

## Lineari: carrozzeria chiara, striscia gialla anteriore, rottami color ruggine.
const BODY_COLOR := Color(0.75, 0.75, 0.68)
const STRIPE_COLOR := Color(1.0, 0.78, 0.05)
const CARGO_SIZE := 0.22
## Layer visivo delle mesh della macchina (solo il 2): anelli e pennello, decal sul layer 1,
## non le dipingono (scelta 12 di D-093).
const VISUAL_LAYER := 2

# --- Movimento procedurale (ActorMotion): un "telaio" calcolato a ogni passo e applicato
# a modello, cubetti e pezzi montati (restano figli diretti: chi li cerca per nome li trova).
## Punto d'appoggio a terra del telaio, nello spazio della macchina (origine al centro del box).
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

var caravan: Caravan
var modules: Array[MachineModule] = []
## Punti vita del telaio (`chassis_health`, li imposta la carovana).
var max_health := 6
var health := 6
var state := State.OK
## Indice del posto nel grappolo (CaravanTuning.cluster_slots).
var slot := 0

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
## Materiali propri della macchina (la vernice). Li tiene anche la macchina: se li tenesse
## solo la superficie del modello, liberando il modello verrebbero liberati prima della sua
## istanza di resa e il server segnalerebbe `Parameter "material" is null` (verificato in
## headless su una macchina senza cubetti; anche il compagno senza cubetti lo fa).
var _own_materials: Array[Material] = []

@onready var _model: Node3D = $Model


func _ready() -> void:
	floor_max_angle = atan(0.8)
	_build_visuals()


## Aggiunge un modulo: figlio della macchina, col suo pezzo visibile se ne ha uno. I servizi
## glieli passa la carovana subito dopo.
func add_module(module: MachineModule) -> void:
	module.machine = self
	module.caravan = caravan
	if module.name.is_empty() or module.name.begins_with("@"):
		module.name = "%sModule" % String(module.module_id).capitalize()
	modules.append(module)
	add_child(module)
	var part := module.build_part()
	if part != null:
		mount_part(StringName("%sPart" % String(module.module_id).capitalize()), part)


func has_module(id: StringName) -> bool:
	return module(id) != null


func module(id: StringName) -> MachineModule:
	for candidate in modules:
		if candidate.module_id == id:
			return candidate
	return null


func cargo() -> CargoModule:
	return module(&"cargo") as CargoModule


## Tipo del primo modulo (icona e colore nel HUD), o vuoto.
func primary_module_id() -> StringName:
	return modules[0].module_id if not modules.is_empty() else &""


func is_broken() -> bool:
	return state == State.BROKEN


func _physics_process(delta: float) -> void:
	if caravan == null or caravan.player == null:
		return
	var tuning := caravan.tuning
	var top_speed := tuning.max_speed * caravan.speed_scale
	var destination := _choose_destination()
	var to_destination := destination - global_position
	to_destination.y = 0.0
	var desired := Vector3.ZERO
	var distance := to_destination.length()
	if distance > tuning.arrive_radius:
		# Rallenta in arrivo per non oscillare attorno al punto.
		desired = to_destination / distance * minf(top_speed, distance * 3.0)
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

	# Moduli prima del telaio, come la raccolta del compagno: un carico che cambia fa
	# saltare le sospensioni nello stesso passo.
	for each in modules:
		if each.active:
			each.tick(delta)
	_update_motion(delta)


## Meta del passo: la prima chiesta da un modulo attivo (il Cassone verso un rottame);
## lontano dal giocatore il campo di percorso, che aggira le mura; altrimenti il posto nel
## grappolo. Lo stesso ordine del compagno di oggi.
func _choose_destination() -> Vector3:
	for each in modules:
		if each.active:
			var wanted: Variant = each.wanted_destination()
			if wanted != null:
				return wanted
	var path_field := caravan.path_field
	if path_field != null and path_field.is_ready() \
			and planar_distance(global_position, caravan.player.global_position) > caravan.slot_of(slot).y + caravan.tuning.path_margin:
		var waypoint: Variant = path_field.next_waypoint(global_position)
		if waypoint != null:
			return waypoint
	return caravan.slot_target(self)


## Cubetti del pianale: [param capacity] posti, i primi [param carried] visibili. Quando il
## carico cambia ballano e le sospensioni rispondono (solo visivo).
func set_cargo_view(capacity: int, carried: int) -> void:
	if capacity > _cargo.size():
		_add_cargo_slots(capacity - _cargo.size())
	for i in _cargo.size():
		_cargo[i].visible = i < carried
	if carried != _shown_carried:
		if _shown_carried >= 0:
			_cargo_wobble = 1.0
			_bounce.y += BOUNCE_KICK_CARGO
		_shown_carried = carried


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
	_set_visual_layer(part)
	add_child(part)
	_parts.append(part)
	_part_rest.append(part.transform)


static func planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _build_visuals() -> void:
	_model_rest = _model.transform
	_last_yaw = rotation.y
	# Modello `companion_cart` (tools/blender/build_actor_assets.py): la carrozzeria e
	# "vernice" tinta con BODY_COLOR, la striscia del muso e la superficie `stripe`.
	var body := ActorModel.mesh_instance_of(_model)
	if ActorModel.surface_material(body, "paint") != null:
		# Modello rifinito (D-072): carrozzeria dalla texture cotta, tinta BODY_COLOR.
		var paint := ActorModel.textured_paint(body.mesh, BODY_COLOR, 2.5)
		ActorModel.dress(body, paint)
		_own_materials.append(paint)
	else:
		var paint := ActorModel.paint_material(BODY_COLOR, 2.5)
		var stripe_material := StandardMaterial3D.new()
		stripe_material.albedo_color = STRIPE_COLOR.linear_to_srgb()
		ActorModel.apply_materials(body, {
			"detail": paint,
			"stripe": stripe_material,
		})
		_own_materials.append_array([paint, stripe_material])
	_set_visual_layer(_model)


func _add_cargo_slots(count: int) -> void:
	if _cargo_mesh == null:
		_cargo_mesh = BoxMesh.new()
		_cargo_mesh.size = Vector3.ONE * CARGO_SIZE
		_cargo_material = StandardMaterial3D.new()
		_cargo_material.albedo_color = ScrapField.SCRAP_COLOR.linear_to_srgb()
	for n in count:
		var i := _cargo.size()
		var cube := MeshInstance3D.new()
		cube.mesh = _cargo_mesh
		cube.material_override = _cargo_material
		cube.layers = VISUAL_LAYER
		# Due file sul pianale del cassone (0,30 m sopra l'origine nel modello).
		cube.position = Vector3((i % 2) * 0.28 - 0.14, 0.42 + (i / 2) * 0.24, 0.1)
		add_child(cube)
		_cargo.append(cube)
		_cargo_rest.append(cube.position)


## Mette sul layer visivo della macchina [param node] e tutto cio che contiene.
static func _set_visual_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = VISUAL_LAYER
	for child in node.get_children():
		_set_visual_layer(child)


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
	var top_speed := caravan.tuning.max_speed * caravan.speed_scale
	var speed_ratio := clampf(speed / maxf(top_speed, 0.01), 0.0, 1.0)
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
