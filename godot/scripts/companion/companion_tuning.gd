class_name CompanionTuning
extends Resource
## Parametri del compagno macchina (Companion Slice, D-032). Unita Godot (metri,
## secondi): non esiste un riferimento Unreal da cui convertire.

@export_group("Movement")
@export var max_speed := 5.0
@export var acceleration := 25.0
## Distanza a cui segue il giocatore, dietro rispetto alla direzione di marcia.
@export var follow_distance := 2.5
## Entro questa distanza dal punto di destinazione si ferma.
@export var arrive_radius := 0.4

@export_group("Scrap")
@export var starting_scrap := 3
@export var capacity := 5
## Raccoglie solo rottami entro questa distanza dal giocatore.
@export var pickup_radius_from_player := 6.0
## Distanza a cui un rottame viene caricato.
@export var collect_radius := 0.9
## Il giocatore puo rialzare solo se il compagno e entro questa distanza dalla cella.
@export var supply_radius := 5.0

@export_group("Hazard assist")
## Interviene se il giocatore e nella corsia, entro questa distanza davanti alla sfera.
@export var threat_distance := 10.0
## Semi-larghezza della corsia considerata pericolosa.
@export var lane_half_width := 1.0
## Fascia davanti alla sfera in cui cerca la cella da alzare.
@export var block_min_ahead := 1.7
@export var block_max_ahead := 6.0
## Il compagno alza celle solo entro questa distanza da se.
@export var action_radius := 9.0
@export var assist_cooldown := 3.0
