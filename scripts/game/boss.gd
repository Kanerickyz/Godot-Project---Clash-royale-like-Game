class_name Boss
extends Enemy
## Summon-charge boss: pressure → telegraph charge / summon → stun → pressure.


signal boss_defeated(boss: Boss)

enum Phase { PRESSURE, TELEGRAPH, CHARGING, SUMMONING, STUNNED }

const DEFAULT_BEHAVIOR_PATH := "res://resources/combat/boss_summon_charge.tres"
const DEFAULT_MINION_PATH := "res://resources/units/boss_minion.tres"
const TELEGRAPH_LENGTH_FALLBACK := 420.0

var behavior: BossBehaviorConfig
var minion_definition: UnitDefinition

var _phase: Phase = Phase.PRESSURE
var _phase_timer: float = 0.0
var _next_is_charge: bool = true
var _charge_dir: Vector2 = Vector2.RIGHT
var _charge_origin: Vector2 = Vector2.ZERO
var _charge_traveled: float = 0.0
var _charge_hit_ids: Dictionary = {}
var _telegraph: Polygon2D


func configure(def: UnitDefinition, rng: RandomNumberGenerator) -> void:
	super.configure(def, rng)
	if behavior == null:
		behavior = _load_behavior(DEFAULT_BEHAVIOR_PATH)
	if minion_definition == null:
		minion_definition = _load_unit_def(DEFAULT_MINION_PATH)
	_apply_body_from_behavior()
	_reset_cycle()


func configure_behavior(cfg: BossBehaviorConfig, minion_def: UnitDefinition = null) -> void:
	if cfg != null:
		behavior = cfg
	if minion_def != null:
		minion_definition = minion_def
	_apply_body_from_behavior()
	_reset_cycle()


func _combat_step(delta: float) -> void:
	if behavior == null:
		super._combat_step(delta)
		return
	match _phase:
		Phase.PRESSURE:
			_tick_pressure(delta)
		Phase.TELEGRAPH:
			_tick_telegraph(delta)
		Phase.CHARGING:
			_tick_charging(delta)
		Phase.SUMMONING:
			_tick_summoning(delta)
		Phase.STUNNED:
			_tick_stunned(delta)


func _die() -> void:
	if is_dead:
		return
	_clear_telegraph()
	boss_defeated.emit(self)
	# Skip gold drop; play shared death tween via Combatant.
	is_dead = true
	died.emit(self)
	collision_layer = 0
	collision_mask = 0
	combat_enabled = false
	velocity = Vector2.ZERO
	_play_death_anim()


func _apply_body_from_behavior() -> void:
	if behavior == null:
		return
	set_collision_radius(behavior.collision_radius)


func _reset_cycle() -> void:
	_phase = Phase.PRESSURE
	_phase_timer = behavior.pressure_duration if behavior else 2.5
	_next_is_charge = behavior.alternate_start_with_charge if behavior else true
	_charge_traveled = 0.0
	_charge_hit_ids.clear()
	_clear_telegraph()
	velocity = Vector2.ZERO


func _tick_pressure(delta: float) -> void:
	_phase_timer = maxf(0.0, _phase_timer - delta)
	var ally := _find_nearest_ally(aggro_range)
	if ally == null:
		velocity = Vector2.ZERO
		move_and_slide()
	else:
		var to_ally := ally.global_position - global_position
		var stop_dist := maxf(16.0, get_attack_range() * 0.7)
		var speed := get_move_speed() * behavior.pressure_move_speed_scale
		if to_ally.length() > stop_dist:
			velocity = to_ally.normalized() * speed
		else:
			velocity = Vector2.ZERO
		move_and_slide()
	_try_auto_attack()
	if _phase_timer <= 0.0:
		if _next_is_charge:
			_begin_telegraph()
		else:
			_begin_summon()


func _begin_telegraph() -> void:
	_phase = Phase.TELEGRAPH
	_phase_timer = behavior.telegraph_duration
	_charge_origin = global_position
	_charge_dir = _aim_at_squad()
	_charge_traveled = 0.0
	_charge_hit_ids.clear()
	velocity = Vector2.ZERO
	_show_telegraph()


