class_name GoldPickup
extends Area2D
## World gold coin; captain must walk over to collect.


signal collected(amount: int)

const PICK_RADIUS := 28.0

var amount: int = 1
var _label: Label
var _visual: Polygon2D
var _taken: bool = false


func configure(p_amount: int) -> void:
	amount = maxi(1, p_amount)
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2  # allies
	_ensure_visuals()
	body_entered.connect(_on_body_entered)
	var bob := create_tween()
	bob.set_loops()
	bob.tween_property(_visual, "position:y", -4.0, 0.45).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_visual, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE)


func _ensure_visuals() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = PICK_RADIUS
		shape.shape = circle
		add_child(shape)
	if _visual == null:
		_visual = Polygon2D.new()
		_visual.polygon = PackedVector2Array([
			Vector2(0, -10), Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0),
		])
		_visual.color = Color(0.95, 0.8, 0.2, 1.0)
		add_child(_visual)
	if _label == null:
		_label = Label.new()
		_label.text = "+%d" % amount
		_label.position = Vector2(-14, -28)
		_label.add_theme_font_size_override("font_size", 12)
		_label.add_theme_color_override("font_color", Color(1, 0.92, 0.4, 1))
		var font: Font = UiFonts.get_font()
		if font != null:
			_label.add_theme_font_override("font", font)
		add_child(_label)


func _on_body_entered(body: Node2D) -> void:
	if _taken or amount <= 0:
		return
	if body is SquadMember and (body as SquadMember).is_captain:
		_taken = true
		collected.emit(amount)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(0.2, 0.2), 0.15)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
		tw.tween_callback(queue_free)
