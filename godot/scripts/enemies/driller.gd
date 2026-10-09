class_name Driller
extends Enemy
## Secondo boss, la Trivella (D-066, docs/RAILWAY_LEVEL_SPEC.md sezione 5).
##
## Regola col terreno, leggibile al primo incontro: **carica in linea retta e scava un
## solco; un terrapieno la ferma**. Ciclo: mira (telegraph: la punta accelera e una
## striscia a terra mostra la linea), carica (fino a `charge_length` metri a
## `charge_speed`, ignorando il campo di percorso; ogni cella Normal sotto la punta
## diventa Lowered), poi riposo. Se la punta incontra una cella Raised la smonta
## (la cella torna Normal e lascia un rottame) e la Trivella resta **stordita**
## `stun_seconds`: in quel tempo subisce danno moltiplicato. I fossati non la
## rallentano; non costruisce nulla. Chi sta sulla linea viene colpito e spinto di lato.
## E un Enemy registrato nell'EnemyDirector e si guida da solo (`self_driven`).

signal charge_started(target: Vector3)
## reason: "length" (fine corsa), "wall" (terrapieno), "blocked" (rovina o bordo).
signal charge_ended(reason: StringName)
signal cell_drilled(cell: Vector2i)
signal wall_broken(cell: Vector2i)
signal stunned(seconds: float)

enum Phase { REST, AIM, CHARGE, STUN }

const BODY_MODEL := preload("res://assets/models/driller.glb")
const BIT_MODEL := preload("res://assets/models/driller_bit.glb")
const BODY_RADIUS := 0.9
const BODY_HEIGHT := 2.4
## Lineare: vernice dello scafo, rosso ruggine scuro (e colore dei frammenti alla morte).
const BODY_COLOR := Color(0.5, 0.1, 0.06)
const EARTH_COLOR := Color(0.44, 0.33, 0.21)
## Innesto della punta: davanti al collare, a meta altezza della capsula (origine al centro).
const BIT_REST := Vector3(0.0, -0.2, -1.3)
## Distanza dal centro alla punta: li si legge la cella da scavare.
const BIT_REACH := BODY_RADIUS + 1.4
const BIT_SPIN_MAX := 28.0
const BIT_SPIN_RATE := 24.0
const NO_CELL := Vector2i(-1, -1)
const ACCELERATION := 30.0
const TURN_RATE := 3.0
## Colore della striscia di mira e sua larghezza.
const AIM_COLOR := Color(1.0, 0.2, 0.1, 0.45)
const AIM_WIDTH := 1.8
## Spinta laterale per chi viene colpito in carica.
const SIDE_PUSH := 2.6
## Lungo la linea di mira, un ostacolo che non e una cella Raised entro questa distanza
## fa preferire il campo di percorso (non si carica contro una rovina).
const AIM_PROBE_METERS: Array[float] = [3.0, 6.0, 9.0]

# --- Movimento procedurale (ActorMotion): solo sul telaio visivo `_rig`.
const RIG_GROUND := Vector3(0.0, -BODY_HEIGHT * 0.5, 0.0)
const TRACK_HALF_LENGTH := 1.1
const TRACK_HALF_WIDTH := 0.95
const RUMBLE_HZ := 11.0
const RUMBLE_HEIGHT := 0.05
const RUMBLE_ROLL := 0.03
const STUN_PITCH := 0.09
const STUN_SINK := 0.08
const HEAVY_STAGGER_SECONDS := 0.3
const HEAVY_STAGGER_BACK := 0.08
const HEAVY_STAGGER_PITCH := 0.03

var player: PlayerCharacter
var grid: TerrainGrid
var path_field: PathField
var director: EnemyDirector
var lamp_field: LampField
var scrap_field: ScrapField
var companion: Node3D
var charge_speed := 6.0
var charge_length := 30.0
var aim_seconds := 2.0
var rest_seconds := 3.0
var stun_seconds := 3.0
var stun_damage_multiplier := 2.0
var contact_damage := 2
var contact_radius := 1.5

