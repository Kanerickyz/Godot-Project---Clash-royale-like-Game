class_name OathService
extends RefCounted
## Phase D: champion keyword counts → oath tiers + combat/revive multipliers.


var catalog: Array[OathDefinition] = []


func configure(defs: Array[OathDefinition]) -> void:
	catalog.clear()
	for d in defs:
		if d != null:
			catalog.append(d)


func count_champions_by_keyword(roster_defs: Array) -> Dictionary:
	## StringName keyword → champion count in army roster domain.
	var counts: Dictionary = {}
	for item in roster_defs:
		var def := item as UnitDefinition
		if def == null:
			continue
		if int(def.rank) < UnitMergeService.RANK_CHAMPION:
			continue
		var kw := def.keyword
		if kw == &"":
			continue
		counts[kw] = int(counts.get(kw, 0)) + 1
	return counts


func count_for_keyword(roster_defs: Array, keyword: StringName) -> int:
	if keyword == &"":
		return 0
	var counts := count_champions_by_keyword(roster_defs)
	return int(counts.get(keyword, 0))


func find_oath(oath_id: StringName) -> OathDefinition:
	for o in catalog:
		if o != null and o.id == oath_id:
			return o
	return null


func find_oath_by_keyword(keyword: StringName) -> OathDefinition:
	for o in catalog:
		if o != null and o.keyword == keyword:
			return o
	return null


func tier_for_oath(oath: OathDefinition, roster_defs: Array) -> int:
	if oath == null:
		return 0
	return oath.tier_for_count(count_for_keyword(roster_defs, oath.keyword))


func tier_for_id(oath_id: StringName, roster_defs: Array) -> int:
	return tier_for_oath(find_oath(oath_id), roster_defs)


func build_hud_rows(roster_defs: Array) -> Array:
	var rows: Array = []
	var counts := count_champions_by_keyword(roster_defs)
	for oath in catalog:
		if oath == null:
			continue
		var count := int(counts.get(oath.keyword, 0))
		var tier := oath.tier_for_count(count)
		var next_need := oath.next_threshold(count)
		rows.append({
			"id": oath.id,
			"name": oath.display_name,
			"keyword": oath.keyword,
			"count": count,
			"tier": tier,
			"max_tier": oath.max_tier(),
			"next_threshold": next_need,
			"thresholds": oath.thresholds.duplicate(),
			"lit": tier > 0,
		})
	return rows


func damage_taken_multiplier(roster_defs: Array, unit_keyword: StringName = &"") -> float:
	## 1.0 = full damage; lower = iron-wall style DR.
	var mult := 1.0
	for oath in catalog:
		if oath == null or oath.effect_kind != OathDefinition.EffectKind.DAMAGE_REDUCTION:
			continue
		var tier := tier_for_oath(oath, roster_defs)
		if tier <= 0:
			continue
		if oath.scope == OathDefinition.Scope.KEYWORD and unit_keyword != oath.keyword:
			continue
		var reduced := oath.primary_for_tier(tier)
		mult *= maxf(0.05, 1.0 - reduced)
	return mult


func revive_time_multiplier(roster_defs: Array) -> float:
	var mult := 1.0
	for oath in catalog:
		if oath == null or oath.effect_kind != OathDefinition.EffectKind.REVIVE_SHORTEN:
			continue
		var tier := tier_for_oath(oath, roster_defs)
		if tier <= 0:
			continue
		var shortened := oath.primary_for_tier(tier)
		mult *= maxf(0.05, 1.0 - shortened)
	return mult


func ranged_damage_multiplier(roster_defs: Array) -> float:
	var mult := 1.0
	for oath in catalog:
		if oath == null or oath.effect_kind != OathDefinition.EffectKind.RANGED_COMBAT:
			continue
		var tier := tier_for_oath(oath, roster_defs)
		if tier <= 0:
			continue
		mult *= 1.0 + oath.primary_for_tier(tier)
	return mult


func ranged_interval_multiplier(roster_defs: Array) -> float:
	## Lower = faster attacks.
	var mult := 1.0
	for oath in catalog:
		if oath == null or oath.effect_kind != OathDefinition.EffectKind.RANGED_COMBAT:
			continue
		var tier := tier_for_oath(oath, roster_defs)
		if tier <= 0:
			continue
		mult *= maxf(0.05, 1.0 - oath.secondary_for_tier(tier))
	return mult


func applies_ranged_to(unit_keyword: StringName) -> bool:
	for oath in catalog:
		if oath == null or oath.effect_kind != OathDefinition.EffectKind.RANGED_COMBAT:
			continue
		if oath.scope == OathDefinition.Scope.ARMY:
			return true
		if unit_keyword == oath.keyword:
			return true
	return false
