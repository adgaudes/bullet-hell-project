extends SceneTree
## Test degli effetti sonori sintetizzati e del loro collegamento alla run.
## In headless il driver audio e fittizio: si contano le riproduzioni, non si
## ascolta nulla. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/audio_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")
const GameSettingsScript := preload("res://scripts/services/game_settings.gd")
const EXPECTED_IDS: Array[StringName] = [
	&"nail_shot", &"enemy_death", &"player_hurt", &"player_death", &"dash",
	&"terrain_dig", &"terrain_raise", &"tool_reject", &"xp_pickup",
	&"scrap_pickup", &"scrap_spend", &"level_up", &"upgrade_chosen",
	&"boss_warning", &"victory",
	&"boss_spawn", &"boss_demolish", &"boss_barricade", &"carrier_pickup",
]
const FREQUENT_IDS: Array[StringName] = [&"nail_shot", &"enemy_death", &"xp_pickup", &"scrap_pickup"]

var _failures := 0
var _scene: Node3D
var _audio: RunAudio
var _run: ArenaRun
var _grid: TerrainGrid
var _player: PlayerCharacter
var _companion: Companion
var _director: EnemyDirector
var _weapon: AutoWeapon
var _path: PathField
var _xp: XpField
var _menu: LevelUpMenu


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_test_library()
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_audio = _scene.get_node(^"RunAudio")
	_run = _scene.get_node(^"Run")
	_grid = _scene.get_node(^"TerrainGrid")
	_player = _scene.get_node(^"Player")
	_companion = _scene.get_node(^"Companion")
	_director = _scene.get_node(^"EnemyDirector")
	_weapon = _scene.get_node(^"PlayerWeapon")
	_path = _scene.get_node(^"PathField")
	_xp = _scene.get_node(^"XpField")
	_menu = _scene.get_node(^"LevelUpMenu")
	_director.spawning = false
	await _frames(5)
	# Dopo il _ready della scena, che riattiverebbe il passo fisico.
	_weapon.set_physics_process(false)
	_test_node_setup()
	await _test_rate_limit()
	_test_buses_and_volume()
	await _test_combat_events()
	await _test_player_events()
	await _test_terrain_events()
	await _test_scrap_events()
	await _test_level_up_events()
	await _test_boss_and_end_events()
	print("PROTOTYPE01_TESTS %s failures=%d" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _count(id: StringName) -> int:
	return _audio.play_count(id)


func _place_player(at: Vector3) -> void:
	_player.global_position = Vector3(at.x, 0.88, at.z)
	_player.velocity = Vector3.ZERO
	_player._invulnerable_left = 0.0
	_path.solve()


func _peak(stream: AudioStreamWAV) -> int:
	var peak := 0
	for i in stream.data.size() / 2:
		peak = maxi(peak, absi(stream.data.decode_s16(i * 2)))
	return peak


func _test_library() -> void:
	print("library")
	var streams := SfxLibrary.build_all()
	_check(streams.size() == EXPECTED_IDS.size(), "%d suoni nella libreria (%d)" % [EXPECTED_IDS.size(), streams.size()])
	for id in EXPECTED_IDS:
		var stream: AudioStreamWAV = streams.get(id)
		if stream == null:
			_check(false, "%s: stream mancante" % id)
			continue
		var seconds := SfxLibrary.duration_of(stream)
		var format_ok := stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo \
			and stream.mix_rate == SfxLibrary.MIX_RATE and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED
		var peak := _peak(stream)
		var tail := absi(stream.data.decode_s16(stream.data.size() - 2))
		_check(format_ok and seconds >= 0.03 and seconds <= 2.0 and peak > 12000 and peak <= 32767 and tail < 400,
			"%s: PCM 16 bit mono, %.2f s, picco %d, coda %d" % [id, seconds, peak, tail])
	for id in FREQUENT_IDS:
		_check(SfxLibrary.duration_of(streams[id]) <= 0.15, "%s e corto: suona spesso" % id)
	var again := SfxLibrary.build(&"nail_shot")
	_check(again != streams[&"nail_shot"] and again.data == streams[&"nail_shot"].data, "sintesi deterministica (rumore con seme fisso)")
	_check(SfxLibrary.build(&"enemy_death").data != again.data, "suoni diversi hanno dati diversi")
	_check(SfxLibrary.build(&"missing_sound") == null, "id sconosciuto: nessuno stream")


func _test_node_setup() -> void:
	print("node")
	_check(_audio.process_mode == Node.PROCESS_MODE_ALWAYS, "RunAudio lavora anche a gioco fermo")
	var has_all := true
	for id in EXPECTED_IDS:
		has_all = has_all and _audio.has_sound(id) and _audio.stream_for(id) != null
	_check(has_all and _audio.sound_ids().size() == EXPECTED_IDS.size(), "tutti gli id disponibili sul nodo")
	var players := 0
	var on_bus := true
	for child in _audio.get_children():
		var stream_player := child as AudioStreamPlayer
		if stream_player != null:
			players += 1
			on_bus = on_bus and stream_player.bus == &"SFX"
	_check(players == RunAudio.POOL_SIZE and on_bus, "%d player sul bus SFX" % players)
	var configured := true
	for id in EXPECTED_IDS:
		configured = configured and RunAudio.SOUND_SETTINGS.has(id)
	_check(configured, "ogni id ha volume, variazione e intervallo")
	_check(_audio.play_counts.is_empty(), "l'avvio della scena non suona nulla")


func _test_rate_limit() -> void:
	print("rate limit")
	_check(not _audio.play(&"missing_sound") and _count(&"missing_sound") == 0, "id sconosciuto: false, non contato")
	_check(_audio.play(&"nail_shot") and _count(&"nail_shot") == 1, "prima riproduzione accettata")
	_check(_audio.last_played == &"nail_shot", "last_played aggiornato")
	_check(not _audio.play(&"nail_shot") and _count(&"nail_shot") == 1, "ripetizione immediata scartata")
	_check(_audio.play(&"xp_pickup"), "il limite e per id: un altro suono passa")
	await _frames(8)
	_check(_audio.play(&"nail_shot", -3.0) and _count(&"nail_shot") == 2, "dopo l'intervallo minimo suona di nuovo")
	var accepted := 0
	for i in 70:
		if _audio.play(&"enemy_death"):
			accepted += 1
	_check(accepted == 1, "70 morti nello stesso frame: un solo suono (%d)" % accepted)
	await _frames(40)
	# Piu richieste dei player disponibili: nessun errore, si riusa il piu vecchio.
	var played := 0
	for id in EXPECTED_IDS:
		if _audio.play(id):
			played += 1
	_check(played == EXPECTED_IDS.size(), "tutti gli id riproducibili, compresi quelli del boss (%d)" % played)
	await _frames(40)


func _test_buses_and_volume() -> void:
	print("buses")
	var sfx := AudioServer.get_bus_index(&"SFX")
	var music := AudioServer.get_bus_index(&"Music")
	var master := AudioServer.get_bus_index(&"Master")
	_check(sfx > 0 and music > 0 and master == 0, "bus SFX e Music nel layout")
	if sfx < 0 or music < 0:
		return
	_check(AudioServer.get_bus_send(sfx) == &"Master" and AudioServer.get_bus_send(music) == &"Master", "entrambi inviano a Master")
	var settings := GameSettingsScript.new()
	_check(is_equal_approx(settings.master_volume, 1.0) and is_equal_approx(settings.sfx_volume, 0.8), "default: generale 100%, effetti 80%")
	settings.master_volume = 0.5
	settings.sfx_volume = 0.25
	settings.apply_audio()
	_check(absf(AudioServer.get_bus_volume_db(master) - linear_to_db(0.5)) < 0.01, "volume generale sul bus Master (%.2f dB)" % AudioServer.get_bus_volume_db(master))
	_check(absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(0.25)) < 0.01, "volume effetti sul bus SFX (%.2f dB)" % AudioServer.get_bus_volume_db(sfx))
	_check(not AudioServer.is_bus_mute(master) and not AudioServer.is_bus_mute(sfx), "bus attivi sopra zero")
	settings.sfx_volume = 0.0
	settings.apply_audio()
	_check(AudioServer.is_bus_mute(sfx) and not AudioServer.is_bus_mute(master), "a zero il bus SFX e muto")
	settings.free()
	var service: GameSettingsService = root.get_node(^"GameSettings")
	service.apply_audio()
	_check(not AudioServer.is_bus_mute(sfx) and absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(service.sfx_volume)) < 0.01,
		"il servizio ripristina i propri volumi")


