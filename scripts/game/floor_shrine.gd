class_name FloorShrine
extends StaticBody2D
## Phase E floor shrine: captain proximity → short buff or corpus choice.


signal activated(shrine: FloorShrine)

var used: bool = false
var _label: Label
var _visual: Polygon2D
var _ring: Polygon2D


func configure() -> void:
	used = false
	collision_layer = 0
	collision_mask = 0
	add_to_group(&"shrines")
	_ensure_visuals()
	_update_label()


func is_used() -> bool:
	return used


func mark_used() -> void:
	used = true
	_update_label()
	if _visual != null:
		_visual.color = Color(0.35, 0.38, 0.42, 0.7)
	if _ring != null:
		_ring.color = Color(0.4, 0.42, 0.45, 0.35)


func _ensure_visuals() -> void:
	if _ring == null:
		_ring = Polygon2D.new()
		_ring.name = "Ring"
		var pts := PackedVector2Array()
		for i in 12:
			var a := float(i) / 12.0 * TAU
			pts.append(Vector2(cos(a), sin(a)) * 34.0)
		_ring.polygon = pts
		_ring.color = Color(0.45, 0.7, 0.85, 0.35)
		add_child(_ring)
	if _visual == null:
		_visual = Polygon2D.new()
		_visual.name = "Stone"
		_visual.polygon = PackedVector2Array([
			Vector2(0, -28), Vector2(16, -8), Vector2(12, 18), Vector2(-12, 18), Vector2(-16, -8),
		])
		_visual.color = Color(0.55, 0.62, 0.78, 1.0)
		add_child(_visual)
	if _label == null:
		_label = Label.new()
		_label.position = Vector2(-22, -48)
		_label.add_theme_font_size_override("font_size", 12)
		_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 1.0))
		var font: Font = UiFonts.get_font()
		if font != null:
			_label.add_theme_font_override("font", font)
		add_child(_label)


func _update_label() -> void:
	if _label == null:
		return
	_label.text = "神龛(已用)" if used else "神龛"
