class_name PhaseBShopEconomyTest
extends RefCounted
## Phase B pure logic: interest, buy/refresh/level, type cap, sell refund.


static func _make_unit(id: StringName, price: int, rarity: int = 1) -> UnitDefinition:
	var u := UnitDefinition.new()
	u.id = id
	u.display_name = str(id)
	u.shop_price = price
	u.rarity_tier = rarity
	u.max_hp = 10
	u.attack_damage = 1
	return u


static func _make_cfg() -> ShopEconomyConfig:
	var cfg := ShopEconomyConfig.new()
	cfg.starting_ducats = 20
	cfg.interest_gold_per_point = 10
	cfg.interest_max = 5
	cfg.shelf_slot_count = 3
	cfg.refresh_cost = 2
	cfg.max_unit_types = 6
	cfg.sell_refund_ratio = 0.5
	cfg.rarity_prices = PackedInt32Array([3, 5, 8])
	cfg.recruit_level_min = 1
	cfg.recruit_level_max = 5
	cfg.recruit_upgrade_costs = PackedInt32Array([4, 6, 8, 10])
	cfg.rarity_weights_by_level = PackedInt32Array([
		100, 0, 0,
		0, 100, 0,
		0, 0, 100,
		0, 0, 100,
		0, 0, 100,
	])
	return cfg


static func test_interest_formula() -> bool:
	var cfg := _make_cfg()
	if cfg.calc_interest(0) != 0:
		push_error("PhaseB: interest(0) expected 0")
		return false
	if cfg.calc_interest(9) != 0:
		push_error("PhaseB: interest(9) expected 0 got %d" % cfg.calc_interest(9))
		return false
	if cfg.calc_interest(10) != 1:
		push_error("PhaseB: interest(10) expected 1")
		return false
	if cfg.calc_interest(49) != 4:
		push_error("PhaseB: interest(49) expected 4 got %d" % cfg.calc_interest(49))
		return false
	if cfg.calc_interest(100) != 5:
		push_error("PhaseB: interest(100) expected cap 5 got %d" % cfg.calc_interest(100))
		return false
	print("PHASE_B_INTEREST_OK")
	return true


static func test_buy_refresh_level_cap_sell() -> bool:
	var cfg := _make_cfg()
	var pool: Array[UnitDefinition] = [
		_make_unit(&"a", 3, 1),
		_make_unit(&"b", 3, 1),
		_make_unit(&"c", 3, 1),
		_make_unit(&"d", 5, 2),
		_make_unit(&"e", 5, 2),
		_make_unit(&"f", 8, 3),
		_make_unit(&"g", 8, 3),
	]
	var shop := ShopService.new()
	shop.configure(cfg, pool)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	shop.roll_shelf(rng)
	if shop.shelf.size() != 3:
		push_error("PhaseB: expected 3 shelf slots got %d" % shop.shelf.size())
		return false

	# Not enough money.
	var owned: Array = [&"a", &"b", &"c"]
	var poor := shop.try_buy(0, 0, owned)
	if bool(poor.get("ok", true)) or poor.get("code") != ShopService.RESULT_NOT_ENOUGH:
		push_error("PhaseB: expected NOT_ENOUGH buy, got %s" % str(poor))
		return false

	# Successful buy.
	var price := int(shop.shelf[0].get("price", 0))
	var ok_buy := shop.try_buy(0, price, owned)
	if not bool(ok_buy.get("ok", false)):
		push_error("PhaseB: expected successful buy, got %s" % str(ok_buy))
		return false
	var bought: UnitDefinition = ok_buy.get("unit") as UnitDefinition
	if bought == null:
		push_error("PhaseB: buy returned null unit")
		return false
	owned.append(bought.id)

	# Refresh costs.
	var refresh_fail := shop.try_refresh(0, rng)
	if bool(refresh_fail.get("ok", true)) or refresh_fail.get("code") != ShopService.RESULT_NOT_ENOUGH:
		push_error("PhaseB: expected refresh NOT_ENOUGH")
		return false
	var refresh_ok := shop.try_refresh(10, rng)
	if not bool(refresh_ok.get("ok", false)) or int(refresh_ok.get("cost", -1)) != 2:
		push_error("PhaseB: refresh failed %s" % str(refresh_ok))
		return false

	# Recruit level upgrade.
	var up_fail := shop.try_upgrade_recruit(0)
	if bool(up_fail.get("ok", true)) or up_fail.get("code") != ShopService.RESULT_NOT_ENOUGH:
		push_error("PhaseB: expected upgrade NOT_ENOUGH")
		return false
	var up_ok := shop.try_upgrade_recruit(20)
	if not bool(up_ok.get("ok", false)) or int(up_ok.get("level", 0)) != 2:
		push_error("PhaseB: upgrade to Lv2 failed %s" % str(up_ok))
		return false

	# Type cap: fill to 6 unique then reject new type.
	owned = [&"t1", &"t2", &"t3", &"t4", &"t5", &"t6"]
	shop.roll_shelf(rng)
	# Force a shelf unit with a new id if needed.
	var new_unit := _make_unit(&"t7", 3, 1)
	shop.shelf[0] = {"unit": new_unit, "price": 3, "sold_out": false}
	var cap := shop.try_buy(0, 100, owned)
	if bool(cap.get("ok", true)) or cap.get("code") != ShopService.RESULT_TYPE_CAP:
		push_error("PhaseB: expected TYPE_CAP, got %s" % str(cap))
		return false
	# Same type still OK.
	shop.shelf[0] = {"unit": _make_unit(&"t1", 3, 1), "price": 3, "sold_out": false}
	var same := shop.try_buy(0, 100, owned)
	if not bool(same.get("ok", false)):
		push_error("PhaseB: same-type buy under cap should succeed, got %s" % str(same))
		return false

	# Sell refund.
	var refund := shop.sell_refund(_make_unit(&"x", 8, 3))
	if refund != 4:
		push_error("PhaseB: sell refund expected 4 got %d" % refund)
		return false

	print("PHASE_B_SHOP_LOGIC_OK")
	return true
