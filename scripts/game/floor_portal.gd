class_name FloorPortal
extends Area2D
## Exit portal: always enterable when captain is in range and confirms.
## Presentation-only visuals; enter rules live in GameController.


signal confirm_requested(portal: FloorPortal)

const PATH_MARKER := "res://assets/sprites/paper_cutout/units/unit_banner_blue.png"

@export var interact_radius: float = 90.0

var _sprite: Sprite2D
var _marker: Sprite2D
var _label: Label
var _hint: Label
var _pulse: Tween
var _captain_near: bool = false


func configure(radius: float = 90.0) -> void:
	interact_radius = maxf(24.0, radius)
	_ensure_visuals()
	_ensure_collision()
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 0


func set_captain_near(near: bool) -> void:
	var changed := near != _captain_near
	_captain_near = near
	if _hint != null:
		_hint.visible = near
	if _label != null:
		_label.modulate = Color(1.0, 0.95, 0.45, 1.0) if near else Color(0.92, 0.96, 1.0, 1.0)
	if _sprite != null:
		_sprite.modulate = Color(1.15, 1.1, 0.85, 1.0) if near else Color.WHITE
	if _marker != null:
		_marker.modulate = Color(1.2, 1.15, 0.7, 1.0) if near else Color(0.95, 0.98, 1.0, 0.95)
	if changed:
		_restart_pulse()


func is_captain_near() -> bool:
	return _captain_near


func _ensure_visuals() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.centered = true
		_sprite.texture = _build_portal_ring_texture()
		_sprite.scale = Vector2(1.55, 1.55)
		_sprite.z_index = 0
		add_child(_sprite)
	if _marker == null:
		_marker = Sprite2D.new()
		_marker.name = "Marker"
		_marker.centered = true
		_marker.position = Vector2(0, -8)
		_marker.z_index = 1
		var tex: Texture2D = load(PATH_MARKER) as Texture2D
		if tex != null:
			_marker.texture = tex
			_marker.scale = Vector2(0.18, 0.18)
			_marker.modulate = Color(0.95, 0.98, 1.0, 0.95)
		else:
			# Keep a bright core if banner asset missing.
			var core := Image.create(24, 24, false, Image.FORMAT_RGBA8)
			core.fill(Color(0.55, 0.8, 1.0, 0.9))
			_marker.texture = ImageTexture.create_from_image(core)
			_marker.scale = Vector2(1.2, 1.2)
		add_child(_marker)
	if _label == null:
		_label = Label.new()
		_label.text = "传送门"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.position = Vector2(-48, -86)
		_label.size = Vector2(96, 28)
		_label.add_theme_font_size_override("font_size", 18)
		_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.14, 0.95))
		_label.add_theme_constant_override("outline_size", 4)
		var font: Font = UiFonts.get_font()
		if font != null:
			_label.add_theme_font_override("font", font)
		_label.modulate = Color(0.92, 0.96, 1.0, 1.0)
		_label.z_index = 2
		add_child(_label)
	if _hint == null:
		_hint = Label.new()
		_hint.text = "按 E / 确认 进入"
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Above portal (not below) so it does not collide with bottom command buttons.
		_hint.position = Vector2(-88, -118)
		_hint.size = Vector2(176, 24)
		_hint.add_theme_font_size_override("font_size", 14)
		_hint.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.02, 0.95))
		_hint.add_theme_constant_override("outline_size", 3)
		var font2: Font = UiFonts.get_font()
		if font2 != null:
			_hint.add_theme_font_override("font", font2)
		_hint.modulate = Color(1.0, 0.94, 0.55, 1.0)
		_hint.visible = false
		_hint.z_index = 2
		add_child(_hint)
	_restart_pulse()


func _build_portal_ring_texture() -> ImageTexture:
	## High-contrast procedural ring (no dedicated portal PNG in paper_cutout/env).
	var size := 72
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(size - 1) * 0.5
	var cy := cx
	for y in size:
		for x in size:
			var dx := float(x) - cx
			var dy := float(y) - cy
			var d := sqrt(dx * dx + dy * dy)
			if d > 33.5:
				continue
			elif d > 30.0:
				# Outer rim: bright ice / parchment edge for silhouette.
				img.set_pixel(x, y, Color(0.92, 0.96, 1.0, 0.98))
			elif d > 26.0:
				img.set_pixel(x, y, Color(0.2, 0.35, 0.7, 0.95))
			elif d > 16.0:
				img.set_pixel(x, y, Color(0.12, 0.2, 0.42, 0.55))
			elif d > 10.0:
				img.set_pixel(x, y, Color(0.35, 0.55, 0.95, 0.72))
			else:
				img.set_pixel(x, y, Color(0.55, 0.75, 1.0, 0.85))
	return ImageTexture.create_from_image(img)


func _ensure_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = interact_radius


func _restart_pulse() -> void:
	if _sprite == null:
		return
	if _pulse != null and is_instance_valid(_pulse):
		_pulse.kill()
	var lo := Vector2(1.5, 1.5) if _captain_near else Vector2(1.45, 1.45)
	var hi := Vector2(1.78, 1.78) if _captain_near else Vector2(1.62, 1.62)
	var beat := 0.55 if _captain_near else 0.75
	_sprite.scale = lo
	_pulse = create_tween()
	_pulse.set_loops()
	_pulse.tween_property(_sprite, "scale", hi, beat).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_sprite, "scale", lo, beat).set_trans(Tween.TRANS_SINE)
