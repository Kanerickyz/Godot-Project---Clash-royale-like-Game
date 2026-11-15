class_name GameController
extends Node2D
## Phase E: corpus + relics shop + floor loot (chest/shrine/elite); builds on A–D.


enum RunPhase { FLOOR, INTERSTITIAL, GAME_OVER }

const CHEST_ENGAGE_RADIUS := 110.0
const PATH_SPAWN_CFG := "res://resources/world/world_spawn.tres"
const PATH_FLOOR_RUN := "res://resources/world/floor_run.tres"
const PATH_THREAT := "res://resources/combat/threat_config.tres"
const PATH_SHOP_ECONOMY := "res://resources/world/shop_economy.tres"
const PATH_MERGE_RANK := "res://resources/combat/merge_rank.tres"
const PATH_CORPUS_RELICS := "res://resources/world/corpus_relics.tres"
const PATH_OATH_IRON_WALL := "res://resources/oaths/oath_iron_wall.tres"
const PATH_OATH_MYRIAD_BONES := "res://resources/oaths/oath_myriad_bones.tres"
const PATH_OATH_TAUT_BOW := "res://resources/oaths/oath_taut_bow.tres"

var gold: int = 0
var corpus: int = 0
var game_over: bool = false
var ui_blocking: bool = false
var run_phase: RunPhase = RunPhase.FLOOR
var floor_index: int = 1

## Test/harness: when non-zero, overrides keyboard/joystick move input.
var forced_move_vector: Vector2 = Vector2.ZERO

var _rng := RandomNumberGenerator.new()
var _spawn_cfg: WorldSpawnConfig
var _floor_cfg: FloorRunConfig
var _shop_cfg: ShopEconomyConfig
var _merge_cfg: MergeRankConfig
var _corpus_cfg: CorpusRelicsConfig
var _shop: ShopService = ShopService.new()
var _relics: RelicService = RelicService.new()
var _threat: ThreatClock = ThreatClock.new()
var _revive_queue: ReviveQueue = ReviveQueue.new()
var _oath_service: OathService = OathService.new()
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
var _focused_shrine: FloorShrine
var _respawn_timer: float = 0.0
var _next_respawn_interval: float = 30.0
var _enemy_serial: int = 0
var _chest_serial: int = 0
var _shrine_serial: int = 0
var _occupied_spots: Array[Vector2] = []
var _hitstop_active: bool = false
var _hitstop_restore_scale: float = 1.0
var _shop_status: String = ""
var _relic_status: String = ""
var _last_merge_log: String = ""
var _merge_rebuild_guard: bool = false

var _assemble_cd: float = 0.0
var _assemble_active_left: float = 0.0
var _rage_cd: float = 0.0
var _rage_active_left: float = 0.0
var _portal_confirm_left: float = 0.0
var _portal_holding: bool = false
var _shrine_buff_left: float = 0.0
var _shrine_choice_open: bool = false


func _ready() -> void:
	add_to_group(&"game_controller")
	_rng.randomize()
	_spawn_cfg = _load_spawn_config()
	_floor_cfg = _load_floor_run_config()
	_shop_cfg = _load_shop_economy()
	_merge_cfg = _load_merge_rank_config()
	_threat.configure(_load_threat_config())
	_init_oath_service()
	_init_shop_service()
	_init_relic_service()
	gold = _shop_cfg.starting_ducats if _shop_cfg != null else 20
	corpus = _corpus_cfg.starting_corpus if _corpus_cfg != null else 0
	_build_world_shell()
	_hud = GameHud.new()
	_hud.name = "HUD"
	add_child(_hud)
	_hud.refresh_gold(gold)
	_hud.refresh_corpus(corpus)
	_hud.restart_pressed.connect(_on_restart)
	_hud.assemble_pressed.connect(_on_assemble_pressed)
	_hud.rage_pressed.connect(_on_rage_pressed)
	_hud.portal_confirm_pressed.connect(_on_portal_confirm_pressed)
	_hud.next_floor_pressed.connect(_on_next_floor_pressed)
	_hud.shop_buy_pressed.connect(_on_shop_buy)
	_hud.shop_refresh_pressed.connect(_on_shop_refresh)
	_hud.shop_upgrade_pressed.connect(_on_shop_upgrade)
	_hud.shop_sell_pressed.connect(_on_shop_sell)
	_hud.relic_buy_pressed.connect(_on_relic_buy)
	_hud.relic_refresh_pressed.connect(_on_relic_refresh)
	_hud.shrine_choice_pressed.connect(_on_shrine_choice)
	_hud.shrine_interact_pressed.connect(_on_shrine_interact_pressed)
	_start_floor(true)
	_hud.set_world_hint("WASD/摇杆移动 · Q集合 · R怒意 · 靠近传送门/神龛")
	_refresh_revive_hud()
	_refresh_oaths()
	_refresh_relic_hud()


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


func get_ducats() -> int:
	return gold


func get_corpus() -> int:
	return corpus


func get_shop_service() -> ShopService:
	return _shop


func get_relic_service() -> RelicService:
	return _relics


func get_shop_economy() -> ShopEconomyConfig:
	return _shop_cfg


func get_corpus_relics_config() -> CorpusRelicsConfig:
	return _corpus_cfg


func get_relic_rows() -> Array:
	return _relics.get_hud_rows() if _relics != null else []


func get_relic_revive_time_multiplier() -> float:
	return _relics.revive_time_multiplier() if _relics != null else 1.0


