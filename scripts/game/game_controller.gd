class_name GameController
extends Node2D
## Squad roam prototype: procedural map, economy, recruit, win/lose, timed respawns.


const START_GOLD := 15
const SHOP_IDLE_OPEN_SEC := 3.0
const MOVE_IDLE_SPEED := 12.0
const CHEST_ENGAGE_RADIUS := 110.0

const PATH_SPAWN_CFG := "res://resources/world/world_spawn.tres"
const PATH_CAPTAIN := "res://resources/units/captain.tres"
const PATH_ALLY_SPEAR := "res://resources/units/ally_spear.tres"
const PATH_ALLY_ARCHER := "res://resources/units/ally_archer.tres"
const PATH_ALLY_SHIELD := "res://resources/units/ally_shield.tres"
const PATH_ENEMY := "res://resources/units/enemy_grunt.tres"
const PATH_BOSS := "res://resources/units/boss.tres"
const PATH_BOSS_BEHAVIOR := "res://resources/combat/boss_summon_charge.tres"
const PATH_BOSS_MINION := "res://resources/units/boss_minion.tres"
const PATH_CHEST_A := "res://resources/units/ally_hunter.tres"
const PATH_CHEST_B := "res://resources/units/ally_axe.tres"
const PATH_CHEST_C := "res://resources/units/ally_musket.tres"

var gold: int = START_GOLD
var game_over: bool = false
var ui_blocking: bool = false

var _rng := RandomNumberGenerator.new()
var _spawn_cfg: WorldSpawnConfig
var _map: RoguelikeMapGenerator
var _entities: Node2D
var _captain: SquadMember
var _camera_ctrl: CaptainController
var _shop: RoamShop
var _hud: GameHud
var _followers: Array[SquadMember] = []
var _pending_chest_choices: Array = []
var _shop_idle_sec: float = 0.0
var _focused_chest: RoamChest
var _respawn_timer: float = 0.0
var _next_respawn_interval: float = 30.0
var _match_elapsed: float = 0.0
var _enemy_serial: int = 0
var _chest_serial: int = 0
var _occupied_spots: Array[Vector2] = []
var _hitstop_active: bool = false
var _hitstop_restore_scale: float = 1.0


func _ready() -> void:
	add_to_group(&"game_controller")
	_rng.randomize()
	_spawn_cfg = _load_spawn_config()
	_build_world()
	_hud = GameHud.new()
	_hud.name = "HUD"
	add_child(_hud)
	_hud.refresh_gold(gold)
	_hud.shop_buy_pressed.connect(_on_shop_buy)
	_hud.shop_refresh_pressed.connect(_on_shop_refresh)
	_hud.shop_closed.connect(_on_shop_closed)
	_hud.chest_pick_pressed.connect(_on_chest_pick)
	_hud.restart_pressed.connect(_on_restart)
	_spawn_captain()
	_spawn_shop()
	_spawn_enemies_initial()
	_spawn_chests_initial()
	_spawn_boss()
	_roll_next_respawn_interval()


func get_move_vector() -> Vector2:
	if ui_blocking or game_over:
		return Vector2.ZERO
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
	if not game_over:
		_match_elapsed += delta
	if _captain == null or not is_instance_valid(_captain):
		return
	_update_chest_focus()
	if _shop != null:
		var near := _shop.is_captain_near(_captain)
		_shop.set_captain_in_range(near)
		_update_shop_idle_open(delta, near)
	_update_respawn(delta)


func _update_shop_idle_open(delta: float, near: bool) -> void:
	if ui_blocking or game_over or not near:
		_shop_idle_sec = 0.0
		if _shop != null:
			_shop.set_idle_progress(0.0)
		return
	var moving := get_move_vector().length() > 0.15
	if not moving and _captain.velocity.length() <= MOVE_IDLE_SPEED:
		_shop_idle_sec += delta
		_shop.set_idle_progress(_shop_idle_sec / SHOP_IDLE_OPEN_SEC)
		if _shop_idle_sec >= SHOP_IDLE_OPEN_SEC:
			_shop_idle_sec = 0.0
			_shop.set_idle_progress(0.0)
			_open_shop()
	else:
		_shop_idle_sec = 0.0
		_shop.set_idle_progress(0.0)


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
	if game_over or ui_blocking or _spawn_cfg == null or _map == null:
		return
	_respawn_timer += delta
	if _respawn_timer < _next_respawn_interval:
		return
	_respawn_timer = 0.0
	_roll_next_respawn_interval()
	_spawn_respawn_squad()
	if _rng.randf() <= _spawn_cfg.respawn_chest_chance:
		_spawn_chest_batch(_spawn_cfg.respawn_chest_count, true)


