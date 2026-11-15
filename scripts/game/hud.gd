class_name GameHud
extends CanvasLayer
## Phase E HUD: dual currency + relic bar/shop + shrine choice; keeps A–D panels.


signal shop_buy_pressed(slot_index: int)
signal shop_refresh_pressed
signal shop_upgrade_pressed
signal shop_sell_pressed(follower_index: int)
signal relic_buy_pressed(slot_index: int)
signal relic_refresh_pressed
signal shrine_choice_pressed(choice_index: int)
signal shrine_interact_pressed
signal shop_closed
signal chest_pick_pressed(choice_index: int)
signal restart_pressed
signal main_menu_pressed
signal assemble_pressed
signal rage_pressed
signal portal_confirm_pressed
signal next_floor_pressed

## Presentation range for threat bar fill (matches ThreatConfig defaults; not a formula change).
const THREAT_BAR_MIN := 1.0
const THREAT_BAR_MAX := 2.5

var gold: int = 0
var corpus: int = 0

var _root: Control
var _gold_label: Label
var _corpus_label: Label
var _threat_label: Label
var _threat_bar: ProgressBar
var _threat_bar_fill: StyleBoxFlat
var _floor_label: Label
var _hint_label: Label
var _revive_panel: PanelContainer
var _revive_title: Label
var _revive_list: VBoxContainer
var _oath_panel: PanelContainer
var _oath_title: Label
var _oath_list: VBoxContainer
var _relic_panel: PanelContainer
var _relic_title: Label
var _relic_list: VBoxContainer
var _shop_panel: PanelContainer
var _shop_title: Label
var _shop_status: Label
var _shop_list: VBoxContainer
var _shop_army_list: VBoxContainer
var _shop_refresh_btn: Button
var _shop_upgrade_btn: Button
var _shop_next_btn: Button
var _relic_shop_status: Label
var _relic_shop_list: VBoxContainer
var _relic_refresh_btn: Button
var _owned_relic_list: VBoxContainer
var _chest_panel: PanelContainer
var _chest_list: HBoxContainer
var _shrine_panel: PanelContainer
var _shrine_title: Label
var _end_panel: PanelContainer
var _end_label: Label
var _end_stats_label: Label
var _interstitial_panel: PanelContainer
var _interstitial_label: Label
var _cmd_row: HBoxContainer
var _assemble_btn: Button
var _rage_btn: Button
var _portal_btn: Button
var _shrine_btn: Button
var _joystick: VirtualJoystick


func _ready() -> void:
	layer = 20
	_build_ui()
	refresh_gold(gold)
	refresh_corpus(corpus)
	refresh_threat(1.0, "平静", 0)
	refresh_floor(1)
	set_command_cooldowns(0.0, 0.0, 0.0, 0.0)
	set_portal_prompt_visible(false)
	set_shrine_prompt_visible(false)


func get_joystick_vector() -> Vector2:
	if _joystick == null:
		return Vector2.ZERO
	return _joystick.get_vector()


func refresh_gold(amount: int) -> void:
	gold = amount
	if _gold_label != null:
		_gold_label.text = "达克特: %d" % gold


func refresh_corpus(amount: int) -> void:
	corpus = amount
	if _corpus_label != null:
		_corpus_label.text = "尸骸: %d" % corpus


func refresh_threat(multiplier: float, tier_label: String, tier_index: int) -> void:
	# Signature unchanged (multiplier, tier_label, tier_index). Presentation only.
	var color := _threat_tier_color(tier_index)
	if _threat_label != null:
		_threat_label.text = "威胁: %s · ×%.2f" % [tier_label, multiplier]
		_threat_label.modulate = color
	if _threat_bar != null:
		var span := maxf(0.001, THREAT_BAR_MAX - THREAT_BAR_MIN)
		var t := clampf((multiplier - THREAT_BAR_MIN) / span, 0.0, 1.0)
		# Keep a small visible stub at floor start so the bar channel is obvious.
		_threat_bar.value = maxf(t * 100.0, 4.0)
		if _threat_bar_fill != null:
			_threat_bar_fill.bg_color = color
		_threat_bar.modulate = Color(1, 1, 1, 1)


func refresh_floor(floor_index: int, total_floors: int = 0, dungeon_label: String = "") -> void:
	if _floor_label == null:
		return
	var fi := maxi(1, floor_index)
	var text := "第 %d 层" % fi
	if total_floors > 0:
		text = "第 %d/%d 层" % [fi, total_floors]
		if total_floors > 0 and fi >= total_floors:
			text += " · 终局"
	if not dungeon_label.is_empty():
		text += " · %s" % dungeon_label
	_floor_label.text = text


