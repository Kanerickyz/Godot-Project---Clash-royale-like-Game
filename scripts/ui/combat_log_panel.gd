class_name CombatLogPanel
extends Control

const MAX_LINES := 200

@onready var _log_label: RichTextLabel = %LogLabel
@onready var _scroll: ScrollContainer = %Scroll

var _bus: CombatEventBus = null
var _lines: PackedStringArray = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin_combat(wave_index: int, spawn_summary: String) -> void:
	clear()
	visible = true
	var wave_num := wave_index + 1
	var text := "第 %d 波战斗开始" % wave_num
	if not spawn_summary.is_empty():
		text += " — 敌人：%s" % spawn_summary
	append_system(text)


func bind_event_bus(bus: CombatEventBus) -> void:
	if _bus != null and _bus.combat_event.is_connected(_on_combat_event):
		_bus.combat_event.disconnect(_on_combat_event)
	_bus = bus
	if _bus != null:
		_bus.combat_event.connect(_on_combat_event)


func append_system(text: String) -> void:
	_append_line(CombatLogText.system_line(text))


func clear() -> void:
	_lines.clear()
	if _log_label != null:
		_log_label.text = ""


func _on_combat_event(event_type: StringName, payload: CombatEventPayload) -> void:
	var line := CombatLogText.format_event(event_type, payload)
	if line.is_empty():
		return
	_append_line(line)


func _append_line(bbcode: String) -> void:
	_lines.append(bbcode)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	if _log_label == null:
		return
	_log_label.text = "\n".join(_lines)
	call_deferred("_scroll_to_bottom")


func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	var v_scroll := _scroll.get_v_scroll_bar()
	if v_scroll != null:
		v_scroll.value = v_scroll.max_value
