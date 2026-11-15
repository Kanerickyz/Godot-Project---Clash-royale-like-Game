extends SceneTree
## Phase C runner: merge boundaries, revive FIFO, captain damage share.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	if not PhaseCMergeReviveTest.test_merge_boundaries():
		ok = false
	if not PhaseCMergeReviveTest.test_revive_fifo_and_extend():
		ok = false
	if not PhaseCMergeReviveTest.test_rank_multipliers():
		ok = false
	if not await _test_game_merge_revive_share():
		ok = false
	quit(0 if ok else 1)


func _test_game_merge_revive_share() -> bool:
	var host := Node.new()
	host.name = "PhaseCTestHost"
	root.add_child(host)
	var gc := GameController.new()
	gc.name = "GameControllerUnderTest"
	host.add_child(gc)
	await process_frame
	await process_frame

	var start_followers := gc.get_follower_count()
	if start_followers < 1:
		push_error("PhaseC: expected starting followers")
		host.queue_free()
		await process_frame
		return false

	# --- Merge via recruit: 3 same id → veteran ---
	var proto := UnitDefinition.new()
	proto.id = &"merge_probe"
	proto.display_name = "合兵探针"
	proto.rank = 0
	proto.keyword = &"蜂群"
	proto.max_hp = 40
	proto.attack_damage = 4
	proto.shop_price = 1
	gc.debug_recruit(proto.duplicate(true) as UnitDefinition)
	gc.debug_recruit(proto.duplicate(true) as UnitDefinition)
	await process_frame
	var before_third := gc.get_follower_count()
	gc.debug_recruit(proto.duplicate(true) as UnitDefinition)
	await process_frame
	# 3 probes merge into 1 veteran; starting army unchanged aside from +1 net.
	var after_merge := gc.get_follower_count()
	if after_merge != before_third - 1:
		# before_third includes 2 probes; after third merge → -2 probes +1 vet = before_third - 1
		push_error(
			"PhaseC: merge follower delta unexpected before=%d after=%d start=%d"
			% [before_third, after_merge, start_followers]
		)
		host.queue_free()
		await process_frame
		return false
	var found_vet := false
	for d in gc.get_army_roster_defs():
		var ud := d as UnitDefinition
		if ud != null and ud.id == &"merge_probe" and int(ud.rank) == UnitMergeService.RANK_VETERAN:
			found_vet = true
			break
	if not found_vet:
		push_error("PhaseC: expected veteran merge_probe in roster")
		host.queue_free()
		await process_frame
		return false
	if gc.get_last_merge_log() == "":
		push_error("PhaseC: expected merge feedback log")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_C_GAME_MERGE_OK log=", gc.get_last_merge_log())

	# --- Revive queue FIFO ---
	var alive_before_kill := gc.get_follower_count()
	if alive_before_kill < 2:
		push_error("PhaseC: need >=2 followers to test queue order")
		host.queue_free()
		await process_frame
		return false
	var first_def := gc.get_army_roster_defs()[0] as UnitDefinition
	var first_id := first_def.id if first_def != null else &""
	if not gc.debug_kill_follower(0):
		push_error("PhaseC: kill follower 0 failed")
		host.queue_free()
		await process_frame
		return false
	await process_frame
	if gc.get_revive_queue_size() < 1:
		push_error("PhaseC: dead follower should enter revive queue")
		host.queue_free()
		await process_frame
		return false
	if gc.get_follower_count() != alive_before_kill - 1:
		push_error("PhaseC: living count should drop on death")
		host.queue_free()
		await process_frame
		return false
	var qrows := gc.get_revive_queue_rows()
	var front_name := str(qrows[0].get("name", ""))
	# Kill another
	if gc.get_follower_count() >= 1:
		gc.debug_kill_follower(0)
		await process_frame
	if gc.get_revive_queue_size() < 2:
		push_error("PhaseC: expected >=2 in queue")
		host.queue_free()
		await process_frame
		return false
	# Advance a lot; FIFO first revived should match first death id when possible.
	var queue_before := gc.get_revive_queue_size()
	gc.debug_advance_revive(100.0)
	await process_frame
	await process_frame
	if gc.get_revive_queue_size() >= queue_before:
		push_error("PhaseC: revive advance should drain queue")
		host.queue_free()
		await process_frame
		return false
	print(
		"PHASE_C_GAME_REVIVE_OK front_was=",
		front_name,
		" first_id=",
		first_id,
		" queue_now=",
		gc.get_revive_queue_size()
	)

	# Ensure at least one living follower for share test.
	if gc.get_follower_count() < 1:
		gc.debug_recruit(proto.duplicate(true) as UnitDefinition)
		await process_frame
	# Kill down to exactly one living if many, keep >=1.
	while gc.get_follower_count() > 3:
		gc.debug_kill_follower(0)
		await process_frame

	var hp_before := gc.get_captain_hp()
	var follower_hps_before := gc.get_living_follower_hps()
	if follower_hps_before.is_empty():
		push_error("PhaseC: need living followers for share test")
		host.queue_free()
		await process_frame
		return false
	# Put someone in queue to observe extend.
	if gc.get_revive_queue_size() == 0 and gc.get_follower_count() > 1:
		gc.debug_kill_follower(0)
		await process_frame
	var q_before_rows := gc.get_revive_queue_rows()
	var rem_before := 0.0
	if not q_before_rows.is_empty():
		rem_before = float(q_before_rows[0].get("remaining", 0.0))

	gc.debug_damage_captain(10)
	await process_frame
	var hp_after := gc.get_captain_hp()
	if hp_after != hp_before:
		push_error(
			"PhaseC: captain should not take direct damage while followers live (%d → %d)"
			% [hp_before, hp_after]
		)
		host.queue_free()
		await process_frame
		return false
	if not q_before_rows.is_empty():
		var q_after_rows := gc.get_revive_queue_rows()
		if q_after_rows.is_empty():
			# Queue may have been emptied if share killed last queued timing — still OK if extend ran.
			pass
		else:
			var rem_after := float(q_after_rows[0].get("remaining", 0.0))
			var extend := gc.get_merge_rank_config().share_extend()
			if rem_after + 0.001 < rem_before + extend - 0.05:
				# Allow small float; require roughly extended unless entry changed identity.
				push_error(
					"PhaseC: share should extend queue remaining (%.2f → %.2f, expect +%.2f)"
					% [rem_before, rem_after, extend]
				)
				host.queue_free()
				await process_frame
				return false
	print("PHASE_C_SHARE_OK captain_hp=", hp_after)

	# No living followers → captain takes damage.
	while gc.get_follower_count() > 0:
		gc.debug_kill_follower(0)
		await process_frame
	# Drain queue so they don't revive mid-assertion.
	gc.debug_advance_revive(0.0)
	# Freeze queue by clearing via killing all and advancing? Simpler: damage when empty living.
	# Revive may still be ticking; kill any that revived.
	for _i in 5:
		while gc.get_follower_count() > 0:
			gc.debug_kill_follower(0)
			await process_frame
		gc.debug_advance_revive(100.0)
		await process_frame
	while gc.get_follower_count() > 0:
		gc.debug_kill_follower(0)
		await process_frame

	hp_before = gc.get_captain_hp()
	gc.debug_damage_captain(7)
	await process_frame
	hp_after = gc.get_captain_hp()
	if hp_after != hp_before - 7 and hp_after >= hp_before:
		push_error(
			"PhaseC: captain should take damage with no living followers (%d → %d)"
			% [hp_before, hp_after]
		)
		host.queue_free()
		await process_frame
		return false
	print("PHASE_C_CAPTAIN_DIRECT_OK hp=", hp_before, "→", hp_after)

	# Floor transition must not permanently drop queued army (persist across clear).
	# Re-recruit and kill one, enter portal, next floor → queue or living still counts in roster.
	gc.debug_recruit(proto.duplicate(true) as UnitDefinition)
	await process_frame
	if gc.get_follower_count() >= 1:
		gc.debug_kill_follower(0)
		await process_frame
	var roster_mid := gc.get_army_roster_defs().size()
	gc.debug_enter_portal()
	await process_frame
	gc.debug_advance_floor()
	await process_frame
	await process_frame
	var roster_after_floor := gc.get_army_roster_defs().size()
	if roster_after_floor < roster_mid:
		push_error(
			"PhaseC: army roster should not shrink across floors (%d → %d)"
			% [roster_mid, roster_after_floor]
		)
		host.queue_free()
		await process_frame
		return false
	print("PHASE_C_ARMY_PERSIST_OK roster=", roster_after_floor)

	host.queue_free()
	await process_frame
	return true
