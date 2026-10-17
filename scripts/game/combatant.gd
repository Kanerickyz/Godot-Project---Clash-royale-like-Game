class_name Combatant
extends CharacterBody2D
## Shared HP / attack / movement for allies and hostiles.


signal died(who: Combatant)
signal damaged(who: Combatant, amount: int, remaining: int)

enum Team { ALLY, HOSTILE }

const GROUP_ALLIES := &"allies"
const GROUP_HOSTILES := &"hostiles"
const GROUP_ATTACKABLE := &"attackable"

var definition: UnitDefinition
var team: Team = Team.ALLY
var current_hp: int = 0
var is_dead: bool = false
var combat_enabled: bool = true

var _attack_cd: float = 0.0
var _sprite: Sprite2D
var _hp_bg: ColorRect
var _hp_fill: ColorRect


func setup(def: UnitDefinition, p_team: Team) -> void:
	if def == null:
		push_error("Combatant.setup: definition is null")
		return
	definition = def.duplicate(true) as UnitDefinition
	team = p_team
	current_hp = definition.max_hp
	is_dead = false
	_ensure_visuals()
	_apply_sprite()
	_update_hp_bar()
	_refresh_groups()


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_hp = maxi(0, current_hp - amount)
	damaged.emit(self, amount, current_hp)
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


func _physics_process(delta: float) -> void:
	if is_dead or not combat_enabled:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_combat_step(delta)


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
	_attack_cd = definition.attack_interval


func _find_attack_target() -> Node2D:
	if definition == null or not is_inside_tree():
		return null
	var best: Node2D = null
	var best_dist := definition.attack_range
	for node in get_tree().get_nodes_in_group(GROUP_ATTACKABLE):
		if node == self or not is_instance_valid(node):
			continue
		if not _is_valid_hostile_target(node):
			continue
		var dist := global_position.distance_to((node as Node2D).global_position)
		if dist <= best_dist:
			best_dist = dist
			best = node as Node2D
	return best


func _is_valid_hostile_target(node: Node) -> bool:
	if node.has_method("get") and node.get("is_dead") == true:
		return false
	if team == Team.ALLY:
		return node.is_in_group(GROUP_HOSTILES) or node.is_in_group(&"chests")
	return node.is_in_group(GROUP_ALLIES)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	collision_layer = 0
	collision_mask = 0
	hide()
	queue_free()


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
		circle.radius = 14.0
		shape.shape = circle
		add_child(shape)


func _apply_sprite() -> void:
	if _sprite == null or definition == null:
		return
	_sprite.texture = definition.sprite
	_sprite.scale = Vector2.ONE * definition.sprite_scale
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
