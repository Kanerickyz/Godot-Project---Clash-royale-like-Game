class_name VirtualJoystick
extends Control
## Bottom-center transparent virtual stick for mobile / touch.


signal vector_changed(vector: Vector2)

const BASE_RADIUS := 96.0
const KNOB_RADIUS := 38.0
const DEADZONE := 0.12
const BOTTOM_MARGIN := 36.0

var output: Vector2 = Vector2.ZERO

var _base: Panel
var _knob: Panel
var _active: bool = false
var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_visuals()
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	var box := BASE_RADIUS * 2.0 + 24.0
	custom_minimum_size = Vector2(box, box)
	offset_left = -box * 0.5
	offset_right = box * 0.5
	offset_top = -BOTTOM_MARGIN - box
	offset_bottom = -BOTTOM_MARGIN
	resized.connect(_on_resized)
	call_deferred("_on_resized")


func get_vector() -> Vector2:
	return output


func _build_visuals() -> void:
	_base = Panel.new()
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(1, 1, 1, 0.16)
	base_style.border_color = Color(1, 1, 1, 0.32)
	base_style.set_border_width_all(2)
	base_style.corner_radius_top_left = int(BASE_RADIUS)
	base_style.corner_radius_top_right = int(BASE_RADIUS)
	base_style.corner_radius_bottom_left = int(BASE_RADIUS)
	base_style.corner_radius_bottom_right = int(BASE_RADIUS)
	_base.add_theme_stylebox_override("panel", base_style)
	add_child(_base)

	_knob = Panel.new()
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(1, 1, 1, 0.36)
	knob_style.border_color = Color(1, 1, 1, 0.5)
	knob_style.set_border_width_all(2)
	knob_style.corner_radius_top_left = int(KNOB_RADIUS)
	knob_style.corner_radius_top_right = int(KNOB_RADIUS)
	knob_style.corner_radius_bottom_left = int(KNOB_RADIUS)
	knob_style.corner_radius_bottom_right = int(KNOB_RADIUS)
	_knob.add_theme_stylebox_override("panel", knob_style)
	add_child(_knob)


func _on_resized() -> void:
	_center = size * 0.5
	_base.size = Vector2(BASE_RADIUS * 2.0, BASE_RADIUS * 2.0)
	_base.position = _center - _base.size * 0.5
	_reset_knob()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if not _active:
				_active = true
				_touch_index = touch.index
				_update_from_local(touch.position)
				accept_event()
		elif touch.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _active and drag.index == _touch_index:
			_update_from_local(drag.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_active = true
			_touch_index = -1
			_update_from_local(mb.position)
			accept_event()
		elif _active:
			_release()
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _active and _touch_index < 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_update_from_local(mm.position)
			accept_event()


func _update_from_local(local_pos: Vector2) -> void:
	var delta := local_pos - _center
	var max_len := BASE_RADIUS
	if delta.length() > max_len:
		delta = delta.normalized() * max_len
	_knob.size = Vector2(KNOB_RADIUS * 2.0, KNOB_RADIUS * 2.0)
	_knob.position = _center + delta - _knob.size * 0.5
	var strength := delta.length() / max_len
	if strength < DEADZONE:
		_set_output(Vector2.ZERO)
	else:
		_set_output(delta.normalized() * ((strength - DEADZONE) / (1.0 - DEADZONE)))


func _release() -> void:
	_active = false
	_touch_index = -1
	_reset_knob()
	_set_output(Vector2.ZERO)


func _reset_knob() -> void:
	if _knob == null:
		return
	_knob.size = Vector2(KNOB_RADIUS * 2.0, KNOB_RADIUS * 2.0)
	_knob.position = _center - _knob.size * 0.5


func _set_output(v: Vector2) -> void:
	if output.is_equal_approx(v):
		return
	output = v
	vector_changed.emit(output)
