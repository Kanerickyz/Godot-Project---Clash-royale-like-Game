class_name UnitTooltip
extends PanelContainer

const TOOLTIP_MARGIN := Vector2(18, 18)
const VIEWPORT_PADDING := 12.0
const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")

@onready var _content: HBoxContainer = %Content
@onready var _card_host: Control = %CardHost
@onready var _text_box: VBoxContainer = %TextBox
@onready var _name_label: Label = %NameLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _skills_label: Label = %SkillsLabel

var _unit: UnitInstance
var _card: UnitCardDisplay
var _follow_mouse: bool = false
var _avoid_rects: Array[Rect2] = []
var _anchor_left_rect: Rect2 = Rect2()
var _last_screen_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_card()


func set_avoid_rects(rects: Array[Rect2]) -> void:
	_avoid_rects = rects


func set_anchor_left_rect(rect: Rect2) -> void:
	_anchor_left_rect = rect


func clear_placement_hints() -> void:
	_avoid_rects.clear()
	_anchor_left_rect = Rect2()


func show_unit(unit: UnitInstance, screen_pos: Vector2) -> void:
	_unit = unit
	_follow_mouse = true
	_last_screen_pos = screen_pos
	_apply_unit_text()
	visible = true
	_reposition(screen_pos)
	call_deferred("_reposition_after_layout")


func show_deck_entry(entry: DeckEntry, screen_pos: Vector2, level_config: LevelConfig = null) -> void:
	_unit = null
	_follow_mouse = true
	_last_screen_pos = screen_pos
	_apply_deck_entry_text(entry, level_config)
	visible = true
	_reposition(screen_pos)
	call_deferred("_reposition_after_layout")


func show_shop_offer(offer: ShopOffer, screen_pos: Vector2) -> void:
	_unit = null
	_follow_mouse = true
	_last_screen_pos = screen_pos
	_apply_shop_offer_text(offer)
	visible = true
	_reposition(screen_pos)
	call_deferred("_reposition_after_layout")


func refresh_if_showing(unit: UnitInstance) -> void:
	if not visible or _unit == null or unit == null:
		return
	if unit.instance_id != _unit.instance_id:
		return
	_unit = unit
	_apply_unit_text()


func hide_tooltip() -> void:
	visible = false
	_unit = null
	_follow_mouse = false
	clear_placement_hints()
	if _card_host != null:
		_card_host.visible = true


func follow_mouse(screen_pos: Vector2) -> void:
	if not visible or not _follow_mouse:
		return
	_last_screen_pos = screen_pos
	_reposition(screen_pos)


func _reposition_after_layout() -> void:
	if visible:
		_reposition(_last_screen_pos)


func _apply_unit_text() -> void:
	if _unit == null:
		return
	_ensure_card()
	if _card_host != null:
		_card_host.visible = true
	_name_label.text = "%s · T%d" % [
		UnitInfoText.get_display_name(_unit),
		_unit.unit_data.tier if _unit.unit_data != null else 1,
	]
	if _stats_label != null:
		_stats_label.text = UnitInfoText.get_stats_line(_unit)
		_stats_label.visible = true
	_skills_label.text = UnitInfoText.get_skills_block(_unit)
	_card.bind_unit_instance(_unit)
	_card.set_state(false, false)


func _apply_deck_entry_text(entry: DeckEntry, level_config: LevelConfig = null) -> void:
	if entry == null or entry.unit == null:
		return
	_ensure_card()
	if _card_host != null:
		_card_host.visible = true
	_name_label.text = "%s · Lv.%d · T%d" % [
		entry.get_display_name(),
		entry.level,
		entry.unit.tier,
	]
	if _stats_label != null:
		_stats_label.text = UnitInfoText.get_stats_line_from_entry(entry)
		_stats_label.visible = true
	_skills_label.text = UnitInfoText.get_skills_block_from_entry(entry)
	_card.bind_deck_entry(entry, level_config)
	_card.set_state(false, false)


func _apply_shop_offer_text(offer: ShopOffer) -> void:
	if offer == null:
		return
	_ensure_card()
	_name_label.text = offer.get_display_name()
	if offer.type == ShopOffer.OfferType.CHARACTER and offer.unit != null:
		if _card_host != null:
			_card_host.visible = true
		_name_label.text = "%s · T%d" % [offer.get_display_name(), offer.unit.tier]
		if _stats_label != null:
			_stats_label.text = UnitInfoText.get_stats_line_from_unit_data(offer.unit)
			_stats_label.visible = true
		_skills_label.text = UnitInfoText.get_skills_block_from_unit_data(offer.unit)
		var stats := offer.unit.stats
		var atk := stats.attack if stats != null else 0
		var max_hp := stats.max_hp if stats != null else 0
		_card.bind_unit_data(offer.unit, atk, max_hp, max_hp)
		_card.set_level(1)
		_card.set_state(false, false)
	elif offer.type == ShopOffer.OfferType.BUFF:
		if _card_host != null:
			_card_host.visible = false
		if _stats_label != null:
			_stats_label.visible = false
		if offer.buff != null:
			_skills_label.text = UnitInfoText.format_buff(offer.buff)
		else:
			_skills_label.text = "无效果描述"


func _ensure_card() -> void:
	if _card != null or _card_host == null:
		return
	_card = CARD_SCENE.instantiate() as UnitCardDisplay
	_card_host.add_child(_card)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.configure(Vector2(120.0, 140.0))


func _reposition(screen_pos: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var tooltip_size := _get_tooltip_size()
	var pos: Vector2

	if _anchor_left_rect.size != Vector2.ZERO:
		pos.x = _anchor_left_rect.position.x - tooltip_size.x - VIEWPORT_PADDING
		pos.y = screen_pos.y - tooltip_size.y * 0.5
	else:
		pos = screen_pos + TOOLTIP_MARGIN

	pos = _clamp_to_viewport(pos, tooltip_size, viewport_size)
	pos = _resolve_avoid_rects(pos, tooltip_size, screen_pos, viewport_size)
	global_position = pos


func _get_tooltip_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	return custom_minimum_size


func _clamp_to_viewport(pos: Vector2, tooltip_size: Vector2, viewport_size: Vector2) -> Vector2:
	pos.x = clampf(pos.x, VIEWPORT_PADDING, viewport_size.x - tooltip_size.x - VIEWPORT_PADDING)
	pos.y = clampf(pos.y, VIEWPORT_PADDING, viewport_size.y - tooltip_size.y - VIEWPORT_PADDING)
	return pos


func _resolve_avoid_rects(
	pos: Vector2,
	tooltip_size: Vector2,
	screen_pos: Vector2,
	viewport_size: Vector2,
) -> Vector2:
	var tooltip_rect := Rect2(pos, tooltip_size)
	for avoid in _avoid_rects:
		if not tooltip_rect.intersects(avoid):
			continue

		var left_pos := Vector2(
			avoid.position.x - tooltip_size.x - VIEWPORT_PADDING,
			screen_pos.y - tooltip_size.y * 0.5,
		)
		left_pos = _clamp_to_viewport(left_pos, tooltip_size, viewport_size)
		if not Rect2(left_pos, tooltip_size).intersects(avoid):
			return left_pos

		var above_pos := Vector2(
			screen_pos.x - tooltip_size.x * 0.5,
			screen_pos.y - tooltip_size.y - VIEWPORT_PADDING,
		)
		above_pos = _clamp_to_viewport(above_pos, tooltip_size, viewport_size)
		if not Rect2(above_pos, tooltip_size).intersects(avoid):
			return above_pos

		tooltip_rect = Rect2(pos, tooltip_size)

	return pos
