class_name Demolisher
extends Enemy
## Primo boss di fine livello (D-043, CAMPAIGN_STRUCTURE_SPEC sezione 5): il Demolitore.
##
## Regola col terreno, leggibile al primo incontro: **i terrapieni lo attirano e lui
## li smonta**. Ogni `walls_per_barricade` mura smontate i suoi rottami diventano
## una **barricata** (cella Raised scura) fra lui e il giocatore, che ferma i chiodi.
## Soluzioni che il campo offre:
## - un fossato (celle Lowered) lo rallenta come ogni altro nemico;
## - un muro a sacrificio lo tiene fermo dove la chiodatrice lo colpisce, ma
##   alimenta le sue barricate;
## - scavare una barricata la fa crollare e restituisce il rottame.
## E un Enemy registrato nell'EnemyDirector (cosi armi, scavo esplosivo e torretta
## lo colpiscono), ma si guida da solo: `self_driven`.

signal wall_demolished(cell: Vector2i)
signal barricade_built(cell: Vector2i)

const BODY_RADIUS := 0.9
const BODY_HEIGHT := 2.4
const BODY_COLOR := Color(0.85, 0.55, 0.05)
const BLADE_COLOR := Color(0.08, 0.08, 0.09)
const EYE_COLOR := Color(1.0, 0.2, 0.05)
## Colore lineare delle barricate: ferro scuro, distinto dai terrapieni del giocatore.
const BARRICADE_COLOR := Color(0.07, 0.06, 0.09)
const ACCELERATION := 10.0
const RETARGET_SECONDS := 0.4
## Sotto questa distanza dal giocatore punta dritto, senza waypoint.
const DIRECT_CHASE_DISTANCE := 3.0

var player: PlayerCharacter
var grid: TerrainGrid
var path_field: PathField
var director: EnemyDirector
var companion: Node3D
var speed := 1.7
var contact_damage := 2
var contact_radius := 1.5
var demolish_seconds := 1.2
var wall_attraction_radius := 12.0
var walls_per_barricade := 2
var max_barricades := 8

## Celle delle barricate ancora in piedi.
var barricades: Dictionary[Vector2i, bool] = {}
var walls_demolished := 0
## Cella che sta smontando, (-1, -1) se nessuna.
var demolish_cell := Vector2i(-1, -1)

var _demolish_left := 0.0
var _pending_scrap := 0
var _wall_target := Vector2i(-1, -1)
var _retarget_left := 0.0
var _blade: MeshInstance3D


func setup_demolisher(hp: int, flash_material: Material) -> void:
	name = "Demolisher"
	self_driven = true
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

	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = BODY_COLOR.linear_to_srgb()
	body_material.roughness = 0.7
	_base_material = body_material
	_flash_material = flash_material
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.7, 1.7, 2.0)
	_body = MeshInstance3D.new()
	_body.mesh = body_mesh
	_body.material_override = body_material
	_body.position.y = -0.3
	add_child(_body)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = BLADE_COLOR
	dark.metallic = 0.5
	dark.roughness = 0.5
	# Lama da demolizione davanti e cabina sopra: sagoma da ruspa.
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(2.1, 1.0, 0.25)
	_blade = MeshInstance3D.new()
	_blade.mesh = blade_mesh
	_blade.material_override = dark
	_blade.position = Vector3(0.0, -0.6, -1.15)
	add_child(_blade)
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.0, 0.6, 0.9)
	var cabin := MeshInstance3D.new()
	cabin.mesh = cabin_mesh
	cabin.material_override = dark
	cabin.position = Vector3(0.0, 0.85, 0.3)
	add_child(cabin)
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = EYE_COLOR.linear_to_srgb()
	eye_material.emission_enabled = true
	eye_material.emission = EYE_COLOR.linear_to_srgb()
	eye_material.emission_energy_multiplier = 3.0
	var eye_mesh := BoxMesh.new()
	eye_mesh.size = Vector3(0.8, 0.14, 0.06)
	var eyes := MeshInstance3D.new()
	eyes.mesh = eye_mesh
	eyes.material_override = eye_material
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eyes.position = Vector3(0.0, 0.9, -0.16)
	add_child(eyes)


func _ready() -> void:
	if grid != null:
		grid.cell_changed.connect(_on_cell_changed)


## Altezza del centro della capsula sopra il pavimento.
static func boss_spawn_height() -> float:
	return BODY_HEIGHT * 0.5 + 0.02


func is_demolishing() -> bool:
	return demolish_cell.x >= 0


## Un passo fisico, chiamato dall'EnemyDirector.
func drive(delta: float) -> void:
	if player == null or grid == null:
		return
	var pos := global_position
	var to_player := _planar(player.global_position - pos)
	if to_player.length() <= contact_radius:
		player.take_damage(contact_damage)

	if is_demolishing():
		_tick_demolition(delta)
		return

	_retarget_left -= delta
	if _retarget_left <= 0.0:
		_retarget_left = RETARGET_SECONDS
		_wall_target = _nearest_wall()
	var has_wall := _wall_target.x >= 0 and grid.state.get_state(_wall_target) == TerrainState.CellState.RAISED
	var direction := Vector3.ZERO
	if has_wall:
		direction = _planar(_cell_center(_wall_target) - pos).normalized()
	else:
		if to_player.length() > DIRECT_CHASE_DISTANCE and path_field != null:
			var waypoint: Variant = path_field.next_waypoint(pos)
			if waypoint != null:
				direction = _planar(waypoint - pos).normalized()
		if direction.is_zero_approx():
			direction = to_player.normalized()

	var current_speed := speed
	if grid.cell_state_at(pos) == TerrainState.CellState.LOWERED:
		current_speed *= 1.0 - grid.lowered_speed_penalty()
	var planar := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * current_speed, ACCELERATION * delta)
	velocity = Vector3(planar.x, 0.0 if is_on_floor() else velocity.y - 9.8 * delta, planar.z)
	move_and_slide()
	if planar.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-planar.x, -planar.z), minf(delta * 6.0, 1.0))

	# Arrivato al muro scelto, o fermato da una cella Raised qualunque: la smonta.
	if has_wall and _planar(_cell_center(_wall_target) - global_position).length() <= BODY_RADIUS + grid.cell_size_m() * 0.5 + 0.4:
		_start_demolition(_wall_target)
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider() as Node
		if collider == null or collider.get_parent() != grid:
			continue
		var cell := grid.cell_at(collision.get_position() - collision.get_normal() * 0.3)
		if grid.state.is_valid(cell) and grid.state.get_state(cell) == TerrainState.CellState.RAISED:
			_start_demolition(cell)
			return


