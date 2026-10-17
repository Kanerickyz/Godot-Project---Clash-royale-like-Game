class_name GameController
extends Node2D
## Squad roam prototype: spawn map entities, economy, recruit, win/lose.


const START_GOLD := 15
const MAP_SIZE := Vector2(1600, 1200)
const SHOP_IDLE_OPEN_SEC := 3.0
const MOVE_IDLE_SPEED := 12.0
const CHEST_ENGAGE_RADIUS := 110.0

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
var _entities: Node2D
var _captain: SquadMember
var _camera_ctrl: CaptainController
var _shop: RoamShop
var _hud: GameHud
var _followers: Array[SquadMember] = []
var _pending_chest_choices: Array = []
var _shop_idle_sec: float = 0.0
var _focused_chest: RoamChest


func _ready() -> void:
	add_to_group(&"game_controller")
	_rng.randomize()
	_build_world()
	_hud = GameHud.new()
	_hud.name = "HUD"
	add_child(_hud)
	_hud.refresh_gold(gold)
	_hud.shop_buy_pressed.connect(_on_shop_buy)
	_hud.shop_closed.connect(_on_shop_closed)
	_hud.chest_pick_pressed.connect(_on_chest_pick)
	_hud.restart_pressed.connect(_on_restart)
	_spawn_captain()
	_spawn_shop()
	_spawn_enemies()
	_spawn_chests()
	_spawn_boss()


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


func _process(delta: float) -> void:
	if _captain == null or not is_instance_valid(_captain):
		return
	_update_chest_focus()
	if _shop != null:
		var near := _shop.is_captain_near(_captain)
		_shop.set_captain_in_range(near)
		_update_shop_idle_open(delta, near)


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


func _build_world() -> void:
	var ground_host := Node2D.new()
	ground_host.name = "GroundHost"
	ground_host.z_index = -10
	add_child(ground_host)
	var poly := Polygon2D.new()
	poly.name = "GroundPoly"
	poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(MAP_SIZE.x, 0),
		Vector2(MAP_SIZE.x, MAP_SIZE.y),
		Vector2(0, MAP_SIZE.y),
	])
	poly.color = Color(0.22, 0.32, 0.22, 1.0)
	ground_host.add_child(poly)

	# Soft grid marks for readability.
	for i in range(1, 8):
		var line_h := Line2D.new()
		line_h.width = 1.0
		line_h.default_color = Color(0.18, 0.26, 0.18, 0.6)
		var y := float(i) * MAP_SIZE.y / 8.0
		line_h.points = PackedVector2Array([Vector2(0, y), Vector2(MAP_SIZE.x, y)])
		ground_host.add_child(line_h)
		var line_v := Line2D.new()
		line_v.width = 1.0
		line_v.default_color = Color(0.18, 0.26, 0.18, 0.6)
		var x := float(i) * MAP_SIZE.x / 8.0
		line_v.points = PackedVector2Array([Vector2(x, 0), Vector2(x, MAP_SIZE.y)])
		ground_host.add_child(line_v)

	_entities = Node2D.new()
	_entities.name = "Entities"
	add_child(_entities)

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	# Closer view for phone portrait (iPhone 14 Pro aspect).
	cam.zoom = Vector2(1.85, 1.85)
	cam.position_smoothing_enabled = false
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
	_captain.global_position = Vector2(420, 560)
	_captain.died.connect(_on_captain_died)
	_entities.add_child(_captain)
	_camera_ctrl.bind_captain(_captain)
	_set_combat_enabled(true)


func _spawn_shop() -> void:
	_shop = RoamShop.new()
	_shop.name = "Shop"
	_shop.global_position = Vector2(220, 220)
	var offers: Array[Dictionary] = [
		{"unit": _load_unit(PATH_ALLY_SPEAR), "price": 15},
		{"unit": _load_unit(PATH_ALLY_ARCHER), "price": 25},
		{"unit": _load_unit(PATH_ALLY_SHIELD), "price": 40},
	]
	_shop.configure(offers)
	_entities.add_child(_shop)


func _spawn_enemies() -> void:
	var def := _load_unit(PATH_ENEMY)
	var spots: Array[Vector2] = [
		Vector2(700, 350),
		Vector2(900, 500),
		Vector2(750, 750),
		Vector2(1100, 400),
		Vector2(1000, 700),
		Vector2(550, 900),
	]
	for i in spots.size():
		var e := Enemy.new()
		e.name = "Enemy_%d" % i
		e.configure(def, _rng)
		e.global_position = spots[i]
		e.gold_dropped.connect(_on_gold_dropped)
		_entities.add_child(e)


func _spawn_chests() -> void:
	var chest_spots: Array[Vector2] = [
		Vector2(500, 300),
		Vector2(1200, 550),
	]
	for i in chest_spots.size():
		var chest := RoamChest.new()
		chest.name = "Chest_%d" % i
		var choices: Array[UnitDefinition] = [
			_load_unit(PATH_CHEST_A),
			_load_unit(PATH_CHEST_B),
			_load_unit(PATH_CHEST_C),
		]
		# Shuffle lightly so two chests can feel different.
		if _rng.randf() > 0.5:
			choices.reverse()
		chest.configure(60, choices)
		chest.global_position = chest_spots[i]
		chest.opened.connect(_on_chest_opened)
		_entities.add_child(chest)


func _spawn_boss() -> void:
	var def := _load_unit(PATH_BOSS)
	var boss := Boss.new()
	boss.name = "Boss"
	boss.configure(def, _rng)
	var behavior := _load_boss_behavior(PATH_BOSS_BEHAVIOR)
	var minion_def := _load_unit(PATH_BOSS_MINION)
	boss.configure_behavior(behavior, minion_def)
	boss.global_position = Vector2(1350, 950)
	boss.aggro_range = 280.0
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


func _open_shop() -> void:
	if ui_blocking or game_over or _shop == null:
		return
	ui_blocking = true
	_set_combat_enabled(false)
	_hud.show_shop(_shop.shelf, gold)


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
	_hud.refresh_gold(gold)
	_hud.show_shop(_shop.shelf, gold)


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