func _test_combat_events() -> void:
	print("combat")
	_place_player(Vector3.ZERO)
	var enemy := _director.spawn_at(Vector3(4.0, 0.0, 0.0))
	_director.set_physics_process(false)
	var shots := _count(&"nail_shot")
	var fired := [0]
	_weapon.fired.connect(func(_n: int) -> void: fired[0] += 1)
	_weapon.set_physics_process(true)
	await _frames(45)
	_weapon.set_physics_process(false)
	_check(fired[0] > 0 and _count(&"nail_shot") == shots + fired[0], "ogni raffica della chiodatrice suona (%d)" % fired[0])
	var deaths := _count(&"enemy_death")
	var pickups := _count(&"xp_pickup")
	if is_instance_valid(enemy) and not enemy.is_dead:
		enemy.take_damage(enemy.health)
	else:
		enemy = _director.spawn_at(Vector3(3.0, 0.0, 0.0))
		enemy.take_damage(enemy.health)
	await _frames(2)
	_check(_count(&"enemy_death") > deaths, "nemico abbattuto: enemy_death")
	_xp.spawn(_player.global_position + Vector3(0.5, 0.0, 0.0), 1)
	await _frames(40)
	_check(_count(&"xp_pickup") > pickups, "frammento raccolto: xp_pickup")
	_director.set_physics_process(true)


