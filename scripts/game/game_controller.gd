class_name GameController
extends Node2D
## City-trade dual-layer sandbox: world march, city menu, encounter combat.


enum Mode { WORLD, CITY, COMBAT, END }

const PATH_TRADE := "res://resources/world/trade_world.tres"
const PATH_CAPTAIN := "res://resources/units/captain.tres"
const PATH_ENEMY := "res://resources/units/enemy_grunt.tres"

var gold: int = 0
var cargo: int = 0
var game_over: bool = false
var ui_blocking: bool = false
var mode: Mode = Mode.WORLD

var _rng := RandomNumberGenerator.new()
var _cfg: TradeWorldConfig
var _hud: GameHud
var _camera: Camera2D
var _camera_ctrl: CaptainController

var _world_layer: Node2D
var _combat_layer: Node2D
var _combat_entities: Node2D
var _world_token: Node2D
var _road_line: Line2D

var _roster: Array = []  # Array of UnitDefinition (duplicated followers)
var _followers: Array[SquadMember] = []
var _captain: SquadMember
var _enemy_serial: int = 0

var _city_index: int = 0
var _at_city: bool = true
var _path_from: int = 0
var _path_to: int = 1
var _path_progress: float = 0.0
var _segment_encounter_done: bool = false
var _combat_won_pending: bool = false
var _combat_check_timer: float = 0.0
var _city_reenter_cd: float = 0.0


func _ready() -> void:
	add_to_group(&"game_controller")
	_rng.randomize()
	_cfg = _load_trade_config()
	gold = _cfg.start_gold
	cargo = _cfg.start_cargo
	_city_index = clampi(_cfg.start_city_index, 0, maxi(0, _cfg.cities.size() - 1))
	_build_layers()
	_hud = GameHud.new()
	_hud.name = "HUD"
	add_child(_hud)
	_hud.refresh_status(gold, cargo, _cfg.cargo_display_name)
	_hud.city_recruit_pressed.connect(_on_city_recruit)
	_hud.city_buy_pressed.connect(_on_city_buy)
	_hud.city_sell_pressed.connect(_on_city_sell)
	_hud.city_leave_pressed.connect(_on_city_leave)
	_hud.restart_pressed.connect(_on_restart)
	_enter_world_at_city(_city_index, true)


func get_move_vector() -> Vector2:
	if ui_blocking or game_over:
		return Vector2.ZERO
	if mode != Mode.WORLD and mode != Mode.COMBAT:
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


func get_focused_chest() -> Node2D:
	return null


## Kept for Boss / legacy callers; only spawns during COMBAT.
func spawn_hostile_minion(def: UnitDefinition, at: Vector2) -> Enemy:
	if def == null or _combat_entities == null or mode != Mode.COMBAT:
		return null
	return _spawn_one_enemy(def, at)


## Add a follower definition to the roster (city recruit). Spawns live ally only in COMBAT.
func recruit_unit(def: UnitDefinition) -> void:
	if def == null:
		return
	var copy := def.duplicate(true) as UnitDefinition
	_roster.append(copy)
	if mode == Mode.COMBAT and _captain != null and is_instance_valid(_captain):
		_spawn_follower_from_def(copy, _roster.size() - 1)


func _process(delta: float) -> void:
	match mode:
		Mode.WORLD:
			_process_world(delta)
		Mode.COMBAT:
			_process_combat(delta)
		_:
			pass


func _process_world(delta: float) -> void:
	if _world_token == null or _cfg == null or _cfg.cities.size() < 2:
		return
	if _city_reenter_cd > 0.0:
		_city_reenter_cd = maxf(0.0, _city_reenter_cd - delta)
	var move := get_move_vector()
	if _at_city:
		if _city_reenter_cd <= 0.0 and (
			Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE)
		):
			_open_city_menu()
			return
		if move.length_squared() > 0.04:
			_start_march_from_city(move)
		return
	_advance_along_path(delta, move)


func _process_combat(delta: float) -> void:
	if game_over or _combat_won_pending:
		return
	_combat_check_timer += delta
	if _combat_check_timer < 0.35:
		return
	_combat_check_timer = 0.0
	if _count_alive_enemies() <= 0:
		_combat_won_pending = true
		_on_combat_won()


