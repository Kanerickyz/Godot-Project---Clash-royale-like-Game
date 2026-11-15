class_name PhaseGMetaProgressTest
extends RefCounted
## Phase G pure logic: save/load, award points, locked reject, purchase nodes.


const TEST_SAVE := "user://phase_g_meta_progress_test.save"


static func _make_service(wipe: bool = true) -> MetaProgressService:
	var cfg := MetaProgressConfig.make_default()
	var svc := MetaProgressService.new()
	svc.configure(cfg, TEST_SAVE)
	if wipe:
		svc.reset_progress(true)
	return svc


static func test_award_points_win_and_loss() -> bool:
	var svc := _make_service(true)
	var win_amt := svc.award_for_outcome(true)
	if win_amt != 3:
		push_error("PhaseG: victory skill points expected 3, got %d" % win_amt)
		return false
	if svc.skill_points != 3:
		push_error("PhaseG: balance after win expected 3")
		return false
	if not svc.has_unlock(&"clear_run"):
		push_error("PhaseG: victory should grant clear_run unlock")
		return false
	if not svc.is_character_unlocked(&"iron_captain"):
		push_error("PhaseG: iron_captain should unlock after clear_run")
		return false

	var svc2 := _make_service(true)
	var lose_amt := svc2.award_for_outcome(false)
	if lose_amt != 1:
		push_error("PhaseG: defeat skill points expected 1, got %d" % lose_amt)
		return false
	if svc2.skill_points != 1:
		push_error("PhaseG: balance after defeat expected 1")
		return false
	if svc2.is_character_unlocked(&"iron_captain"):
		push_error("PhaseG: defeat must not unlock iron_captain")
		return false
	print("PHASE_G_AWARD_OK win=", win_amt, " lose=", lose_amt)
	return true


static func test_save_load_roundtrip() -> bool:
	var svc := _make_service(true)
	svc.award_for_outcome(true)
	var buy := svc.try_purchase_node(&"warden_hp_1")
	if not bool(buy.get("ok", false)):
		push_error("PhaseG: purchase before save failed %s" % str(buy))
		return false
	svc.try_select_character(&"iron_captain")
	if not svc.save_to_disk():
		push_error("PhaseG: save_to_disk failed")
		return false

	var loaded := MetaProgressService.new()
	loaded.configure(MetaProgressConfig.make_default(), TEST_SAVE)
	if not loaded.load_from_disk():
		push_error("PhaseG: load_from_disk failed")
		return false
	if loaded.skill_points != svc.skill_points:
		push_error(
			"PhaseG: skill_points mismatch save=%d load=%d"
			% [svc.skill_points, loaded.skill_points]
		)
		return false
	if not loaded.owns_node(&"warden_hp_1"):
		push_error("PhaseG: purchased node missing after load")
		return false
	if not loaded.is_character_unlocked(&"iron_captain"):
		push_error("PhaseG: unlock missing after load")
		return false
	if loaded.selected_character_id != &"iron_captain":
		push_error("PhaseG: selected character not restored")
		return false
	print(
		"PHASE_G_SAVE_LOAD_OK sp=",
		loaded.skill_points,
		" char=",
		loaded.selected_character_id
	)
	return true


static func test_locked_character_reject() -> bool:
	var svc := _make_service(true)
	var locked := svc.try_select_character(&"iron_captain")
	if bool(locked.get("ok", true)) or locked.get("code") != MetaProgressService.RESULT_LOCKED:
		push_error("PhaseG: expected LOCKED select, got %s" % str(locked))
		return false
	var reason := str(locked.get("lock_reason", ""))
	if reason.is_empty():
		push_error("PhaseG: lock_reason should be visible")
		return false
	var ok_pick := svc.try_select_character(&"warden")
	if not bool(ok_pick.get("ok", false)):
		push_error("PhaseG: warden should be selectable")
		return false
	print("PHASE_G_LOCKED_CHAR_OK reason=", reason)
	return true


static func test_purchase_node_and_rejects() -> bool:
	var svc := _make_service(true)
	# No points → not enough.
	var poor := svc.try_purchase_node(&"warden_hp_1")
	if bool(poor.get("ok", true)) or poor.get("code") != MetaProgressService.RESULT_NOT_ENOUGH:
		push_error("PhaseG: expected NOT_ENOUGH, got %s" % str(poor))
		return false

	svc.skill_points = 5
	# Locked character tree node.
	var locked_node := svc.try_purchase_node(&"iron_hp_1")
	if (
		bool(locked_node.get("ok", true))
		or locked_node.get("code") != MetaProgressService.RESULT_LOCKED
	):
		push_error("PhaseG: iron tree should be LOCKED, got %s" % str(locked_node))
		return false

	# Missing prereq for ducats node.
	var prereq := svc.try_purchase_node(&"warden_ducats_1")
	if (
		bool(prereq.get("ok", true))
		or prereq.get("code") != MetaProgressService.RESULT_MISSING_PREREQ
	):
		push_error("PhaseG: expected MISSING_PREREQ, got %s" % str(prereq))
		return false

	var buy_hp := svc.try_purchase_node(&"warden_hp_1")
	if not bool(buy_hp.get("ok", false)):
		push_error("PhaseG: buy hp node failed %s" % str(buy_hp))
		return false
	if svc.get_starting_hp_bonus(&"warden") < 10:
		push_error("PhaseG: hp bonus after purchase expected >=10")
		return false

	var again := svc.try_purchase_node(&"warden_hp_1")
	if (
		bool(again.get("ok", true))
		or again.get("code") != MetaProgressService.RESULT_ALREADY_OWNED
	):
		push_error("PhaseG: expected ALREADY_OWNED, got %s" % str(again))
		return false

	var buy_d := svc.try_purchase_node(&"warden_ducats_1")
	if not bool(buy_d.get("ok", false)):
		push_error("PhaseG: buy ducats node failed %s" % str(buy_d))
		return false
	if svc.get_starting_ducats_bonus(&"warden") < 5:
		push_error("PhaseG: ducats bonus expected >=5")
		return false
	print(
		"PHASE_G_PURCHASE_OK sp=",
		svc.skill_points,
		" hp=",
		svc.get_starting_hp_bonus(&"warden"),
		" ducats=",
		svc.get_starting_ducats_bonus(&"warden")
	)
	return true
