extends SceneTree
## Catture delle armi dell'impianto (D-092, piano 1), non e una suite. Con finestra reale:
##   godot_console --path godot --resolution 1280x800 --fixed-fps 60 --quit-after 6000 --script res://tests/tools/capture_weapons.gd -- --out=../output/weapons
## Produce: burst (chiodatrice con Raffica sull'orda), incendiary (macchie di fuoco degli
## Incandescenti), stake_rising e stake_ring (anello del picchetto che sale e chiude l'orda,
## striscia del HUD in ricarica), branch_screen (scelta della trasformazione); kit comune
## (piano 2): blade, hammer, ram, dozer (Ruspa a dischi), mixer.

var _out := "../output/weapons"
var _run: ArenaRun
var _player: PlayerCharacter
var _director: EnemyDirector


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(_out))
	var scene: Node3D = preload("res://scenes/main/arena_run.tscn").instantiate()
	root.add_child(scene)
	_run = scene.get_node(^"Run")
	_player = scene.get_node(^"Player")
	_director = scene.get_node(^"EnemyDirector")
	var field: TerrainField = scene.get_node(^"TerrainField")
	_director.spawning = false
	# Nessun level-up durante le catture: il menu metterebbe in pausa.
	_run.progression.xp_first_level = 1000000
	await _frames(20)
	_run._start_protect_left = 0.0
	field.set_protected(Vector3.ZERO, field.tuning.start_protected_radius_m, false)
	_player.global_position = Vector3(0.0, field.height_at(Vector3.ZERO) + 0.88, 0.0)
	_player.velocity = Vector3.ZERO
	var loadout := _run.loadout

	loadout.level_up(&"nailgun")
	loadout.choose_branch(&"nailgun", &"a")
	_horde(Vector3(0.0, 0.0, -7.0), 8)
	await _frames(70)
	await _save("burst")

	loadout.level_up(&"nailgun")
	loadout.choose_branch(&"nailgun", &"b")
	_horde(Vector3(5.0, 0.0, -5.0), 8)
	await _frames(90)
	await _save("incendiary")

	# Picchetto: chiodatrice ferma, cosi si vede solo l'anello (i rottamatori poi lo rosicchiano).
	_director.clear_horde()
	loadout.weapon(&"nailgun").process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(int(2.5 * Engine.physics_ticks_per_second))
	_player.set_aim_mode(PlayerCharacter.AimMode.MANUAL)
	_player.rotation.y = 0.0
	_horde(Vector3(0.0, 0.0, -6.0), 6, 1.2)
	loadout.trigger_active(0)
	await _frames(int(0.75 * Engine.physics_ticks_per_second))
	await _save("stake_rising")
	await _frames(int(0.45 * Engine.physics_ticks_per_second))
	await _save("stake_ring")

	_run._pending_level_ups = 1
	loadout.level_up(&"seismic_stake")
	_run._on_upgrade_chosen(&"w:branch:seismic_stake")
	await _frames(30)
	await _save("branch_screen")
	await _common_kit(loadout)
	quit()


## Kit comune (piano 2): una cattura per arma, la chiodatrice resta ferma. Mira da controller:
## col mouse le attive andrebbero verso il cursore della finestra.
func _common_kit(loadout: WeaponLoadout) -> void:
	_player._set_aim_device(PlayerCharacter.AimDevice.GAMEPAD)
	# La schermata del bivio resta senza scelta: niente level-up in coda dopo.
	_run._pending_level_ups = 0
	_run.level_up_menu.close()
	_director.clear_horde()
	await _frames(int(2.5 * Engine.physics_ticks_per_second))
	loadout.add(&"site_blade")
	_horde(Vector3(0.0, 0.0, -8.0), 6, 1.5)
	await _frames(int(1.2 * Engine.physics_ticks_per_second))
	await _save("blade")
	_director.clear_horde()
	loadout.add(&"jackhammer")
	var hammer := loadout.weapon(&"jackhammer") as Jackhammer
	_horde(Vector3.ZERO, 8, 2.6)
	for i in 600:
		await physics_frame
		if hammer._ring_left > 0.0 and hammer._ring_left < 0.1:
			break
	await _save("hammer")
	_director.clear_horde()
	await _frames(60)
	loadout.add(&"ram")
	_player._set_aim_device(PlayerCharacter.AimDevice.GAMEPAD)
	_player.rotation.y = 0.0
	_horde(Vector3(0.0, 0.0, -5.0), 5, 1.0)
	loadout.trigger_active(1)
	await _frames(int(0.25 * Engine.physics_ticks_per_second))
	await _save("ram")
	await _frames(int(1.0 * Engine.physics_ticks_per_second))
	_director.clear_horde()
	for id in [&"site_blade", &"ram"]:
		while loadout.level_of(id) < WeaponCatalog.MAX_LEVEL:
			if loadout.needs_branch(id):
				loadout.choose_branch(id, &"b")
			else:
				loadout.level_up(id)
	loadout.fuse(&"site_blade")
	_horde(Vector3(4.0, 0.0, -7.0), 6, 1.5)
	await _frames(int(1.4 * Engine.physics_ticks_per_second))
	await _save("dozer")
	_director.clear_horde()
	await _frames(60)
	loadout.add(&"cement_mixer")
	_player._set_aim_device(PlayerCharacter.AimDevice.GAMEPAD)
	_player.rotation.y = 0.0
	_horde(Vector3(0.0, 0.0, -6.0), 6, 1.2)
	loadout.trigger_active(1)
	await _frames(int(1.0 * Engine.physics_ticks_per_second))
	await _save("mixer")


func _horde(center: Vector3, count: int, spread := 2.0) -> void:
	for i in count:
		var angle := TAU * i / count
		var enemy := _director.spawn_at(center + Vector3(cos(angle), 0.0, sin(angle)) * spread * (0.5 + 0.5 * (i % 2)))
		enemy.health = 30
		enemy.max_health = 30


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join(_out).path_join("%s.png" % name)
	var err := root.get_texture().get_image().save_png(path)
	print("CAPTURE %s err=%d" % [path, err])
