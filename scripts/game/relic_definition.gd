class_name RelicDefinition
extends Resource
## Phase E: one relic — corpus price + combat/economy effect (resourceized).


enum EffectKind {
	REVIVE_SHORTEN = 0, ## effect_value = fraction revive time shortened
	DAMAGE_REDUCTION = 1, ## effect_value = fraction damage reduced
	ATTACK_BONUS = 2, ## effect_value = fraction attack damage bonus
	CORPUS_FIND = 3, ## effect_value = flat bonus corpus on kill pickup
}

@export var id: StringName = &""
@export var display_name: String = "遗物"
@export var description: String = ""
@export var price: int = 5
@export var effect_kind: EffectKind = EffectKind.REVIVE_SHORTEN
@export var effect_value: float = 0.15
