class_name WfcCell
extends RefCounted

var options: Array[int] = []
var collapsed: bool = false


func setup(all_types: Array[TerrainType.Type]) -> void:
	options.clear()
	collapsed = false
	for t in all_types:
		options.append(int(t))


func copy_from(other: WfcCell) -> void:
	options = other.options.duplicate()
	collapsed = other.collapsed


func clone() -> WfcCell:
	var c := WfcCell.new()
	c.copy_from(self)
	return c


func entropy() -> int:
	if collapsed:
		return 0
	return options.size()


func is_contradiction() -> bool:
	return not collapsed and options.is_empty()


func get_collapsed_type() -> int:
	if options.size() == 1:
		return options[0]
	return -1


func collapse_to(type_id: int) -> void:
	options = [type_id]
	collapsed = true


func remove_option(type_id: int) -> bool:
	var idx := options.find(type_id)
	if idx < 0:
		return false
	options.remove_at(idx)
	if options.size() == 1:
		collapsed = true
	return true
