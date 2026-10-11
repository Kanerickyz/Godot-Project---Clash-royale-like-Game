class_name SacrificeDropSlot
extends PanelContainer

signal cleared
signal drag_started(entry_id: int, viewport_pos: Vector2)

const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")
const DRAG_THRESHOLD := 8.0

@onready var _label: Label = %SlotLabel
@onready var _card_host: Control = %CardHost
@onready var _placeholder: Label = %Placeholder

var entry_id: int = -1
var _entry: DeckEntry
var _card: UnitCardDisplay
var _level_config: LevelConfig
var _press_viewport_pos: Vector2 = Vector2.ZERO
var _drag_started: bool = false


func _ready() -> void:
	gui_input.connect(_on_gui_input)


func setup(label_text: String) -> void:
	if _label != null:
		_label.text = label_text


func set_level_config(config: LevelConfig) -> void:
	_level_config = config


func set_entry(entry: DeckEntry) -> void:
	_entry = entry
	entry_id = entry.entry_id if entry != null else -1
	if is_node_ready():
		_refresh_display()
	else:
		call_deferred("_refresh_display")


func clear_entry() -> void:
	if entry_id < 0:
		return
	entry_id = -1
	_entry = null
	_refresh_display()
	cleared.emit()


func clear_entry_silent() -> void:
	entry_id = -1
	_entry = null
	_refresh_display()


func get_entry() -> DeckEntry:
	return _entry


func get_drop_rect() -> Rect2:
	return get_global_rect().grow(12.0)


func contains_global_point(global_pos: Vector2) -> bool:
	return get_drop_rect().has_point(global_pos)


func _refresh_display() -> void:
	var placeholder := _get_placeholder()
	if _entry == null or _entry.unit == null:
		if placeholder != null:
			placeholder.visible = true
		if _card != null:
			_card.visible = false
		return
	_ensure_card()
	if _card == null:
		return
	if placeholder != null:
		placeholder.visible = false
	_card.visible = true
	_card.bind_deck_entry(_entry, _level_config)


func _get_card_host() -> Control:
	if _card_host != null:
		return _card_host
	return get_node_or_null("%CardHost") as Control


func _get_placeholder() -> Label:
	if _placeholder != null:
		return _placeholder
	return get_node_or_null("%Placeholder") as Label


func _ensure_card() -> void:
	var host := _get_card_host()
	if _card != null or host == null:
		return
	_card = CARD_SCENE.instantiate() as UnitCardDisplay
	if _card == null:
		return
	host.add_child(_card)
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.configure(UnitCardDisplay.SIZE_DEFAULT)


func _on_gui_input(event: InputEvent) -> void:
	if entry_id < 0:
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
			drag_started.emit(entry_id, get_viewport().get_mouse_position())
			accept_event()
