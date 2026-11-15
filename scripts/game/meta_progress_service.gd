class_name MetaProgressService
extends RefCounted
## Phase G: local meta save — skill points, unlocks, purchased nodes, character pick.


const RESULT_OK := &"ok"
const RESULT_LOCKED := &"locked"
const RESULT_NOT_ENOUGH := &"not_enough"
const RESULT_ALREADY_OWNED := &"already_owned"
const RESULT_MISSING_PREREQ := &"missing_prereq"
const RESULT_UNKNOWN := &"unknown"
const RESULT_BAD_PATH := &"bad_path"

const DEFAULT_SAVE_PATH := "user://meta_progress.save"

var config: MetaProgressConfig
var skill_points: int = 0
var unlocked_ids: PackedStringArray = PackedStringArray()
var purchased_nodes: PackedStringArray = PackedStringArray()
var selected_character_id: StringName = &""
var last_awarded_skill_points: int = 0
var last_new_unlocks: PackedStringArray = PackedStringArray()

var _save_path: String = DEFAULT_SAVE_PATH


func configure(cfg: MetaProgressConfig, save_path: String = "") -> void:
	config = cfg if cfg != null else MetaProgressConfig.new()
	if save_path.is_empty():
		var name := config.save_file_name if config != null else "meta_progress.save"
		if name.is_empty():
			name = "meta_progress.save"
		_save_path = "user://%s" % name.trim_prefix("user://")
	else:
		_save_path = save_path
	_ensure_default_unlocks()
	if selected_character_id == &"":
		selected_character_id = preferred_character_id()


func get_save_path() -> String:
	return _save_path


func reset_progress(clear_disk: bool = false) -> void:
	skill_points = 0
	unlocked_ids = PackedStringArray()
	purchased_nodes = PackedStringArray()
	selected_character_id = &""
	last_awarded_skill_points = 0
	last_new_unlocks = PackedStringArray()
	_ensure_default_unlocks()
	selected_character_id = preferred_character_id()
	if clear_disk:
		_delete_save_file()


func load_from_disk(path: String = "") -> bool:
	var p := path if not path.is_empty() else _save_path
	if p.is_empty():
		return false
	if not FileAccess.file_exists(p):
		_ensure_default_unlocks()
		if selected_character_id == &"":
			selected_character_id = preferred_character_id()
		return false
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	skill_points = maxi(0, int(data.get("skill_points", 0)))
	unlocked_ids = _to_packed_string_array(data.get("unlocked_ids", []))
	purchased_nodes = _to_packed_string_array(data.get("purchased_nodes", []))
	selected_character_id = StringName(str(data.get("selected_character_id", "")))
	_ensure_default_unlocks()
	if selected_character_id == &"" or not is_character_unlocked(selected_character_id):
		selected_character_id = preferred_character_id()
	return true


func save_to_disk(path: String = "") -> bool:
	var p := path if not path.is_empty() else _save_path
	if p.is_empty():
		return false
	var payload := {
		"skill_points": skill_points,
		"unlocked_ids": Array(unlocked_ids),
		"purchased_nodes": Array(purchased_nodes),
		"selected_character_id": String(selected_character_id),
		"version": 1,
	}
	var text := JSON.stringify(payload, "\t")
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func award_for_outcome(won: bool) -> int:
	var amount := 0
	if config != null:
		amount = config.skill_points_for_outcome(won)
	skill_points = maxi(0, skill_points + amount)
	last_awarded_skill_points = amount
	last_new_unlocks = PackedStringArray()
	if won and config != null and config.victory_unlock_id != &"":
		if grant_unlock(config.victory_unlock_id):
			last_new_unlocks.append(String(config.victory_unlock_id))
			_unlock_characters_for_id(config.victory_unlock_id)
	return amount


func grant_unlock(unlock_id: StringName) -> bool:
	if unlock_id == &"":
		return false
	var key := String(unlock_id)
	if unlocked_ids.has(key):
		return false
	unlocked_ids.append(key)
	_unlock_characters_for_id(unlock_id)
	return true


func has_unlock(unlock_id: StringName) -> bool:
	if unlock_id == &"":
		return false
	return unlocked_ids.has(String(unlock_id))


