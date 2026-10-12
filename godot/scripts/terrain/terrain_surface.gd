class_name TerrainSurface
extends RefCounted
## Resa del rilievo continuo (spec 6.2, D-082): cinque strati dalle tile dipinte (impacchettate
## da `tests/tools/pack_terrain_tiles.gd`), shader di Terrain3D con il blocco "Rilievo"
## (tinte di alzato e scavato dal delta rispetto alla base, fango nelle conche) e scelta
## dello strato dal control map (`TerrainField.paint_layer`). Solo con finestra: in
## headless Terrain3D non c'e e nessuno chiama queste funzioni.

const LAYERS: Array[String] = ["dirt", "slabs", "asphalt", "dug_soil", "mud"]
const LAYER_DIRT := 0
const LAYER_SLABS := 1
const LAYER_ASPHALT := 2
const LAYER_DUG_SOIL := 3
const LAYER_MUD := 4
const TEXTURE_DIR := "res://assets/textures/terrain/"
const SHADER := preload("res://resources/materials/terrain_relief.gdshader")
const RAISED_TINT := Color(0.62, 0.42, 0.24)
const DUG_TINT := Color(0.30, 0.20, 0.12)
const MUD_LEVEL := -0.6


## Strati, materiale e shader del rilievo.
static func apply(terrain: Terrain3D) -> void:
	var assets := Terrain3DAssets.new()
	for i in LAYERS.size():
		var asset := Terrain3DTextureAsset.new()
		asset.name = LAYERS[i]
		asset.albedo_texture = load(TEXTURE_DIR + "%s_albedo_height.png" % LAYERS[i])
		asset.normal_texture = load(TEXTURE_DIR + "%s_normal_rough.png" % LAYERS[i])
		asset.uv_scale = 0.12
		asset.detiling_rotation = 0.15
		assets.set_texture(i, asset)
	terrain.assets = assets
	var material: Terrain3DMaterial = terrain.material
	material.world_background = Terrain3DMaterial.NONE
	material.auto_shader = false
	material.shader_override = SHADER
	material.shader_override_enabled = true
	set_raised_tint(terrain, RAISED_TINT)
	material.set_shader_param("dug_tint", _rgb(DUG_TINT))
	material.set_shader_param("mud_level", MUD_LEVEL)


## Tinta degli argini alzati dal giocatore (spiked_wall la cambia in metallo chiaro).
static func set_raised_tint(terrain: Terrain3D, color: Color) -> void:
	terrain.material.set_shader_param("raised_tint", _rgb(color))


## La base del livello come texture R32F (stessa risoluzione del campo): lo shader ne
## ricava il delta per le tinte di alzato e scavato.
static func update_base(terrain: Terrain3D, base: PackedFloat32Array, resolution: int, half: float) -> void:
	var image := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, base.to_byte_array())
	terrain.material.set_shader_param("base_map", ImageTexture.create_from_image(image))
	terrain.material.set_shader_param("base_half", half)


static func _rgb(color: Color) -> Vector3:
	return Vector3(color.r, color.g, color.b)
