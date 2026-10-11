class_name AttackRangePreview
extends RefCounted

const _GridLine := preload("res://scripts/combat/grid_line.gd")


static func get_cells(grid: BoardGrid, origin: Vector2i, unit: UnitInstance) -> Array[Vector2i]:
	if grid == null or unit == null or not grid.in_bounds(origin):
		return []

	var seen: Dictionary = {}
	var result: Array[Vector2i] = []

	if unit.uses_line_attack():
		for axis in _GridLine.AXIS_ORDER:
			for cell in _GridLine.cells_on_axis(origin, axis, grid):
				if cell == origin or seen.has(cell):
					continue
				seen[cell] = true
				result.append(cell)

	if unit.can_perform_normal_attack():
		var attack_range := unit.get_attack_range()
		var size := grid.get_size()
		for y in range(size.y):
			for x in range(size.x):
				var cell := Vector2i(x, y)
				if cell == origin or seen.has(cell):
					continue
				if not grid.in_bounds(cell) or grid.is_blocked(cell):
					continue
				if grid.chebyshev_distance(origin, cell) <= attack_range:
					seen[cell] = true
					result.append(cell)

	return result
