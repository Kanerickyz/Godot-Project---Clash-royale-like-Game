class_name SquadMember
extends Combatant
## Ally unit: captain is player-moved; others follow and auto-attack.


var is_captain: bool = false
var follow_target: Node2D
var follow_index: int = 0
var follow_distance: float = 42.0


func configure_as_captain(def: UnitDefinition) -> void:
	is_captain = true
	setup(def, Team.ALLY)


func configure_as_follower(def: UnitDefinition, captain: Node2D, index: int) -> void:
	is_captain = false
	follow_target = captain
	follow_index = index
	setup(def, Team.ALLY)


func _combat_step(delta: float) -> void:
	if is_captain:
		_move_as_captain(delta)
	else:
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
	# When captain camps a chest, peel toward the chest to auto-smash.
	var desired := follow_target.global_position
	var gc := get_tree().get_first_node_in_group(&"game_controller") if is_inside_tree() else null
	var chest: Node2D = null
	if gc != null and gc.has_method("get_focused_chest"):
		chest = gc.call("get_focused_chest") as Node2D
	if chest != null and is_instance_valid(chest):
		var angle := float(follow_index + 1) * TAU / 5.0
		desired = chest.global_position + Vector2(cos(angle), sin(angle)) * 28.0
	else:
		var angle2 := float(follow_index + 1) * TAU / 5.0
		desired = follow_target.global_position + Vector2(cos(angle2), sin(angle2)) * follow_distance
	var to_desired := desired - global_position
	if to_desired.length() > 8.0:
		velocity = to_desired.normalized() * get_move_speed()
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
