class_name ArenaRun
extends Node
## Regia del prototipo della promessa A (D-038, docs/PROMISE_A_PROTOTYPE_SPEC.md):
## collega nemici, arma, esperienza, level-up, vita e fine run, applica alla
## griglia la disposizione del terreno (cortili, depositi, trincee) prodotta
## dall'arena grande (D-042) e gli effetti degli upgrade.
## Chiude il livello col boss (D-043): chiamata a tempo, direzione annunciata,
## arrivo del Demolitore, vittoria alla sua morte.
## Seed: `-- --seed=N` sulla riga di comando, altrimenti casuale; sempre nel log.
## `-- --boss-at=N` anticipa la chiamata del boss a N secondi.

signal boss_called(direction: Vector3)
signal boss_spawned(boss: Enemy)
## Boss battuto e piazzola di estrazione chiamata (D-076).
signal extraction_called
signal level_completed
## Rilancio di DayNightCycle.phase_changed: HUD e audio non dipendono dal nodo del ciclo.
signal night_phase_changed(phase: DayNightCycle.Phase)

enum BossPhase { WAITING, WARNING, ACTIVE, EXTRACTION, DEFEATED }

## Indicatori a bordo schermo (D-044): oltre questa distanza un punto e fuori vista.
const MARKER_MIN_DISTANCE := 14.0
## Scala degli indicatori con la distanza della camera (D-078): la soglia "fuori vista"
## segue la finestra visibile come l'anello di comparsa.
var marker_scale := 1.0
const MARKER_MAX_DISTANCE := 130.0
## Quanti cortili e quanti depositi indicare, i piu vicini.
const MARKERS_PER_KIND := 2
const MARKER_COURTYARD_COLOR := Color(0.95, 0.85, 0.55)
const MARKER_DEPOSIT_COLOR := Color(0.95, 0.5, 0.15)
const MARKER_BOSS_COLOR := Color(1.0, 0.25, 0.15)
## Ogni quanto si ricontrolla quali punti di interesse hanno ancora celle Raised.
const MARKER_REFRESH_SECONDS := 1.0
const MAIN_MENU_SCENE := "res://scenes/main/main_menu.tscn"
## Raggio della carta ripetibile Barattolo di chiodi.

## Nome a schermo di ogni boss (annuncio e barra vita).
const BOSS_NAMES: Dictionary[StringName, String] = {&"demolisher": "IL DEMOLITORE", &"driller": "LA TRIVELLA"}
## Direzioni di arrivo annunciate: nome e verso nel mondo (nord = -Z = alto dello schermo).
## Rilievo di base cotto da `tests/tools/bake_terrain_base.gd` (LFS); se manca si ricalcola.
const BASE_RELIEF_PATH := "res://levels/district/base.bin"
const BOSS_DIRECTIONS := [
	["NORD", Vector3(0.0, 0.0, -1.0)], ["EST", Vector3(1.0, 0.0, 0.0)],
	["SUD", Vector3(0.0, 0.0, 1.0)], ["OVEST", Vector3(-1.0, 0.0, 0.0)],
]

@export var tuning: RunTuning
## Quale livello della campagna e questa scena (LevelCatalog, D-066).
@export var level_id: StringName = &"district"
## Arena grande con i punti di interesse del terreno; senza, si costruisce il solo
## cortile centrale di `tuning.wall_ring_radius`.
@export var district: RuinsDistrict
@export var player: PlayerCharacter
@export var companion: Companion
@export var grid: TerrainGrid
## Rilievo continuo del livello (D-085); con questo nodo la griglia non c'e piu.
@export var terrain_field: TerrainField
@export var director: EnemyDirector
@export var weapon: AutoWeapon
@export var xp_field: XpField
@export var hud: RunHud
@export var level_up_menu: LevelUpMenu
@export var game_over: GameOverPanel
## Officina fra i livelli (D-049); opzionale.
@export var workshop: WorkshopPanel
## Ciclo giorno/notte (D-058); senza nodo il livello resta diurno.
@export var day_night: DayNightCycle
## Lampioni (D-058, tappa 2); senza nodo il tool ha due modalita.
@export var lamp_field: LampField
## Treno della ferrovia (D-066, livello 2); senza nodo non passa nessun treno.
@export var train_event: TrainEvent
## Terremoto del quartiere (D-075), solo nel livello 1.
@export var quake_event: QuakeEvent
## Piazzola di estrazione (D-076): battuto il boss, il livello finisce solo con un 3x3
## piano tenuto; senza nodo (o con `extraction_enabled` spento) la vittoria e immediata.
@export var extraction_pad: ExtractionPad

var progression := RunProgression.new()
var elapsed := 0.0
var is_over := false
var run_seed := 0
var companion_weapon: AutoWeapon
## Luci logiche della notte: torcia del giocatore, faro del compagno (e lampioni, tappa 2).
var light_field := LightField.new()
var torch_light_id := 0
var beacon_light_id := 0
var torch_radius := 0.0
var beacon_radius := 0.0
var _torch: OmniLight3D
var _beacon: OmniLight3D
var _night_factor_applied := -1.0
var _day_second_shown := -1
var dig_blast_radius := 0.0
var boss_phase := BossPhase.WAITING
var boss: Enemy
var boss_direction := Vector3.ZERO
var boss_direction_name := ""
## Secondi di livello a cui il boss viene chiamato (tuning o riga di comando); 0 = mai.
var boss_call_at := 0.0
var _boss_warning_left := 0.0
var _boss_rng := RandomNumberGenerator.new()
var _pending_level_ups := 0
## Punti di interesse ancora da indicare: { center: Vector3, text: String, color: Color, kind: StringName }.
var _marker_targets: Array[Dictionary] = []
var _marker_refresh_left := 0.0
var _marker_step := 0
## Profilo permanente (autoload PlayerProfile); null se la scena gira senza.
var _profile: PlayerProfileService
var _death_scrap_share := 0.0
## Fotografia della griglia a inizio livello e conteggi del tool, per la mappa finale (D-052).
var _initial_terrain := PackedByteArray()
## Quote iniziali del rilievo continuo per la mappa di fine livello (Task 13: RunMap.snapshot_heights).
var _initial_heights := PackedFloat32Array()
## Secondi in cui il cortile di partenza resta non scolpibile.
var _start_protect_left := 0.0
## Mappa di fine run catturata alla vittoria, prima che l'orda e il boss siano liberati.
var _final_map: Image
var _start_position := Vector3.ZERO
var cells_dug := 0
var cells_raised := 0


