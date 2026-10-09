extends SceneTree
## Test delle correzioni di economia e ritmo (D-056): rottami solo dalle celle
## rialzate, rottami di recupero per livelli, carte ripetibili, rottamatori veloci,
## menu di level-up aperto a fine passo. Eseguire con:
##   godot_console --headless --path godot --fixed-fps 60 --script res://tests/economy_tests.gd

const RunScene := preload("res://scenes/main/arena_run.tscn")
const DIG := TerrainState.ToolMode.DIG
const RAISE := TerrainState.ToolMode.RAISE

var _failures := 0
var _scene: Node3D
var _run: ArenaRun
var _grid: TerrainGrid
var _player: PlayerCharacter
var _director: EnemyDirector
var _scrap: ScrapField
var _companion: Companion
var _menu: LevelUpMenu


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	_test_catalog_and_fillers()
	_scene = RunScene.instantiate()
	root.add_child(_scene)
	_run = _scene.get_node(^"Run")
	_grid = _scene.get_node(^"TerrainGrid")
	_player = _scene.get_node(^"Player")
	_director = _scene.get_node(^"EnemyDirector")
	_scrap = _scene.get_node(^"ScrapField")
	_companion = _scene.get_node(^"Companion")
	_menu = _scene.get_node(^"LevelUpMenu")
	_director.spawning = false
	await _frames(5)
	(_scene.get_node(^"PlayerWeapon") as Node).set_physics_process(false)
	_companion.set_physics_process(false)
	_test_scrap_sources()
	_test_recovery_scrap()
	await _test_filler_effects()
	await _test_runners()
	await _test_level_up_opens_at_step_end()
	# T-12: i nodi messi in coda con queue_free vanno liberati prima di uscire, o
	# il motore segnala istanze ObjectDB perse all'uscita.
	await _frames(2)
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


func _test_catalog_and_fillers() -> void:
	print("catalog and fillers")
	var cargo := {}
	var fillers := 0
	for upgrade in UpgradeCatalog.all():
		if upgrade.id == &"companion_cargo":
			cargo = upgrade
		if upgrade.get(&"filler", false):
			fillers += 1
	_check(cargo.rarity == UpgradeCatalog.Rarity.UNCOMMON and cargo.max_level == 2, "Cassone rinforzato: Non comune, due livelli")
	_check(fillers == 3, "tre carte ripetibili nel catalogo")
	var progression := RunProgression.new()
	progression.setup(7)
	var seen_filler := false
	for i in 60:
		for card in progression.roll_offer():
			seen_filler = seen_filler or card.get(&"filler", false)
	_check(not seen_filler, "finche ci sono upgrade veri le ripetibili non compaiono")
	for upgrade in UpgradeCatalog.all():
		if not upgrade.get(&"filler", false):
			progression.levels[upgrade.id] = upgrade.max_level
	_check(progression.eligible().is_empty(), "tutti gli upgrade veri al massimo")
	var offer := progression.roll_offer()
	_check(offer.size() == 3 and offer.all(func(c: Dictionary) -> bool: return c.get(&"filler", false)),
		"l'offerta resta di tre carte, tutte ripetibili")
	for i in 5:
		progression.choose(&"field_patch")
	_check(progression.roll_offer().size() == 3, "una ripetibile scelta cinque volte resta disponibile")
	# Con un solo upgrade vero rimasto: lui piu due ripetibili.
	progression.levels[&"boots"] = 0
	var mixed := progression.roll_offer()
	_check(mixed.size() == 3 and mixed.any(func(c: Dictionary) -> bool: return c.id == &"boots"),
		"l'ultimo upgrade vero rimasto e sempre nell'offerta")
	progression.has_companion = false
	_check(progression.fillers().all(func(c: Dictionary) -> bool: return c.requires != "companion"), "senza compagno niente Rottame di fortuna")


func _test_scrap_sources() -> void:
	print("scrap sources")
	_check(not _scrap.bare_ground_yields_scrap, "nel livello il terreno nudo non rende rottami")
	var before := _scrap.count()
	_check(_grid.apply_command_at(Vector3(0.0, 0.0, -4.8), DIG, _player) and _scrap.count() == before,
		"scavare un fossato nel terreno nudo: nessun rottame")
	# Un muro del cortile (anello a 4 celle dal centro): smontarlo rende un rottame.
	var wall := Vector3(2.4, 0.0, -9.6)
	_check(_grid.cell_state_at(wall) == TerrainState.CellState.RAISED, "c'e un muro del cortile")
	_check(_grid.apply_command_at(wall, DIG, _player) and _scrap.count() == before + 1, "smontare un muro rende un rottame")
	_check(_grid.apply_command_at(wall, DIG, _player) and _scrap.count() == before + 1, "scavare ancora li sotto non ne rende altri")
	_check(_grid.apply_command_at(Vector3(4.8, 0.0, 0.0), RAISE, _player)
		and _grid.apply_command_at(Vector3(4.8, 0.0, 0.0), DIG, _player) and _scrap.count() == before + 2,
		"un terrapieno tuo, smontato, rende il rottame che e costato")


