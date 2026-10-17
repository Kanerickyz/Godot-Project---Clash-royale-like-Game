class_name RoamShop
extends Node2D
## Fixed-shelf shop building. Interact when captain is in range.


signal interact_requested(shop: RoamShop)

const INTERACT_RADIUS := 72.0

var shelf: Array[Dictionary] = []  # {unit: UnitDefinition, price: int, sold_out: bool}
var _body: ColorRect
var _label: Label
var _hint: Label
var _progress: ColorRect
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


func set_idle_progress(ratio: float) -> void:
	if _progress == null:
		return
	var t := clampf(ratio, 0.0, 1.0)
	_progress.visible = t > 0.0 and captain_in_range
	_progress.size.x = 72.0 * t


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
		var font: Font = UiFonts.get_font()
		if font != null:
			_label.add_theme_font_override("font", font)
		add_child(_label)
	if _hint == null:
		_hint = Label.new()
		_hint.text = "附近站住 3 秒打开"
		_hint.position = Vector2(-52, 34)
		_hint.add_theme_font_size_override("font_size", 12)
		var hint_font: Font = UiFonts.get_font()
		if hint_font != null:
			_hint.add_theme_font_override("font", hint_font)
		_hint.visible = false
		add_child(_hint)
	if _progress == null:
		var bg := ColorRect.new()
		bg.name = "IdleProgressBg"
		bg.size = Vector2(72, 6)
		bg.position = Vector2(-36, 52)
		bg.color = Color(0.1, 0.1, 0.12, 0.7)
		add_child(bg)
		_progress = ColorRect.new()
		_progress.name = "IdleProgress"
		_progress.size = Vector2(0, 6)
		_progress.position = Vector2(-36, 52)
		_progress.color = Color(0.45, 0.85, 1.0, 0.9)
		_progress.visible = false
		add_child(_progress)
	if _area == null:
		_area = Area2D.new()
		_area.name = "InteractArea"
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = INTERACT_RADIUS
		shape.shape = circle
		_area.add_child(shape)
		add_child(_area)
