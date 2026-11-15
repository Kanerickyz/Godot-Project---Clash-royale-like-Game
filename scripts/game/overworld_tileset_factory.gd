class_name OverworldTilesetFactory
extends RefCounted
## Builds a TileSet from the sliced overworld atlas (grass / path / water / props).


const PATH_ATLAS := "res://assets/sprites/overworld/overworld_tileset.png"
const TILE_SIZE := 64
const SOURCE_ID := 0
const PATH_MASK_ROW := 8
const WATER_MASK_ROW := 9

## N=1 E=2 S=4 W=8 — atlas column on mask rows.
const BIT_N := 1
const BIT_E := 2
const BIT_S := 4
const BIT_W := 8

## Checkerboard pair: warm yellow-green vs cooler olive (atlas row 0).
const GRASS_A := Vector2i(0, 0)
const GRASS_B := Vector2i(2, 0)

static var _grass_coords: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(4, 1), Vector2i(5, 1),
]

static var _prop_tree := Vector2i(0, 6)
static var _prop_bush := Vector2i(1, 6)
static var _prop_bush_yellow := Vector2i(2, 6)
static var _prop_bush_small := Vector2i(3, 6)
static var _prop_rocks_big := Vector2i(4, 6)
static var _prop_rocks_pair := Vector2i(5, 6)
static var _prop_rock := Vector2i(6, 6)
static var _prop_grass_tuft := Vector2i(7, 6)
static var _prop_stump := Vector2i(0, 7)
static var _prop_log := Vector2i(1, 7)
static var _prop_chest := Vector2i(2, 7)
static var _prop_campfire := Vector2i(3, 7)
static var _prop_tent := Vector2i(4, 7)
static var _prop_bush_low := Vector2i(5, 7)
static var _prop_bush_white := Vector2i(6, 7)
static var _prop_grass_tuft2 := Vector2i(7, 7)


static func build_tileset() -> TileSet:
	var tex := load(PATH_ATLAS) as Texture2D
	if tex == null:
		push_warning("OverworldTilesetFactory: missing atlas %s" % PATH_ATLAS)
		return TileSet.new()

	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var cols := int(tex.get_width()) / TILE_SIZE
	var rows := int(tex.get_height()) / TILE_SIZE
	for y in rows:
		for x in cols:
			var coords := Vector2i(x, y)
			if not atlas.has_tile(coords):
				atlas.create_tile(coords)

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_source(atlas, SOURCE_ID)
	return tileset


static func grass_atlas(rng: RandomNumberGenerator) -> Vector2i:
	if _grass_coords.is_empty():
		return GRASS_A
	return _grass_coords[rng.randi() % _grass_coords.size()]


static func grass_checker_atlas(x: int, y: int) -> Vector2i:
	return GRASS_A if ((x + y) & 1) == 0 else GRASS_B


static func path_atlas(mask: int) -> Vector2i:
	return Vector2i(clampi(mask, 0, 15), PATH_MASK_ROW)


static func water_atlas(mask: int) -> Vector2i:
	return Vector2i(clampi(mask, 0, 15), WATER_MASK_ROW)


static func neighbor_mask(grid: Array, x: int, y: int, cols: int, rows: int) -> int:
	var mask := 0
	if y > 0 and bool(grid[y - 1][x]):
		mask |= BIT_N
	if x + 1 < cols and bool(grid[y][x + 1]):
		mask |= BIT_E
	if y + 1 < rows and bool(grid[y + 1][x]):
		mask |= BIT_S
	if x > 0 and bool(grid[y][x - 1]):
		mask |= BIT_W
	return mask


