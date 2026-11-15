class_name RoguelikeMapGenerator
extends RefCounted
## Roguelike layout: rectangular rooms + L-corridors, painted as Skull Horde dungeon.


class Room:
	var rect: Rect2 = Rect2()
	var is_safe: bool = false
	var is_boss: bool = false

	func center() -> Vector2:
		return rect.get_center()


const TILE := OverworldTilesetFactory.TILE_SIZE
const ARENA_BG := "res://assets/sprites/paper_cutout/env/arena_background.jpg"

## Walk-cell kinds for painting.
const CELL_VOID := 0
const CELL_ROOM := 1
const CELL_CORRIDOR := 2
const CELL_SAFE := 3
const CELL_EXIT := 4

var map_size: Vector2 = Vector2(2800, 2200)
var rooms: Array[Room] = []
var corridors: Array[Rect2] = []
var safe_room: Room
var boss_room: Room


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
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var cols := maxi(1, int(ceili(map_size.x / float(TILE))))
	var rows := maxi(1, int(ceili(map_size.y / float(TILE))))
	var grid := _build_cell_grid(cols, rows)

	_add_atmosphere(parent)
	_paint_dungeon_layers(parent, grid, cols, rows, rng)

	for room in rooms:
		if room.is_safe or room.is_boss:
			_add_room_label(parent, room)


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


func _add_room_label(parent: Node2D, room: Room) -> void:
	var label := Label.new()
	# Boss room slot is the Phase A exit/portal room (no end-boss in this phase).
	label.text = "SAFE" if room.is_safe else "EXIT"
	label.position = room.center() + Vector2(-28, -room.rect.size.y * 0.42)
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(0.85, 0.95, 0.85, 0.7) if room.is_safe else Color(0.7, 0.85, 1.0, 0.8)
	label.z_index = 8
	parent.add_child(label)


func _build_cell_grid(cols: int, rows: int) -> Array:
	var grid: Array = []
	grid.resize(rows)
	for y in rows:
		var row: Array = []
		row.resize(cols)
		row.fill(CELL_VOID)
		grid[y] = row

	for rect in corridors:
		_stamp_rect(grid, cols, rows, rect, CELL_CORRIDOR)

	for room in rooms:
		var kind := CELL_ROOM
		if room.is_safe:
			kind = CELL_SAFE
		elif room.is_boss:
			kind = CELL_EXIT
		_stamp_rect(grid, cols, rows, room.rect, kind)

	return grid


func _stamp_rect(grid: Array, cols: int, rows: int, rect: Rect2, kind: int) -> void:
	var x0 := clampi(int(floor(rect.position.x / float(TILE))), 0, cols - 1)
	var y0 := clampi(int(floor(rect.position.y / float(TILE))), 0, rows - 1)
	var x1 := clampi(int(ceili((rect.position.x + rect.size.x) / float(TILE))) - 1, 0, cols - 1)
	var y1 := clampi(int(ceili((rect.position.y + rect.size.y) / float(TILE))) - 1, 0, rows - 1)
	if x1 < x0 or y1 < y0:
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			# Rooms overwrite corridors so special floors win.
			var prev: int = grid[y][x]
			if kind == CELL_CORRIDOR and prev != CELL_VOID:
				continue
			grid[y][x] = kind


func _add_atmosphere(parent: Node2D) -> void:
	# Deep void under everything so gaps never flash grass.
	var void_poly := Polygon2D.new()
	void_poly.name = "DungeonVoid"
	void_poly.color = Color(0.05, 0.04, 0.07, 1.0)
	void_poly.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(map_size.x, 0.0),
		map_size,
		Vector2(0.0, map_size.y),
	])
	void_poly.z_index = -20
	parent.add_child(void_poly)

	var tex := load(ARENA_BG) as Texture2D
	if tex == null:
		return
	var bg := Sprite2D.new()
	bg.name = "DungeonAtmosphere"
	bg.texture = tex
	bg.centered = false
	bg.position = Vector2.ZERO
	bg.z_index = -18
	# Stretch portrait arena art across the dungeon map; keep dark.
	var sx := map_size.x / float(tex.get_width())
	var sy := map_size.y / float(tex.get_height())
	bg.scale = Vector2(sx, sy)
	bg.modulate = Color(0.22, 0.18, 0.28, 0.55)
	parent.add_child(bg)


