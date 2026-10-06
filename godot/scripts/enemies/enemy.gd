class_name Enemy
extends CharacterBody3D
## "Rottamatore": nemico base dell'orda lenta (D-038). Costruito e guidato da
## EnemyDirector, che calcola la velocita di tutti in un solo passo; qui restano
## stato, aspetto e danni. Collide solo col mondo statico: le celle Raised lo
## fermano, gli altri nemici no (li separa lo sterzo del direttore).

signal died(enemy: Enemy)
## Arrivato al punto della commissione; emesso a ogni passo finche resta li.
signal errand_reached(enemy: Enemy)

const HEIGHT := 1.0
const RADIUS := 0.32
const FLASH_SECONDS := 0.08
const CARGO_SIZE := 0.36

var health := 2
var max_health := 2
var is_dead := false
## Ricarica del danno da terrapieno spinato.
var spike_cooldown := 0.0
## Si guida da solo con drive() (boss): l'EnemyDirector non lo sterza ne lo riporta sull'anello.
var self_driven := false
## Raggio in piu rispetto a un rottamatore, per i colpi (corpi grandi).
var hit_radius_bonus := 0.0
## Commissione (D-045): il direttore lo porta a `errand_point` invece che dal giocatore.
var has_errand := false
var errand_point := Vector3.ZERO
## Porta un rottame sulla schiena (visibile): se muore lo lascia cadere.
var carrying_scrap := false
var _cargo: MeshInstance3D
var _flash_left := 0.0
var _body: MeshInstance3D
var _base_material: Material
var _flash_material: Material


## Mesh e materiali condivisi da tutta l'orda. Il modello (`scavenger`) ha una sola
## superficie: scafo, visiera luminosa e chele sono colori di vertice.
func setup(hp: int, body_mesh: Mesh, base_material: Material, flash_material: Material) -> void:
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
	# Origine del modello a terra, quella del nemico al centro della capsula.
	_body.position.y = -HEIGHT * 0.5
	add_child(_body)


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


func set_errand(point: Vector3) -> void:
	has_errand = true
	errand_point = point


func clear_errand() -> void:
	has_errand = false


func set_carrying(value: bool) -> void:
	carrying_scrap = value
	if value and _cargo == null:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * CARGO_SIZE
		var material := StandardMaterial3D.new()
		material.albedo_color = ScrapField.SCRAP_COLOR.linear_to_srgb()
		_cargo = MeshInstance3D.new()
		_cargo.mesh = mesh
		_cargo.material_override = material
		# Sul portapacchi del modello (0,66 m da terra).
		_cargo.position = Vector3(0.0, 0.35, 0.06)
		add_child(_cargo)
	if _cargo != null:
		_cargo.visible = value


## Passo fisico dei nemici `self_driven`; gli altri li muove il direttore.
func drive(_delta: float) -> void:
	pass


func tick_visuals(delta: float) -> void:
	spike_cooldown = maxf(spike_cooldown - delta, 0.0)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_body.material_override = _base_material


## Corpo sopra il pavimento: l'origine e al centro della capsula.
static func spawn_height() -> float:
	return HEIGHT * 0.5 + 0.02