func _build_layers() -> void:
	_world_layer = Node2D.new()
	_world_layer.name = "WorldLayer"
	add_child(_world_layer)

	_combat_layer = Node2D.new()
	_combat_layer.name = "CombatLayer"
	_combat_layer.visible = false
	add_child(_combat_layer)

	_combat_entities = Node2D.new()
	_combat_entities.name = "Entities"
	_combat_layer.add_child(_combat_entities)

	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera_ctrl = CaptainController.new()
	_camera_ctrl.name = "CaptainController"
	_camera_ctrl.camera = _camera
	add_child(_camera_ctrl)

	_build_world_visuals()
	_build_combat_arena_visual()


func _build_world_visuals() -> void:
	var bg := ColorRect.new()
	bg.name = "WorldBg"
	bg.color = Color(0.12, 0.16, 0.14, 1.0)
	bg.size = Vector2(393, 852)
	bg.position = Vector2.ZERO
	bg.z_index = -20
	_world_layer.add_child(bg)

	_road_line = Line2D.new()
	_road_line.name = "Road"
	_road_line.width = 10.0
	_road_line.default_color = Color(0.55, 0.45, 0.28, 1.0)
	_road_line.z_index = -5
	_world_layer.add_child(_road_line)

	if _cfg == null:
		return
	var pts := PackedVector2Array()
	for i in _cfg.cities.size():
		var city: TradeCityConfig = _cfg.cities[i]
		if city == null:
			continue
		pts.append(city.world_position)
		var node := Node2D.new()
		node.name = "City_%d" % i
		node.position = city.world_position
		_world_layer.add_child(node)
		var body := ColorRect.new()
		body.size = Vector2(48, 48)
		body.position = Vector2(-24, -24)
		body.color = Color(0.35, 0.55, 0.75, 1.0) if i == 0 else Color(0.55, 0.4, 0.35, 1.0)
		node.add_child(body)
		var label := Label.new()
		label.text = city.display_name
		label.position = Vector2(-28, -48)
		label.add_theme_font_size_override("font_size", 16)
		var font: Font = UiFonts.get_font()
		if font != null:
			label.add_theme_font_override("font", font)
		node.add_child(label)
	_road_line.points = pts

	_world_token = Node2D.new()
	_world_token.name = "WorldToken"
	_world_layer.add_child(_world_token)
	var token_body := ColorRect.new()
	token_body.size = Vector2(22, 22)
	token_body.position = Vector2(-11, -11)
	token_body.color = Color(0.95, 0.85, 0.35, 1.0)
	_world_token.add_child(token_body)
	var token_label := Label.new()
	token_label.text = "队"
	token_label.position = Vector2(-10, -32)
	token_label.add_theme_font_size_override("font_size", 14)
	var tfont: Font = UiFonts.get_font()
	if tfont != null:
		token_label.add_theme_font_override("font", tfont)
	_world_token.add_child(token_label)


func _build_combat_arena_visual() -> void:
	var size := _cfg.combat_arena_size if _cfg != null else Vector2(360, 520)
	var floor_rect := ColorRect.new()
	floor_rect.name = "ArenaFloor"
	floor_rect.color = Color(0.18, 0.2, 0.16, 1.0)
	floor_rect.size = size
	floor_rect.position = -size * 0.5
	floor_rect.z_index = -10
	_combat_layer.add_child(floor_rect)
	var border := ColorRect.new()
	border.name = "ArenaBorder"
	border.color = Color(0.4, 0.35, 0.25, 1.0)
	border.size = size + Vector2(16, 16)
	border.position = -border.size * 0.5
	border.z_index = -11
	_combat_layer.add_child(border)


func _enter_world_at_city(city_idx: int, open_menu: bool) -> void:
	mode = Mode.WORLD
	game_over = false
	ui_blocking = false
	_at_city = true
	_city_index = clampi(city_idx, 0, maxi(0, _cfg.cities.size() - 1))
	_segment_encounter_done = false
	_combat_won_pending = false
	_clear_combat_entities()
	_world_layer.visible = true
	_combat_layer.visible = false
	_apply_world_camera()
	_place_token_at_city(_city_index)
	_camera_ctrl.bind_captain(_world_token)
	_update_world_hint()
	_hud.refresh_status(gold, cargo, _cfg.cargo_display_name)
	if open_menu:
		_open_city_menu()


