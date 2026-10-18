class_name DamagePopup
extends Node2D
## Floating damage number with a short scale punch.


func setup(amount: int, color: Color = Color(1.0, 0.35, 0.3, 1.0)) -> void:
	z_index = 40
	var label := Label.new()
	label.text = str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	var font: Font = UiFonts.get_font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.position = Vector2(-18, -12)
	add_child(label)
	scale = Vector2(0.55, 0.55)
	var drift_x := randf_range(-14.0, 14.0)
	var end_pos := global_position + Vector2(drift_x, -48)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.28, 1.28), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.1)
	tw.parallel().tween_property(self, "global_position", end_pos, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.28)
	tw.tween_callback(queue_free)


static func spawn(parent: Node, at: Vector2, amount: int, color: Color = Color(1.0, 0.35, 0.3, 1.0)) -> void:
	if parent == null or amount <= 0:
		return
	var popup := DamagePopup.new()
	parent.add_child(popup)
	popup.global_position = at + Vector2(randf_range(-6.0, 6.0), -28)
	popup.setup(amount, color)