func _test_player_events() -> void:
	print("player")
	if _menu.is_open:
		_menu.close()
	_place_player(Vector3.ZERO)
	var dashes := _count(&"dash")
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = &"dash"
		event.pressed = pressed
		Input.parse_input_event(event)
	await _frames(6)
	_check(_count(&"dash") == dashes + 1, "dash: un soffio")
	await _frames(30)
	var hurts := _count(&"player_hurt")
	_player._invulnerable_left = 0.0
	_player.take_damage(1)
	_check(_count(&"player_hurt") == hurts + 1, "colpo subito: player_hurt")
	_player.set_max_health(_run.tuning.player_max_health)
	_check(_count(&"player_hurt") == hurts + 1, "la cura non suona come un colpo")


func _test_terrain_events() -> void:
	print("terrain")
	_place_player(Vector3.ZERO)
	var digs := _count(&"terrain_dig")
	var raises := _count(&"terrain_raise")
	var dig_target := Vector3(4.8, 0.0, 4.8)
	_check(_grid.apply_command_at(dig_target, TerrainState.ToolMode.DIG, _player) and _count(&"terrain_dig") == digs + 1, "scavo: terrain_dig")
	_check(_grid.apply_command_at(Vector3(-4.8, 0.0, 4.8), TerrainState.ToolMode.RAISE, _player) and _count(&"terrain_raise") == raises + 1, "rialzo: terrain_raise")
	_check(_count(&"terrain_dig") == digs + 1, "il rialzo non suona come uno scavo")
	await _frames(12)
	# Lo strumento del giocatore su una cella gia scavata: rifiuto.
	var rejects := _count(&"tool_reject")
	_player.terrain_tool_mode = TerrainState.ToolMode.DIG
	_player.look_at(Vector3(dig_target.x, _player.global_position.y, dig_target.z))
	_player._update_terrain_target()
	_grid.force_cell_state(_grid.cell_at(_player.terrain_target), TerrainState.CellState.LOWERED)
	digs = _count(&"terrain_dig")
	_player._use_terrain_tool()
	_check(_count(&"tool_reject") == rejects + 1 and _count(&"terrain_dig") == digs, "comando rifiutato: tool_reject")
	await _frames(12)
	# Rialzo senza rottami: stesso suono.
	_grid.force_cell_state(_grid.cell_at(_player.terrain_target), TerrainState.CellState.LOWERED)
	_player.terrain_tool_mode = TerrainState.ToolMode.RAISE
	var carried := _companion.carried
	_companion.carried = 0
	_player._use_terrain_tool()
	_check(_count(&"tool_reject") == rejects + 2, "rialzo senza rottami: tool_reject")
	_companion.carried = carried
	_player.terrain_tool_mode = TerrainState.ToolMode.DIG
	await _frames(12)


