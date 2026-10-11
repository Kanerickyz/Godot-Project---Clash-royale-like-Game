class_name TierUnlock
extends RefCounted


static func get_max_unlocked_tier(shop_wave: int) -> int:
	var wave := maxi(1, shop_wave)
	if wave <= 2:
		return 1
	if wave <= 4:
		return 2
	if wave <= 6:
		return 3
	if wave <= 8:
		return 4
	if wave <= 10:
		return 5
	return 6


static func filter_by_tier(items: Array, get_tier: Callable, max_tier: int) -> Array:
	var filtered: Array = []
	for item in items:
		if item == null:
			continue
		var tier: int = int(get_tier.call(item))
		if tier <= max_tier:
			filtered.append(item)
	return filtered
