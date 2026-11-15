class_name ShopService
extends RefCounted
## Phase B interstitial shop logic: shelf, buy/refresh/recruit level, type cap, sell helpers.


const RESULT_OK := &"ok"
const RESULT_NOT_ENOUGH := &"not_enough"
const RESULT_TYPE_CAP := &"type_cap"
const RESULT_SOLD_OUT := &"sold_out"
const RESULT_BAD_SLOT := &"bad_slot"
const RESULT_MAX_LEVEL := &"max_level"
const RESULT_NO_POOL := &"no_pool"

var config: ShopEconomyConfig
var recruit_level: int = 1
var shelf: Array[Dictionary] = []  # {unit: UnitDefinition, price: int, sold_out: bool}
var last_interest: int = 0

var _pool: Array[UnitDefinition] = []
var _by_rarity: Dictionary = {}  # int -> Array[UnitDefinition]


func configure(cfg: ShopEconomyConfig, pool: Array[UnitDefinition]) -> void:
	config = cfg if cfg != null else ShopEconomyConfig.new()
	recruit_level = config.recruit_level_min
	last_interest = 0
	_pool.clear()
	_by_rarity.clear()
	for unit in pool:
		if unit == null:
			continue
		var copy := unit.duplicate(true) as UnitDefinition
		_pool.append(copy)
		var tier := clampi(copy.rarity_tier, 1, 3)
		if not _by_rarity.has(tier):
			_by_rarity[tier] = []
		(_by_rarity[tier] as Array).append(copy)
	shelf.clear()


func settle_interest(balance: int) -> int:
	last_interest = config.calc_interest(balance) if config != null else 0
	return last_interest


func roll_shelf(rng: RandomNumberGenerator) -> void:
	shelf.clear()
	if config == null or _pool.is_empty():
		return
	var slots := maxi(1, config.shelf_slot_count)
	for _i in slots:
		var unit := _pick_weighted_unit(rng)
		if unit == null:
			continue
		shelf.append({
			"unit": unit.duplicate(true),
			"price": config.price_for(unit),
			"sold_out": false,
		})


func try_buy(slot_index: int, balance: int, owned_type_ids: Array) -> Dictionary:
	## Returns {ok: bool, code: StringName, cost: int, unit: UnitDefinition}
	if slot_index < 0 or slot_index >= shelf.size():
		return {"ok": false, "code": RESULT_BAD_SLOT, "cost": 0, "unit": null}
	var slot: Dictionary = shelf[slot_index]
	if bool(slot.get("sold_out", false)):
		return {"ok": false, "code": RESULT_SOLD_OUT, "cost": 0, "unit": null}
	var unit: UnitDefinition = slot.get("unit") as UnitDefinition
	if unit == null:
		return {"ok": false, "code": RESULT_BAD_SLOT, "cost": 0, "unit": null}
	var cost := int(slot.get("price", config.price_for(unit) if config != null else 0))
	if balance < cost:
		return {"ok": false, "code": RESULT_NOT_ENOUGH, "cost": cost, "unit": unit}
	if not can_add_unit_type(owned_type_ids, unit.id):
		return {"ok": false, "code": RESULT_TYPE_CAP, "cost": cost, "unit": unit}
	slot["sold_out"] = true
	return {"ok": true, "code": RESULT_OK, "cost": cost, "unit": unit.duplicate(true)}


func try_refresh(balance: int, rng: RandomNumberGenerator) -> Dictionary:
	## Returns {ok: bool, code: StringName, cost: int}
	if config == null or _pool.is_empty():
		return {"ok": false, "code": RESULT_NO_POOL, "cost": 0}
	var cost := maxi(0, config.refresh_cost)
	if balance < cost:
		return {"ok": false, "code": RESULT_NOT_ENOUGH, "cost": cost}
	roll_shelf(rng)
	return {"ok": true, "code": RESULT_OK, "cost": cost}


func try_upgrade_recruit(balance: int) -> Dictionary:
	## Returns {ok: bool, code: StringName, cost: int, level: int}
	if config == null:
		return {"ok": false, "code": RESULT_MAX_LEVEL, "cost": 0, "level": recruit_level}
	if recruit_level >= config.recruit_level_max:
		return {"ok": false, "code": RESULT_MAX_LEVEL, "cost": 0, "level": recruit_level}
	var cost := config.upgrade_cost_for(recruit_level)
	if cost < 0:
		return {"ok": false, "code": RESULT_MAX_LEVEL, "cost": 0, "level": recruit_level}
	if balance < cost:
		return {"ok": false, "code": RESULT_NOT_ENOUGH, "cost": cost, "level": recruit_level}
	recruit_level += 1
	return {"ok": true, "code": RESULT_OK, "cost": cost, "level": recruit_level}


func sell_refund(unit: UnitDefinition) -> int:
	if config == null or unit == null:
		return 0
	return config.sell_refund_for(unit)


func can_add_unit_type(owned_type_ids: Array, new_id: StringName) -> bool:
	if config == null:
		return true
	var unique := _unique_type_count(owned_type_ids)
	for id_v in owned_type_ids:
		if StringName(str(id_v)) == new_id:
			return true  # already owned type: OK
	return unique < config.max_unit_types


func count_unique_types(owned_type_ids: Array) -> int:
	return _unique_type_count(owned_type_ids)


func get_upgrade_cost() -> int:
	if config == null:
		return -1
	return config.upgrade_cost_for(recruit_level)


func get_refresh_cost() -> int:
	if config == null:
		return 0
	return maxi(0, config.refresh_cost)


func _unique_type_count(owned_type_ids: Array) -> int:
	var seen: Dictionary = {}
	for id_v in owned_type_ids:
		var key := StringName(str(id_v))
		if key == &"":
			continue
		seen[key] = true
	return seen.size()


func _pick_weighted_unit(rng: RandomNumberGenerator) -> UnitDefinition:
	if _pool.is_empty():
		return null
	var weights := config.weights_for_level(recruit_level) if config != null else PackedInt32Array([80, 18, 2])
	var total := 0
	for w in weights:
		total += maxi(0, int(w))
	if total <= 0:
		return _pool[rng.randi_range(0, _pool.size() - 1)] if rng != null else _pool[0]
	var roll := rng.randi_range(0, total - 1) if rng != null else 0
	var chosen_tier := 1
	var acc := 0
	for i in mini(3, weights.size()):
		acc += maxi(0, int(weights[i]))
		if roll < acc:
			chosen_tier = i + 1
			break
	var bucket: Array = _by_rarity.get(chosen_tier, []) as Array
	if bucket.is_empty():
		# Fall back to any pool unit.
		return _pool[rng.randi_range(0, _pool.size() - 1)] if rng != null else _pool[0]
	var pick: UnitDefinition = bucket[rng.randi_range(0, bucket.size() - 1)] if rng != null else bucket[0]
	return pick
