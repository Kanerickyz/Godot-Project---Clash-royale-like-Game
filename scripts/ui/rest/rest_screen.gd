class_name RestScreen
extends Control

signal rest_choice_selected(choice: StringName)

@onready var _title: Label = %TitleLabel
@onready var _heal_button: Button = %HealButton
@onready var _remove_button: Button = %RemoveButton


func _ready() -> void:
	_heal_button.pressed.connect(_on_heal_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)


func show_rest() -> void:
	visible = true
	_heal_button.grab_focus()


func hide_rest() -> void:
	visible = false


func _on_heal_pressed() -> void:
	rest_choice_selected.emit(&"heal")


func _on_remove_pressed() -> void:
	rest_choice_selected.emit(&"remove")