func get_focused_shrine() -> FloorShrine:
	return _focused_shrine


func get_follower_count() -> int:
	return _followers.size()


func get_army_type_ids() -> Array:
	return _collect_owned_type_ids()


func get_last_interest() -> int:
	return _shop.last_interest if _shop != null else 0


func get_revive_queue_size() -> int:
	return _revive_queue.size() if _revive_queue != null else 0


func get_revive_queue_rows() -> Array:
	return _revive_queue.get_hud_rows() if _revive_queue != null else []


func get_last_merge_log() -> String:
	return _last_merge_log


func get_captain_hp() -> int:
	if _captain == null or not is_instance_valid(_captain):
		return 0
	return _captain.current_hp


func get_captain() -> SquadMember:
	return _captain


func get_merge_rank_config() -> MergeRankConfig:
	return _merge_cfg


func get_living_follower_hps() -> Array:
	var out: Array = []
	for m in _followers:
		if m == null or not is_instance_valid(m) or m.is_dead:
			continue
		out.append(m.current_hp)
	return out


func get_army_roster_defs() -> Array:
	## Living roster defs + queued (unscaled). Army domain for type cap / oaths.
	var out: Array = []
	for m in _followers:
		if m == null or not is_instance_valid(m):
			continue
		var d := m.roster_definition if m.roster_definition != null else m.definition
		if d != null:
			out.append(d)
	if _revive_queue != null:
		for d2 in _revive_queue.get_defs():
			out.append(d2)
	return out


func get_oath_service() -> OathService:
	return _oath_service


func get_oath_rows() -> Array:
	return _oath_service.build_hud_rows(get_army_roster_defs()) if _oath_service != null else []


func get_champion_keyword_count(keyword: StringName) -> int:
	if _oath_service == null:
		return 0
	return _oath_service.count_for_keyword(get_army_roster_defs(), keyword)


func get_oath_tier(oath_id: StringName) -> int:
	if _oath_service == null:
		return 0
	return _oath_service.tier_for_id(oath_id, get_army_roster_defs())


func get_oath_damage_taken_multiplier() -> float:
	if _oath_service == null:
		return 1.0
	return _oath_service.damage_taken_multiplier(get_army_roster_defs())


func get_oath_revive_time_multiplier() -> float:
	if _oath_service == null:
		return 1.0
	return _oath_service.revive_time_multiplier(get_army_roster_defs())


func get_oath_ranged_damage_multiplier() -> float:
	if _oath_service == null:
		return 1.0
	return _oath_service.ranged_damage_multiplier(get_army_roster_defs())


func get_oath_ranged_interval_multiplier() -> float:
	if _oath_service == null:
		return 1.0
	return _oath_service.ranged_interval_multiplier(get_army_roster_defs())


## Test helper: grant ducats without pickup.
func debug_add_ducats(amount: int) -> void:
	if amount == 0:
		return
	gold = maxi(0, gold + amount)
	if _hud != null:
		_hud.refresh_gold(gold)
	if run_phase == RunPhase.INTERSTITIAL:
		_refresh_shop_hud()


## Test helper: grant corpus without pickup.
func debug_add_corpus(amount: int) -> void:
	if amount == 0:
		return
	corpus = maxi(0, corpus + amount)
	if _hud != null:
		_hud.refresh_corpus(corpus)
	if run_phase == RunPhase.INTERSTITIAL:
		_refresh_shop_hud()


## Test helpers for shop actions (same as HUD buttons).
func debug_shop_buy(slot_index: int) -> Dictionary:
	return _try_shop_buy(slot_index)


func debug_shop_refresh() -> Dictionary:
	return _try_shop_refresh()


func debug_shop_upgrade() -> Dictionary:
	return _try_shop_upgrade()


func debug_shop_sell(follower_index: int) -> Dictionary:
	return _try_shop_sell(follower_index)


func debug_relic_buy(slot_index: int) -> Dictionary:
	return _try_relic_buy(slot_index)


func debug_relic_refresh() -> Dictionary:
	return _try_relic_refresh()


## Test helper: credit corpus as if a kill drop was collected (applies find bonus).
func debug_grant_kill_corpus(is_elite: bool = false) -> int:
	var base := 0
	if _corpus_cfg != null:
		base = _corpus_cfg.roll_kill_corpus(_rng, is_elite)
	var bonus := _relics.corpus_find_bonus() if _relics != null else 0
	var total := maxi(0, base + bonus)
	if total > 0:
		_on_corpus_collected(total)
	return total


## Test helper: recruit a unit definition (triggers auto-merge).
func debug_recruit(def: UnitDefinition) -> void:
	recruit_unit(def)


## Test helper: kill living follower by index (enters revive queue).
func debug_kill_follower(follower_index: int) -> bool:
	if follower_index < 0 or follower_index >= _followers.size():
		return false
	var m := _followers[follower_index]
	if m == null or not is_instance_valid(m) or m.is_dead:
		return false
	# Overcome incoming DR (oaths) so one call always kills.
	var dr := maxf(0.05, m.incoming_damage_multiplier)
	var need := int(ceil(float(m.current_hp) / dr)) + 1
	m.take_damage(maxi(1, need))
	return m.is_dead or not is_instance_valid(m) or _followers.find(m) < 0


## Test helper: advance revive timers without waiting real time.
func debug_advance_revive(seconds: float) -> void:
	_tick_revive_queue(maxf(0.0, seconds))


