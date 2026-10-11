class_name DeckReplaceModal
extends Control

signal entry_selected(entry_id: int)
signal cancelled

@onready var _panel: PanelContainer = %Panel
@onready var _list: VBoxContainer = %EntryList
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	visible = false
	_cancel_button.pressed.connect(_on_cancel_pressed)


func show_entries(entries: Array[DeckEntry]) -> void:
	for child in _list.get_children():
		child.queue_free()

	for entry in entries:
		if entry == null:
			continue
		var button := Button.new()
		var summary := entry.get_buff_summary()
		var level_tag := " · Lv.%d" % entry.level
		if summary.is_empty():
			button.text = "%s%s" % [entry.get_display_name(), level_tag]
		else:
			button.text = "%s%s（%s）" % [entry.get_display_name(), level_tag, summary]
		var entry_id := entry.entry_id
		button.pressed.connect(func() -> void: _on_entry_pressed(entry_id))
		_list.add_child(button)

	visible = true


func hide_modal() -> void:
	visible = false


func _on_entry_pressed(entry_id: int) -> void:
	hide_modal()
	entry_selected.emit(entry_id)


func _on_cancel_pressed() -> void:
	hide_modal()
	cancelled.emit()