func is_character_unlocked(character_id: StringName) -> bool:
	var def := _character(character_id)
	if def == null:
		return false
	if def.unlocked_by_default:
		return true
	if def.unlock_id != &"" and has_unlock(def.unlock_id):
		return true
	# Direct unlock by character id also counts.
	return has_unlock(character_id)


func get_lock_reason(character_id: StringName) -> String:
	if is_character_unlocked(character_id):
		return ""
	var def := _character(character_id)
	if def == null:
		return "未知角色"
	if def.lock_reason.is_empty():
		return "未解锁"
	return def.lock_reason


func preferred_character_id() -> StringName:
	if selected_character_id != &"" and is_character_unlocked(selected_character_id):
		return selected_character_id
	if config != null:
		var fallback := config.default_character_id()
		if fallback != &"" and is_character_unlocked(fallback):
			return fallback
	for c in _characters():
		if c != null and is_character_unlocked(c.id):
			return c.id
	return &""


func try_select_character(character_id: StringName) -> Dictionary:
	## Returns {ok, code, lock_reason, character_id}
	if character_id == &"":
		return {
			"ok": false,
			"code": RESULT_UNKNOWN,
			"lock_reason": "无效角色",
			"character_id": character_id,
		}
	if _character(character_id) == null:
		return {
			"ok": false,
			"code": RESULT_UNKNOWN,
			"lock_reason": "未知角色",
			"character_id": character_id,
		}
	if not is_character_unlocked(character_id):
		return {
			"ok": false,
			"code": RESULT_LOCKED,
			"lock_reason": get_lock_reason(character_id),
			"character_id": character_id,
		}
	selected_character_id = character_id
	return {
		"ok": true,
		"code": RESULT_OK,
		"lock_reason": "",
		"character_id": character_id,
	}


func try_purchase_node(node_id: StringName) -> Dictionary:
	## Returns {ok, code, cost, node_id, skill_points}
	var node := _skill_node(node_id)
	if node == null:
		return {
			"ok": false,
			"code": RESULT_UNKNOWN,
			"cost": 0,
			"node_id": node_id,
			"skill_points": skill_points,
		}
	if purchased_nodes.has(String(node_id)):
		return {
			"ok": false,
			"code": RESULT_ALREADY_OWNED,
			"cost": maxi(0, node.cost),
			"node_id": node_id,
			"skill_points": skill_points,
		}
	# Character-tree nodes require that character unlocked.
	if node.character_id != &"" and not is_character_unlocked(node.character_id):
		return {
			"ok": false,
			"code": RESULT_LOCKED,
			"cost": maxi(0, node.cost),
			"node_id": node_id,
			"skill_points": skill_points,
		}
	for req in node.requires:
		if not purchased_nodes.has(str(req)):
			return {
				"ok": false,
				"code": RESULT_MISSING_PREREQ,
				"cost": maxi(0, node.cost),
				"node_id": node_id,
				"skill_points": skill_points,
			}
	var cost := maxi(0, node.cost)
	if skill_points < cost:
		return {
			"ok": false,
			"code": RESULT_NOT_ENOUGH,
			"cost": cost,
			"node_id": node_id,
			"skill_points": skill_points,
		}
	skill_points -= cost
	purchased_nodes.append(String(node_id))
	return {
		"ok": true,
		"code": RESULT_OK,
		"cost": cost,
		"node_id": node_id,
		"skill_points": skill_points,
	}


func owns_node(node_id: StringName) -> bool:
	return purchased_nodes.has(String(node_id))


func get_starting_hp_bonus(character_id: StringName = &"") -> int:
	var cid := character_id if character_id != &"" else selected_character_id
	var total := 0
	var char_def := _character(cid)
	if char_def != null:
		total += maxi(0, char_def.base_starting_hp_bonus)
	for node in _skill_nodes():
		if node == null or not owns_node(node.id):
			continue
		if node.character_id != &"" and node.character_id != cid:
			continue
		if node.effect_kind == MetaSkillNodeDef.EffectKind.STARTING_HP:
			total += int(round(node.effect_value))
	return total


