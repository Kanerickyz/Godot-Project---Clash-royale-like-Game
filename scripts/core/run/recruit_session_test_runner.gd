extends SceneTree

const RecruitSessionTestScript := preload("res://scripts/core/run/recruit_session_test.gd")


func _initialize() -> void:
	var ok: bool = RecruitSessionTestScript.run_all()
	quit(0 if ok else 1)