## Test helper: apply damage through captain share hook.
func debug_damage_captain(amount: int) -> void:
	if _captain == null or not is_instance_valid(_captain):
		return
	_captain.take_damage(maxi(0, amount))


## Captain damage share hook (called from SquadMember.take_damage).
## Returns true if damage was fully redirected to living followers.
func try_share_captain_damage(amount: int) -> bool:
	if amount <= 0 or game_over:
		return false
	var living: Array[SquadMember] = []
	for m in _followers:
		if m == null or not is_instance_valid(m) or m.is_dead:
			continue
		living.append(m)
	if living.is_empty():
		return false
	var n := living.size()
	var each := int(amount / n)
	var rem := int(amount % n)
	for i in n:
		var share := each + (1 if i < rem else 0)
		if share > 0:
			living[i].take_damage(share)
	if _revive_queue != null and _merge_cfg != null:
		_revive_queue.extend_all(_merge_cfg.share_extend())
	_refresh_revive_hud()
	if _captain != null and is_instance_valid(_captain) and _entities != null:
		DamagePopup.spawn_text(
			_entities,
			_captain.global_position,
			"分摊",
			Color(0.85, 0.7, 0.95, 1.0)
		)
	return true


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
		_tick_revive_queue(delta)
	if _captain == null or not is_instance_valid(_captain):
		return
	if run_phase == RunPhase.FLOOR and not game_over:
		_update_chest_focus()
		_update_shrine_focus()


func _update_command_input() -> void:
	if ui_blocking or game_over or run_phase != RunPhase.FLOOR:
		return
	if Input.is_physical_key_pressed(KEY_Q):
		_try_assemble()
	if Input.is_physical_key_pressed(KEY_R):
		_try_rage()
	if Input.is_physical_key_pressed(KEY_E):
		if _focused_shrine != null and not _focused_shrine.is_used():
			_open_shrine_choice(_focused_shrine)
		else:
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
	if _shrine_buff_left > 0.0:
		_shrine_buff_left = maxf(0.0, _shrine_buff_left - delta)
		if _shrine_buff_left <= 0.0:
			_refresh_temp_damage_mults()
			if _hud != null:
				_hud.set_world_hint("神龛增益结束")
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
	var rage_dmg := _floor_cfg.rage_damage_mult if active else 1.0
	var spd := _floor_cfg.rage_speed_mult if active else 1.0
	var shrine_dmg := _shrine_attack_mult()
	var dmg := rage_dmg * shrine_dmg
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


func _shrine_attack_mult() -> float:
	if _shrine_buff_left <= 0.0 or _corpus_cfg == null:
		return 1.0
	return 1.0 + maxf(0.0, _corpus_cfg.shrine_attack_bonus)


func _refresh_temp_damage_mults() -> void:
	_apply_rage(_rage_active_left > 0.0)


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
	# Interest settles on current balance before shop opens.
	var interest := 0
	if _shop != null:
		interest = _shop.settle_interest(gold)
		gold += interest
		_shop.roll_shelf(_rng)
	if _relics != null:
		_relics.roll_shelf(_rng)
	_shop_status = "利息 +%d" % interest if interest >= 0 else ""
	_relic_status = ""
	_shrine_choice_open = false
	if _hud != null:
		_hud.hide_shrine_choice()
		_hud.refresh_gold(gold)
		_hud.refresh_corpus(corpus)
		_refresh_shop_hud()


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
	_shrine_buff_left = 0.0
	_shrine_choice_open = false
	_focused_shrine = null
	_clear_floor_entities(is_run_start)
	_generate_map()
	if is_run_start:
		_spawn_captain()
		_spawn_starting_followers()
		if _relics != null:
			_relics.clear_run()
			corpus = _corpus_cfg.starting_corpus if _corpus_cfg != null else 0
	else:
		_reposition_army_to_safe()
	_spawn_enemies_initial()
	_spawn_chests_initial()
	_spawn_shrines_initial()
	_spawn_portal()
	_roll_next_respawn_interval()
	_set_combat_enabled(true)
	_refresh_threat_hud()
	_refresh_temp_damage_mults()
	_refresh_oaths()
	_refresh_relic_hud()
	if _hud != null:
		_hud.refresh_floor(floor_index)
		_hud.refresh_corpus(corpus)
		_hud.hide_interstitial()
		_hud.hide_shrine_choice()
		_hud.set_portal_prompt_visible(false)
		_hud.set_shrine_prompt_visible(false)


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
	# Phase C: dead followers enter revive queue (not permanent prune, except sell / run reset).
	var alive_followers: Array[SquadMember] = []
	for f in _followers:
		if f == null or not is_instance_valid(f):
			continue
		if f.is_dead:
			_enqueue_follower_def(_roster_def_of(f))
			continue
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
	_focused_shrine = null
	if clear_army:
		_captain = null
		_followers.clear()
		if _revive_queue != null:
			_revive_queue.clear()
	_refresh_revive_hud()


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


func _spawn_shrines_initial() -> void:
	var count := 1
	if _corpus_cfg != null:
		count = maxi(0, _corpus_cfg.start_shrine_count)
	for _i in count:
		_spawn_one_shrine(_sample_loot_spawn_pos())


func _spawn_one_shrine(at: Vector2) -> FloorShrine:
	if _entities == null:
		return null
	var shrine := FloorShrine.new()
	shrine.name = "Shrine_%d" % _shrine_serial
	_shrine_serial += 1
	shrine.configure()
	shrine.global_position = at
	_entities.add_child(shrine)
	_occupied_spots.append(at)
	return shrine


