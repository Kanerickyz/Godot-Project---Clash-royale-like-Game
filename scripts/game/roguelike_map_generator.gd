class_name RoguelikeMapGenerator
extends RefCounted
## Lightweight roguelike layout: rectangular rooms + L-corridors, placeholder floor draw.


class Room:
	var rect: Rect2 = Rect2()
	var is_safe: bool = false
	var is_boss: bool = false

	func center() -> Vector2:
		return rect.get_center()


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


func build_visuals(parent: Node2D) -> void:
	if parent == null:
		return
	# Void / wall base.
	var void_poly := Polygon2D.new()
	void_poly.name = "MapVoid"
	void_poly.color = Color(0.10, 0.14, 0.11, 1.0)
	void_poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(map_size.x, 0),
		Vector2(map_size.x, map_size.y),
		Vector2(0, map_size.y),
	])
	parent.add_child(void_poly)

	for i in corridors.size():
		var c: Rect2 = corridors[i]
		var poly := Polygon2D.new()
		poly.name = "Corridor_%d" % i
		poly.color = Color(0.20, 0.28, 0.20, 1.0)
		poly.polygon = _rect_to_poly(c)
		parent.add_child(poly)

	for i in rooms.size():
		var room: Room = rooms[i]
		var poly := Polygon2D.new()
		poly.name = "Room_%d" % i
		if room.is_safe:
			poly.color = Color(0.28, 0.40, 0.30, 1.0)
		elif room.is_boss:
			poly.color = Color(0.34, 0.24, 0.24, 1.0)
		else:
			poly.color = Color(0.26, 0.36, 0.26, 1.0)
		poly.polygon = _rect_to_poly(room.rect)
		parent.add_child(poly)
		_add_room_outline(parent, room.rect, i)
		if room.is_safe or room.is_boss:
			_add_room_label(parent, room)

	# Soft grid over whole map for scale readability.
	var grid_step := 200.0
	var gx := grid_step
	while gx < map_size.x:
		var line_v := Line2D.new()
		line_v.width = 1.0
		line_v.default_color = Color(0.14, 0.20, 0.14, 0.35)
		line_v.points = PackedVector2Array([Vector2(gx, 0), Vector2(gx, map_size.y)])
		parent.add_child(line_v)
		gx += grid_step
	var gy := grid_step
	while gy < map_size.y:
		var line_h := Line2D.new()
		line_h.width = 1.0
		line_h.default_color = Color(0.14, 0.20, 0.14, 0.35)
		line_h.points = PackedVector2Array([Vector2(0, gy), Vector2(map_size.x, gy)])
		parent.add_child(line_h)
		gy += grid_step


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


func _rect_to_poly(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		rect.position + rect.size,
		Vector2(rect.position.x, rect.position.y + rect.size.y),
	])


func _add_room_outline(parent: Node2D, rect: Rect2, index: int) -> void:
	var line := Line2D.new()
	line.name = "RoomOutline_%d" % index
	line.width = 2.0
	line.default_color = Color(0.16, 0.22, 0.16, 0.85)
	line.closed = true
	line.points = _rect_to_poly(rect)
	parent.add_child(line)


func _add_room_label(parent: Node2D, room: Room) -> void:
	var label := Label.new()
	label.text = "SAFE" if room.is_safe else "BOSS"
	label.position = room.center() + Vector2(-28, -room.rect.size.y * 0.42)
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(0.85, 0.95, 0.85, 0.7) if room.is_safe else Color(1.0, 0.7, 0.7, 0.75)
	parent.add_child(label)