func _ready() -> void:
	# Ultimo nel passo fisico, qualunque sia l'ordine dei fratelli: aprire la pausa
	# (level-up, game over) da qui non lascia nodi a meta passo (T-05).
	process_physics_priority = 100
	if tuning == null:
		tuning = RunTuning.new()
	run_seed = _seed_from_command_line()
	progression.setup(run_seed)
	progression.xp_first_level = tuning.xp_first_level
	progression.xp_growth = tuning.xp_growth
	progression.pity_level_ups = tuning.pity_level_ups
	progression.has_companion = companion != null
	director.rng.seed = run_seed + 1
	_boss_rng.seed = run_seed + 2
	_check_scale()
	_setup_night()
	_setup_train()
	_setup_quake()
	_setup_extraction()
	_setup_camera_distance()
	# La cella protetta (0,0) e un residuo della parita Unreal (smoke test): nel livello
	# nessuna cella e intoccabile (R-28).
	if grid != null:
		grid.set_protected_cell(Vector2i(-1, -1))
	boss_call_at = _boss_call_from_command_line(tuning.boss_call_seconds)

	player.invulnerability_seconds = tuning.player_invulnerability
	player.set_max_health(tuning.player_max_health)
	weapon.fire_interval = tuning.fire_interval
	weapon.weapon_range = tuning.weapon_range
	weapon.damage = tuning.weapon_damage
	weapon.projectile_speed = tuning.projectile_speed
	xp_field.player_radius = tuning.pickup_radius
	_death_scrap_share = tuning.death_scrap_share
	_apply_permanent_upgrades()
	_build_terrain_layout()
	if grid != null:
		_initial_terrain = RunMap.snapshot(grid.state)
	_start_position = player.global_position

	player.health_changed.connect(hud.set_health)
	player.died.connect(_on_player_died)
	director.enemy_killed.connect(_on_enemy_killed)
	xp_field.collected.connect(_on_xp_collected)
	level_up_menu.chosen.connect(_on_upgrade_chosen)
	game_over.restart_requested.connect(restart)
	game_over.menu_requested.connect(return_to_menu)
	game_over.next_level_requested.connect(start_next_level)
	if workshop != null:
		game_over.workshop_requested.connect(workshop.open)
		# Tornando dall'Officina il passo successivo e ripartire.
		workshop.closed.connect(game_over.focus_default.bind(false))
	if grid != null:
		grid.command_applied.connect(_on_terrain_command)
	hud.set_health(player.health, player.max_health)
	_refresh_xp()
	var title := LevelCatalog.title_of(level_id)
	if not title.is_empty():
		hud.show_notice("LIVELLO %d: %s" % [LevelCatalog.index_of(level_id) + 1, title.to_upper()], 4.0, RunHud.TITLE_COLOR)
	print("PROTOTYPE01_RUN_START seed=%d level=%s" % [run_seed, level_id])


func _physics_process(delta: float) -> void:
	if is_over:
		return
	elapsed += delta
	hud.set_time(elapsed)
	_tick_night()
	if train_event != null:
		train_event.advance(elapsed, delta)
	if quake_event != null:
		quake_event.advance(elapsed, delta)
	if extraction_pad != null:
		extraction_pad.advance(delta)
	_tick_boss(delta)
	_tick_start_protection(delta)
	_tick_markers(delta)
	_open_next_level_up()


# --- Indicatori a bordo schermo ----------------------------------------------------

func _tick_markers(delta: float) -> void:
	if district == null:
		return
	_marker_refresh_left -= delta
	if _marker_refresh_left <= 0.0:
		_marker_refresh_left = MARKER_REFRESH_SECONDS
		_refresh_marker_targets()
	# Un passo si e uno no (60 Hz): gli indicatori non hanno bisogno dei 120 Hz della fisica (R-22).
	_marker_step += 1
	if _marker_step % 2 == 0:
		hud.set_markers(current_markers())


## Un cortile o un deposito resta indicato finche il suo argine o cumulo sporge dalla
## base (rilievo continuo) o finche ha almeno una cella Raised (griglia): un deposito
## spianato del tutto sparisce dagli indicatori.
func _refresh_marker_targets() -> void:
	_marker_targets.clear()
	if terrain_field != null:
		for stroke: Dictionary in district.terrain_strokes:
			if stroke.height <= 0.0:
				continue
			var center := Vector3(stroke.center.x, 0.0, stroke.center.y)
			var is_deposit: bool = stroke.kind == &"deposit"
			if is_deposit and _scrap_field() != null:
				# Un deposito vale finche la sua vena ha rottami, anche se il cumulo e spianato.
				if _scrap_field().vein_scrap_left(center) <= 0:
					continue
			elif terrain_field.highest_bump(center, stroke.radius + 2.0, 0.8) == null:
				continue
			_add_marker_target(is_deposit, stroke.marker)
		return
	for feature: Dictionary in district.terrain_features:
		if feature.state != TerrainState.CellState.RAISED:
			continue
		var center_cell := grid.cell_at(Vector3(feature.center.x, 0.0, feature.center.y))
		var standing := false
		for offset: Vector2i in feature.offsets:
			if grid.state.get_state(center_cell + offset) == TerrainState.CellState.RAISED:
				standing = true
				break
		if not standing:
			continue
		# I vagoni sui binari (livello 2) sono depositi di rottami a tutti gli effetti.
		# Il baricentro vero del blocco (R-29): i depositi 2x2 non hanno una cella centrale.
		_add_marker_target(feature.kind == &"deposit" or feature.kind == &"wagon", feature.get("marker", feature.center))


func _scrap_field() -> ScrapField:
	return companion.scrap_field if companion != null else null


