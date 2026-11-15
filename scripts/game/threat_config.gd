class_name ThreatConfig
extends Resource
## Tunables for the floor threat clock (multiplier + tier bands). Runtime must duplicate().


@export_group("Multiplier")
## Threat multiplier at floor start.
@export var base_multiplier: float = 1.0
## Soft cap for threat multiplier after full ramp.
@export var max_multiplier: float = 2.5
## Real-time seconds to reach max_multiplier (progress 0→1).
@export var ramp_duration: float = 120.0

@export_group("Tiers")
## Multiplier thresholds for HUD tiers (ascending). Tier index = last threshold <= current mult.
@export var tier_thresholds: PackedFloat32Array = PackedFloat32Array([1.0, 1.25, 1.6, 2.0])
@export var tier_labels: PackedStringArray = PackedStringArray(["平静", "警惕", "高压", "淹没"])

@export_group("Pressure Hooks")
## Spawn interval is divided by (1 + interval_threat_weight * (mult - 1)).
@export var interval_threat_weight: float = 1.0
## Enemy HP/damage scale uses this weight on (mult - 1).
@export var enemy_stat_threat_weight: float = 1.0
