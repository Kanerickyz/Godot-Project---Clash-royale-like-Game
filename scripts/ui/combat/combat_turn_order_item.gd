class_name CombatTurnOrderItem
extends Control

enum State { CURRENT, PENDING }

const PLACEHOLDER_HEAD := preload("res://assets/sprites/0_head.png")
const UNIT_ICON_BASE := "res://assets/sprites/units"
const COLOR_PLAYER := Color(0.35, 0.75, 0.95, 1.0)
const COLOR_ENEMY := Color(0.95, 0.4, 0.35, 1.0)
const COLOR_CURRENT := Color(1.0, 0.92, 0.2, 1.0)
const ITEM_SIZE := Vector2(64, 80)

static var _icon_cache: Dictionary = {}

@onready var _frame: Panel = $Frame
@onready var _portrait: TextureRect = $Frame/Portrait

var _unit: UnitInstance
var _state: State = State.PENDING


func _ready() -> void:
	custom_minimum_size = ITEM_SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	pivot_offset = ITEM_SIZE * 0.5


func bind_unit(unit: UnitInstance) -> void:
	_unit = unit
	_refresh_portrait()


func get_unit_instance_id() -> int:
	if _unit == null:
		return -1
	return _unit.instance_id


func set_state(state: State, alive: bool) -> void:
	_state = state
	_apply_visuals(alive)


func _refresh_portrait() -> void:
	if _portrait == null:
		return
	var tex := _resolve_portrait()
	_portrait.texture = tex
	_portrait.visible = tex != null


func _resolve_portrait() -> Texture2D:
	if _unit == null:
		return PLACEHOLDER_HEAD
	var data := _unit.unit_data
	if data != null:
		if data.portrait_head != null:
			return data.portrait_head
		if data.icon != null:
			return data.icon
		if not data.id.is_empty():
			if _icon_cache.has(data.id):
				return _icon_cache[data.id] as Texture2D
			var path := "%s/%s.png" % [UNIT_ICON_BASE, data.id]
			if ResourceLoader.exists(path):
				var tex: Texture2D = load(path) as Texture2D
				if tex != null:
					_icon_cache[data.id] = tex
					return tex
	return PLACEHOLDER_HEAD


func _apply_visuals(alive: bool) -> void:
	if _frame == null:
		return
	var team_color := COLOR_PLAYER
	if _unit != null and _unit.team == UnitInstance.Team.ENEMY:
		team_color = COLOR_ENEMY
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.border_color = team_color
	modulate = Color.WHITE
	scale = Vector2.ONE
	match _state:
		State.CURRENT:
			style.border_color = COLOR_CURRENT
			style.set_border_width_all(3)
			scale = Vector2(1.08, 1.08)
		State.PENDING:
			if not alive:
				modulate = Color(1.0, 1.0, 1.0, 0.55)
	_frame.add_theme_stylebox_override("panel", style)
