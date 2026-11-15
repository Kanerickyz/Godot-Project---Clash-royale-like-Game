extends SceneTree
## Phase F runner: advance to final floor, boss kill → victory; captain death → defeat.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	if not PhaseFRunVictoryTest.test_floor_run_config_helpers():
		ok = false
	if not PhaseFRunVictoryTest.test_tileset_palettes_differ():
		ok = false
	if not await _test_victory_path():
		ok = false
	if not await _test_defeat_path():
		ok = false
	quit(0 if ok else 1)


func _test_victory_path() -> bool:
	var host := Node.new()
	host.name = "PhaseFVictoryHost"
	root.add_child(host)
	var gc := GameController.new()
	gc.name = "GameControllerVictory"
	host.add_child(gc)
	await process_frame
	await process_frame

	if gc.get_total_floors() < 2:
		push_error("PhaseF: total_floors should be >= 2")
		host.queue_free()
		await process_frame
		return false
	if gc.get_floor_index() != 1 or gc.is_final_floor():
		push_error("PhaseF: start should be floor 1 non-final")
		host.queue_free()
		await process_frame
		return false
	var type1 := gc.get_dungeon_type_id()
	print("PHASE_F_START_OK floor=1 type=", type1, " total=", gc.get_total_floors())

	# Advance through interstitial until final floor.
	gc.debug_goto_final_floor()
	await process_frame
	await process_frame
	if not gc.is_final_floor():
		push_error("PhaseF: expected final floor after goto, got %d" % gc.get_floor_index())
		host.queue_free()
		await process_frame
		return false
	if gc.get_run_phase() != GameController.RunPhase.FLOOR:
		push_error("PhaseF: final floor should be FLOOR phase")
		host.queue_free()
		await process_frame
		return false
	# Portal blocked on final floor.
	gc.debug_enter_portal()
	await process_frame
	if gc.get_run_phase() != GameController.RunPhase.FLOOR:
		push_error("PhaseF: portal must not leave final floor")
		host.queue_free()
		await process_frame
		return false
	var boss := gc.get_final_boss()
	if boss == null or not is_instance_valid(boss) or boss.is_dead:
		push_error("PhaseF: final boss missing on final floor")
		host.queue_free()
		await process_frame
		return false
	print(
		"PHASE_F_FINAL_FLOOR_OK floor=",
		gc.get_floor_index(),
		" type=",
		gc.get_dungeon_type_id(),
		" boss_hp=",
		boss.current_hp
	)

	if not gc.debug_kill_final_boss():
		push_error("PhaseF: debug_kill_final_boss failed")
		host.queue_free()
		await process_frame
		return false
	await process_frame
	await process_frame
	if gc.get_run_outcome() != GameController.RunOutcome.VICTORY:
		push_error("PhaseF: expected VICTORY after boss kill, got %s" % str(gc.get_run_outcome()))
		host.queue_free()
		await process_frame
		return false
	if gc.get_run_phase() != GameController.RunPhase.GAME_OVER:
		push_error("PhaseF: expected GAME_OVER after victory")
		host.queue_free()
		await process_frame
		return false
	var stats: Dictionary = gc.get_run_stats()
	if not bool(stats.get("won", false)):
		push_error("PhaseF: run_stats.won should be true")
		host.queue_free()
		await process_frame
		return false
	if int(stats.get("floors_reached", 0)) != gc.get_total_floors():
		push_error("PhaseF: victory floors_reached should equal total")
		host.queue_free()
		await process_frame
		return false
	print(
		"PHASE_F_VICTORY_OK floors=",
		stats.get("floors_reached"),
		" ducats=",
		stats.get("ducats"),
		" corpus=",
		stats.get("corpus")
	)

	host.queue_free()
	await process_frame
	return true


func _test_defeat_path() -> bool:
	var host := Node.new()
	host.name = "PhaseFDefeatHost"
	root.add_child(host)
	var gc := GameController.new()
	gc.name = "GameControllerDefeat"
	host.add_child(gc)
	await process_frame
	await process_frame

	if gc.get_run_outcome() != GameController.RunOutcome.NONE:
		push_error("PhaseF: outcome should be NONE at start")
		host.queue_free()
		await process_frame
		return false

	gc.debug_force_defeat()
	await process_frame
	await process_frame
	if gc.get_run_outcome() != GameController.RunOutcome.DEFEAT:
		push_error("PhaseF: expected DEFEAT after captain lethal, got %s" % str(gc.get_run_outcome()))
		host.queue_free()
		await process_frame
		return false
	if not gc.game_over or gc.get_run_phase() != GameController.RunPhase.GAME_OVER:
		push_error("PhaseF: defeat should set GAME_OVER")
		host.queue_free()
		await process_frame
		return false
	var stats: Dictionary = gc.get_run_stats()
	if bool(stats.get("won", true)):
		push_error("PhaseF: defeat run_stats.won should be false")
		host.queue_free()
		await process_frame
		return false
	print(
		"PHASE_F_DEFEAT_OK floors=",
		stats.get("floors_reached"),
		" ducats=",
		stats.get("ducats")
	)

	host.queue_free()
	await process_frame
	return true
