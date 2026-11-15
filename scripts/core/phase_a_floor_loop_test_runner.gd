extends SceneTree
## Phase A runner: move path, threat rise, portal → interstitial → next floor.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	if not PhaseAFloorLoopTest.test_threat_clock_rises():
		ok = false
	if not await _test_game_flow():
		ok = false
	quit(0 if ok else 1)


func _test_game_flow() -> bool:
	var host := Node.new()
	host.name = "PhaseATestHost"
	root.add_child(host)
	var gc := GameController.new()
	gc.name = "GameControllerUnderTest"
	host.add_child(gc)
	await process_frame
	await process_frame

	if gc.get_run_phase() != GameController.RunPhase.FLOOR:
		push_error("PhaseAFloorLoopTest: expected FLOOR phase at start")
		host.queue_free()
		await process_frame
		return false
	if gc.get_floor_index() != 1:
		push_error("PhaseAFloorLoopTest: expected floor 1 at start, got %d" % gc.get_floor_index())
		host.queue_free()
		await process_frame
		return false

	# Move path: forced vector must be returned while on floor.
	gc.forced_move_vector = Vector2(1, 0)
	var mv := gc.get_move_vector()
	if mv.length() < 0.5:
		push_error("PhaseAFloorLoopTest: forced move_vector not honored (got %s)" % str(mv))
		host.queue_free()
		await process_frame
		return false
	print("PHASE_A_MOVE_OK vec=", mv)

	# Threat via controller helper.
	var t0 := gc.get_threat_multiplier()
	gc.debug_advance_threat(60.0)
	var t1 := gc.get_threat_multiplier()
	if t1 <= t0:
		push_error("PhaseAFloorLoopTest: controller threat did not rise (%.3f → %.3f)" % [t0, t1])
		host.queue_free()
		await process_frame
		return false
	print("PHASE_A_THREAT_CTRL_OK t0=%.3f t1=%.3f" % [t0, t1])

	# Portal → interstitial.
	gc.debug_enter_portal()
	await process_frame
	if gc.get_run_phase() != GameController.RunPhase.INTERSTITIAL:
		push_error("PhaseAFloorLoopTest: expected INTERSTITIAL after portal, got %s" % str(gc.get_run_phase()))
		host.queue_free()
		await process_frame
		return false
	gc.forced_move_vector = Vector2(1, 0)
	if gc.get_move_vector() != Vector2.ZERO:
		push_error("PhaseAFloorLoopTest: move should be zero in interstitial")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_A_PORTAL_OK phase=INTERSTITIAL")

	# Next floor.
	gc.debug_advance_floor()
	await process_frame
	await process_frame
	if gc.get_run_phase() != GameController.RunPhase.FLOOR:
		push_error("PhaseAFloorLoopTest: expected FLOOR after next floor, got %s" % str(gc.get_run_phase()))
		host.queue_free()
		await process_frame
		return false
	if gc.get_floor_index() != 2:
		push_error("PhaseAFloorLoopTest: expected floor 2, got %d" % gc.get_floor_index())
		host.queue_free()
		await process_frame
		return false
	# After reset, multiplier should be near base; a frame or two may tick elapsed slightly.
	if gc.get_threat_multiplier() > 1.05:
		push_error("PhaseAFloorLoopTest: threat mult should reset near 1.0 on new floor, got %.3f" % gc.get_threat_multiplier())
		host.queue_free()
		await process_frame
		return false
	if gc.get_threat_elapsed() > 1.0:
		push_error("PhaseAFloorLoopTest: threat elapsed should be near 0 after floor reset, got %.3f" % gc.get_threat_elapsed())
		host.queue_free()
		await process_frame
		return false
	print("PHASE_A_NEXT_FLOOR_OK floor=", gc.get_floor_index(), " threat=", gc.get_threat_multiplier())

	host.queue_free()
	await process_frame
	return true
