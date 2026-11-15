class_name GameHud
extends CanvasLayer
## Phase A HUD: threat, floor, commands, interstitial stub, end screen.
## Legacy shop/chest-pick panels remain hidden (Phase B+).


signal shop_buy_pressed(slot_index: int)
signal shop_refresh_pressed
signal shop_closed
signal chest_pick_pressed(choice_index: int)
signal restart_pressed
signal assemble_pressed
signal rage_pressed
signal portal_confirm_pressed
signal next_floor_pressed

## Presentation range for threat bar fill (matches ThreatConfig defaults; not a formula change).
const THREAT_BAR_MIN := 1.0
const THREAT_BAR_MAX := 2.5

var gold: int = 0

var _root: Control
var _gold_label: Label
var _threat_label: Label
var _threat_bar: ProgressBar
var _threat_bar_fill: StyleBoxFlat
var _floor_label: Label
var _hint_label: Label
var _shop_panel: PanelContainer
var _shop_list: VBoxContainer
var _chest_panel: PanelContainer
var _chest_list: HBoxContainer
var _end_panel: PanelContainer
var _end_label: Label
var _interstitial_panel: PanelContainer
var _interstitial_label: Label
var _cmd_row: HBoxContainer
var _assemble_btn: Button
var _rage_btn: Button
var _portal_btn: Button
var _joystick: VirtualJoystick


func _ready() -> void:
	layer = 20
	_build_ui()
	refresh_gold(gold)
	refresh_threat(1.0, "平静", 0)
	refresh_floor(1)
	set_command_cooldowns(0.0, 0.0, 0.0, 0.0)
	set_portal_prompt_visible(false)


func get_joystick_vector() -> Vector2:
	if _joystick == null:
		return Vector2.ZERO
	return _joystick.get_vector()


func refresh_gold(amount: int) -> void:
	gold = amount
	if _gold_label != null:
		# Phase A: pickup placeholder only; not a shop-driving wallet.
		_gold_label.text = "达克特(占位): %d" % gold


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


func refresh_floor(floor_index: int) -> void:
	if _floor_label != null:
		_floor_label.text = "第 %d 层" % maxi(1, floor_index)


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


func show_interstitial(floor_cleared: int) -> void:
	if _interstitial_label != null:
		_interstitial_label.text = "离开第 %d 层\n层间营地（占位，无商店）" % floor_cleared
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


func hide_interstitial() -> void:
	if _interstitial_panel != null:
		_interstitial_panel.visible = false
	if _cmd_row != null:
		_cmd_row.visible = true


func show_shop(shelf: Array[Dictionary], current_gold: int, refresh_cost: int = 10) -> void:
	# Phase A: shop UI disabled; keep API so old signals do not crash callers.
	refresh_gold(current_gold)
	hide_shop()
	if shelf.is_empty() and refresh_cost < 0:
		pass


func hide_shop() -> void:
	if _shop_panel != null:
		_shop_panel.visible = false


func show_chest_pick(choices: Array) -> void:
	# Phase A: three-pick recruit disabled.
	hide_chest_pick()
	if choices.is_empty():
		pass


func hide_chest_pick() -> void:
	if _chest_panel != null:
		_chest_panel.visible = false


func show_end(won: bool) -> void:
	if _end_label != null:
		_end_label.text = "胜利（占位）" if won else "失败…指挥官阵亡"
	if _end_panel != null:
		_end_panel.visible = true
	hide_shop()
	hide_chest_pick()
	hide_interstitial()
	if _cmd_row != null:
		_cmd_row.visible = false
	set_portal_prompt_visible(false)


func set_world_hint(text: String) -> void:
	if _hint_label != null:
		_hint_label.text = text


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
	_gold_label.offset_right = -16
	_gold_label.offset_bottom = 112
	_gold_label.add_theme_font_size_override("font_size", 15)
	_gold_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.85))
	_gold_label.add_theme_constant_override("outline_size", 2)
	_gold_label.text = "达克特(占位): 0"
	_root.add_child(_gold_label)

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
	_hint_label.text = "WASD/摇杆移动 · Q集合 · R怒意 · 靠近传送门确认进层"
	_root.add_child(_hint_label)

	_joystick = VirtualJoystick.new()
	_joystick.name = "VirtualJoystick"
	_root.add_child(_joystick)

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

	# Legacy panels kept off-screen/hidden for API stability.
	_shop_panel = _make_centered_panel(Vector2(340, 330))
	_shop_panel.visible = false
	_root.add_child(_shop_panel)
	var shop_v := VBoxContainer.new()
	_shop_panel.add_child(shop_v)
	var shop_title := Label.new()
	shop_title.text = "商店（已停用）"
	shop_v.add_child(shop_title)
	_shop_list = VBoxContainer.new()
	shop_v.add_child(_shop_list)

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
	_interstitial_label.text = "层间营地（占位）"
	inter_v.add_child(_interstitial_label)
	var next_btn := Button.new()
	next_btn.text = "下一层"
	next_btn.custom_minimum_size = Vector2(0, 52)
	next_btn.pressed.connect(func() -> void: next_floor_pressed.emit())
	inter_v.add_child(next_btn)

	_end_panel = _make_centered_panel(Vector2(300, 180))
	_end_panel.visible = false
	_root.add_child(_end_panel)
	var end_v := VBoxContainer.new()
	_end_panel.add_child(end_v)
	_end_label = Label.new()
	_end_label.add_theme_font_size_override("font_size", 24)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_v.add_child(_end_label)
	var restart := Button.new()
	restart.text = "重新开始"
	restart.custom_minimum_size = Vector2(0, 48)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	end_v.add_child(restart)


func _make_centered_panel(min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -min_size.x * 0.5
	panel.offset_right = min_size.x * 0.5
	panel.offset_top = -min_size.y * 0.5 - 40.0
	panel.offset_bottom = min_size.y * 0.5 - 40.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.94)
	style.border_color = Color(0.7, 0.75, 0.85, 1.0)
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	return panel