func _sample_loot_spawn_pos() -> Vector2:
	if _map == null:
		return Vector2(500, 500)
	var avoid := _collect_live_avoid_positions()
	var sep := _spawn_cfg.spawn_min_separation if _spawn_cfg != null else 90.0
	var margin := _spawn_cfg.spawn_edge_margin if _spawn_cfg != null else 56.0
	var pos := _map.sample_spawn_point(_rng, avoid, sep, margin, true, true)
	_occupied_spots.append(pos)
	return pos


func _spawn_enemies_initial() -> void:
	var count := _rng.randi_range(_spawn_cfg.start_enemy_min, _spawn_cfg.start_enemy_max)
	var elite_n := 1 if _corpus_cfg == null else maxi(0, _corpus_cfg.start_elite_count)
	elite_n = mini(elite_n, count)
	var grunt_n := maxi(0, count - elite_n)
	_spawn_enemy_batch(grunt_n, false)
	for _i in elite_n:
		_spawn_one_enemy(_sample_loot_spawn_pos(), true)


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


func _spawn_one_enemy(at: Vector2, as_elite: bool = false) -> Enemy:
	var path := _floor_cfg.enemy_path if _floor_cfg != null else "res://resources/units/enemy_grunt.tres"
	var def := _scale_enemy_def(_load_unit(path), as_elite)
	var e := Enemy.new()
	e.name = ("Elite_%d" % _enemy_serial) if as_elite else ("Enemy_%d" % _enemy_serial)
	_enemy_serial += 1
	e.configure(def, _rng, as_elite)
	var corpus_amt := 0
	if _corpus_cfg != null:
		corpus_amt = _corpus_cfg.roll_kill_corpus(_rng, as_elite)
	var ducat_override := -1
	if as_elite and def != null and _corpus_cfg != null:
		var lo := mini(def.gold_drop_min, def.gold_drop_max)
		var hi := maxi(def.gold_drop_min, def.gold_drop_max)
		var base_gold := _rng.randi_range(lo, hi) if hi > 0 else 1
		ducat_override = maxi(1, int(round(float(base_gold) * maxf(1.0, _corpus_cfg.elite_ducat_multiplier))))
	e.set_loot_overrides(corpus_amt, ducat_override)
	e.global_position = at
	e.gold_dropped.connect(_on_gold_dropped)
	e.corpus_dropped.connect(_on_corpus_dropped)
	_entities.add_child(e)
	return e


func _scale_enemy_def(def: UnitDefinition, as_elite: bool = false) -> UnitDefinition:
	if def == null:
		return def
	var scaled := def.duplicate(true) as UnitDefinition
	var scale := _threat.get_enemy_stat_scale()
	if as_elite and _corpus_cfg != null:
		scale *= maxf(1.0, _corpus_cfg.elite_hp_multiplier)
	scaled.max_hp = maxi(1, int(ceil(float(scaled.max_hp) * scale)))
	var dmg_scale := _threat.get_enemy_stat_scale()
	if as_elite and _corpus_cfg != null:
		dmg_scale *= maxf(1.0, _corpus_cfg.elite_damage_multiplier)
	scaled.attack_damage = maxi(1, int(round(float(scaled.attack_damage) * dmg_scale)))
	if as_elite:
		scaled.display_name = "精英·%s" % scaled.display_name
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
	e.configure(def, _rng, false)
	var corpus_amt := 0
	if _corpus_cfg != null:
		corpus_amt = _corpus_cfg.roll_kill_corpus(_rng, false)
	e.set_loot_overrides(corpus_amt, -1)
	e.global_position = at
	e.aggro_range = 200.0
	e.gold_dropped.connect(_on_gold_dropped)
	e.corpus_dropped.connect(_on_corpus_dropped)
	_entities.add_child(e)
	return e


func recruit_unit(def: UnitDefinition) -> void:
	if def == null or _captain == null:
		return
	_spawn_follower_from_roster(def.duplicate(true) as UnitDefinition)
	_try_auto_merge()
	_refresh_oaths()


func _spawn_follower_from_roster(roster_def: UnitDefinition) -> SquadMember:
	if roster_def == null or _captain == null or _entities == null:
		return null
	var member := SquadMember.new()
	var index := _followers.size()
	member.name = "Ally_%d" % index
	var mult := 1.0
	if _merge_cfg != null:
		mult = _merge_cfg.multiplier_for_rank(int(roster_def.rank))
	member.configure_as_follower(roster_def, _captain, index, mult)
	var angle := float(index + 1) * TAU / 5.0
	var radius := _merge_cfg.revive_spawn_radius if _merge_cfg != null else 48.0
	member.global_position = _captain.global_position + Vector2(cos(angle), sin(angle)) * radius
	member.combat_enabled = not ui_blocking and not game_over and run_phase == RunPhase.FLOOR
	if not member.died.is_connected(_on_follower_died):
		member.died.connect(_on_follower_died)
	_entities.add_child(member)
	_followers.append(member)
	return member


func _on_follower_died(who: Combatant) -> void:
	var sm := who as SquadMember
	if sm == null or sm.is_captain:
		return
	var roster := _roster_def_of(sm)
	var idx := _followers.find(sm)
	if idx >= 0:
		_followers.remove_at(idx)
		_reindex_followers()
	_enqueue_follower_def(roster)
	_refresh_revive_hud()
	_refresh_oaths()


