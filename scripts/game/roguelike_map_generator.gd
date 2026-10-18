class_name RoguelikeMapGenerator
extends RefCounted
## Roguelike layout: rectangular rooms + L-corridors, painted from overworld tileset.


class Room:
	var rect: Rect2 = Rect2()
	var is_safe: bool = false
	var is_boss: bool = false

	func center() -> Vector2:
		return rect.get_center()


const TILE := OverworldTilesetFactory.TILE_SIZE

var map_size: Vector2 = Vector2(2800, 2200)
var rooms: Array[Room] = []
var corridors: Array[Rect2] = []
var safe_room: Room
var boss_room: Room
var _paint_rng := RandomNumberGenerator.new()


func generate(cfg: WorldSpawnConfig, rng: RandomNumberGenerator) -> void:
	rooms.clear()
	corridors.clear()
	safe_room = null
	boss_room = null
	map_size = cfg.map_size if cfg != null else Vector2(2800, 2200)

	var count := rng.randi_range(cfg.room_count_min, cfg.room_count_max)
	count = maxi(3, count)
	_place_rooms(cfg, rng, count)
	_connect_rooms(cfg)
	_assign_special_rooms()


func build_visuals(parent: Node2D, rng: RandomNumberGenerator = null) -> void:
	if parent == null:
		return
	if rng != null:
		_paint_rng.seed = rng.randi()
	else:
		_paint_rng.randomize()

	var cols := maxi(1, int(ceili(map_size.x / float(TILE))))
	var rows := maxi(1, int(ceili(map_size.y / float(TILE))))
	var walkable := _make_bool_grid(cols, rows, false)
	var path_grid := _make_bool_grid(cols, rows, false)
	var water_grid := _make_bool_grid(cols, rows, false)

	for corridor in corridors:
		_mark_rect_cells(path_grid, corridor, cols, rows, true)
		_mark_rect_cells(walkable, corridor, cols, rows, true)
	for room in rooms:
		_mark_rect_cells(walkable, room.rect, cols, rows, true)
		_mark_room_paths(path_grid, room, cols, rows)

	_carve_river(water_grid, path_grid, cols, rows)
	# Water wins over dirt path where they overlap.
	for y in rows:
		for x in cols:
			if water_grid[y][x]:
				path_grid[y][x] = false

	var tileset := OverworldTilesetFactory.build_tileset()
	var ground := TileMapLayer.new()
	ground.name = "GroundTiles"
	ground.tile_set = tileset
	ground.z_index = 0
	parent.add_child(ground)

	var water_layer := TileMapLayer.new()
	water_layer.name = "WaterTiles"
	water_layer.tile_set = tileset
	water_layer.z_index = 1
	parent.add_child(water_layer)

	var props := TileMapLayer.new()
	props.name = "PropTiles"
	props.tile_set = tileset
	props.z_index = 2
	props.y_sort_enabled = true
	parent.add_child(props)

	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			ground.set_cell(
				cell,
				OverworldTilesetFactory.SOURCE_ID,
				OverworldTilesetFactory.grass_atlas(_paint_rng)
			)
			if path_grid[y][x]:
				var pmask := OverworldTilesetFactory.neighbor_mask(path_grid, x, y, cols, rows)
				ground.set_cell(
					cell,
					OverworldTilesetFactory.SOURCE_ID,
					OverworldTilesetFactory.path_atlas(pmask)
				)
			if water_grid[y][x]:
				var wmask := OverworldTilesetFactory.neighbor_mask(water_grid, x, y, cols, rows)
				water_layer.set_cell(
					cell,
					OverworldTilesetFactory.SOURCE_ID,
					OverworldTilesetFactory.water_atlas(wmask)
				)

	_scatter_props(props, walkable, path_grid, water_grid, cols, rows)

	for i in rooms.size():
		var room: Room = rooms[i]
		if room.is_safe or room.is_boss:
			_add_room_label(parent, room)
			if room.is_safe:
				_place_camp_props(props, room)


func get_non_safe_rooms() -> Array[Room]:
	var out: Array[Room] = []
	for room in rooms:
		if room != null and not room.is_safe:
			out.append(room)
	return out


func sample_in_room(room: Room, rng: RandomNumberGenerator, margin: float) -> Vector2:
	if room == null:
		return map_size * 0.5
	var r := room.rect.grow(-margin)
	if r.size.x < 8.0 or r.size.y < 8.0:
		return room.center()
	return Vector2(
		rng.randf_range(r.position.x, r.position.x + r.size.x),
		rng.randf_range(r.position.y, r.position.y + r.size.y)
	)


