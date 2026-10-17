class_name RoamShop
extends Node2D
## Fixed-shelf shop building. Interact when captain is in range.


signal interact_requested(shop: RoamShop)

const INTERACT_RADIUS := 72.0

var shelf: Array[Dictionary] = []  # {unit: UnitDefinition, price: int, sold_out: bool}
var _body: ColorRect
var _label: Label
var _hint: Label
var _area: Area2D
var captain_in_range: bool = false


func configure(offers: Array[Dictionary]) -> void:
	shelf.clear()
	for offer in offers:
		var unit: UnitDefinition = offer.get("unit") as UnitDefinition
		if unit == null:
			continue
		shelf.append({
			"unit": unit.duplicate(true),
			"price": int(offer.get("price", 0)),
			"sold_out": false,
		})
	_ensure_visuals()


func mark_sold(index: int) -> void:
	if index < 0 or index >= shelf.size():
		return
	shelf[index]["sold_out"] = true


func is_captain_near(captain: Node2D) -> bool:
	if captain == null or not is_instance_valid(captain):
		return false
	return global_position.distance_to(captain.global_position) <= INTERACT_RADIUS


func _process(_delta: float) -> void:
	if _hint == null:
		return
	_hint.visible = captain_in_range


func try_interact() -> bool:
	if not captain_in_range:
		return false
	interact_requested.emit(self)
	return true


func set_captain_in_range(value: bool) -> void:
	captain_in_range = value


func _ensure_visuals() -> void:
	if _body == null:
		_body = ColorRect.new()
		_body.size = Vector2(72, 56)
		_body.position = Vector2(-36, -28)
		_body.color = Color(0.35, 0.55, 0.75, 1.0)
		add_child(_body)
	if _label == null:
		_label = Label.new()
		_label.text = "商店"
		_label.position = Vector2(-20, -48)
		_label.add_theme_font_size_override("font_size", 16)
		add_child(_label)
	if _hint == null:
		_hint = Label.new()
		_hint.text = "[E/空格] 打开货架"
		_hint.position = Vector2(-52, 34)
		_hint.add_theme_font_size_override("font_size", 12)
		_hint.visible = false
		add_child(_hint)
	if _area == null:
		_area = Area2D.new()
		_area.name = "InteractArea"
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = INTERACT_RADIUS
		shape.shape = circle
		_area.add_child(shape)
		add_child(_area)
