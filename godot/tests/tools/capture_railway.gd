extends SceneTree
## Catture del livello 2, la ferrovia (D-066), non e una suite. Con finestra reale:
##   godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 4000 --script res://tests/tools/capture_railway.gd -- --out=../output/railway
## Produce: warning (annuncio del treno con freccia), train (il convoglio che passa
## accanto al cortile di partenza), aftermath (la fascia spianata, vagone compreso).

var _out := "../output/railway"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(_out))
	var scene: Node3D = preload("res://scenes/main/railway_run.tscn").instantiate()
	root.add_child(scene)
	var run: ArenaRun = scene.get_node(^"Run")
	var train: TrainEvent = scene.get_node(^"TrainEvent")
	var player: PlayerCharacter = scene.get_node(^"Player")
	var director: EnemyDirector = scene.get_node(^"EnemyDirector")
	var district: RailwayDistrict = scene.get_node(^"District")
	director.spawning = false
	for i in 10:
		await physics_frame
	# Il giocatore accanto al vagone piu vicino alla partenza, fuori dalla fascia.
	var wagon_x := 40.0
	for f: Dictionary in district.terrain_features:
		if f.kind == &"wagon" and absf(f.center.x) < absf(wagon_x):
			wagon_x = f.center.x
	player.global_position = Vector3(wagon_x - 6.0, 0.88, 7.0)
	player.velocity = Vector3.ZERO
	for i in 6:
		director.spawn_at(Vector3(wagon_x + 6.0 + i * 2.0, 0.0, train.track_z))
	train.warning_seconds = 4.0
	train.next_at = run.elapsed + 4.5
	for i in 60:
		await physics_frame
	await _save("warning")
	while train.state != TrainEvent.State.PASSING:
		await physics_frame
	# Il muso del treno arriva all'altezza del giocatore.
	while absf(train.head_x() - player.global_position.x) > 4.0 and train.state == TrainEvent.State.PASSING:
		await physics_frame
	await _save("train")
	while train.state == TrainEvent.State.PASSING:
		await physics_frame
	for i in 30:
		await physics_frame
	await _save("aftermath")
	quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join(_out).path_join("%s.png" % name)
	var err := root.get_texture().get_image().save_png(path)
	print("CAPTURE %s err=%d" % [path, err])
