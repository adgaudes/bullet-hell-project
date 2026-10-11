extends SceneTree
## Restyling grafico (spec 2026-10-11): tile di superficie, texture negli shader, preset
## grafici, camera a tre distanze.
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/restyle_tests.gd

const SURFACE_DIR := "res://assets/textures/surfaces"
## Gruppo -> numero di strati, nell'ordine fissato dal piano (Task 2).
const SURFACE_LAYERS := {"ground": 5, "walls": 3, "plants": 2}
const COMPRESSED_FORMATS: Array[int] = [Image.FORMAT_DXT1, Image.FORMAT_DXT5, Image.FORMAT_BPTC_RGBA,
	Image.FORMAT_RGTC_RG, Image.FORMAT_DXT5_RA_AS_RG, Image.FORMAT_BPTC_RGBF, Image.FORMAT_ETC2_RGBA8]

var _failures := 0


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_test_surface_tiles()
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


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
