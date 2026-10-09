class_name ActorModel
extends RefCounted
## Modelli statici degli attori (D-037, tools/blender/build_actor_assets.py): un solo
## oggetto per .glb, colore nei vertici, materiali con nomi semantici (`detail`,
## `suit`, `stripe`) che qui si rimappano sui materiali del gioco.

const PAINT_SHADER := preload("res://resources/materials/actor_paint.gdshader")
const OUTLINE_SHADER := preload("res://resources/materials/actor_outline.gdshader")

static var _outline_material: ShaderMaterial


## La mesh dell'unico oggetto di un modello importato.
static func mesh_of(scene: PackedScene) -> Mesh:
	var model := scene.instantiate()
	var instance := mesh_instance_of(model)
	var mesh := instance.mesh if instance != null else null
	model.free()
	return mesh


static func mesh_instance_of(model: Node) -> MeshInstance3D:
	if model is MeshInstance3D:
		return model
	var found := model.find_children("*", "MeshInstance3D", true, false)
	return found[0] as MeshInstance3D if not found.is_empty() else null


## Materiale a colori di vertice. [param tint_linear] colora le facce "vernice".
static func paint_material(tint_linear := Color.WHITE, emission_energy := 2.0, roughness := 0.8) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PAINT_SHADER
	material.set_shader_parameter(&"tint", tint_linear.linear_to_srgb())
	material.set_shader_parameter(&"emission_energy", emission_energy)
	material.set_shader_parameter(&"roughness", roughness)
	material.next_pass = outline_material()
	return material


## Contorno scuro condiviso (D-070): seconda passata a facce interne, spinte lungo la
## normale; stacca gli attori dal suolo nella camera di gioco.
static func outline_material() -> ShaderMaterial:
	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = OUTLINE_SHADER
	return _outline_material


## Assegna a ogni superficie il materiale col suo nome semantico; le altre restano come sono.
static func apply_materials(instance: MeshInstance3D, materials: Dictionary[String, Material]) -> void:
	for surface in instance.mesh.get_surface_count():
		var source := instance.mesh.surface_get_material(surface)
		var semantic := source.resource_name if source != null else ""
		if materials.has(semantic):
			instance.set_surface_override_material(surface, materials[semantic])
