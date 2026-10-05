class_name Enemy
extends CharacterBody3D
## "Rottamatore": nemico base dell'orda lenta (D-038). Costruito e guidato da
## EnemyDirector, che calcola la velocita di tutti in un solo passo; qui restano
## stato, aspetto e danni. Collide solo col mondo statico: le celle Raised lo
## fermano, gli altri nemici no (li separa lo sterzo del direttore).

signal died(enemy: Enemy)

const HEIGHT := 1.0
const RADIUS := 0.32
const FLASH_SECONDS := 0.08

var health := 2
var max_health := 2
var is_dead := false
## Ricarica del danno da terrapieno spinato.
var spike_cooldown := 0.0
var _flash_left := 0.0
var _body: MeshInstance3D
var _base_material: Material
var _flash_material: Material


## [param meshes]: corpo e occhi condivisi; [param materials]: base, occhi, lampo.
func setup(hp: int, body_mesh: Mesh, eye_mesh: Mesh, base_material: Material,
		eye_material: Material, flash_material: Material) -> void:
	health = hp
	max_health = hp
	collision_layer = 16
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	_base_material = base_material
	_flash_material = flash_material
	_body = MeshInstance3D.new()
	_body.mesh = body_mesh
	_body.material_override = base_material
	_body.position.y = -0.15
	add_child(_body)
	var eyes := MeshInstance3D.new()
	eyes.mesh = eye_mesh
	eyes.material_override = eye_material
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eyes.position = Vector3(0.0, 0.0, -0.36)
	add_child(eyes)


## Restituisce true se il colpo lo uccide.
func take_damage(amount: int) -> bool:
	if is_dead:
		return false
	health -= amount
	_flash_left = FLASH_SECONDS
	_body.material_override = _flash_material
	if health <= 0:
		is_dead = true
		died.emit(self)
		return true
	return false


func tick_visuals(delta: float) -> void:
	spike_cooldown = maxf(spike_cooldown - delta, 0.0)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_body.material_override = _base_material


## Corpo sopra il pavimento: l'origine e al centro della capsula.
static func spawn_height() -> float:
	return HEIGHT * 0.5 + 0.02
