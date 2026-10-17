class_name Combatant
extends CharacterBody2D
## Shared HP / attack / movement for allies and hostiles.


signal died(who: Combatant)
signal damaged(who: Combatant, amount: int, remaining: int)

enum Team { ALLY, HOSTILE }
enum AnimPose { IDLE, MOVE, ATTACK, DEATH }

const GROUP_ALLIES := &"allies"
const GROUP_HOSTILES := &"hostiles"
const GROUP_ATTACKABLE := &"attackable"
const REGEN_DELAY_SEC := 5.0
const REGEN_PER_SEC := 6.0

var definition: UnitDefinition
var team: Team = Team.ALLY
var current_hp: int = 0
var is_dead: bool = false
var combat_enabled: bool = true

var _attack_cd: float = 0.0
var _stun_remaining: float = 0.0
var _collision_radius: float = 14.0
var _sprite: Sprite2D
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _base_sprite_scale: Vector2 = Vector2.ONE
var _pose: AnimPose = AnimPose.IDLE
var _loop_tween: Tween
var _oneshot_tween: Tween
var _out_of_combat_sec: float = 0.0
var _regen_accum: float = 0.0


func setup(def: UnitDefinition, p_team: Team) -> void:
	if def == null:
		push_error("Combatant.setup: definition is null")
		return
	definition = def.duplicate(true) as UnitDefinition
	team = p_team
	current_hp = definition.max_hp
	is_dead = false
	_out_of_combat_sec = 0.0
	_ensure_visuals()
	_apply_sprite()
	_update_hp_bar()
	_refresh_groups()
	_set_pose(AnimPose.IDLE)


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_hp = maxi(0, current_hp - amount)
	_mark_in_combat()
	damaged.emit(self, amount, current_hp)
	DamagePopup.spawn(get_parent() if get_parent() else self, global_position, amount)
	_flash_hit()
	_update_hp_bar()
	if current_hp <= 0:
		_die()


func heal_full() -> void:
	if definition == null:
		return
	current_hp = definition.max_hp
	_update_hp_bar()


func get_attack_range() -> float:
	if definition == null:
		return 0.0
	return definition.attack_range


func get_move_speed() -> float:
	if definition == null:
		return 0.0
	return definition.move_speed


func get_collision_radius() -> float:
	return _collision_radius


func set_collision_radius(radius: float) -> void:
	_collision_radius = maxf(4.0, radius)
	_ensure_visuals()
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = _collision_radius


func is_stunned() -> bool:
	return _stun_remaining > 0.0


func apply_stun(duration: float) -> void:
	if is_dead or duration <= 0.0:
		return
	_stun_remaining = maxf(_stun_remaining, duration)
	velocity = Vector2.ZERO


## Knockback displace, then damage, then short stun. Safe for allies and hostiles.
func apply_charge_impact(
	push_dir: Vector2,
	knockback_distance: float,
	damage: int,
	stun_duration: float
) -> void:
	if is_dead:
		return
	var dir := push_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if knockback_distance > 0.0:
		global_position += dir * knockback_distance
	if damage > 0:
		take_damage(damage)
	if not is_dead and stun_duration > 0.0:
		apply_stun(stun_duration)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _stun_remaining > 0.0:
		_stun_remaining = maxf(0.0, _stun_remaining - delta)
		_attack_cd = maxf(0.0, _attack_cd - delta)
		velocity = Vector2.ZERO
		move_and_slide()
		_update_move_pose()
		_tick_regen(delta)
		return
	if not combat_enabled:
		velocity = Vector2.ZERO
		_update_move_pose()
		_tick_regen(delta)
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_combat_step(delta)
	_update_move_pose()
	_tick_regen(delta)


func _combat_step(_delta: float) -> void:
	pass


func _try_auto_attack() -> void:
	if is_dead or definition == null or _attack_cd > 0.0:
		return
	var target := _find_attack_target()
	if target == null:
		return
	if target.has_method("take_damage"):
		target.call("take_damage", definition.attack_damage)
	_mark_in_combat()
	_play_attack_punch(target as Node2D)
	_attack_cd = definition.attack_interval


