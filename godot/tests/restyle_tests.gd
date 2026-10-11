extends SceneTree
## Restyling grafico (spec 2026-10-11): tile di superficie, texture negli shader, preset
## grafici, camera a tre distanze.
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/restyle_tests.gd

const SURFACE_DIR := "res://assets/textures/surfaces"
## Gruppo -> numero di strati, nell'ordine fissato dal piano (Task 2).
const SURFACE_LAYERS := {"ground": 6, "walls": 3, "plants": 2}
const COMPRESSED_FORMATS: Array[int] = [Image.FORMAT_DXT1, Image.FORMAT_DXT5, Image.FORMAT_BPTC_RGBA,
	Image.FORMAT_RGTC_RG, Image.FORMAT_DXT5_RA_AS_RG, Image.FORMAT_BPTC_RGBF, Image.FORMAT_ETC2_RGBA8]

const RunScene := preload("res://scenes/main/arena_run.tscn")

var _failures := 0
var _scene: Node


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_test_surface_tiles()
	await _test_terrain_textures()
	await _test_ruin_textures()
	await _frames(2)
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _test_surface_tiles() -> void:
	print("surface tiles")
	for group: String in SURFACE_LAYERS:
		for map in ["albedo", "normal", "orm"]:
			var path := "%s/%s_%s.png" % [SURFACE_DIR, group, map]
			var texture: Resource = load(path) if ResourceLoader.exists(path) else null
			# L'import produce una CompressedTexture2DArray, che deriva da TextureLayered
			# (non da Texture2DArray): si controlla il tipo di strati.
			var is_array := texture is TextureLayered and (texture as TextureLayered).get_layered_type() == TextureLayered.LAYERED_TYPE_2D_ARRAY
			_check(is_array, "%s e un array 2D di texture" % path)
			if not is_array:
				continue
			var array := texture as TextureLayered
			_check(array.get_layers() == SURFACE_LAYERS[group], "%s ha %d strati" % [path, SURFACE_LAYERS[group]])
			_check(array.get_width() == 2048 and array.get_height() == 2048, "%s e 2048x2048 per strato" % path)
			_check(array.get_format() in COMPRESSED_FORMATS, "%s e compressa in VRAM (formato %d)" % [path, array.get_format()])


func _test_terrain_textures() -> void:
	print("terrain textures")
	await _open_scene()
	var grid: TerrainGrid = _scene.get_node(^"TerrainGrid")
	var batch: MultiMeshInstance3D = grid.get_node(^"CellsFlat")
	var material := batch.material_override as ShaderMaterial
	for map in ["albedo", "normal", "orm"]:
		_check(material.get_shader_parameter("ground_%s" % map) is TextureLayered, "le celle hanno l'array ground_%s" % map)
	var tile_scale: Variant = material.get_shader_parameter(&"tile_scale")
	_check(tile_scale != null and tile_scale > 0.0, "le celle hanno la scala delle tile")
	var raised: MultiMeshInstance3D = grid.get_node(^"CellsRaised")
	_check(raised.material_override == material, "i terrapieni condividono il materiale delle celle")
	var ground := _scene.get_node(^"District").find_child("Ground", true, false)
	var ground_mesh: MeshInstance3D = ground.find_child("*", true, false) as MeshInstance3D if ground != null else null
	var ground_material := ground_mesh.material_override as ShaderMaterial if ground_mesh != null else null
	_check(ground_material != null and ground_material.get_shader_parameter(&"ground_albedo") is TextureLayered, "il suolo usa l'array ground_albedo")
	_check(ground_material != null and ground_material.get_shader_parameter(&"ground_orm") is TextureLayered, "il suolo usa l'array ground_orm")
	await _close_scene()


func _test_ruin_textures() -> void:
	print("ruin textures")
	await _open_scene()
	var district: Node3D = _scene.get_node(^"District")
	var block := district.find_child("Block0", true, false)
	_check(block != null, "esiste il guscio Block0")
	var pieces: Array[Node] = block.find_children("*", "MeshInstance3D", true, false) if block != null else []
	var piece: MeshInstance3D = pieces[0] as MeshInstance3D if pieces.size() > 0 else null
	var material := piece.material_override as ShaderMaterial if piece != null else null
	for map in ["albedo", "normal", "orm"]:
		_check(material != null and material.get_shader_parameter("walls_%s" % map) is TextureLayered, "i muri delle rovine usano l'array walls_%s" % map)
	_check(piece != null and piece.get_instance_shader_parameter(&"base_tint") != null, "base_tint per istanza ancora impostata sui pezzi")
	var crowns: MultiMeshInstance3D = district.find_child("RuinCrowns", true, false)
	var crown_material := crowns.material_override as ShaderMaterial if crowns != null else null
	_check(crown_material != null and crown_material.get_shader_parameter(&"batched") == true, "le corone restano batched")
	_check(crown_material != null and crown_material.get_shader_parameter(&"walls_albedo") is TextureLayered, "le corone usano l'array walls_albedo")
	await _close_scene()


func _open_scene() -> void:
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_scene.get_node(^"EnemyDirector").spawning = false
	await _frames(5)


func _close_scene() -> void:
	root.remove_child(_scene)
	_scene.queue_free()
	_scene = null
	await _frames(2)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
