@tool
extends EditorPlugin

const DOCK_SCENE := preload("res://addons/wave_spawn_editor/wave_spawn_editor_dock.tscn")

var _dock: Control


func _enter_tree() -> void:
	_dock = DOCK_SCENE.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_dock.name = "Wave Spawn"


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
