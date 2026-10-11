extends Node2D

const COLOR_PLAYER := Color(0.35, 0.75, 0.95, 1.0)
const COLOR_ENEMY := Color(0.95, 0.4, 0.35, 1.0)
const COLOR_RAGE := Color(0.95, 0.55, 0.2, 1.0)
const COLOR_SPAWN := Color(0.65, 0.45, 0.95, 1.0)
const COLOR_HEAL := Color(0.35, 0.9, 0.55, 1.0)
const COLOR_SPIDER := Color(0.45, 0.25, 0.7, 1.0)
const COLOR_PIG := Color(0.95, 0.65, 0.75, 1.0)
const COLOR_T2 := Color(0.3, 0.65, 0.85, 1.0)


func set_team(team: UnitInstance.Team) -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual == null:
		return
	visual.color = COLOR_PLAYER if team == UnitInstance.Team.PLAYER else COLOR_ENEMY


func set_unit_id(unit_id: String) -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual == null:
		return
	match unit_id:
		"peacock":
			visual.color = COLOR_RAGE
		"cricket", "zombie_cricket":
			visual.color = COLOR_SPAWN
		"spider", "spider_hatchling":
			visual.color = COLOR_SPIDER
		"pig":
			visual.color = COLOR_PIG
		"hedgehog", "crab":
			visual.color = COLOR_T2


func set_hp_ratio(ratio: float) -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual == null:
		return
	var scale_factor := clampf(0.45 + ratio * 0.55, 0.45, 1.0)
	visual.scale = Vector2(scale_factor, scale_factor)
