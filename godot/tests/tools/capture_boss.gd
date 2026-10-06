extends SceneTree
## Catture del boss (D-043), non e una suite. Con finestra reale:
##   godot_console --path godot --resolution 1280x800 --fixed-fps 60 --script res://tests/tools/capture_boss.gd -- --out=../output/boss
## Produce: warning (annuncio con freccia), boss (Demolitore al cortile con barricata), victory.

var _out := "../output/boss"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(_out))
	var scene: Node3D = preload("res://scenes/main/arena_run.tscn").instantiate()
	root.add_child(scene)
	var run: ArenaRun = scene.get_node(^"Run")
	var player: PlayerCharacter = scene.get_node(^"Player")
	var director: EnemyDirector = scene.get_node(^"EnemyDirector")
	director.spawning = false
	for i in 10:
		await physics_frame
	run.call_boss()
	for i in 30:
		await physics_frame
	await _save("warning")
	run._boss_warning_left = 0.0
	while run.boss == null:
		await physics_frame
	var boss := run.boss
	boss.global_position = Vector3(4.8, Demolisher.boss_spawn_height(), -17.0)
	for i in 2400:
		player.set_max_health(5)
		player._invulnerable_left = 1.0
		await physics_frame
		if boss.barricades.size() >= 1 and boss.is_demolishing():
			break
	await _save("boss")
	boss.take_damage(boss.health)
	for i in 70:
		await process_frame
	await _save("victory")
	quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join(_out).path_join("%s.png" % name)
	var err := root.get_texture().get_image().save_png(path)
	print("CAPTURE %s err=%d" % [path, err])
