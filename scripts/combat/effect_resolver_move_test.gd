class_name EffectResolverMoveTest
extends RefCounted

const _EffectResolver := preload("res://scripts/combat/effects/effect_resolver.gd")
const _Ability := preload("res://resources/abilities/move_damage_enemy_ahead.tres")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_cell_ahead_east()
	_test_cell_ahead_zero_delta()
	_test_enemy_ahead_resolved()
	_test_enemy_on_landing_not_ahead()
	_test_ally_ahead_ignored()
	_test_bump_adjacent_enemy()
	if _failures == 0:
		print("EffectResolverMoveTest: all tests passed")
	else:
		push_error("EffectResolverMoveTest: %d failure(s)" % _failures)
	return _failures == 0


static func _grid(size: Vector2i = Vector2i(8, 8)) -> BoardGrid:
	var grid := BoardGrid.new()
	grid.configure(size)
	return grid


static func _place(
	grid: BoardGrid,
	cell: Vector2i,
	team: UnitInstance.Team,
	hp: int = 10,
) -> UnitInstance:
	var unit := UnitInstance.new("test", cell, team)
	unit.current_hp = hp
	grid.place(unit, cell)
	return unit


static func _payload(from_cell: Vector2i, to_cell: Vector2i, source: UnitInstance) -> CombatEventPayload:
	var payload := CombatEventPayload.new()
	payload.source = source
	payload.from_cell = from_cell
	payload.to_cell = to_cell
	return payload


static func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error(
			"EffectResolverMoveTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("EffectResolverMoveTest FAIL: %s" % message)


static func _test_cell_ahead_east() -> void:
	var grid := _grid()
	var payload := _payload(Vector2i(1, 0), Vector2i(2, 0), null)
	_assert_eq(
		_EffectResolver.cell_ahead_of_move(payload, grid),
		Vector2i(3, 0),
		"cell ahead when moving east",
	)


static func _test_cell_ahead_zero_delta() -> void:
	var grid := _grid()
	var payload := _payload(Vector2i(1, 0), Vector2i(1, 0), null)
	_assert_eq(
		_EffectResolver.cell_ahead_of_move(payload, grid),
		Vector2i(-1, -1),
		"no cell ahead when delta is zero",
	)


static func _owner_with_move_ability(cell: Vector2i) -> UnitInstance:
	var unit_data := UnitData.new()
	unit_data.ability = _Ability
	var stats := UnitStats.new()
	stats.attack = 4
	unit_data.stats = stats
	var owner := UnitInstance.from_unit_data(unit_data, cell, UnitInstance.Team.PLAYER)
	owner.current_hp = 10
	return owner


static func _run_move_damage(
	grid: BoardGrid,
	owner: UnitInstance,
	from_cell: Vector2i,
	to_cell: Vector2i,
) -> void:
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var payload := _payload(from_cell, to_cell, owner)
	resolver.on_event(CombatEvents.ON_MOVE, payload)
	while resolver.has_pending_steps():
		resolver.process_next_step()


static func _test_enemy_ahead_resolved() -> void:
	var grid := _grid()
	var owner := _owner_with_move_ability(Vector2i(1, 0))
	grid.place(owner, Vector2i(1, 0))
	var enemy := _place(grid, Vector2i(3, 0), UnitInstance.Team.ENEMY, 10)
	_run_move_damage(grid, owner, Vector2i(1, 0), Vector2i(2, 0))
	_assert_eq(enemy.current_hp, 6, "enemy ahead takes current attack damage on move")


static func _test_enemy_on_landing_not_ahead() -> void:
	var grid := _grid()
	var owner := _owner_with_move_ability(Vector2i(1, 0))
	grid.place(owner, Vector2i(1, 0))
	var enemy := _place(grid, Vector2i(2, 0), UnitInstance.Team.ENEMY, 10)
	_run_move_damage(grid, owner, Vector2i(1, 0), Vector2i(2, 0))
	_assert_eq(enemy.current_hp, 10, "enemy on landing cell is not damaged")


static func _test_ally_ahead_ignored() -> void:
	var grid := _grid()
	var owner := _owner_with_move_ability(Vector2i(1, 0))
	grid.place(owner, Vector2i(1, 0))
	var ally := _place(grid, Vector2i(3, 0), UnitInstance.Team.PLAYER, 10)
	_run_move_damage(grid, owner, Vector2i(1, 0), Vector2i(2, 0))
	_assert_eq(ally.current_hp, 10, "ally ahead is not damaged")


static func _test_bump_adjacent_enemy() -> void:
	var grid := _grid()
	var owner := _owner_with_move_ability(Vector2i(3, 0))
	grid.place(owner, Vector2i(3, 0))
	var enemy := _place(grid, Vector2i(4, 0), UnitInstance.Team.ENEMY, 10)
	var action := UnitBrain.decide(grid, owner)
	_assert_eq(action.type, UnitBrain.ActionType.BUMP, "adjacent blocked chariot bumps enemy")
	_assert_eq(action.bump_from, Vector2i(2, 0), "bump from one cell back")
	_assert_eq(action.bump_to, Vector2i(3, 0), "bump ends on current cell")
	_emit_bump(grid, owner, action)
	_assert_eq(enemy.current_hp, 6, "bump deals current attack to adjacent enemy")


static func _emit_bump(grid: BoardGrid, owner: UnitInstance, action: UnitBrain.CombatAction) -> void:
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var payload := _payload(action.bump_from, action.bump_to, owner)
	resolver.on_event(CombatEvents.ON_MOVE, payload)
	while resolver.has_pending_steps():
		resolver.process_next_step()
