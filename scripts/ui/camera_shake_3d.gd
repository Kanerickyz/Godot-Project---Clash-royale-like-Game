class_name CameraShake3D
extends Node

var _camera: Camera3D
var _amplitude: float = 0.0
var _rest_h: float = 0.0
var _rest_v: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var parent := get_parent()
	if parent is Camera3D:
		bind_camera(parent as Camera3D)


func bind_camera(camera: Camera3D) -> void:
	_camera = camera
	if _camera != null:
		_rest_h = _camera.h_offset
		_rest_v = _camera.v_offset


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
		_camera.h_offset = _rest_h
		_camera.v_offset = _rest_v


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
	_camera.h_offset = _rest_h + shake.x
	_camera.v_offset = _rest_v + shake.y