func sample_spawn_point(
	rng: RandomNumberGenerator,
	avoid: Array[Vector2],
	min_separation: float,
	margin: float,
	prefer_non_safe: bool = true,
	exclude_boss: bool = false
) -> Vector2:
	var candidates: Array[Room] = []
	for room in rooms:
		if room == null:
			continue
		if prefer_non_safe and room.is_safe:
			continue
		if exclude_boss and room.is_boss:
			continue
		candidates.append(room)
	if candidates.is_empty():
		candidates = rooms.duplicate()
	if candidates.is_empty():
		return map_size * 0.5

	var best := candidates[rng.randi() % candidates.size()].center()
	for _attempt in range(28):
		var room: Room = candidates[rng.randi() % candidates.size()]
		var p := sample_in_room(room, rng, margin)
		if _is_far_enough(p, avoid, min_separation):
			return p
		best = p
	return best


func _place_rooms(cfg: WorldSpawnConfig, rng: RandomNumberGenerator, count: int) -> void:
	var pad := cfg.room_padding
	var attempts := 0
	var max_attempts := count * 40
	while rooms.size() < count and attempts < max_attempts:
		attempts += 1
		var w := rng.randf_range(cfg.room_size_min.x, cfg.room_size_max.x)
		var h := rng.randf_range(cfg.room_size_min.y, cfg.room_size_max.y)
		var max_x := map_size.x - w - pad
		var max_y := map_size.y - h - pad
		if max_x <= pad or max_y <= pad:
			continue
		var x := rng.randf_range(pad, max_x)
		var y := rng.randf_range(pad, max_y)
		var rect := Rect2(x, y, w, h).grow(cfg.room_margin)
		var overlaps := false
		for existing in rooms:
			if rect.intersects(existing.rect.grow(cfg.room_margin)):
				overlaps = true
				break
		if overlaps:
			continue
		var room := Room.new()
		room.rect = Rect2(x, y, w, h)
		rooms.append(room)

	# Guarantee at least 3 rooms on tiny maps / unlucky RNG.
	while rooms.size() < 3:
		var idx := rooms.size()
		var room := Room.new()
		var w2 := clampf(cfg.room_size_min.x, 200.0, map_size.x * 0.25)
		var h2 := clampf(cfg.room_size_min.y, 160.0, map_size.y * 0.25)
		room.rect = Rect2(
			pad + float(idx) * (w2 + 120.0),
			pad + float(idx % 2) * (h2 + 100.0),
			w2,
			h2
		)
		rooms.append(room)


func _connect_rooms(cfg: WorldSpawnConfig) -> void:
	if rooms.size() < 2:
		return
	# Nearest-neighbor chain from room 0, then connect leftovers to nearest linked.
	var linked: Array[bool] = []
	linked.resize(rooms.size())
	linked[0] = true
	for _i in range(1, rooms.size()):
		var best_a := -1
		var best_b := -1
		var best_d := INF
		for a in rooms.size():
			if not linked[a]:
				continue
			for b in rooms.size():
				if linked[b]:
					continue
				var d: float = rooms[a].center().distance_squared_to(rooms[b].center())
				if d < best_d:
					best_d = d
					best_a = a
					best_b = b
		if best_a < 0 or best_b < 0:
			break
		_add_corridor(rooms[best_a].center(), rooms[best_b].center(), cfg.corridor_width)
		linked[best_b] = true


func _add_corridor(from: Vector2, to: Vector2, width: float) -> void:
	var half := width * 0.5
	# Horizontal then vertical (L-shape).
	var mid := Vector2(to.x, from.y)
	var h_rect := Rect2(
		Vector2(minf(from.x, mid.x) - half, from.y - half),
		Vector2(absf(mid.x - from.x) + width, width)
	)
	var v_rect := Rect2(
		Vector2(to.x - half, minf(mid.y, to.y) - half),
		Vector2(width, absf(to.y - mid.y) + width)
	)
	corridors.append(h_rect)
	corridors.append(v_rect)