func _match_progress() -> float:
	if _spawn_cfg == null:
		return 0.0
	var ramp := maxf(0.001, _spawn_cfg.respawn_ramp_duration)
	return clampf(_match_elapsed / ramp, 0.0, 1.0)


func _roll_next_respawn_interval() -> void:
	if _spawn_cfg == null:
		_next_respawn_interval = 30.0
		return
	var progress := _match_progress()
	var floor_iv := _spawn_cfg.respawn_interval_floor
	var lo := lerpf(_spawn_cfg.respawn_interval_min, floor_iv, progress)
	var hi := lerpf(_spawn_cfg.respawn_interval_max, floor_iv, progress)
	if hi < lo:
		var tmp := lo
		lo = hi
		hi = tmp
	_next_respawn_interval = _rng.randf_range(lo, hi)


func _roll_respawn_squad_size() -> int:
	if _spawn_cfg == null:
		return 2
	var progress := _match_progress()
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


## One clustered squad near a shared room center; respects max_alive_enemies.
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
		false
	)
	var spread := maxf(24.0, _spawn_cfg.respawn_squad_spread_radius)
	var def := _load_unit(PATH_ENEMY)
	for i in to_spawn:
		var pos := center
		if to_spawn > 1:
			var angle := TAU * float(i) / float(to_spawn) + _rng.randf() * 0.4
			var radius := spread * (0.35 + _rng.randf() * 0.65)
			pos = center + Vector2(cos(angle), sin(angle)) * radius
			pos = _clamp_spawn_to_map(pos)
		_spawn_one_enemy(def, pos)
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


func _build_world() -> void:
	_map = RoguelikeMapGenerator.new()
	_map.generate(_spawn_cfg, _rng)

	var ground_host := Node2D.new()
	ground_host.name = "GroundHost"
	ground_host.z_index = -10
	add_child(ground_host)
	_map.build_visuals(ground_host)

	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.y_sort_enabled = true
	add_child(_entities)

	var zoom := _spawn_cfg.camera_zoom if _spawn_cfg != null else 1.5
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.zoom = Vector2(zoom, zoom)
	cam.position_smoothing_enabled = false
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(_map.map_size.x)
	cam.limit_bottom = int(_map.map_size.y)
	add_child(cam)
	_camera_ctrl = CaptainController.new()
	_camera_ctrl.name = "CaptainController"
	_camera_ctrl.camera = cam
	add_child(_camera_ctrl)


func _spawn_captain() -> void:
	var def := _load_unit(PATH_CAPTAIN)
	_captain = SquadMember.new()
	_captain.name = "Captain"
	_captain.configure_as_captain(def)
	var spawn_pos := _map.safe_room.center() if _map.safe_room != null else Vector2(420, 560)
	_captain.global_position = spawn_pos
	_occupied_spots.append(spawn_pos)
	_captain.died.connect(_on_captain_died)
	_entities.add_child(_captain)
	_camera_ctrl.bind_captain(_captain)
	_set_combat_enabled(true)


func _spawn_shop() -> void:
	_shop = RoamShop.new()
	_shop.name = "Shop"
	var shop_pos := Vector2(220, 220)
	if _map != null and _map.safe_room != null:
		shop_pos = _map.sample_in_room(_map.safe_room, _rng, _spawn_cfg.spawn_edge_margin)
		# Nudge away from captain if too close.
		if _captain != null and shop_pos.distance_to(_captain.global_position) < 70.0:
			shop_pos = _map.safe_room.center() + Vector2(-90, -70)
	_shop.global_position = shop_pos
	_occupied_spots.append(shop_pos)
	var offers: Array[Dictionary] = [
		{"unit": _load_unit(PATH_ALLY_SPEAR), "price": 15},
		{"unit": _load_unit(PATH_ALLY_ARCHER), "price": 25},
		{"unit": _load_unit(PATH_ALLY_SHIELD), "price": 40},
	]
	_shop.configure(offers)
	_entities.add_child(_shop)


func _spawn_enemies_initial() -> void:
	var count := _rng.randi_range(_spawn_cfg.start_enemy_min, _spawn_cfg.start_enemy_max)
	_spawn_enemy_batch(count, false)


func _spawn_chests_initial() -> void:
	var count := _rng.randi_range(_spawn_cfg.start_chest_min, _spawn_cfg.start_chest_max)
	_spawn_chest_batch(count, false)


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
	var def := _load_unit(PATH_ENEMY)
	for _i in to_spawn:
		var pos := _map.sample_spawn_point(
			_rng,
			avoid,
			_spawn_cfg.spawn_min_separation,
			_spawn_cfg.spawn_edge_margin,
			true,
			false
		)
		_spawn_one_enemy(def, pos)
		avoid.append(pos)
		_occupied_spots.append(pos)


