class_name MapScreen
extends Control

signal node_selected(node_id: int)

@onready var _map_view: MapView = %MapView
@onready var _title_label: Label = %TitleLabel
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	_map_view.node_selected.connect(_on_node_selected)


func show_map(run_controller: RunController) -> void:
	visible = true
	if run_controller != null and run_controller.map_config != null:
		_title_label.text = run_controller.map_config.act_display_name
	else:
		_title_label.text = "远征地图"
	_hint_label.text = "选择一条路径前进"
	if run_controller != null:
		_map_view.set_map_state(run_controller.get_map_state())


func hide_map() -> void:
	visible = false


func refresh_map(run_controller: RunController) -> void:
	if run_controller != null:
		_map_view.set_map_state(run_controller.get_map_state())


func _on_node_selected(node_id: int) -> void:
	node_selected.emit(node_id)
