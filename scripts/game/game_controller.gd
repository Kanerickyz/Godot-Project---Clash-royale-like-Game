class_name GameController
extends Node2D
## Phase A floor loop: roam, auto army, threat clock, portal → interstitial → next floor.


enum RunPhase { FLOOR, INTERSTITIAL, GAME_OVER }

const CHEST_ENGAGE_RADIUS := 110.0
const PATH_SPAWN_CFG := "res://resources/world/world_spawn.tres"
const PATH_FLOOR_RUN := "res://resources/world/floor_run.tres"
const PATH_THREAT := "res://resources/combat/threat_config.tres"

var gold: int = 0
var game_over: bool = false
var ui_blocking: bool = false
var run_phase: RunPhase = RunPhase.FLOOR
var floor_index: int = 1

## Test/harness: when non-zero, overrides keyboard/joystick move input.
var forced_move_vector: Vector2 = Vector2.ZERO

var _rng := RandomNumberGenerator.new()
var _spawn_cfg: WorldSpawnConfig
var _floor_cfg: FloorRunConfig
var _threat: ThreatClock = ThreatClock.new()
var _map: RoguelikeMapGenerator
var _ground_host: Node2D
var _entities: Node2D
var _captain: SquadMember
var _camera_ctrl: CaptainController
var _camera: Camera2D
var _portal: FloorPortal
var _hud: GameHud
var _followers: Array[SquadMember] = []
var _focused_chest: RoamChest
var _respawn_timer: float = 0.0
var _next_respawn_interval: float = 30.0
var _enemy_serial: int = 0
var _chest_serial: int = 0
var _occupied_spots: Array[Vector2] = []
var _hitstop_active: bool = false
var _hitstop_restore_scale: float = 1.0

var _assemble_cd: float = 0.0
var _assemble_active_left: float = 0.0
var _rage_cd: float = 0.0
var _rage_active_left: float = 0.0
var _portal_confirm_left: float = 0.0
var _portal_holding: bool = false


func _ready() -> void:
	add_to_group(&"game_controller")
	_rng.randomize()
	_spawn_cfg = _load_spawn_config()
	_floor_cfg = _load_floor_run_config()
	_threat.configure(_load_threat_config())
	_build_world_shell()
	_hud = GameHud.new()
	_hud.name = "HUD"
	add_child(_hud)
	_hud.refresh_gold(gold)
	_hud.restart_pressed.connect(_on_restart)
	_hud.assemble_pressed.connect(_on_assemble_pressed)
	_hud.rage_pressed.connect(_on_rage_pressed)
	_hud.portal_confirm_pressed.connect(_on_portal_confirm_pressed)
	_hud.next_floor_pressed.connect(_on_next_floor_pressed)
	_start_floor(true)
	_hud.set_world_hint("WASD/摇杆移动 · Q集合 · R怒意 · 靠近传送门确认进层")


func get_move_vector() -> Vector2:
	if ui_blocking or game_over or run_phase != RunPhase.FLOOR:
		return Vector2.ZERO
	if forced_move_vector != Vector2.ZERO:
		var forced := forced_move_vector
		if forced.length_squared() > 1.0:
			forced = forced.normalized()
		return forced
	var dir := Vector2.ZERO
	if _hud != null:
		dir += _hud.get_joystick_vector()
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	return dir


func get_focused_chest() -> RoamChest:
	return _focused_chest


func get_run_phase() -> RunPhase:
	return run_phase


func get_floor_index() -> int:
	return floor_index


func get_threat_multiplier() -> float:
	return _threat.get_multiplier()


func get_threat_tier_index() -> int:
	return _threat.get_tier_index()


func get_threat_elapsed() -> float:
	return _threat.elapsed


## Test helper: advance threat clock by seconds without waiting real time.
func debug_advance_threat(seconds: float) -> void:
	_threat.tick(maxf(0.0, seconds))
	_refresh_threat_hud()


## Test helper: enter portal as if confirmed near it.
func debug_enter_portal() -> void:
	if run_phase != RunPhase.FLOOR or game_over:
		return
	_enter_interstitial()


