class_name EffectAction
extends Resource

enum Type {
	MODIFY_STAT,
	HEAL,
	SPAWN_UNIT,
	DEAL_DAMAGE,
	SET_HP_FROM_ALLY_PERCENT,
	GRANT_GOLD,
	PERMANENT_DECK_STAT,
	STOCK_FREE_BUFF,
	SHOP_CHARACTER_BONUS_HP,
	APPLY_CELL_EFFECT,
	FRIENDS_HURT_AOE,
	SWAP_POSITIONS,
	SPLIT_SELF,
	FUSE_EXPLODE,
}

enum DamageMode { FIXED, OWNER_ATTACK_PERCENT }

@export var action_type: Type = Type.MODIFY_STAT
@export var stat_name: StringName = &"attack"
@export var value: int = 0
@export var damage_mode: DamageMode = DamageMode.FIXED
@export_range(0, 200, 1) var percent: int = 100
@export var spawn_unit: UnitData
@export var spawn_hp_override: int = 0
@export_range(1, 8, 1) var spawn_count: int = 1
@export var buff_card: BuffCardData
@export var cell_effect: CellEffectData
@export_range(0, 3, 1) var radius: int = 1
@export var include_center: bool = true
@export_range(0, 16, 1) var threshold: int = 0
