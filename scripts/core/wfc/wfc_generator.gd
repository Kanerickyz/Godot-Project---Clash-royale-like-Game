class_name WfcGenerator
extends RefCounted

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]


static func generate(
	size: Vector2i,
	tileset: TerrainTileset,
	rng: RandomNumberGenerator,
) -> Dictionary:
	## Returns Dictionary[Vector2i, TerrainType.Type]. Never empty for valid size.
	if size.x <= 0 or size.y <= 0 or tileset == null:
		return {}
	var types := tileset.get_all_types()
	if types.is_empty():
		return _fill_default(size, tileset.default_type)

	var adj := tileset.build_adjacency()
	var weights: Dictionary = {}
	for t in types:
		weights[int(t)] = tileset.get_weight(t)

	var max_retries := maxi(1, tileset.max_retries)
	var max_backtracks := maxi(0, tileset.max_backtracks)

	for _attempt in max_retries:
		var result := _try_generate(size, types, adj, weights, rng, max_backtracks)
		if result.is_empty():
			continue
		if not validate_adjacency(result, size, tileset):
			continue
		result = _fix_connectivity(result, size, tileset)
		if not validate_adjacency(result, size, tileset):
			# Island→grass may create illegal pairs (e.g. GRASS↔LAKE); retry.
			continue
		if (
			_meets_walkable_ratio(result, size, tileset)
			and _is_walkable_connected(result, size, tileset)
		):
			return result
	return _fill_default(size, tileset.default_type)


static func validate_adjacency(
	terrain_map: Dictionary,
	size: Vector2i,
	tileset: TerrainTileset,
) -> bool:
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if not terrain_map.has(cell):
				return false
			var a: TerrainType.Type = terrain_map[cell]
			for dir in DIRS:
				var n := cell + dir
				if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
					continue
				var b: TerrainType.Type = terrain_map[n]
				if not tileset.are_compatible(a, b):
					return false
	return true


static func walkable_ratio(
	terrain_map: Dictionary,
	size: Vector2i,
	tileset: TerrainTileset,
) -> float:
	var total := size.x * size.y
	if total <= 0:
		return 0.0
	var walkable := 0
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var t: TerrainType.Type = terrain_map.get(cell, tileset.default_type)
			if tileset.is_walkable(t):
				walkable += 1
	return float(walkable) / float(total)


static func is_walkable_connected(
	terrain_map: Dictionary,
	size: Vector2i,
	tileset: TerrainTileset,
) -> bool:
	return _is_walkable_connected(terrain_map, size, tileset)


static func blocked_cells_from_terrain(
	terrain_map: Dictionary,
	size: Vector2i,
	tileset: TerrainTileset,
) -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var t: TerrainType.Type = terrain_map.get(cell, tileset.default_type)
			if not tileset.is_walkable(t):
				blocked.append(cell)
	return blocked


static func _try_generate(
	size: Vector2i,
	types: Array[TerrainType.Type],
	adj: Dictionary,
	weights: Dictionary,
	rng: RandomNumberGenerator,
	max_backtracks: int,
) -> Dictionary:
	var grid := _make_grid(size, types)
	var backtracks := 0
	## Each frame: cell, options still available to try, snapshot before collapse.
	var stack: Array[Dictionary] = []

	while true:
		if _has_contradiction(grid, size):
			if not _undo_and_retry(grid, size, adj, weights, rng, stack):
				return {}
			backtracks += 1
			if backtracks > max_backtracks:
				return {}
			continue

		if _is_fully_collapsed(grid, size):
			return _grid_to_map(grid, size)

		var pick := _find_min_entropy_cell(grid, size, rng)
		if pick.x < 0:
			return {}

		var cell: WfcCell = grid[pick.y][pick.x]
		var snapshot := _snapshot_grid(grid, size)
		var remaining := cell.options.duplicate()
		var choice := _weighted_pick(remaining, weights, rng)
		if choice < 0:
			return {}

		remaining.erase(choice)
		stack.append({
			"cell": pick,
			"remaining": remaining,
			"snapshot": snapshot,
		})
		cell.collapse_to(choice)
		if not _propagate(grid, size, adj, pick):
			continue
	return {}


