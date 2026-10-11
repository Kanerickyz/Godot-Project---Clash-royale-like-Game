class_name CameraShake
extends Node

var _camera: Camera2D
var _amplitude: float = 0.0
var _rest_offset: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var parent := get_parent()
	if parent is Camera2D:
		bind_camera(parent as Camera2D)


func bind_camera(camera: Camera2D) -> void:
	_camera = camera
	if _camera != null:
		_rest_offset = _camera.offset


func add_impulse(intensity: float) -> void:
	if _camera == null or intensity <= 0.0:
		return
	_amplitude = minf(
		_amplitude + intensity,
		CombatAnimationConfig.SHAKE_MAX_AMPLITUDE * CombatAnimationConfig.SHAKE_AMPLITUDE_SCALE,
	)
	if not is_processing():
		set_process(true)


func reset() -> void:
	_amplitude = 0.0
	set_process(false)
	if _camera != null:
		_camera.offset = _rest_offset


func _process(delta: float) -> void:
	if _camera == null:
		set_process(false)
		return
	if _amplitude < 0.15:
		reset()
		return
	_amplitude *= exp(-CombatAnimationConfig.SHAKE_DECAY * delta)
	var shake := Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0),
	) * _amplitude
	_camera.offset = _rest_offset + shake