## Test helper: from interstitial, go to next floor.
func debug_advance_floor() -> void:
	if run_phase != RunPhase.INTERSTITIAL or game_over:
		return
	_begin_next_floor()


## Brief global hitstop (real-time). Re-entrant calls while active are ignored.
func request_hitstop(duration: float = 0.1) -> void:
	if _hitstop_active or duration <= 0.0 or not is_inside_tree():
		return
	_hitstop_active = true
	_hitstop_restore_scale = Engine.time_scale if Engine.time_scale > 0.0 else 1.0
	Engine.time_scale = 0.0
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(_end_hitstop, CONNECT_ONE_SHOT)


func _end_hitstop() -> void:
	Engine.time_scale = _hitstop_restore_scale if _hitstop_restore_scale > 0.0 else 1.0
	_hitstop_active = false


func _process(delta: float) -> void:
	if run_phase == RunPhase.FLOOR and not game_over:
		_threat.tick(delta)
		_refresh_threat_hud()
		_update_commands(delta)
		_update_command_input()
		_update_portal(delta)
		_update_respawn(delta)
	if _captain == null or not is_instance_valid(_captain):
		return
	if run_phase == RunPhase.FLOOR and not game_over:
		_update_chest_focus()


func _update_command_input() -> void:
	if ui_blocking or game_over or run_phase != RunPhase.FLOOR:
		return
	if Input.is_physical_key_pressed(KEY_Q):
		_try_assemble()
	if Input.is_physical_key_pressed(KEY_R):
		_try_rage()
	if Input.is_physical_key_pressed(KEY_E):
		_try_portal_confirm(true)
	else:
		_portal_holding = false
		_portal_confirm_left = 0.0


func _update_commands(delta: float) -> void:
	_assemble_cd = maxf(0.0, _assemble_cd - delta)
	_rage_cd = maxf(0.0, _rage_cd - delta)
	if _assemble_active_left > 0.0:
		_assemble_active_left = maxf(0.0, _assemble_active_left - delta)
		if _assemble_active_left <= 0.0:
			_clear_assemble()
	if _rage_active_left > 0.0:
		_rage_active_left = maxf(0.0, _rage_active_left - delta)
		if _rage_active_left <= 0.0:
			_clear_rage()
	if _hud != null and _floor_cfg != null:
		_hud.set_command_cooldowns(
			_assemble_cd,
			_floor_cfg.assemble_cooldown,
			_rage_cd,
			_floor_cfg.rage_cooldown
		)


func _on_assemble_pressed() -> void:
	_try_assemble()


func _on_rage_pressed() -> void:
	_try_rage()


func _on_portal_confirm_pressed() -> void:
	_try_portal_confirm(true)


func _try_assemble() -> void:
	if game_over or run_phase != RunPhase.FLOOR or _floor_cfg == null:
		return
	if _assemble_cd > 0.0:
		return
	_assemble_cd = _floor_cfg.assemble_cooldown
	_assemble_active_left = _floor_cfg.assemble_duration
	for member in _followers:
		if member == null or not is_instance_valid(member) or member.is_dead:
			continue
		member.set_assemble(true, _floor_cfg.assemble_follow_distance)


func _clear_assemble() -> void:
	for member in _followers:
		if member == null or not is_instance_valid(member):
			continue
		member.set_assemble(false)


func _try_rage() -> void:
	if game_over or run_phase != RunPhase.FLOOR or _floor_cfg == null:
		return
	if _rage_cd > 0.0:
		return
	_rage_cd = _floor_cfg.rage_cooldown
	_rage_active_left = _floor_cfg.rage_duration
	_apply_rage(true)


func _apply_rage(active: bool) -> void:
	if _floor_cfg == null:
		return
	var dmg := _floor_cfg.rage_damage_mult if active else 1.0
	var spd := _floor_cfg.rage_speed_mult if active else 1.0
	for member in _followers:
		if member == null or not is_instance_valid(member) or member.is_dead:
			continue
		member.damage_multiplier = dmg
		member.speed_multiplier = spd
	# Commander: move speed only (no basic attack in Phase A).
	if _captain != null and is_instance_valid(_captain) and not _captain.is_dead:
		_captain.speed_multiplier = spd
		_captain.damage_multiplier = 1.0