func _test_scrap_events() -> void:
	print("scrap")
	var pickups := _count(&"scrap_pickup")
	var spends := _count(&"scrap_spend")
	_companion.carried = maxi(_companion.carried - 1, 0) + 1
	_audio._last_carried = _companion.carried - 1
	_companion._refresh_cargo()
	_check(_count(&"scrap_pickup") == pickups + 1 and _count(&"scrap_spend") == spends, "cassone che cresce: scrap_pickup")
	_companion.spend()
	_check(_count(&"scrap_spend") == spends + 1 and _count(&"scrap_pickup") == pickups + 1, "rottame speso: scrap_spend")
	_companion._refresh_cargo()
	_check(_count(&"scrap_spend") == spends + 1 and _count(&"scrap_pickup") == pickups + 1, "cassone invariato: silenzio")
	await _frames(12)


func _test_level_up_events() -> void:
	print("level up")
	_place_player(Vector3.ZERO)
	var level_ups := _count(&"level_up")
	var chosen := _count(&"upgrade_chosen")
	_xp.spawn(_player.global_position + Vector3(1.0, 0.0, 0.0), _run.progression.xp_to_next())
	await _frames(20)
	_check(_menu.is_open and paused, "menu aperto, gioco fermo")
	_check(_count(&"level_up") == level_ups + 1, "apertura del menu: level_up")
	# L'orologio del limite avanza anche in pausa.
	_check(not _audio.play(&"level_up"), "ripetizione immediata scartata anche in pausa")
	await _frames(30)
	_check(paused and _audio.play(&"level_up"), "in pausa il limite scade e il suono riparte")
	_menu.press(0)
	await _frames(2)
	_check(_count(&"upgrade_chosen") == chosen + 1, "carta scelta: upgrade_chosen")
	await _frames(10)
	if _menu.is_open:
		_menu.close()
	paused = false


func _test_boss_and_end_events() -> void:
	print("boss and end")
	_place_player(Vector3.ZERO)
	var warnings := _count(&"boss_warning")
	_run.boss_call_at = _run.elapsed + 0.05
	await _frames(6)
	_check(_run.boss_phase == ArenaRun.BossPhase.WARNING and _count(&"boss_warning") == warnings + 1, "boss annunciato: boss_warning")
	_run._boss_warning_left = 0.05
	await _frames(6)
	var boss := _run.boss
	_check(boss != null, "boss in campo")
	if boss == null:
		return
	var victories := _count(&"victory")
	var deaths := _count(&"player_death")
	boss.take_damage(boss.health)
	await _frames(2)
	_check(_run.is_over and paused, "livello completato, gioco fermo")
	_check(_count(&"victory") == victories + 1, "vittoria: victory, a gioco fermo")
	_check(_count(&"player_death") == deaths, "nessun suono di sconfitta sulla vittoria")
	# Il segnale died del giocatore basta: la run e gia chiusa.
	var hurts := _count(&"player_hurt")
	_player._invulnerable_left = 0.0
	_player.take_damage(_player.health)
	_check(_count(&"player_death") == deaths + 1, "giocatore abbattuto: player_death")
	_check(_count(&"player_hurt") == hurts, "il colpo mortale non suona anche come ferita")
	paused = false
