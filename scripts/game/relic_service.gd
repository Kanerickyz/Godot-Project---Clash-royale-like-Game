class_name RelicService
extends RefCounted
## Phase E interstitial relic shop: shelf buy/refresh, inventory cap, effect hooks.


const RESULT_OK := &"ok"
const RESULT_NOT_ENOUGH := &"not_enough"
const RESULT_SLOTS_FULL := &"slots_full"
const RESULT_SOLD_OUT := &"sold_out"
const RESULT_BAD_SLOT := &"bad_slot"
const RESULT_NO_POOL := &"no_pool"

var config: CorpusRelicsConfig
var shelf: Array[Dictionary] = []  # {relic: RelicDefinition, price: int, sold_out: bool}
var inventory: Array[RelicDefinition] = []

var _pool: Array[RelicDefinition] = []


func configure(cfg: CorpusRelicsConfig, pool: Array[RelicDefinition]) -> void:
	config = cfg if cfg != null else CorpusRelicsConfig.new()
	inventory.clear()
	shelf.clear()
	_pool.clear()
	for relic in pool:
		if relic == null:
			continue
		_pool.append(relic.duplicate(true) as RelicDefinition)


func clear_run() -> void:
	inventory.clear()
	shelf.clear()


func owned_count() -> int:
	return inventory.size()


func max_slots() -> int:
	return maxi(1, config.max_relic_slots) if config != null else 3


func slots_remaining() -> int:
	return maxi(0, max_slots() - owned_count())


func get_refresh_cost() -> int:
	return maxi(0, config.relic_refresh_cost) if config != null else 2


func roll_shelf(rng: RandomNumberGenerator) -> void:
	shelf.clear()
	if config == null or _pool.is_empty():
		return
	var slots := maxi(1, config.relic_shelf_slot_count)
	for _i in slots:
		var relic := _pick_relic(rng)
		if relic == null:
			continue
		shelf.append({
			"relic": relic.duplicate(true),
			"price": maxi(1, relic.price),
			"sold_out": false,
		})


func try_buy(slot_index: int, corpus_balance: int) -> Dictionary:
	## Returns {ok, code, cost, relic}
	if slot_index < 0 or slot_index >= shelf.size():
		return {"ok": false, "code": RESULT_BAD_SLOT, "cost": 0, "relic": null}
	var slot: Dictionary = shelf[slot_index]
	if bool(slot.get("sold_out", false)):
		return {"ok": false, "code": RESULT_SOLD_OUT, "cost": 0, "relic": null}
	var relic: RelicDefinition = slot.get("relic") as RelicDefinition
	if relic == null:
		return {"ok": false, "code": RESULT_BAD_SLOT, "cost": 0, "relic": null}
	var cost := int(slot.get("price", maxi(1, relic.price)))
	if corpus_balance < cost:
		return {"ok": false, "code": RESULT_NOT_ENOUGH, "cost": cost, "relic": relic}
	if owned_count() >= max_slots():
		return {"ok": false, "code": RESULT_SLOTS_FULL, "cost": cost, "relic": relic}
	slot["sold_out"] = true
	var owned := relic.duplicate(true) as RelicDefinition
	inventory.append(owned)
	return {"ok": true, "code": RESULT_OK, "cost": cost, "relic": owned}


func try_refresh(corpus_balance: int, rng: RandomNumberGenerator) -> Dictionary:
	## Returns {ok, code, cost}
	if config == null or _pool.is_empty():
		return {"ok": false, "code": RESULT_NO_POOL, "cost": 0}
	var cost := get_refresh_cost()
	if corpus_balance < cost:
		return {"ok": false, "code": RESULT_NOT_ENOUGH, "cost": cost}
	roll_shelf(rng)
	return {"ok": true, "code": RESULT_OK, "cost": cost}


func get_hud_rows() -> Array:
	var rows: Array = []
	for i in inventory.size():
		var r := inventory[i]
		if r == null:
			continue
		rows.append({
			"index": i,
			"id": r.id,
			"name": r.display_name,
			"description": r.description,
			"effect_kind": int(r.effect_kind),
			"effect_value": r.effect_value,
		})
	return rows


func revive_time_multiplier() -> float:
	## Product of (1 - shorten) over owned REVIVE_SHORTEN relics.
	var mult := 1.0
	for r in inventory:
		if r == null:
			continue
		if r.effect_kind != RelicDefinition.EffectKind.REVIVE_SHORTEN:
			continue
		mult *= maxf(0.05, 1.0 - maxf(0.0, r.effect_value))
	return mult


func damage_taken_multiplier() -> float:
	var mult := 1.0
	for r in inventory:
		if r == null:
			continue
		if r.effect_kind != RelicDefinition.EffectKind.DAMAGE_REDUCTION:
			continue
		mult *= maxf(0.05, 1.0 - maxf(0.0, r.effect_value))
	return mult


func attack_damage_multiplier() -> float:
	var bonus := 0.0
	for r in inventory:
		if r == null:
			continue
		if r.effect_kind != RelicDefinition.EffectKind.ATTACK_BONUS:
			continue
		bonus += maxf(0.0, r.effect_value)
	return 1.0 + bonus


func corpus_find_bonus() -> int:
	var bonus := 0
	for r in inventory:
		if r == null:
			continue
		if r.effect_kind != RelicDefinition.EffectKind.CORPUS_FIND:
			continue
		bonus += int(round(maxf(0.0, r.effect_value)))
	return bonus


func _pick_relic(rng: RandomNumberGenerator) -> RelicDefinition:
	if _pool.is_empty():
		return null
	if rng != null:
		return _pool[rng.randi_range(0, _pool.size() - 1)]
	return _pool[0]
