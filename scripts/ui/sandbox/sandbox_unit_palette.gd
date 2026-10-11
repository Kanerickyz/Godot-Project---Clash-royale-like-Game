class_name SandboxUnitPalette
extends Control

signal unit_selected(unit_data: UnitData)
signal unit_hovered(unit_data: UnitData)
signal unit_unhovered()
signal team_changed(team: UnitInstance.Team)
signal level_changed(level: int)
signal clear_pressed
signal start_combat_pressed
signal back_pressed

const DEFAULT_SHOP_POOL := preload("res://resources/shop/dev_shop_pool.tres")

@onready var _player_team_button: Button = %PlayerTeamButton
@onready var _enemy_team_button: Button = %EnemyTeamButton
@onready var _level_option: OptionButton = %LevelOption
@onready var _unit_list: GridContainer = %UnitList
@onready var _clear_button: Button = %ClearButton
@onready var _start_button: Button = %StartButton
@onready var _back_button: Button = %BackButton

var _team: UnitInstance.Team = UnitInstance.Team.PLAYER
var _level: int = 1
var _selected_unit: UnitData
var _unit_buttons: Array[Button] = []


func _ready() -> void:
	_player_team_button.pressed.connect(_on_player_team_pressed)
	_enemy_team_button.pressed.connect(_on_enemy_team_pressed)
	_level_option.item_selected.connect(_on_level_selected)
	_clear_button.pressed.connect(func() -> void: clear_pressed.emit())
	_start_button.pressed.connect(func() -> void: start_combat_pressed.emit())
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	_setup_level_option()
	_populate_units()
	_update_team_buttons()
	set_combat_ready(false)


func get_selected_unit() -> UnitData:
	return _selected_unit


func get_selected_team() -> UnitInstance.Team:
	return _team


func get_selected_level() -> int:
	return _level


func set_edit_mode(enabled: bool) -> void:
	visible = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_set_controls_interactive(enabled)


func set_combat_ready(ready: bool) -> void:
	_start_button.disabled = not ready


func _setup_level_option() -> void:
	_level_option.clear()
	_level_option.add_item("Lv1", 0)
	_level_option.add_item("Lv2", 1)
	_level_option.add_item("Lv3", 2)
	_level_option.select(0)


func _populate_units() -> void:
	for child in _unit_list.get_children():
		child.queue_free()
	_unit_buttons.clear()

	var pool := _get_unit_pool()

	for unit_data in pool:
		if unit_data == null:
			continue
		var button := Button.new()
		button.text = unit_data.display_name
		button.custom_minimum_size = Vector2(120, 36)
		button.toggle_mode = true
		button.pressed.connect(_on_unit_button_pressed.bind(unit_data, button))
		button.mouse_entered.connect(_on_unit_button_mouse_entered.bind(unit_data))
		button.mouse_exited.connect(_on_unit_button_mouse_exited)
		_unit_list.add_child(button)
		_unit_buttons.append(button)

	if not _unit_buttons.is_empty():
		_unit_buttons[0].button_pressed = true
		_selected_unit = pool[0] if not pool.is_empty() else null
		if _selected_unit != null:
			unit_selected.emit(_selected_unit)


func _on_unit_button_pressed(unit_data: UnitData, button: Button) -> void:
	for other in _unit_buttons:
		if other != button:
			other.button_pressed = false
	button.button_pressed = true
	_selected_unit = unit_data
	unit_selected.emit(unit_data)


func _on_unit_button_mouse_entered(unit_data: UnitData) -> void:
	unit_hovered.emit(unit_data)


func _on_unit_button_mouse_exited() -> void:
	unit_unhovered.emit()


func _on_player_team_pressed() -> void:
	_team = UnitInstance.Team.PLAYER
	_update_team_buttons()
	team_changed.emit(_team)


func _on_enemy_team_pressed() -> void:
	_team = UnitInstance.Team.ENEMY
	_update_team_buttons()
	team_changed.emit(_team)


func _on_level_selected(index: int) -> void:
	_level = index + 1
	level_changed.emit(_level)


func _update_team_buttons() -> void:
	_player_team_button.button_pressed = _team == UnitInstance.Team.PLAYER
	_enemy_team_button.button_pressed = _team == UnitInstance.Team.ENEMY


func _set_controls_interactive(enabled: bool) -> void:
	_player_team_button.disabled = not enabled
	_enemy_team_button.disabled = not enabled
	_level_option.disabled = not enabled
	_clear_button.disabled = not enabled
	_back_button.disabled = not enabled
	for button in _unit_buttons:
		button.disabled = not enabled
	if not enabled:
		_start_button.disabled = true


func _get_unit_pool() -> Array[UnitData]:
	var pool: Array[UnitData] = []
	if DEFAULT_SHOP_POOL == null:
		return pool
	var source: Array = (
		DEFAULT_SHOP_POOL.character_pool
		if not DEFAULT_SHOP_POOL.character_pool.is_empty()
		else DEFAULT_SHOP_POOL.pool
	)
	for item in source:
		if item is UnitData:
			pool.append(item)
	return pool
