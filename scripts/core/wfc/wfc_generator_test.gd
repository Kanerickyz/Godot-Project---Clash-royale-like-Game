class_name WfcGeneratorTest
extends RefCounted


static func run_all() -> bool:
	var passed := true
	passed = _test_seed_reproducible() and passed
	passed = _test_adjacency_valid() and passed
	passed = _test_walkable_connected() and passed
	passed = _test_walkable_ratio() and passed
	passed = _test_batch_generation() and passed
	passed = _test_manual_blocked_unaffected() and passed
	passed = _test_blocked_from_unwalkable() and passed
	if passed:
		print("WfcGeneratorTest: all passed")
	else:
		push_error("WfcGeneratorTest: failures detected")
	return passed


static func _make_tileset() -> TerrainTileset:
	return TerrainTileset.create_default()


static func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _maps_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key):
			return false
		if int(a[key]) != int(b[key]):
			return false
	return true


static func _test_seed_reproducible() -> bool:
	var tileset := _make_tileset()
	var size := Vector2i(8, 8)
	var a := WfcGenerator.generate(size, tileset, _make_rng(12345))
	var b := WfcGenerator.generate(size, tileset, _make_rng(12345))
	if not _maps_equal(a, b):
		push_error("WfcGeneratorTest: same seed produced different maps")
		return false
	var c := WfcGenerator.generate(size, tileset, _make_rng(99999))
	if _maps_equal(a, c):
		# Extremely unlikely but not impossible; only warn via soft check.
		# Different seed should usually differ — if equal, still OK for pass.
		pass
	return true


static func _test_adjacency_valid() -> bool:
	var tileset := _make_tileset()
	var size := Vector2i(8, 8)
	var terrain := WfcGenerator.generate(size, tileset, _make_rng(7))
	if not WfcGenerator.validate_adjacency(terrain, size, tileset):
		push_error("WfcGeneratorTest: adjacency validation failed")
		return false
	return true


static func _test_walkable_connected() -> bool:
	var tileset := _make_tileset()
	var size := Vector2i(8, 8)
	var terrain := WfcGenerator.generate(size, tileset, _make_rng(42))
	if not WfcGenerator.is_walkable_connected(terrain, size, tileset):
		push_error("WfcGeneratorTest: walkable cells not 4-connected")
		return false
	return true


static func _test_walkable_ratio() -> bool:
	var tileset := _make_tileset()
	var size := Vector2i(8, 8)
	var terrain := WfcGenerator.generate(size, tileset, _make_rng(1001))
	var ratio := WfcGenerator.walkable_ratio(terrain, size, tileset)
	if ratio < tileset.min_walkable_ratio:
		push_error(
			"WfcGeneratorTest: walkable ratio %.3f < min %.3f" % [ratio, tileset.min_walkable_ratio]
		)
		return false
	return true


static func _test_batch_generation() -> bool:
	var tileset := _make_tileset()
	var size := Vector2i(8, 8)
	for i in 20:
		var terrain := WfcGenerator.generate(size, tileset, _make_rng(2000 + i))
		if terrain.is_empty():
			push_error("WfcGeneratorTest: empty map at seed %d" % (2000 + i))
			return false
		if terrain.size() != size.x * size.y:
			push_error("WfcGeneratorTest: incomplete map at seed %d" % (2000 + i))
			return false
		if not WfcGenerator.is_walkable_connected(terrain, size, tileset):
			push_error("WfcGeneratorTest: disconnected at seed %d" % (2000 + i))
			return false
		if WfcGenerator.walkable_ratio(terrain, size, tileset) < tileset.min_walkable_ratio:
			push_error("WfcGeneratorTest: low walkable ratio at seed %d" % (2000 + i))
			return false
	return true


static func _test_manual_blocked_unaffected() -> bool:
	## When generate_terrain is false, BoardGrid.configure keeps manual blocked cells.
	var grid := BoardGrid.new()
	var blocked: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 3)]
	grid.configure(Vector2i(6, 6), blocked)
	if grid.has_terrain():
		push_error("WfcGeneratorTest: manual configure should not set terrain")
		return false
	if not grid.is_blocked(Vector2i(1, 1)) or not grid.is_blocked(Vector2i(2, 3)):
		push_error("WfcGeneratorTest: manual blocked cells lost")
		return false
	if grid.is_blocked(Vector2i(0, 0)):
		push_error("WfcGeneratorTest: unexpected blocked cell")
		return false
	return true


static func _test_blocked_from_unwalkable() -> bool:
	var tileset := _make_tileset()
	var size := Vector2i(8, 8)
	var terrain := WfcGenerator.generate(size, tileset, _make_rng(55))
	var grid := BoardGrid.new()
	grid.configure_from_terrain(size, terrain, tileset)
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var t: TerrainType.Type = terrain[cell]
			var expect_blocked := not tileset.is_walkable(t)
			if grid.is_blocked(cell) != expect_blocked:
				push_error(
					"WfcGeneratorTest: blocked mismatch at %s terrain=%d" % [str(cell), int(t)]
				)
				return false
			if grid.get_terrain(cell) != t:
				push_error("WfcGeneratorTest: terrain mismatch at %s" % str(cell))
				return false
	return true
