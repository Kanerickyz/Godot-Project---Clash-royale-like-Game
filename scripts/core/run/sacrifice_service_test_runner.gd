extends SceneTree

const SacrificeServiceTestScript := preload("res://scripts/core/run/sacrifice_service_test.gd")


func _initialize() -> void:
	var ok: bool = SacrificeServiceTestScript.run_all()
	quit(0 if ok else 1)
