class_name MetaProgressConfig
extends Resource
## Phase G tunables: skill-point awards, characters, skill-tree nodes.


@export_group("Skill Points")
@export var victory_skill_points: int = 3
@export var defeat_skill_points: int = 1

@export_group("Save")
## Relative to user:// ; service prefixes user:// when needed.
@export var save_file_name: String = "meta_progress.save"

@export_group("Unlock Challenges")
## Unlock id granted on victory (challenge-style unlock for second character).
@export var victory_unlock_id: StringName = &"clear_run"

@export_group("Roster")
@export var characters: Array[MetaCharacterDef] = []
@export var skill_nodes: Array[MetaSkillNodeDef] = []


func skill_points_for_outcome(won: bool) -> int:
	return maxi(0, victory_skill_points if won else defeat_skill_points)


func find_character(character_id: StringName) -> MetaCharacterDef:
	for c in characters:
		if c != null and c.id == character_id:
			return c
	return null


func find_skill_node(node_id: StringName) -> MetaSkillNodeDef:
	for n in skill_nodes:
		if n != null and n.id == node_id:
			return n
	return null


func default_character_id() -> StringName:
	for c in characters:
		if c != null and c.unlocked_by_default and c.id != &"":
			return c.id
	for c in characters:
		if c != null and c.id != &"":
			return c.id
	return &""


## Built-in Phase G minimal roster (used when .tres missing or for tests).
static func make_default() -> MetaProgressConfig:
	var cfg := MetaProgressConfig.new()
	cfg.victory_skill_points = 3
	cfg.defeat_skill_points = 1
	cfg.save_file_name = "meta_progress.save"
	cfg.victory_unlock_id = &"clear_run"

	var warden := MetaCharacterDef.new()
	warden.id = &"warden"
	warden.display_name = "守墓人"
	warden.description = "均衡开局，默认解锁"
	warden.unlocked_by_default = true
	warden.unlock_id = &"char_warden"
	warden.lock_reason = ""
	warden.base_starting_hp_bonus = 0
	warden.base_starting_ducats_bonus = 0

	var iron := MetaCharacterDef.new()
	iron.id = &"iron_captain"
	iron.display_name = "铁壁队长"
	iron.description = "偏重生存；通关后解锁"
	iron.unlocked_by_default = false
	iron.unlock_id = &"clear_run"
	iron.lock_reason = "通关任意地城后解锁"
	iron.base_starting_hp_bonus = 15
	iron.base_starting_ducats_bonus = 0

	cfg.characters.clear()
	cfg.characters.append(warden)
	cfg.characters.append(iron)

	var hp1 := MetaSkillNodeDef.new()
	hp1.id = &"warden_hp_1"
	hp1.display_name = "韧骨 I"
	hp1.description = "开局指挥官生命 +10"
	hp1.cost = 1
	hp1.character_id = &"warden"
	hp1.effect_kind = MetaSkillNodeDef.EffectKind.STARTING_HP
	hp1.effect_value = 10.0

	var ducat1 := MetaSkillNodeDef.new()
	ducat1.id = &"warden_ducats_1"
	ducat1.display_name = "窖藏 I"
	ducat1.description = "开局达克特 +5"
	ducat1.cost = 1
	ducat1.character_id = &"warden"
	ducat1.requires = PackedStringArray(["warden_hp_1"])
	ducat1.effect_kind = MetaSkillNodeDef.EffectKind.STARTING_DUCATS
	ducat1.effect_value = 5.0

	var iron_hp := MetaSkillNodeDef.new()
	iron_hp.id = &"iron_hp_1"
	iron_hp.display_name = "铁壁根骨"
	iron_hp.description = "开局指挥官生命 +20"
	iron_hp.cost = 2
	iron_hp.character_id = &"iron_captain"
	iron_hp.effect_kind = MetaSkillNodeDef.EffectKind.STARTING_HP
	iron_hp.effect_value = 20.0

	cfg.skill_nodes.clear()
	cfg.skill_nodes.append(hp1)
	cfg.skill_nodes.append(ducat1)
	cfg.skill_nodes.append(iron_hp)
	return cfg
