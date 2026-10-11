class_name CombatTurnOrderBar
extends Control

const ITEM_SCENE := preload("res://scenes/ui/combat/combat_turn_order_item.tscn")
const BAR_HEIGHT := 192.0
const BAR_BOTTOM_MARGIN := 12.0

@onready var _round_label: Label = %RoundLabel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _row_host: HBoxContainer = %RowHost
@onready var _items_row: HBoxContainer = %ItemsRow

var _items_by_id: Dictionary = {}
var _active: bool = false
var _scroll_tween: Tween


func layout_under_board(board_rect: Rect2) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or board_rect.size.x <= 0.0:
		return
	anchor_left = board_rect.position.x / vp.x
	anchor_right = (board_rect.position.x + board_rect.size.x) / vp.x
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = -(BAR_HEIGHT + BAR_BOTTOM_MARGIN)
	offset_bottom = -BAR_BOTTOM_MARGIN
	_apply_row_layout()


func begin_combat() -> void:
	_active = true
	_clear_items()
	if _round_label != null:
		_round_label.text = ""


func end_combat() -> void:
	_active = false
	_kill_scroll_tween()
	_clear_items()
	if _round_label != null:
		_round_label.text = ""


func apply_snapshot(snapshot: Dictionary) -> void:
	if not _active or snapshot.is_empty():
		return
	var queue: Array = snapshot.get("queue", [])
	var act_index: int = int(snapshot.get("act_index", 0))
	var combat_tick: int = int(snapshot.get("combat_tick", -1))
	if _round_label != null and combat_tick >= 0:
		_round_label.text = "第 %d 回合" % combat_tick
	var remaining := _build_remaining_units(queue, act_index)
	var removed_width := _measure_removed_left_width(remaining)
	_sync_queue_items(remaining)
	var current_row_index := _resolve_current_row_index(remaining)
	for i in remaining.size():
		var unit: UnitInstance = remaining[i]
		if unit == null:
			continue
		var item: CombatTurnOrderItem = _items_by_id.get(unit.instance_id)
		if item == null:
			continue
		var state := CombatTurnOrderItem.State.PENDING
		if current_row_index >= 0 and i == current_row_index:
			state = CombatTurnOrderItem.State.CURRENT
		item.set_state(state, unit.is_alive())
	_apply_row_layout()
	_animate_scroll_left(removed_width)


func _build_remaining_units(queue: Array, act_index: int) -> Array:
	var remaining: Array = []
	for i in range(act_index, queue.size()):
		var unit: UnitInstance = queue[i]
		if unit != null:
			remaining.append(unit)
	return remaining


func _resolve_current_row_index(remaining: Array) -> int:
	for i in remaining.size():
		var unit: UnitInstance = remaining[i]
		if unit != null and unit.is_alive():
			return i
	return -1


func _measure_removed_left_width(remaining: Array) -> float:
	if _items_row == null:
		return 0.0
	var remaining_ids: Dictionary = {}
	for unit in remaining:
		if unit != null:
			remaining_ids[unit.instance_id] = true
	var width := 0.0
	var sep := 8.0
	if _items_row.has_theme_constant("separation"):
		sep = float(_items_row.get_theme_constant("separation"))
	for child in _items_row.get_children():
		var item := child as CombatTurnOrderItem
		if item == null:
			continue
		if remaining_ids.has(item.get_unit_instance_id()):
			break
		var item_w: float = item.size.x
		if item_w <= 0.0:
			item_w = CombatTurnOrderItem.ITEM_SIZE.x
		width += item_w + sep
	return width


func _sync_queue_items(remaining: Array) -> void:
	if _items_row == null:
		return
	var seen: Dictionary = {}
	for unit in remaining:
		if unit == null:
			continue
		seen[unit.instance_id] = true
		if not _items_by_id.has(unit.instance_id):
			var item := ITEM_SCENE.instantiate() as CombatTurnOrderItem
			_items_row.add_child(item)
			_items_by_id[unit.instance_id] = item
		var existing: CombatTurnOrderItem = _items_by_id[unit.instance_id]
		existing.bind_unit(unit)
	var stale_ids: Array = []
	for instance_id in _items_by_id:
		if not seen.has(instance_id):
			stale_ids.append(instance_id)
	for instance_id in stale_ids:
		var stale: CombatTurnOrderItem = _items_by_id[instance_id]
		_items_by_id.erase(instance_id)
		if is_instance_valid(stale):
			stale.queue_free()
	for i in remaining.size():
		var unit: UnitInstance = remaining[i]
		if unit == null:
			continue
		var item: CombatTurnOrderItem = _items_by_id.get(unit.instance_id)
		if item != null:
			_items_row.move_child(item, i)


func _apply_row_layout() -> void:
	if _scroll == null or _row_host == null or _items_row == null:
		return
	var scroll_w := _scroll.size.x
	if scroll_w <= 0.0:
		return
	var content_w := _items_row.get_combined_minimum_size().x
	_row_host.custom_minimum_size.x = maxf(scroll_w, content_w)


func _animate_scroll_left(removed_width: float) -> void:
	if _scroll == null:
		return
	if removed_width <= 0.0:
		_scroll.scroll_horizontal = 0
		return
	call_deferred("_play_scroll_left", removed_width)


func _play_scroll_left(removed_width: float) -> void:
	if _scroll == null:
		return
	_scroll.scroll_horizontal = int(removed_width)
	_tween_scroll_to_x(0.0)


func _tween_scroll_to_x(target_x: float) -> void:
	if _scroll == null:
		return
	_kill_scroll_tween()
	if absf(float(_scroll.scroll_horizontal) - target_x) < 1.0:
		_scroll.scroll_horizontal = int(target_x)
		return
	_scroll_tween = create_tween()
	_scroll_tween.set_ease(Tween.EASE_OUT)
	_scroll_tween.set_trans(Tween.TRANS_CUBIC)
	_scroll_tween.tween_property(
		_scroll,
		"scroll_horizontal",
		int(target_x),
		CombatAnimationConfig.DUR_TURN_ORDER_SCROLL,
	)


func _clear_items() -> void:
	_kill_scroll_tween()
	for instance_id in _items_by_id:
		var item: CombatTurnOrderItem = _items_by_id[instance_id]
		if is_instance_valid(item):
			item.queue_free()
	_items_by_id.clear()
	if _scroll != null:
		_scroll.scroll_horizontal = 0


func _kill_scroll_tween() -> void:
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = null