func _add_marker_target(is_deposit: bool, marker: Vector2) -> void:
	_marker_targets.append({
		center = Vector3(marker.x, 0.0, marker.y),
		kind = &"deposit" if is_deposit else &"courtyard",
		text = "ROTTAMI" if is_deposit else "CORTILE",
		color = MARKER_DEPOSIT_COLOR if is_deposit else MARKER_COURTYARD_COLOR,
	})


## I due cortili e i due depositi piu vicini fuori vista, piu il boss se e in campo.
func current_markers() -> Array[Dictionary]:
	var origin := player.global_position
	var by_kind := {&"courtyard": [], &"deposit": []}
	for target in _marker_targets:
		var offset: Vector3 = target.center - origin
		var distance := Vector2(offset.x, offset.z).length()
		if distance < marker_min_distance() or distance > MARKER_MAX_DISTANCE:
			continue
		by_kind[target.kind].append({
			direction = Vector2(offset.x, offset.z), distance = distance, color = target.color, text = target.text,
		})
	var markers: Array[Dictionary] = []
	for kind: StringName in by_kind:
		var list: Array = by_kind[kind]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
		for i in mini(MARKERS_PER_KIND, list.size()):
			markers.append(list[i])
	if boss_phase == BossPhase.ACTIVE and is_instance_valid(boss):
		var offset := boss.global_position - origin
		var distance := Vector2(offset.x, offset.z).length()
		if distance >= marker_min_distance():
			markers.append({direction = Vector2(offset.x, offset.z), distance = distance, color = MARKER_BOSS_COLOR, text = "BOSS"})
	return markers


# --- Boss di fine livello ----------------------------------------------------------

func _tick_boss(delta: float) -> void:
	match boss_phase:
		BossPhase.WAITING:
			if boss_call_at > 0.0 and elapsed >= boss_call_at:
				call_boss()
		BossPhase.WARNING:
			_boss_warning_left -= delta
			hud.set_boss_warning(boss_name(), boss_direction_name, boss_direction, _boss_warning_left)
			if _boss_warning_left <= 0.0:
				_spawn_boss()
		BossPhase.ACTIVE:
			if is_instance_valid(boss):
				hud.set_boss_health(boss.health, boss.max_health)


## Annuncia la direzione di arrivo: il giocatore ha il preavviso per preparare il terreno.
func call_boss() -> void:
	if boss_phase != BossPhase.WAITING:
		return
	# Solo direzioni in cui c'e spazio per arrivare da lontano (vicino ai bordi no).
	var limit := _play_half_extents() - Vector2(3.0, 3.0)
	var options: Array = []
	var path := director.path_field
	for entry: Array in BOSS_DIRECTIONS:
		var point: Vector3 = player.global_position + entry[1] * tuning.boss_spawn_distance
		if absf(point.x) > limit.x or absf(point.z) > limit.y:
			continue
		# E con un punto d'ingresso percorribile (T-01: non dentro una rovina).
		if path != null and path.is_ready() and _walkable_near(point, 9.0) == null:
			continue
		options.append(entry)
	if options.is_empty():
		options = BOSS_DIRECTIONS
	var chosen: Array = options[_boss_rng.randi_range(0, options.size() - 1)]
	boss_direction_name = chosen[0]
	boss_direction = chosen[1]
	boss_phase = BossPhase.WARNING
	_boss_warning_left = tuning.boss_warning_seconds
	hud.set_boss_warning(boss_name(), boss_direction_name, boss_direction, _boss_warning_left)
	print("PROTOTYPE01_BOSS_CALLED direction=%s time=%.1f" % [boss_direction_name, elapsed])
	boss_called.emit(boss_direction)


## Nome a schermo del boss di questo livello.
func boss_name() -> String:
	return BOSS_NAMES.get(tuning.boss_kind, "IL BOSS")


func _spawn_boss() -> void:
	boss_phase = BossPhase.ACTIVE
	hud.clear_boss_warning()
	hud.set_boss_name(boss_name())
	match tuning.boss_kind:
		&"driller":
			boss = _make_driller()
		_:
			boss = _make_demolisher()
	var point := _boss_spawn_point()
	director.add_enemy(boss, Vector3(point.x, boss.spawn_center_height(), point.z))
	boss.rotation.y = atan2(boss_direction.x, boss_direction.z)
	boss.died.connect(_on_boss_died)
	if train_event != null:
		train_event.boss = boss
	if quake_event != null:
		quake_event.boss = boss
	hud.set_boss_health(boss.health, boss.max_health)
	boss_spawned.emit(boss)
	print("PROTOTYPE01_BOSS_SPAWNED direction=%s x=%.1f z=%.1f health=%d" % [boss_direction_name, point.x, point.z, boss.health])


func _make_demolisher() -> Demolisher:
	var demolisher := Demolisher.new()
	demolisher.setup_demolisher(tuning.boss_health, director.flash_material())
	demolisher.player = player
	demolisher.grid = grid
	demolisher.path_field = director.path_field
	demolisher.director = director
	demolisher.companion = companion
	demolisher.speed = tuning.boss_speed
	demolisher.contact_damage = tuning.boss_contact_damage
	demolisher.contact_radius = tuning.boss_contact_radius
	demolisher.demolish_seconds = tuning.boss_demolish_seconds
	demolisher.wall_attraction_radius = tuning.boss_wall_attraction_radius
	demolisher.walls_per_barricade = tuning.boss_walls_per_barricade
	demolisher.max_barricades = tuning.boss_max_barricades
	demolisher.scrap_field = companion.scrap_field if companion != null else null
	demolisher.lamp_field = lamp_field
	demolisher.max_carriers = tuning.boss_max_carriers
	demolisher.carrier_scrap_radius = tuning.boss_carrier_scrap_radius
	demolisher.carrier_recruit_radius = tuning.boss_carrier_recruit_radius
	demolisher.carrier_timeout = tuning.boss_carrier_timeout
	return demolisher


