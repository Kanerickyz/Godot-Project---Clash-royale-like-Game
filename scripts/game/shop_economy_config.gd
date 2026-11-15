class_name ShopEconomyConfig
extends Resource
## Phase B tunables: ducats wallet, interest, shelf, recruit level, type cap, sell.


@export_group("Wallet")
@export var starting_ducats: int = 20
## Chest smash reward in ducats (Phase A placeholder replaced).
@export var chest_ducats: int = 8

@export_group("Interest")
## Every N ducats of current balance → 1 interest when entering interstitial.
@export var interest_gold_per_point: int = 10
@export var interest_max: int = 5

@export_group("Shop")
@export var shelf_slot_count: int = 3
@export var refresh_cost: int = 2
@export var max_unit_types: int = 6
## Sell refund = floor(price * sell_refund_ratio).
@export var sell_refund_ratio: float = 0.5
## Fallback prices by rarity_tier 1..N when unit.shop_price <= 0.
@export var rarity_prices: PackedInt32Array = PackedInt32Array([3, 5, 8])

@export_group("Recruit Level")
@export var recruit_level_min: int = 1
@export var recruit_level_max: int = 5
## Cost to upgrade FROM level i to i+1 (index 0 = 1→2). Empty → derived.
@export var recruit_upgrade_costs: PackedInt32Array = PackedInt32Array([4, 6, 8, 10])

@export_group("Rarity Weights")
## Per recruit level (1-based), weight for rarity tiers 1/2/3. Length = level_max * 3.
## Default: L1=[80,18,2] L2=[65,28,7] L3=[50,35,15] L4=[35,40,25] L5=[20,40,40]
@export var rarity_weights_by_level: PackedInt32Array = PackedInt32Array([
	80, 18, 2,
	65, 28, 7,
	50, 35, 15,
	35, 40, 25,
	20, 40, 40,
])

@export_group("Pool")
@export var pool_unit_paths: PackedStringArray = PackedStringArray([
	"res://resources/units/ally_skeleton.tres",
	"res://resources/units/ally_spear.tres",
	"res://resources/units/ally_shield.tres",
	"res://resources/units/ally_axe.tres",
	"res://resources/units/ally_archer.tres",
	"res://resources/units/ally_hunter.tres",
	"res://resources/units/ally_musket.tres",
])


func calc_interest(balance: int) -> int:
	if balance <= 0 or interest_gold_per_point <= 0 or interest_max <= 0:
		return 0
	return mini(interest_max, int(balance / interest_gold_per_point))


func price_for(unit: UnitDefinition) -> int:
	if unit == null:
		return 0
	if unit.shop_price > 0:
		return unit.shop_price
	var tier := clampi(unit.rarity_tier, 1, maxi(1, rarity_prices.size()))
	var idx := tier - 1
	if idx >= 0 and idx < rarity_prices.size():
		return maxi(1, rarity_prices[idx])
	return 3


func sell_refund_for(unit: UnitDefinition) -> int:
	var price := price_for(unit)
	return maxi(0, int(floor(float(price) * sell_refund_ratio)))


func upgrade_cost_for(current_level: int) -> int:
	if current_level >= recruit_level_max:
		return -1
	var idx := current_level - recruit_level_min
	if idx < 0:
		idx = 0
	if idx < recruit_upgrade_costs.size():
		return maxi(0, recruit_upgrade_costs[idx])
	# Fallback curve: 4 + 2 * idx
	return 4 + 2 * idx


func weights_for_level(level: int) -> PackedInt32Array:
	var lv := clampi(level, recruit_level_min, recruit_level_max)
	var base := (lv - recruit_level_min) * 3
	var out := PackedInt32Array([80, 18, 2])
	if rarity_weights_by_level.size() >= base + 3:
		out[0] = maxi(0, rarity_weights_by_level[base])
		out[1] = maxi(0, rarity_weights_by_level[base + 1])
		out[2] = maxi(0, rarity_weights_by_level[base + 2])
	return out
