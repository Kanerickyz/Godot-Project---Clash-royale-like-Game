extends SceneTree

const AttackRangeTest := preload("res://scripts/combat/attack_range_preview_test.gd")


func _initialize() -> void:
	quit(0 if AttackRangeTest.run_all() else 1)