var phase := Phase.REST
var phase_left := 0.0
var charge_direction := Vector3.FORWARD
var charge_start := Vector3.ZERO
var charges := 0
var cells_drilled := 0
var walls_broken := 0
## Cella appena smontata dall'ultima carica, NO_CELL se nessuna.
var last_wall := NO_CELL

var _bit: MeshInstance3D
var _rig: Node3D
var _aim_strip: MeshInstance3D
var _bit_spin := 0.0
var _hit_this_charge: Dictionary[Node, bool] = {}
var _motion_time := 0.0
var _stun_weight := 0.0


func setup_driller(hp: int, flash_material: Material) -> void:
	name = "Driller"
	kind = &"driller"
	self_driven = true
	ignores_lowered = true
	hit_radius_bonus = BODY_RADIUS - RADIUS
	health = hp
	max_health = hp
	collision_layer = 16
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = BODY_HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	_body = MeshInstance3D.new()
	_body.mesh = ActorModel.mesh_of(BODY_MODEL)
	_base_material = ActorModel.textured_paint(_body.mesh, BODY_COLOR, 2.5, 0.7)
	_flash_material = flash_material
	ActorModel.dress(_body, _base_material)
	_body.position.y = -BODY_HEIGHT * 0.5
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_rig.add_child(_body)
	_bit = MeshInstance3D.new()
	_bit.name = "Bit"
	_bit.mesh = ActorModel.mesh_of(BIT_MODEL)
	ActorModel.dress(_bit, ActorModel.textured_paint(_bit.mesh, Color.WHITE, 0.0, 0.5))
	_bit.position = BIT_REST
	_rig.add_child(_bit)
	_aim_strip = MeshInstance3D.new()
	_aim_strip.name = "AimStrip"
	_aim_strip.top_level = true
	var strip := BoxMesh.new()
	strip.size = Vector3.ONE
	_aim_strip.mesh = strip
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = AIM_COLOR
	_aim_strip.material_override = material
	_aim_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_strip.visible = false
	add_child(_aim_strip)
	phase = Phase.REST
	phase_left = rest_seconds * 0.5


static func boss_spawn_height() -> float:
	return BODY_HEIGHT * 0.5 + 0.02


func spawn_center_height() -> float:
	return boss_spawn_height()


func death_debris_color() -> Color:
	return BODY_COLOR


func is_charging() -> bool:
	return phase == Phase.CHARGE


func is_stunned() -> bool:
	return phase == Phase.STUN


func is_aiming() -> bool:
	return phase == Phase.AIM


## Stordita subisce danno moltiplicato: e la finestra che un terrapieno le apre.
func take_damage(amount: int) -> bool:
	if phase == Phase.STUN:
		amount = int(ceil(amount * stun_damage_multiplier))
	return super.take_damage(amount)


## Un passo fisico, chiamato dall'EnemyDirector.
func drive(delta: float) -> void:
	if player == null or grid == null:
		return
	var pos := global_position
	var to_player := _planar(player.global_position - pos)
	if phase != Phase.STUN and to_player.length() <= contact_radius:
		player.take_damage(contact_damage)
	if lamp_field != null and lamp_field.count() > 0:
		lamp_field.knock_down_near(pos, contact_radius)
	phase_left -= delta
	match phase:
		Phase.REST:
			_face(to_player, delta)
			_settle(delta)
			if phase_left <= 0.0:
				_start_aim()
		Phase.AIM:
			_face(charge_direction, delta)
			_settle(delta)
			_update_aim_strip()
			if phase_left <= 0.0:
				_start_charge()
		Phase.CHARGE:
			_tick_charge(delta)
		Phase.STUN:
			_settle(delta)
			if phase_left <= 0.0:
				phase = Phase.REST
				phase_left = rest_seconds


func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(delta * TURN_RATE, 1.0))


## Da ferma: frena e resta appoggiata a terra.
func _settle(delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, ACCELERATION * delta)
	velocity = Vector3(planar.x, 0.0 if is_on_floor() else velocity.y - 9.8 * delta, planar.z)
	move_and_slide()


