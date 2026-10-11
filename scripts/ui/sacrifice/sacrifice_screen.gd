class_name SacrificeScreen
extends Control

enum Step { INTRO, DRAG }
enum DragSource { NONE, POOL, RECIPIENT, DONOR }

signal sacrifice_completed(donor_id: int, recipient_id: int)
signal skipped

const POOL_CARD_SCENE := preload("res://scenes/ui/sacrifice/sacrifice_pool_card.tscn")
const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")

@onready var _title: Label = %TitleLabel
@onready var _desc: Label = %DescLabel
@onready var _intro_panel: VBoxContainer = %IntroPanel
@onready var _drag_panel: VBoxContainer = %DragPanel
@onready var _recipient_slot: SacrificeDropSlot = %RecipientSlot
@onready var _donor_slot: SacrificeDropSlot = %DonorSlot
@onready var _pool_scroll: ScrollContainer = %PoolScroll
@onready var _pool_row: HBoxContainer = %PoolRow
@onready var _start_button: Button = %StartButton
@onready var _skip_button: Button = %SkipButton
@onready var _back_button: Button = %BackButton
@onready var _confirm_button: Button = %ConfirmButton
@onready var _drag_skip_button: Button = %DragSkipButton
@onready var _ghost_layer: Control = %GhostLayer

var _entries: Array[DeckEntry] = []
var _entry_map: Dictionary = {}
var _level_config: LevelConfig
var _step: Step = Step.INTRO
var _recipient_id: int = -1
var _donor_id: int = -1
var _drag_source: DragSource = DragSource.NONE
var _drag_entry_id: int = -1
var _ghost: UnitCardDisplay
var _pool_cards: Array[SacrificePoolCard] = []


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_drag_skip_button.pressed.connect(_on_skip_pressed)
	_recipient_slot.cleared.connect(_on_recipient_cleared)
	_donor_slot.cleared.connect(_on_donor_cleared)
	_recipient_slot.drag_started.connect(_on_recipient_drag_started)
	_donor_slot.drag_started.connect(_on_donor_drag_started)
	_recipient_slot.setup("祭献目标")
	_donor_slot.setup("祭献者")
	_ensure_ghost()


