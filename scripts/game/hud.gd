class_name GameHud
extends CanvasLayer
## Gold, cargo, city menu, and run-end panels for the trade sandbox.


signal city_recruit_pressed(slot_index: int)
signal city_buy_pressed
signal city_sell_pressed
signal city_leave_pressed
signal restart_pressed

var gold: int = 0
var cargo: int = 0
var cargo_name: String = "粮食"

var _root: Control
var _status_label: Label
var _hint_label: Label
var _city_panel: PanelContainer
var _city_title: Label
var _city_body: VBoxContainer
var _end_panel: PanelContainer
var _end_label: Label
var _joystick: VirtualJoystick


func _ready() -> void:
	layer = 20
	_build_ui()
	refresh_status(gold, cargo, cargo_name)


func get_joystick_vector() -> Vector2:
	if _joystick == null:
		return Vector2.ZERO
	return _joystick.get_vector()


func refresh_status(p_gold: int, p_cargo: int, p_cargo_name: String = "") -> void:
	gold = p_gold
	cargo = p_cargo
	if not p_cargo_name.is_empty():
		cargo_name = p_cargo_name
	if _status_label != null:
		_status_label.text = "金币: %d    %s: %d" % [gold, cargo_name, cargo]


func refresh_gold(amount: int) -> void:
	refresh_status(amount, cargo, cargo_name)


func set_world_hint(text: String) -> void:
	if _hint_label != null:
		_hint_label.text = text


func show_city_menu(
	city_name: String,
	buy_price: int,
	sell_price: int,
	offers: Array[Dictionary],
	current_gold: int,
	current_cargo: int,
	p_cargo_name: String
) -> void:
	refresh_status(current_gold, current_cargo, p_cargo_name)
	if _city_title != null:
		_city_title.text = "%s · 城内" % city_name
	_clear_children(_city_body)

	var trade_l := Label.new()
	trade_l.text = "%s  买入 %d金 / 卖出 %d金" % [p_cargo_name, buy_price, sell_price]
	trade_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_body.add_child(trade_l)

	var trade_row := HBoxContainer.new()
	trade_row.add_theme_constant_override("separation", 8)
	var buy_btn := Button.new()
	buy_btn.text = "买货"
	buy_btn.custom_minimum_size = Vector2(0, 44)
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.disabled = current_gold < buy_price or buy_price <= 0
	buy_btn.pressed.connect(func() -> void: city_buy_pressed.emit())
	trade_row.add_child(buy_btn)
	var sell_btn := Button.new()
	sell_btn.text = "卖货"
	sell_btn.custom_minimum_size = Vector2(0, 44)
	sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_btn.disabled = current_cargo <= 0 or sell_price <= 0
	sell_btn.pressed.connect(func() -> void: city_sell_pressed.emit())
	trade_row.add_child(sell_btn)
	_city_body.add_child(trade_row)

	var recruit_title := Label.new()
	recruit_title.text = "招人"
	recruit_title.add_theme_font_size_override("font_size", 16)
	_city_body.add_child(recruit_title)

	for i in offers.size():
		var slot: Dictionary = offers[i]
		var unit: UnitDefinition = slot.get("unit") as UnitDefinition
		var price: int = int(slot.get("price", 0))
		var row := HBoxContainer.new()
		var name_l := Label.new()
		var unit_name := "?" if unit == null else unit.display_name
		name_l.text = "%s — %d 金" % [unit_name, price]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var btn := Button.new()
		btn.text = "招募"
		btn.custom_minimum_size = Vector2(0, 44)
		btn.disabled = unit == null or current_gold < price
		var idx := i
		btn.pressed.connect(func() -> void: city_recruit_pressed.emit(idx))
		row.add_child(btn)
		_city_body.add_child(row)

	var leave_btn := Button.new()
	leave_btn.text = "离开"
	leave_btn.custom_minimum_size = Vector2(0, 48)
	leave_btn.pressed.connect(func() -> void: city_leave_pressed.emit())
	_city_body.add_child(leave_btn)

	_city_panel.visible = true
	_end_panel.visible = false


func hide_city_menu() -> void:
	_city_panel.visible = false


func show_end(score_gold: int) -> void:
	_end_label.text = "失败…队长阵亡\n本局分数（金币）: %d\n持货已作废" % score_gold
	_end_panel.visible = true
	_city_panel.visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFonts.apply_to_control(_root)
	add_child(_root)

	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status_label.offset_left = 16
	_status_label.offset_top = 16
	_status_label.offset_right = -16
	_status_label.offset_bottom = 48
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.text = "金币: 0    粮食: 0"
	_root.add_child(_status_label)

	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_left = 16
	_hint_label.offset_top = 48
	_hint_label.offset_right = -16
	_hint_label.offset_bottom = 110
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.text = "摇杆/WASD 在城际路线上行军 · 抵达城池可进城"
	_root.add_child(_hint_label)

	_joystick = VirtualJoystick.new()
	_joystick.name = "VirtualJoystick"
	_root.add_child(_joystick)

	_city_panel = _make_centered_panel(Vector2(340, 460))
	_city_panel.visible = false
	_root.add_child(_city_panel)
	var city_v := VBoxContainer.new()
	city_v.add_theme_constant_override("separation", 8)
	_city_panel.add_child(city_v)
	_city_title = Label.new()
	_city_title.text = "城内"
	_city_title.add_theme_font_size_override("font_size", 20)
	city_v.add_child(_city_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	city_v.add_child(scroll)
	_city_body = VBoxContainer.new()
	_city_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_city_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_city_body)

	_end_panel = _make_centered_panel(Vector2(300, 220))
	_end_panel.visible = false
	_root.add_child(_end_panel)
	var end_v := VBoxContainer.new()
	end_v.add_theme_constant_override("separation", 12)
	_end_panel.add_child(end_v)
	_end_label = Label.new()
	_end_label.add_theme_font_size_override("font_size", 20)
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
