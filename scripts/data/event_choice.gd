class_name EventChoice
extends Resource

enum EffectType {
	NONE,
	GRANT_GOLD,
	LOSE_GOLD,
	HEAL_ALL_UNITS,
	REMOVE_RANDOM_DECK_ENTRY,
	GRANT_RANDOM_BUFF,
}


@export var label: String = ""
@export var effect_type: EffectType = EffectType.NONE
@export var value: int = 0
