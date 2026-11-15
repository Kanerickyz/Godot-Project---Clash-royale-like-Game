class_name PhaseCMergeReviveTest
extends RefCounted
## Phase C pure logic: merge boundaries, revive FIFO, share extend.


static func _make_unit(id: StringName, rank: int = 0, keyword: StringName = &"") -> UnitDefinition:
	var u := UnitDefinition.new()
	u.id = id
	u.display_name = str(id)
	u.rank = rank
	u.keyword = keyword
	u.max_hp = 30
	u.attack_damage = 5
	u.shop_price = 3
	return u


static func test_merge_boundaries() -> bool:
	# 2 same: no merge.
	var living: Array = [_make_unit(&"skel", 0), _make_unit(&"skel", 0)]
	var queued: Array = []
	var r2 := UnitMergeService.auto_merge(living, queued)
	if not (r2.get("merges", []) as Array).is_empty():
		push_error("PhaseC: 2 units should not merge")
		return false
	if (r2.get("living", []) as Array).size() != 2:
		push_error("PhaseC: 2 units should remain living")
		return false

	# 3 recruit → 1 veteran.
	living = [_make_unit(&"skel", 0), _make_unit(&"skel", 0), _make_unit(&"skel", 0)]
	var r3 := UnitMergeService.auto_merge(living, queued)
	var merges: Array = r3.get("merges", [])
	if merges.size() != 1:
		push_error("PhaseC: expected 1 merge from 3 recruits, got %d" % merges.size())
		return false
	var live_after: Array = r3.get("living", [])
	if live_after.size() != 1:
		push_error("PhaseC: expected 1 living after merge, got %d" % live_after.size())
		return false
	var vet: UnitDefinition = live_after[0]
	if int(vet.rank) != UnitMergeService.RANK_VETERAN:
		push_error("PhaseC: expected VETERAN rank, got %d" % int(vet.rank))
		return false

	# 3 veteran → 1 champion keeps keyword.
	living = [
		_make_unit(&"skel", 1, &"蜂群"),
		_make_unit(&"skel", 1, &"蜂群"),
		_make_unit(&"skel", 1, &"蜂群"),
	]
	var r4 := UnitMergeService.auto_merge(living, [])
	var champ_live: Array = r4.get("living", [])
	if champ_live.size() != 1:
		push_error("PhaseC: expected 1 champion, got %d" % champ_live.size())
		return false
	var champ: UnitDefinition = champ_live[0]
	if int(champ.rank) != UnitMergeService.RANK_CHAMPION:
		push_error("PhaseC: expected CHAMPION")
		return false
	if champ.keyword != &"蜂群":
		push_error("PhaseC: champion keyword missing")
		return false

	# Mixed ranks / ids do not false-merge.
	living = [_make_unit(&"a", 0), _make_unit(&"a", 0), _make_unit(&"b", 0)]
	var r5 := UnitMergeService.auto_merge(living, [])
	if not (r5.get("merges", []) as Array).is_empty():
		push_error("PhaseC: mixed ids should not merge")
		return false

	# Living + queue together can merge.
	living = [_make_unit(&"x", 0)]
	queued = [_make_unit(&"x", 0), _make_unit(&"x", 0)]
	var r6 := UnitMergeService.auto_merge(living, queued)
	if (r6.get("merges", []) as Array).size() != 1:
		push_error("PhaseC: living+queue should merge to 1")
		return false
	if (r6.get("queued", []) as Array).size() != 0:
		push_error("PhaseC: queue should be emptied by merge consume")
		return false

	# Champions do not merge further.
	living = [
		_make_unit(&"c", 2, &"射术"),
		_make_unit(&"c", 2, &"射术"),
		_make_unit(&"c", 2, &"射术"),
	]
	var r7 := UnitMergeService.auto_merge(living, [])
	if not (r7.get("merges", []) as Array).is_empty():
		push_error("PhaseC: champions must not merge")
		return false

	print("PHASE_C_MERGE_OK")
	return true


static func test_revive_fifo_and_extend() -> bool:
	var q := ReviveQueue.new()
	var a := _make_unit(&"a")
	var b := _make_unit(&"b")
	var c := _make_unit(&"c")
	q.enqueue(a, 5.0)
	q.enqueue(b, 3.0)
	q.enqueue(c, 1.0)
	if q.size() != 3:
		push_error("PhaseC: queue size expected 3")
		return false
	# Tick 1s: only C ready by timer, but FIFO blocks until front ready.
	var r1 := q.tick(1.0)
	if not r1.is_empty():
		push_error("PhaseC: FIFO should block later ready entries")
		return false
	# Extend all (captain share penalty).
	q.extend_all(2.0)
	var rows := q.get_hud_rows()
	if rows.is_empty() or float(rows[0].get("remaining", 0.0)) < 5.9:
		push_error("PhaseC: extend_all did not lengthen front remaining")
		return false
	# Advance until front ready; order must be A then B then C.
	var order: Array = []
	var guard := 0
	while not q.is_empty() and guard < 40:
		guard += 1
		var ready := q.tick(1.0)
		for d in ready:
			order.append((d as UnitDefinition).id)
	if order != [&"a", &"b", &"c"]:
		push_error("PhaseC: FIFO order expected [a,b,c] got %s" % str(order))
		return false
	print("PHASE_C_REVIVE_FIFO_OK")
	return true


static func test_rank_multipliers() -> bool:
	var cfg := MergeRankConfig.new()
	cfg.rank_stat_multipliers = PackedFloat32Array([1.0, 1.35, 1.75])
	if absf(cfg.multiplier_for_rank(0) - 1.0) > 0.001:
		push_error("PhaseC: recruit mult")
		return false
	if absf(cfg.multiplier_for_rank(1) - 1.35) > 0.001:
		push_error("PhaseC: veteran mult")
		return false
	if absf(cfg.multiplier_for_rank(2) - 1.75) > 0.001:
		push_error("PhaseC: champion mult")
		return false
	print("PHASE_C_RANK_MULT_OK")
	return true
