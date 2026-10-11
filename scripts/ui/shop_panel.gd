class_name ShopPanel
extends Control

signal character_buy_pressed(slot_index: int)
signal buff_buy_pressed(slot_index: int)
signal refresh_pressed
signal offer_hovered(offer: ShopOffer)
signal offer_unhovered

const SLOT_SCENE := preload("res://scenes/ui/shop_slot.tscn")

@onready var _character_slots_row: HBoxContainer = %CharacterSlotsRow
@onready var _buff_slots_row: HBoxContainer = %BuffSlotsRow
@onready var _refresh_button: Button = %RefreshButton
@onready var _tier_unlock_toast: TierUnlockToast = %TierUnlockToast

var _character_slot_widgets: Array[Control] = []
var _buff_slot_widgets: Array[Control] = []


func _ready() -> void:
	_refresh_button.pressed.connect(func() -> void: refresh_pressed.emit())


func setup(character_count: int, buff_count: int) -> void:
	_build_slots(_character_slots_row, _character_slot_widgets, character_count, true)
	_build_slots(_buff_slots_row, _buff_slot_widgets, buff_count, false)


func show_tier_unlock(tier: int) -> void:
	if _tier_unlock_toast != null:
		_tier_unlock_toast.show_unlock(tier)


func hide_tier_unlock() -> void:
	if _tier_unlock_toast != null:
		_tier_unlock_toast.hide_immediately()


func set_interactive(enabled: bool) -> void:
	_refresh_button.disabled = not enabled
	for slot in _character_slot_widgets:
		if slot.has_method("set_interactive"):
			slot.set_interactive(enabled)
	for slot in _buff_slot_widgets:
		if slot.has_method("set_interactive"):
			slot.set_interactive(enabled)


func refresh_slots(
	character_offers: Array,
	buff_offers: Array,
	refresh_cost: int,
	gold: int,
) -> void:
	_refresh_button.text = "刷新 (%d)" % refresh_cost
	_refresh_button.disabled = gold < refresh_cost
	_refresh_slot_row(_character_slot_widgets, character_offers, gold)
	_refresh_slot_row(_buff_slot_widgets, buff_offers, gold)


func _build_slots(
	row: HBoxContainer,
	widgets: Array[Control],
	slot_count: int,
	is_character: bool,
) -> void:
	for child in row.get_children():
		child.queue_free()
	widgets.clear()

	for i in slot_count:
		var slot: Control = SLOT_SCENE.instantiate()
		row.add_child(slot)
		if slot.has_method("set_show_type_label"):
			slot.set_show_type_label(false)
		var index := i
		if slot.has_signal("buy_pressed"):
			if is_character:
				slot.buy_pressed.connect(
					func() -> void: character_buy_pressed.emit(index)
				)
			else:
				slot.buy_pressed.connect(
					func() -> void: buff_buy_pressed.emit(index)
				)
		if slot.has_signal("offer_hovered"):
			slot.offer_hovered.connect(_on_slot_offer_hovered)
		if slot.has_signal("offer_unhovered"):
			slot.offer_unhovered.connect(_on_slot_offer_unhovered)
		widgets.append(slot)


func _refresh_slot_row(
	widgets: Array[Control],
	offers: Array,
	gold: int,
) -> void:
	for i in widgets.size():
		var offer: ShopOffer = offers[i] if i < offers.size() else null
		var slot: Control = widgets[i]
		if slot.has_method("set_offer"):
			slot.set_offer(offer, gold)


func _on_slot_offer_hovered(offer: ShopOffer) -> void:
	offer_hovered.emit(offer)


func _on_slot_offer_unhovered() -> void:
	offer_unhovered.emit()
