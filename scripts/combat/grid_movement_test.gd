class_name GridMovementTest
extends RefCounted

const _UnitStats := preload("res://scripts/data/unit_stats.gd")
const _GridMovement := preload("res://scripts/combat/grid_movement.gd")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_orthogonal_default_matches_legacy()
	_test_orthogonal_multi_step()
	_test_line_axis_only()
	_test_knight_ignores_leg()
	_test_diagonal_steps()
	_test_rook_slide_full_row()
	_test_rook_blocked_slide()
	_test_bishop_slide_full_diagonal()
	_test_bishop_blocked_slide()
	_test_queen_slide_full_row()
	_test_queen_blocked_slide()
	_test_blocked_path_truncates()
	_test_boundary_truncates()
	_test_swap_units_at()
	_test_swap_units_at_to_empty()
	_test_teleport_picks_closest_to_enemy()
	_test_teleport_excludes_occupied()
	_test_teleport_no_valid_cell()
	if _failures == 0:
		print("GridMovementTest: all tests passed")
	else:
		push_error("GridMovementTest: %d failure(s)" % _failures)
	return _failures == 0


static func _grid(size: Vector2i = Vector2i(8, 8), blocked: Array[Vector2i] = []) -> BoardGrid:
	var grid := BoardGrid.new()
	grid.configure(size, blocked)
	return grid


static func _place(grid: BoardGrid, cell: Vector2i, team: UnitInstance.Team = UnitInstance.Team.ENEMY) -> UnitInstance:
	var unit := UnitInstance.new("test", cell, team)
	unit.current_hp = 1
	grid.place(unit, cell)
	return unit


static func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("GridMovementTest FAIL: %s" % message)


static func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error("GridMovementTest FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])


static func _test_orthogonal_default_matches_legacy() -> void:
	var grid := _grid()
	var from := Vector2i(2, 2)
	var target := Vector2i(5, 2)
	var legacy := _GridMovement.get_step_toward(grid, from, target)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.ORTHOGONAL,
		1,
	)
	_assert_eq(path.size(), 1, "orthogonal single step path length")
	_assert_eq(path[0], legacy, "orthogonal default matches legacy step")


static func _test_orthogonal_multi_step() -> void:
	var grid := _grid()
	var from := Vector2i(0, 0)
	var target := Vector2i(4, 0)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.ORTHOGONAL,
		3,
	)
	_assert_eq(path.size(), 3, "orthogonal 3 steps on open board")
	for i in path.size():
		var step := path[i]
		var prev := from if i == 0 else path[i - 1]
		var delta := step - prev
		_assert_true(
			absi(delta.x) + absi(delta.y) == 1,
			"orthogonal step %d is adjacent" % i,
		)


static func _test_line_axis_only() -> void:
	var grid := _grid()
	var from := Vector2i(2, 2)
	var target := Vector2i(5, 4)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.LINE,
		2,
	)
	_assert_true(not path.is_empty(), "line path is not empty")
	var axis_x_const := true
	var axis_y_const := true
	for cell in path:
		if cell.x != from.x:
			axis_x_const = false
		if cell.y != from.y:
			axis_y_const = false
	_assert_true(axis_x_const or axis_y_const, "line path stays on one axis")
	_assert_true(not (axis_x_const and axis_y_const and path.size() > 1), "line path does not mix axes")


static func _test_knight_ignores_leg() -> void:
	var grid := _grid()
	var from := Vector2i(3, 3)
	_place(grid, Vector2i(3, 4))
	var target := Vector2i(2, 5)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.KNIGHT,
		1,
	)
	_assert_eq(path.size(), 1, "knight produces one jump")
	var delta := path[0] - from
	var dist_sorted := [absi(delta.x), absi(delta.y)]
	dist_sorted.sort()
	_assert_eq(dist_sorted, [1, 2], "knight jump is L-shaped")


