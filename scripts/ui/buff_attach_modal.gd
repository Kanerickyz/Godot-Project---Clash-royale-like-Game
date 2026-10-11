class_name BuffAttachModal
extends Control

signal entry_selected(entry_id: int)
signal cancelled

@onready var _list: VBoxContainer = %EntryList
@onready var _cancel_button: Button = %CancelButton
@onready var _title: Label = %TitleLabel


func _ready() -> void:
	visible = false
	_cancel_button.pressed.connect(_on_cancel_pressed)


func show_for_buff(buff: BuffCardData, entries: Array[DeckEntry]) -> void:
	var buff_name := buff.display_name if buff != null else "增益"
	_title.text = "选择要附加「%s」的角色" % buff_name

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
			button.text = "%s%s（已有：%s）" % [entry.get_display_name(), level_tag, summary]
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
