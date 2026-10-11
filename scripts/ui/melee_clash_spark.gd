class_name MeleeClashSpark
extends Node2D

static func spawn(
	parent: Node2D,
	world_pos: Vector2,
	cell_size: int,
	tint: Color,
	duration: float,
) -> void:
	if parent == null or duration <= 0.0:
		return

	var spark := MeleeClashSpark.new()
	spark.position = world_pos
	spark.z_index = 0
	parent.add_child(spark)
	spark._play(tint, cell_size, duration)


func _play(tint: Color, cell_size: int, duration: float) -> void:
	var outer := float(cell_size) * 0.22
	var inner := outer * 0.42
	var star := Polygon2D.new()
	star.polygon = PackedVector2Array([
		Vector2(0.0, -outer),
		Vector2(inner, -inner),
		Vector2(outer, 0.0),
		Vector2(inner, inner),
		Vector2(0.0, outer),
		Vector2(-inner, inner),
		Vector2(-outer, 0.0),
		Vector2(-inner, -inner),
	])
	star.color = tint
	add_child(star)

	scale = Vector2.ONE
	var end_scale := Vector2.ONE * CombatAnimationConfig.MELEE_CLASH_SPARK_SCALE_END
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(star, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", end_scale, duration)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
