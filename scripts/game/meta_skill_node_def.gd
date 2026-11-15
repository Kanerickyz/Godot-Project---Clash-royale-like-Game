class_name MetaSkillNodeDef
extends Resource
## Phase G: one purchasable permanent skill-tree node.


enum EffectKind {
	STARTING_HP,
	STARTING_DUCATS,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: int = 1
## Empty = global tree; otherwise owned by that character tree.
@export var character_id: StringName = &""
@export var requires: PackedStringArray = PackedStringArray()
@export var effect_kind: EffectKind = EffectKind.STARTING_HP
@export var effect_value: float = 10.0