func _place_token_at_city(idx: int) -> void:
	if _world_token == null or _cfg == null or idx < 0 or idx >= _cfg.cities.size():
		return
	var city: TradeCityConfig = _cfg.cities[idx]
	if city == null:
		return
	_world_token.global_position = city.world_position


func _apply_world_camera() -> void:
	if _camera == null or _cfg == null:
		return
	var zoom := _cfg.world_camera_zoom
	_camera.zoom = Vector2(zoom, zoom)
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 393
	_camera.limit_bottom = 852
	_camera.make_current()


func _apply_combat_camera() -> void:
	if _camera == null or _cfg == null:
		return
	var zoom := _cfg.combat_camera_zoom
	_camera.zoom = Vector2(zoom, zoom)
	var half := _cfg.combat_arena_size * 0.5
	_camera.limit_left = int(-half.x - 40)
	_camera.limit_top = int(-half.y - 40)
	_camera.limit_right = int(half.x + 40)
	_camera.limit_bottom = int(half.y + 40)
	_camera.make_current()


func _update_world_hint() -> void:
	if _hud == null or _cfg == null:
		return
	if mode == Mode.COMBAT:
		_hud.set_world_hint("遭遇战中 · 只控队长 · 清场后回世界层")
		return
	if mode == Mode.CITY:
		var city := _current_city()
		var name_str := city.display_name if city != null else "城池"
		_hud.set_world_hint("%s：招人 / 买卖%s / 离开" % [name_str, _cfg.cargo_display_name])
		return
	if _at_city:
		var c := _current_city()
		var n := c.display_name if c != null else "城池"
		_hud.set_world_hint("位于%s · 摇杆前往邻城 · E/空格再进城" % n)
	else:
		var a := _city_name(_path_from)
		var b := _city_name(_path_to)
		_hud.set_world_hint("行军：%s → %s · 途中可能遭遇" % [a, b])


func _current_city() -> TradeCityConfig:
	if _cfg == null or _city_index < 0 or _city_index >= _cfg.cities.size():
		return null
	return _cfg.cities[_city_index]


func _city_name(idx: int) -> String:
	if _cfg == null or idx < 0 or idx >= _cfg.cities.size():
		return "?"
	var c: TradeCityConfig = _cfg.cities[idx]
	return c.display_name if c != null else "?"


func _start_march_from_city(move: Vector2) -> void:
	if _cfg == null or _cfg.cities.size() < 2:
		return
	var from_idx := _city_index
	var best_to := -1
	var best_dot := -999.0
	var from_pos: Vector2 = _cfg.cities[from_idx].world_position
	for i in _cfg.cities.size():
		if i == from_idx:
			continue
		var to_pos: Vector2 = _cfg.cities[i].world_position
		var along := (to_pos - from_pos).normalized()
		if along == Vector2.ZERO:
			continue
		var d := move.normalized().dot(along)
		if d > best_dot:
			best_dot = d
			best_to = i
	if best_to < 0 or best_dot < 0.15:
		# With two cities, any clear input starts toward the other.
		if _cfg.cities.size() == 2:
			best_to = 1 if from_idx == 0 else 0
		else:
			return
	_path_from = from_idx
	_path_to = best_to
	_path_progress = 0.0
	_at_city = false
	_segment_encounter_done = false
	_hud.hide_city_menu()
	ui_blocking = false
	mode = Mode.WORLD
	_update_world_hint()


func _advance_along_path(delta: float, move: Vector2) -> void:
	if _cfg == null or _path_from < 0 or _path_to < 0:
		return
	if _path_from >= _cfg.cities.size() or _path_to >= _cfg.cities.size():
		return
	var a: Vector2 = _cfg.cities[_path_from].world_position
	var b: Vector2 = _cfg.cities[_path_to].world_position
	var seg := b - a
	var seg_len := seg.length()
	if seg_len < 1.0:
		_arrive_at_city(_path_to)
		return
	var along := seg / seg_len
	var speed := _cfg.token_move_speed
	var signed := 0.0
	if move.length_squared() > 0.04:
		signed = move.normalized().dot(along)
	else:
		# Keep slight forward drift only when actively holding? Prefer stop when no input.
		signed = 0.0
	if absf(signed) < 0.08:
		return
	_path_progress = clampf(_path_progress + (signed * speed * delta) / seg_len, 0.0, 1.0)
	_world_token.global_position = a.lerp(b, _path_progress)

	# Encounter once mid-road when leaving the origin city.
	if not _segment_encounter_done and _path_progress >= 0.35 and _path_progress <= 0.85:
		_segment_encounter_done = true
		if _rng.randf() <= _cfg.encounter_chance:
			_enter_combat()
			return

	var arrive_r := _cfg.city_arrive_radius / seg_len
	if _path_progress >= 1.0 - arrive_r or _path_progress >= 0.995:
		_arrive_at_city(_path_to)
	elif _path_progress <= arrive_r and signed < 0.0:
		_arrive_at_city(_path_from)


