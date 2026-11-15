extends SceneTree
## Phase D runner: champion keyword counts, light/dim oaths, revive still counts.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	if not PhaseDOathsTest.test_count_and_tiers():
		ok = false
	if not PhaseDOathsTest.test_effect_multipliers():
		ok = false
	if not PhaseDOathsTest.test_hud_rows():
		ok = false
	if not await _test_game_oaths():
		ok = false
	if not await _test_shop_pool_first_batch():
		ok = false
	quit(0 if ok else 1)


func _make_champ(id: StringName, keyword: StringName) -> UnitDefinition:
	var u := UnitDefinition.new()
	u.id = id
	u.display_name = str(id)
	u.rank = UnitMergeService.RANK_CHAMPION
	u.keyword = keyword
	u.max_hp = 50
	u.attack_damage = 6
	u.shop_price = 3
	u.attack_range = 80.0
	u.attack_interval = 0.8
	return u


func _test_game_oaths() -> bool:
	var host := Node.new()
	host.name = "PhaseDTestHost"
	root.add_child(host)
	var gc := GameController.new()
	gc.name = "GameControllerUnderTest"
	host.add_child(gc)
	await process_frame
	await process_frame

	if gc.get_oath_tier(&"iron_wall") != 0:
		push_error("PhaseD: iron should start dark")
		host.queue_free()
		await process_frame
		return false

	gc.debug_recruit(_make_champ(&"vanguard_a", &"先锋"))
	gc.debug_recruit(_make_champ(&"vanguard_b", &"先锋"))
	await process_frame
	if gc.get_champion_keyword_count(&"先锋") != 2:
		push_error("PhaseD: expected 2 先锋 champions living")
		host.queue_free()
		await process_frame
		return false
	if gc.get_oath_tier(&"iron_wall") != 1:
		push_error("PhaseD: iron should light at 2")
		host.queue_free()
		await process_frame
		return false
	var dr := gc.get_oath_damage_taken_multiplier()
	if dr >= 0.999:
		push_error("PhaseD: iron DR should apply, got %s" % dr)
		host.queue_free()
		await process_frame
		return false
	print("PHASE_D_GAME_LIGHT_OK tier=", gc.get_oath_tier(&"iron_wall"), " dr=", dr)

	# Kill one champion → still in revive queue → still counts.
	var kill_idx := -1
	var defs := gc.get_army_roster_defs()
	for i in gc.get_follower_count():
		# Find living champion follower index by scanning defs vs followers via kill attempts.
		pass
	# Prefer last recruited: search followers via roster.
	for i in range(gc.get_follower_count() - 1, -1, -1):
		if gc.debug_kill_follower(i):
			kill_idx = i
			break
	await process_frame
	if kill_idx < 0:
		push_error("PhaseD: failed to kill a follower")
		host.queue_free()
		await process_frame
		return false
	if gc.get_revive_queue_size() < 1:
		push_error("PhaseD: expected unit in revive queue")
		host.queue_free()
		await process_frame
		return false
	if gc.get_champion_keyword_count(&"先锋") != 2:
		push_error(
			"PhaseD: queued champion must still count, got %d"
			% gc.get_champion_keyword_count(&"先锋")
		)
		host.queue_free()
		await process_frame
		return false
	if gc.get_oath_tier(&"iron_wall") != 1:
		push_error("PhaseD: iron must stay lit while champion is reviving")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_D_REVIVE_COUNTS_OK")

	# Swarm oath + shortened revive.
	gc.debug_recruit(_make_champ(&"swarm_a", &"蜂群"))
	gc.debug_recruit(_make_champ(&"swarm_b", &"蜂群"))
	await process_frame
	if gc.get_oath_tier(&"myriad_bones") != 1:
		push_error("PhaseD: myriad bones should light at 2")
		host.queue_free()
		await process_frame
		return false
	var base_revive := 8.0
	if gc.get_merge_rank_config() != null:
		base_revive = gc.get_merge_rank_config().base_revive_time()
	var expect_mult := gc.get_oath_revive_time_multiplier()
	# Kill a living swarm champ and check queued remaining ≈ base * mult.
	var killed_swarm := false
	for i in range(gc.get_follower_count() - 1, -1, -1):
		# Kill any living follower; oath mult applies to enqueue.
		if gc.debug_kill_follower(i):
			killed_swarm = true
			break
	await process_frame
	if not killed_swarm:
		push_error("PhaseD: could not kill for revive shorten check")
		host.queue_free()
		await process_frame
		return false
	var rows := gc.get_revive_queue_rows()
	if rows.is_empty():
		push_error("PhaseD: revive queue empty after kill")
		host.queue_free()
		await process_frame
		return false
	# Front may be older death; check any row near expected shortened time for latest.
	var latest: Dictionary = rows[rows.size() - 1]
	var rem := float(latest.get("remaining", 0.0))
	var expected := base_revive * expect_mult
	if absf(rem - expected) > 0.15:
		push_error(
			"PhaseD: revive remaining %.3f expected ~%.3f (base %.3f * mult %.3f)"
			% [rem, expected, base_revive, expect_mult]
		)
		host.queue_free()
		await process_frame
		return false
	print("PHASE_D_REVIVE_SHORTEN_OK rem=", rem)

	# Sell drops count / dims oath (need interstitial).
	gc.debug_enter_portal()
	await process_frame
	if gc.get_run_phase() != GameController.RunPhase.INTERSTITIAL:
		push_error("PhaseD: expected interstitial for sell")
		host.queue_free()
		await process_frame
		return false
	# Sell living 先锋 champions until iron dims.
	var guard := 0
	while gc.get_oath_tier(&"iron_wall") > 0 and guard < 12:
		guard += 1
		var sold := false
		for i in gc.get_follower_count():
			var result := gc.debug_shop_sell(i)
			if bool(result.get("ok", false)):
				sold = true
				break
		if not sold:
			break
		await process_frame
	if gc.get_champion_keyword_count(&"先锋") >= 2:
		push_error("PhaseD: sell should drop living 先锋 champions below 2")
		host.queue_free()
		await process_frame
		return false
	# Queued 先锋 may still keep the oath lit — sell only removes living.
	# Spec: 出售才掉计数; queued still counts. So we must also not have 2+ in queue.
	# If iron still lit solely from queue, that is correct. To force dim, only sell living
	# and ensure total roster 先锋 champs < 2.
	var total_vanguard := gc.get_champion_keyword_count(&"先锋")
	if total_vanguard >= 2 and gc.get_oath_tier(&"iron_wall") < 1:
		push_error("PhaseD: tier/count mismatch")
		host.queue_free()
		await process_frame
		return false
	if total_vanguard < 2 and gc.get_oath_tier(&"iron_wall") != 0:
		push_error("PhaseD: iron should dim when count < 2 after sells")
		host.queue_free()
		await process_frame
		return false
	print(
		"PHASE_D_SELL_DIM_OK count=",
		total_vanguard,
		" tier=",
		gc.get_oath_tier(&"iron_wall")
	)

	# Ranged oath light + multipliers.
	gc.debug_recruit(_make_champ(&"bow_a", &"射术"))
	gc.debug_recruit(_make_champ(&"bow_b", &"射术"))
	await process_frame
	if gc.get_oath_tier(&"taut_bow") != 1:
		push_error("PhaseD: taut bow should light")
		host.queue_free()
		await process_frame
		return false
	if absf(gc.get_oath_ranged_damage_multiplier() - 1.15) > 0.001:
		push_error("PhaseD: ranged dmg mult wrong")
		host.queue_free()
		await process_frame
		return false
	if absf(gc.get_oath_ranged_interval_multiplier() - 0.9) > 0.001:
		push_error("PhaseD: ranged interval mult wrong")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_D_RANGED_OK")

	var hud_rows := gc.get_oath_rows()
	if hud_rows.size() < 3:
		push_error("PhaseD: HUD oath rows missing")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_D_GAME_OK")

	host.queue_free()
	await process_frame
	return true


