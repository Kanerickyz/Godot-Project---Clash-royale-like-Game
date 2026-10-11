class_name GridLineTest
extends RefCounted

const _GridLine := preload("res://scripts/combat/grid_line.gd")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_row_cells()
	_test_column_cells()
	_test_diagonal_cells()
	_test_pick_best_axis()
	if _failures == 0:
		print("GridLineTest: all tests passed")
	else:
		push_error("GridLineTest: %d failure(s)" % _failures)
	return _failures == 0


static func _grid(size: Vector2i = Vector2i(6, 6)) -> BoardGrid:
	var grid := BoardGrid.new()
	grid.configure(size)
	return grid


static func _place(grid: BoardGrid, cell: Vector2i, team: UnitInstance.Team) -> UnitInstance:
	var unit := UnitInstance.new("test", cell, team)
	unit.current_hp = 5
	grid.place(unit, cell)
	return unit


static func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("GridLineTest FAIL: %s" % message)


static func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error(
			"GridLineTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _test_row_cells() -> void:
	var origin := Vector2i(2, 3)
	var cells := _GridLine.cells_on_axis(origin, _GridLine.Axis.ROW, _grid())
	_assert_eq(cells.size(), 6, "row spans full width")
	for cell in cells:
		_assert_eq(cell.y, 3, "row cell y")


static func _test_column_cells() -> void:
	var origin := Vector2i(2, 3)
	var cells := _GridLine.cells_on_axis(origin, _GridLine.Axis.COLUMN, _grid())
	_assert_eq(cells.size(), 6, "column spans full height")
	for cell in cells:
		_assert_eq(cell.x, 2, "column cell x")


static func _test_diagonal_cells() -> void:
	var origin := Vector2i(1, 1)
	var pos := _GridLine.cells_on_axis(origin, _GridLine.Axis.POS_DIAG, _grid())
	_assert_true(pos.has(Vector2i(0, 0)), "pos diag includes corner")
	_assert_true(pos.has(Vector2i(3, 3)), "pos diag includes far corner")
	var neg := _GridLine.cells_on_axis(origin, _GridLine.Axis.NEG_DIAG, _grid())
	_assert_true(neg.has(Vector2i(2, 0)), "neg diag includes (2,0)")
	_assert_true(neg.has(Vector2i(0, 2)), "neg diag includes (0,2)")


static func _test_pick_best_axis() -> void:
	var grid := _grid()
	var origin := Vector2i(2, 2)
	_place(grid, Vector2i(0, 2), UnitInstance.Team.ENEMY)
	_place(grid, Vector2i(4, 2), UnitInstance.Team.ENEMY)
	_place(grid, Vector2i(2, 0), UnitInstance.Team.ENEMY)
	var axis := _GridLine.pick_best_axis(grid, origin, UnitInstance.Team.PLAYER)
	_assert_eq(axis, _GridLine.Axis.ROW, "row hits two enemies")