func _spawn_one_enemy(def: UnitDefinition, at: Vector2) -> Enemy:
	var e := Enemy.new()
	e.name = "Enemy_%d" % _enemy_serial
	_enemy_serial += 1
	e.configure(def, _rng)
	e.global_position = at
	e.gold_dropped.connect(_on_gold_dropped)
	_entities.add_child(e)
	return e


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
	if _shop != null and is_instance_valid(_shop):
		avoid.append(_shop.global_position)
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
	var choices: Array[UnitDefinition] = [
		_load_unit(PATH_CHEST_A),
		_load_unit(PATH_CHEST_B),
		_load_unit(PATH_CHEST_C),
	]
	if _rng.randf() > 0.5:
		choices.reverse()
	chest.configure(60, choices)
	chest.global_position = at
	chest.opened.connect(_on_chest_opened)
	_entities.add_child(chest)
	return chest


func _spawn_boss() -> void:
	var def := _load_unit(PATH_BOSS)
	var boss := Boss.new()
	boss.name = "Boss"
	boss.configure(def, _rng)
	var behavior := _load_boss_behavior(PATH_BOSS_BEHAVIOR)
	var minion_def := _load_unit(PATH_BOSS_MINION)
	boss.configure_behavior(behavior, minion_def)
	var boss_pos := Vector2(1350, 950)
	if _map != null and _map.boss_room != null:
		boss_pos = _map.sample_in_room(_map.boss_room, _rng, _spawn_cfg.spawn_edge_margin * 0.6)
	boss.global_position = boss_pos
	_occupied_spots.append(boss_pos)
	if behavior != null:
		boss.aggro_range = behavior.charge_distance
	boss.boss_defeated.connect(_on_boss_defeated)
	_entities.add_child(boss)
	var marker := Label.new()
	marker.text = "BOSS"
	marker.position = Vector2(-28, -78)
	marker.add_theme_font_size_override("font_size", 14)
	boss.add_child(marker)


## Spawns a hostile minion under Entities (Boss summons). Connects gold drop.
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
	member.combat_enabled = not ui_blocking and not game_over
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


func _open_shop() -> void:
	if ui_blocking or game_over or _shop == null:
		return
	ui_blocking = true
	_set_combat_enabled(false)
	_hud.show_shop(_shop.shelf, gold, _shop.refresh_cost)


func _on_shop_buy(slot_index: int) -> void:
	if _shop == null or slot_index < 0 or slot_index >= _shop.shelf.size():
		return
	var slot: Dictionary = _shop.shelf[slot_index]
	if bool(slot.get("sold_out", false)):
		return
	var price: int = int(slot.get("price", 0))
	var unit: UnitDefinition = slot.get("unit") as UnitDefinition
	if unit == null or gold < price:
		return
	gold -= price
	_shop.mark_sold(slot_index)
	recruit_unit(unit)
	if _shop.all_sold():
		_shop.refresh_shelf(_rng)
	_hud.refresh_gold(gold)
	_hud.show_shop(_shop.shelf, gold, _shop.refresh_cost)


func _on_shop_refresh() -> void:
	if _shop == null or game_over:
		return
	var cost := _shop.refresh_cost
	if gold < cost:
		return
	gold -= cost
	_shop.refresh_shelf(_rng)
	_hud.refresh_gold(gold)
	_hud.show_shop(_shop.shelf, gold, cost)


func _on_shop_closed() -> void:
	ui_blocking = false
	_set_combat_enabled(not game_over)


func _on_chest_opened(_chest: RoamChest, choices: Array) -> void:
	if game_over:
		return
	_pending_chest_choices = choices
	ui_blocking = true
	_set_combat_enabled(false)
	_hud.show_chest_pick(choices)


func _on_chest_pick(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= _pending_chest_choices.size():
		return
	var unit := _pending_chest_choices[choice_index] as UnitDefinition
	recruit_unit(unit)
	_pending_chest_choices.clear()
	_hud.hide_chest_pick()
	ui_blocking = false
	_set_combat_enabled(not game_over)


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
	_hud.refresh_gold(gold)


func _on_boss_defeated(_boss: Boss) -> void:
	if game_over:
		return
	game_over = true
	ui_blocking = true
	_set_combat_enabled(false)
	_hud.show_end(true)


func _on_captain_died(_who: Combatant) -> void:
	if game_over:
		return
	game_over = true
	ui_blocking = true
	_set_combat_enabled(false)
	_hud.show_end(false)


func _on_restart() -> void:
	get_tree().reload_current_scene()


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


func _load_boss_behavior(path: String) -> BossBehaviorConfig:
	var res := load(path)
	if res is BossBehaviorConfig:
		return (res as BossBehaviorConfig).duplicate(true) as BossBehaviorConfig
	push_error("GameController: failed to load BossBehaviorConfig %s" % path)
	return BossBehaviorConfig.new()


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
