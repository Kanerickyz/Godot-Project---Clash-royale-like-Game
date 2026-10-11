class_name TreasureScreen
extends Control

signal treasure_selected(buff_index: int)

@onready var _title: Label = %TitleLabel
@onready var _choices: HBoxContainer = %ChoicesContainer

var _offers: Array[BuffCardData] = []


func show_treasure(offers: Array[BuffCardData]) -> void:
	_offers = offers
	visible = true
	_rebuild_choices()


func hide_treasure() -> void:
	visible = false
	_offers.clear()


func _rebuild_choices() -> void:
	for child in _choices.get_children():
		child.queue_free()
	for i in _offers.size():
		var buff := _offers[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(180, 120)
		button.text = buff.display_name if buff != null else "增益"
		button.pressed.connect(_on_pick_pressed.bind(i))
		_choices.add_child(button)
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()


func _on_pick_pressed(index: int) -> void:
	treasure_selected.emit(index)