func set_command_cooldowns(
	assemble_remaining: float,
	assemble_total: float,
	rage_remaining: float,
	rage_total: float
) -> void:
	if _assemble_btn != null:
		if assemble_remaining > 0.0:
			_assemble_btn.disabled = true
			_assemble_btn.text = "集合 (%.0fs)" % ceil(assemble_remaining)
		else:
			_assemble_btn.disabled = false
			_assemble_btn.text = "集合 (Q)"
	if _rage_btn != null:
		if rage_remaining > 0.0:
			_rage_btn.disabled = true
			_rage_btn.text = "怒意 (%.0fs)" % ceil(rage_remaining)
		else:
			_rage_btn.disabled = false
			_rage_btn.text = "怒意 (R)"
	# Silence unused when totals are 0 (HUD still works).
	if assemble_total < 0.0 or rage_total < 0.0:
		pass


func set_portal_prompt_visible(visible_on: bool) -> void:
	if _portal_btn != null:
		_portal_btn.visible = visible_on


func set_shrine_prompt_visible(visible_on: bool) -> void:
	if _shrine_btn != null:
		_shrine_btn.visible = visible_on


func show_interstitial(floor_cleared: int) -> void:
	# Legacy stub path: prefer show_shop_interstitial from GameController.
	if _interstitial_label != null:
		_interstitial_label.text = "离开第 %d 层\n层间营地" % floor_cleared
	if _interstitial_panel != null:
		_interstitial_panel.visible = true
	if _shop_panel != null:
		_shop_panel.visible = false
	if _chest_panel != null:
		_chest_panel.visible = false
	if _end_panel != null:
		_end_panel.visible = false
	if _cmd_row != null:
		_cmd_row.visible = false
	set_portal_prompt_visible(false)


func show_shop_interstitial(
	floor_cleared: int,
	shelf: Array,
	current_gold: int,
	refresh_cost: int,
	recruit_level: int,
	upgrade_cost: int,
	interest_gained: int,
	army_rows: Array,
	type_count: int,
	type_cap: int,
	status_text: String = "",
	current_corpus: int = 0,
	relic_shelf: Array = [],
	relic_refresh_cost: int = 2,
	owned_relics: Array = [],
	relic_max_slots: int = 3,
	relic_status_text: String = ""
) -> void:
	refresh_gold(current_gold)
	refresh_corpus(current_corpus)
	refresh_relics(owned_relics, relic_max_slots)
	if _interstitial_panel != null:
		_interstitial_panel.visible = false
	if _chest_panel != null:
		_chest_panel.visible = false
	if _shrine_panel != null:
		_shrine_panel.visible = false
	if _end_panel != null:
		_end_panel.visible = false
	if _cmd_row != null:
		_cmd_row.visible = false
	set_portal_prompt_visible(false)
	set_shrine_prompt_visible(false)
	if _shop_title != null:
		var interest_line := ""
		if interest_gained > 0:
			interest_line = " · 利息 +%d" % interest_gained
		elif interest_gained == 0:
			interest_line = " · 利息 +0"
		_shop_title.text = "第 %d 层后 · 招兵/遗物%s" % [floor_cleared, interest_line]
	_rebuild_shop_shelf(shelf, current_gold)
	_rebuild_shop_army(army_rows)
	_rebuild_relic_shelf(relic_shelf, current_corpus, owned_relics.size(), relic_max_slots)
	_rebuild_owned_relics(owned_relics, relic_max_slots)
	if _shop_refresh_btn != null:
		_shop_refresh_btn.text = "刷新 (-%d)" % maxi(0, refresh_cost)
		_shop_refresh_btn.disabled = current_gold < refresh_cost
	if _shop_upgrade_btn != null:
		if upgrade_cost < 0:
			_shop_upgrade_btn.text = "招募等级 Lv%d (满)" % recruit_level
			_shop_upgrade_btn.disabled = true
		else:
			_shop_upgrade_btn.text = "招募等级 Lv%d → (-%d)" % [recruit_level, upgrade_cost]
			_shop_upgrade_btn.disabled = current_gold < upgrade_cost
	if _relic_refresh_btn != null:
		_relic_refresh_btn.text = "刷新遗物 (-%d尸骸)" % maxi(0, relic_refresh_cost)
		_relic_refresh_btn.disabled = current_corpus < relic_refresh_cost
	if _shop_status != null:
		var base := "种类 %d/%d · 达克特 %d · 尸骸 %d" % [
			type_count, type_cap, current_gold, current_corpus,
		]
		if status_text != "":
			base = "%s · %s" % [base, status_text]
		_shop_status.text = base
	if _relic_shop_status != null:
		var rbase := "遗物槽 %d/%d" % [owned_relics.size(), relic_max_slots]
		if relic_status_text != "":
			rbase = "%s · %s" % [rbase, relic_status_text]
		_relic_shop_status.text = rbase
	if _shop_panel != null:
		_shop_panel.visible = true


func hide_interstitial() -> void:
	if _interstitial_panel != null:
		_interstitial_panel.visible = false
	if _shop_panel != null:
		_shop_panel.visible = false
	if _shrine_panel != null:
		_shrine_panel.visible = false
	if _cmd_row != null:
		_cmd_row.visible = true


