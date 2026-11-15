extends SceneTree
## Phase B runner: interest on interstitial, buy/refresh/level/cap/sell, army persists.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	if not PhaseBShopEconomyTest.test_interest_formula():
		ok = false
	if not PhaseBShopEconomyTest.test_buy_refresh_level_cap_sell():
		ok = false
	if not await _test_game_shop_flow():
		ok = false
	quit(0 if ok else 1)


func _test_game_shop_flow() -> bool:
	var host := Node.new()
	host.name = "PhaseBTestHost"
	root.add_child(host)
	var gc := GameController.new()
	gc.name = "GameControllerUnderTest"
	host.add_child(gc)
	await process_frame
	await process_frame

	var start_gold := gc.get_ducats()
	if start_gold <= 0:
		push_error("PhaseB: expected starting ducats > 0, got %d" % start_gold)
		host.queue_free()
		await process_frame
		return false
	print("PHASE_B_START_DUCATS_OK gold=", start_gold)

	var followers_before := gc.get_follower_count()
	if followers_before < 1:
		push_error("PhaseB: expected starting followers")
		host.queue_free()
		await process_frame
		return false

	# Interest settles on portal enter.
	gc.debug_enter_portal()
	await process_frame
	if gc.get_run_phase() != GameController.RunPhase.INTERSTITIAL:
		push_error("PhaseB: expected INTERSTITIAL")
		host.queue_free()
		await process_frame
		return false
	var interest := gc.get_last_interest()
	var expected_interest := gc.get_shop_economy().calc_interest(start_gold)
	if interest != expected_interest:
		push_error("PhaseB: interest expected %d got %d" % [expected_interest, interest])
		host.queue_free()
		await process_frame
		return false
	if gc.get_ducats() != start_gold + interest:
		push_error(
			"PhaseB: balance after interest expected %d got %d"
			% [start_gold + interest, gc.get_ducats()]
		)
		host.queue_free()
		await process_frame
		return false
	print("PHASE_B_INTEREST_FLOW_OK interest=", interest, " gold=", gc.get_ducats())

	var shop := gc.get_shop_service()
	if shop == null or shop.shelf.is_empty():
		push_error("PhaseB: shop shelf empty after interstitial")
		host.queue_free()
		await process_frame
		return false

	# Refresh.
	var before_refresh := gc.get_ducats()
	var refresh_res := gc.debug_shop_refresh()
	if not bool(refresh_res.get("ok", false)):
		push_error("PhaseB: refresh failed %s" % str(refresh_res))
		host.queue_free()
		await process_frame
		return false
	if gc.get_ducats() != before_refresh - int(refresh_res.get("cost", 0)):
		push_error("PhaseB: refresh did not deduct correctly")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_B_REFRESH_OK gold=", gc.get_ducats())

	# Recruit level.
	var before_up := gc.get_ducats()
	var up_res := gc.debug_shop_upgrade()
	if not bool(up_res.get("ok", false)):
		# Give money if somehow short.
		gc.debug_add_ducats(50)
		before_up = gc.get_ducats()
		up_res = gc.debug_shop_upgrade()
	if not bool(up_res.get("ok", false)):
		push_error("PhaseB: upgrade failed %s" % str(up_res))
		host.queue_free()
		await process_frame
		return false
	if shop.recruit_level < 2:
		push_error("PhaseB: recruit level should be >= 2, got %d" % shop.recruit_level)
		host.queue_free()
		await process_frame
		return false
	if gc.get_ducats() != before_up - int(up_res.get("cost", 0)):
		push_error("PhaseB: upgrade cost mismatch")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_B_UPGRADE_OK level=", shop.recruit_level)

	# Buy a unit (ensure funds).
	gc.debug_add_ducats(30)
	var types_before := gc.get_army_type_ids().duplicate()
	var buy_slot := -1
	for i in shop.shelf.size():
		var slot: Dictionary = shop.shelf[i]
		if bool(slot.get("sold_out", false)):
			continue
		buy_slot = i
		break
	if buy_slot < 0:
		gc.debug_shop_refresh()
		buy_slot = 0
	var followers_mid := gc.get_follower_count()
	var buy_res := gc.debug_shop_buy(buy_slot)
	if not bool(buy_res.get("ok", false)):
		# If type cap somehow, sell one first then buy existing type.
		push_error("PhaseB: buy failed %s (types=%s)" % [str(buy_res), str(types_before)])
		host.queue_free()
		await process_frame
		return false
	if gc.get_follower_count() != followers_mid + 1:
		push_error("PhaseB: follower count should rise after buy")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_B_BUY_OK followers=", gc.get_follower_count())

	# Type cap rejection: fill unique types to cap then force new id on shelf.
	var cap := gc.get_shop_economy().max_unit_types
	var owned := gc.get_army_type_ids()
	# Sell extras of duplicate types if any, then buy until near cap — simpler: force shelf.
	while shop.count_unique_types(owned) < cap:
		var filler_id := StringName("fill_%d" % shop.count_unique_types(owned))
		# If already at followers with unique < cap, inject buy of new type via shelf force.
		shop.shelf[0] = {
			"unit": _make_unit(filler_id, 1, 1),
			"price": 1,
			"sold_out": false,
		}
		gc.debug_add_ducats(5)
		var fill_buy := gc.debug_shop_buy(0)
		if not bool(fill_buy.get("ok", false)):
			push_error("PhaseB: failed filling types %s owned=%s" % [str(fill_buy), str(owned)])
			host.queue_free()
			await process_frame
			return false
		owned = gc.get_army_type_ids()
	shop.shelf[0] = {
		"unit": _make_unit(&"overflow_type", 1, 1),
		"price": 1,
		"sold_out": false,
	}
	gc.debug_add_ducats(5)
	var cap_res := gc.debug_shop_buy(0)
	if bool(cap_res.get("ok", true)) or cap_res.get("code") != ShopService.RESULT_TYPE_CAP:
		push_error("PhaseB: expected TYPE_CAP in flow, got %s (types=%d)" % [
			str(cap_res),
			shop.count_unique_types(gc.get_army_type_ids()),
		])
		host.queue_free()
		await process_frame
		return false
	print("PHASE_B_TYPE_CAP_OK types=", shop.count_unique_types(gc.get_army_type_ids()))

	# Sell one follower.
	var sell_count_before := gc.get_follower_count()
	var gold_before_sell := gc.get_ducats()
	var sell_res := gc.debug_shop_sell(0)
	if not bool(sell_res.get("ok", false)):
		push_error("PhaseB: sell failed %s" % str(sell_res))
		host.queue_free()
		await process_frame
		return false
	if gc.get_follower_count() != sell_count_before - 1:
		push_error("PhaseB: sell should remove one follower")
		host.queue_free()
		await process_frame
		return false
	if gc.get_ducats() < gold_before_sell:
		push_error("PhaseB: sell should increase or keep ducats")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_B_SELL_OK gold=", gc.get_ducats(), " followers=", gc.get_follower_count())

	var army_after_shop := gc.get_follower_count()

	# Next floor: army persists, shop closes, floor advances.
	gc.debug_advance_floor()
	await process_frame
	await process_frame
	if gc.get_run_phase() != GameController.RunPhase.FLOOR:
		push_error("PhaseB: expected FLOOR after next")
		host.queue_free()
		await process_frame
		return false
	if gc.get_floor_index() != 2:
		push_error("PhaseB: expected floor 2")
		host.queue_free()
		await process_frame
		return false
	if gc.get_follower_count() != army_after_shop:
		push_error(
			"PhaseB: army should persist across floors (%d vs %d)"
			% [army_after_shop, gc.get_follower_count()]
		)
		host.queue_free()
		await process_frame
		return false
	print("PHASE_B_ARMY_PERSIST_OK floor=", gc.get_floor_index(), " followers=", gc.get_follower_count())

	host.queue_free()
	await process_frame
	return true


func _make_unit(id: StringName, price: int, rarity: int) -> UnitDefinition:
	var u := UnitDefinition.new()
	u.id = id
	u.display_name = str(id)
	u.shop_price = price
	u.rarity_tier = rarity
	u.max_hp = 10
	u.attack_damage = 1
	return u