func _roster_def_of(member: SquadMember) -> UnitDefinition:
	if member == null:
		return null
	if member.roster_definition != null:
		return member.roster_definition.duplicate(true) as UnitDefinition
	if member.definition != null:
		return member.definition.duplicate(true) as UnitDefinition
	return null


func _enqueue_follower_def(def: UnitDefinition) -> void:
	if def == null or _revive_queue == null:
		return
	var sec := _merge_cfg.base_revive_time() if _merge_cfg != null else 8.0
	# Include the unit about to enter the queue so champion keywords still count.
	var roster_for_oath := get_army_roster_defs()
	roster_for_oath.append(def)
	if _oath_service != null:
		sec *= _oath_service.revive_time_multiplier(roster_for_oath)
	if _relics != null:
		sec *= _relics.revive_time_multiplier()
	_revive_queue.enqueue(def, sec)


func _tick_revive_queue(delta: float) -> void:
	if _revive_queue == null or game_over:
		return
	var ready := _revive_queue.tick(delta)
	for def in ready:
		_spawn_follower_from_roster(def)
	if not ready.is_empty():
		_try_auto_merge()
		_refresh_oaths()
		if _hud != null:
			var first: UnitDefinition = ready[0]
			var msg := "复活 %s" % (first.display_name if first != null else "随从")
			_hud.set_world_hint(msg)
	_refresh_revive_hud()


func _try_auto_merge() -> void:
	if _merge_rebuild_guard or _captain == null:
		return
	var living_defs: Array = []
	for m in _followers:
		if m == null or not is_instance_valid(m) or m.is_dead:
			continue
		var d := _roster_def_of(m)
		if d != null:
			living_defs.append(d)
	var queued_defs: Array = _revive_queue.get_defs() if _revive_queue != null else []
	var result := UnitMergeService.auto_merge(living_defs, queued_defs)
	var merges: Array = result.get("merges", [])
	if merges.is_empty():
		return
	_merge_rebuild_guard = true
	# Rebuild living followers from merge result.
	var keep_nodes: Array[SquadMember] = _followers.duplicate()
	_followers.clear()
	for m in keep_nodes:
		if m == null or not is_instance_valid(m):
			continue
		if m.died.is_connected(_on_follower_died):
			m.died.disconnect(_on_follower_died)
		if m.get_parent() != null:
			m.get_parent().remove_child(m)
		m.free()
	if _revive_queue != null:
		_revive_queue.clear()
		for qd in result.get("queued", []):
			var qdef := qd as UnitDefinition
			if qdef != null:
				_enqueue_follower_def(qdef)
	for ld in result.get("living", []):
		var ldef := ld as UnitDefinition
		if ldef != null:
			_spawn_follower_from_roster(ldef)
	_merge_rebuild_guard = false
	_emit_merge_feedback(merges)
	_refresh_revive_hud()
	_refresh_oaths()
	if run_phase == RunPhase.INTERSTITIAL:
		_refresh_shop_hud()


func _emit_merge_feedback(merges: Array) -> void:
	if merges.is_empty():
		return
	var parts: PackedStringArray = PackedStringArray()
	for m in merges:
		var info: Dictionary = m
		var to_rank := int(info.get("to_rank", 0))
		var name_str := str(info.get("name", "?"))
		var label := UnitMergeService.rank_label(to_rank)
		var kw := StringName(str(info.get("keyword", &"")))
		var line := "合兵 → %s·%s" % [label, name_str]
		if to_rank >= UnitMergeService.RANK_CHAMPION and kw != &"":
			line += " [%s]" % String(kw)
		parts.append(line)
		print("PHASE_C_MERGE ", line)
	_last_merge_log = " · ".join(parts)
	_shop_status = _last_merge_log
	if _hud != null:
		_hud.set_world_hint(_last_merge_log)
	if _captain != null and is_instance_valid(_captain) and _entities != null:
		DamagePopup.spawn_text(
			_entities,
			_captain.global_position,
			_last_merge_log,
			Color(1.0, 0.88, 0.35, 1.0)
		)


func _on_shop_buy(slot_index: int) -> void:
	_try_shop_buy(slot_index)


func _on_shop_refresh() -> void:
	_try_shop_refresh()


func _on_shop_upgrade() -> void:
	_try_shop_upgrade()


func _on_shop_sell(follower_index: int) -> void:
	_try_shop_sell(follower_index)


func _on_relic_buy(slot_index: int) -> void:
	_try_relic_buy(slot_index)


func _on_relic_refresh() -> void:
	_try_relic_refresh()


func _on_shrine_interact_pressed() -> void:
	if _focused_shrine != null and not _focused_shrine.is_used():
		_open_shrine_choice(_focused_shrine)


func _on_shrine_choice(choice_index: int) -> void:
	_resolve_shrine_choice(choice_index)


func _try_shop_buy(slot_index: int) -> Dictionary:
	if run_phase != RunPhase.INTERSTITIAL or game_over or _shop == null:
		return {"ok": false, "code": &"wrong_phase"}
	var result := _shop.try_buy(slot_index, gold, _collect_owned_type_ids())
	if not bool(result.get("ok", false)):
		_shop_status = _shop_fail_message(StringName(str(result.get("code", &""))))
		_refresh_shop_hud()
		return result
	var cost := int(result.get("cost", 0))
	var unit: UnitDefinition = result.get("unit") as UnitDefinition
	gold = maxi(0, gold - cost)
	recruit_unit(unit)
	_shop_status = "购入 %s (-%d)" % [
		unit.display_name if unit != null else "?",
		cost,
	]
	_refresh_shop_hud()
	return result


