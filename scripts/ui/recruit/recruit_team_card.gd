class_name RecruitTeamCard
extends Control
## 上区队伍成员卡片：满员替换时作为放置目标 / 点选目标。

const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")

signal selected(entry_id: int)

@onready var _card_host: Control = %CardHost
@onready var _name_label: Label = %NameLabel
@onready var _highlight: ColorRect = %Highlight

var entry_id: int = -1
var _entry: DeckEntry
var _card: UnitCardDisplay
var _selected: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_card()
	_refresh()


func setup(entry: DeckEntry, selected: bool = false) -> void:
	_entry = entry
	entry_id = entry.entry_id if entry != null else -1
	_selected = selected
	if is_node_ready():
		_refresh()
	else:
		call_deferred("_refresh")


func set_selected(selected: bool) -> void:
	_selected = selected
	if _highlight != null:
		_highlight.visible = selected


func _refresh() -> void:
	_ensure_card()
	if _entry == null or _entry.unit == null:
		visible = false
		return
	visible = true
	if _name_label != null:
		_name_label.text = _entry.get_display_name()
	if _highlight != null:
		_highlight.visible = _selected
	if _card != null:
		_card.bind_deck_entry(_entry, null)


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
	if _entry == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			selected.emit(entry_id)
