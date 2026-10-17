class_name DamagePopup
extends Node2D
## Floating damage number.


func setup(amount: int, color: Color = Color(1.0, 0.35, 0.3, 1.0)) -> void:
	z_index = 40
	var label := Label.new()
	label.text = str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	var font: Font = UiFonts.get_font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.position = Vector2(-16, -10)
	add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", global_position + Vector2(0, -42), 0.55).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tw.chain().tween_callback(queue_free)


static func spawn(parent: Node, at: Vector2, amount: int, color: Color = Color(1.0, 0.35, 0.3, 1.0)) -> void:
	if parent == null or amount <= 0:
		return
	var popup := DamagePopup.new()
	parent.add_child(popup)
	popup.global_position = at + Vector2(0, -28)
	popup.setup(amount, color)
