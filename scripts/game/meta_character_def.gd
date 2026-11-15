class_name MetaCharacterDef
extends Resource
## Phase G: selectable captain identity for a run.


@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
## When true, available with a fresh save.
@export var unlocked_by_default: bool = false
## Unlock id granted into the save's unlock set (e.g. challenge clear).
@export var unlock_id: StringName = &""
@export var lock_reason: String = "完成挑战后解锁"
## Flat bonuses applied at run start (before skill-tree nodes).
@export var base_starting_hp_bonus: int = 0
@export var base_starting_ducats_bonus: int = 0
