class_name Companion
extends CharacterBody3D
## Primo compagno macchina (Companion Slice, D-032; specifica in
## docs/COMPANION_SLICE_SPEC.md). Autonomo e non pilotabile: segue il giocatore,
## raccoglie i rottami prodotti scavando, li fornisce per i rialzi e, quando la
## sfera hazard punta verso il giocatore, alza da solo una cella sulla corsia.

signal carried_changed(carried: int)

## Lineari: cassone chiaro, striscia gialla anteriore, rottami color ruggine.
const BODY_COLOR := Color(0.75, 0.75, 0.68)
const STRIPE_COLOR := Color(1.0, 0.78, 0.05)
const CARGO_SIZE := 0.22

@export var tuning: CompanionTuning
@export var player: PlayerCharacter
@export var grid: TerrainGrid
@export var hazard: TerrainHazard
@export var scrap_field: ScrapField

var carried := 0
var _assist_cooldown := 0.0
var _cargo: Array[MeshInstance3D] = []


func _ready() -> void:
	if tuning == null:
		tuning = CompanionTuning.new()
	carried = clampi(tuning.starting_scrap, 0, tuning.capacity)
	_build_visuals()
	if player != null:
		player.companion = self
	_refresh_cargo()
	print("PROTOTYPE01_COMPANION_READY carried=%d" % carried)


## Puo pagare un rialzo sulla cella che contiene [param world_target]?
func can_supply(world_target: Vector3) -> bool:
	return carried > 0 and _planar_distance(global_position, world_target) <= tuning.supply_radius


func spend() -> void:
	carried = maxi(carried - 1, 0)
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


## Rottame vicino al giocatore se c'e posto nel cassone, altrimenti il punto
## di inseguimento dietro al giocatore.
func _choose_destination() -> Vector3:
	if scrap_field != null and carried < tuning.capacity:
		var scrap: Variant = scrap_field.nearest(player.global_position, tuning.pickup_radius_from_player)
		if scrap != null:
			return scrap
	var back := global_position - player.global_position
	var player_planar := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if player_planar.length() > 1.0:
		back = -player_planar
	back.y = 0.0
	if back.is_zero_approx():
		back = Vector3.BACK
	return player.global_position + back.normalized() * tuning.follow_distance


func _collect_scrap() -> void:
	if scrap_field == null or carried >= tuning.capacity:
		return
	var taken := scrap_field.take_near(global_position, tuning.collect_radius, tuning.capacity - carried)
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
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = BODY_COLOR.linear_to_srgb()
	($Body as MeshInstance3D).material_override = body_material
	var stripe_material := StandardMaterial3D.new()
	stripe_material.albedo_color = STRIPE_COLOR.linear_to_srgb()
	($Stripe as MeshInstance3D).material_override = stripe_material

	var cargo_mesh := BoxMesh.new()
	cargo_mesh.size = Vector3.ONE * CARGO_SIZE
	var cargo_material := StandardMaterial3D.new()
	cargo_material.albedo_color = ScrapField.SCRAP_COLOR.linear_to_srgb()
	for i in tuning.capacity:
		var cube := MeshInstance3D.new()
		cube.mesh = cargo_mesh
		cube.material_override = cargo_material
		# Due file sopra il cassone.
		cube.position = Vector3((i % 2) * 0.28 - 0.14, 0.42 + (i / 2) * 0.24, 0.1)
		add_child(cube)
		_cargo.append(cube)


func _refresh_cargo() -> void:
	for i in _cargo.size():
		_cargo[i].visible = i < carried
	carried_changed.emit(carried)


static func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