func _clear_rage() -> void:
	_apply_rage(false)


func _update_portal(delta: float) -> void:
	if _portal == null or _captain == null or not is_instance_valid(_captain):
		return
	var radius := _floor_cfg.portal_interact_radius if _floor_cfg != null else 90.0
	var near := _captain.global_position.distance_to(_portal.global_position) <= radius
	_portal.set_captain_near(near)
	if _hud != null:
		_hud.set_portal_prompt_visible(near)
	if not near:
		_portal_holding = false
		_portal_confirm_left = 0.0
		return
	if _portal_holding:
		_portal_confirm_left -= delta
		if _portal_confirm_left <= 0.0:
			_portal_holding = false
			_enter_interstitial()


func _try_portal_confirm(from_input: bool) -> void:
	if not from_input or game_over or run_phase != RunPhase.FLOOR:
		return
	if _portal == null or not _portal.is_captain_near():
		return
	var need := _floor_cfg.portal_confirm_sec if _floor_cfg != null else 0.35
	if need <= 0.0:
		_enter_interstitial()
		return
	if not _portal_holding:
		_portal_holding = true
		_portal_confirm_left = need


func _enter_interstitial() -> void:
	if run_phase != RunPhase.FLOOR or game_over:
		return
	run_phase = RunPhase.INTERSTITIAL
	ui_blocking = true
	_set_combat_enabled(false)
	_clear_assemble()
	_clear_rage()
	_assemble_active_left = 0.0
	_rage_active_left = 0.0
	_portal_holding = false
	if _hud != null:
		_hud.show_interstitial(floor_index)


func _on_next_floor_pressed() -> void:
	_begin_next_floor()


func _begin_next_floor() -> void:
	if run_phase != RunPhase.INTERSTITIAL or game_over:
		return
	floor_index += 1
	if _hud != null:
		_hud.hide_interstitial()
	_start_floor(false)


func _start_floor(is_run_start: bool) -> void:
	run_phase = RunPhase.FLOOR
	game_over = false
	ui_blocking = false
	_threat.reset()
	_respawn_timer = 0.0
	_assemble_cd = 0.0
	_rage_cd = 0.0
	_assemble_active_left = 0.0
	_rage_active_left = 0.0
	_portal_confirm_left = 0.0
	_portal_holding = false
	_occupied_spots.clear()
	_clear_floor_entities(is_run_start)
	_generate_map()
	if is_run_start:
		_spawn_captain()
		_spawn_starting_followers()
	else:
		_reposition_army_to_safe()
	_spawn_enemies_initial()
	_spawn_chests_initial()
	_spawn_portal()
	_roll_next_respawn_interval()
	_set_combat_enabled(true)
	_refresh_threat_hud()
	if _hud != null:
		_hud.refresh_floor(floor_index)
		_hud.hide_interstitial()
		_hud.set_portal_prompt_visible(false)


func _clear_floor_entities(clear_army: bool) -> void:
	if _entities == null:
		return
	var keep: Array[Node] = []
	if not clear_army:
		if _captain != null and is_instance_valid(_captain):
			keep.append(_captain)
		for f in _followers:
			if f != null and is_instance_valid(f) and not f.is_dead:
				keep.append(f)
	# Prune dead followers from roster.
	var alive_followers: Array[SquadMember] = []
	for f in _followers:
		if f != null and is_instance_valid(f) and not f.is_dead:
			alive_followers.append(f)
	_followers = alive_followers
	var children := _entities.get_children()
	for child in children:
		if child in keep:
			continue
		_entities.remove_child(child)
		child.free()
	_portal = null
	_focused_chest = null
	if clear_army:
		_captain = null
		_followers.clear()


