class_name ShopOffer
extends RefCounted

enum OfferType { CHARACTER, BUFF }

var type: OfferType = OfferType.CHARACTER
var unit: UnitData
var buff: BuffCardData
var shop_bonus_max_hp: int = 0


func get_cost() -> int:
	match type:
		OfferType.CHARACTER:
			if unit != null:
				return maxi(0, unit.cost)
		OfferType.BUFF:
			if buff != null:
				return maxi(0, buff.shop_cost)
	return 0


func get_display_name() -> String:
	match type:
		OfferType.CHARACTER:
			if unit != null and not unit.display_name.is_empty():
				return unit.display_name
			if unit != null:
				return unit.id
		OfferType.BUFF:
			if buff != null and not buff.display_name.is_empty():
				return buff.display_name
			if buff != null:
				return buff.id
	return "—"


func get_type_label() -> String:
	match type:
		OfferType.CHARACTER:
			return "角色"
		OfferType.BUFF:
			return "增益"
	return ""
