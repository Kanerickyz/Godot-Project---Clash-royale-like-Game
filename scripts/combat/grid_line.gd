class_name GridLine
extends RefCounted

enum Axis {
	ROW,
	COLUMN,
	POS_DIAG,
	NEG_DIAG,
}

const AXIS_ORDER: Array[Axis] = [
	Axis.ROW,
	Axis.COLUMN,
	Axis.POS_DIAG,
	Axis.NEG_DIAG,
]


static func cell_on_axis(origin: Vector2i, cell: Vector2i, axis: Axis) -> bool:
	match axis:
		Axis.ROW:
			return cell.y == origin.y
		Axis.COLUMN:
			return cell.x == origin.x
		Axis.POS_DIAG:
			return cell.x - origin.x == cell.y - origin.y
		Axis.NEG_DIAG:
			return cell.x - origin.x == -(cell.y - origin.y)
		_:
			return false


static func cells_on_axis(origin: Vector2i, axis: Axis, grid: BoardGrid) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if grid == null:
		return cells
	var size := grid.get_size()
	for y in range(size.y):
		for x in range(size.x):
			var cell := Vector2i(x, y)
			if not grid.in_bounds(cell) or grid.is_blocked(cell):
				continue
			if cell_on_axis(origin, cell, axis):
				cells.append(cell)
	cells.sort_custom(_sort_cells)
	return cells


static func enemies_on_axis(
	grid: BoardGrid,
	origin: Vector2i,
	axis: Axis,
	team: UnitInstance.Team,
) -> Array[UnitInstance]:
	var enemies: Array[UnitInstance] = []
	if grid == null:
		return enemies
	for cell in cells_on_axis(origin, axis, grid):
		var unit := grid.get_unit(cell)
		if unit == null or not unit.is_alive():
			continue
		if unit.team == team:
			continue
		enemies.append(unit)
	return enemies


static func pick_best_axis(
	grid: BoardGrid,
	origin: Vector2i,
	team: UnitInstance.Team,
) -> int:
	var best_axis := -1
	var best_hits := 0
	for axis in AXIS_ORDER:
		var hits := enemies_on_axis(grid, origin, axis, team).size()
		if hits > best_hits:
			best_hits = hits
			best_axis = axis
	return best_axis


static func _sort_cells(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y
