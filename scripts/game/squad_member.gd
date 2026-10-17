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
	var angle := float(follow_index + 1) * TAU / 5.0
	var desired := follow_target.global_position + Vector2(cos(angle), sin(angle)) * follow_distance
	var to_desired := desired - global_position
	if to_desired.length() > 8.0:
		velocity = to_desired.normalized() * get_move_speed()
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _read_move_vector() -> Vector2:
	if get_parent() != null:
		var gc := get_tree().get_first_node_in_group(&"game_controller")
		if gc != null and (gc.get("ui_blocking") == true or gc.get("game_over") == true):
			return Vector2.ZERO
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if InputMap.has_action("ui_up") and Input.is_action_pressed("ui_up"):
		dir.y -= 1.0
	if InputMap.has_action("ui_down") and Input.is_action_pressed("ui_down"):
		dir.y += 1.0
	if InputMap.has_action("ui_left") and Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if InputMap.has_action("ui_right") and Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	return dir