func _test_shop_pool_first_batch() -> bool:
	var host := Node.new()
	host.name = "PhaseDPoolHost"
	root.add_child(host)
	var gc := GameController.new()
	host.add_child(gc)
	await process_frame
	await process_frame
	var shop := gc.get_shop_service()
	var econ := gc.get_shop_economy()
	if shop == null or econ == null:
		push_error("PhaseD: shop missing")
		host.queue_free()
		await process_frame
		return false
	if econ.pool_unit_paths.size() != 12:
		push_error("PhaseD: expected 12 first-batch pool paths, got %d" % econ.pool_unit_paths.size())
		host.queue_free()
		await process_frame
		return false
	var required := PackedStringArray([
		"skeleton",
		"shield",
		"spear",
		"axe",
		"archer",
		"crossbow",
		"banner",
		"wardrum",
		"horsebow",
		"ram",
		"giant_knight",
		"soulcaller",
	])
	# Existing resources may use ally_* ids; accept either roster id or ally_<id>.
	var pool_ids: Dictionary = {}
	for path in econ.pool_unit_paths:
		var def: UnitDefinition = load(str(path)) as UnitDefinition
		if def == null:
			push_error("PhaseD: pool path failed to load %s" % path)
			host.queue_free()
			await process_frame
			return false
		pool_ids[String(def.id)] = true
		if def.sprite == null:
			push_error("PhaseD: unit %s missing sprite" % def.id)
			host.queue_free()
			await process_frame
			return false
	for need in required:
		var ok_id := pool_ids.has(need) or pool_ids.has("ally_%s" % need)
		if not ok_id:
			push_error("PhaseD: missing first-batch unit id for %s in pool" % need)
			host.queue_free()
			await process_frame
			return false
	print("PHASE_D_POOL_OK size=", econ.pool_unit_paths.size())
	host.queue_free()
	await process_frame
	return true
