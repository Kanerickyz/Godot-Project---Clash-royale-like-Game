@tool
class_name SpawnScheduleEntry
extends Resource

## 在第几个战斗 tick 开始时刷出（0 = 开战当轮）
@export_range(0, 256, 1) var combat_tick: int = 0
@export var unit: UnitData
@export_range(1, 16, 1) var count: int = 1


func duplicate_entry() -> SpawnScheduleEntry:
	var copy := SpawnScheduleEntry.new()
	copy.combat_tick = combat_tick
	copy.unit = unit
	copy.count = count
	return copy


func get_summary() -> String:
	var name_str := unit.display_name if unit != null else "?"
	return "T%d ×%d %s" % [combat_tick, count, name_str]