func show_shop(shelf: Array[Dictionary], current_gold: int, refresh_cost: int = 10) -> void:
	# Compatibility shim: open a minimal shop view without army/interest.
	show_shop_interstitial(
		0,
		shelf,
		current_gold,
		refresh_cost,
		1,
		-1,
		0,
		[],
		0,
		6,
		""
	)


func hide_shop() -> void:
	if _shop_panel != null:
		_shop_panel.visible = false


func show_chest_pick(choices: Array) -> void:
	# Phase B: three-pick recruit still disabled.
	hide_chest_pick()
	if choices.is_empty():
		pass


func hide_chest_pick() -> void:
	if _chest_panel != null:
		_chest_panel.visible = false


func show_end(won: bool, stats: Dictionary = {}) -> void:
	if _end_label != null:
		_end_label.text = "胜利！终局 Boss 已击败" if won else "失败…指挥官阵亡"
		_end_label.add_theme_color_override(
			"font_color",
			Color(0.95, 0.86, 0.45, 1.0) if won else Color(1.0, 0.55, 0.5, 1.0)
		)
	if _end_stats_label != null:
		var floors_reached := int(stats.get("floors_reached", stats.get("floor_index", 1)))
		var total := int(stats.get("total_floors", 0))
		var ducats := int(stats.get("ducats", 0))
		var corpus_amt := int(stats.get("corpus", 0))
		var dungeon := str(stats.get("dungeon_label", ""))
		var floor_line := "层数：%d" % floors_reached
		if total > 0:
			floor_line = "层数：%d / %d" % [floors_reached, total]
		var lines: PackedStringArray = PackedStringArray([
			floor_line,
			"达克特：%d" % ducats,
			"尸骸：%d" % corpus_amt,
		])
		if not dungeon.is_empty():
			lines.append("地城：%s" % dungeon)
		_end_stats_label.text = "\n".join(lines)
	if _end_panel != null:
		_end_panel.visible = true
	hide_shop()
	hide_chest_pick()
	hide_interstitial()
	hide_shrine_choice()
	if _cmd_row != null:
		_cmd_row.visible = false
	set_portal_prompt_visible(false)
	set_shrine_prompt_visible(false)


func set_world_hint(text: String) -> void:
	if _hint_label != null:
		_hint_label.text = text


func set_shop_status(text: String) -> void:
	if _shop_status != null:
		_shop_status.text = text


func refresh_revive_queue(rows: Array) -> void:
	if _revive_list == null:
		return
	for child in _revive_list.get_children():
		_revive_list.remove_child(child)
		child.queue_free()
	if _revive_panel != null:
		_revive_panel.visible = true
	if _revive_title != null:
		_revive_title.text = "复活队列 (%d)" % rows.size()
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "（空）"
		empty.add_theme_font_size_override("font_size", 12)
		_revive_list.add_child(empty)
		return
	for row_data in rows:
		var info: Dictionary = row_data
		var name_str := str(info.get("name", "?"))
		var rank_lbl := str(info.get("rank_label", ""))
		var rem := float(info.get("remaining", 0.0))
		var kw := StringName(str(info.get("keyword", &"")))
		var rank_i := int(info.get("rank", 0))
		var line := "%s·%s  %.0fs" % [rank_lbl, name_str, ceil(rem)]
		if rank_i >= 2 and kw != &"":
			line = "%s·%s[%s]  %.0fs" % [rank_lbl, name_str, String(kw), ceil(rem)]
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.85))
		lbl.add_theme_constant_override("outline_size", 2)
		_revive_list.add_child(lbl)


func refresh_relics(rows: Array, max_slots: int = 3) -> void:
	if _relic_list == null:
		return
	for child in _relic_list.get_children():
		_relic_list.remove_child(child)
		child.queue_free()
	if _relic_panel != null:
		_relic_panel.visible = true
	if _relic_title != null:
		_relic_title.text = "遗物 (%d/%d)" % [rows.size(), maxi(1, max_slots)]
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "（空）"
		empty.add_theme_font_size_override("font_size", 12)
		_relic_list.add_child(empty)
		return
	for row_data in rows:
		var info: Dictionary = row_data
		var name_str := str(info.get("name", "?"))
		var desc := str(info.get("description", ""))
		var line := name_str if desc == "" else "%s · %s" % [name_str, desc]
		var lbl := Label.new()
		lbl.text = line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.95, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.85))
		lbl.add_theme_constant_override("outline_size", 2)
		_relic_list.add_child(lbl)


func show_shrine_choice(title_text: String = "神龛") -> void:
	if _shrine_title != null:
		_shrine_title.text = title_text
	if _shrine_panel != null:
		_shrine_panel.visible = true
	if _cmd_row != null:
		_cmd_row.visible = false
	set_shrine_prompt_visible(false)