func _assign_special_rooms() -> void:
	if rooms.is_empty():
		return
	# Safe: room closest to top-left (spawn corner feel).
	var best_safe: Room = rooms[0]
	var best_safe_score := INF
	for room in rooms:
		var score := room.center().length_squared()
		if score < best_safe_score:
			best_safe_score = score
			best_safe = room
	best_safe.is_safe = true
	safe_room = best_safe

	# Boss: farthest from safe.
	var best_boss: Room = rooms[0]
	var best_boss_d := -1.0
	for room in rooms:
		if room == safe_room:
			continue
		var d := room.center().distance_squared_to(safe_room.center())
		if d > best_boss_d:
			best_boss_d = d
			best_boss = room
	if best_boss == safe_room and rooms.size() > 1:
		best_boss = rooms[1]
	best_boss.is_boss = true
	boss_room = best_boss


func _is_far_enough(point: Vector2, avoid: Array[Vector2], min_sep: float) -> bool:
	var min_sq := min_sep * min_sep
	for other in avoid:
		if point.distance_squared_to(other) < min_sq:
			return false
	return true


func _make_bool_grid(cols: int, rows: int, fill: bool) -> Array:
	var grid: Array = []
	grid.resize(rows)
	for y in rows:
		var row: Array = []
		row.resize(cols)
		for x in cols:
			row[x] = fill
		grid[y] = row
	return grid


func _mark_rect_cells(grid: Array, rect: Rect2, cols: int, rows: int, value: bool) -> void:
	var x0 := clampi(int(floor(rect.position.x / float(TILE))), 0, cols - 1)
	var y0 := clampi(int(floor(rect.position.y / float(TILE))), 0, rows - 1)
	var x1 := clampi(int(ceil((rect.position.x + rect.size.x) / float(TILE))) - 1, 0, cols - 1)
	var y1 := clampi(int(ceil((rect.position.y + rect.size.y) / float(TILE))) - 1, 0, rows - 1)
	if x1 < x0 or y1 < y0:
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			grid[y][x] = value


func _mark_room_paths(path_grid: Array, room: Room, cols: int, rows: int) -> void:
	# Dirt clearing through room centers so corridors read as connected roads.
	var c := room.center()
	var cx := clampi(int(c.x / float(TILE)), 0, cols - 1)
	var cy := clampi(int(c.y / float(TILE)), 0, rows - 1)
	var half_w := maxi(1, int(room.rect.size.x / float(TILE * 4.0)))
	var half_h := maxi(1, int(room.rect.size.y / float(TILE * 4.0)))
	for y in range(maxi(0, cy - half_h), mini(rows, cy + half_h + 1)):
		for x in range(maxi(0, cx - half_w), mini(cols, cx + half_w + 1)):
			path_grid[y][x] = true
	# Cross through room for readable path junctions.
	var x0 := clampi(int(floor(room.rect.position.x / float(TILE))), 0, cols - 1)
	var x1 := clampi(int(ceil((room.rect.end.x) / float(TILE))) - 1, 0, cols - 1)
	var y0 := clampi(int(floor(room.rect.position.y / float(TILE))), 0, rows - 1)
	var y1 := clampi(int(ceil((room.rect.end.y) / float(TILE))) - 1, 0, rows - 1)
	for x in range(x0, x1 + 1):
		path_grid[cy][x] = true
	for y in range(y0, y1 + 1):
		path_grid[y][cx] = true


func _carve_river(water_grid: Array, path_grid: Array, cols: int, rows: int) -> void:
	if cols < 4 or rows < 4:
		return
	# Meander from a random map edge toward the opposite side, avoiding safe-room core.
	var start := Vector2i(_paint_rng.randi_range(1, cols - 2), 0)
	if _paint_rng.randf() < 0.5:
		start = Vector2i(0, _paint_rng.randi_range(1, rows - 2))
	var target := Vector2i(cols - 1, _paint_rng.randi_range(1, rows - 2))
	if start.x == 0:
		target = Vector2i(cols - 1, _paint_rng.randi_range(1, rows - 2))
	else:
		target = Vector2i(_paint_rng.randi_range(1, cols - 2), rows - 1)

	var avoid_center := Vector2i(cols / 2, rows / 2)
	if safe_room != null:
		var sc := safe_room.center()
		avoid_center = Vector2i(int(sc.x / float(TILE)), int(sc.y / float(TILE)))

	var cur := start
	var guard := 0
	while guard < cols * rows and cur != target:
		guard += 1
		_stamp_water(water_grid, path_grid, cur, cols, rows)
		var step := Vector2i(
			clampi(target.x - cur.x, -1, 1),
			clampi(target.y - cur.y, -1, 1)
		)
		if _paint_rng.randf() < 0.35:
			if _paint_rng.randf() < 0.5:
				step.x = _paint_rng.randi_range(-1, 1)
			else:
				step.y = _paint_rng.randi_range(-1, 1)
		var nxt := Vector2i(
			clampi(cur.x + step.x, 0, cols - 1),
			clampi(cur.y + step.y, 0, rows - 1)
		)
		# Soft avoidance of safe-room neighborhood.
		if abs(nxt.x - avoid_center.x) <= 2 and abs(nxt.y - avoid_center.y) <= 2:
			nxt = Vector2i(
				clampi(cur.x + (1 if cur.x >= avoid_center.x else -1), 0, cols - 1),
				clampi(cur.y + (1 if cur.y >= avoid_center.y else -1), 0, rows - 1)
			)
		if nxt == cur:
			break
		cur = nxt
	_stamp_water(water_grid, path_grid, target, cols, rows)