func _build_world_shell() -> void:
	_ground_host = Node2D.new()
	_ground_host.name = "GroundHost"
	_ground_host.z_index = -10
	add_child(_ground_host)

	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.y_sort_enabled = true
	add_child(_entities)

	var zoom := _spawn_cfg.camera_zoom if _spawn_cfg != null else 1.5
	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera_ctrl = CaptainController.new()
	_camera_ctrl.name = "CaptainController"
	_camera_ctrl.camera = _camera
	add_child(_camera_ctrl)


func _generate_map() -> void:
	# Wipe previous ground visuals.
	if _ground_host != null:
		for child in _ground_host.get_children():
			_ground_host.remove_child(child)
			child.free()
	_map = RoguelikeMapGenerator.new()
	_map.generate(_spawn_cfg, _rng)
	_map.build_visuals(_ground_host, _rng)
	if _camera != null:
		_camera.limit_left = 0
		_camera.limit_top = 0
		_camera.limit_right = int(_map.map_size.x)
		_camera.limit_bottom = int(_map.map_size.y)


func _spawn_captain() -> void:
	var path := _floor_cfg.captain_path if _floor_cfg != null else "res://resources/units/captain.tres"
	var def := _load_unit(path)
	_captain = SquadMember.new()
	_captain.name = "Captain"
	_captain.configure_as_captain(def)
	var spawn_pos := _map.safe_room.center() if _map.safe_room != null else Vector2(420, 560)
	_captain.global_position = spawn_pos
	_occupied_spots.append(spawn_pos)
	_captain.died.connect(_on_captain_died)
	_entities.add_child(_captain)
	_camera_ctrl.bind_captain(_captain)


func _spawn_starting_followers() -> void:
	if _floor_cfg == null:
		return
	for path in _floor_cfg.starting_follower_paths:
		var def := _load_unit(path)
		recruit_unit(def)


func _reposition_army_to_safe() -> void:
	var spawn_pos := _map.safe_room.center() if _map.safe_room != null else Vector2(420, 560)
	if _captain != null and is_instance_valid(_captain):
		_captain.global_position = spawn_pos
		_captain.velocity = Vector2.ZERO
		_occupied_spots.append(spawn_pos)
		_camera_ctrl.bind_captain(_captain)
	var i := 0
	for member in _followers:
		if member == null or not is_instance_valid(member):
			continue
		var angle := float(i + 1) * TAU / 5.0
		member.global_position = spawn_pos + Vector2(cos(angle), sin(angle)) * 42.0
		member.follow_target = _captain
		member.follow_index = i
		member.velocity = Vector2.ZERO
		member.set_assemble(false)
		member.damage_multiplier = 1.0
		member.speed_multiplier = 1.0
		i += 1


func _spawn_portal() -> void:
	_portal = FloorPortal.new()
	_portal.name = "FloorPortal"
	var radius := _floor_cfg.portal_interact_radius if _floor_cfg != null else 90.0
	_portal.configure(radius)
	var portal_pos := Vector2(1350, 950)
	if _map != null and _map.boss_room != null:
		portal_pos = _map.boss_room.center()
	_portal.global_position = portal_pos
	_occupied_spots.append(portal_pos)
	_entities.add_child(_portal)


func _spawn_enemies_initial() -> void:
	var count := _rng.randi_range(_spawn_cfg.start_enemy_min, _spawn_cfg.start_enemy_max)
	_spawn_enemy_batch(count, false)


func _spawn_chests_initial() -> void:
	# Keep smash skeleton; fewer chests so portal loop stays readable.
	var lo := mini(1, _spawn_cfg.start_chest_min)
	var hi := mini(2, _spawn_cfg.start_chest_max)
	if hi < lo:
		hi = lo
	var count := _rng.randi_range(lo, hi)
	_spawn_chest_batch(count, false)


func _update_chest_focus() -> void:
	_focused_chest = null
	if ui_blocking or game_over or not is_inside_tree():
		return
	var best_dist := CHEST_ENGAGE_RADIUS
	for node in get_tree().get_nodes_in_group(&"chests"):
		if node == null or not is_instance_valid(node):
			continue
		if node.get("is_dead") == true:
			continue
		var chest := node as RoamChest
		if chest == null:
			continue
		var dist := _captain.global_position.distance_to(chest.global_position)
		if dist <= best_dist:
			best_dist = dist
			_focused_chest = chest