func _try_shop_refresh() -> Dictionary:
	if run_phase != RunPhase.INTERSTITIAL or game_over or _shop == null:
		return {"ok": false, "code": &"wrong_phase"}
	var result := _shop.try_refresh(gold, _rng)
	if not bool(result.get("ok", false)):
		_shop_status = _shop_fail_message(StringName(str(result.get("code", &""))))
		_refresh_shop_hud()
		return result
	var cost := int(result.get("cost", 0))
	gold = maxi(0, gold - cost)
	_shop_status = "货架已刷新 (-%d)" % cost
	_refresh_shop_hud()
	return result


func _try_shop_upgrade() -> Dictionary:
	if run_phase != RunPhase.INTERSTITIAL or game_over or _shop == null:
		return {"ok": false, "code": &"wrong_phase"}
	var result := _shop.try_upgrade_recruit(gold)
	if not bool(result.get("ok", false)):
		_shop_status = _shop_fail_message(StringName(str(result.get("code", &""))))
		_refresh_shop_hud()
		return result
	var cost := int(result.get("cost", 0))
	gold = maxi(0, gold - cost)
	_shop_status = "招募等级 → Lv%d (-%d)" % [int(result.get("level", 1)), cost]
	_refresh_shop_hud()
	return result


func _try_shop_sell(follower_index: int) -> Dictionary:
	if run_phase != RunPhase.INTERSTITIAL or game_over:
		return {"ok": false, "code": &"wrong_phase"}
	if follower_index < 0 or follower_index >= _followers.size():
		_shop_status = "无效单位"
		_refresh_shop_hud()
		return {"ok": false, "code": &"bad_index"}
	var member := _followers[follower_index]
	if member == null or not is_instance_valid(member):
		_shop_status = "无效单位"
		_refresh_shop_hud()
		return {"ok": false, "code": &"bad_index"}
	var def: UnitDefinition = member.definition
	var refund := _shop.sell_refund(def) if _shop != null else 0
	_followers.remove_at(follower_index)
	if member.get_parent() != null:
		member.get_parent().remove_child(member)
	member.queue_free()
	_reindex_followers()
	gold += refund
	_shop_status = "出售 +%d" % refund
	_refresh_oaths()
	_refresh_shop_hud()
	return {"ok": true, "code": &"ok", "refund": refund}


func _reindex_followers() -> void:
	for i in _followers.size():
		var m := _followers[i]
		if m == null or not is_instance_valid(m):
			continue
		m.follow_index = i
		m.name = "Ally_%d" % i


func _collect_owned_type_ids() -> Array:
	## Army roster domain: living + revive queue (queued still count for type cap / oaths).
	var ids: Array = []
	for m in _followers:
		if m == null or not is_instance_valid(m):
			continue
		var d := _roster_def_of(m)
		if d == null:
			continue
		ids.append(d.id)
	if _revive_queue != null:
		for qd in _revive_queue.get_defs():
			var qdef := qd as UnitDefinition
			if qdef != null:
				ids.append(qdef.id)
	return ids


func _army_rows_for_hud() -> Array:
	## Shop sell list: living / on-field roster only (queued still belong to army but not sold here).
	var rows: Array = []
	for i in _followers.size():
		var m := _followers[i]
		if m == null or not is_instance_valid(m) or m.is_dead:
			continue
		var def: UnitDefinition = _roster_def_of(m)
		var name_str := def.display_name if def != null else "?"
		var rank := int(def.rank) if def != null else 0
		var rank_lbl := UnitMergeService.rank_label(rank)
		var kw := def.keyword if def != null else &""
		var label := "%s·%s" % [rank_lbl, name_str]
		if rank >= UnitMergeService.RANK_CHAMPION and kw != &"":
			label += " [%s]" % String(kw)
		var refund := _shop.sell_refund(def) if _shop != null else 0
		rows.append({
			"index": i,
			"name": label,
			"refund": refund,
			"rank": rank,
			"keyword": kw,
		})
	return rows


func _refresh_revive_hud() -> void:
	if _hud == null:
		return
	_hud.refresh_revive_queue(get_revive_queue_rows())


func _refresh_oaths() -> void:
	_apply_oath_effects_to_army()
	if _hud == null:
		return
	_hud.refresh_oaths(get_oath_rows())


func _refresh_relic_hud() -> void:
	if _hud == null:
		return
	var max_slots := _relics.max_slots() if _relics != null else 3
	_hud.refresh_relics(get_relic_rows(), max_slots)


