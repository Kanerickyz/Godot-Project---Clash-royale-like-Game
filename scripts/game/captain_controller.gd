class_name CaptainController
extends Node
## Keeps a Camera2D locked onto the captain.


@export var camera: Camera2D
@export var follow_lerp: float = 8.0

var captain: Node2D


func bind_captain(p_captain: Node2D) -> void:
	captain = p_captain
	if camera != null and captain != null:
		camera.global_position = captain.global_position
		camera.make_current()


func _process(delta: float) -> void:
	if camera == null or captain == null or not is_instance_valid(captain):
		return
	var t := clampf(follow_lerp * delta, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(captain.global_position, t)
