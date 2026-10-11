class_name BoardCell
extends Area2D

signal clicked(cell: Vector2i)
signal right_clicked(cell: Vector2i)

var cell: Vector2i = Vector2i.ZERO

var _blocked: bool = false
var _pixel_size: int = 64
var _base_color: Color = Color.WHITE
var _highlight: BoardTheme.CellHighlight = BoardTheme.CellHighlight.NONE
var _burning: bool = false
var _pulse_tween: Tween


func setup(p_cell: Vector2i, blocked: bool, pixel_size: int = 64) -> void:
	cell = p_cell
	_blocked = blocked
	_pixel_size = pixel_size
	_base_color = BoardTheme.get_base_color(cell, blocked)
	_highlight = BoardTheme.CellHighlight.NONE
	_apply_geometry()
	_apply_visual()


func set_highlight(highlight: BoardTheme.CellHighlight) -> void:
	if _highlight == highlight:
		return
	_highlight = highlight
	_apply_visual()


func get_highlight() -> BoardTheme.CellHighlight:
	return _highlight


func _apply_geometry() -> void:
	var s := float(_pixel_size)
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual:
		visual.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(s, 0),
			Vector2(s, s),
			Vector2(0, s),
		])

	var border := get_node_or_null("Border") as Line2D
	if border:
		border.points = PackedVector2Array([
			Vector2(0, 0),
			Vector2(s, 0),
			Vector2(s, s),
			Vector2(0, s),
			Vector2(0, 0),
		])
		border.width = 1.0
		border.default_color = BoardTheme.get_border_color(cell, _blocked)
		border.antialiased = true

	var blocked_a := get_node_or_null("BlockedMarkA") as Line2D
	var blocked_b := get_node_or_null("BlockedMarkB") as Line2D
	if blocked_a and blocked_b:
		var inset := s * 0.2
		blocked_a.points = PackedVector2Array([
			Vector2(inset, inset),
			Vector2(s - inset, s - inset),
		])
		blocked_b.points = PackedVector2Array([
			Vector2(s - inset, inset),
			Vector2(inset, s - inset),
		])
		blocked_a.width = 1.5
		blocked_b.width = 1.5
		blocked_a.default_color = Color(1, 1, 1, 0.25)
		blocked_b.default_color = Color(1, 1, 1, 0.25)
		blocked_a.visible = _blocked
		blocked_b.visible = _blocked
		blocked_a.antialiased = true
		blocked_b.antialiased = true


func set_burning(active: bool) -> void:
	if _burning == active:
		return
	_burning = active
	_apply_visual()


func play_teleport_pulse(tint: Color, duration: float) -> void:
	play_impact_pulse(tint, duration)


func play_impact_pulse(tint: Color, duration: float) -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual == null or duration <= 0.0:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(visual, "modulate", tint, duration * 0.35)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(visual, "modulate", Color.WHITE, duration * 0.65)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pulse_tween.tween_callback(func() -> void:
		_apply_visual()
	)


func _apply_visual() -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual == null:
		return
	var color := BoardTheme.apply_highlight(_base_color, _highlight)
	if _burning:
		color = BoardTheme.apply_burn_overlay(color)
	visual.color = color
	visual.modulate = BoardTheme.get_blocked_modulate() if _blocked else Color.WHITE


func _input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int,
) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(cell)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			right_clicked.emit(cell)