func _paint_dungeon_layers(
	parent: Node2D,
	grid: Array,
	cols: int,
	rows: int,
	rng: RandomNumberGenerator
) -> void:
	var dungeon_set := DungeonTilesetFactory.build_tileset()
	# Cleaned props: campfire/rocks without baked grass fringe.
	var prop_set := OverworldTilesetFactory.build_clean_prop_tileset()

	var ground := TileMapLayer.new()
	ground.name = "GroundTiles"
	ground.tile_set = dungeon_set
	ground.z_index = 0
	parent.add_child(ground)

	var walls := TileMapLayer.new()
	walls.name = "WallTiles"
	walls.tile_set = dungeon_set
	walls.z_index = 1
	parent.add_child(walls)

	var props := TileMapLayer.new()
	props.name = "PropTiles"
	props.tile_set = prop_set
	props.z_index = 2
	parent.add_child(props)

	var walk_count := 0
	for y in rows:
		for x in cols:
			var kind: int = grid[y][x]
			var cell := Vector2i(x, y)
			if kind == CELL_VOID:
				# Only paint wall ring around walkable space (keep void dark).
				if _is_wall_edge(grid, x, y, cols, rows):
					walls.set_cell(
						cell,
						DungeonTilesetFactory.SOURCE_ID,
						DungeonTilesetFactory.wall_fill_atlas(x, y)
					)
					# Sparse cleaned rock props (grass keyed out) for silhouette.
					if rng.randf() < 0.35 and prop_set.get_source_count() > 0:
						props.set_cell(
							cell,
							OverworldTilesetFactory.SOURCE_ID,
							OverworldTilesetFactory.rock_atlas(rng)
						)
				continue

			walk_count += 1
			var floor_kind := "room"
			match kind:
				CELL_SAFE:
					floor_kind = "safe"
				CELL_EXIT:
					floor_kind = "exit"
				CELL_CORRIDOR:
					floor_kind = "corridor"
				_:
					floor_kind = "room"
			ground.set_cell(
				cell,
				DungeonTilesetFactory.SOURCE_ID,
				DungeonTilesetFactory.floor_atlas(floor_kind, x, y)
			)

	# Torch-like campfires: one near each room center (safe/exit always).
	for room in rooms:
		_place_room_torch(props, room, rng)

	# Sparse rocks inside rooms along inner rim (not corridors).
	_scatter_inner_rocks(props, grid, cols, rows, rng)

	if walk_count < 10:
		push_warning("RoguelikeMapGenerator: few walkable cells (%d)" % walk_count)


func _is_wall_edge(grid: Array, x: int, y: int, cols: int, rows: int) -> bool:
	if grid[y][x] != CELL_VOID:
		return false
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
			continue
		if grid[ny][nx] != CELL_VOID:
			return true
	return false


func _place_room_torch(props: TileMapLayer, room: Room, rng: RandomNumberGenerator) -> void:
	if room == null:
		return
	# Offset from center so label / portal remain readable.
	var offset := Vector2(
		rng.randf_range(-room.rect.size.x * 0.22, room.rect.size.x * 0.22),
		rng.randf_range(-room.rect.size.y * 0.18, room.rect.size.y * 0.18)
	)
	var pos := room.center() + offset
	var cell := Vector2i(int(pos.x / float(TILE)), int(pos.y / float(TILE)))
	props.set_cell(
		cell,
		OverworldTilesetFactory.SOURCE_ID,
		OverworldTilesetFactory.campfire_atlas()
	)
	# Extra torch chance for larger rooms.
	if room.rect.size.x * room.rect.size.y > 120000.0 and rng.randf() < 0.65:
		var pos2 := room.center() + Vector2(-offset.x, offset.y)
		var cell2 := Vector2i(int(pos2.x / float(TILE)), int(pos2.y / float(TILE)))
		if cell2 != cell:
			props.set_cell(
				cell2,
				OverworldTilesetFactory.SOURCE_ID,
				OverworldTilesetFactory.campfire_atlas()
			)


func _scatter_inner_rocks(
	props: TileMapLayer,
	grid: Array,
	cols: int,
	rows: int,
	rng: RandomNumberGenerator
) -> void:
	for y in rows:
		for x in cols:
			var kind: int = grid[y][x]
			if kind == CELL_VOID or kind == CELL_CORRIDOR:
				continue
			# Inner rim: walkable cell with a void neighbor.
			if not _touches_void(grid, x, y, cols, rows):
				continue
			if rng.randf() > 0.18:
				continue
			# Don't overwrite campfire cells.
			if props.get_cell_source_id(Vector2i(x, y)) != -1:
				continue
			props.set_cell(
				Vector2i(x, y),
				OverworldTilesetFactory.SOURCE_ID,
				OverworldTilesetFactory.rock_atlas(rng)
			)


func _touches_void(grid: Array, x: int, y: int, cols: int, rows: int) -> bool:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
			return true
		if grid[ny][nx] == CELL_VOID:
			return true
	return false
