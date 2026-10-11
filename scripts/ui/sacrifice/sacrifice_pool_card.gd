class_name SacrificePoolCard
extends Control

const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")
const DRAG_THRESHOLD := 8.0

signal drag_started(entry_id: int, viewport_pos: Vector2)

@onready var _card_host: Control = %CardHost

var _entry_id: int = -1
var _entry: DeckEntry
var _card: UnitCardDisplay
var _level_config: LevelConfig
var _press_viewport_pos: Vector2 = Vector2.ZERO
var _drag_started: bool = false


func _ready() -> void:
	_ensure_card()
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_level_config(config: LevelConfig) -> void:
	_level_config = config


func set_entry(entry: DeckEntry) -> void:
	_entry = entry
	_entry_id = entry.entry_id if entry != null else -1
	if is_node_ready():
		_refresh_display()
	else:
		call_deferred("_refresh_display")


func get_entry_id() -> int:
	return _entry_id


func _refresh_display() -> void:
	_ensure_card()
	if _entry == null or _entry.unit == null:
		visible = false
		return
	if _card == null:
		return
	visible = true
	_card.bind_deck_entry(_entry, _level_config)


func _get_card_host() -> Control:
	if _card_host != null:
		return _card_host
	return get_node_or_null("%CardHost") as Control


func _ensure_card() -> void:
	var host := _get_card_host()
	if _card != null or host == null:
		return
	_card = CARD_SCENE.instantiate() as UnitCardDisplay
	if _card == null:
		return
	host.add_child(_card)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.configure(UnitCardDisplay.SIZE_DEFAULT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if _entry == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_viewport_pos = mb.position
			_drag_started = false
		elif _drag_started:
			accept_event()
			_drag_started = false
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		if _drag_started:
			accept_event()
			return
		if motion.position.distance_to(_press_viewport_pos) >= DRAG_THRESHOLD:
			_drag_started = true
			drag_started.emit(_entry_id, get_viewport().get_mouse_position())
			accept_event()
