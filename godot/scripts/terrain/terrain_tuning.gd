class_name TerrainTuning
extends Resource
## Parametri della griglia terreno, con valori e unita di
## APrototype01TerrainGridActor (centimetri). Vedi D-024.
## Ogni modifica emette `changed`: la griglia si ricostruisce subito, anche nell'editor.

## Limite di celle per lato (201 celle = 482 m): l'arena grande (D-042) ne usa 85.
const MAX_CELLS := 201

@export_group("Grid")
## Celle lungo l'asse X Unreal (avanti, -Z Godot). Dispari, 1..MAX_CELLS.
@export_range(1, 201) var grid_width := 7:
	set(value):
		grid_width = value
		emit_changed()
## Celle lungo l'asse Y Unreal (destra, +X Godot). Dispari, 1..MAX_CELLS.
@export_range(1, 201) var grid_height := 7:
	set(value):
		grid_height = value
		emit_changed()
@export var cell_size_cm := 240.0:
	set(value):
		cell_size_cm = value
		emit_changed()
@export var cell_gap_cm := 12.0:
	set(value):
		cell_gap_cm = value
		emit_changed()

@export_group("Presentation")
@export var lowered_height_cm := 4.0:
	set(value):
		lowered_height_cm = value
		emit_changed()
@export var normal_height_cm := 12.0:
	set(value):
		normal_height_cm = value
		emit_changed()
@export var raised_height_cm := 120.0:
	set(value):
		raised_height_cm = value
		emit_changed()

@export_group("Gameplay")
## Velocita sottratta sopra una cella Lowered (0 = nessuna, 0.95 = quasi fermo). Usata in Fase 8.
@export_range(0.0, 0.95) var lowered_speed_penalty_percent := 0.5:
	set(value):
		lowered_speed_penalty_percent = value
		emit_changed()

@export_group("Brush")
## Pennello del giocatore (terreno continuo, D-082): raggio, velocita al centro, livella.
@export var brush_radius_m := 2.4
@export var sculpt_rate_m_s := 2.2
@export var level_rate := 5.0
## Pendenza massima di marcia (metri di quota per metro).
@export var max_grade := 0.8
## Zainetto di terra (m3): capacita e quantita all'avvio del livello.
@export var pack_capacity_m3 := 60.0
@export var pack_start_m3 := 20.0
## Distanza del bersaglio del tool davanti al giocatore, metri.
@export var tool_range_m := 3.6
## Dischi non scolpibili attorno alle fondamenta e al cortile di partenza (primi 10 s).
@export var protected_radius_m := 1.5
@export var start_protected_radius_m := 6.0
@export var start_protected_seconds := 10.0
