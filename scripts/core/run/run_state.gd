class_name RunState
extends RefCounted

var rng_seed: int = 0
var map_state: MapState = MapState.new()
var run_depth: int = 0
var shop_visit_count: int = 0
var completed_encounter_count: int = 0
var current_node_id: int = -1


func reset_progress() -> void:
	run_depth = 0
	shop_visit_count = 0
	completed_encounter_count = 0
	current_node_id = -1
	map_state = MapState.new()
