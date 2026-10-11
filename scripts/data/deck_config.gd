class_name DeckConfig
extends Resource

@export var starting_unit: UnitData
@export var starting_units: Array[UnitData] = []
@export_range(1, 40, 1) var starting_count: int = 10
@export_range(1, 40, 1) var max_size: int = 20
@export_range(1, 20, 1) var max_board_units: int = 5
@export var level_config: LevelConfig