func hide_shrine_choice() -> void:
	if _shrine_panel != null:
		_shrine_panel.visible = false
	if _cmd_row != null and (_shop_panel == null or not _shop_panel.visible) and (
		_end_panel == null or not _end_panel.visible
	):
		_cmd_row.visible = true


func refresh_oaths(rows: Array) -> void:
	if _oath_list == null:
		return
	for child in _oath_list.get_children():
		_oath_list.remove_child(child)
		child.queue_free()
	if _oath_panel != null:
		_oath_panel.visible = true
	var lit_n := 0
	for row_data in rows:
		if bool((row_data as Dictionary).get("lit", false)):
			lit_n += 1
	if _oath_title != null:
		_oath_title.text = "誓约 (%d 点亮)" % lit_n
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "（无）"
		empty.add_theme_font_size_override("font_size", 12)
		_oath_list.add_child(empty)
		return
	for row_data in rows:
		var info: Dictionary = row_data
		var name_str := str(info.get("name", "?"))
		var kw := String(info.get("keyword", ""))
		var count := int(info.get("count", 0))
		var tier := int(info.get("tier", 0))
		var next_need := int(info.get("next_threshold", 2))
		var lit := bool(info.get("lit", false))
		var status := "熄灭" if not lit else ("T%d" % tier)
		var line := "%s[%s] %s %d/%d" % [name_str, kw, status, count, next_need]
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 12)
		if lit:
			lbl.add_theme_color_override("font_color", Color(0.95, 0.86, 0.45, 1.0))
		else:
			lbl.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
		lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.85))
		lbl.add_theme_constant_override("outline_size", 2)
		_oath_list.add_child(lbl)


func _threat_tier_color(tier_index: int) -> Color:
	## Blue → amber → purple-gray (not red/green alone; text + bar length also encode state).
	match clampi(tier_index, 0, 3):
		0:
			return Color(0.45, 0.72, 0.95, 1.0)  # calm blue
		1:
			return Color(0.95, 0.78, 0.35, 1.0)  # amber caution
		2:
			return Color(0.92, 0.58, 0.28, 1.0)  # deep amber pressure
		_:
			return Color(0.62, 0.52, 0.72, 1.0)  # purple-gray overwhelm


