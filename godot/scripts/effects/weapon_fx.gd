class_name WeaponFx
extends RefCounted
## Effetti leggibili delle armi (piano 5 di D-092): schegge, onda a terra, polvere. Solo
## presentazione, niente stato di gioco; ogni nodo e nel gruppo `weapon_fx` e si libera da
## solo. Un tetto di nodi vivi protegge il Deck quando cinque armi sparano nell'orda: oltre
## il tetto l'effetto si salta (il colpo resta, si perde solo la decorazione).

const GROUP := &"weapon_fx"
const MAX_LIVE := 40
const EARTH := Color(0.36, 0.25, 0.14)
const DUST := Color(0.62, 0.53, 0.40)
const RUST := Color(0.55, 0.25, 0.10)
const SPARK := Color(1.0, 0.82, 0.35)
const LEAF := Color(0.25, 0.55, 0.12)
const CEMENT := Color(0.55, 0.55, 0.53)

static var _ring_mesh: TorusMesh
static var _dust_meshes: Dictionary[String, SphereMesh] = {}


static func _room(parent: Node) -> bool:
	return parent != null and parent.is_inside_tree() and parent.get_tree().get_node_count_in_group(GROUP) < MAX_LIVE


## Schegge che saltano (DebrisBurst) nel gruppo degli effetti delle armi.
static func burst(parent: Node, at: Vector3, color: Color, amount := 8, speed := 4.0, size := 0.1) -> Node:
	if not _room(parent):
		return null
	var node := DebrisBurst.spawn(parent, at, color, amount, speed, size)
	node.add_to_group(GROUP)
	return node


## Anello piatto che si allarga da 0,3 m a [param radius] e svanisce in [param seconds].
static func shockwave(parent: Node, at: Vector3, radius: float, color: Color, seconds := 0.45) -> Node:
	if not _room(parent):
		return null
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.82
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 40
		_ring_mesh.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.top_level = true
	ring.position = at + Vector3(0.0, 0.08, 0.0)
	ring.scale = Vector3(0.3, 1.0, 0.3)
	ring.add_to_group(GROUP)
	parent.add_child(ring)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, ^"scale", Vector3(radius, 1.0, radius), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(mat, ^"albedo_color:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)
	return ring


## Sbuffo di polvere morbida che sale piano (scavi, cemento, ruote, dischi).
static func dust(parent: Node, at: Vector3, color: Color, radius := 0.6, amount := 6) -> Node:
	if not _room(parent):
		return null
	var puff := CPUParticles3D.new()
	puff.mesh = _dust_mesh(color)
	puff.amount = amount
	puff.lifetime = 0.9
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = radius
	puff.direction = Vector3.UP
	puff.spread = 35.0
	puff.initial_velocity_min = 0.4
	puff.initial_velocity_max = 1.2
	puff.gravity = Vector3(0.0, 0.3, 0.0)
	puff.damping_min = 1.5
	puff.damping_max = 2.5
	puff.scale_amount_min = 0.7
	puff.scale_amount_max = 1.6
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.top_level = true
	puff.position = at + Vector3(0.0, 0.15, 0.0)
	puff.add_to_group(GROUP)
	parent.add_child(puff)
	puff.emitting = true
	puff.finished.connect(puff.queue_free)
	return puff


static func _dust_mesh(color: Color) -> SphereMesh:
	var key := color.to_html(true)
	var mesh: SphereMesh = _dust_meshes.get(key)
	if mesh == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color.linear_to_srgb(), 0.45)
		mesh = SphereMesh.new()
		mesh.radius = 0.22
		mesh.height = 0.44
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh.material = mat
		_dust_meshes[key] = mesh
	return mesh
