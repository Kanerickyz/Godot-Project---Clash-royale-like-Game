class_name Enemy
extends Combatant
## Hostile grunt: chases nearest ally in aggro range, auto-attacks, drops gold/corpus.


signal gold_dropped(amount: int, at: Vector2)
signal corpus_dropped(amount: int, at: Vector2)

@export var aggro_range: float = 220.0

const WANDER_COOLDOWN_MIN := 1.6
const WANDER_COOLDOWN_MAX := 3.8
const WANDER_MOVE_MIN := 0.35
const WANDER_MOVE_MAX := 0.75
const WANDER_SPEED_FACTOR := 0.38

var is_elite: bool = false
var _corpus_drop_amount: int = 0
var _ducat_drop_override: int = -1
var _rng: RandomNumberGenerator
var _wander_cd: float = 0.0
var _wander_remaining: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _elite_label: Label


func configure(def: UnitDefinition, rng: RandomNumberGenerator, p_elite: bool = false) -> void:
	_rng = rng
	is_elite = p_elite
	setup(def, Team.HOSTILE)
	_wander_cd = _roll_wander_cooldown()
	if is_elite:
		add_to_group(&"elites")
		_ensure_elite_mark()


func set_loot_overrides(corpus_amount: int, ducat_override: int = -1) -> void:
	_corpus_drop_amount = maxi(0, corpus_amount)
	_ducat_drop_override = ducat_override


func _combat_step(delta: float) -> void:
	_chase_or_idle(delta)
	_try_auto_attack()


func _chase_or_idle(delta: float) -> void:
	var ally := _find_nearest_ally(aggro_range)
	if ally != null:
		_wander_remaining = 0.0
		var to_ally := ally.global_position - global_position
		var stop_dist := maxf(12.0, get_attack_range() * 0.7)
		if to_ally.length() > stop_dist:
			velocity = to_ally.normalized() * get_move_speed()
		else:
			velocity = Vector2.ZERO
		move_and_slide()
		return
	# No target: optional short wander (Boss has its own FSM — skip).
	if self is Boss:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_tick_wander(delta)


func _tick_wander(delta: float) -> void:
	if _wander_remaining > 0.0:
		_wander_remaining = maxf(0.0, _wander_remaining - delta)
		velocity = _wander_dir * get_move_speed() * WANDER_SPEED_FACTOR
		move_and_slide()
		if _wander_remaining <= 0.0:
			_wander_cd = _roll_wander_cooldown()
		return
	velocity = Vector2.ZERO
	move_and_slide()
	_wander_cd = maxf(0.0, _wander_cd - delta)
	if _wander_cd > 0.0:
		return
	_wander_dir = Vector2.RIGHT.rotated(_roll_angle())
	if _wander_dir == Vector2.ZERO:
		_wander_dir = Vector2.RIGHT
	_wander_remaining = _roll_wander_move_sec()


func _roll_wander_cooldown() -> float:
	if _rng != null:
		return _rng.randf_range(WANDER_COOLDOWN_MIN, WANDER_COOLDOWN_MAX)
	return WANDER_COOLDOWN_MIN


func _roll_wander_move_sec() -> float:
	if _rng != null:
		return _rng.randf_range(WANDER_MOVE_MIN, WANDER_MOVE_MAX)
	return WANDER_MOVE_MIN


func _roll_angle() -> float:
	if _rng != null:
		return _rng.randf() * TAU
	return 0.0


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
	if _ducat_drop_override >= 0:
		amount = _ducat_drop_override
	elif definition != null and _rng != null:
		var lo := mini(definition.gold_drop_min, definition.gold_drop_max)
		var hi := maxi(definition.gold_drop_min, definition.gold_drop_max)
		if hi > 0:
			amount = _rng.randi_range(lo, hi)
	if amount > 0:
		gold_dropped.emit(amount, global_position)
	if _corpus_drop_amount > 0:
		corpus_dropped.emit(_corpus_drop_amount, global_position)
	super._die()


func _ensure_elite_mark() -> void:
	if _elite_label != null:
		return
	_elite_label = Label.new()
	_elite_label.name = "EliteMark"
	_elite_label.text = "精英"
	_elite_label.position = Vector2(-16, -56)
	_elite_label.add_theme_font_size_override("font_size", 13)
	_elite_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25, 1.0))
	_elite_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02, 0.95))
	_elite_label.add_theme_constant_override("outline_size", 3)
	var font: Font = UiFonts.get_font()
	if font != null:
		_elite_label.add_theme_font_override("font", font)
	add_child(_elite_label)
	# Slight tint so silhouette reads as higher threat even without reading text.
	modulate = Color(1.15, 0.85, 0.7, 1.0)
