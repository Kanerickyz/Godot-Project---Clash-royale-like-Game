class_name FloorRunConfig
extends Resource
## Phase A/F floor-run tunables: starting army, portal, assemble/rage, run length, dungeon types.
## Runtime must duplicate().


@export_group("Start")
## UnitDefinition paths for starting followers (not captain).
@export var starting_follower_paths: PackedStringArray = PackedStringArray([
	"res://resources/units/ally_skeleton.tres",
	"res://resources/units/ally_spear.tres",
	"res://resources/units/ally_shield.tres",
])
@export var captain_path: String = "res://resources/units/captain.tres"
@export var enemy_path: String = "res://resources/units/enemy_grunt.tres"

@export_group("Run Length")
## Inclusive floor count for one run (final floor is the last).
@export var total_floors: int = 3
@export var final_boss_path: String = "res://resources/units/boss.tres"
@export var final_boss_behavior_path: String = "res://resources/combat/boss_summon_charge.tres"
@export var final_boss_minion_path: String = "res://resources/units/boss_minion.tres"

@export_group("Dungeon Types")
## Type ids cycled by floor (need 2+). Used for floor tint / HUD tag.
@export var dungeon_type_ids: PackedStringArray = PackedStringArray(["crypt", "aqueduct"])
## Display labels aligned with dungeon_type_ids.
@export var dungeon_type_labels: PackedStringArray = PackedStringArray(["地下墓穴", "水道"])

@export_group("Pressure")
## Extra starting enemies on floors after the first (scales toward final).
@export var late_floor_enemy_bonus: int = 2
## Threat ramp duration scale on final floor (<1 = faster pressure).
@export var final_floor_threat_ramp_scale: float = 0.85

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


func resolved_total_floors() -> int:
	return maxi(1, total_floors)


func dungeon_type_id_for_floor(floor_index: int) -> String:
	var ids := dungeon_type_ids
	if ids.is_empty():
		return "crypt"
	var i := posmod(maxi(0, floor_index - 1), ids.size())
	return String(ids[i])


func dungeon_type_label_for_floor(floor_index: int) -> String:
	var id := dungeon_type_id_for_floor(floor_index)
	var ids := dungeon_type_ids
	var labels := dungeon_type_labels
	for i in mini(ids.size(), labels.size()):
		if String(ids[i]) == id:
			return String(labels[i])
	return id


func is_final_floor_index(floor_index: int) -> bool:
	return floor_index >= resolved_total_floors()