func _find_attack_target() -> Node2D:
	if definition == null or not is_inside_tree():
		return null
	var focused_chest := _get_focused_chest()
	if focused_chest != null and team == Team.ALLY and _is_valid_hostile_target(focused_chest):
		var chest_range := maxf(definition.attack_range, 100.0)
		if global_position.distance_to(focused_chest.global_position) <= chest_range:
			return focused_chest
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(GROUP_ATTACKABLE):
		if node == self or not is_instance_valid(node):
			continue
		if not _is_valid_hostile_target(node):
			continue
		var range_limit := definition.attack_range
		if team == Team.ALLY and node.is_in_group(&"chests"):
			range_limit = maxf(range_limit, 100.0)
		var dist := global_position.distance_to((node as Node2D).global_position)
		if dist <= range_limit and dist < best_dist:
			best_dist = dist
			best = node as Node2D
	return best


func _get_focused_chest() -> Node2D:
	var gc := get_tree().get_first_node_in_group(&"game_controller")
	if gc != null and gc.has_method("get_focused_chest"):
		return gc.call("get_focused_chest") as Node2D
	return null


func _is_valid_hostile_target(node: Node) -> bool:
	if node.has_method("get") and node.get("is_dead") == true:
		return false
	if team == Team.ALLY:
		return node.is_in_group(GROUP_HOSTILES) or node.is_in_group(&"chests")
	return node.is_in_group(GROUP_ALLIES)


func _mark_in_combat() -> void:
	_out_of_combat_sec = 0.0
	_regen_accum = 0.0


func _tick_regen(delta: float) -> void:
	if team != Team.ALLY or definition == null or is_dead:
		return
	if current_hp >= definition.max_hp:
		_out_of_combat_sec = 0.0
		return
	_out_of_combat_sec += delta
	if _out_of_combat_sec < REGEN_DELAY_SEC:
		return
	_regen_accum += REGEN_PER_SEC * delta
	var heal := int(_regen_accum)
	if heal <= 0:
		return
	_regen_accum -= float(heal)
	current_hp = mini(definition.max_hp, current_hp + heal)
	_update_hp_bar()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	collision_layer = 0
	collision_mask = 0
	combat_enabled = false
	velocity = Vector2.ZERO
	_play_death_anim()


func _ensure_visuals() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.centered = true
		add_child(_sprite)
	if _hp_bg == null:
		_hp_bg = ColorRect.new()
		_hp_bg.name = "HpBg"
		_hp_bg.size = Vector2(40, 5)
		_hp_bg.position = Vector2(-20, -36)
		_hp_bg.color = Color(0.15, 0.15, 0.15, 0.85)
		add_child(_hp_bg)
		_hp_fill = ColorRect.new()
		_hp_fill.name = "HpFill"
		_hp_fill.size = Vector2(40, 5)
		_hp_fill.position = Vector2.ZERO
		_hp_fill.color = Color(0.25, 0.85, 0.35, 1.0)
		_hp_bg.add_child(_hp_fill)
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = _collision_radius
		shape.shape = circle
		add_child(shape)
	else:
		var existing := get_node("CollisionShape2D") as CollisionShape2D
		var circle2 := existing.shape as CircleShape2D
		if circle2 != null:
			circle2.radius = _collision_radius


func _apply_sprite() -> void:
	if _sprite == null or definition == null:
		return
	_sprite.texture = definition.sprite
	_base_sprite_scale = Vector2.ONE * definition.sprite_scale
	_sprite.scale = _base_sprite_scale
	_sprite.modulate = Color.WHITE
	_sprite.rotation = 0.0
	if team == Team.HOSTILE:
		_hp_fill.color = Color(0.9, 0.3, 0.25, 1.0)
	else:
		_hp_fill.color = Color(0.25, 0.85, 0.35, 1.0)


func _update_hp_bar() -> void:
	if _hp_fill == null or definition == null:
		return
	var ratio := 0.0
	if definition.max_hp > 0:
		ratio = float(current_hp) / float(definition.max_hp)
	_hp_fill.size.x = 40.0 * clampf(ratio, 0.0, 1.0)


