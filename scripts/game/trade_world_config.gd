class_name TradeWorldConfig
extends Resource
## Tunables for the city-trade dual-layer sandbox.


@export_group("Economy")
@export var start_gold: int = 40
@export var cargo_display_name: String = "粮食"
@export var start_cargo: int = 0

@export_group("World")
@export var cities: Array[TradeCityConfig] = []
@export var encounter_chance: float = 0.4
@export var world_camera_zoom: float = 1.0
@export var token_move_speed: float = 140.0
@export var city_arrive_radius: float = 28.0
@export var start_city_index: int = 0

@export_group("Recruit")
@export var recruit_offers: Array[TradeRecruitOffer] = []

@export_group("Combat")
@export var combat_enemy_count: int = 4
@export var combat_arena_size: Vector2 = Vector2(360, 520)
@export var combat_camera_zoom: float = 1.35
