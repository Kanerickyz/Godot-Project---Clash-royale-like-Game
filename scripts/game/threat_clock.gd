class_name ThreatClock
extends RefCounted
## Floor threat clock: advances with real delta, exposes multiplier/tier (frame-rate independent).


var config: ThreatConfig
var elapsed: float = 0.0


func configure(cfg: ThreatConfig) -> void:
	if cfg == null:
		config = ThreatConfig.new()
	else:
		config = cfg.duplicate(true) as ThreatConfig
	elapsed = 0.0


func reset() -> void:
	elapsed = 0.0


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed += delta


func get_progress() -> float:
	if config == null:
		return 0.0
	var ramp := maxf(0.001, config.ramp_duration)
	return clampf(elapsed / ramp, 0.0, 1.0)


func get_multiplier() -> float:
	if config == null:
		return 1.0
	return lerpf(config.base_multiplier, config.max_multiplier, get_progress())


func get_tier_index() -> int:
	if config == null or config.tier_thresholds.is_empty():
		return 0
	var mult := get_multiplier()
	var tier := 0
	for i in config.tier_thresholds.size():
		if mult + 0.0001 >= config.tier_thresholds[i]:
			tier = i
	return tier


func get_tier_label() -> String:
	var idx := get_tier_index()
	if config == null or config.tier_labels.is_empty():
		return "威胁 %d" % (idx + 1)
	if idx < 0 or idx >= config.tier_labels.size():
		return config.tier_labels[config.tier_labels.size() - 1]
	return config.tier_labels[idx]


## Interval scale factor >= 1: divide base interval by this for higher pressure.
func get_spawn_interval_divisor() -> float:
	if config == null:
		return 1.0
	var mult := get_multiplier()
	var weight := config.interval_threat_weight
	return maxf(1.0, 1.0 + weight * (mult - config.base_multiplier))


## Stat scale for newly spawned enemies (>= 1).
func get_enemy_stat_scale() -> float:
	if config == null:
		return 1.0
	var mult := get_multiplier()
	var weight := config.enemy_stat_threat_weight
	return maxf(1.0, 1.0 + weight * (mult - config.base_multiplier))
