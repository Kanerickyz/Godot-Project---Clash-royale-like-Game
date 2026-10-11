extends SceneTree

const FaintTest := preload("res://scripts/combat/effect_resolver_faint_test.gd")


func _initialize() -> void:
	var ok: bool = FaintTest.run_all()
	quit(0 if ok else 1)
