@tool
extends Control

enum TabFilter { PLAYER, ENEMY, ALL }
enum SortKey { DISPLAY_NAME, TIER, ATTACK, MAX_HP, ATTACK_RANGE }

const UNITS_DIR := "res://resources/units"

@onready var _search_edit: LineEdit = %SearchEdit
@onready var _tab_bar: TabBar = %TabBar
@onready var _sort_option: OptionButton = %SortOption
@onready var _sort_desc_check: CheckBox = %SortDescCheck
@onready var _unit_list: ItemList = %UnitList
@onready var _id_edit: LineEdit = %IdEdit
@onready var _name_edit: LineEdit = %NameEdit
@onready var _team_option: OptionButton = %TeamOption
@onready var _cost_spin: SpinBox = %CostSpin
@onready var _tier_spin: SpinBox = %TierSpin
@onready var _kill_gold_spin: SpinBox = %KillGoldSpin
@onready var _max_hp_spin: SpinBox = %MaxHpSpin
@onready var _attack_spin: SpinBox = %AttackSpin
@onready var _range_spin: SpinBox = %RangeSpin
@onready var _move_pattern_option: OptionButton = %MovePatternOption
@onready var _move_steps_spin: SpinBox = %MoveStepsSpin
@onready var _ability_option: OptionButton = %AbilityOption
@onready var _icon_picker: EditorResourcePicker = %IconPicker
@onready var _icon_preview: TextureRect = %IconPreview
@onready var _status_label: Label = %StatusLabel

var _editor_interface: EditorInterface
var _all_entries: Array = []
var _filtered_entries: Array = []
var _abilities: Array[AbilityData] = []
var _current_path: String = ""
var _current_data: UnitData
var _loading_form: bool = false
var _pending_delete_path: String = ""
var _delete_dialog: ConfirmationDialog


