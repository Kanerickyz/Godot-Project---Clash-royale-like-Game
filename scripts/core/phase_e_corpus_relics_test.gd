class_name PhaseECorpusRelicsTest
extends RefCounted
## Phase E pure logic: corpus shop buy/refresh, slots full, revive shorten hook.


static func _make_relic(
	id: StringName,
	price: int,
	kind: RelicDefinition.EffectKind,
	value: float
) -> RelicDefinition:
	var r := RelicDefinition.new()
	r.id = id
	r.display_name = str(id)
	r.description = "test"
	r.price = price
	r.effect_kind = kind
	r.effect_value = value
	return r


static func _make_service(max_slots: int = 2, refresh_cost: int = 2) -> RelicService:
	var cfg := CorpusRelicsConfig.new()
	cfg.max_relic_slots = max_slots
	cfg.relic_shelf_slot_count = 3
	cfg.relic_refresh_cost = refresh_cost
	var pool: Array[RelicDefinition] = [
		_make_relic(&"bone", 5, RelicDefinition.EffectKind.REVIVE_SHORTEN, 0.2),
		_make_relic(&"iron", 6, RelicDefinition.EffectKind.DAMAGE_REDUCTION, 0.1),
		_make_relic(&"greed", 4, RelicDefinition.EffectKind.CORPUS_FIND, 1.0),
	]
	var svc := RelicService.new()
	svc.configure(cfg, pool)
	return svc


static func test_buy_refresh_and_rejects() -> bool:
	var svc := _make_service(2, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	svc.roll_shelf(rng)
	if svc.shelf.size() < 1:
		push_error("PhaseE: shelf should roll at least 1")
		return false

	# Not enough corpus.
	var poor := svc.try_buy(0, 0)
	if bool(poor.get("ok", true)) or poor.get("code") != RelicService.RESULT_NOT_ENOUGH:
		push_error("PhaseE: expected NOT_ENOUGH, got %s" % str(poor))
		return false

	# Buy until slots full then reject.
	svc.shelf[0] = {
		"relic": _make_relic(&"a", 1, RelicDefinition.EffectKind.REVIVE_SHORTEN, 0.2),
		"price": 1,
		"sold_out": false,
	}
	svc.shelf[1] = {
		"relic": _make_relic(&"b", 1, RelicDefinition.EffectKind.DAMAGE_REDUCTION, 0.1),
		"price": 1,
		"sold_out": false,
	}
	svc.shelf[2] = {
		"relic": _make_relic(&"c", 1, RelicDefinition.EffectKind.ATTACK_BONUS, 0.1),
		"price": 1,
		"sold_out": false,
	}
	var buy0 := svc.try_buy(0, 10)
	if not bool(buy0.get("ok", false)):
		push_error("PhaseE: buy0 failed %s" % str(buy0))
		return false
	var buy1 := svc.try_buy(1, 10)
	if not bool(buy1.get("ok", false)):
		push_error("PhaseE: buy1 failed %s" % str(buy1))
		return false
	if svc.owned_count() != 2:
		push_error("PhaseE: expected 2 owned, got %d" % svc.owned_count())
		return false
	var full := svc.try_buy(2, 10)
	if bool(full.get("ok", true)) or full.get("code") != RelicService.RESULT_SLOTS_FULL:
		push_error("PhaseE: expected SLOTS_FULL, got %s" % str(full))
		return false

	# Refresh costs corpus.
	var refresh_poor := svc.try_refresh(0, rng)
	if bool(refresh_poor.get("ok", true)) or refresh_poor.get("code") != RelicService.RESULT_NOT_ENOUGH:
		push_error("PhaseE: refresh should NOT_ENOUGH, got %s" % str(refresh_poor))
		return false
	var refresh_ok := svc.try_refresh(5, rng)
	if not bool(refresh_ok.get("ok", false)):
		push_error("PhaseE: refresh failed %s" % str(refresh_ok))
		return false
	if int(refresh_ok.get("cost", 0)) != 2:
		push_error("PhaseE: refresh cost expected 2")
		return false
	if svc.shelf.is_empty():
		push_error("PhaseE: shelf empty after refresh")
		return false
	print("PHASE_E_BUY_REFRESH_REJECT_OK owned=", svc.owned_count())
	return true


static func test_revive_shorten_hook() -> bool:
	var svc := _make_service(3, 2)
	if absf(svc.revive_time_multiplier() - 1.0) > 0.001:
		push_error("PhaseE: empty inventory revive mult should be 1")
		return false
	svc.inventory.append(
		_make_relic(&"bone", 5, RelicDefinition.EffectKind.REVIVE_SHORTEN, 0.2)
	)
	var mult := svc.revive_time_multiplier()
	if absf(mult - 0.8) > 0.001:
		push_error("PhaseE: revive mult expected 0.8 got %s" % str(mult))
		return false
	svc.inventory.append(
		_make_relic(&"bone2", 5, RelicDefinition.EffectKind.REVIVE_SHORTEN, 0.25)
	)
	mult = svc.revive_time_multiplier()
	# 0.8 * 0.75 = 0.6
	if absf(mult - 0.6) > 0.001:
		push_error("PhaseE: stacked revive mult expected 0.6 got %s" % str(mult))
		return false
	print("PHASE_E_REVIVE_HOOK_OK mult=", mult)
	return true


static func test_drop_pool_helpers() -> bool:
	var cfg := CorpusRelicsConfig.new()
	cfg.kill_corpus_min = 1
	cfg.kill_corpus_max = 1
	cfg.elite_corpus_min = 5
	cfg.elite_corpus_max = 5
	cfg.chest_corpus_chance = 1.0
	cfg.chest_corpus_min = 3
	cfg.chest_corpus_max = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	if cfg.roll_kill_corpus(rng, false) != 1:
		push_error("PhaseE: kill corpus expected 1")
		return false
	if cfg.roll_kill_corpus(rng, true) != 5:
		push_error("PhaseE: elite corpus expected 5")
		return false
	if cfg.roll_chest_corpus(rng) != 3:
		push_error("PhaseE: chest corpus expected 3")
		return false
	print("PHASE_E_DROP_POOL_OK")
	return true