static func _undo_and_retry(
	grid: Array,
	size: Vector2i,
	adj: Dictionary,
	weights: Dictionary,
	rng: RandomNumberGenerator,
	stack: Array[Dictionary],
) -> bool:
	while not stack.is_empty():
		var frame: Dictionary = stack.pop_back()
		_restore_snapshot(grid, size, frame["snapshot"])
		var pick: Vector2i = frame["cell"]
		var remaining: Array = frame["remaining"]
		if remaining.is_empty():
			continue
		var choice := _weighted_pick_int_array(remaining, weights, rng)
		if choice < 0:
			continue
		remaining.erase(choice)
		stack.append({
			"cell": pick,
			"remaining": remaining,
			"snapshot": frame["snapshot"],
		})
		var cell: WfcCell = grid[pick.y][pick.x]
		cell.collapse_to(choice)
		if _propagate(grid, size, adj, pick):
			return true
		# Contradiction again — loop to try next remaining or deeper undo.
	return false


static func _make_grid(size: Vector2i, types: Array[TerrainType.Type]) -> Array:
	var grid: Array = []
	grid.resize(size.y)
	for y in size.y:
		var row: Array = []
		row.resize(size.x)
		for x in size.x:
			var cell := WfcCell.new()
			cell.setup(types)
			row[x] = cell
		grid[y] = row
	return grid


static func _propagate(grid: Array, size: Vector2i, adj: Dictionary, start: Vector2i) -> bool:
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var cur_cell: WfcCell = grid[cur.y][cur.x]
		for dir in DIRS:
			var n := cur + dir
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
				continue
			var neighbor: WfcCell = grid[n.y][n.x]
			var changed := false
			var remaining: Array[int] = neighbor.options.duplicate()
			for opt in remaining:
				if not _option_supported(cur_cell.options, opt, adj):
					if neighbor.remove_option(opt):
						changed = true
			if neighbor.is_contradiction():
				return false
			if changed:
				queue.append(n)
	return true


static func _option_supported(source_options: Array[int], neighbor_opt: int, adj: Dictionary) -> bool:
	for src in source_options:
		var allowed: Dictionary = adj.get(src, {})
		if allowed.has(neighbor_opt):
			return true
	return false


