class_name ReviveQueue
extends RefCounted
## Phase C ally revive queue: death order FIFO, per-entry remaining time.


var entries: Array[Dictionary] = []  # {def: UnitDefinition, remaining: float, serial: int}
var _serial: int = 0


func clear() -> void:
	entries.clear()
	_serial = 0


func size() -> int:
	return entries.size()


func is_empty() -> bool:
	return entries.is_empty()


func enqueue(def: UnitDefinition, revive_sec: float) -> Dictionary:
	if def == null:
		return {}
	_serial += 1
	var entry := {
		"def": def.duplicate(true) as UnitDefinition,
		"remaining": maxf(0.1, revive_sec),
		"serial": _serial,
	}
	entries.append(entry)
	return entry


## Tick all timers. Returns defs ready to revive in FIFO (death) order.
func tick(delta: float) -> Array[UnitDefinition]:
	var ready: Array[UnitDefinition] = []
	if delta <= 0.0 or entries.is_empty():
		return ready
	for entry in entries:
		entry["remaining"] = maxf(0.0, float(entry.get("remaining", 0.0)) - delta)
	# Pop from front while ready (FIFO). Later entries may also be 0 but wait their turn.
	while not entries.is_empty():
		var head: Dictionary = entries[0]
		if float(head.get("remaining", 0.0)) > 0.0:
			break
		var def: UnitDefinition = head.get("def") as UnitDefinition
		entries.remove_at(0)
		if def != null:
			ready.append(def)
	return ready


func extend_all(seconds: float) -> void:
	if seconds <= 0.0:
		return
	for entry in entries:
		entry["remaining"] = float(entry.get("remaining", 0.0)) + seconds


func get_defs() -> Array:
	var out: Array = []
	for entry in entries:
		var def: UnitDefinition = entry.get("def") as UnitDefinition
		if def != null:
			out.append(def)
	return out


func get_hud_rows() -> Array:
	var rows: Array = []
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var def: UnitDefinition = entry.get("def") as UnitDefinition
		var name_str := def.display_name if def != null else "?"
		var rank := int(def.rank) if def != null else 0
		var kw := def.keyword if def != null else &""
		rows.append({
			"index": i,
			"name": name_str,
			"rank": rank,
			"rank_label": UnitMergeService.rank_label(rank),
			"keyword": kw,
			"remaining": float(entry.get("remaining", 0.0)),
		})
	return rows


## Test helper: force front remaining.
func debug_set_front_remaining(sec: float) -> void:
	if entries.is_empty():
		return
	entries[0]["remaining"] = maxf(0.0, sec)
