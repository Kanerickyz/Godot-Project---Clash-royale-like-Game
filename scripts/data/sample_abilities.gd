class_name SampleAbilities
extends RefCounted

## 运行时构建样本 Ability（与 resources/abilities/*.tres 等价，供测试与编辑器缺失时回退）


static func rage_on_hit() -> AbilityData:
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.MODIFY_STAT
	action.stat_name = &"attack"
	action.value = 2

	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_DAMAGE_TAKEN
	spec.target_selector = EffectSpec.TargetSelector.SELF
	spec.actions = [action]

	var ability := AbilityData.new()
	ability.id = "rage_on_hit"
	ability.effect_specs = [spec]
	ability.display_name = UnitInfoText.get_ability_description(ability)
	return ability


static func spawn_on_death() -> AbilityData:
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.SPAWN_UNIT
	action.spawn_unit = load("res://resources/units/zombie_cricket.tres") as UnitData
	action.spawn_hp_override = 1

	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_DEATH
	spec.target_selector = EffectSpec.TargetSelector.SELF
	spec.actions = [action]

	var ability := AbilityData.new()
	ability.id = "spawn_on_death"
	ability.effect_specs = [spec]
	ability.display_name = UnitInfoText.get_ability_description(ability)
	return ability


static func heal_on_move() -> AbilityData:
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.HEAL
	action.value = 1

	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_MOVE
	spec.target_selector = EffectSpec.TargetSelector.SELF
	spec.actions = [action]

	var ability := AbilityData.new()
	ability.id = "heal_on_move"
	ability.effect_specs = [spec]
	ability.display_name = UnitInfoText.get_ability_description(ability)
	return ability


static func faint_buff_random_ally() -> AbilityData:
	var act_atk := EffectAction.new()
	act_atk.stat_name = &"attack"
	act_atk.value = 1
	var act_hp := EffectAction.new()
	act_hp.stat_name = &"max_hp"
	act_hp.value = 1
	var act_heal := EffectAction.new()
	act_heal.action_type = EffectAction.Type.HEAL
	act_heal.value = 1

	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_DEATH
	spec.target_selector = EffectSpec.TargetSelector.RANDOM_ALLY
	spec.exclude_owner = true
	spec.actions = [act_atk, act_hp, act_heal]

	var ability := AbilityData.new()
	ability.id = "faint_buff_random_ally"
	ability.effect_specs = [spec]
	ability.display_name = UnitInfoText.get_ability_description(ability)
	return ability


static func round_start_hurt_ally() -> AbilityData:
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.DEAL_DAMAGE
	action.value = 1

	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_ROUND_START
	spec.target_selector = EffectSpec.TargetSelector.RANDOM_ALLY
	spec.exclude_owner = true
	spec.actions = [action]

	var ability := AbilityData.new()
	ability.id = "round_start_hurt_ally"
	ability.effect_specs = [spec]
	ability.display_name = UnitInfoText.get_ability_description(ability)
	return ability
