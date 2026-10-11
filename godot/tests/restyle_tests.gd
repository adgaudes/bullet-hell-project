extends SceneTree
## Restyling grafico (spec 2026-10-11): tile di superficie, texture negli shader, preset
## grafici, camera a tre distanze.
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/restyle_tests.gd

const SURFACE_DIR := "res://assets/textures/surfaces"
## Gruppo -> numero di strati, nell'ordine fissato dal piano (Task 2).
const SURFACE_LAYERS := {"ground": 6, "walls": 3, "plants": 2}
## Lato per gruppo: il suolo copre lo schermo, muri e piante no (VRAM).
const SURFACE_SIZES := {"ground": 2048, "walls": 1024, "plants": 1024}
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
	await _test_vegetation_and_props()
	await _test_sky_and_post()
	await _test_world_applies_preset()
	await _test_camera_distance()
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
			var side: int = SURFACE_SIZES[group]
			_check(array.get_width() == side and array.get_height() == side, "%s e %dx%d per strato" % [path, side, side])
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


func _test_vegetation_and_props() -> void:
	print("vegetation and props")
	await _open_scene()
	var district: Node3D = _scene.get_node(^"District")
	var tufts: MultiMeshInstance3D = district.find_child("GrassTufts", true, false)
	var grass_material := tufts.material_override as ShaderMaterial if tufts != null else null
	_check(grass_material != null and grass_material.get_shader_parameter(&"plants_albedo") is TextureLayered, "l'erba usa l'array plants_albedo")
	var bush := district.find_child("Bush", true, false)
	var cards: Array[Node] = bush.find_children("*", "MeshInstance3D", true, false) if bush != null else []
	var card: MeshInstance3D = cards[0] as MeshInstance3D if cards.size() > 0 else null
	var card_uv: Variant = card.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] if card != null else null
	_check(card != null and card_uv != null and (card_uv as PackedVector2Array).size() > 0, "i cespugli sono cartelle con UV")
	var bush_material := card.material_override as ShaderMaterial if card != null else null
	_check(bush_material != null and bush_material.get_shader_parameter(&"textured") == true and bush_material.get_shader_parameter(&"plants_albedo") is TextureLayered, "i cespugli usano le cartelle di foglie dipinte")
	var car := district.find_child("WreckedCar", true, false)
	var meshes: Array[Node] = car.find_children("*", "MeshInstance3D", true, false) if car != null else []
	var found_maps := false
	for node in meshes:
		var mi := node as MeshInstance3D
		for surface in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(surface) as ShaderMaterial
			if mat != null and mat.get_shader_parameter(&"has_maps") == true 					and mat.get_shader_parameter(&"normal_tex") != null and mat.get_shader_parameter(&"orm_tex") != null:
				found_maps = true
	_check(found_maps, "i prop cotti hanno normal e ORM nel materiale env_baked")
	var tree := district.find_child("Tree", true, false)
	var tree_meshes: Array[Node] = tree.find_children("*", "MeshInstance3D", true, false) if tree != null else []
	var leaves_textured := false
	for node in tree_meshes:
		var mi := node as MeshInstance3D
		for surface in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(surface) as ShaderMaterial
			if mat != null and mat.get_shader_parameter(&"textured") == true:
				leaves_textured = true
	_check(leaves_textured, "la chioma dell'albero usa le cartelle di foglie dipinte")
	await _close_scene()