func _arrive_at_city(idx: int) -> void:
	_city_index = idx
	_at_city = true
	_path_progress = 0.0
	_place_token_at_city(idx)
	_update_world_hint()
	_open_city_menu()


func _open_city_menu() -> void:
	var city := _current_city()
	if city == null or _hud == null:
		return
	mode = Mode.CITY
	ui_blocking = true
	var offers := _build_recruit_offer_dicts()
	_hud.show_city_menu(
		city.display_name,
		city.buy_price,
		city.sell_price,
		offers,
		gold,
		cargo,
		_cfg.cargo_display_name
	)
	_update_world_hint()


func _refresh_city_menu() -> void:
	if mode != Mode.CITY:
		return
	_open_city_menu()


func _build_recruit_offer_dicts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _cfg == null:
		return out
	for offer in _cfg.recruit_offers:
		if offer == null:
			continue
		var unit: UnitDefinition = offer.unit
		if unit != null:
			unit = unit.duplicate(true) as UnitDefinition
		out.append({"unit": unit, "price": offer.price})
	return out


func _on_city_recruit(slot_index: int) -> void:
	if mode != Mode.CITY or _cfg == null:
		return
	if slot_index < 0 or slot_index >= _cfg.recruit_offers.size():
		return
	var offer: TradeRecruitOffer = _cfg.recruit_offers[slot_index]
	if offer == null or offer.unit == null:
		return
	if gold < offer.price:
		return
	gold -= offer.price
	recruit_unit(offer.unit)
	_hud.refresh_status(gold, cargo, _cfg.cargo_display_name)
	_refresh_city_menu()


func _on_city_buy() -> void:
	if mode != Mode.CITY:
		return
	var city := _current_city()
	if city == null:
		return
	if gold < city.buy_price:
		return
	gold -= city.buy_price
	cargo += 1
	_hud.refresh_status(gold, cargo, _cfg.cargo_display_name)
	_refresh_city_menu()


func _on_city_sell() -> void:
	if mode != Mode.CITY:
		return
	var city := _current_city()
	if city == null or cargo <= 0:
		return
	cargo -= 1
	gold += city.sell_price
	_hud.refresh_status(gold, cargo, _cfg.cargo_display_name)
	_refresh_city_menu()


func _on_city_leave() -> void:
	if mode != Mode.CITY:
		return
	_hud.hide_city_menu()
	mode = Mode.WORLD
	ui_blocking = false
	_at_city = true
	_city_reenter_cd = 0.35
	_update_world_hint()


func _enter_combat() -> void:
	mode = Mode.COMBAT
	ui_blocking = false
	_combat_won_pending = false
	_combat_check_timer = 0.0
	_hud.hide_city_menu()
	_world_layer.visible = false
	_combat_layer.visible = true
	_apply_combat_camera()
	_clear_combat_entities()
	_spawn_combat_party()
	_spawn_combat_enemies()
	_set_combat_enabled(true)
	_update_world_hint()
	_hud.set_world_hint("遭遇！清场后继续行军")


func _spawn_combat_party() -> void:
	var def := _load_unit(PATH_CAPTAIN)
	_captain = SquadMember.new()
	_captain.name = "Captain"
	_captain.configure_as_captain(def)
	_captain.global_position = Vector2(0, 80)
	_captain.died.connect(_on_captain_died)
	_combat_entities.add_child(_captain)
	_camera_ctrl.bind_captain(_captain)
	_followers.clear()
	for i in _roster.size():
		var unit_def: UnitDefinition = _roster[i] as UnitDefinition
		if unit_def == null:
			continue
		_spawn_follower_from_def(unit_def, i)


