class_name SquadMember
extends Combatant
## Ally unit: captain is player-moved (no basic attack); followers follow / assemble / auto-attack.


var is_captain: bool = false
var follow_target: Node2D
var follow_index: int = 0
var follow_distance: float = 42.0
var assemble_active: bool = false
var assemble_follow_distance: float = 28.0


func configure_as_captain(def: UnitDefinition) -> void:
	is_captain = true
	setup(def, Team.ALLY)


func configure_as_follower(def: UnitDefinition, captain: Node2D, index: int) -> void:
	is_captain = false
	follow_target = captain
	follow_index = index
	setup(def, Team.ALLY)


func set_assemble(active: bool, pull_distance: float = 28.0) -> void:
	assemble_active = active
	assemble_follow_distance = maxf(12.0, pull_distance)


func _combat_step(delta: float) -> void:
	if is_captain:
		_move_as_captain(delta)
		# Phase A: commander positions; followers auto-fight. No captain basic attack.
		return
	_follow_captain(delta)
	_try_auto_attack()


func _move_as_captain(_delta: float) -> void:
	var dir := _read_move_vector()
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		velocity = dir * get_move_speed()
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _follow_captain(_delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var desired := follow_target.global_position
	var ring := assemble_follow_distance if assemble_active else follow_distance
	# When captain camps a chest, peel toward the chest to auto-smash (unless assembling).
	var gc := get_tree().get_first_node_in_group(&"game_controller") if is_inside_tree() else null
	var chest: Node2D = null
	if not assemble_active and gc != null and gc.has_method("get_focused_chest"):
		chest = gc.call("get_focused_chest") as Node2D
	if chest != null and is_instance_valid(chest):
		var angle := float(follow_index + 1) * TAU / 5.0
		desired = chest.global_position + Vector2(cos(angle), sin(angle)) * 28.0
	else:
		var angle2 := float(follow_index + 1) * TAU / 5.0
		desired = follow_target.global_position + Vector2(cos(angle2), sin(angle2)) * ring
	var to_desired := desired - global_position
	var speed := get_move_speed()
	if assemble_active:
		speed *= 1.35
	if to_desired.length() > 8.0:
		velocity = to_desired.normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _read_move_vector() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	var gc := get_tree().get_first_node_in_group(&"game_controller")
	if gc != null and gc.has_method("get_move_vector"):
		return gc.call("get_move_vector") as Vector2
	return Vector2.ZERO