func _ready() -> void:
	_team_option.clear()
	_team_option.add_item("友方 (PLAYER)", UnitInstance.Team.PLAYER)
	_team_option.add_item("敌方 (ENEMY)", UnitInstance.Team.ENEMY)

	_sort_option.clear()
	_sort_option.add_item("显示名", SortKey.DISPLAY_NAME)
	_sort_option.add_item("Tier", SortKey.TIER)
	_sort_option.add_item("攻击", SortKey.ATTACK)
	_sort_option.add_item("生命", SortKey.MAX_HP)
	_sort_option.add_item("攻击距离", SortKey.ATTACK_RANGE)
	_sort_option.item_selected.connect(_on_sort_changed)
	_sort_desc_check.toggled.connect(_on_sort_changed)

	_move_pattern_option.clear()
	_move_pattern_option.add_item("四向", UnitStats.MovementPattern.ORTHOGONAL)
	_move_pattern_option.add_item("同行/列", UnitStats.MovementPattern.LINE)
	_move_pattern_option.add_item("战车/直线滑行", UnitStats.MovementPattern.ROOK)
	_move_pattern_option.add_item("马步", UnitStats.MovementPattern.KNIGHT)
	_move_pattern_option.add_item("斜向", UnitStats.MovementPattern.DIAGONAL)
	_move_pattern_option.add_item("象/斜向滑行", UnitStats.MovementPattern.BISHOP)
	_move_pattern_option.add_item("皇后/八向滑行", UnitStats.MovementPattern.QUEEN)
	_move_pattern_option.add_item("瞬移", UnitStats.MovementPattern.TELEPORT)

	_search_edit.text_changed.connect(_on_search_changed)
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_unit_list.item_selected.connect(_on_unit_selected)
	_icon_picker.resource_changed.connect(_on_icon_changed)

	%NewButton.pressed.connect(_on_new_pressed)
	%DuplicateButton.pressed.connect(_on_duplicate_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%DeleteButton.pressed.connect(_on_delete_pressed)
	%InspectorButton.pressed.connect(_on_inspector_pressed)
	%RefreshButton.pressed.connect(_reload_catalog)

	_ensure_delete_dialog()

	if Engine.is_editor_hint():
		_reload_catalog()


func set_editor_interface(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _reload_catalog() -> void:
	_all_entries = UnitCatalog.scan_units()
	_abilities = UnitCatalog.scan_abilities()
	_populate_ability_options()
	_refresh_unit_list()
	_set_status("已扫描 %d 个单位" % _all_entries.size())


func _populate_ability_options() -> void:
	_ability_option.clear()
	_ability_option.add_item("（无）", -1)
	for i in _abilities.size():
		var ability := _abilities[i]
		if ability == null:
			continue
		var label := UnitInfoText.get_ability_description(ability)
		if label.is_empty():
			label = ability.id if not ability.id.is_empty() else "ability_%d" % i
		_ability_option.add_item(label, i)


func _ensure_ability_options_populated() -> void:
	var expected := _abilities.size() + 1
	if _ability_option.item_count != expected:
		_populate_ability_options()


func _safe_option_select(option: OptionButton, index: int) -> void:
	if option == null or option.item_count <= 0:
		return
	option.select(clampi(index, 0, option.item_count - 1))


func _get_tab_filter() -> TabFilter:
	match _tab_bar.current_tab:
		0:
			return TabFilter.PLAYER
		1:
			return TabFilter.ENEMY
		_:
			return TabFilter.ALL


func _apply_tab_filter(entries: Array) -> Array:
	match _get_tab_filter():
		TabFilter.PLAYER:
			return UnitCatalog.filter_by_team(entries, UnitInstance.Team.PLAYER)
		TabFilter.ENEMY:
			return UnitCatalog.filter_by_team(entries, UnitInstance.Team.ENEMY)
		_:
			return entries.duplicate()


func _apply_search_filter(entries: Array) -> Array:
	var query := _search_edit.text.strip_edges().to_lower()
	if query.is_empty():
		return entries
	var filtered: Array = []
	for entry in entries:
		var data: UnitData = entry.get("data")
		if data == null:
			continue
		var hay := "%s %s" % [data.id, data.display_name]
		if hay.to_lower().contains(query):
			filtered.append(entry)
	return filtered


func _on_sort_changed(_unused = null) -> void:
	_refresh_unit_list()


func _apply_sort(entries: Array) -> Array:
	var sorted: Array = entries.duplicate()
	var key: SortKey = _sort_option.get_selected_id() as SortKey
	if key < 0:
		key = SortKey.DISPLAY_NAME
	var descending := _sort_desc_check.button_pressed
	sorted.sort_custom(func(a, b) -> bool:
		return _compare_entries(a, b, key, descending)
	)
	return sorted


func _compare_entries(a: Dictionary, b: Dictionary, key: SortKey, descending: bool) -> bool:
	var da: UnitData = a.get("data")
	var db: UnitData = b.get("data")
	if da == null:
		return not descending
	if db == null:
		return descending

	var cmp := 0
	match key:
		SortKey.TIER:
			cmp = _cmp_int(da.tier, db.tier)
		SortKey.ATTACK:
			cmp = _cmp_int(_stat_attack(da), _stat_attack(db))
		SortKey.MAX_HP:
			cmp = _cmp_int(_stat_max_hp(da), _stat_max_hp(db))
		SortKey.ATTACK_RANGE:
			cmp = _cmp_int(_stat_range(da), _stat_range(db))
		_:
			var na := da.display_name if not da.display_name.is_empty() else da.id
			var nb := db.display_name if not db.display_name.is_empty() else db.id
			if na == nb:
				cmp = _cmp_int(da.tier, db.tier)
			else:
				cmp = -1 if na < nb else (1 if na > nb else 0)

	if cmp == 0:
		var pa: String = a.get("path", "")
		var pb: String = b.get("path", "")
		cmp = -1 if pa < pb else (1 if pa > pb else 0)
	if descending:
		return cmp > 0
	return cmp < 0


func _cmp_int(a: int, b: int) -> int:
	if a < b:
		return -1
	if a > b:
		return 1
	return 0


func _stat_attack(data: UnitData) -> int:
	if data == null or data.stats == null:
		return 0
	return data.stats.attack


func _stat_max_hp(data: UnitData) -> int:
	if data == null or data.stats == null:
		return 0
	return data.stats.max_hp


func _stat_range(data: UnitData) -> int:
	if data == null or data.stats == null:
		return 1
	return data.stats.attack_range


func _refresh_unit_list() -> void:
	var selected_path := _current_path
	_filtered_entries = _apply_sort(
		_apply_search_filter(_apply_tab_filter(_all_entries))
	)
	_unit_list.clear()
	for entry in _filtered_entries:
		var data: UnitData = entry.get("data")
		if data == null:
			continue
		var stats := data.stats
		var atk := _stat_attack(data)
		var hp := _stat_max_hp(data)
		var rng := _stat_range(data)
		var team_tag := "友" if UnitCatalog.is_player(data) else "敌"
		var text := "[%s] %s  T%d  %d/%d 距%d" % [
			team_tag, data.display_name, data.tier, atk, hp, rng
		]
		if data.id != data.display_name and not data.id.is_empty():
			text += " (%s)" % data.id
		_unit_list.add_item(text)

	if not selected_path.is_empty():
		_select_path_in_list(selected_path, false)


func _on_search_changed(_text: String) -> void:
	_refresh_unit_list()


func _on_tab_changed(_tab: int) -> void:
	_refresh_unit_list()


func _on_unit_selected(index: int) -> void:
	if index < 0 or index >= _filtered_entries.size():
		return
	if _abilities.is_empty():
		_reload_catalog()
	var entry: Dictionary = _filtered_entries[index]
	_current_path = entry.get("path", "")
	_current_data = entry.get("data")
	_load_form_from_data(_current_data)
	_check_warnings()


func _load_form_from_data(data: UnitData) -> void:
	_loading_form = true
	if data == null:
		_loading_form = false
		return

	_id_edit.text = data.id
	_name_edit.text = data.display_name
	_safe_option_select(
		_team_option,
		0 if data.team_default == UnitInstance.Team.PLAYER else 1,
	)
	_cost_spin.value = data.cost
	_tier_spin.value = data.tier
	_kill_gold_spin.value = data.kill_gold_reward

	if data.stats == null:
		data.stats = UnitStats.new()
	_max_hp_spin.value = data.stats.max_hp
	_attack_spin.value = data.stats.attack
	_range_spin.value = data.stats.attack_range
	_select_movement_pattern(data.stats.movement_pattern)
	_move_steps_spin.value = data.stats.steps_per_turn

	_ensure_ability_options_populated()
	_select_ability_in_option(data.ability)
	_icon_picker.edited_resource = data.icon
	_update_icon_preview(data.icon)
	_loading_form = false


func _select_movement_pattern(pattern: UnitStats.MovementPattern) -> void:
	for i in _move_pattern_option.item_count:
		if _move_pattern_option.get_item_id(i) == pattern:
			_safe_option_select(_move_pattern_option, i)
			return
	_safe_option_select(_move_pattern_option, 0)


func _select_ability_in_option(ability: AbilityData) -> void:
	if ability == null:
		_safe_option_select(_ability_option, 0)
		return
	for i in _abilities.size():
		var scanned := _abilities[i]
		if scanned == null:
			continue
		if scanned == ability or (
			not ability.id.is_empty()
			and not scanned.id.is_empty()
			and scanned.id == ability.id
		):
			_safe_option_select(_ability_option, i + 1)
			return
	_safe_option_select(_ability_option, 0)


func _apply_form_to_data(data: UnitData) -> void:
	if data == null:
		return
	data.id = _id_edit.text.strip_edges()
	data.display_name = _name_edit.text.strip_edges()
	data.team_default = (
		UnitInstance.Team.PLAYER
		if _team_option.selected == 0
		else UnitInstance.Team.ENEMY
	)
	data.cost = int(_cost_spin.value)
	data.tier = int(_tier_spin.value)
	data.kill_gold_reward = int(_kill_gold_spin.value)
	if data.stats == null:
		data.stats = UnitStats.new()
	data.stats.max_hp = int(_max_hp_spin.value)
	data.stats.attack = int(_attack_spin.value)
	data.stats.attack_range = int(_range_spin.value)
	data.stats.movement_pattern = _move_pattern_option.get_selected_id() as UnitStats.MovementPattern
	data.stats.steps_per_turn = int(_move_steps_spin.value)

	var ability_idx := _ability_option.selected - 1
	if ability_idx >= 0 and ability_idx < _abilities.size():
		data.ability = _abilities[ability_idx]
	else:
		data.ability = null

	data.icon = _icon_picker.edited_resource as Texture2D


func _on_icon_changed(resource: Resource) -> void:
	_update_icon_preview(resource as Texture2D)


func _update_icon_preview(tex: Texture2D) -> void:
	_icon_preview.texture = tex


func _check_warnings() -> void:
	if _current_data == null:
		return
	var warnings: PackedStringArray = []
	if UnitCatalog.is_player(_current_data) and _current_data.ability == null:
		warnings.append("友方单位建议配置 ability")
	if not _current_path.is_empty():
		var file_stem := _current_path.get_file().get_basename()
		if _current_data.id != file_stem:
			warnings.append("id 与文件名不一致（保存不会自动改名）")
	if warnings.is_empty():
		return
	_set_status("⚠ " + " · ".join(warnings))


func _on_new_pressed() -> void:
	var data := UnitData.new()
	data.stats = UnitStats.new()
	match _get_tab_filter():
		TabFilter.ENEMY:
			data.team_default = UnitInstance.Team.ENEMY
			data.id = "enemy_new"
			data.display_name = "新敌人"
		_:
			data.team_default = UnitInstance.Team.PLAYER
			data.id = "unit_new"
			data.display_name = "新单位"
	data.cost = 1
	data.tier = 1
	_current_path = ""
	_current_data = data
	_load_form_from_data(data)
	_unit_list.deselect_all()
	_set_status("新建草稿 — 填写 id 后点保存")


func _on_duplicate_pressed() -> void:
	if _current_data == null:
		_set_status("请先选择或新建单位")
		return
	var copy: UnitData = _current_data.duplicate(true) as UnitData
	if copy.stats != null:
		copy.stats = copy.stats.duplicate_stats()
	copy.id = _current_data.id + "_copy"
	copy.display_name = _current_data.display_name + " 副本"
	_current_path = ""
	_current_data = copy
	_load_form_from_data(copy)
	_unit_list.deselect_all()
	_set_status("已复制为草稿 — 修改 id 后保存")


func _on_save_pressed() -> void:
	if _current_data == null:
		_set_status("无选中单位")
		return
	_apply_form_to_data(_current_data)
	if _current_data.id.is_empty():
		_set_status("id 不能为空")
		return

	var path := _current_path
	if path.is_empty():
		path = "%s/%s.tres" % [UNITS_DIR, _current_data.id]
		if ResourceLoader.exists(path):
			_set_status("文件已存在：%s" % path)
			return

	if _current_data.stats != null:
		_current_data.stats.resource_local_to_scene = false

	var err := ResourceSaver.save(_current_data, path)
	if err != OK:
		_set_status("保存失败：错误码 %d" % err)
		return

	_current_path = path
	_reload_catalog()
	_select_path_in_list(path)
	_set_status("已保存 %s" % path)
	_check_warnings()


func _select_path_in_list(path: String, reload_form: bool = true) -> void:
	for i in _filtered_entries.size():
		if _filtered_entries[i].get("path", "") == path:
			_unit_list.select(i)
			if reload_form:
				_on_unit_selected(i)
			return


func _ensure_delete_dialog() -> void:
	if _delete_dialog != null:
		return
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "删除角色"
	_delete_dialog.ok_button_text = "删除"
	_delete_dialog.confirmed.connect(_confirm_delete)
	add_child(_delete_dialog)


func _on_delete_pressed() -> void:
	if _current_path.is_empty():
		_set_status("草稿无法删除，请先保存或放弃")
		return
	if not _current_path.ends_with(".tres"):
		_set_status("只能删除已保存的 .tres 资源文件")
		return
	_pending_delete_path = _current_path
	_ensure_delete_dialog()
	_delete_dialog.dialog_text = (
		"确定从磁盘删除以下角色文件？\n%s\n\n"
		+ "此操作不可撤销。请自行检查波次/商店/技能中的引用。"
		% _pending_delete_path
	)
	_delete_dialog.popup_centered()


func _confirm_delete() -> void:
	var path := _pending_delete_path
	if path.is_empty():
		_set_status("未指定删除路径")
		return

	var err := _delete_unit_file(path)
	_pending_delete_path = ""
	if err != OK:
		_set_status("删除失败：%s（错误码 %d）" % [path, err])
		return

	if _current_path == path:
		_current_path = ""
		_current_data = null
		_clear_form()
	_reload_catalog()
	_set_status("已从磁盘删除 %s" % path)


func _delete_unit_file(res_path: String) -> Error:
	if res_path.is_empty() or not res_path.begins_with("res://"):
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(res_path):
		return ERR_FILE_NOT_FOUND

	if _editor_interface != null:
		var fs: EditorFileSystem = _editor_interface.get_resource_filesystem()
		if fs != null and fs.has_method("delete_files"):
			fs.delete_files(PackedStringArray([res_path]))
			return OK

	var abs_path := ProjectSettings.globalize_path(res_path)
	if abs_path.is_empty():
		return ERR_FILE_NOT_FOUND
	var err := DirAccess.remove_absolute(abs_path)
	if err != OK:
		return err

	if _editor_interface != null:
		var fs_scan: EditorFileSystem = _editor_interface.get_resource_filesystem()
		if fs_scan != null:
			fs_scan.call_deferred("scan")
	return OK


func _clear_form() -> void:
	_loading_form = true
	_id_edit.text = ""
	_name_edit.text = ""
	_cost_spin.value = 1
	_tier_spin.value = 1
	_kill_gold_spin.value = -1
	_max_hp_spin.value = 10
	_attack_spin.value = 3
	_range_spin.value = 1
	_select_movement_pattern(UnitStats.MovementPattern.ORTHOGONAL)
	_move_steps_spin.value = 1
	_ensure_ability_options_populated()
	_safe_option_select(_ability_option, 0)
	_icon_picker.edited_resource = null
	_update_icon_preview(null)
	_loading_form = false


func _on_inspector_pressed() -> void:
	if _current_data == null:
		_set_status("无选中单位")
		return
	_apply_form_to_data(_current_data)
	if _editor_interface != null:
		_editor_interface.edit_resource(_current_data)
		_set_status("已在检查器中打开（passives 等高级字段）")
	else:
		_set_status("EditorInterface 不可用")


func _set_status(text: String) -> void:
	_status_label.text = text
