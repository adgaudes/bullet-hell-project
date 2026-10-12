extends SceneTree
## Cuoce il rilievo di base del quartiere (D-085) in `levels/district/base.bin`: apre
## `arena_run.tscn`, toglie le aree protette, ricalcola `RuinsDistrict.apply_base_relief`
## e salva con `TerrainField.save_base`. Da rilanciare quando cambiano il seme del
## quartiere, il rumore o le rovine; il file e in LFS. Comando:
##   godot_console --headless --path godot --script res://tests/tools/bake_terrain_base.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")
const OUT := "res://levels/district/base.bin"


func _initialize() -> void:
	var scene: Node3D = RunScene.instantiate()
	root.add_child(scene)
	await physics_frame
	var district: RuinsDistrict = scene.get_node(^"District")
	var field: TerrainField = scene.get_node(^"TerrainField")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	# Il livello ha gia protetto rovine e cortile: la base si cuoce senza protezioni.
	field.set_protected(Vector3.ZERO, field.half_extent() * 2.0, false)
	district.apply_base_relief(field)
	var bytes := field.save_base(OUT, district.layout_seed)
	print("PROTOTYPE01_TERRAIN_BASE_BAKED path=%s bytes=%d" % [OUT, bytes])
	scene.queue_free()
	await physics_frame
	quit(0 if bytes > 0 else 1)
