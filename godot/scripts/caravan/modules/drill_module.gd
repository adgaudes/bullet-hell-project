class_name DrillModule
extends MachineModule
## Trivella (spec D-093, Sezione 1): ogni `drill_interval` secondi (diviso per la forza della
## macchina, scelta 4 del piano B), se una vena con rottami tocca il cerchio di `drill_reach`
## attorno alla macchina, ne estrae un rottame e lo posa a terra sul bordo della vena verso la
## macchina (accanto alla macchina se li non si passa), senza scrivere il terreno. Altrimenti
## scava una buca (`DigCharge.dig_crater`) a 1 m dal nemico vivo piu vicino entro `drill_reach`,
## verso la macchina: solo su suolo entro `drill_flat_tolerance` dalla base e in un punto libero
## (`clear_spot`).

## Distanza della buca dal nemico, verso la macchina.
const HOLE_GAP_M := 1.0
## Il rottame della vena cade oltre il bordo di tanto, verso la macchina...
const DROP_OUTSIDE_M := 0.4
## ...o, se li non si passa, a tanto dalla macchina verso la vena.
const DROP_BESIDE_M := 0.6

## Secondi al prossimo colpo di trivella; a 0 lavora al primo passo.
var _drill_left := 0.0


func tick(delta: float) -> void:
	_drill_left -= delta
	if _drill_left > TIMER_EPSILON:
		return
	_drill_left = interval()
	if terrain_field == null:
		return
	if not _drill_vein():
		_drill_hole()


## Secondi fra due colpi: `drill_interval` diviso per la forza.
func interval() -> float:
	return caravan.tuning.drill_interval / power


## Vero se una vena con rottami tocca il raggio: ne cede uno, a terra, e il terreno resta com'e.
func _drill_vein() -> bool:
	if scrap_field == null:
		return false
	var reach := caravan.tuning.drill_reach
	var here := machine.global_position
	var vein := scrap_field.vein_touching(here, reach)
	if vein.is_empty():
		return false
	var center: Vector3 = vein.center
	var away := Vector3(here.x - center.x, 0.0, here.z - center.z)
	away = away.normalized() if away.length() >= 0.01 else Vector3.BACK
	var drop := Vector3(center.x, 0.0, center.z) + away * (float(vein.radius) + DROP_OUTSIDE_M)
	if not caravan.is_open_point(drop):
		drop = Vector3(here.x, 0.0, here.z) - away * DROP_BESIDE_M
	if not scrap_field.take_from_vein(here, reach, drop):
		return false
	_dust(center, float(vein.radius))
	print("PROTOTYPE01_DRILL_HOLE x=%.1f z=%.1f vein=%d" % [center.x, center.z, 1])
	return true


## Buca a `HOLE_GAP_M` dal nemico vivo piu vicino, verso la macchina, se il punto e quasi alla
## base e libero.
func _drill_hole() -> void:
	if write_queue == null:
		return
	var tuning := caravan.tuning
	var enemy := nearest_enemy(tuning.drill_reach)
	if enemy == null:
		return
	var spot: Variant = point_toward(enemy.global_position, machine.global_position, HOLE_GAP_M)
	if spot == null:
		return
	var point: Vector3 = spot
	if absf(terrain_field.height_at(point) - terrain_field.base_height_at(point)) > tuning.drill_flat_tolerance:
		return
	if not clear_spot(point, tuning.drill_radius):
		return
	DigCharge.dig_crater(write_queue, terrain_field, point, tuning.drill_radius, tuning.drill_depth)
	_dust(point, tuning.drill_radius)
	print("PROTOTYPE01_DRILL_HOLE x=%.1f z=%.1f vein=%d" % [point.x, point.z, 0])


func _dust(at: Vector3, radius: float) -> void:
	WeaponFx.dust(fx_parent(), Vector3(at.x, terrain_field.height_at(at), at.z), WeaponFx.EARTH, radius, 8, 0.0, true)


## Punta d'acciaio verso il basso su un braccio scuro, sul muso del pianale.
func build_part() -> Node3D:
	var part := Node3D.new()
	part.position = Vector3(0.0, 0.5, -0.3)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.14, 0.14, 0.15)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.7, 0.72, 0.75)
	steel.metallic = 0.6
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.14, 0.14, 0.4)
	arm.mesh = arm_mesh
	arm.material_override = dark
	part.add_child(arm)
	var motor := MeshInstance3D.new()
	var motor_mesh := CylinderMesh.new()
	motor_mesh.top_radius = 0.1
	motor_mesh.bottom_radius = 0.1
	motor_mesh.height = 0.2
	motor.mesh = motor_mesh
	motor.material_override = dark
	motor.position = Vector3(0.0, 0.0, -0.22)
	part.add_child(motor)
	var bit := MeshInstance3D.new()
	var bit_mesh := CylinderMesh.new()
	bit_mesh.top_radius = 0.07
	bit_mesh.bottom_radius = 0.0
	bit_mesh.height = 0.36
	bit.mesh = bit_mesh
	bit.material_override = steel
	bit.position = Vector3(0.0, -0.28, -0.22)
	part.add_child(bit)
	return part