func _input(event: InputEvent) -> void:
	if not visible or _drag_source == DragSource.NONE:
		return
	if event is InputEventMouseMotion:
		_update_drag_ghost((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish_drag(mb.position)


func show_sacrifice(entries: Array[DeckEntry], level_config: LevelConfig = null) -> void:
	_entries = entries.duplicate()
	_entry_map.clear()
	for entry in _entries:
		if entry != null:
			_entry_map[entry.entry_id] = entry
	_level_config = level_config
	_recipient_slot.set_level_config(level_config)
	_donor_slot.set_level_config(level_config)
	_recipient_id = -1
	_donor_id = -1
	_cancel_drag()
	_show_step(Step.INTRO)
	visible = true
	if _start_button.disabled:
		_skip_button.grab_focus()
	else:
		_start_button.grab_focus()


func hide_sacrifice() -> void:
	_cancel_drag()
	visible = false


func _show_step(step: Step) -> void:
	_step = step
	_intro_panel.visible = step == Step.INTRO
	_drag_panel.visible = step == Step.DRAG

	match step:
		Step.INTRO:
			_title.text = "献祭祭坛"
			_desc.text = "祭献一名角色，将其主技能移植给另一名角色。"
			var can_sacrifice := _entries.size() >= 2
			_start_button.disabled = not can_sacrifice
			if can_sacrifice:
				_desc.text += "\n将角色拖拽到左侧接收者与右侧祭献者槽位。"
			else:
				_desc.text += "\n牌库角色不足，无法献祭。"
		Step.DRAG:
			_title.text = "布置献祭"
			_desc.text = "左侧：祭献目标（接收技能）  ·  右侧：祭献者（移出牌库）"
			_recipient_slot.clear_entry_silent()
			_donor_slot.clear_entry_silent()
			_recipient_id = -1
			_donor_id = -1
			_rebuild_pool()
			_update_confirm_state()


func _rebuild_pool() -> void:
	for card in _pool_cards:
		if is_instance_valid(card):
			card.queue_free()
	_pool_cards.clear()

	for entry in _entries:
		if entry == null:
			continue
		if entry.entry_id == _recipient_id or entry.entry_id == _donor_id:
			continue
		var card: SacrificePoolCard = POOL_CARD_SCENE.instantiate()
		_pool_row.add_child(card)
		card.set_level_config(_level_config)
		card.set_entry(entry)
		card.drag_started.connect(_on_pool_drag_started)
		_pool_cards.append(card)


func _find_entry(entry_id: int) -> DeckEntry:
	return _entry_map.get(entry_id, null) as DeckEntry


func _on_start_pressed() -> void:
	_show_step(Step.DRAG)


func _on_skip_pressed() -> void:
	hide_sacrifice()
	skipped.emit()


func _on_back_pressed() -> void:
	_cancel_drag()
	_show_step(Step.INTRO)


func _on_confirm_pressed() -> void:
	if _recipient_id < 0 or _donor_id < 0 or _recipient_id == _donor_id:
		return
	hide_sacrifice()
	sacrifice_completed.emit(_donor_id, _recipient_id)


func _on_recipient_cleared() -> void:
	_recipient_id = -1
	_rebuild_pool()
	_update_confirm_state()
	_refresh_desc_preview()


func _on_donor_cleared() -> void:
	_donor_id = -1
	_rebuild_pool()
	_update_confirm_state()
	_refresh_desc_preview()


func _on_pool_drag_started(entry_id: int, viewport_pos: Vector2) -> void:
	_begin_drag(DragSource.POOL, entry_id, viewport_pos)


func _on_recipient_drag_started(entry_id: int, viewport_pos: Vector2) -> void:
	_recipient_slot.clear_entry_silent()
	_recipient_id = -1
	_begin_drag(DragSource.RECIPIENT, entry_id, viewport_pos)


func _on_donor_drag_started(entry_id: int, viewport_pos: Vector2) -> void:
	_donor_slot.clear_entry_silent()
	_donor_id = -1
	_begin_drag(DragSource.DONOR, entry_id, viewport_pos)


func _begin_drag(source: DragSource, entry_id: int, viewport_pos: Vector2) -> void:
	var entry := _find_entry(entry_id)
	if entry == null:
		return
	_drag_source = source
	_drag_entry_id = entry_id
	_show_ghost(entry, viewport_pos)
	match source:
		DragSource.POOL:
			for card in _pool_cards:
				if card.get_entry_id() == entry_id:
					card.modulate = Color(1, 1, 1, 0.35)
		DragSource.RECIPIENT:
			_recipient_slot.modulate = Color(1, 1, 1, 0.65)
		DragSource.DONOR:
			_donor_slot.modulate = Color(1, 1, 1, 0.65)


func _finish_drag(viewport_pos: Vector2) -> void:
	if _drag_source == DragSource.NONE:
		return
	var entry_id := _drag_entry_id
	var source := _drag_source
	_cancel_drag_visuals()

	var target := _resolve_drop_target(viewport_pos)
	match target:
		"recipient":
			_assign_recipient(entry_id, source)
		"donor":
			_assign_donor(entry_id, source)
		"pool":
			_return_to_pool(entry_id, source)
		_:
			_restore_after_failed_drop(entry_id, source)

	_drag_source = DragSource.NONE
	_drag_entry_id = -1
	if _ghost != null:
		_ghost.visible = false
	_update_confirm_state()
	_refresh_desc_preview()


func _resolve_drop_target(viewport_pos: Vector2) -> String:
	if _recipient_slot.contains_global_point(viewport_pos):
		return "recipient"
	if _donor_slot.contains_global_point(viewport_pos):
		return "donor"
	if _pool_scroll.get_global_rect().grow(8.0).has_point(viewport_pos):
		return "pool"
	return ""


func _assign_recipient(entry_id: int, source: DragSource) -> void:
	if entry_id == _donor_id:
		return
	if source == DragSource.RECIPIENT:
		return
	var entry := _find_entry(entry_id)
	if entry == null:
		return
	if source == DragSource.DONOR:
		_donor_id = -1
		_donor_slot.clear_entry_silent()
	_recipient_id = entry_id
	_recipient_slot.set_entry(entry)
	_rebuild_pool()


func _assign_donor(entry_id: int, source: DragSource) -> void:
	if entry_id == _recipient_id:
		return
	if source == DragSource.DONOR:
		return
	var entry := _find_entry(entry_id)
	if entry == null:
		return
	if source == DragSource.RECIPIENT:
		_recipient_id = -1
		_recipient_slot.clear_entry_silent()
	_donor_id = entry_id
	_donor_slot.set_entry(entry)
	_rebuild_pool()


func _return_to_pool(entry_id: int, source: DragSource) -> void:
	match source:
		DragSource.RECIPIENT:
			if _recipient_id == entry_id:
				_recipient_id = -1
				_recipient_slot.clear_entry_silent()
		DragSource.DONOR:
			if _donor_id == entry_id:
				_donor_id = -1
				_donor_slot.clear_entry_silent()
	_rebuild_pool()


func _restore_after_failed_drop(entry_id: int, source: DragSource) -> void:
	match source:
		DragSource.RECIPIENT:
			var entry := _find_entry(entry_id)
			if entry != null:
				_recipient_slot.set_entry(entry)
		DragSource.DONOR:
			var entry := _find_entry(entry_id)
			if entry != null:
				_donor_slot.set_entry(entry)
		DragSource.POOL:
			_rebuild_pool()


func _cancel_drag_visuals() -> void:
	for card in _pool_cards:
		if is_instance_valid(card):
			card.modulate = Color.WHITE
	_recipient_slot.modulate = Color.WHITE
	_donor_slot.modulate = Color.WHITE


func _cancel_drag() -> void:
	_cancel_drag_visuals()
	_drag_source = DragSource.NONE
	_drag_entry_id = -1
	if _ghost != null:
		_ghost.visible = false


func _update_confirm_state() -> void:
	var ready := _recipient_id >= 0 and _donor_id >= 0 and _recipient_id != _donor_id
	_confirm_button.disabled = not ready


func _refresh_desc_preview() -> void:
	if _step != Step.DRAG:
		return
	var base := "左侧：祭献目标（接收技能）  ·  右侧：祭献者（移出牌库）"
	var donor := _find_entry(_donor_id)
	if donor != null and donor.unit != null and donor.unit.ability != null:
		var ability_desc := UnitInfoText.get_ability_description(donor.unit.ability)
		if not ability_desc.is_empty():
			base += "\n将移植：%s" % ability_desc
	elif _donor_id >= 0:
		base += "\n该祭献者没有可转移的主技能，献祭后仅将其移出牌库。"
	_desc.text = base


func _ensure_ghost() -> void:
	if _ghost != null:
		return
	var layer := _ghost_layer if _ghost_layer != null else get_node_or_null("%GhostLayer") as Control
	if layer == null:
		return
	_ghost = CARD_SCENE.instantiate() as UnitCardDisplay
	if _ghost == null:
		return
	_ghost.name = "DragGhost"
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 100
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.88)
	layer.add_child(_ghost)
	_ghost.configure(UnitCardDisplay.SIZE_DEFAULT)
	_ghost.visible = false


func _show_ghost(entry: DeckEntry, viewport_pos: Vector2) -> void:
	_ensure_ghost()
	if entry == null or entry.unit == null or _ghost == null:
		return
	_ghost.bind_deck_entry(entry, _level_config)
	_ghost.visible = true
	_position_ghost(viewport_pos)


func _update_drag_ghost(viewport_pos: Vector2) -> void:
	if _ghost == null or not _ghost.visible:
		return
	_position_ghost(viewport_pos)
	_highlight_drop_targets(viewport_pos)


func _position_ghost(viewport_pos: Vector2) -> void:
	if _ghost == null:
		return
	var half := UnitCardDisplay.SIZE_DEFAULT * 0.5
	_ghost.global_position = viewport_pos - half


func _highlight_drop_targets(viewport_pos: Vector2) -> void:
	var over_recipient := _recipient_slot.contains_global_point(viewport_pos)
	var over_donor := _donor_slot.contains_global_point(viewport_pos)
	_recipient_slot.modulate = Color(0.85, 1.0, 0.85) if over_recipient else Color.WHITE
	_donor_slot.modulate = Color(1.0, 0.85, 0.85) if over_donor else Color.WHITE