static func scatter_prop(rng: RandomNumberGenerator, kind: String) -> Vector2i:
	match kind:
		"tree":
			return _prop_tree
		"bush":
			var bushes: Array[Vector2i] = [
				_prop_bush, _prop_bush_yellow, _prop_bush_small, _prop_bush_low, _prop_bush_white
			]
			return bushes[rng.randi() % bushes.size()]
		"rock":
			var rocks: Array[Vector2i] = [_prop_rocks_big, _prop_rocks_pair, _prop_rock]
			return rocks[rng.randi() % rocks.size()]
		"wall_rock":
			# Prefer denser rocks for dungeon wall silhouettes.
			var wall_rocks: Array[Vector2i] = [
				_prop_rocks_big, _prop_rocks_pair, _prop_rock, _prop_rocks_big
			]
			return wall_rocks[rng.randi() % wall_rocks.size()]
		"tuft":
			return _prop_grass_tuft if rng.randf() < 0.5 else _prop_grass_tuft2
		"stump":
			return _prop_stump
		"log":
			return _prop_log
		"chest":
			return _prop_chest
		"campfire":
			return _prop_campfire
		"tent":
			return _prop_tent
		_:
			return _prop_bush_small


static func campfire_atlas() -> Vector2i:
	return _prop_campfire


static func rock_atlas(rng: RandomNumberGenerator) -> Vector2i:
	return scatter_prop(rng, "wall_rock")


## Prop atlas with grass chroma-keyed out for dungeon floors/walls.
static func build_clean_prop_tileset() -> TileSet:
	var src := _load_atlas_image()
	if src == null:
		push_warning("OverworldTilesetFactory: cannot read atlas pixels; props skipped")
		return TileSet.new()

	var cleaned := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	cleaned.fill(Color(0, 0, 0, 0))
	# Only prop rows (6–7) need cleaning; leave rest transparent.
	for row in [6, 7]:
		for col in range(8):
			_blit_prop_cleared(src, cleaned, Vector2i(col, row))

	var out_tex := ImageTexture.create_from_image(cleaned)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = out_tex
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for row in [6, 7]:
		for col in range(8):
			var coords := Vector2i(col, row)
			if not atlas.has_tile(coords):
				atlas.create_tile(coords)

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_source(atlas, SOURCE_ID)
	return tileset


static func _load_atlas_image() -> Image:
	# Prefer raw file decode — CompressedTexture2D.get_image() is often null at runtime.
	var abs_path := ProjectSettings.globalize_path(PATH_ATLAS)
	if FileAccess.file_exists(abs_path):
		var from_file := Image.load_from_file(abs_path)
		if from_file != null:
			return from_file
	var tex := load(PATH_ATLAS) as Texture2D
	if tex == null:
		return null
	return tex.get_image()


static func _blit_prop_cleared(src: Image, dst: Image, atlas_xy: Vector2i) -> void:
	var ox := atlas_xy.x * TILE_SIZE
	var oy := atlas_xy.y * TILE_SIZE
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var c := src.get_pixel(ox + x, oy + y)
			if _is_grass_pixel(c):
				dst.set_pixel(ox + x, oy + y, Color(0, 0, 0, 0))
			else:
				dst.set_pixel(ox + x, oy + y, c)


static func _is_grass_pixel(c: Color) -> bool:
	# Paper-cutout grass is yellow-olive (R≈G, B much lower), not G-dominant.
	if c.a < 0.12:
		return true
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	# Low-saturation gray rocks / iron stay.
	if mx - mn < 0.12:
		return false
	# Flame / ember: strongly red over green.
	if c.r > c.g + 0.12 and c.r > c.b + 0.15 and c.g < 0.55:
		return false
	var warm := (c.r + c.g) * 0.5
	# Bright yellow-olive grass checker.
	if (
		warm > 0.40
		and c.b < warm - 0.18
		and absf(c.r - c.g) < 0.22
		and c.g > c.b + 0.08
		and (c.r - c.g) < 0.18
	):
		return true
	# Dimmer olive fringe.
	if (
		warm > 0.28
		and c.b < warm - 0.12
		and absf(c.r - c.g) < 0.18
		and c.g > c.b + 0.05
		and mx < 0.75
		and (c.r - c.g) < 0.15
	):
		return true
	return false