func _make_driller() -> Driller:
	var driller := Driller.new()
	driller.setup_driller(tuning.driller_health, director.flash_material())
	driller.player = player
	driller.grid = grid
	driller.path_field = director.path_field
	driller.director = director
	driller.companion = companion
	driller.scrap_field = companion.scrap_field if companion != null else null
	driller.lamp_field = lamp_field
	driller.contact_damage = tuning.boss_contact_damage
	driller.contact_radius = tuning.boss_contact_radius
	driller.charge_speed = tuning.driller_charge_speed
	driller.charge_length = tuning.driller_charge_length
	driller.aim_seconds = tuning.driller_aim_seconds
	driller.rest_seconds = tuning.driller_rest_seconds
	driller.stun_seconds = tuning.driller_stun_seconds
	driller.stun_damage_multiplier = tuning.driller_stun_damage_multiplier
	return driller


## Punto di ingresso nella direzione annunciata: dentro l'arena e su terreno libero.
func _boss_spawn_point() -> Vector3:
	var path := director.path_field
	var side := Vector3(-boss_direction.z, 0.0, boss_direction.x)
	for lateral in [0.0, 3.0, -3.0, 6.0, -6.0, 9.0, -9.0]:
		for back in [0.0, -3.0, 3.0, -6.0]:
			var point: Vector3 = player.global_position + boss_direction * (tuning.boss_spawn_distance + back) + side * lateral
			point = _clamp_inside(point)
			if path == null or (path.is_walkable(point) and path.is_walkable(point + Vector3(1.0, 0.0, 1.0)) \
					and path.is_walkable(point - Vector3(1.0, 0.0, 1.0))):
				return point
	var fallback := _clamp_inside(player.global_position + boss_direction * tuning.boss_spawn_distance)
	# Ripiego verificato: la cella percorribile piu vicina a spirale (T-01).
	var near: Variant = _walkable_near(fallback, 24.0)
	return near if near != null else fallback


## Punto percorribile (dentro l'arena) piu vicino a [param origin] entro [param radius],
## cercato a spirale a passi di una cella del campo; null se non c'e.
func _walkable_near(origin: Vector3, radius: float) -> Variant:
	var path := director.path_field
	if path == null:
		return origin
	var step := path.cell_size
	var rings := int(ceil(radius / step))
	for ring in rings + 1:
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var point := _clamp_inside(origin + Vector3(dx * step, 0.0, dz * step))
				if path.is_walkable(point) and path.is_walkable(point + Vector3(1.0, 0.0, 1.0)) \
						and path.is_walkable(point - Vector3(1.0, 0.0, 1.0)):
					return point
	return null


## La scala e scritta in quattro posti (R-27): se non coincidono le feature del quartiere
## finirebbero su celle sbagliate in silenzio. Qui si grida all'avvio.
func _check_scale() -> void:
	if district != null and terrain_field != null \
			and (Vector2.ONE * terrain_field.half_extent() - district.half_extents()).length() > 0.5:
		push_error("Scala incoerente: rilievo %.1f m di semilato, distretto %s" % [terrain_field.half_extent(), district.half_extents()])
	if grid == null:
		return
	if district != null and not is_equal_approx(grid.cell_size_m(), RuinsDistrict.CELL):
		push_error("Scala incoerente: griglia %.2f m per cella, distretto %.2f" % [grid.cell_size_m(), RuinsDistrict.CELL])
	if director.path_field != null and district != null \
			and not Vector2(director.path_field.half_extent, director.path_field.half_z()).is_equal_approx(district.half_extents()):
		push_error("Scala incoerente: campo di percorso %.1f x %.1f m, distretto %s"
			% [director.path_field.half_extent, director.path_field.half_z(), district.half_extents()])
	# Assi Unreal della griglia: `width` corre lungo X Unreal (Z Godot), `height` lungo Y Unreal (X Godot).
	var grid_half := Vector2(grid.state.height, grid.state.width) * grid.cell_size_m() * 0.5
	if district != null and (grid_half - district.half_extents()).length() > grid.cell_size_m():
		push_error("Scala incoerente: griglia %s m di semilato, distretto %s" % [grid_half, district.half_extents()])


## Mezzi lati dell'area giocabile (X, Z).
func _play_half_extents() -> Vector2:
	if district != null:
		return district.half_extents()
	if director.path_field != null:
		return Vector2(director.path_field.half_extent, director.path_field.half_z())
	return Vector2(24.0, 24.0)


## Il punto riportato dentro l'arena, a 3 m dal bordo, a quota zero.
func _clamp_inside(point: Vector3) -> Vector3:
	var limit := _play_half_extents() - Vector2(3.0, 3.0)
	return Vector3(clampf(point.x, -limit.x, limit.x), 0.0, clampf(point.z, -limit.y, limit.y))


## Rottami di recupero: per i livelli guadagnati (`recovery_scrap_levels`) e, se
## accesa, per il tempo di livello (`survival_scrap_seconds`).
func recovery_scrap() -> int:
	var total := 0
	if tuning.recovery_scrap_levels > 0.0:
		total += int((progression.level - 1) / tuning.recovery_scrap_levels)
	if tuning.survival_scrap_seconds > 0.0:
		total += int(elapsed / tuning.survival_scrap_seconds)
	return total


## Rottami che escono dal livello: quelli nel cassone e quelli di recupero, piu il
## premio del boss se battuto.
func scrap_out(victory: bool) -> int:
	var carried := (companion.carried if companion != null else 0) + recovery_scrap()
	if victory:
		return carried + tuning.boss_scrap_bonus
	return int(floor(carried * _death_scrap_share))


## Boss battuto: con la piazzola (D-076) il livello continua finche il giocatore non tiene
## un 3x3 piano; altrimenti vittoria subito (D-043).
func _on_boss_died(_enemy: Enemy) -> void:
	if extraction_pad != null and tuning.extraction_enabled and not is_over:
		boss_phase = BossPhase.EXTRACTION
		hud.clear_boss()
		extraction_pad.begin()
		extraction_called.emit()
		return
	_end_level(true)


func _on_extraction_completed() -> void:
	_end_level(true)