func _update_respawn(delta: float) -> void:
	if game_over or ui_blocking or run_phase != RunPhase.FLOOR or _spawn_cfg == null or _map == null:
		return
	_respawn_timer += delta
	if _respawn_timer < _next_respawn_interval:
		return
	_respawn_timer = 0.0
	_roll_next_respawn_interval()
	_spawn_respawn_squad()


func _roll_next_respawn_interval() -> void:
	if _spawn_cfg == null:
		_next_respawn_interval = 30.0
		return
	# Base interval from world spawn mid-range, scaled by threat (higher threat → shorter).
	var base := lerpf(_spawn_cfg.respawn_interval_min, _spawn_cfg.respawn_interval_max, 0.5)
	var divisor := _threat.get_spawn_interval_divisor()
	var floor_iv := _spawn_cfg.respawn_interval_floor
	_next_respawn_interval = maxf(floor_iv, base / divisor)


func _roll_respawn_squad_size() -> int:
	if _spawn_cfg == null:
		return 2
	# Threat progress drives squad size instead of match-elapsed ramp.
	var progress := _threat.get_progress()
	var lo_f := lerpf(
		float(_spawn_cfg.respawn_squad_min_start),
		float(_spawn_cfg.respawn_squad_min_end),
		progress
	)
	var hi_f := lerpf(
		float(_spawn_cfg.respawn_squad_max_start),
		float(_spawn_cfg.respawn_squad_max_end),
		progress
	)
	var lo := mini(int(round(lo_f)), int(round(hi_f)))
	var hi := maxi(int(round(lo_f)), int(round(hi_f)))
	lo = maxi(1, lo)
	hi = maxi(lo, hi)
	return _rng.randi_range(lo, hi)


func _spawn_respawn_squad() -> void:
	if _entities == null or _map == null or _spawn_cfg == null:
		return
	var want := _roll_respawn_squad_size()
	var alive := _count_alive_enemies()
	var to_spawn := mini(want, maxi(0, _spawn_cfg.max_alive_enemies - alive))
	if to_spawn <= 0:
		return
	var avoid := _collect_live_avoid_positions()
	var center := _map.sample_spawn_point(
		_rng,
		avoid,
		_spawn_cfg.spawn_min_separation,
		_spawn_cfg.spawn_edge_margin,
		true,
		true
	)
	var spread := maxf(24.0, _spawn_cfg.respawn_squad_spread_radius)
	for i in to_spawn:
		var pos := center
		if to_spawn > 1:
			var angle := TAU * float(i) / float(to_spawn) + _rng.randf() * 0.4
			var radius := spread * (0.35 + _rng.randf() * 0.65)
			pos = center + Vector2(cos(angle), sin(angle)) * radius
			pos = _clamp_spawn_to_map(pos)
		_spawn_one_enemy(pos)
		avoid.append(pos)
		_occupied_spots.append(pos)


func _clamp_spawn_to_map(pos: Vector2) -> Vector2:
	if _map == null:
		return pos
	var margin := _spawn_cfg.spawn_edge_margin if _spawn_cfg != null else 40.0
	var size := _map.map_size
	return Vector2(
		clampf(pos.x, margin, maxf(margin, size.x - margin)),
		clampf(pos.y, margin, maxf(margin, size.y - margin))
	)


func _spawn_enemy_batch(want: int, respect_cap: bool) -> void:
	if want <= 0 or _entities == null or _map == null:
		return
	var alive := _count_alive_enemies()
	var to_spawn := want
	if respect_cap:
		to_spawn = mini(want, maxi(0, _spawn_cfg.max_alive_enemies - alive))
	if to_spawn <= 0:
		return
	var avoid := _collect_live_avoid_positions()
	for _i in to_spawn:
		var pos := _map.sample_spawn_point(
			_rng,
			avoid,
			_spawn_cfg.spawn_min_separation,
			_spawn_cfg.spawn_edge_margin,
			true,
			true
		)
		_spawn_one_enemy(pos)
		avoid.append(pos)
		_occupied_spots.append(pos)


