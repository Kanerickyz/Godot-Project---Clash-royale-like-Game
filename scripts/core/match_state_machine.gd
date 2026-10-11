class_name MatchStateMachine
extends RefCounted

enum Phase { SHOP, PREPARE, COMBAT, RESOLVE, LEVEL_COMPLETE, DEFEAT }

var phase: Phase = Phase.PREPARE
var current_encounter: EncounterData


func reset() -> void:
	phase = Phase.PREPARE
	current_encounter = null


func has_active_encounter() -> bool:
	return current_encounter != null and current_encounter.wave != null


func get_current_wave() -> WaveData:
	if current_encounter == null:
		return null
	return current_encounter.wave


func set_encounter(encounter: EncounterData) -> void:
	current_encounter = encounter