func _rebuild_shop_shelf(shelf: Array, current_gold: int) -> void:
	if _shop_list == null:
		return
	for child in _shop_list.get_children():
		_shop_list.remove_child(child)
		child.queue_free()
	if shelf.is_empty():
		var empty := Label.new()
		empty.text = "货架空"
		_shop_list.add_child(empty)
		return
	for i in shelf.size():
		var slot: Dictionary = shelf[i]
		var unit: UnitDefinition = slot.get("unit") as UnitDefinition
		var price := int(slot.get("price", 0))
		var sold := bool(slot.get("sold_out", false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_lbl := Label.new()
		var unit_name := unit.display_name if unit != null else "?"
		var rarity := unit.rarity_tier if unit != null else 1
		name_lbl.text = "[%d] %s · R%d · %d达克特" % [i + 1, unit_name, rarity, price]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(88, 36)
		if sold:
			buy.text = "已购"
			buy.disabled = true
		elif current_gold < price:
			buy.text = "钱不够"
			buy.disabled = true
		else:
			buy.text = "购买"
			buy.disabled = false
		var slot_i := i
		buy.pressed.connect(func() -> void: shop_buy_pressed.emit(slot_i))
		row.add_child(buy)
		_shop_list.add_child(row)


func _rebuild_shop_army(army_rows: Array) -> void:
	if _shop_army_list == null:
		return
	for child in _shop_army_list.get_children():
		_shop_army_list.remove_child(child)
		child.queue_free()
	var header := Label.new()
	header.text = "军队（出售返还部分达克特）"
	_shop_army_list.add_child(header)
	if army_rows.is_empty():
		var empty := Label.new()
		empty.text = "无随从可售"
		_shop_army_list.add_child(empty)
		return
	for i in army_rows.size():
		var row_data: Dictionary = army_rows[i]
		var name_str := str(row_data.get("name", "?"))
		var refund := int(row_data.get("refund", 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.text = "%s · 售 %+d" % [name_str, refund]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var sell := Button.new()
		sell.text = "出售"
		sell.custom_minimum_size = Vector2(72, 32)
		var idx := int(row_data.get("index", i))
		sell.pressed.connect(func() -> void: shop_sell_pressed.emit(idx))
		row.add_child(sell)
		_shop_army_list.add_child(row)


func _rebuild_relic_shelf(
	shelf: Array,
	current_corpus: int,
	owned_count: int,
	max_slots: int
) -> void:
	if _relic_shop_list == null:
		return
	for child in _relic_shop_list.get_children():
		_relic_shop_list.remove_child(child)
		child.queue_free()
	if shelf.is_empty():
		var empty := Label.new()
		empty.text = "遗物货架空"
		_relic_shop_list.add_child(empty)
		return
	var slots_full := owned_count >= max_slots
	for i in shelf.size():
		var slot: Dictionary = shelf[i]
		var relic: RelicDefinition = slot.get("relic") as RelicDefinition
		var price := int(slot.get("price", 0))
		var sold := bool(slot.get("sold_out", false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_lbl := Label.new()
		var relic_name := relic.display_name if relic != null else "?"
		var desc := relic.description if relic != null else ""
		name_lbl.text = "[%d] %s · %d尸骸" % [i + 1, relic_name, price]
		if desc != "":
			name_lbl.text += "\n  %s" % desc
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(96, 36)
		if sold:
			buy.text = "已购"
			buy.disabled = true
		elif slots_full:
			buy.text = "槽满"
			buy.disabled = true
		elif current_corpus < price:
			buy.text = "尸骸不够"
			buy.disabled = true
		else:
			buy.text = "购买"
			buy.disabled = false
		var slot_i := i
		buy.pressed.connect(func() -> void: relic_buy_pressed.emit(slot_i))
		row.add_child(buy)
		_relic_shop_list.add_child(row)


func _rebuild_owned_relics(owned_relics: Array, max_slots: int) -> void:
	if _owned_relic_list == null:
		return
	for child in _owned_relic_list.get_children():
		_owned_relic_list.remove_child(child)
		child.queue_free()
	var header := Label.new()
	header.text = "持有遗物 (%d/%d)" % [owned_relics.size(), maxi(1, max_slots)]
	_owned_relic_list.add_child(header)
	if owned_relics.is_empty():
		var empty := Label.new()
		empty.text = "尚未持有遗物"
		_owned_relic_list.add_child(empty)
		return
	for row_data in owned_relics:
		var info: Dictionary = row_data
		var lbl := Label.new()
		lbl.text = "- %s" % str(info.get("name", "?"))
		lbl.add_theme_font_size_override("font_size", 12)
		_owned_relic_list.add_child(lbl)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFonts.apply_to_control(_root)
	add_child(_root)

	_floor_label = Label.new()
	_floor_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_floor_label.offset_left = 16
	_floor_label.offset_top = 10
	_floor_label.offset_right = -16
	_floor_label.offset_bottom = 36
	_floor_label.add_theme_font_size_override("font_size", 20)
	_floor_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.9))
	_floor_label.add_theme_constant_override("outline_size", 3)
	_floor_label.text = "第 1 层"
	_root.add_child(_floor_label)

	_threat_label = Label.new()
	_threat_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_threat_label.offset_left = 16
	_threat_label.offset_top = 36
	_threat_label.offset_right = -16
	_threat_label.offset_bottom = 62
	_threat_label.add_theme_font_size_override("font_size", 17)
	_threat_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.9))
	_threat_label.add_theme_constant_override("outline_size", 3)
	_threat_label.text = "威胁: 平静 · ×1.00"
	_root.add_child(_threat_label)

	_threat_bar = ProgressBar.new()
	_threat_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_threat_bar.offset_left = 16
	_threat_bar.offset_top = 64
	_threat_bar.offset_right = -16
	_threat_bar.offset_bottom = 82
	_threat_bar.min_value = 0.0
	_threat_bar.max_value = 100.0
	_threat_bar.value = 0.0
	_threat_bar.show_percentage = false
	_threat_bar.custom_minimum_size = Vector2(0, 18)
	_threat_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg := StyleBoxFlat.new()
	# Light track so empty/low fill stays readable (not dark-on-dark).
	bar_bg.bg_color = Color(0.22, 0.26, 0.34, 0.92)
	bar_bg.border_color = Color(0.75, 0.8, 0.9, 0.85)
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(5)
	bar_bg.set_content_margin_all(2)
	_threat_bar_fill = StyleBoxFlat.new()
	_threat_bar_fill.bg_color = _threat_tier_color(0)
	_threat_bar_fill.set_corner_radius_all(3)
	_threat_bar.add_theme_stylebox_override("background", bar_bg)
	_threat_bar.add_theme_stylebox_override("fill", _threat_bar_fill)
	_root.add_child(_threat_bar)

	_gold_label = Label.new()
	_gold_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_gold_label.offset_left = 16
	_gold_label.offset_top = 86
	_gold_label.offset_right = -220
	_gold_label.offset_bottom = 112
	_gold_label.add_theme_font_size_override("font_size", 15)
	_gold_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.85))
	_gold_label.add_theme_constant_override("outline_size", 2)
	_gold_label.text = "达克特: 0"
	_root.add_child(_gold_label)

	_corpus_label = Label.new()
	_corpus_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_corpus_label.offset_left = 200
	_corpus_label.offset_top = 86
	_corpus_label.offset_right = -16
	_corpus_label.offset_bottom = 112
	_corpus_label.add_theme_font_size_override("font_size", 15)
	_corpus_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.95, 1.0))
	_corpus_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.85))
	_corpus_label.add_theme_constant_override("outline_size", 2)
	_corpus_label.text = "尸骸: 0"
	_root.add_child(_corpus_label)

	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_left = 16
	_hint_label.offset_top = 112
	_hint_label.offset_right = -16
	_hint_label.offset_bottom = 162
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.8))
	_hint_label.add_theme_constant_override("outline_size", 2)
	_hint_label.text = "WASD/摇杆移动 · Q集合 · R怒意 · 靠近传送门/神龛"
	_root.add_child(_hint_label)

	_joystick = VirtualJoystick.new()
	_joystick.name = "VirtualJoystick"
	_root.add_child(_joystick)

	# Phase C: revive queue, bottom-left (above command row / joystick).
	_revive_panel = PanelContainer.new()
	_revive_panel.name = "ReviveQueuePanel"
	_revive_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_revive_panel.offset_left = 12
	_revive_panel.offset_right = 260
	_revive_panel.offset_top = -320
	_revive_panel.offset_bottom = -220
	_revive_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var revive_style := StyleBoxFlat.new()
	revive_style.bg_color = Color(0.08, 0.1, 0.14, 0.82)
	revive_style.border_color = Color(0.65, 0.72, 0.85, 0.9)
	revive_style.set_border_width_all(1)
	revive_style.set_content_margin_all(8)
	revive_style.set_corner_radius_all(6)
	_revive_panel.add_theme_stylebox_override("panel", revive_style)
	_root.add_child(_revive_panel)
	var revive_v := VBoxContainer.new()
	revive_v.add_theme_constant_override("separation", 2)
	_revive_panel.add_child(revive_v)
	_revive_title = Label.new()
	_revive_title.text = "复活队列 (0)"
	_revive_title.add_theme_font_size_override("font_size", 13)
	_revive_title.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.9))
	_revive_title.add_theme_constant_override("outline_size", 2)
	revive_v.add_child(_revive_title)
	_revive_list = VBoxContainer.new()
	_revive_list.add_theme_constant_override("separation", 1)
	revive_v.add_child(_revive_list)
	var empty_q := Label.new()
	empty_q.text = "（空）"
	empty_q.add_theme_font_size_override("font_size", 12)
	_revive_list.add_child(empty_q)

	# Phase D: oath progress, top-right under floor/threat.
	_oath_panel = PanelContainer.new()
	_oath_panel.name = "OathPanel"
	_oath_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_oath_panel.offset_left = -280
	_oath_panel.offset_right = -12
	_oath_panel.offset_top = 96
	_oath_panel.offset_bottom = 210
	_oath_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var oath_style := StyleBoxFlat.new()
	oath_style.bg_color = Color(0.1, 0.09, 0.12, 0.84)
	oath_style.border_color = Color(0.85, 0.72, 0.35, 0.95)
	oath_style.set_border_width_all(1)
	oath_style.set_content_margin_all(8)
	oath_style.set_corner_radius_all(6)
	_oath_panel.add_theme_stylebox_override("panel", oath_style)
	_root.add_child(_oath_panel)
	var oath_v := VBoxContainer.new()
	oath_v.add_theme_constant_override("separation", 2)
	_oath_panel.add_child(oath_v)
	_oath_title = Label.new()
	_oath_title.text = "誓约 (0 点亮)"
	_oath_title.add_theme_font_size_override("font_size", 13)
	_oath_title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.45, 1.0))
	_oath_title.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.9))
	_oath_title.add_theme_constant_override("outline_size", 2)
	oath_v.add_child(_oath_title)
	_oath_list = VBoxContainer.new()
	_oath_list.add_theme_constant_override("separation", 1)
	oath_v.add_child(_oath_list)
	var empty_o := Label.new()
	empty_o.text = "（无）"
	empty_o.add_theme_font_size_override("font_size", 12)
	_oath_list.add_child(empty_o)

	# Phase E: relic inventory under oaths.
	_relic_panel = PanelContainer.new()
	_relic_panel.name = "RelicPanel"
	_relic_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_relic_panel.offset_left = -280
	_relic_panel.offset_right = -12
	_relic_panel.offset_top = 218
	_relic_panel.offset_bottom = 330
	_relic_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var relic_style := StyleBoxFlat.new()
	relic_style.bg_color = Color(0.1, 0.09, 0.14, 0.84)
	relic_style.border_color = Color(0.72, 0.65, 0.88, 0.95)
	relic_style.set_border_width_all(1)
	relic_style.set_content_margin_all(8)
	relic_style.set_corner_radius_all(6)
	_relic_panel.add_theme_stylebox_override("panel", relic_style)
	_root.add_child(_relic_panel)
	var relic_v := VBoxContainer.new()
	relic_v.add_theme_constant_override("separation", 2)
	_relic_panel.add_child(relic_v)
	_relic_title = Label.new()
	_relic_title.text = "遗物 (0/3)"
	_relic_title.add_theme_font_size_override("font_size", 13)
	_relic_title.add_theme_color_override("font_color", Color(0.88, 0.82, 0.95, 1.0))
	_relic_title.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.9))
	_relic_title.add_theme_constant_override("outline_size", 2)
	relic_v.add_child(_relic_title)
	_relic_list = VBoxContainer.new()
	_relic_list.add_theme_constant_override("separation", 1)
	relic_v.add_child(_relic_list)
	var empty_r := Label.new()
	empty_r.text = "（空）"
	empty_r.add_theme_font_size_override("font_size", 12)
	_relic_list.add_child(empty_r)

	_cmd_row = HBoxContainer.new()
	_cmd_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cmd_row.offset_left = 12
	_cmd_row.offset_right = -12
	_cmd_row.offset_top = -210
	_cmd_row.offset_bottom = -150
	_cmd_row.add_theme_constant_override("separation", 10)
	_cmd_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_cmd_row)

	_assemble_btn = Button.new()
	_assemble_btn.text = "集合 (Q)"
	_assemble_btn.custom_minimum_size = Vector2(110, 48)
	_assemble_btn.pressed.connect(func() -> void: assemble_pressed.emit())
	_cmd_row.add_child(_assemble_btn)

	_rage_btn = Button.new()
	_rage_btn.text = "怒意 (R)"
	_rage_btn.custom_minimum_size = Vector2(110, 48)
	_rage_btn.pressed.connect(func() -> void: rage_pressed.emit())
	_cmd_row.add_child(_rage_btn)

	_portal_btn = Button.new()
	_portal_btn.text = "进入传送门 (E)"
	_portal_btn.custom_minimum_size = Vector2(160, 48)
	_portal_btn.visible = false
	_portal_btn.pressed.connect(func() -> void: portal_confirm_pressed.emit())
	_cmd_row.add_child(_portal_btn)

	_shrine_btn = Button.new()
	_shrine_btn.text = "祈愿神龛 (E)"
	_shrine_btn.custom_minimum_size = Vector2(160, 48)
	_shrine_btn.visible = false
	_shrine_btn.pressed.connect(func() -> void: shrine_interact_pressed.emit())
	_cmd_row.add_child(_shrine_btn)

	# Phase B/E shop panel (interstitial: ducats + corpus relics).
	_shop_panel = _make_centered_panel(Vector2(560, 640))
	_shop_panel.visible = false
	_root.add_child(_shop_panel)
	var shop_scroll := ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_scroll.custom_minimum_size = Vector2(520, 600)
	_shop_panel.add_child(shop_scroll)
	var shop_v := VBoxContainer.new()
	shop_v.add_theme_constant_override("separation", 8)
	shop_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_scroll.add_child(shop_v)
	_shop_title = Label.new()
	_shop_title.add_theme_font_size_override("font_size", 18)
	_shop_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_title.text = "招兵/遗物"
	shop_v.add_child(_shop_title)
	_shop_status = Label.new()
	_shop_status.add_theme_font_size_override("font_size", 13)
	_shop_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_status.text = "种类 0/6"
	shop_v.add_child(_shop_status)
	var shelf_header := Label.new()
	shelf_header.text = "招兵货架（达克特）"
	shop_v.add_child(shelf_header)
	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 6)
	shop_v.add_child(_shop_list)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	shop_v.add_child(action_row)
	_shop_refresh_btn = Button.new()
	_shop_refresh_btn.text = "刷新"
	_shop_refresh_btn.custom_minimum_size = Vector2(140, 40)
	_shop_refresh_btn.pressed.connect(func() -> void: shop_refresh_pressed.emit())
	action_row.add_child(_shop_refresh_btn)
	_shop_upgrade_btn = Button.new()
	_shop_upgrade_btn.text = "招募等级"
	_shop_upgrade_btn.custom_minimum_size = Vector2(200, 40)
	_shop_upgrade_btn.pressed.connect(func() -> void: shop_upgrade_pressed.emit())
	action_row.add_child(_shop_upgrade_btn)
	_shop_army_list = VBoxContainer.new()
	_shop_army_list.add_theme_constant_override("separation", 4)
	shop_v.add_child(_shop_army_list)
	var relic_header := Label.new()
	relic_header.text = "遗物货架（尸骸）"
	relic_header.add_theme_color_override("font_color", Color(0.88, 0.82, 0.95, 1.0))
	shop_v.add_child(relic_header)
	_relic_shop_status = Label.new()
	_relic_shop_status.add_theme_font_size_override("font_size", 13)
	_relic_shop_status.text = "遗物槽 0/3"
	shop_v.add_child(_relic_shop_status)
	_relic_shop_list = VBoxContainer.new()
	_relic_shop_list.add_theme_constant_override("separation", 6)
	shop_v.add_child(_relic_shop_list)
	_relic_refresh_btn = Button.new()
	_relic_refresh_btn.text = "刷新遗物"
	_relic_refresh_btn.custom_minimum_size = Vector2(200, 40)
	_relic_refresh_btn.pressed.connect(func() -> void: relic_refresh_pressed.emit())
	shop_v.add_child(_relic_refresh_btn)
	_owned_relic_list = VBoxContainer.new()
	_owned_relic_list.add_theme_constant_override("separation", 2)
	shop_v.add_child(_owned_relic_list)
	_shop_next_btn = Button.new()
	_shop_next_btn.text = "下一层"
	_shop_next_btn.custom_minimum_size = Vector2(0, 48)
	_shop_next_btn.pressed.connect(func() -> void: next_floor_pressed.emit())
	shop_v.add_child(_shop_next_btn)

	_shrine_panel = _make_centered_panel(Vector2(360, 220))
	_shrine_panel.visible = false
	_root.add_child(_shrine_panel)
	var shrine_v := VBoxContainer.new()
	shrine_v.add_theme_constant_override("separation", 10)
	_shrine_panel.add_child(shrine_v)
	_shrine_title = Label.new()
	_shrine_title.text = "神龛"
	_shrine_title.add_theme_font_size_override("font_size", 18)
	_shrine_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shrine_v.add_child(_shrine_title)
	var shrine_hint := Label.new()
	shrine_hint.text = "选择一项恩惠"
	shrine_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shrine_v.add_child(shrine_hint)
	var buff_btn := Button.new()
	buff_btn.text = "短时攻击强化"
	buff_btn.custom_minimum_size = Vector2(0, 44)
	buff_btn.pressed.connect(func() -> void: shrine_choice_pressed.emit(0))
	shrine_v.add_child(buff_btn)
	var corpus_btn := Button.new()
	corpus_btn.text = "获得尸骸"
	corpus_btn.custom_minimum_size = Vector2(0, 44)
	corpus_btn.pressed.connect(func() -> void: shrine_choice_pressed.emit(1))
	shrine_v.add_child(corpus_btn)

	_chest_panel = _make_centered_panel(Vector2(360, 220))
	_chest_panel.visible = false
	_root.add_child(_chest_panel)
	var chest_v := VBoxContainer.new()
	_chest_panel.add_child(chest_v)
	var chest_title := Label.new()
	chest_title.text = "宝箱招募（已停用）"
	chest_v.add_child(chest_title)
	_chest_list = HBoxContainer.new()
	chest_v.add_child(_chest_list)

	# Legacy interstitial kept as fallback (hidden when shop opens).
	_interstitial_panel = _make_centered_panel(Vector2(320, 220))
	_interstitial_panel.visible = false
	_root.add_child(_interstitial_panel)
	var inter_v := VBoxContainer.new()
	inter_v.add_theme_constant_override("separation", 12)
	_interstitial_panel.add_child(inter_v)
	_interstitial_label = Label.new()
	_interstitial_label.add_theme_font_size_override("font_size", 20)
	_interstitial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interstitial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_interstitial_label.text = "层间营地"
	inter_v.add_child(_interstitial_label)
	var next_btn := Button.new()
	next_btn.text = "下一层"
	next_btn.custom_minimum_size = Vector2(0, 52)
	next_btn.pressed.connect(func() -> void: next_floor_pressed.emit())
	inter_v.add_child(next_btn)

	_end_panel = _make_centered_panel(Vector2(340, 280))
	_end_panel.visible = false
	_root.add_child(_end_panel)
	var end_v := VBoxContainer.new()
	end_v.add_theme_constant_override("separation", 10)
	_end_panel.add_child(end_v)
	_end_label = Label.new()
	_end_label.add_theme_font_size_override("font_size", 24)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_v.add_child(_end_label)
	_end_stats_label = Label.new()
	_end_stats_label.add_theme_font_size_override("font_size", 15)
	_end_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_stats_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 1.0))
	end_v.add_child(_end_stats_label)
	var restart := Button.new()
	restart.text = "再开一局"
	restart.custom_minimum_size = Vector2(0, 48)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	end_v.add_child(restart)
	var menu_btn := Button.new()
	menu_btn.text = "回主菜单"
	menu_btn.custom_minimum_size = Vector2(0, 44)
	menu_btn.pressed.connect(func() -> void: main_menu_pressed.emit())
	end_v.add_child(menu_btn)


func _make_centered_panel(min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -min_size.x * 0.5
	panel.offset_right = min_size.x * 0.5
	panel.offset_top = -min_size.y * 0.5 - 20.0
	panel.offset_bottom = min_size.y * 0.5 - 20.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.94)
	style.border_color = Color(0.7, 0.75, 0.85, 1.0)
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	return panel
