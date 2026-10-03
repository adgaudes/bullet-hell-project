class_name TerrainTuning
extends Resource
## Parametri della griglia terreno, con valori e unita di
## APrototype01TerrainGridActor (centimetri). Vedi D-024.

@export_group("Grid")
## Celle lungo l'asse X Unreal (avanti, -Z Godot). Dispari, 1..15.
@export_range(1, 15) var grid_width := 7
## Celle lungo l'asse Y Unreal (destra, +X Godot). Dispari, 1..15.
@export_range(1, 15) var grid_height := 7
@export var cell_size_cm := 240.0
@export var cell_gap_cm := 12.0

@export_group("Presentation")
@export var lowered_height_cm := 4.0
@export var normal_height_cm := 12.0
@export var raised_height_cm := 120.0

@export_group("Gameplay")
## Velocita sottratta sopra una cella Lowered (0 = nessuna, 0.95 = quasi fermo). Usata in Fase 8.
@export_range(0.0, 0.95) var lowered_speed_penalty_percent := 0.5
