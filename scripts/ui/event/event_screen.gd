class_name EventScreen
extends Control

signal choice_selected(choice_index: int)

@onready var _title: Label = %TitleLabel
@onready var _body: Label = %BodyLabel
@onready var _choices: VBoxContainer = %ChoicesContainer

var _event_data: EventData


func show_event(event_data: EventData) -> void:
	_event_data = event_data
	visible = true
	_title.text = event_data.title if event_data != null else "随机事件"
	_body.text = event_data.body if event_data != null else ""
	_rebuild_choices()


func hide_event() -> void:
	visible = false
	_event_data = null


func _rebuild_choices() -> void:
	for child in _choices.get_children():
		child.queue_free()
	if _event_data == null:
		return
	for i in _event_data.choices.size():
		var choice := _event_data.choices[i]
		var button := Button.new()
		button.text = choice.label
		button.custom_minimum_size = Vector2(360, 44)
		button.pressed.connect(_on_choice_pressed.bind(i))
		_choices.add_child(button)
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()


func _on_choice_pressed(index: int) -> void:
	choice_selected.emit(index)