func _test_sky_and_post() -> void:
	print("sky and post")
	await _open_scene()
	var env: Environment = (_scene.get_node(^"District/WorldEnvironment") as WorldEnvironment).environment
	var sky_material := env.sky.sky_material if env.sky != null else null
	_check(sky_material is ShaderMaterial, "il cielo e dipinto (ShaderMaterial)")
	_check(env.tonemap_mode == Environment.TONE_MAPPER_ACES, "tonemap ACES")
	_check(env.adjustment_enabled and env.adjustment_saturation >= 1.2, "saturazione alzata")
	_check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and env.ambient_light_color.b > env.ambient_light_color.r, "ambiente freddo: ombre blu-viola")
	var sun: DirectionalLight3D = _scene.get_node(^"District/SunLight")
	_check(sun.light_angular_distance > 0.0, "il sole ha un diametro angolare (ombre morbide)")
	var day_night: DayNightCycle = _scene.get_node(^"Run").day_night
	var day_top: Color = (sky_material as ShaderMaterial).get_shader_parameter(&"top_color") if sky_material is ShaderMaterial else Color.WHITE
	day_night.night_start_seconds = 1.0  # 0 spegnerebbe il ciclo
	day_night.dusk_seconds = 1.0
	day_night.advance(5.0)
	var night_top: Color = (sky_material as ShaderMaterial).get_shader_parameter(&"top_color") if sky_material is ShaderMaterial else Color.WHITE
	_check(night_top.v < day_top.v, "di notte il cielo dipinto si scurisce")
	var player := _scene.get_node(^"Player")
	var suit_rim := false
	for mi: MeshInstance3D in player.find_children("*", "MeshInstance3D", true, false):
		for surface in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(surface) as StandardMaterial3D
			if mat != null and mat.rim_enabled:
				suit_rim = true
	_check(suit_rim, "l'ingegnere ha la rim light nel materiale della tuta")
	await _close_scene()


func _test_world_applies_preset() -> void:
	print("world applies preset")
	var settings: GameSettingsService = root.get_node("GameSettings")
	settings.set_preset(GameSettingsService.Preset.MAX)
	await _open_scene()
	var env: Environment = (_scene.get_node(^"District/WorldEnvironment") as WorldEnvironment).environment
	_check(env.sdfgi_enabled and env.volumetric_fog_enabled, "l'arena nasce con il preset Massimo applicato")
	settings.set_preset(GameSettingsService.Preset.STEAM_DECK)
	await _frames(1)
	_check(not env.sdfgi_enabled and not env.volumetric_fog_enabled and env.ssao_enabled, "cambiare preset a scena aperta aggiorna l'ambiente")
	var district := _scene.get_node(^"District")
	var tufts: MultiMeshInstance3D = district.find_child("GrassTufts", true, false)
	var full_count := tufts.multimesh.instance_count
	await _close_scene()
	await _open_scene()
	district = _scene.get_node(^"District")
	tufts = district.find_child("GrassTufts", true, false)
	_check(tufts.multimesh.instance_count < full_count, "con densita media l'erba ha meno istanze (%d < %d)" % [tufts.multimesh.instance_count, full_count])
	settings.set_preset(GameSettingsService.Preset.HIGH)
	await _close_scene()


func _test_camera_distance() -> void:
	print("camera distance")
	await _open_scene()
	var director: EnemyDirector = _scene.get_node(^"EnemyDirector")
	var rig: IsometricCameraRig = _scene.get_node(^"CameraRig")
	_check(is_equal_approx(rig.current_arm_m(), 15.0), "parte a 15 m")
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_Y
	press.pressed = true
	Input.parse_input_event(press)
	var release := press.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)
	_check(rig.distance_index == 2, "Y passa al preset lontano")
	await _frames(45)
	_check(absf(rig.current_arm_m() - 20.0) < 0.2, "il braccio arriva a 20 m in meno di 0,75 s (%.2f)" % rig.current_arm_m())
	_check(director.ring_scale > 1.3 and director.ring_scale * director.tuning.spawn_ring_min >= 22.0, "l'anello di comparsa si allarga con la camera lontana (%.2f)" % director.ring_scale)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(640, 400)
	wheel.global_position = wheel.position
	Input.parse_input_event(wheel)
	await _frames(2)
	_check(rig.distance_index == 1, "la rotellina in su avvicina di un preset")
	var settings: GameSettingsService = root.get_node("GameSettings")
	_check(settings.camera_distance == 1, "la distanza si salva nelle impostazioni")
	settings.set_camera_distance(0)
	await _frames(2)
	_check(rig.distance_index == 0, "cambiare la distanza dalle impostazioni muove la camera")
	settings.set_camera_distance(1)
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