func _spawn_follower_from_def(def: UnitDefinition, index: int) -> void:
	if def == null or _captain == null:
		return
	var member := SquadMember.new()
	member.name = "Ally_%d" % index
	member.configure_as_follower(def.duplicate(true) as UnitDefinition, _captain, index)
	var angle := float(index + 1) * TAU / 5.0
	member.global_position = _captain.global_position + Vector2(cos(angle), sin(angle)) * 42.0
	member.combat_enabled = true
	_combat_entities.add_child(member)
	_followers.append(member)


func _spawn_combat_enemies() -> void:
	var count := _cfg.combat_enemy_count if _cfg != null else 4
	var def := _load_unit(PATH_ENEMY)
	var arena := _cfg.combat_arena_size if _cfg != null else Vector2(360, 520)
	for i in count:
		var t := float(i) / float(maxi(1, count))
		var x := lerpf(-arena.x * 0.28, arena.x * 0.28, t)
		var y := -arena.y * 0.22 + float(i % 2) * 36.0
		_spawn_one_enemy(def, Vector2(x, y))


func _spawn_one_enemy(def: UnitDefinition, at: Vector2) -> Enemy:
	var e := Enemy.new()
	e.name = "Enemy_%d" % _enemy_serial
	_enemy_serial += 1
	e.configure(def, _rng)
	e.global_position = at
	e.gold_dropped.connect(_on_gold_dropped)
	_combat_entities.add_child(e)
	return e


func _clear_combat_entities() -> void:
	_followers.clear()
	_captain = null
	if _combat_entities == null:
		return
	for child in _combat_entities.get_children():
		child.queue_free()


func _on_combat_won() -> void:
	_set_combat_enabled(false)
	# Resume world mid-road (keep progress); do not force city.
	mode = Mode.WORLD
	ui_blocking = false
	_clear_combat_entities()
	_world_layer.visible = true
	_combat_layer.visible = false
	_apply_world_camera()
	_camera_ctrl.bind_captain(_world_token)
	_hud.refresh_status(gold, cargo, _cfg.cargo_display_name)
	_update_world_hint()
	_hud.set_world_hint("遭遇已解除 · 继续前往%s" % _city_name(_path_to))


func _on_gold_dropped(amount: int, at: Vector2) -> void:
	if game_over or amount <= 0 or mode != Mode.COMBAT:
		return
	var drop := GoldPickup.new()
	drop.name = "GoldPickup"
	_combat_entities.add_child(drop)
	drop.global_position = at
	drop.configure(amount)
	drop.collected.connect(_on_gold_collected)


func _on_gold_collected(amount: int) -> void:
	if game_over:
		return
	gold += amount
	_hud.refresh_status(gold, cargo, _cfg.cargo_display_name)


func _on_captain_died(_who: Combatant) -> void:
	if game_over:
		return
	game_over = true
	mode = Mode.END
	ui_blocking = true
	_set_combat_enabled(false)
	cargo = 0  # cargo voided; score is gold only
	_hud.refresh_status(gold, cargo, _cfg.cargo_display_name)
	_hud.show_end(gold)


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


func _load_trade_config() -> TradeWorldConfig:
	var res := load(PATH_TRADE)
	if res is TradeWorldConfig:
		return (res as TradeWorldConfig).duplicate(true) as TradeWorldConfig
	push_error("GameController: failed to load TradeWorldConfig %s" % PATH_TRADE)
	return _make_fallback_trade_config()


func _make_fallback_trade_config() -> TradeWorldConfig:
	var cfg := TradeWorldConfig.new()
	cfg.start_gold = 40
	cfg.cargo_display_name = "粮食"
	var a := TradeCityConfig.new()
	a.display_name = "洛阳"
	a.world_position = Vector2(100, 420)
	a.buy_price = 8
	a.sell_price = 14
	var b := TradeCityConfig.new()
	b.display_name = "长安"
	b.world_position = Vector2(290, 420)
	b.buy_price = 12
	b.sell_price = 9
	cfg.cities = [a, b]
	return cfg


func _load_unit(path: String) -> UnitDefinition:
	var res := load(path)
	if res == null:
		push_error("GameController: failed to load unit %s" % path)
		return _make_fallback_unit(path.get_file())
	var def := res as UnitDefinition
	if def == null:
		push_error("GameController: not UnitDefinition %s" % path)
		return _make_fallback_unit(path.get_file())
	return def.duplicate(true) as UnitDefinition


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