## Fine del livello, vittoria o morte (R-14): prima il conto e l'incasso nel profilo,
## poi log, mappa e pannello, cosi un errore nella parte cosmetica non salta l'incasso
## (F-04: la mappa viene dopo l'incasso ma prima di congedare l'orda, che le serve, T-08).
func _end_level(victory: bool) -> void:
	if is_over:
		return
	is_over = true
	director.spawning = false
	if level_up_menu.is_open:
		level_up_menu.close()
	var scrap := scrap_out(victory)
	var banked := _bank(scrap, victory)
	var save_failed := _profile != null and _profile.last_save_error != OK
	print("%s time=%.1f level=%d kills=%d scrap=%d seed=%d"
		% ["PROTOTYPE01_LEVEL_COMPLETE" if victory else "PROTOTYPE01_PLAYER_DIED", elapsed, progression.level, director.kills, scrap, run_seed])
	if victory:
		boss_phase = BossPhase.DEFEATED
		_final_map = build_run_map()
		director.clear_horde()
		hud.clear_boss()
		level_completed.emit()
	_show_run_map()
	var next := LevelCatalog.next_of(level_id)
	game_over.set_next_level(LevelCatalog.title_of(next) if victory and LevelCatalog.is_playable(next) else "")
	game_over.open(elapsed, progression.level, director.kills, victory, scrap, banked, save_failed)


# --- Profilo permanente e Officina (D-049) ------------------------------------------

## Upgrade permanenti comprati in Officina: valgono dall'inizio di ogni livello.
func _apply_permanent_upgrades() -> void:
	_profile = get_node_or_null(^"/root/PlayerProfile") as PlayerProfileService
	if _profile == null:
		return
	var applied: PackedStringArray = []
	for entry in PermanentCatalog.all():
		var id: StringName = entry.id
		var owned := _profile.level_of(id)
		if owned <= 0:
			continue
		applied.append("%s=%d" % [id, owned])
		match id:
			&"tool_reach":
				if grid != null:
					player.tool_range_bonus_cm = grid.cell_size_m() * 100.0 * owned
			&"base_health":
				player.set_max_health(tuning.player_max_health + owned)
			&"reflexes":
				player.invulnerability_seconds += 0.2 * owned
			&"cargo":
				if companion != null:
					companion.add_capacity(2 * owned)
			&"stock":
				if companion != null:
					companion.add_capacity(0, 2 * owned)
			&"fixed_turret":
				if companion != null:
					# Conta come primo livello della carta: al level-up si puo solo migliorare.
					apply_upgrade(&"companion_turret", progression.choose(&"companion_turret"))
			&"salvage":
				_death_scrap_share = maxf(_death_scrap_share, 0.75)
	if not applied.is_empty():
		print("PROTOTYPE01_PERMANENT_APPLIED %s" % ",".join(applied))


## Incassa i rottami nel profilo; restituisce il totale in Officina, -1 senza profilo.
func _bank(scrap: int, victory: bool) -> int:
	if _profile == null:
		return -1
	_profile.bank_run(scrap, victory, maxi(LevelCatalog.index_of(level_id), 0), level_id)
	return _profile.scrap


## Disposizione iniziale del terreno: i punti di interesse dell'arena grande,
## oppure il solo cortile centrale.
func _build_terrain_layout() -> void:
	if district == null:
		_build_courtyard_walls()
		return
	if terrain_field != null:
		_build_terrain_relief()
		return
	grid.plaza_radius = district.plaza_radius()
	var raised := 0
	var lowered := 0
	for feature: Dictionary in district.terrain_features:
		var center := grid.cell_at(Vector3(feature.center.x, 0.0, feature.center.y))
		var cells: Array[Vector2i] = []
		for offset: Vector2i in feature.offsets:
			cells.append(center + offset)
		grid.set_cell_states(cells, feature.state)
		if feature.has("tint"):
			for cell in cells:
				grid.set_raised_tint(cell, feature.tint)
		if feature.state == TerrainState.CellState.RAISED:
			raised += cells.size()
		else:
			lowered += cells.size()
	print("PROTOTYPE01_TERRAIN_LAYOUT_READY features=%d raised=%d lowered=%d"
		% [district.terrain_features.size(), raised, lowered])


## Rilievo continuo (D-085): base cotta (`BASE_RELIEF_PATH`) o ricalcolata dal quartiere,
## poi le pennellate dei punti di interesse; dischi protetti attorno alle rovine e, per i
## primi secondi, al cortile di partenza. Le quote iniziali per la mappa arrivano col Task 13.
func _build_terrain_relief() -> void:
	if not terrain_field.load_base(BASE_RELIEF_PATH):
		district.apply_base_relief(terrain_field)
	district.apply_strokes(terrain_field, _scrap_field())
	var margin: float = terrain_field.tuning.protected_radius_m
	for rect: Rect2 in district.block_rects():
		var center := rect.get_center()
		terrain_field.set_protected(Vector3(center.x, 0.0, center.y), rect.size.length() * 0.5 + margin, true)
	_start_protect_left = terrain_field.tuning.start_protected_seconds
	terrain_field.set_protected(Vector3.ZERO, terrain_field.tuning.start_protected_radius_m, true)
	print("PROTOTYPE01_TERRAIN_LAYOUT_READY strokes=%d" % district.terrain_strokes.size())


func _tick_start_protection(delta: float) -> void:
	if terrain_field == null or _start_protect_left <= 0.0:
		return
	_start_protect_left -= delta
	if _start_protect_left <= 0.0:
		terrain_field.set_protected(Vector3.ZERO, terrain_field.tuning.start_protected_radius_m, false)


## Mura del cortile: anello di celle Raised con un varco al centro di ogni lato.
func _build_courtyard_walls() -> void:
	var radius := tuning.wall_ring_radius
	if radius <= 0 or grid == null:
		return
	var center := Vector2i(grid.state.width / 2, grid.state.height / 2)
	var cells: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if maxi(absi(dx), absi(dy)) != radius or dx == 0 or dy == 0:
				continue
			cells.append(center + Vector2i(dx, dy))
	grid.set_cell_states(cells, TerrainState.CellState.RAISED)


## Con il velo il gioco resta fermo finche la scena nuova non e caricata (lo sblocca
## UiFx al cambio); senza velo si riparte subito.
func restart() -> void:
	var fx := get_node_or_null(^"/root/UiFx") as UiFxService
	if fx == null:
		get_tree().paused = false
		get_tree().reload_current_scene()
	else:
		fx.fade_reload()


