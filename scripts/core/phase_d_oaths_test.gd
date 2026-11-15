class_name PhaseDOathsTest
extends RefCounted
## Phase D pure logic: keyword counts, thresholds, effect multipliers.


static func _champ(id: StringName, keyword: StringName) -> UnitDefinition:
	var u := UnitDefinition.new()
	u.id = id
	u.display_name = str(id)
	u.rank = UnitMergeService.RANK_CHAMPION
	u.keyword = keyword
	u.max_hp = 40
	u.attack_damage = 6
	return u


static func _recruit(id: StringName, keyword: StringName = &"") -> UnitDefinition:
	var u := UnitDefinition.new()
	u.id = id
	u.display_name = str(id)
	u.rank = UnitMergeService.RANK_RECRUIT
	u.keyword = keyword
	u.max_hp = 30
	u.attack_damage = 4
	return u


static func _make_service() -> OathService:
	var svc := OathService.new()
	var iron := OathDefinition.new()
	iron.id = &"iron_wall"
	iron.display_name = "铁壁誓约"
	iron.keyword = &"先锋"
	iron.thresholds = PackedInt32Array([2, 4])
	iron.effect_kind = OathDefinition.EffectKind.DAMAGE_REDUCTION
	iron.scope = OathDefinition.Scope.ARMY
	iron.tier_primary = PackedFloat32Array([0.12, 0.22])
	var bones := OathDefinition.new()
	bones.id = &"myriad_bones"
	bones.display_name = "万骨誓约"
	bones.keyword = &"蜂群"
	bones.thresholds = PackedInt32Array([2, 4])
	bones.effect_kind = OathDefinition.EffectKind.REVIVE_SHORTEN
	bones.scope = OathDefinition.Scope.ARMY
	bones.tier_primary = PackedFloat32Array([0.2, 0.35])
	var bow := OathDefinition.new()
	bow.id = &"taut_bow"
	bow.display_name = "劲弦誓约"
	bow.keyword = &"射术"
	bow.thresholds = PackedInt32Array([2, 4])
	bow.effect_kind = OathDefinition.EffectKind.RANGED_COMBAT
	bow.scope = OathDefinition.Scope.KEYWORD
	bow.tier_primary = PackedFloat32Array([0.15, 0.28])
	bow.tier_secondary = PackedFloat32Array([0.1, 0.2])
	var defs: Array[OathDefinition] = [iron, bones, bow]
	svc.configure(defs)
	return svc


static func test_count_and_tiers() -> bool:
	var svc := _make_service()
	var roster: Array = [
		_champ(&"a", &"先锋"),
		_recruit(&"b", &"先锋"),
		_champ(&"c", &"蜂群"),
	]
	if svc.count_for_keyword(roster, &"先锋") != 1:
		push_error("PhaseD: recruit must not count; expected 1 先锋 champion")
		return false
	if svc.tier_for_id(&"iron_wall", roster) != 0:
		push_error("PhaseD: iron wall should be dark at 1")
		return false
	roster.append(_champ(&"d", &"先锋"))
	if svc.count_for_keyword(roster, &"先锋") != 2:
		push_error("PhaseD: expected 2 先锋 champions")
		return false
	if svc.tier_for_id(&"iron_wall", roster) != 1:
		push_error("PhaseD: iron wall tier1 at 2")
		return false
	roster.append(_champ(&"e", &"先锋"))
	roster.append(_champ(&"f", &"先锋"))
	if svc.tier_for_id(&"iron_wall", roster) != 2:
		push_error("PhaseD: iron wall tier2 at 4")
		return false
	print("PHASE_D_COUNT_TIER_OK")
	return true


static func test_effect_multipliers() -> bool:
	var svc := _make_service()
	var dark: Array = [_champ(&"a", &"先锋")]
	if absf(svc.damage_taken_multiplier(dark) - 1.0) > 0.001:
		push_error("PhaseD: DR should be 1 when dark")
		return false
	var lit: Array = [_champ(&"a", &"先锋"), _champ(&"b", &"先锋")]
	var dr := svc.damage_taken_multiplier(lit)
	if absf(dr - 0.88) > 0.001:
		push_error("PhaseD: expected DR 0.88 got %s" % dr)
		return false
	var swarm: Array = [_champ(&"s1", &"蜂群"), _champ(&"s2", &"蜂群")]
	var rv := svc.revive_time_multiplier(swarm)
	if absf(rv - 0.8) > 0.001:
		push_error("PhaseD: expected revive mult 0.8 got %s" % rv)
		return false
	var ranged: Array = [_champ(&"r1", &"射术"), _champ(&"r2", &"射术")]
	var dmg := svc.ranged_damage_multiplier(ranged)
	var iv := svc.ranged_interval_multiplier(ranged)
	if absf(dmg - 1.15) > 0.001:
		push_error("PhaseD: expected ranged dmg 1.15 got %s" % dmg)
		return false
	if absf(iv - 0.9) > 0.001:
		push_error("PhaseD: expected ranged interval 0.9 got %s" % iv)
		return false
	print("PHASE_D_EFFECT_MULT_OK")
	return true


static func test_hud_rows() -> bool:
	var svc := _make_service()
	var roster: Array = [
		_champ(&"a", &"先锋"),
		_champ(&"b", &"先锋"),
	]
	var rows := svc.build_hud_rows(roster)
	if rows.size() != 3:
		push_error("PhaseD: expected 3 oath rows")
		return false
	var iron: Dictionary = rows[0]
	if not bool(iron.get("lit", false)) or int(iron.get("tier", 0)) != 1:
		push_error("PhaseD: iron row should be lit T1")
		return false
	if int(iron.get("count", 0)) != 2 or int(iron.get("next_threshold", 0)) != 4:
		push_error("PhaseD: iron progress 2/4 expected")
		return false
	print("PHASE_D_HUD_ROWS_OK")
	return true
