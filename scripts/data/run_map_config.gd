class_name RunMapConfig
extends Resource

@export_range(0, 8, 1) var act_index: int = 0
@export var act_display_name: String = "第一幕"
@export_range(3, 20, 1) var floor_count: int = 14
@export_range(3, 9, 1) var min_nodes_per_floor: int = 3
@export_range(3, 9, 1) var max_nodes_per_floor: int = 6
@export_range(5, 11, 1) var column_count: int = 7
@export_range(5, 15, 1) var shop_min_floor: int = 5
@export_range(1, 4, 1) var max_shops_per_act: int = 2
@export_range(1, 4, 1) var max_rests_per_act: int = 2
@export_range(2, 6, 1) var elite_interval: int = 4
@export var board_defaults: LevelData
@export var combat_pool: Array[EncounterData] = []
@export var elite_pool: Array[EncounterData] = []
@export var boss_encounter: EncounterData
@export var event_pool: Array[EventData] = []
@export var treasure_buff_pool: Array[BuffCardData] = []
