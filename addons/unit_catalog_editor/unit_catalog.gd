@tool
class_name UnitCatalog
extends RefCounted

const UNITS_DIR := "res://resources/units"
const ABILITIES_DIR := "res://resources/abilities"


static func scan_units(dir: String = UNITS_DIR) -> Array:
	var result: Array = []
	_collect_units(dir, result)
	result.sort_custom(func(a, b) -> bool:
		var ua: UnitData = a.get("data")
		var ub: UnitData = b.get("data")
		if ua == null or ub == null:
			return false
		return ua.display_name < ub.display_name
	)
	return result


static func _collect_units(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir() and not name.begins_with("."):
			_collect_units(full, out)
		elif name.ends_with(".tres"):
			var data := ResourceLoader.load(
				full,
				"",
				ResourceLoader.CACHE_MODE_REUSE,
			) as UnitData
			if data != null:
				out.append({"path": full, "data": data})
		name = dir.get_next()
	dir.list_dir_end()


static func scan_abilities() -> Array[AbilityData]:
	return AbilityCatalog.scan_abilities_only()


static func filter_by_team(entries: Array, team: int) -> Array:
	var filtered: Array = []
	for entry in entries:
		var data: UnitData = entry.get("data")
		if data == null:
			continue
		if data.team_default == team:
			filtered.append(entry)
	return filtered


static func is_player(unit: UnitData) -> bool:
	return unit != null and unit.team_default == UnitInstance.Team.PLAYER


static func is_enemy(unit: UnitData) -> bool:
	return unit != null and unit.team_default == UnitInstance.Team.ENEMY