func _tick_telegraph(delta: float) -> void:
	_phase_timer = maxf(0.0, _phase_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	_update_telegraph_visual()
	if _phase_timer <= 0.0:
		_begin_charge()


func _begin_charge() -> void:
	_phase = Phase.CHARGING
	_charge_origin = global_position
	_charge_traveled = 0.0
	_charge_hit_ids.clear()
	# Keep telegraph briefly readable at wind-up pose; clear so it does not ride the boss.
	_clear_telegraph()


func _tick_charging(delta: float) -> void:
	var step := behavior.charge_speed * delta
	velocity = _charge_dir * behavior.charge_speed
	move_and_slide()
	_charge_traveled += step
	_resolve_charge_hits()
	if _charge_traveled >= behavior.charge_distance:
		_next_is_charge = false
		_enter_stun(behavior.boss_stun_after_charge)


func _begin_summon() -> void:
	_phase = Phase.SUMMONING
	_phase_timer = 0.05
	velocity = Vector2.ZERO
	_spawn_minions()


func _tick_summoning(delta: float) -> void:
	_phase_timer = maxf(0.0, _phase_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _phase_timer <= 0.0:
		_next_is_charge = true
		_enter_stun(behavior.boss_stun_after_summon)


func _enter_stun(duration: float) -> void:
	_phase = Phase.STUNNED
	_phase_timer = maxf(0.05, duration)
	velocity = Vector2.ZERO


func _tick_stunned(delta: float) -> void:
	_phase_timer = maxf(0.0, _phase_timer - delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _phase_timer <= 0.0:
		_phase = Phase.PRESSURE
		_phase_timer = behavior.pressure_duration


func _aim_at_squad() -> Vector2:
	var ally := _find_nearest_ally(99999.0)
	if ally == null:
		return Vector2.RIGHT if _charge_dir == Vector2.ZERO else _charge_dir
	var dir := (ally.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		return Vector2.RIGHT
	return dir


func _resolve_charge_hits() -> void:
	if not is_inside_tree():
		return
	var half_w := behavior.charge_path_half_width
	var path_end := _charge_origin + _charge_dir * _charge_traveled
	_hit_group_on_path(GROUP_ALLIES, half_w, path_end)
	_hit_group_on_path(GROUP_HOSTILES, half_w, path_end)


func _hit_group_on_path(group: StringName, half_w: float, path_end: Vector2) -> void:
	for node in get_tree().get_nodes_in_group(group):
		if node == self or not is_instance_valid(node):
			continue
		if not (node is Combatant):
			continue
		var other := node as Combatant
		if other.is_dead:
			continue
		# Do not charge-hit other bosses (self already skipped).
		if other is Boss:
			continue
		var id := other.get_instance_id()
		if _charge_hit_ids.has(id):
			continue
		if not _is_on_charge_path(other.global_position, path_end, half_w + other.get_collision_radius()):
			continue
		_charge_hit_ids[id] = true
		other.apply_charge_impact(
			_charge_dir,
			behavior.knockback_distance,
			behavior.charge_damage,
			behavior.target_stun_duration
		)


func _is_on_charge_path(point: Vector2, path_end: Vector2, accept_radius: float) -> bool:
	var a := _charge_origin
	var b := path_end
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0001:
		return point.distance_to(a) <= accept_radius
	var t := clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest := a + ab * t
	return point.distance_to(closest) <= accept_radius


func _spawn_minions() -> void:
	if minion_definition == null:
		return
	var count := maxi(1, behavior.summon_count)
	var gc := get_tree().get_first_node_in_group(&"game_controller") if is_inside_tree() else null
	for i in count:
		var angle := TAU * float(i) / float(count) + (_rng.randf() * 0.35 if _rng else 0.0)
		var offset := Vector2(cos(angle), sin(angle)) * behavior.summon_radius
		var at := global_position + offset
		if gc != null and gc.has_method("spawn_hostile_minion"):
			gc.call("spawn_hostile_minion", minion_definition, at)
		else:
			_spawn_minion_local(at)


func _spawn_minion_local(at: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var e := Enemy.new()
	e.name = "BossMinion"
	e.configure(minion_definition, _rng)
	e.global_position = at
	e.aggro_range = 200.0
	parent.add_child(e)


func _show_telegraph() -> void:
	_clear_telegraph()
	_telegraph = Polygon2D.new()
	_telegraph.name = "ChargeTelegraph"
	_telegraph.z_index = -1
	_telegraph.color = Color(0.95, 0.25, 0.15, 0.35)
	add_child(_telegraph)
	_update_telegraph_visual()


func _update_telegraph_visual() -> void:
	if _telegraph == null or not is_instance_valid(_telegraph):
		return
	var length := behavior.charge_distance if behavior else TELEGRAPH_LENGTH_FALLBACK
	var half_w := behavior.charge_path_half_width if behavior else 48.0
	var dir := _charge_dir
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x) * half_w
	# Local space: Boss faces charge along dir from origin at feet.
	var tip := dir * length
	_telegraph.polygon = PackedVector2Array([
		-perp,
		perp,
		tip + perp,
		tip - perp,
	])


func _clear_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _load_behavior(path: String) -> BossBehaviorConfig:
	var res := load(path)
	if res is BossBehaviorConfig:
		return (res as BossBehaviorConfig).duplicate(true) as BossBehaviorConfig
	push_warning("Boss: missing behavior config at %s, using defaults" % path)
	return BossBehaviorConfig.new()


func _load_unit_def(path: String) -> UnitDefinition:
	var res := load(path)
	if res is UnitDefinition:
		return res as UnitDefinition
	push_warning("Boss: missing minion def at %s" % path)
	return null