func return_to_menu() -> void:
	var fx := get_node_or_null(^"/root/UiFx") as UiFxService
	if fx == null:
		get_tree().paused = false
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		fx.fade_to_scene(MAIN_MENU_SCENE)


## Il livello successivo della campagna (dalla schermata di vittoria).
func start_next_level() -> void:
	var next := LevelCatalog.next_of(level_id)
	if not LevelCatalog.is_playable(next):
		return
	var fx := get_node_or_null(^"/root/UiFx") as UiFxService
	if fx == null:
		get_tree().paused = false
		get_tree().change_scene_to_file(LevelCatalog.scene_of(next))
	else:
		fx.fade_to_scene(LevelCatalog.scene_of(next))


# --- Treno della ferrovia (D-066) ---------------------------------------------------

func _setup_train() -> void:
	if train_event == null:
		return
	train_event.first_seconds = tuning.train_first_seconds
	train_event.next_at = tuning.train_first_seconds
	train_event.interval_seconds = tuning.train_interval_seconds
	train_event.warning_seconds = tuning.train_warning_seconds
	train_event.speed = tuning.train_speed
	train_event.carriages = tuning.train_carriages
	train_event.player_damage = tuning.train_player_damage
	train_event.boss_damage = tuning.train_boss_damage
	train_event.rng.seed = run_seed + 3


func _setup_extraction() -> void:
	if extraction_pad == null:
		return
	extraction_pad.hold_seconds = tuning.extraction_hold_seconds
	extraction_pad.radius_cells = tuning.extraction_pad_radius
	extraction_pad.extraction_completed.connect(_on_extraction_completed)


func _setup_quake() -> void:
	if quake_event == null:
		return
	quake_event.first_seconds = RunLaunchOptions.quake_seconds(tuning.quake_first_seconds)
	quake_event.next_at = quake_event.first_seconds
	quake_event.interval_seconds = tuning.quake_interval_seconds
	quake_event.warning_seconds = tuning.quake_warning_seconds
	quake_event.length_cells = tuning.quake_length_cells
	quake_event.distance_min = tuning.quake_distance_min
	quake_event.distance_max = tuning.quake_distance_max
	quake_event.player_damage = tuning.quake_player_damage
	quake_event.rng.seed = run_seed + 4


# --- Ciclo giorno/notte (D-058, tappa 1) -----------------------------------------

func _setup_night() -> void:
	torch_radius = tuning.torch_radius
	beacon_radius = tuning.beacon_radius
	torch_light_id = light_field.add_source(player, torch_radius)
	if companion != null:
		beacon_light_id = light_field.add_source(companion, beacon_radius)
	director.light_field = light_field
	if lamp_field != null:
		lamp_field.scrap_cost = tuning.lamp_scrap_cost
		lamp_field.max_count = tuning.lamp_max_count
		lamp_field.light_radius = tuning.lamp_light_radius
		lamp_field.light_field = light_field
		lamp_field.lamps_changed.connect(func(_count: int) -> void: _refresh_tool_hud())
		player.terrain_mode_changed.connect(func(_mode: TerrainState.ToolMode) -> void: _refresh_tool_hud())
		_refresh_tool_hud()
	if day_night == null:
		return
	day_night.night_start_seconds = RunLaunchOptions.night_start_seconds(tuning.night_start_seconds)
	day_night.dusk_seconds = tuning.dusk_seconds
	if day_night.district == null:
		day_night.district = district
	day_night.phase_changed.connect(_on_night_phase_changed)


func _tick_night() -> void:
	if day_night == null:
		return
	day_night.advance(elapsed)
	var to_dusk := day_night.seconds_to_dusk(elapsed)
	var second := int(to_dusk) if is_finite(to_dusk) else -2
	if second != _day_second_shown or day_night.phase != DayNightCycle.Phase.DAY:
		_day_second_shown = second
		hud.set_day_phase(day_night.phase, to_dusk)
	_update_game_lights()


func _on_night_phase_changed(phase: DayNightCycle.Phase) -> void:
	director.night_active = phase == DayNightCycle.Phase.NIGHT
	match phase:
		DayNightCycle.Phase.DUSK:
			hud.show_night_notice("CALA LA NOTTE", 4.0)
		DayNightCycle.Phase.NIGHT:
			hud.show_night_notice("E NOTTE", 3.0)
	night_phase_changed.emit(phase)


## Le due OmniLight3D sono di ArenaRun, non delle scene del giocatore e del compagno
## (piano, sezione 14): nascono alla prima chiamata e costano zero a fattore 0.
func _update_game_lights() -> void:
	var factor := day_night.night_factor
	if _torch == null:
		_torch = _make_game_light("TorchLight", player)
		if companion != null:
			_beacon = _make_game_light("BeaconLight", companion)
	if is_equal_approx(factor, _night_factor_applied):
		return
	_night_factor_applied = factor
	director.set_night(factor)
	for pair in [[_torch, torch_radius], [_beacon, beacon_radius]]:
		var light: OmniLight3D = pair[0]
		if light == null:
			continue
		light.visible = factor > 0.0
		light.light_energy = 2.2 * factor
		light.omni_range = pair[1] * 1.15


func _make_game_light(light_name: String, owner_node: Node3D) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = Vector3(0.0, 1.6, 0.0)
	light.light_color = Color(1.0, 0.9, 0.72)
	light.shadow_enabled = false
	light.visible = false
	owner_node.add_child.call_deferred(light)
	return light


func _refresh_tool_hud() -> void:
	if lamp_field == null:
		return
	hud.set_tool_mode(player.terrain_tool_mode, lamp_field.count(), lamp_field.max_count, lamp_field.scrap_cost)


func is_night() -> bool:
	return day_night != null and day_night.phase == DayNightCycle.Phase.NIGHT


## Abbandono dalla pausa (R-20, D-064): vale come una morte, si incassa la stessa quota.
## Niente mappa ne pannello: chi abbandona vuole uscire.
func abandon_run() -> void:
	if is_over:
		return
	is_over = true
	director.spawning = false
	var scrap := scrap_out(false)
	var banked := _bank(scrap, false)
	print("PROTOTYPE01_RUN_ABANDONED time=%.1f level=%d kills=%d scrap=%d banked=%d seed=%d"
		% [elapsed, progression.level, director.kills, scrap, banked, run_seed])