static func _test_diagonal_steps() -> void:
	var grid := _grid()
	var from := Vector2i(1, 1)
	var target := Vector2i(4, 4)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.DIAGONAL,
		2,
	)
	_assert_eq(path.size(), 2, "diagonal two steps")
	for i in path.size():
		var step := path[i]
		var prev := from if i == 0 else path[i - 1]
		var delta := step - prev
		_assert_true(absi(delta.x) == 1 and absi(delta.y) == 1, "diagonal step %d" % i)


static func _test_rook_slide_full_row() -> void:
	var grid := _grid()
	var from := Vector2i(0, 0)
	var target := Vector2i(7, 0)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.ROOK,
		1,
	)
	_assert_eq(path.size(), 7, "rook slides full row on open 8x8 board")
	for cell in path:
		_assert_eq(cell.y, 0, "rook path stays on same row")
	_assert_eq(path[path.size() - 1], Vector2i(7, 0), "rook ends at board edge")


static func _test_rook_blocked_slide() -> void:
	var grid := _grid()
	var from := Vector2i(0, 0)
	var target := Vector2i(7, 0)
	_place(grid, Vector2i(3, 0))
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.ROOK,
		1,
	)
	_assert_eq(path.size(), 2, "rook stops before blocker")
	_assert_eq(path[path.size() - 1], Vector2i(2, 0), "rook ends at last free cell")
	for cell in path:
		_assert_true(cell != Vector2i(3, 0), "rook path avoids blocked cell")


static func _test_bishop_slide_full_diagonal() -> void:
	var grid := _grid()
	var from := Vector2i(0, 0)
	var target := Vector2i(7, 7)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.BISHOP,
		1,
	)
	_assert_eq(path.size(), 7, "bishop slides full diagonal on open 8x8 board")
	for i in path.size():
		var step := path[i]
		var prev := from if i == 0 else path[i - 1]
		var delta := step - prev
		_assert_true(absi(delta.x) == 1 and absi(delta.y) == 1, "bishop path stays diagonal")
	_assert_eq(path[path.size() - 1], Vector2i(7, 7), "bishop ends at board corner")


static func _test_bishop_blocked_slide() -> void:
	var grid := _grid()
	var from := Vector2i(0, 0)
	var target := Vector2i(7, 7)
	_place(grid, Vector2i(3, 3))
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.BISHOP,
		1,
	)
	_assert_eq(path.size(), 2, "bishop stops before blocker on diagonal")
	_assert_eq(path[path.size() - 1], Vector2i(2, 2), "bishop ends at last free diagonal cell")
	for cell in path:
		_assert_true(cell != Vector2i(3, 3), "bishop path avoids blocked cell")


static func _test_queen_slide_full_row() -> void:
	var grid := _grid()
	var from := Vector2i(0, 3)
	var target := Vector2i(7, 3)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.QUEEN,
		1,
	)
	_assert_eq(path.size(), 7, "queen slides full row")
	for cell in path:
		_assert_eq(cell.y, 3, "queen row path stays on same row")


static func _test_queen_blocked_slide() -> void:
	var blocked: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	var grid := _grid(Vector2i(8, 8), blocked)
	var from := Vector2i(0, 0)
	var target := Vector2i(7, 7)
	_place(grid, Vector2i(4, 4))
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.QUEEN,
		1,
	)
	_assert_eq(path.size(), 3, "queen stops before blocker on diagonal")
	_assert_eq(path[path.size() - 1], Vector2i(3, 3), "queen ends at last free diagonal cell")


static func _test_blocked_path_truncates() -> void:
	var grid := _grid()
	var from := Vector2i(0, 0)
	var target := Vector2i(5, 0)
	_place(grid, Vector2i(1, 0))
	_assert_true(grid.is_occupied(Vector2i(1, 0)), "blocker occupies cell")
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.ORTHOGONAL,
		5,
	)
	for cell in path:
		_assert_true(cell != Vector2i(1, 0), "orthogonal path never enters blocked cell")


