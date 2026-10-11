class_name StatModifierStack
extends RefCounted

var _flat: Dictionary = {}


func add_flat(stat_name: StringName, value: int) -> void:
	if not _flat.has(stat_name):
		_flat[stat_name] = 0
	_flat[stat_name] += value


func get_flat_bonus(stat_name: StringName) -> int:
	return int(_flat.get(stat_name, 0))


func clear() -> void:
	_flat.clear()
