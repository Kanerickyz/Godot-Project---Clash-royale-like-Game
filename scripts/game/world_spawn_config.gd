class_name WorldSpawnConfig
extends Resource
## Tunables for procedural map size, camera zoom, and enemy/chest spawn cadence.


@export_group("Map")
@export var map_size: Vector2 = Vector2(2800, 2200)
@export var camera_zoom: float = 1.5
@export var room_count_min: int = 5
@export var room_count_max: int = 8
@export var room_size_min: Vector2 = Vector2(280, 220)
@export var room_size_max: Vector2 = Vector2(480, 380)
@export var corridor_width: float = 80.0
@export var room_padding: float = 40.0
@export var room_margin: float = 48.0

@export_group("Start Spawn")
@export var start_enemy_min: int = 8
@export var start_enemy_max: int = 10
@export var start_chest_min: int = 3
@export var start_chest_max: int = 4
@export var spawn_min_separation: float = 90.0
@export var spawn_edge_margin: float = 56.0

@export_group("Respawn")
@export var respawn_interval_min: float = 25.0
@export var respawn_interval_max: float = 35.0
@export var respawn_enemy_min: int = 2
@export var respawn_enemy_max: int = 3
@export var respawn_chest_chance: float = 0.55
@export var respawn_chest_count: int = 1
@export var max_alive_enemies: int = 18
@export var max_alive_chests: int = 6
