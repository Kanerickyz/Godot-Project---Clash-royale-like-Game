class_name Enemy
extends Combatant
## Hostile grunt: chases nearest ally in aggro range, auto-attacks, drops gold.


signal gold_dropped(amount: int, at: Vector2)

@export var aggro_range: float = 220.0

var _rng: RandomNumberGenerator


func configure(def: UnitDefinition, rng: RandomNumberGenerator) -> void:
	_rng = rng
	setup(def, Team.HOSTILE)


func _combat_step(_delta: float) -> void:
	_chase_or_idle()
	_try_auto_attack()


func _chase_or_idle() -> void:
	var ally := _find_nearest_ally(aggro_range)
	if ally == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var to_ally := ally.global_position - global_position
	var stop_dist := maxf(12.0, get_attack_range() * 0.7)
	if to_ally.length() > stop_dist:
		velocity = to_ally.normalized() * get_move_speed()
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _find_nearest_ally(max_dist: float) -> Node2D:
	if not is_inside_tree():
		return null
	var best: Node2D = null
	var best_d := max_dist
	for node in get_tree().get_nodes_in_group(GROUP_ALLIES):
		if not is_instance_valid(node):
			continue
		if node.get("is_dead") == true:
			continue
		var dist := global_position.distance_to((node as Node2D).global_position)
		if dist <= best_d:
			best_d = dist
			best = node as Node2D
	return best


func _die() -> void:
	if is_dead:
		return
	var amount := 0
	if definition != null and _rng != null:
		var lo := mini(definition.gold_drop_min, definition.gold_drop_max)
		var hi := maxi(definition.gold_drop_min, definition.gold_drop_max)
		if hi > 0:
			amount = _rng.randi_range(lo, hi)
	if amount > 0:
		gold_dropped.emit(amount, global_position)
	super._die()