static func _test_boundary_truncates() -> void:
	var grid := _grid(Vector2i(4, 4))
	var from := Vector2i(1, 1)
	var mover := UnitInstance.new("mover", from, UnitInstance.Team.PLAYER)
	mover.current_hp = 1
	grid.place(mover, from)
	_place(grid, Vector2i(0, 1))
	_place(grid, Vector2i(2, 1))
	_place(grid, Vector2i(1, 0))
	_place(grid, Vector2i(1, 2))
	_assert_true(grid.is_occupied(Vector2i(0, 1)), "left blocked")
	_assert_true(grid.is_occupied(Vector2i(2, 1)), "right blocked")
	_assert_true(grid.is_occupied(Vector2i(1, 0)), "up blocked")
	_assert_true(grid.is_occupied(Vector2i(1, 2)), "down blocked")
	var target := Vector2i(3, 3)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.ORTHOGONAL,
		5,
	)
	_assert_eq(path.size(), 0, "orthogonal path with all neighbors blocked")


static func _test_swap_units_at() -> void:
	var grid := _grid()
	var unit_a := _place(grid, Vector2i(1, 0), UnitInstance.Team.PLAYER)
	var unit_b := _place(grid, Vector2i(3, 0), UnitInstance.Team.PLAYER)
	_assert_true(grid.swap_units_at(Vector2i(1, 0), Vector2i(3, 0)), "swap two units")
	_assert_eq(grid.find_cell_of(unit_a), Vector2i(3, 0), "unit_a at target cell")
	_assert_eq(grid.find_cell_of(unit_b), Vector2i(1, 0), "unit_b at source cell")
	_assert_eq(unit_a.grid_pos, Vector2i(3, 0), "unit_a grid_pos synced")
	_assert_eq(unit_b.grid_pos, Vector2i(1, 0), "unit_b grid_pos synced")


static func _test_swap_units_at_to_empty() -> void:
	var grid := _grid()
	var unit := _place(grid, Vector2i(2, 2), UnitInstance.Team.PLAYER)
	_assert_true(grid.swap_units_at(Vector2i(2, 2), Vector2i(4, 4)), "swap to empty moves unit")
	_assert_eq(grid.find_cell_of(unit), Vector2i(4, 4), "unit moved to empty cell")
	_assert_eq(grid.get_unit(Vector2i(2, 2)), null, "source cell empty")


static func _test_teleport_picks_closest_to_enemy() -> void:
	var grid := _grid()
	var from := Vector2i(2, 2)
	var enemy := Vector2i(6, 2)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		enemy,
		_UnitStats.MovementPattern.TELEPORT,
		2,
	)
	_assert_eq(path.size(), 1, "teleport returns one destination")
	var best_dist := 999
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			if maxi(absi(dx), absi(dy)) > 2:
				continue
			var cell := from + Vector2i(dx, dy)
			if grid.in_bounds(cell) and not grid.is_blocked(cell) and not grid.is_occupied(cell):
				best_dist = mini(best_dist, BoardGrid._chebyshev(cell, enemy))
	_assert_eq(
		BoardGrid._chebyshev(path[0], enemy),
		best_dist,
		"teleport picks minimum chebyshev distance to enemy",
	)


static func _test_teleport_excludes_occupied() -> void:
	var grid := _grid()
	_place(grid, Vector2i(3, 2))
	var from := Vector2i(2, 2)
	var enemy := Vector2i(5, 2)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		enemy,
		_UnitStats.MovementPattern.TELEPORT,
		2,
	)
	_assert_eq(path.size(), 1, "teleport finds alternate cell when blocked")
	_assert_true(path[0] != Vector2i(3, 2), "teleport skips occupied cell")


static func _test_teleport_no_valid_cell() -> void:
	var grid := _grid(Vector2i(4, 4))
	var from := Vector2i(1, 1)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			var cell := from + Vector2i(dx, dy)
			if grid.in_bounds(cell):
				_place(grid, cell)
	var path := _GridMovement.plan_move_path(
		grid,
		from,
		Vector2i(3, 3),
		_UnitStats.MovementPattern.TELEPORT,
		2,
	)
	_assert_eq(path.size(), 0, "teleport returns empty when no valid cell")