func _spawn_one_enemy(at: Vector2) -> Enemy:
	var path := _floor_cfg.enemy_path if _floor_cfg != null else "res://resources/units/enemy_grunt.tres"
	var def := _scale_enemy_def(_load_unit(path))
	var e := Enemy.new()
	e.name = "Enemy_%d" % _enemy_serial
	_enemy_serial += 1
	e.configure(def, _rng)
	e.global_position = at
	e.gold_dropped.connect(_on_gold_dropped)
	_entities.add_child(e)
	return e


func _scale_enemy_def(def: UnitDefinition) -> UnitDefinition:
	if def == null:
		return def
	var scaled := def.duplicate(true) as UnitDefinition
	var scale := _threat.get_enemy_stat_scale()
	scaled.max_hp = maxi(1, int(ceil(float(scaled.max_hp) * scale)))
	scaled.attack_damage = maxi(1, int(round(float(scaled.attack_damage) * scale)))
	return scaled


func _spawn_chest_batch(want: int, respect_cap: bool) -> void:
	if want <= 0 or _entities == null or _map == null:
		return
	var alive := _count_alive_chests()
	var to_spawn := want
	if respect_cap:
		to_spawn = mini(want, maxi(0, _spawn_cfg.max_alive_chests - alive))
	if to_spawn <= 0:
		return
	var avoid := _collect_live_avoid_positions()
	for _i in to_spawn:
		var pos := _map.sample_spawn_point(
			_rng,
			avoid,
			_spawn_cfg.spawn_min_separation,
			_spawn_cfg.spawn_edge_margin,
			true,
			true
		)
		_spawn_one_chest(pos)
		avoid.append(pos)
		_occupied_spots.append(pos)


func _collect_live_avoid_positions() -> Array[Vector2]:
	var avoid: Array[Vector2] = []
	if _captain != null and is_instance_valid(_captain):
		avoid.append(_captain.global_position)
	if _portal != null and is_instance_valid(_portal):
		avoid.append(_portal.global_position)
	if not is_inside_tree():
		return avoid
	for node in get_tree().get_nodes_in_group(Combatant.GROUP_HOSTILES):
		if node == null or not is_instance_valid(node):
			continue
		if node.get("is_dead") == true:
			continue
		if node is Node2D:
			avoid.append((node as Node2D).global_position)
	for node in get_tree().get_nodes_in_group(&"chests"):
		if node == null or not is_instance_valid(node):
			continue
		if node.get("is_dead") == true:
			continue
		if node is Node2D:
			avoid.append((node as Node2D).global_position)
	return avoid


func _spawn_one_chest(at: Vector2) -> RoamChest:
	var chest := RoamChest.new()
	chest.name = "Chest_%d" % _chest_serial
	_chest_serial += 1
	# Empty choices: smash still works; no recruit three-pick contract.
	var choices: Array[UnitDefinition] = []
	chest.configure(60, choices)
	chest.global_position = at
	chest.smashed.connect(_on_chest_smashed)
	_entities.add_child(chest)
	return chest


## Legacy Boss summon hook kept so Boss script (unused in Phase A) still compiles against API.
func spawn_hostile_minion(def: UnitDefinition, at: Vector2) -> Enemy:
	if def == null or _entities == null:
		return null
	var e := Enemy.new()
	e.name = "BossMinion_%d" % _entities.get_child_count()
	e.configure(def, _rng)
	e.global_position = at
	e.aggro_range = 200.0
	e.gold_dropped.connect(_on_gold_dropped)
	_entities.add_child(e)
	return e


func recruit_unit(def: UnitDefinition) -> void:
	if def == null or _captain == null:
		return
	var member := SquadMember.new()
	var index := _followers.size()
	member.name = "Ally_%d" % index
	member.configure_as_follower(def, _captain, index)
	member.global_position = _captain.global_position + Vector2(30, 30)
	member.combat_enabled = not ui_blocking and not game_over and run_phase == RunPhase.FLOOR
	_entities.add_child(member)
	_followers.append(member)


