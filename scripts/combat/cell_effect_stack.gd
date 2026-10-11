class_name CellEffectStack
extends RefCounted

class CellEffectInstance:
	var data: CellEffectData
	var remaining_rounds: int = 1


## 每格最多一种效果；新效果覆盖旧效果。
var _by_cell: Dictionary = {}


func clear() -> void:
	_by_cell.clear()


func add_effect(cell: Vector2i, data: CellEffectData, duration_rounds: int = -1) -> void:
	if data == null:
		return
	var inst := CellEffectInstance.new()
	inst.data = data
	inst.remaining_rounds = duration_rounds if duration_rounds >= 0 else data.duration_rounds
	_by_cell[_cell_key(cell)] = inst


func has_effect_at(cell: Vector2i) -> bool:
	return _by_cell.has(_cell_key(cell))


func get_effect_at(cell: Vector2i) -> CellEffectData:
	var inst: CellEffectInstance = _by_cell.get(_cell_key(cell))
	return inst.data if inst != null else null


func get_cells_with_effects() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in _by_cell.keys():
		result.append(_parse_cell_key(str(key)))
	return result


## 回合开始时、移动阶段之前：对站在效果格上的单位结算伤害。
func apply_stand_damage(grid: BoardGrid, pipeline: DamagePipeline) -> void:
	if grid == null or pipeline == null:
		return
	for key in _by_cell.keys():
		var cell := _parse_cell_key(str(key))
		var unit := grid.get_unit(cell)
		if unit == null or not unit.is_alive():
			continue
		var inst: CellEffectInstance = _by_cell[key]
		if inst == null or inst.data == null:
			continue
		pipeline.apply_damage(null, unit, inst.data.damage_per_tick)


## 回合开始结算伤害后递减剩余回合；归零则移除该格效果。
func tick_round_end() -> void:
	var expired: Array[String] = []
	for key in _by_cell.keys():
		var inst: CellEffectInstance = _by_cell[key]
		if inst == null:
			expired.append(str(key))
			continue
		inst.remaining_rounds -= 1
		if inst.remaining_rounds <= 0:
			expired.append(str(key))
	for key in expired:
		_by_cell.erase(key)


static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func _parse_cell_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
