class_name PlacementDragController
extends Control

enum Source { NONE, HAND, BOARD }
enum DropType { INVALID, BOARD, HAND }

const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")

var source: Source = Source.NONE
var entry_id: int = -1
var board_unit: UnitInstance
var from_cell: Vector2i = Vector2i(-1, -1)

var _ghost: UnitCardDisplay
var _enabled: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ensure_ghost()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		cancel_drag()


func is_dragging() -> bool:
	return source != Source.NONE


func begin_hand_drag(
	p_entry_id: int,
	entry: DeckEntry,
	level_config: LevelConfig,
	viewport_pos: Vector2,
) -> void:
	if not _enabled or entry == null or entry.unit == null:
		return
	cancel_drag()
	source = Source.HAND
	entry_id = p_entry_id
	board_unit = null
	from_cell = Vector2i(-1, -1)
	_show_ghost(entry, level_config, viewport_pos)


func begin_board_drag(
	unit: UnitInstance,
	entry: DeckEntry,
	level_config: LevelConfig,
	viewport_pos: Vector2,
	p_from_cell: Vector2i,
) -> void:
	if not _enabled or unit == null:
		return
	cancel_drag()
	source = Source.BOARD
	entry_id = unit.deck_entry_id
	board_unit = unit
	from_cell = p_from_cell
	_show_ghost(entry, level_config, viewport_pos)


func update_drag(viewport_pos: Vector2) -> void:
	if not is_dragging() or _ghost == null:
		return
	_position_ghost(viewport_pos)


func end_drag(viewport_pos: Vector2) -> Dictionary:
	if not is_dragging():
		return {"type": DropType.INVALID}

	update_drag(viewport_pos)
	var result := {
		"type": DropType.INVALID,
		"cell": Vector2i(-1, -1),
		"entry_id": entry_id,
		"unit": board_unit,
		"from_cell": from_cell,
		"source": source,
	}
	clear_drag_state()
	return result


func cancel_drag() -> void:
	clear_drag_state()


func clear_drag_state() -> void:
	source = Source.NONE
	entry_id = -1
	board_unit = null
	from_cell = Vector2i(-1, -1)
	if _ghost != null:
		_ghost.visible = false


func _ensure_ghost() -> void:
	if _ghost != null:
		return
	_ghost = CARD_SCENE.instantiate() as UnitCardDisplay
	_ghost.name = "DragGhost"
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 100
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.85)
	add_child(_ghost)
	_ghost.configure(UnitCardDisplay.SIZE_DEFAULT)
	_ghost.visible = false


func _show_ghost(entry: DeckEntry, level_config: LevelConfig, viewport_pos: Vector2) -> void:
	_ensure_ghost()
	if entry == null or entry.unit == null:
		return
	_ghost.bind_deck_entry(entry, level_config)
	_ghost.visible = true
	_position_ghost(viewport_pos)


func _position_ghost(viewport_pos: Vector2) -> void:
	if _ghost == null:
		return
	var half := UnitCardDisplay.SIZE_DEFAULT * 0.5
	_ghost.position = viewport_pos - half