func _count_alive_enemies() -> int:
	if not is_inside_tree():
		return 0
	var n := 0
	for node in get_tree().get_nodes_in_group(Combatant.GROUP_HOSTILES):
		if node == null or not is_instance_valid(node):
			continue
		if node.get("is_dead") == true:
			continue
		n += 1
	return n


func _count_alive_chests() -> int:
	if not is_inside_tree():
		return 0
	var n := 0
	for node in get_tree().get_nodes_in_group(&"chests"):
		if node == null or not is_instance_valid(node):
			continue
		if node.get("is_dead") == true:
			continue
		n += 1
	return n


func _on_chest_smashed(chest: RoamChest, placeholder_gold: int) -> void:
	if game_over or placeholder_gold <= 0:
		return
	# Placeholder reward — not shop-driving economy.
	var at := _captain.global_position if _captain != null else Vector2.ZERO
	if chest != null and is_instance_valid(chest):
		at = chest.global_position
	_on_gold_dropped(placeholder_gold, at)


func _on_gold_dropped(amount: int, at: Vector2) -> void:
	if game_over or amount <= 0:
		return
	var drop := GoldPickup.new()
	drop.name = "GoldPickup"
	_entities.add_child(drop)
	drop.global_position = at
	drop.configure(amount)
	drop.collected.connect(_on_gold_collected)


func _on_gold_collected(amount: int) -> void:
	if game_over:
		return
	gold += amount
	if _hud != null:
		_hud.refresh_gold(gold)


func _on_captain_died(_who: Combatant) -> void:
	if game_over:
		return
	game_over = true
	run_phase = RunPhase.GAME_OVER
	ui_blocking = true
	_set_combat_enabled(false)
	if _hud != null:
		_hud.show_end(false)


func _on_restart() -> void:
	get_tree().reload_current_scene()


func _refresh_threat_hud() -> void:
	if _hud == null:
		return
	_hud.refresh_threat(_threat.get_multiplier(), _threat.get_tier_label(), _threat.get_tier_index())


func _set_combat_enabled(enabled: bool) -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(Combatant.GROUP_ATTACKABLE):
		if node is Combatant:
			(node as Combatant).combat_enabled = enabled
			if not enabled:
				(node as Combatant).velocity = Vector2.ZERO


func _load_spawn_config() -> WorldSpawnConfig:
	var res := load(PATH_SPAWN_CFG)
	if res is WorldSpawnConfig:
		return (res as WorldSpawnConfig).duplicate(true) as WorldSpawnConfig
	push_error("GameController: failed to load WorldSpawnConfig %s" % PATH_SPAWN_CFG)
	return WorldSpawnConfig.new()


func _load_floor_run_config() -> FloorRunConfig:
	var res := load(PATH_FLOOR_RUN)
	if res is FloorRunConfig:
		return (res as FloorRunConfig).duplicate(true) as FloorRunConfig
	push_error("GameController: failed to load FloorRunConfig %s" % PATH_FLOOR_RUN)
	return FloorRunConfig.new()


func _load_threat_config() -> ThreatConfig:
	var res := load(PATH_THREAT)
	if res is ThreatConfig:
		return (res as ThreatConfig).duplicate(true) as ThreatConfig
	push_error("GameController: failed to load ThreatConfig %s" % PATH_THREAT)
	return ThreatConfig.new()


func _load_unit(path: String) -> UnitDefinition:
	var res := load(path)
	if res == null:
		push_error("GameController: failed to load unit %s" % path)
		return _make_fallback_unit(path.get_file())
	var def := res as UnitDefinition
	if def == null:
		push_error("GameController: not UnitDefinition %s" % path)
		return _make_fallback_unit(path.get_file())
	return def


func _make_fallback_unit(name_hint: String) -> UnitDefinition:
	var def := UnitDefinition.new()
	def.id = StringName(name_hint)
	def.display_name = name_hint
	def.max_hp = 50
	def.attack_damage = 5
	def.attack_interval = 0.8
	def.attack_range = 70.0
	def.move_speed = 140.0
	return def
