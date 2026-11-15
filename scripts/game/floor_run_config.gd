class_name FloorRunConfig
extends Resource
## Phase A floor-run tunables: starting army, portal, assemble/rage. Runtime must duplicate().


@export_group("Start")
## UnitDefinition paths for starting followers (not captain).
@export var starting_follower_paths: PackedStringArray = PackedStringArray([
	"res://resources/units/ally_skeleton.tres",
	"res://resources/units/ally_spear.tres",
	"res://resources/units/ally_shield.tres",
])
@export var captain_path: String = "res://resources/units/captain.tres"
@export var enemy_path: String = "res://resources/units/enemy_grunt.tres"

@export_group("Portal")
@export var portal_interact_radius: float = 90.0
## Hold/confirm seconds while near portal (0 = press confirm once).
@export var portal_confirm_sec: float = 0.35

@export_group("Assemble")
@export var assemble_duration: float = 2.5
@export var assemble_cooldown: float = 8.0
@export var assemble_follow_distance: float = 28.0

@export_group("Rage")
@export var rage_duration: float = 5.0
@export var rage_cooldown: float = 16.0
@export var rage_damage_mult: float = 1.5
@export var rage_speed_mult: float = 1.25
