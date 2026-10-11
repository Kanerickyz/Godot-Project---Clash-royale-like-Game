class_name TeleportAfterimage
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

	var ghost := TeleportAfterimage.new()
	ghost.position = world_pos
	ghost.z_index = 0
	parent.add_child(ghost)
	ghost._play(tint, cell_size, duration)


func _play(tint: Color, cell_size: int, duration: float) -> void:
	var w := float(cell_size) * 0.52
	var h := float(cell_size) * 0.62
	var silhouette := Polygon2D.new()
	silhouette.polygon = PackedVector2Array([
		Vector2(-w, -h * 0.15),
		Vector2(-w * 0.85, -h),
		Vector2(w * 0.85, -h),
		Vector2(w, -h * 0.15),
		Vector2(w * 0.72, h * 0.55),
		Vector2(-w * 0.72, h * 0.55),
	])
	silhouette.color = tint
	silhouette.modulate.a = CombatAnimationConfig.TELEPORT_GHOST_ALPHA
	add_child(silhouette)

	scale = Vector2.ONE
	var end_scale := Vector2.ONE * CombatAnimationConfig.TELEPORT_GHOST_SCALE_END
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(silhouette, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", end_scale, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
