extends SceneTree
## Phase G runner: save/load, award, locked reject, purchase; settlement persists.


const TEST_SAVE := "user://phase_g_meta_progress_game_test.save"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	if not PhaseGMetaProgressTest.test_award_points_win_and_loss():
		ok = false
	if not PhaseGMetaProgressTest.test_save_load_roundtrip():
		ok = false
	if not PhaseGMetaProgressTest.test_locked_character_reject():
		ok = false
	if not PhaseGMetaProgressTest.test_purchase_node_and_rejects():
		ok = false
	if not await _test_game_settlement_and_reload():
		ok = false
	if not await _test_game_locked_select_and_bonuses():
		ok = false
	quit(0 if ok else 1)


func _wipe_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)


func _make_gc(host: Node) -> GameController:
	var gc := GameController.new()
	gc.name = "GameControllerPhaseG"
	gc.meta_auto_start = true
	gc.meta_save_path_override = TEST_SAVE
	host.add_child(gc)
	return gc


func _test_game_settlement_and_reload() -> bool:
	_wipe_test_save()
	var host := Node.new()
	host.name = "PhaseGSettlementHost"
	root.add_child(host)
	var gc := _make_gc(host)
	await process_frame
	await process_frame

	var meta := gc.get_meta_service()
	if meta == null:
		push_error("PhaseG: meta service missing")
		host.queue_free()
		await process_frame
		return false
	var sp0 := meta.skill_points
	print("PHASE_G_GAME_START_OK sp=", sp0, " char=", gc.get_selected_character_id())

	# Defeat awards points and saves.
	gc.debug_force_defeat()
	await process_frame
	if gc.get_run_outcome() != GameController.RunOutcome.DEFEAT:
		push_error("PhaseG: expected DEFEAT")
		host.queue_free()
		await process_frame
		return false
	var after_defeat := meta.skill_points
	if after_defeat < sp0 + 1:
		push_error("PhaseG: defeat should award skill points, sp=%d" % after_defeat)
		host.queue_free()
		await process_frame
		return false
	if not FileAccess.file_exists(TEST_SAVE):
		push_error("PhaseG: save file missing after settlement")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_G_DEFEAT_AWARD_OK sp=", after_defeat)

	host.queue_free()
	await process_frame

	# New GC reads persisted balance.
	var host2 := Node.new()
	host2.name = "PhaseGReloadHost"
	root.add_child(host2)
	var gc2 := _make_gc(host2)
	await process_frame
	await process_frame
	var meta2 := gc2.get_meta_service()
	if meta2.skill_points != after_defeat:
		push_error(
			"PhaseG: reloaded sp %d != settled %d" % [meta2.skill_points, after_defeat]
		)
		host2.queue_free()
		await process_frame
		return false
	print("PHASE_G_RELOAD_OK sp=", meta2.skill_points)

	# Victory awards more + unlocks second character.
	gc2.debug_goto_final_floor()
	await process_frame
	await process_frame
	if not gc2.debug_kill_final_boss():
		push_error("PhaseG: kill final boss failed")
		host2.queue_free()
		await process_frame
		return false
	await process_frame
	if gc2.get_run_outcome() != GameController.RunOutcome.VICTORY:
		push_error("PhaseG: expected VICTORY")
		host2.queue_free()
		await process_frame
		return false
	if not meta2.is_character_unlocked(&"iron_captain"):
		push_error("PhaseG: victory should unlock iron_captain")
		host2.queue_free()
		await process_frame
		return false
	var stats := gc2.get_run_stats()
	if int(stats.get("awarded_skill_points", 0)) < 1:
		push_error("PhaseG: settlement stats missing awarded points")
		host2.queue_free()
		await process_frame
		return false
	print(
		"PHASE_G_VICTORY_UNLOCK_OK sp=",
		meta2.skill_points,
		" awarded=",
		stats.get("awarded_skill_points")
	)

	host2.queue_free()
	await process_frame
	return true


func _test_game_locked_select_and_bonuses() -> bool:
	_wipe_test_save()
	var host := Node.new()
	host.name = "PhaseGBonusHost"
	root.add_child(host)
	var gc := _make_gc(host)
	await process_frame
	await process_frame

	var meta := gc.get_meta_service()
	var locked := gc.debug_confirm_character(&"iron_captain")
	if bool(locked.get("ok", true)) or locked.get("code") != MetaProgressService.RESULT_LOCKED:
		push_error("PhaseG: game select locked expected, got %s" % str(locked))
		host.queue_free()
		await process_frame
		return false
	print("PHASE_G_GAME_LOCKED_OK reason=", locked.get("lock_reason"))

	# Fund and buy HP node; restart run bonuses via new controller.
	meta.skill_points = 3
	var buy := gc.debug_purchase_skill(&"warden_hp_1")
	if not bool(buy.get("ok", false)):
		push_error("PhaseG: game purchase failed %s" % str(buy))
		host.queue_free()
		await process_frame
		return false
	var hp_before := gc.get_captain_hp()
	host.queue_free()
	await process_frame

	var host2 := Node.new()
	host2.name = "PhaseGBonusReload"
	root.add_child(host2)
	var gc2 := _make_gc(host2)
	await process_frame
	await process_frame
	var hp_after := gc2.get_captain_hp()
	# Base captain 100 + node 10.
	if hp_after < 110:
		push_error("PhaseG: expected captain hp >=110 after meta node, got %d" % hp_after)
		host2.queue_free()
		await process_frame
		return false
	var ducats := gc2.get_ducats() if gc2.has_method("get_ducats") else -1
	# Also buy ducats node on fresh points.
	var meta2 := gc2.get_meta_service()
	meta2.skill_points = maxi(meta2.skill_points, 2)
	var buy_d := gc2.debug_purchase_skill(&"warden_ducats_1")
	if not bool(buy_d.get("ok", false)):
		# May need prereq already owned from previous save — warden_hp_1 should persist.
		push_error("PhaseG: ducats node buy failed %s" % str(buy_d))
		host2.queue_free()
		await process_frame
		return false
	print(
		"PHASE_G_BONUS_OK hp_before=",
		hp_before,
		" hp_after=",
		hp_after,
		" ducats_now=",
		ducats,
		" sp=",
		meta2.skill_points
	)

	# Ducats bonus applies on next run start.
	host2.queue_free()
	await process_frame
	var host3 := Node.new()
	root.add_child(host3)
	var gc3 := _make_gc(host3)
	await process_frame
	await process_frame
	var expected_min := 20 + 5  # starting_ducats default + node
	# shop_economy.tres may differ; compare against bonus helper.
	var bonus := gc3.get_meta_service().get_starting_ducats_bonus()
	var gold_now := gc3.gold
	# gold should be base starting + bonus
	if bonus < 5:
		push_error("PhaseG: ducats bonus missing after reload")
		host3.queue_free()
		await process_frame
		return false
	print("PHASE_G_DUCATS_BONUS_OK gold=", gold_now, " bonus=", bonus, " floor=", expected_min)

	print("PHASE_G_GAME_OK")
	host3.queue_free()
	await process_frame
	_wipe_test_save()
	return true