func _start_aim() -> void:
	phase = Phase.AIM
	phase_left = aim_seconds
	charge_direction = _aim_direction()
	_aim_strip.visible = true
	_update_aim_strip()


## Dritto verso il giocatore; se nei primi metri c'e una rovina (non un terrapieno,
## quello lo vuole) segue il campo di percorso.
func _aim_direction() -> Vector3:
	var pos := global_position
	var direct := _planar(player.global_position - pos)
	if direct.length_squared() < 0.01:
		return -global_basis.z
	direct = direct.normalized()
	if path_field == null or not path_field.is_ready():
		return direct
	for meters in AIM_PROBE_METERS:
		var probe := pos + direct * meters
		if not path_field.is_walkable(probe) and grid.cell_state_at(probe) != TerrainState.CellState.RAISED:
			var waypoint: Variant = path_field.next_waypoint(pos)
			if waypoint != null:
				var via := _planar(waypoint - pos)
				if via.length_squared() > 0.01:
					return via.normalized()
			break
	return direct


func _update_aim_strip() -> void:
	var from := global_position
	# Sopra rotaie e massicciata del livello 2 (0,36 m): la striscia si vede anche sui binari.
	from.y = 0.4
	var to := from + charge_direction * charge_length
	var mid := (from + to) * 0.5
	var basis := Basis(Vector3.UP, atan2(-charge_direction.x, -charge_direction.z))
	_aim_strip.global_transform = Transform3D(basis.scaled_local(Vector3(AIM_WIDTH, 0.04, charge_length)), mid)


func _start_charge() -> void:
	phase = Phase.CHARGE
	phase_left = INF
	charges += 1
	charge_start = global_position
	last_wall = NO_CELL
	_hit_this_charge.clear()
	_aim_strip.visible = false
	var target := charge_start + charge_direction * charge_length
	print("PROTOTYPE01_DRILLER_CHARGE n=%d dir=(%.2f, %.2f)" % [charges, charge_direction.x, charge_direction.z])
	charge_started.emit(target)


func _tick_charge(delta: float) -> void:
	rotation.y = atan2(-charge_direction.x, -charge_direction.z)
	var planar := Vector3(velocity.x, 0.0, velocity.z).move_toward(charge_direction * charge_speed, ACCELERATION * delta)
	velocity = Vector3(planar.x, 0.0 if is_on_floor() else velocity.y - 9.8 * delta, planar.z)
	move_and_slide()
	var pos := global_position
	# La punta scava la cella che ha davanti.
	var tip := pos + charge_direction * BIT_REACH
	var cell := grid.cell_at(tip)
	if grid.state.is_valid(cell):
		match grid.state.get_state(cell):
			TerrainState.CellState.RAISED:
				_break_wall(cell)
				return
			TerrainState.CellState.NORMAL:
				if grid.force_cell_state(cell, TerrainState.CellState.LOWERED):
					cells_drilled += 1
					DebrisBurst.spawn(get_parent(), _cell_center(cell) + Vector3(0.0, 0.3, 0.0), EARTH_COLOR, 6, 3.0, 0.16)
					cell_drilled.emit(cell)
	_hit_in_the_way(player, true)
	if companion != null:
		_hit_in_the_way(companion, false)
	# Fermata contro una rovina o il bordo (mai contro una cella della griglia: quella la scava).
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		# Il pavimento non conta: solo pareti (normale quasi orizzontale) che non sono celle.
		if collision.get_normal().y > 0.5:
			continue
		var collider := collision.get_collider() as Node
		if collider != null and collider.get_parent() != grid:
			_end_charge(&"blocked")
			return
	if _planar(pos - charge_start).length() >= charge_length:
		_end_charge(&"length")


