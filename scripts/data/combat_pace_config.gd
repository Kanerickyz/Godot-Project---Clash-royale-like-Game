class_name CombatPaceConfig
extends Resource

@export_range(0.0, 0.2, 0.005) var scale_per_combat_tick: float = 0.05
@export_range(0.1, 1.0, 0.05) var min_pace_scale: float = 0.4
@export_range(0.0, 3.0, 0.05) var skill_callout_hold_sec: float = 1.2


func get_pace_scale(combat_tick: int) -> float:
	var t := maxi(combat_tick, 0)
	return clampf(1.0 - float(t) * scale_per_combat_tick, min_pace_scale, 1.0)


func scaled_duration(base: float, combat_tick: int) -> float:
	return base * get_pace_scale(combat_tick)