## Mappa del campo come l'ha lasciato il giocatore, per la schermata di fine livello.
func build_run_map() -> Image:
	if grid == null:
		# Rilievo continuo: la mappa delle quote arriva col Task 13 (RunMap.render_heights).
		var placeholder := Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
		placeholder.fill(Color(0.12, 0.1, 0.08))
		return placeholder
	var buildings: Array[Rect2] = []
	if district != null:
		for child in district.get_children():
			if not (child is StaticBody3D) or not child.name.begins_with("Block"):
				continue
			for part in child.get_children():
				if part is CollisionShape3D and (part as CollisionShape3D).shape is BoxShape3D:
					var size := ((part as CollisionShape3D).shape as BoxShape3D).size
					var at := (child as StaticBody3D).global_position
					buildings.append(Rect2(at.x - size.x * 0.5, at.z - size.z * 0.5, size.x, size.z))
	var barricades: Dictionary = (boss as Demolisher).barricades if is_instance_valid(boss) and boss is Demolisher else {}
	var boss_position: Variant = boss.global_position if is_instance_valid(boss) else null
	var lamps: Array[Vector2i] = lamp_field.cells() if lamp_field != null else []
	return RunMap.render(grid, _initial_terrain, barricades, buildings, _start_position, player.global_position, boss_position, lamps)


func _show_run_map() -> void:
	game_over.set_map(_final_map if _final_map != null else build_run_map(), "Celle scavate %d   rialzate %d" % [cells_dug, cells_raised], "run_%d" % run_seed)


func _on_enemy_killed(world_position: Vector3, total: int) -> void:
	xp_field.spawn(world_position, tuning.xp_per_enemy)
	hud.set_kills(total)


func _on_xp_collected(amount: int) -> void:
	if is_over:
		return
	_pending_level_ups += progression.add_xp(amount)
	_refresh_xp()
	# Il menu (e la pausa) si aprono a fine passo, in `_physics_process`: fermare
	# il gioco qui, a meta passo, lascerebbe indietro i nodi non ancora elaborati.


func _open_next_level_up() -> void:
	if _pending_level_ups <= 0 or level_up_menu.is_open or is_over:
		return
	var offer := progression.roll_offer()
	if offer.is_empty():
		_pending_level_ups = 0
		return
	var ids := offer.map(func(u: Dictionary) -> String: return str(u.id))
	var shown_level := progression.level - _pending_level_ups + 1
	print("PROTOTYPE01_LEVEL_UP level=%d offer=%s" % [shown_level, ",".join(PackedStringArray(ids))])
	level_up_menu.open(offer, progression.levels, shown_level)


func _on_upgrade_chosen(id: StringName) -> void:
	_pending_level_ups -= 1
	var new_level := progression.choose(id)
	apply_upgrade(id, new_level)
	print("PROTOTYPE01_UPGRADE_CHOSEN id=%s level=%d" % [id, new_level])
	_open_next_level_up.call_deferred()


## Effetto di un upgrade al suo nuovo livello.
func apply_upgrade(id: StringName, new_level: int) -> void:
	match id:
		&"nail_rate":
			weapon.fire_interval /= 1.0 + UpgradeCatalog.value(id, &"rate_percent") / 100.0
		&"nail_pierce":
			weapon.pierce += 1
		&"nail_spread":
			weapon.projectiles += 1
		&"companion_turret":
			_upgrade_companion_turret(new_level)
		&"companion_magnet":
			xp_field.set_attractor(companion, UpgradeCatalog.value(id, &"radius") + UpgradeCatalog.value(id, &"radius_per_level") * (new_level - 1))
			if new_level == 1:
				companion.mount_part(&"MagnetPart", _magnet_part())
		&"companion_cargo":
			companion.add_capacity(int(UpgradeCatalog.value(id, &"capacity")), int(UpgradeCatalog.value(id, &"scrap_now")))
		&"dig_blast":
			dig_blast_radius = UpgradeCatalog.value(id, &"radius") + UpgradeCatalog.value(id, &"radius_per_level") * (new_level - 1)
		&"spiked_wall":
			director.spike_damage = int(UpgradeCatalog.value(id, &"damage"))
			director.spike_interval = UpgradeCatalog.value(id, &"interval") if new_level == 1 else UpgradeCatalog.value(id, &"interval_level_2")
			_set_raised_tint(Color(0.85, 0.75, 0.7))
		&"boots":
			player.speed_bonus *= 1.0 + UpgradeCatalog.value(id, &"speed_percent") / 100.0
		&"patch":
			player.set_max_health(player.max_health + int(UpgradeCatalog.value(id, &"health")))
		&"reach":
			xp_field.player_radius *= 1.0 + UpgradeCatalog.value(id, &"radius_percent") / 100.0
		&"field_patch":
			player.heal(int(UpgradeCatalog.value(id, &"heal")))
		&"lucky_scrap":
			if companion != null:
				companion.add_capacity(0, int(UpgradeCatalog.value(id, &"scrap_now")))
		&"torch_range":
			torch_radius = tuning.torch_radius + tuning.torch_radius_per_level * new_level
			light_field.set_radius(torch_light_id, torch_radius)
			_night_factor_applied = -1.0
		&"beacon_range":
			beacon_radius = tuning.beacon_radius + tuning.beacon_radius_per_level * new_level
			light_field.set_radius(beacon_light_id, beacon_radius)
			_night_factor_applied = -1.0
		&"nail_jar":
			var radius := UpgradeCatalog.value(id, &"radius")
			var center := Vector3(player.global_position.x, 0.1, player.global_position.z)
			for enemy in director.enemies_near(center, radius):
				enemy.take_damage(int(UpgradeCatalog.value(id, &"damage")))
			_blast_effect(center, radius)