func _test_recovery_scrap() -> void:
	print("recovery scrap")
	var tuning := _run.tuning
	_check(is_zero_approx(tuning.survival_scrap_seconds) and tuning.recovery_scrap_levels > 0.0, "reddito a tempo spento, reddito per livelli acceso")
	var base := _run.recovery_scrap()
	var elapsed := _run.elapsed
	_run.elapsed += 900.0
	_check(_run.recovery_scrap() == base, "quindici minuti fermi non rendono nulla")
	_run.elapsed = elapsed
	var level := _run.progression.level
	_run.progression.level = 1 + int(tuning.recovery_scrap_levels * 4)
	_check(_run.recovery_scrap() == 4, "quattro rottami dopo %d livelli" % (_run.progression.level - 1))
	_check(_run.scrap_out(false) == int(floor((_companion.carried + 4) * tuning.death_scrap_share)), "morendo si riducono come il cassone")
	_run.progression.level = level


func _test_filler_effects() -> void:
	print("filler effects")
	_player.set_max_health(5)
	_player._invulnerable_left = 0.0
	_player.take_damage(2)
	_run.apply_upgrade(&"field_patch", 1)
	_check(_player.health == 4, "Rattoppo al volo: un punto vita in piu (%d)" % _player.health)
	_player.heal(10)
	_check(_player.health == 5, "la cura non supera il massimo")
	var carried := _companion.carried
	var capacity := _companion.capacity
	_run.apply_upgrade(&"lucky_scrap", 1)
	_check(_companion.carried == mini(carried + 1, capacity) and _companion.capacity == capacity, "Rottame di fortuna: un rottame, stessa capienza")
	var near := _director.spawn_at(Vector3(4.0, 0.0, 3.0))
	var far := _director.spawn_at(Vector3(12.0, 0.0, 3.0))
	near.health = 5
	far.health = 5
	await _frames(2)
	_run.apply_upgrade(&"nail_jar", 1)
	_check(near.health == 3 and far.health == 5, "Barattolo di chiodi: 2 danni entro 7 m, niente oltre")
	for enemy: Enemy in [near, far]:
		_director.enemies.erase(enemy)
		enemy.queue_free()
	await _frames(2)


func _test_runners() -> void:
	print("runners")
	var tuning := _run.tuning
	_director.elapsed = 0.0
	_check(is_zero_approx(_director.current_runner_share()), "all'inizio nessun rottamatore veloce")
	_director.elapsed = tuning.runner_start_seconds + tuning.runner_ramp_seconds * 0.5
	_check(is_equal_approx(_director.current_runner_share(), tuning.runner_share_max * 0.5), "a meta rampa meta della quota")
	_director.elapsed = tuning.runner_start_seconds + tuning.runner_ramp_seconds * 3.0
	_check(is_equal_approx(_director.current_runner_share(), tuning.runner_share_max), "poi la quota resta al massimo (%.0f%%)" % (tuning.runner_share_max * 100.0))
	_player.global_position = Vector3(0.0, 0.88, 40.0)
	_player.velocity = Vector3.ZERO
	(_scene.get_node(^"PathField") as PathField).solve()
	var walker := _director.spawn_at(Vector3(-3.0, 0.0, 20.0))
	var runner := _director.spawn_at(Vector3(3.0, 0.0, 20.0), true)
	_check(runner.health == maxi(ceili(walker.health * tuning.runner_health_share), 1) and runner.health <= walker.health,
		"il veloce ha meno vita (%d contro %d)" % [runner.health, walker.health])
	_check(runner.paint_material() != walker.paint_material(), "e di un altro colore")
	await _frames(60)
	var walker_speed := Vector2(walker.velocity.x, walker.velocity.z).length()
	var runner_speed := Vector2(runner.velocity.x, runner.velocity.z).length()
	_check(absf(walker_speed - tuning.enemy_speed) < 0.3, "il rottamatore normale va a %.1f m/s" % walker_speed)
	_check(absf(runner_speed - tuning.runner_speed) < 0.4, "quello veloce a %.1f m/s" % runner_speed)
	_check(tuning.runner_speed < 6.0, "resta piu lento del giocatore in corsa (6 m/s)")
	for enemy: Enemy in [walker, runner]:
		_director.enemies.erase(enemy)
		enemy.queue_free()
	_player.global_position = Vector3(0.0, 0.88, 0.0)
	await _frames(2)


## Il menu (e la pausa) si aprono a fine passo, non dentro la raccolta dell'esperienza.
func _test_level_up_opens_at_step_end() -> void:
	print("level-up timing")
	var needed := _run.progression.xp_to_next() - _run.progression.xp
	_run._on_xp_collected(needed)
	_check(_run._pending_level_ups == 1 and not _menu.is_open and not paused, "esperienza raccolta: il gioco non si ferma a meta passo")
	await _frames(2)
	_check(_menu.is_open and paused, "al passo successivo il menu e aperto e il gioco fermo")
	_menu._set_enabled(true)
	_menu.press(0)
	await _frames(2)
	_check(not _menu.is_open and not paused and _run._pending_level_ups == 0, "scelta la carta il gioco riparte")
