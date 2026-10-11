class_name ShopPoolConfig
extends Resource

@export var pool: Array[UnitData] = []
@export var character_pool: Array[UnitData] = []
@export var buff_pool: Array[BuffCardData] = []
@export_range(1, 8, 1) var character_slot_count: int = 5
@export_range(0, 8, 1) var buff_slot_count: int = 2