func _start_demolition(cell: Vector2i) -> void:
	demolish_cell = cell
	_demolish_left = demolish_seconds
	velocity = Vector3.ZERO
	print("PROTOTYPE01_BOSS_DEMOLISH_START X=%d Y=%d" % [cell.x, cell.y])


func _tick_demolition(delta: float) -> void:
	# Il giocatore l'ha scavata prima di lui: niente rottame per il boss.
	if grid.state.get_state(demolish_cell) != TerrainState.CellState.RAISED:
		demolish_cell = Vector2i(-1, -1)
		_blade.position.y = -0.6
		return
	_demolish_left -= delta
	# La lama martella: telegraph del colpo.
	_blade.position.y = -0.6 + absf(sin(_demolish_left * 14.0)) * 0.35
	var facing := _planar(_cell_center(demolish_cell) - global_position)
	if facing.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(delta * 8.0, 1.0))
	if _demolish_left > 0.0:
		return
	var cell := demolish_cell
	var was_barricade := barricades.has(cell)
	demolish_cell = Vector2i(-1, -1)
	_blade.position.y = -0.6
	grid.force_cell_state(cell, TerrainState.CellState.NORMAL)
	if was_barricade:
		return
	walls_demolished += 1
	_pending_scrap += 1
	print("PROTOTYPE01_BOSS_WALL_DEMOLISHED X=%d Y=%d total=%d" % [cell.x, cell.y, walls_demolished])
	wall_demolished.emit(cell)
	if _pending_scrap >= walls_per_barricade and barricades.size() < max_barricades and _build_barricade():
		_pending_scrap -= walls_per_barricade


## Terrapieno del giocatore piu vicino entro il raggio di attrazione, (-1,-1) se nessuno.
func _nearest_wall() -> Vector2i:
	var own := grid.cell_at(global_position)
	var reach := int(ceil(wall_attraction_radius / grid.cell_size_m()))
	var best := Vector2i(-1, -1)
	var best_distance := wall_attraction_radius
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := own + Vector2i(dx, dy)
			if not grid.state.is_valid(cell) or barricades.has(cell):
				continue
			if grid.state.get_state(cell) != TerrainState.CellState.RAISED:
				continue
			var distance := _planar(_cell_center(cell) - global_position).length()
			if distance < best_distance:
				best_distance = distance
				best = cell
	return best


## Barricata a due celle dal boss verso il giocatore (o accanto, se li non si puo).
## Mai sopra giocatore, compagno, nemici o il boss stesso.
func _build_barricade() -> bool:
	var to_player := _planar(player.global_position - global_position)
	if to_player.length() < 0.1:
		return false
	var forward := to_player.normalized()
	var side := Vector3(-forward.z, 0.0, forward.x)
	var step := grid.cell_size_m()
	for lateral in [0.0, 1.0, -1.0, 2.0, -2.0]:
		var point: Vector3 = global_position + forward * step * 2.0 + side * step * lateral
		var cell := grid.cell_at(point)
		if not grid.state.is_valid(cell) or grid.state.get_state(cell) != TerrainState.CellState.NORMAL:
			continue
		var center := _cell_center(cell)
		if not grid.can_apply_at(center, TerrainState.ToolMode.RAISE, player):
			continue
		if _planar(center - player.global_position).length() < step:
			continue
		if companion != null and _planar(center - companion.global_position).length() < step:
			continue
		if _planar(center - global_position).length() < BODY_RADIUS + step * 0.75:
			continue
		if director != null and director.enemies_near(center, step * 0.75).any(func(e: Enemy) -> bool: return e != self):
			continue
		barricades[cell] = true
		grid.set_raised_tint(cell, BARRICADE_COLOR)
		grid.force_cell_state(cell, TerrainState.CellState.RAISED)
		print("PROTOTYPE01_BOSS_BARRICADE X=%d Y=%d standing=%d" % [cell.x, cell.y, barricades.size()])
		barricade_built.emit(cell)
		return true
	return false


## Una barricata scavata dal giocatore (o smontata) crolla: non e piu sua.
func _on_cell_changed(cell: Vector2i, cell_state: TerrainState.CellState) -> void:
	if barricades.has(cell) and cell_state != TerrainState.CellState.RAISED:
		barricades.erase(cell)
		grid.clear_raised_tint(cell)
		print("PROTOTYPE01_BOSS_BARRICADE_DOWN X=%d Y=%d standing=%d" % [cell.x, cell.y, barricades.size()])


func _cell_center(cell: Vector2i) -> Vector3:
	var p := grid.to_global(grid.cell_local_position(cell, TerrainState.CellState.NORMAL))
	return Vector3(p.x, 0.0, p.z)


static func _planar(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