func _hit_in_the_way(body: Node3D, damages: bool) -> void:
	if body == null or _hit_this_charge.has(body):
		return
	var offset := _planar(body.global_position - global_position)
	if offset.length() > contact_radius + 0.4:
		return
	_hit_this_charge[body] = true
	var side := Vector3(-charge_direction.z, 0.0, charge_direction.x)
	if offset.dot(side) < 0.0:
		side = -side
	if damages and body is PlayerCharacter:
		(body as PlayerCharacter).take_damage(contact_damage)
	var at := body.global_position + side * SIDE_PUSH
	body.global_position = at
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	body.reset_physics_interpolation()


## Un terrapieno ferma la carica: la cella torna Normal, lascia un rottame, e la
## Trivella resta stordita con la punta scoperta.
func _break_wall(cell: Vector2i) -> void:
	grid.force_cell_state(cell, TerrainState.CellState.NORMAL)
	walls_broken += 1
	last_wall = cell
	DebrisBurst.spawn(get_parent(), _cell_center(cell) + Vector3(0.0, 0.6, 0.0), EARTH_COLOR, 14, 5.0, 0.22)
	if scrap_field != null:
		scrap_field.spawn_on_cell(cell, TerrainState.CellState.NORMAL)
	print("PROTOTYPE01_DRILLER_WALL X=%d Y=%d total=%d" % [cell.x, cell.y, walls_broken])
	wall_broken.emit(cell)
	_end_charge(&"wall")
	phase = Phase.STUN
	phase_left = stun_seconds
	print("PROTOTYPE01_DRILLER_STUNNED seconds=%.1f" % stun_seconds)
	stunned.emit(stun_seconds)


func _end_charge(reason: StringName) -> void:
	velocity = Vector3.ZERO
	phase = Phase.REST
	phase_left = rest_seconds
	print("PROTOTYPE01_DRILLER_CHARGE_END reason=%s cells=%d" % [reason, cells_drilled])
	charge_ended.emit(reason)


func _cell_center(cell: Vector2i) -> Vector3:
	var p := grid.to_global(grid.cell_local_position(cell, TerrainState.CellState.NORMAL))
	return Vector3(p.x, 0.0, p.z)


# --- Movimento procedurale -------------------------------------------------------------

## La punta gira (accelera in mira, piena in carica, si ferma stordita), i cingoli
## vibrano in carica, stordita affonda il muso; barcollamento pesante se colpita.
func _animate(delta: float) -> void:
	_motion_time += delta
	var spin_target := 0.0
	match phase:
		Phase.AIM:
			spin_target = BIT_SPIN_MAX * (1.0 - phase_left / maxf(aim_seconds, 0.01))
		Phase.CHARGE:
			spin_target = BIT_SPIN_MAX
	_bit_spin = move_toward(_bit_spin, spin_target, BIT_SPIN_RATE * delta)
	_bit.rotate_object_local(Vector3.FORWARD, _bit_spin * delta)
	var moving := clampf(Vector2(velocity.x, velocity.z).length() / maxf(charge_speed, 0.01), 0.0, 1.0)
	_stun_weight = move_toward(_stun_weight, 1.0 if phase == Phase.STUN else 0.0, 6.0 * delta)
	var pitch := STUN_PITCH * _stun_weight
	var roll := sin(_motion_time * TAU * 5.0) * RUMBLE_ROLL * moving
	var rise := (0.5 + 0.5 * sin(_motion_time * TAU * RUMBLE_HZ)) * RUMBLE_HEIGHT * moving - STUN_SINK * _stun_weight
	var slide := 0.0
	if _stagger > 0.0:
		_stagger = maxf(_stagger - delta / HEAVY_STAGGER_SECONDS, 0.0)
		var hit := _stagger * _stagger
		slide += HEAVY_STAGGER_BACK * hit
		pitch += HEAVY_STAGGER_PITCH * hit
	var pose := ActorMotion.tilt_on_ground(RIG_GROUND, pitch, roll, TRACK_HALF_LENGTH, TRACK_HALF_WIDTH)
	pose.origin += Vector3(0.0, rise, slide)
	_rig.transform = pose
	_at_rest = false


func _reset_pose() -> void:
	_rig.transform = Transform3D.IDENTITY
	_at_rest = true


static func _planar(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