static func _find_min_entropy_cell(grid: Array, size: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var best_entropy := 999999
	var ties: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var cell: WfcCell = grid[y][x]
			if cell.options.size() == 1:
				cell.collapsed = true
				continue
			if cell.collapsed:
				continue
			var e := cell.entropy()
			if e < best_entropy:
				best_entropy = e
				ties = [Vector2i(x, y)]
			elif e == best_entropy:
				ties.append(Vector2i(x, y))
	if ties.is_empty():
		return Vector2i(-1, -1)
	return ties[rng.randi_range(0, ties.size() - 1)]


static func _weighted_pick(
	options: Array[int],
	weights: Dictionary,
	rng: RandomNumberGenerator,
) -> int:
	return _weighted_pick_int_array(options, weights, rng)


static func _weighted_pick_int_array(
	options: Array,
	weights: Dictionary,
	rng: RandomNumberGenerator,
) -> int:
	var total := 0.0
	var candidates: Array[int] = []
	var candidate_weights: Array[float] = []
	for opt_variant in options:
		var opt: int = int(opt_variant)
		var w: float = float(weights.get(opt, 0.0))
		if w <= 0.0:
			continue
		candidates.append(opt)
		candidate_weights.append(w)
		total += w
	if candidates.is_empty() or total <= 0.0:
		return -1
	var roll := rng.randf() * total
	var acc := 0.0
	for i in candidates.size():
		acc += candidate_weights[i]
		if roll <= acc:
			return candidates[i]
	return candidates[candidates.size() - 1]


static func _is_fully_collapsed(grid: Array, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			var cell: WfcCell = grid[y][x]
			if cell.options.size() != 1:
				return false
			cell.collapsed = true
	return true


static func _has_contradiction(grid: Array, size: Vector2i) -> bool:
	for y in size.y:
		for x in size.x:
			var cell: WfcCell = grid[y][x]
			if cell.is_contradiction():
				return true
	return false


static func _grid_to_map(grid: Array, size: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	for y in size.y:
		for x in size.x:
			var cell: WfcCell = grid[y][x]
			result[Vector2i(x, y)] = cell.get_collapsed_type() as TerrainType.Type
	return result


static func _snapshot_grid(grid: Array, size: Vector2i) -> Array:
	var snap: Array = []
	snap.resize(size.y)
	for y in size.y:
		var row: Array = []
		row.resize(size.x)
		for x in size.x:
			var cell: WfcCell = grid[y][x]
			row[x] = cell.clone()
		snap[y] = row
	return snap


static func _restore_snapshot(grid: Array, size: Vector2i, snapshot: Array) -> void:
	for y in size.y:
		for x in size.x:
			var src: WfcCell = snapshot[y][x]
			var dst: WfcCell = grid[y][x]
			dst.copy_from(src)


static func _fill_default(size: Vector2i, default_type: TerrainType.Type) -> Dictionary:
	var result: Dictionary = {}
	for y in size.y:
		for x in size.x:
			result[Vector2i(x, y)] = default_type
	return result


static func _meets_walkable_ratio(
	terrain_map: Dictionary,
	size: Vector2i,
	tileset: TerrainTileset,
) -> bool:
	return walkable_ratio(terrain_map, size, tileset) >= tileset.min_walkable_ratio


static func _is_walkable_connected(
	terrain_map: Dictionary,
	size: Vector2i,
	tileset: TerrainTileset,
) -> bool:
	var start := Vector2i(-1, -1)
	var walkable_count := 0
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var t: TerrainType.Type = terrain_map.get(cell, tileset.default_type)
			if tileset.is_walkable(t):
				walkable_count += 1
				if start.x < 0:
					start = cell
	if walkable_count == 0:
		return false
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var reached := 0
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		reached += 1
		for dir in DIRS:
			var n := cur + dir
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
				continue
			if visited.has(n):
				continue
			var t2: TerrainType.Type = terrain_map.get(n, tileset.default_type)
			if not tileset.is_walkable(t2):
				continue
			visited[n] = true
			queue.append(n)
	return reached == walkable_count


static func _fix_connectivity(
	terrain_map: Dictionary,
	size: Vector2i,
	tileset: TerrainTileset,
) -> Dictionary:
	var result := terrain_map.duplicate()
	var components := _walkable_components(result, size, tileset)
	if components.size() <= 1:
		return result
	var largest_idx := 0
	var largest_size := 0
	for i in components.size():
		var comp: Array = components[i]
		if comp.size() > largest_size:
			largest_size = comp.size()
			largest_idx = i
	for i in components.size():
		if i == largest_idx:
			continue
		for cell in components[i]:
			result[cell] = tileset.default_type
	return result


static func _walkable_components(
	terrain_map: Dictionary,
	size: Vector2i,
	tileset: TerrainTileset,
) -> Array:
	var visited: Dictionary = {}
	var components: Array = []
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if visited.has(cell):
				continue
			var t: TerrainType.Type = terrain_map.get(cell, tileset.default_type)
			if not tileset.is_walkable(t):
				visited[cell] = true
				continue
			var comp: Array[Vector2i] = []
			var queue: Array[Vector2i] = [cell]
			visited[cell] = true
			while not queue.is_empty():
				var cur: Vector2i = queue.pop_front()
				comp.append(cur)
				for dir in DIRS:
					var n := cur + dir
					if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
						continue
					if visited.has(n):
						continue
					var t2: TerrainType.Type = terrain_map.get(n, tileset.default_type)
					if not tileset.is_walkable(t2):
						continue
					visited[n] = true
					queue.append(n)
			components.append(comp)
	return components
