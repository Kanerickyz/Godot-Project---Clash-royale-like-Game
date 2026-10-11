class_name SacrificeServiceTest
extends RefCounted

const CRICKET := preload("res://resources/units/cricket.tres")
const GUNNER := preload("res://resources/units/gunner.tres")


static func run_all() -> bool:
	var passed := true
	passed = _test_successful_transfer() and passed
	passed = _test_duplicate_ability_not_reattached() and passed
	passed = _test_invalid_ids() and passed
	passed = _test_unit_instance_includes_attached_specs() and passed
	if passed:
		print("SacrificeServiceTest: all passed")
	else:
		push_error("SacrificeServiceTest: failures detected")
	return passed


static func _make_deck_with(units: Array[UnitData]) -> DeckState:
	var deck := DeckState.new()
	var config := DeckConfig.new()
	config.max_size = 10
	deck.configure(config)
	for unit_data in units:
		deck.add_entry(unit_data)
	return deck


static func _test_successful_transfer() -> bool:
	var deck := _make_deck_with([CRICKET, GUNNER])
	var entries := deck.get_entries()
	var donor := entries[0]
	var recipient := entries[1]
	var donor_ability_id := donor.unit.ability.id if donor.unit.ability != null else ""

	if not deck.sacrifice_transfer_ability(donor.entry_id, recipient.entry_id):
		push_error("SacrificeServiceTest: transfer should succeed")
		return false
	if deck.size() != 1:
		push_error("SacrificeServiceTest: donor should be removed")
		return false

	var remaining := deck.get_entries()[0]
	if remaining.entry_id != recipient.entry_id:
		push_error("SacrificeServiceTest: wrong recipient remained")
		return false
	if remaining.attached_abilities.size() != 1:
		push_error("SacrificeServiceTest: recipient should have one attached ability")
		return false
	if remaining.attached_abilities[0].id != donor_ability_id:
		push_error("SacrificeServiceTest: attached ability id mismatch")
		return false
	return true


static func _test_duplicate_ability_not_reattached() -> bool:
	var deck := _make_deck_with([CRICKET, GUNNER])
	var entries := deck.get_entries()
	var donor := entries[0]
	var recipient := entries[1]
	recipient.attached_abilities.append(donor.unit.ability)

	if not deck.sacrifice_transfer_ability(donor.entry_id, recipient.entry_id):
		push_error("SacrificeServiceTest: duplicate transfer should still succeed")
		return false
	if recipient.attached_abilities.size() != 1:
		push_error("SacrificeServiceTest: duplicate ability should not be appended")
		return false
	return true


static func _test_invalid_ids() -> bool:
	var deck := _make_deck_with([CRICKET, GUNNER])
	var entries := deck.get_entries()
	if deck.sacrifice_transfer_ability(entries[0].entry_id, entries[0].entry_id):
		push_error("SacrificeServiceTest: same entry should fail")
		return false
	if deck.sacrifice_transfer_ability(999, entries[0].entry_id):
		push_error("SacrificeServiceTest: invalid donor should fail")
		return false
	if deck.sacrifice_transfer_ability(entries[0].entry_id, 999):
		push_error("SacrificeServiceTest: invalid recipient should fail")
		return false
	return true


static func _test_unit_instance_includes_attached_specs() -> bool:
	var deck := _make_deck_with([CRICKET, GUNNER])
	var entries := deck.get_entries()
	var donor := entries[0]
	var recipient := entries[1]
	deck.sacrifice_transfer_ability(donor.entry_id, recipient.entry_id)

	recipient = deck.get_entries()[0]
	var unit := UnitInstance.from_deck_entry(recipient, Vector2i.ZERO, UnitInstance.Team.PLAYER)
	var native_count := 0
	if recipient.unit.ability != null:
		native_count += recipient.unit.ability.effect_specs.size()
	for passive in recipient.unit.passives:
		if passive != null:
			native_count += passive.effect_specs.size()
	var attached_count := 0
	for attached in recipient.attached_abilities:
		if attached != null:
			attached_count += attached.effect_specs.size()

	var specs := unit.get_all_effect_specs()
	if specs.size() != native_count + attached_count:
		push_error(
			"SacrificeServiceTest: expected %d specs, got %d"
			% [native_count + attached_count, specs.size()]
		)
		return false
	return true