func _apply_oath_effects_to_army() -> void:
	var roster := get_army_roster_defs()
	var dr := 1.0
	var ranged_dmg := 1.0
	var ranged_iv := 1.0
	if _oath_service != null:
		dr = _oath_service.damage_taken_multiplier(roster)
		ranged_dmg = _oath_service.ranged_damage_multiplier(roster)
		ranged_iv = _oath_service.ranged_interval_multiplier(roster)
	var relic_dr := _relics.damage_taken_multiplier() if _relics != null else 1.0
	var relic_atk := _relics.attack_damage_multiplier() if _relics != null else 1.0
	dr *= relic_dr
	for m in _followers:
		if m == null or not is_instance_valid(m) or m.is_dead:
			continue
		m.incoming_damage_multiplier = dr
		var kw := &""
		if m.roster_definition != null:
			kw = m.roster_definition.keyword
		elif m.definition != null:
			kw = m.definition.keyword
		if _oath_service != null and _oath_service.applies_ranged_to(kw) and kw == &"射术":
			m.oath_damage_multiplier = ranged_dmg * relic_atk
			m.oath_attack_interval_multiplier = ranged_iv
		else:
			m.oath_damage_multiplier = relic_atk
			m.oath_attack_interval_multiplier = 1.0
	if _captain != null and is_instance_valid(_captain) and not _captain.is_dead:
		_captain.incoming_damage_multiplier = dr
		_captain.oath_damage_multiplier = 1.0
		_captain.oath_attack_interval_multiplier = 1.0


func _refresh_shop_hud() -> void:
	if _hud == null or _shop == null:
		return
	var type_cap := _shop_cfg.max_unit_types if _shop_cfg != null else 6
	var type_count := _shop.count_unique_types(_collect_owned_type_ids())
	var relic_shelf: Array = _relics.shelf if _relics != null else []
	var relic_refresh := _relics.get_refresh_cost() if _relics != null else 2
	var owned_relics := get_relic_rows()
	var max_slots := _relics.max_slots() if _relics != null else 3
	_hud.show_shop_interstitial(
		floor_index,
		_shop.shelf,
		gold,
		_shop.get_refresh_cost(),
		_shop.recruit_level,
		_shop.get_upgrade_cost(),
		_shop.last_interest,
		_army_rows_for_hud(),
		type_count,
		type_cap,
		_shop_status,
		corpus,
		relic_shelf,
		relic_refresh,
		owned_relics,
		max_slots,
		_relic_status
	)


func _shop_fail_message(code: StringName) -> String:
	match code:
		ShopService.RESULT_NOT_ENOUGH:
			return "达克特不足"
		ShopService.RESULT_TYPE_CAP:
			return "种类已达上限"
		ShopService.RESULT_SOLD_OUT:
			return "该槽已售出"
		ShopService.RESULT_MAX_LEVEL:
			return "招募等级已满"
		ShopService.RESULT_BAD_SLOT:
			return "无效货架槽"
		ShopService.RESULT_NO_POOL:
			return "兵池为空"
		_:
			return "无法完成操作"


func _try_relic_buy(slot_index: int) -> Dictionary:
	if run_phase != RunPhase.INTERSTITIAL or game_over or _relics == null:
		return {"ok": false, "code": &"wrong_phase"}
	var result := _relics.try_buy(slot_index, corpus)
	if not bool(result.get("ok", false)):
		_relic_status = _relic_fail_message(StringName(str(result.get("code", &""))))
		_refresh_shop_hud()
		return result
	var cost := int(result.get("cost", 0))
	var relic: RelicDefinition = result.get("relic") as RelicDefinition
	corpus = maxi(0, corpus - cost)
	_relic_status = "购入遗物 %s (-%d尸骸)" % [
		relic.display_name if relic != null else "?",
		cost,
	]
	_refresh_oaths()
	_refresh_relic_hud()
	_refresh_shop_hud()
	return result


func _try_relic_refresh() -> Dictionary:
	if run_phase != RunPhase.INTERSTITIAL or game_over or _relics == null:
		return {"ok": false, "code": &"wrong_phase"}
	var result := _relics.try_refresh(corpus, _rng)
	if not bool(result.get("ok", false)):
		_relic_status = _relic_fail_message(StringName(str(result.get("code", &""))))
		_refresh_shop_hud()
		return result
	var cost := int(result.get("cost", 0))
	corpus = maxi(0, corpus - cost)
	_relic_status = "遗物货架已刷新 (-%d尸骸)" % cost
	_refresh_shop_hud()
	return result


func _relic_fail_message(code: StringName) -> String:
	match code:
		RelicService.RESULT_NOT_ENOUGH:
			return "尸骸不足"
		RelicService.RESULT_SLOTS_FULL:
			return "遗物槽已满"
		RelicService.RESULT_SOLD_OUT:
			return "该遗物已售出"
		RelicService.RESULT_BAD_SLOT:
			return "无效遗物槽"
		RelicService.RESULT_NO_POOL:
			return "遗物池为空"
		_:
			return "无法购买遗物"


func _update_shrine_focus() -> void:
	_focused_shrine = null
	if ui_blocking or game_over or _shrine_choice_open or not is_inside_tree():
		if _hud != null:
			_hud.set_shrine_prompt_visible(false)
		return
	if _captain == null or not is_instance_valid(_captain):
		return
	var radius := _corpus_cfg.shrine_interact_radius if _corpus_cfg != null else 90.0
	var best_dist := radius
	for node in get_tree().get_nodes_in_group(&"shrines"):
		if node == null or not is_instance_valid(node):
			continue
		var shrine := node as FloorShrine
		if shrine == null or shrine.is_used():
			continue
		var dist := _captain.global_position.distance_to(shrine.global_position)
		if dist <= best_dist:
			best_dist = dist
			_focused_shrine = shrine
	if _hud != null:
		_hud.set_shrine_prompt_visible(_focused_shrine != null)


func _open_shrine_choice(shrine: FloorShrine) -> void:
	if shrine == null or shrine.is_used() or _shrine_choice_open or game_over:
		return
	if run_phase != RunPhase.FLOOR:
		return
	_shrine_choice_open = true
	ui_blocking = true
	_focused_shrine = shrine
	if _hud != null:
		_hud.show_shrine_choice("选择神龛恩惠")


