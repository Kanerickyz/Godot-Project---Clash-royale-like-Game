class_name RecruitCandidateCard
extends Control
## 下区候选人卡片：显示单位与价格，支持拖出招募。

const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")
const DRAG_THRESHOLD := 8.0

signal drag_started(candidate_index: int, viewport_pos: Vector2)
signal pressed(candidate_index: int)

@onready var _card_host: Control = %CardHost
@onready var _cost_label: Label = %CostLabel
@onready var _name_label: Label = %NameLabel

var candidate_index: int = -1
var unit: UnitData
var cost: int = 0
var affordable: bool = true
var _card: UnitCardDisplay
var _press_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_card()
	_refresh()


func setup(index: int, p_unit: UnitData, p_cost: int, p_affordable: bool) -> void:
	candidate_index = index
	unit = p_unit
	cost = p_cost
	affordable = p_affordable
	if is_node_ready():
		_refresh()
	else:
		call_deferred("_refresh")


func _refresh() -> void:
	_ensure_card()
	if unit == null:
		visible = false
		return
	visible = true
	modulate = Color(1, 1, 1, 1) if affordable else Color(0.7, 0.7, 0.7, 0.85)
	if _name_label != null:
		_name_label.text = unit.display_name if not unit.display_name.is_empty() else unit.id
	if _cost_label != null:
		_cost_label.text = "%d 金" % cost
		_cost_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.86, 0.35) if affordable else Color(0.85, 0.4, 0.35),
		)
	if _card != null:
		_card.bind_unit_data(unit)


func _ensure_card() -> void:
	if _card != null or _card_host == null:
		return
	_card = CARD_SCENE.instantiate() as UnitCardDisplay
	if _card == null:
		return
	_card_host.add_child(_card)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.configure(UnitCardDisplay.SIZE_DEFAULT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if unit == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_pos = mb.global_position
			_dragging = false
		else:
			if not _dragging:
				pressed.emit(candidate_index)
			_dragging = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _dragging:
			if _press_pos.distance_to(mm.global_position) >= DRAG_THRESHOLD:
				_dragging = true
				drag_started.emit(candidate_index, mm.global_position)
