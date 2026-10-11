class_name SettingsPanel
extends Control

signal closed

@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_label: Label = %VolumeLabel
@onready var _fullscreen_check: CheckBox = %FullscreenCheck
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	visible = false
	_volume_slider.value_changed.connect(_on_volume_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_back_button.pressed.connect(_on_back_pressed)


func open() -> void:
	_volume_slider.value = GameSettings.master_volume
	_fullscreen_check.button_pressed = GameSettings.fullscreen
	_update_volume_label(GameSettings.master_volume)
	visible = true
	_volume_slider.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _on_volume_changed(value: float) -> void:
	GameSettings.master_volume = value
	_update_volume_label(value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	GameSettings.fullscreen = enabled


func _on_back_pressed() -> void:
	close()


func _update_volume_label(value: float) -> void:
	_volume_label.text = "主音量：%d%%" % int(round(value * 100.0))
