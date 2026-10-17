class_name ProjectLoadSmokeTest
extends RefCounted
## Light-acceptance smoke: load key PackedScenes without SCRIPT/Parse errors.


const SCENES: PackedStringArray = [
	"res://scenes/main/main.tscn",
]


static func run_all() -> bool:
	var ok := true
	for path in SCENES:
		if not _load_scene(path):
			ok = false
	return ok


static func _load_scene(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_error("ProjectLoadSmokeTest: missing scene %s" % path)
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("ProjectLoadSmokeTest: failed to load %s" % path)
		return false
	var node := packed.instantiate()
	if node == null:
		push_error("ProjectLoadSmokeTest: instantiate failed %s" % path)
		return false
	# Fail if the root script failed to compile/attach (instantiate can still succeed).
	if path.ends_with("main.tscn") and node.get_script() == null:
		push_error("ProjectLoadSmokeTest: main scene root has no script (compile failed?) %s" % path)
		node.free()
		return false
	node.free()
	return true