func _stamp_water(water_grid: Array, path_grid: Array, cell: Vector2i, cols: int, rows: int) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if abs(dx) + abs(dy) > 1 and _paint_rng.randf() > 0.35:
				continue
			var x := cell.x + dx
			var y := cell.y + dy
			if x < 0 or y < 0 or x >= cols or y >= rows:
				continue
			# Prefer carving beside roads rather than erasing whole roadbeds.
			if path_grid[y][x] and (dx != 0 or dy != 0) and _paint_rng.randf() < 0.7:
				continue
			water_grid[y][x] = true


func _scatter_props(
	props: TileMapLayer,
	walkable: Array,
	path_grid: Array,
	water_grid: Array,
	cols: int,
	rows: int
) -> void:
	for y in rows:
		for x in cols:
			if path_grid[y][x] or water_grid[y][x]:
				continue
			var cell := Vector2i(x, y)
			var edge := x <= 1 or y <= 1 or x >= cols - 2 or y >= rows - 2
			var roll := _paint_rng.randf()
			if edge and roll < 0.55:
				props.set_cell(
					cell,
					OverworldTilesetFactory.SOURCE_ID,
					OverworldTilesetFactory.scatter_prop(_paint_rng, "tree")
				)
			elif not walkable[y][x] and roll < 0.4:
				props.set_cell(
					cell,
					OverworldTilesetFactory.SOURCE_ID,
					OverworldTilesetFactory.scatter_prop(_paint_rng, "tree")
				)
			elif roll < 0.06:
				props.set_cell(
					cell,
					OverworldTilesetFactory.SOURCE_ID,
					OverworldTilesetFactory.scatter_prop(_paint_rng, "bush")
				)
			elif roll < 0.09:
				props.set_cell(
					cell,
					OverworldTilesetFactory.SOURCE_ID,
					OverworldTilesetFactory.scatter_prop(_paint_rng, "rock")
				)
			elif roll < 0.13:
				props.set_cell(
					cell,
					OverworldTilesetFactory.SOURCE_ID,
					OverworldTilesetFactory.scatter_prop(_paint_rng, "tuft")
				)
			elif roll < 0.145:
				var deco := "stump" if _paint_rng.randf() < 0.5 else "log"
				props.set_cell(
					cell,
					OverworldTilesetFactory.SOURCE_ID,
					OverworldTilesetFactory.scatter_prop(_paint_rng, deco)
				)


func _place_camp_props(props: TileMapLayer, room: Room) -> void:
	var c := room.center()
	var cx := int(c.x / float(TILE))
	var cy := int(c.y / float(TILE))
	var placements: Array = [
		[Vector2i(cx - 1, cy - 1), "tent"],
		[Vector2i(cx + 1, cy - 1), "campfire"],
		[Vector2i(cx, cy + 1), "chest"],
		[Vector2i(cx - 2, cy), "bush"],
		[Vector2i(cx + 2, cy), "rock"],
	]
	for item in placements:
		var cell: Vector2i = item[0]
		var kind: String = item[1]
		props.set_cell(
			cell,
			OverworldTilesetFactory.SOURCE_ID,
			OverworldTilesetFactory.scatter_prop(_paint_rng, kind)
		)


func _add_room_label(parent: Node2D, room: Room) -> void:
	var label := Label.new()
	label.text = "SAFE" if room.is_safe else "BOSS"
	label.position = room.center() + Vector2(-28, -room.rect.size.y * 0.42)
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(0.85, 0.95, 0.85, 0.7) if room.is_safe else Color(1.0, 0.7, 0.7, 0.75)
	label.z_index = 8
	parent.add_child(label)