func _upgrade_companion_turret(new_level: int) -> void:
	if companion_weapon == null:
		companion_weapon = AutoWeapon.new()
		companion_weapon.name = "CompanionWeapon"
		companion_weapon.shooter = companion
		companion_weapon.director = director
		companion_weapon.muzzle_height = 0.55
		companion_weapon.fire_interval = UpgradeCatalog.value(&"companion_turret", &"fire_interval")
		companion_weapon.weapon_range = UpgradeCatalog.value(&"companion_turret", &"weapon_range")
		companion_weapon.damage = tuning.weapon_damage
		companion_weapon.projectile_speed = tuning.projectile_speed
		# Differito: con la Torretta fissa (D-049) succede durante il _ready della scena.
		get_parent().add_child.call_deferred(companion_weapon)
		companion.mount_part(&"TurretPart", _turret_part())
	else:
		companion_weapon.fire_interval /= UpgradeCatalog.value(&"companion_turret", &"rate_per_level")
	print("PROTOTYPE01_COMPANION_TURRET level=%d" % new_level)


## Scavo esplosivo: ogni passo di scavo colpisce i nemici attorno alla cella.
func _on_terrain_command(cell: Vector2i, mode: TerrainState.ToolMode, new_state: TerrainState.CellState) -> void:
	if mode == TerrainState.ToolMode.DIG:
		cells_dug += 1
	else:
		cells_raised += 1
	var center := grid.to_global(grid.cell_local_position(cell, new_state))
	# Zolle che saltano a ogni colpo di tool: dalla cima della cella.
	DebrisBurst.spawn(get_parent(), Vector3(center.x, center.y * 2.0 - grid.global_position.y + 0.1, center.z),
		Demolisher.EARTH_COLOR, 8, 3.2, 0.16)
	if mode != TerrainState.ToolMode.DIG or dig_blast_radius <= 0.0:
		return
	center.y = 0.1
	for enemy in director.enemies_near(center, dig_blast_radius):
		enemy.take_damage(2)
	_blast_effect(center, dig_blast_radius)
	print("PROTOTYPE01_DIG_BLAST X=%d Y=%d" % [cell.x, cell.y])


func _blast_effect(center: Vector3, radius: float) -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.05
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.6, 0.15, 0.7)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ring)
	ring.global_position = center
	ring.scale = Vector3(0.2, 1.0, 0.2)
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, ^"scale", Vector3(radius, 1.0, radius), 0.25)
	tween.tween_property(material, ^"albedo_color:a", 0.0, 0.25)
	tween.chain().tween_callback(ring.queue_free)


## Terrapieni spinati: le celle rialzate prendono un colore metallico chiaro.
func _set_raised_tint(color: Color) -> void:
	if grid != null:
		grid.raised_color_override = color


func _turret_part() -> Node3D:
	var part := Node3D.new()
	part.position = Vector3(0.0, 0.42, -0.25)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.13)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.16
	base_mesh.bottom_radius = 0.2
	base_mesh.height = 0.14
	base.mesh = base_mesh
	base.material_override = dark
	part.add_child(base)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.09, 0.09, 0.45)
	barrel.mesh = barrel_mesh
	barrel.material_override = dark
	barrel.position = Vector3(0.0, 0.1, -0.22)
	part.add_child(barrel)
	return part


func _magnet_part() -> Node3D:
	var part := Node3D.new()
	part.position = Vector3(0.0, 0.55, 0.42)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.08, 0.06)
	var tip := StandardMaterial3D.new()
	tip.albedo_color = Color(0.8, 0.8, 0.82)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.1, 0.4, 0.1)
		arm.mesh = arm_mesh
		arm.material_override = red
		arm.position = Vector3(side * 0.14, 0.2, 0.0)
		part.add_child(arm)
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.11, 0.08, 0.11)
		cap.mesh = cap_mesh
		cap.material_override = tip
		cap.position = Vector3(side * 0.14, 0.42, 0.0)
		part.add_child(cap)
	var bridge := MeshInstance3D.new()
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(0.38, 0.1, 0.1)
	bridge.mesh = bridge_mesh
	bridge.material_override = red
	part.add_child(bridge)
	return part


func _refresh_xp() -> void:
	hud.set_xp(progression.xp, progression.xp_to_next(), progression.level)


func _on_player_died() -> void:
	_end_level(false)


static func _boss_call_from_command_line(default_seconds: float) -> float:
	return RunLaunchOptions.boss_call_seconds(default_seconds)


static func _seed_from_command_line() -> int:
	return RunLaunchOptions.run_seed()


# --- Distanza della camera (D-078) ------------------------------------------------

## Oltre questa distanza un punto e fuori vista con la distanza di camera corrente.
func marker_min_distance() -> float:
	return MARKER_MIN_DISTANCE * marker_scale


## Il rig della camera e fratello di questo nodo nelle scene dei livelli.
func _camera_rig() -> IsometricCameraRig:
	var parent := get_parent()
	return parent.get_node_or_null(^"CameraRig") as IsometricCameraRig if parent != null else null


func _setup_camera_distance() -> void:
	var rig := _camera_rig()
	if rig == null:
		return
	rig.distance_changed.connect(_on_camera_distance_changed)
	var settings := get_node_or_null(^"/root/GameSettings") as GameSettingsService
	rig.set_distance_index(settings.camera_distance if settings != null else IsometricCameraRig.DEFAULT_DISTANCE_INDEX, true)
	_on_camera_distance_changed(rig.distance_index, rig.target_arm_m())
	if settings != null and not settings.changed.is_connected(_on_settings_changed_camera):
		settings.changed.connect(_on_settings_changed_camera)


## L'anello di comparsa segue la finestra visibile: a 20 m di braccio si allarga di 4/3.
func _on_camera_distance_changed(index: int, arm_m: float) -> void:
	director.ring_scale = arm_m / 15.0
	marker_scale = arm_m / 15.0
	var settings := get_node_or_null(^"/root/GameSettings") as GameSettingsService
	if settings != null and settings.camera_distance != index:
		settings.set_camera_distance(index)


func _on_settings_changed_camera() -> void:
	var settings := get_node_or_null(^"/root/GameSettings") as GameSettingsService
	var rig := _camera_rig()
	if settings != null and rig != null and rig.distance_index != settings.camera_distance:
		rig.set_distance_index(settings.camera_distance)
