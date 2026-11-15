class_name UnitMergeService
extends RefCounted
## Phase C: 3 same id + same rank → one next rank. Pure logic; no SceneTree.


const RANK_RECRUIT := 0
const RANK_VETERAN := 1
const RANK_CHAMPION := 2


static func rank_label(rank: int) -> String:
	match clampi(rank, 0, 2):
		RANK_VETERAN:
			return "老兵"
		RANK_CHAMPION:
			return "冠军"
		_:
			return "新兵"


static func can_promote(rank: int) -> bool:
	return rank < RANK_CHAMPION


static func promoted_def(source: UnitDefinition) -> UnitDefinition:
	## Returns next-rank copy with base stats preserved (multipliers applied at spawn).
	if source == null:
		return null
	var out := source.duplicate(true) as UnitDefinition
	out.rank = mini(RANK_CHAMPION, int(source.rank) + 1)
	# Keyword stays on the unit definition for champion HUD / Phase D.
	return out


static func group_key(def: UnitDefinition) -> String:
	if def == null:
		return ""
	return "%s#%d" % [String(def.id), int(def.rank)]


## living / queued are Array[UnitDefinition]. Returns {living, queued, merges}.
## merges: Array of {from_rank, to_rank, id, name, keyword}
static func auto_merge(living: Array, queued: Array) -> Dictionary:
	var live: Array = []
	for d in living:
		if d is UnitDefinition:
			live.append((d as UnitDefinition).duplicate(true))
	var queue: Array = []
	for d in queued:
		if d is UnitDefinition:
			queue.append((d as UnitDefinition).duplicate(true))
	var merges: Array = []
	var guard := 0
	while guard < 64:
		guard += 1
		var key := _find_full_group_key(live, queue)
		if key == "":
			break
		var removed := _remove_three(live, queue, key)
		if removed.size() < 3:
			break
		var sample: UnitDefinition = removed[0]
		var next_def := promoted_def(sample)
		if next_def == null:
			break
		# Promoted unit enters living roster (player-visible).
		live.append(next_def)
		merges.append({
			"from_rank": int(sample.rank),
			"to_rank": int(next_def.rank),
			"id": next_def.id,
			"name": next_def.display_name,
			"keyword": next_def.keyword,
		})
	return {"living": live, "queued": queue, "merges": merges}


static func count_group(living: Array, queued: Array, unit_id: StringName, rank: int) -> int:
	var n := 0
	for d in living:
		var ud := d as UnitDefinition
		if ud != null and ud.id == unit_id and int(ud.rank) == rank:
			n += 1
	for d in queued:
		var ud2 := d as UnitDefinition
		if ud2 != null and ud2.id == unit_id and int(ud2.rank) == rank:
			n += 1
	return n


static func _find_full_group_key(live: Array, queue: Array) -> String:
	var counts: Dictionary = {}
	for d in live:
		var ud := d as UnitDefinition
		if ud == null or not can_promote(int(ud.rank)):
			continue
		var k := group_key(ud)
		counts[k] = int(counts.get(k, 0)) + 1
	for d in queue:
		var ud2 := d as UnitDefinition
		if ud2 == null or not can_promote(int(ud2.rank)):
			continue
		var k2 := group_key(ud2)
		counts[k2] = int(counts.get(k2, 0)) + 1
	for k in counts.keys():
		if int(counts[k]) >= 3:
			return str(k)
	return ""


static func _remove_three(live: Array, queue: Array, key: String) -> Array:
	var removed: Array = []
	# Prefer consuming living first, then queue (FIFO within each).
	var i := 0
	while i < live.size() and removed.size() < 3:
		var ud := live[i] as UnitDefinition
		if ud != null and group_key(ud) == key:
			removed.append(ud)
			live.remove_at(i)
		else:
			i += 1
	i = 0
	while i < queue.size() and removed.size() < 3:
		var ud2 := queue[i] as UnitDefinition
		if ud2 != null and group_key(ud2) == key:
			removed.append(ud2)
			queue.remove_at(i)
		else:
			i += 1
	return removed