func get_starting_ducats_bonus(character_id: StringName = &"") -> int:
	var cid := character_id if character_id != &"" else selected_character_id
	var total := 0
	var char_def := _character(cid)
	if char_def != null:
		total += maxi(0, char_def.base_starting_ducats_bonus)
	for node in _skill_nodes():
		if node == null or not owns_node(node.id):
			continue
		if node.character_id != &"" and node.character_id != cid:
			continue
		if node.effect_kind == MetaSkillNodeDef.EffectKind.STARTING_DUCATS:
			total += int(round(node.effect_value))
	return total


func list_characters() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for c in _characters():
		if c == null or c.id == &"":
			continue
		var unlocked := is_character_unlocked(c.id)
		rows.append({
			"id": c.id,
			"display_name": c.display_name if not c.display_name.is_empty() else String(c.id),
			"description": c.description,
			"unlocked": unlocked,
			"lock_reason": "" if unlocked else get_lock_reason(c.id),
			"selected": c.id == selected_character_id,
		})
	return rows


func list_skill_nodes(character_id: StringName = &"") -> Array[Dictionary]:
	var cid := character_id if character_id != &"" else selected_character_id
	var rows: Array[Dictionary] = []
	for node in _skill_nodes():
		if node == null or node.id == &"":
			continue
		# Include global (empty character_id) and matching character tree.
		if node.character_id != &"" and node.character_id != cid:
			continue
		var owned := owns_node(node.id)
		var char_ok := node.character_id == &"" or is_character_unlocked(node.character_id)
		var prereq_ok := true
		for req in node.requires:
			if not purchased_nodes.has(str(req)):
				prereq_ok = false
				break
		var affordable := skill_points >= maxi(0, node.cost)
		var can_buy := (not owned) and char_ok and prereq_ok and affordable
		var block_reason := ""
		if owned:
			block_reason = "已购买"
		elif not char_ok:
			block_reason = get_lock_reason(node.character_id)
		elif not prereq_ok:
			block_reason = "需要前置节点"
		elif not affordable:
			block_reason = "技能点不足"
		rows.append({
			"id": node.id,
			"display_name": node.display_name if not node.display_name.is_empty() else String(node.id),
			"description": node.description,
			"cost": maxi(0, node.cost),
			"owned": owned,
			"can_buy": can_buy,
			"block_reason": block_reason,
			"effect_kind": node.effect_kind,
			"effect_value": node.effect_value,
			"character_id": node.character_id,
		})
	return rows


func settlement_summary(won: bool) -> Dictionary:
	return {
		"won": won,
		"awarded": last_awarded_skill_points,
		"skill_points": skill_points,
		"new_unlocks": Array(last_new_unlocks),
		"selected_character_id": String(selected_character_id),
	}


func _ensure_default_unlocks() -> void:
	for c in _characters():
		if c == null:
			continue
		if c.unlocked_by_default and c.id != &"":
			var key := String(c.id)
			if not unlocked_ids.has(key):
				unlocked_ids.append(key)
			if c.unlock_id != &"":
				var ukey := String(c.unlock_id)
				if not unlocked_ids.has(ukey):
					unlocked_ids.append(ukey)


func _unlock_characters_for_id(unlock_id: StringName) -> void:
	for c in _characters():
		if c == null:
			continue
		if c.unlock_id == unlock_id and c.id != &"":
			var key := String(c.id)
			if not unlocked_ids.has(key):
				unlocked_ids.append(key)


func _characters() -> Array[MetaCharacterDef]:
	if config == null:
		return []
	return config.characters


func _skill_nodes() -> Array[MetaSkillNodeDef]:
	if config == null:
		return []
	return config.skill_nodes


func _character(character_id: StringName) -> MetaCharacterDef:
	if config == null:
		return null
	return config.find_character(character_id)


func _skill_node(node_id: StringName) -> MetaSkillNodeDef:
	if config == null:
		return null
	return config.find_skill_node(node_id)


func _delete_save_file() -> void:
	if _save_path.is_empty():
		return
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)


func _to_packed_string_array(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		return value
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			out.append(str(item))
	return out
