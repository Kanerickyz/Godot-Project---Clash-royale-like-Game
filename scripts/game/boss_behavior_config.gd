class_name BossBehaviorConfig
extends Resource
## Tunable values for Boss pressure / charge / summon / stun loop.


@export_group("Pressure")
@export var pressure_duration: float = 2.5
@export var pressure_move_speed_scale: float = 0.55

@export_group("Charge")
@export var telegraph_duration: float = 0.85
@export var charge_speed: float = 420.0
@export var charge_distance: float = 480.0
@export var charge_path_half_width: float = 48.0
@export var charge_damage: int = 20
@export var knockback_distance: float = 100.0
@export var target_stun_duration: float = 0.75
@export var boss_stun_after_charge: float = 1.0

@export_group("Summon")
@export var summon_count: int = 2
@export var summon_radius: float = 90.0
@export var boss_stun_after_summon: float = 0.9

@export_group("Body")
@export var collision_radius: float = 32.0

@export_group("Cycle")
## If true, first special after pressure is charge; then alternates with summon.
@export var alternate_start_with_charge: bool = true