func _resolve_shrine_choice(choice_index: int) -> void:
	if not _shrine_choice_open:
		return
	var shrine := _focused_shrine
	_shrine_choice_open = false
	ui_blocking = false
	if _hud != null:
		_hud.hide_shrine_choice()
	if shrine == null or not is_instance_valid(shrine) or shrine.is_used():
		return
	shrine.mark_used()
	if choice_index == 0:
		# Short attack buff.
		var dur := 12.0
		if _corpus_cfg != null:
			dur = maxf(1.0, _corpus_cfg.shrine_buff_duration_sec)
		_shrine_buff_left = dur
		_refresh_temp_damage_mults()
		if _hud != null:
			_hud.set_world_hint("神龛：短时攻击强化 %.0fs" % dur)
	else:
		var reward := 3
		if _corpus_cfg != null:
			reward = maxi(1, _corpus_cfg.shrine_corpus_reward)
		_on_corpus_collected(reward)
		if _hud != null:
			_hud.set_world_hint("神龛：获得 %d 尸骸" % reward)
	_focused_shrine = null
	if _hud != null:
		_hud.set_shrine_prompt_visible(false)


func _init_shop_service() -> void:
	var pool: Array[UnitDefinition] = []
	if _shop_cfg != null:
		for path in _shop_cfg.pool_unit_paths:
			var def := _load_unit(str(path))
			if def != null:
				pool.append(def)
	_shop.configure(_shop_cfg, pool)


func _init_relic_service() -> void:
	_corpus_cfg = _load_corpus_relics_config()
	var pool: Array[RelicDefinition] = []
	if _corpus_cfg != null:
		for path in _corpus_cfg.relic_pool_paths:
			var res := load(str(path))
			if res is RelicDefinition:
				pool.append((res as RelicDefinition).duplicate(true) as RelicDefinition)
			else:
				push_error("GameController: failed to load RelicDefinition %s" % path)
	_relics.configure(_corpus_cfg, pool)


func _load_corpus_relics_config() -> CorpusRelicsConfig:
	var res := load(PATH_CORPUS_RELICS)
	if res is CorpusRelicsConfig:
		return (res as CorpusRelicsConfig).duplicate(true) as CorpusRelicsConfig
	push_warning("GameController: missing corpus_relics.tres, using defaults")
	return CorpusRelicsConfig.new()


func _init_oath_service() -> void:
	var defs: Array[OathDefinition] = []
	for path in [
		PATH_OATH_IRON_WALL,
		PATH_OATH_MYRIAD_BONES,
		PATH_OATH_TAUT_BOW,
	]:
		var res := load(str(path))
		if res is OathDefinition:
			defs.append((res as OathDefinition).duplicate(true) as OathDefinition)
		else:
			push_error("GameController: failed to load OathDefinition %s" % path)
	_oath_service.configure(defs)


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
	if game_over:
		return
	var amount := placeholder_gold
	if _shop_cfg != null:
		amount = maxi(1, _shop_cfg.chest_ducats)
	var at := _captain.global_position if _captain != null else Vector2.ZERO
	if chest != null and is_instance_valid(chest):
		at = chest.global_position
	if amount > 0:
		_on_gold_dropped(amount, at)
	var corpus_amt := 0
	if _corpus_cfg != null:
		corpus_amt = _corpus_cfg.roll_chest_corpus(_rng)
	if corpus_amt > 0:
		_on_corpus_dropped(corpus_amt, at + Vector2(18, 8))


func _on_gold_dropped(amount: int, at: Vector2) -> void:
	if game_over or amount <= 0:
		return
	var drop := GoldPickup.new()
	drop.name = "GoldPickup"
	_entities.add_child(drop)
	drop.global_position = at
	drop.configure(amount)
	drop.collected.connect(_on_gold_collected)


func _on_corpus_dropped(amount: int, at: Vector2) -> void:
	if game_over or amount <= 0:
		return
	var bonus := _relics.corpus_find_bonus() if _relics != null else 0
	var total := amount + bonus
	var drop := CorpusPickup.new()
	drop.name = "CorpusPickup"
	_entities.add_child(drop)
	drop.global_position = at
	drop.configure(total)
	drop.collected.connect(_on_corpus_collected)


func _on_gold_collected(amount: int) -> void:
	if game_over:
		return
	gold += amount
	if _hud != null:
		_hud.refresh_gold(gold)


func _on_corpus_collected(amount: int) -> void:
	if game_over:
		return
	corpus += amount
	if _hud != null:
		_hud.refresh_corpus(corpus)


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


func _load_shop_economy() -> ShopEconomyConfig:
	var res := load(PATH_SHOP_ECONOMY)
	if res is ShopEconomyConfig:
		return (res as ShopEconomyConfig).duplicate(true) as ShopEconomyConfig
	push_error("GameController: failed to load ShopEconomyConfig %s" % PATH_SHOP_ECONOMY)
	return ShopEconomyConfig.new()


func _load_merge_rank_config() -> MergeRankConfig:
	var res := load(PATH_MERGE_RANK)
	if res is MergeRankConfig:
		return (res as MergeRankConfig).duplicate(true) as MergeRankConfig
	push_error("GameController: failed to load MergeRankConfig %s" % PATH_MERGE_RANK)
	return MergeRankConfig.new()


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
