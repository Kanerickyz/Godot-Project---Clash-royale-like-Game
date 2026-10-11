class_name CombatSkillCallout
extends PanelContainer

const VIEWPORT_PADDING := 12.0
const ANCHOR_OFFSET := Vector2(0.0, -8.0)

@onready var _name_label: Label = %NameLabel
@onready var _skill_label: Label = %SkillLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_skill(
	owner: UnitInstance,
	spec: EffectSpec,
	action: EffectAction,
	anchor_global: Vector2,
) -> void:
	if owner == null:
		hide_callout()
		return
	_name_label.text = UnitInfoText.get_display_name(owner)
	if spec != null:
		_skill_label.text = UnitInfoText.format_effect_spec(spec)
	elif action != null:
		_skill_label.text = UnitInfoText.format_action(action)
	else:
		_skill_label.text = "无效果描述"
	visible = true
	call_deferred("_reposition", anchor_global + ANCHOR_OFFSET)


func hide_callout() -> void:
	visible = false


func show_failed(
	owner: UnitInstance,
	message: String,
	anchor_global: Vector2,
) -> void:
	if owner == null:
		hide_callout()
		return
	_name_label.text = UnitInfoText.get_display_name(owner)
	_skill_label.text = message if not message.is_empty() else "技能失败"
	visible = true
	call_deferred("_reposition", anchor_global + ANCHOR_OFFSET)


func _reposition(anchor_global: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var pos := anchor_global - Vector2(size.x * 0.5, size.y)
	pos.x = clampf(pos.x, VIEWPORT_PADDING, viewport_size.x - size.x - VIEWPORT_PADDING)
	pos.y = clampf(pos.y, VIEWPORT_PADDING, viewport_size.y - size.y - VIEWPORT_PADDING)
	global_position = pos
