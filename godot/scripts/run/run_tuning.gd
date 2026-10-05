class_name RunTuning
extends Resource
## Parametri della run del prototipo della promessa A (D-038). Unita Godot
## (metri, secondi). I nodi copiano i valori all'avvio e non modificano mai la
## risorsa: gli upgrade cambiano le copie, non il file condiviso.

@export_group("Player")
@export var player_max_health := 5
## Invulnerabilita dopo un colpo.
@export var player_invulnerability := 0.8
## Raggio entro cui i frammenti di esperienza volano verso il giocatore.
@export var pickup_radius := 2.5

@export_group("Enemies")
@export var enemy_speed := 2.2
@export var enemy_health := 2
## Ogni quanti secondi la vita dei nuovi nemici cresce di 1.
@export var enemy_health_growth_seconds := 150.0
## Distanza planare di contatto col giocatore.
@export var contact_radius := 0.75
@export var contact_damage := 1
@export var max_alive := 70

@export_group("Spawning")
@export var spawn_interval_start := 1.6
@export var spawn_interval_min := 0.3
## Secondi per passare dall'intervallo iniziale al minimo.
@export var spawn_ramp_seconds := 300.0
@export var batch_min := 1
@export var batch_max := 3
## Nessun nemico nasce piu vicino di cosi al giocatore.
@export var spawn_min_player_distance := 11.0
## Anello di comparsa attorno al giocatore (D-039), in metri: oltre il bordo
## dello schermo a 1280x800 (circa 15 m in orizzontale), ma non troppo lontano.
## I punti sono riportati dentro l'area giocabile, quindi in un'arena piccola
## cadono sui bordi come prima.
@export var spawn_ring_min := 17.0
@export var spawn_ring_max := 23.0
## Un nemico piu lontano di cosi dal giocatore viene riportato sull'anello di
## comparsa: in un'arena grande l'orda non si disperde dietro le spalle.
@export var enemy_leash_distance := 40.0

@export_group("Weapon")
@export var fire_interval := 0.5
@export var weapon_range := 9.0
@export var weapon_damage := 1
@export var projectile_speed := 24.0

@export_group("Progression")
@export var xp_per_enemy := 1
## Esperienza per passare dal livello 1 al 2; ogni livello ne chiede xp_growth in piu.
@export var xp_first_level := 5
@export var xp_growth := 3
## Level-up consecutivi senza carte Rare prima della garanzia (regola 4).
@export var pity_level_ups := 4

@export_group("Courtyard")
## Mura iniziali del cortile: anello di celle Raised a questa distanza dal centro
## della griglia, con un varco al centro di ogni lato. 0 = nessuna mura.
@export var wall_ring_radius := 4
