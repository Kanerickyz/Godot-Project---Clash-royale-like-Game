class_name CombatVictoryOverlay
extends Control

const _VICTORY_TITLE_COLOR := Color(0.98, 0.88, 0.38, 1.0)
const _VICTORY_GOLD_COLOR := Color(0.55, 0.95, 0.65, 1.0)
const _VICTORY_BORDER_COLOR := Color(0.95, 0.78, 0.22, 1.0)
const _DEFEAT_TITLE_COLOR := Color(0.95, 0.45, 0.42, 1.0)
const _DEFEAT_BORDER_COLOR := Color(0.82, 0.32, 0.28, 1.0)

@onready var _dim: ColorRect = %Dim
@onready var _panel: PanelContainer = %Panel
@onready var _title_label: Label = %TitleLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _collect_button: Button = %CollectButton

var _active_tween: Tween
var _panel_style: StyleBoxFlat
var _awaiting_dismiss: bool = false
var _dismiss_requested: bool = false


func _ready() -> void:
	var base_style := _panel.get_theme_stylebox("panel")
	if base_style is StyleBoxFlat:
		_panel_style = base_style.duplicate() as StyleBoxFlat
	_collect_button.pressed.connect(_on_collect_pressed)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_visual_state()


func play_victory(wave_gold: int, wave_number: int, level_complete: bool) -> void:
	if level_complete:
		_apply_content(
			"关卡完成！",
			"+%d 金" % wave_gold,
			"全部 %d 波已通过 · 点击提现或等待自动进入商店" % wave_number,
			true,
		)
	else:
		_apply_content(
			"波次胜利！",
			"+%d 金" % wave_gold,
			"第 %d 波清扫完毕 · 点击提现或等待自动进入商店" % wave_number,
			true,
		)
	await _play_presentation(true)


func play_defeat(wave_number: int) -> void:
	_apply_content(
		"战斗失败",
		"",
		"第 %d 波未能守住 · 牌库重置并返回商店" % wave_number,
		false,
	)
	await _play_presentation(false)


func hide_immediately() -> void:
	_awaiting_dismiss = false
	_dismiss_requested = false
	_kill_tween()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_visual_state()


func _on_collect_pressed() -> void:
	if _awaiting_dismiss:
		_request_dismiss()


func _on_auto_continue_timeout() -> void:
	if _awaiting_dismiss:
		_request_dismiss()


func _request_dismiss() -> void:
	if _dismiss_requested:
		return
	_dismiss_requested = true
	_collect_button.disabled = true


func _apply_content(
	title: String,
	detail: String,
	subtitle: String,
	victory: bool,
) -> void:
	_title_label.text = title
	_subtitle_label.text = subtitle
	if victory:
		_title_label.add_theme_color_override("font_color", _VICTORY_TITLE_COLOR)
		_gold_label.add_theme_color_override("font_color", _VICTORY_GOLD_COLOR)
		_gold_label.text = detail
		_gold_label.visible = true
		_collect_button.visible = false
		if _panel_style != null:
			_panel_style.border_color = _VICTORY_BORDER_COLOR
			_panel.add_theme_stylebox_override("panel", _panel_style)
	else:
		_title_label.add_theme_color_override("font_color", _DEFEAT_TITLE_COLOR)
		_gold_label.visible = false
		_collect_button.visible = false
		if _panel_style != null:
			_panel_style.border_color = _DEFEAT_BORDER_COLOR
			_panel.add_theme_stylebox_override("panel", _panel_style)


func _play_presentation(victory: bool) -> void:
	_kill_tween()
	_reset_visual_state()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5

	_active_tween = _create_overlay_tween()
	_active_tween.set_parallel(true)
	var fade_in := CombatAnimationConfig.COMBAT_RESULT_OVERLAY_FADE_IN
	_active_tween.tween_property(_dim, "modulate:a", 1.0, fade_in)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_panel, "modulate:a", 1.0, fade_in)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_panel, "scale", Vector2.ONE, fade_in)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _active_tween.finished

	if victory:
		await _wait_victory_continue()
	else:
		await _wait_overlay_hold()

	_active_tween = _create_overlay_tween()
	_active_tween.set_parallel(true)
	var fade_out := CombatAnimationConfig.COMBAT_RESULT_OVERLAY_FADE_OUT
	_active_tween.tween_property(_dim, "modulate:a", 0.0, fade_out)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(_panel, "modulate:a", 0.0, fade_out)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(_panel, "scale", Vector2(0.94, 0.94), fade_out)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if victory and _collect_button.visible:
		_active_tween.tween_property(_collect_button, "modulate:a", 0.0, fade_out)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _active_tween.finished

	hide_immediately()


func _wait_victory_continue() -> void:
	_awaiting_dismiss = true
	_dismiss_requested = false
	_collect_button.text = "提现"
	_collect_button.disabled = false
	_collect_button.visible = true
	_collect_button.modulate.a = 1.0

	var hold_sec := CombatAnimationConfig.COMBAT_RESULT_OVERLAY_HOLD_SEC
	get_tree().create_timer(hold_sec, true).timeout.connect(
		_on_auto_continue_timeout,
		CONNECT_ONE_SHOT,
	)

	while not _dismiss_requested:
		await get_tree().process_frame

	_awaiting_dismiss = false


func _create_overlay_tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


func _wait_overlay_hold() -> void:
	var hold_sec := CombatAnimationConfig.COMBAT_RESULT_OVERLAY_HOLD_SEC
	await get_tree().create_timer(hold_sec, true).timeout


func _reset_visual_state() -> void:
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.92, 0.92)
	_panel.pivot_offset = _panel.size * 0.5
	_collect_button.visible = false
	_collect_button.disabled = true
	_collect_button.modulate.a = 1.0


func _kill_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
