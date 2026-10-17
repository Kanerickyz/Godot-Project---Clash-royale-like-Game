class_name GameHud
extends CanvasLayer
## Gold, shop shelf, chest three-pick, win/lose panels.


signal shop_buy_pressed(slot_index: int)
signal shop_refresh_pressed
signal shop_closed
signal chest_pick_pressed(choice_index: int)
signal restart_pressed

var gold: int = 0

var _root: Control
var _gold_label: Label
var _hint_label: Label
var _shop_panel: PanelContainer
var _shop_list: VBoxContainer
var _chest_panel: PanelContainer
var _chest_list: HBoxContainer
var _end_panel: PanelContainer
var _end_label: Label
var _joystick: VirtualJoystick


func _ready() -> void:
	layer = 20
	_build_ui()
	refresh_gold(gold)


func get_joystick_vector() -> Vector2:
	if _joystick == null:
		return Vector2.ZERO
	return _joystick.get_vector()


func refresh_gold(amount: int) -> void:
	gold = amount
	if _gold_label != null:
		_gold_label.text = "金币: %d" % gold


func show_shop(shelf: Array[Dictionary], current_gold: int, refresh_cost: int = 10) -> void:
	refresh_gold(current_gold)
	_clear_children(_shop_list)
	for i in shelf.size():
		var slot: Dictionary = shelf[i]
		var unit: UnitDefinition = slot.get("unit") as UnitDefinition
		var price: int = int(slot.get("price", 0))
		var sold: bool = bool(slot.get("sold_out", false))
		var row := HBoxContainer.new()
		var name_l := Label.new()
		var unit_name := "?" if unit == null else unit.display_name
		if sold:
			name_l.text = "%s — 售罄" % unit_name
		else:
			name_l.text = "%s — %d 金" % [unit_name, price]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var btn := Button.new()
		btn.text = "购买"
		btn.custom_minimum_size = Vector2(0, 44)
		btn.disabled = sold or current_gold < price or unit == null
		var idx := i
		btn.pressed.connect(func() -> void: shop_buy_pressed.emit(idx))
		row.add_child(btn)
		_shop_list.add_child(row)
	var refresh_btn := Button.new()
	refresh_btn.text = "刷新（%d金）" % refresh_cost
	refresh_btn.custom_minimum_size = Vector2(0, 44)
	refresh_btn.disabled = current_gold < refresh_cost
	refresh_btn.pressed.connect(func() -> void: shop_refresh_pressed.emit())
	_shop_list.add_child(refresh_btn)
	_shop_panel.visible = true
	_chest_panel.visible = false


func hide_shop() -> void:
	_shop_panel.visible = false


func show_chest_pick(choices: Array) -> void:
	_clear_children(_chest_list)
	for i in choices.size():
		var unit: UnitDefinition = choices[i] as UnitDefinition
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 88)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if unit == null:
			btn.text = "空"
			btn.disabled = true
		else:
			btn.text = "招募\n%s\nHP%d 攻%d" % [unit.display_name, unit.max_hp, unit.attack_damage]
		var idx := i
		btn.pressed.connect(func() -> void: chest_pick_pressed.emit(idx))
		_chest_list.add_child(btn)
	_chest_panel.visible = true
	_shop_panel.visible = false


func hide_chest_pick() -> void:
	_chest_panel.visible = false


func show_end(won: bool) -> void:
	_end_label.text = "胜利！击败 Boss" if won else "失败…队长阵亡"
	_end_panel.visible = true
	_shop_panel.visible = false
	_chest_panel.visible = false


func set_world_hint(text: String) -> void:
	if _hint_label != null:
		_hint_label.text = text


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFonts.apply_to_control(_root)
	add_child(_root)

	_gold_label = Label.new()
	_gold_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_gold_label.offset_left = 16
	_gold_label.offset_top = 16
	_gold_label.offset_right = -16
	_gold_label.offset_bottom = 48
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.text = "金币: 0"
	_root.add_child(_gold_label)

	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_left = 16
	_hint_label.offset_top = 48
	_hint_label.offset_right = -16
	_hint_label.offset_bottom = 100
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.text = "底部摇杆移动 · 商店旁站住3秒 · 捡金币 · 靠近宝箱自动砸"
	_root.add_child(_hint_label)

	_joystick = VirtualJoystick.new()
	_joystick.name = "VirtualJoystick"
	_root.add_child(_joystick)

	_shop_panel = _make_centered_panel(Vector2(340, 330))
	_shop_panel.visible = false
	_root.add_child(_shop_panel)
	var shop_v := VBoxContainer.new()
	_shop_panel.add_child(shop_v)
	var shop_title := Label.new()
	shop_title.text = "商店货架"
	shop_title.add_theme_font_size_override("font_size", 20)
	shop_v.add_child(shop_title)
	_shop_list = VBoxContainer.new()
	shop_v.add_child(_shop_list)
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.pressed.connect(func() -> void:
		hide_shop()
		shop_closed.emit()
	)
	shop_v.add_child(close_btn)

	_chest_panel = _make_centered_panel(Vector2(360, 220))
	_chest_panel.visible = false
	_root.add_child(_chest_panel)
	var chest_v := VBoxContainer.new()
	_chest_panel.add_child(chest_v)
	var chest_title := Label.new()
	chest_title.text = "宝箱三选一（免费入队）"
	chest_title.add_theme_font_size_override("font_size", 18)
	chest_v.add_child(chest_title)
	_chest_list = HBoxContainer.new()
	_chest_list.alignment = BoxContainer.ALIGNMENT_CENTER
	chest_v.add_child(_chest_list)

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


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
