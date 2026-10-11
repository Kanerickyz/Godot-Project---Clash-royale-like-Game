class_name AttackRangePreviewTest
extends RefCounted

const _AbilityData := preload("res://scripts/data/ability_data.gd")
const _UnitData := preload("res://scripts/data/unit_data.gd")
const _UnitStats := preload("res://scripts/data/unit_stats.gd")
const _AttackRangePreview := preload("res://scripts/combat/attack_range_preview.gd")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_melee_range_one()
	_test_melee_range_four()
	_test_line_attack_four_axes()
	_test_no_attack_unit()
	if _failures == 0:
		print("AttackRangePreviewTest: all tests passed")
	else:
		push_error("AttackRangePreviewTest: %d failure(s)" % _failures)
	return _failures == 0


static func _grid(size: Vector2i = Vector2i(6, 6)) -> BoardGrid:
	var grid := BoardGrid.new()
	grid.configure(size)
	return grid


static func _unit_with_melee(attack_range: int) -> UnitInstance:
	var data := _UnitData.new()
	data.ability = _AbilityData.new()
	var stats := _UnitStats.new()
	stats.attack_range = attack_range
	data.stats = stats
	var unit := UnitInstance.new("melee", Vector2i.ZERO, UnitInstance.Team.PLAYER)
	unit.unit_data = data
	unit.stats = stats.duplicate_stats()
	return unit


static func _unit_with_line_attack() -> UnitInstance:
	var data := _UnitData.new()
	var ability := _AbilityData.new()
	ability.can_normal_attack = false
	ability.uses_line_attack = true
	data.ability = ability
	data.stats = _UnitStats.new()
	var unit := UnitInstance.new("line", Vector2i.ZERO, UnitInstance.Team.PLAYER)
	unit.unit_data = data
	unit.stats = data.stats.duplicate_stats()
	return unit


static func _unit_without_attack() -> UnitInstance:
	var data := _UnitData.new()
	var ability := _AbilityData.new()
	ability.can_normal_attack = false
	ability.uses_line_attack = false
	data.ability = ability
	data.stats = _UnitStats.new()
	var unit := UnitInstance.new("none", Vector2i.ZERO, UnitInstance.Team.PLAYER)
	unit.unit_data = data
	unit.stats = data.stats.duplicate_stats()
	return unit


static func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("AttackRangePreviewTest FAIL: %s" % message)


static func _assert_eq(actual: int, expected: int, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error(
			"AttackRangePreviewTest FAIL: %s (expected %d, got %d)"
			% [message, expected, actual]
		)


static func _test_melee_range_one() -> void:
	var grid := _grid()
	var origin := Vector2i(2, 2)
	var cells := _AttackRangePreview.get_cells(grid, origin, _unit_with_melee(1))
	_assert_eq(cells.size(), 8, "range 1 chebyshev has 8 cells")
	for cell in cells:
		_assert_true(
			grid.chebyshev_distance(origin, cell) == 1,
			"range 1 cell within chebyshev 1: %s" % str(cell),
		)


static func _test_melee_range_four() -> void:
	var grid := _grid()
	var origin := Vector2i(0, 0)
	var cells := _AttackRangePreview.get_cells(grid, origin, _unit_with_melee(4))
	_assert_eq(cells.size(), 24, "range 4 from corner covers 24 cells")
	_assert_true(
		cells.has(Vector2i(4, 0)) and cells.has(Vector2i(0, 4)),
		"range 4 includes edge cells at distance 4",
	)


static func _test_line_attack_four_axes() -> void:
	var grid := _grid(Vector2i(5, 5))
	var origin := Vector2i(2, 2)
	var cells := _AttackRangePreview.get_cells(grid, origin, _unit_with_line_attack())
	_assert_eq(cells.size(), 16, "5x5 board line axes from center exclude origin (16 cells)")
	for cell in cells:
		var on_axis := (
			cell.x == origin.x
			or cell.y == origin.y
			or cell.x - origin.x == cell.y - origin.y
			or cell.x - origin.x == -(cell.y - origin.y)
		)
		_assert_true(on_axis, "line cell on an axis: %s" % str(cell))


static func _test_no_attack_unit() -> void:
	var grid := _grid()
	var origin := Vector2i(2, 2)
	var cells := _AttackRangePreview.get_cells(grid, origin, _unit_without_attack())
	_assert_eq(cells.size(), 0, "unit without attack modes has empty range")