func _refresh_groups() -> void:
	add_to_group(GROUP_ATTACKABLE)
	if team == Team.ALLY:
		add_to_group(GROUP_ALLIES)
		remove_from_group(GROUP_HOSTILES)
		collision_layer = 2
		collision_mask = 1
	else:
		add_to_group(GROUP_HOSTILES)
		remove_from_group(GROUP_ALLIES)
		collision_layer = 4
		collision_mask = 1


func _update_move_pose() -> void:
	if is_dead or _pose == AnimPose.ATTACK or _pose == AnimPose.DEATH:
		return
	if velocity.length() > 18.0:
		_set_pose(AnimPose.MOVE)
	else:
		_set_pose(AnimPose.IDLE)


func _set_pose(pose: AnimPose) -> void:
	if _pose == pose and pose != AnimPose.ATTACK:
		return
	if pose != AnimPose.ATTACK and pose != AnimPose.DEATH:
		_pose = pose
	else:
		_pose = pose
	if pose == AnimPose.IDLE or pose == AnimPose.MOVE:
		_start_loop_anim(pose)


func _kill_loop_tween() -> void:
	if _loop_tween != null and is_instance_valid(_loop_tween):
		_loop_tween.kill()
	_loop_tween = null
	if _sprite != null and _pose != AnimPose.DEATH and _pose != AnimPose.ATTACK:
		_sprite.position.y = 0.0
		_sprite.rotation = 0.0
		_sprite.scale = _base_sprite_scale


func _start_loop_anim(pose: AnimPose) -> void:
	if _sprite == null:
		return
	_kill_loop_tween()
	_loop_tween = create_tween()
	_loop_tween.set_loops()
	match pose:
		AnimPose.IDLE:
			_loop_tween.tween_property(_sprite, "position:y", -3.0, 0.55).set_trans(Tween.TRANS_SINE)
			_loop_tween.tween_property(_sprite, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
		AnimPose.MOVE:
			_loop_tween.tween_property(_sprite, "position:y", -5.0, 0.18).set_trans(Tween.TRANS_SINE)
			_loop_tween.parallel().tween_property(_sprite, "rotation", 0.08, 0.18)
			_loop_tween.tween_property(_sprite, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
			_loop_tween.parallel().tween_property(_sprite, "rotation", -0.08, 0.18)
		_:
			_kill_loop_tween()


func _play_attack_punch(target: Node2D) -> void:
	if _sprite == null:
		return
	_kill_loop_tween()
	_pose = AnimPose.ATTACK
	if _oneshot_tween != null and is_instance_valid(_oneshot_tween):
		_oneshot_tween.kill()
	var dir := Vector2.RIGHT
	if target != null and is_instance_valid(target):
		dir = (target.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
	_oneshot_tween = create_tween()
	_oneshot_tween.tween_property(_sprite, "position", dir * 10.0, 0.07)
	_oneshot_tween.parallel().tween_property(_sprite, "scale", _base_sprite_scale * 1.12, 0.07)
	_oneshot_tween.tween_property(_sprite, "position", Vector2.ZERO, 0.12)
	_oneshot_tween.parallel().tween_property(_sprite, "scale", _base_sprite_scale, 0.12)
	_oneshot_tween.tween_callback(func() -> void:
		if is_dead:
			return
		_pose = AnimPose.IDLE
		_update_move_pose()
	)


func _flash_hit() -> void:
	if _sprite == null or is_dead:
		return
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.05)
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.12)


func _play_death_anim() -> void:
	_kill_loop_tween()
	_pose = AnimPose.DEATH
	if _oneshot_tween != null and is_instance_valid(_oneshot_tween):
		_oneshot_tween.kill()
	if _sprite == null:
		queue_free()
		return
	_oneshot_tween = create_tween()
	_oneshot_tween.set_parallel(true)
	_oneshot_tween.tween_property(_sprite, "modulate:a", 0.0, 0.35)
	_oneshot_tween.tween_property(_sprite, "scale", _base_sprite_scale * 0.25, 0.35)
	_oneshot_tween.tween_property(_sprite, "rotation", 0.6, 0.35)
	if _hp_bg != null:
		_oneshot_tween.tween_property(_hp_bg, "modulate:a", 0.0, 0.2)
	_oneshot_tween.chain().tween_callback(queue_free)
