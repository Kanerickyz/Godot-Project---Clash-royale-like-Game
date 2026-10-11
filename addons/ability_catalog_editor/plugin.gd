@tool
extends EditorPlugin

const DOCK_SCENE := preload("res://addons/ability_catalog_editor/ability_catalog_editor_dock.tscn")

var _dock: Control


func _enter_tree() -> void:
	_dock = DOCK_SCENE.instantiate()
	if _dock.has_method("set_editor_interface"):
		_dock.set_editor_interface(get_editor_interface())
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_dock.name = "Ability Catalog"


func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
