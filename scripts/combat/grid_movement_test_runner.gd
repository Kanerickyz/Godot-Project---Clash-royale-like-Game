extends SceneTree

const GridMovementTestScript := preload("res://scripts/combat/grid_movement_test.gd")


func _initialize() -> void:
	var ok: bool = GridMovementTestScript.run_all()
	quit(0 if ok else 1)
