extends SceneTree

const MapGeneratorTestScript := preload("res://scripts/core/run/map_generator_test.gd")


func _initialize() -> void:
	var ok: bool = MapGeneratorTestScript.run_all()
	quit(0 if ok else 1)
