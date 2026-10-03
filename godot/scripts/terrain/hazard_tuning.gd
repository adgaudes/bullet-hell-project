class_name HazardTuning
extends Resource
## Parametri dell'hazard e della sua corsia, con valori e unita di
## APrototype01TerrainHazardActor e SmokeTestGameMode (centimetri). Vedi D-024.

## MoveSpeed, cm/s (min 10).
@export var move_speed_cm := 350.0
## RestartDelay, secondi (min 0,05).
@export var restart_delay := 1.0
## Raggio della sfera, cm.
@export var radius_cm := 45.0
## Margine della corsia oltre ciascun bordo della griglia, cm.
@export var lane_margin_cm := 260.0
## Altezza del centro sulla griglia: a 0 lo sweep toccherebbe il pavimento.
@export var lane_center_height_cm := 50.0
