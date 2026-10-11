extends SceneTree

const WfcGeneratorTestScript := preload("res://scripts/core/wfc/wfc_generator_test.gd")


func _initialize() -> void:
	var ok: bool = WfcGeneratorTestScript.run_all()
	quit(0 if ok else 1)
