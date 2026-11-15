class_name DungeonTilesetFactory
extends RefCounted
## Procedural stone / void TileSet for Skull Horde dungeon floors (GL Compatibility).
## Used when overworld path tiles (grass fringe) are too outdoor for dungeon rooms.


const TILE_SIZE := 64
const SOURCE_ID := 0

## Atlas columns (single row).
const ATLAS_VOID := Vector2i(0, 0)
const ATLAS_WALL := Vector2i(1, 0)
const ATLAS_FLOOR_A := Vector2i(2, 0)
const ATLAS_FLOOR_B := Vector2i(3, 0)
const ATLAS_SAFE_A := Vector2i(4, 0)
const ATLAS_SAFE_B := Vector2i(5, 0)
const ATLAS_EXIT_A := Vector2i(6, 0)
const ATLAS_EXIT_B := Vector2i(7, 0)
const ATLAS_CORRIDOR_A := Vector2i(8, 0)
const ATLAS_CORRIDOR_B := Vector2i(9, 0)
## Extra wall-fill variants (no grass) when overworld props unavailable.
const ATLAS_WALL_FILL_A := Vector2i(10, 0)
const ATLAS_WALL_FILL_B := Vector2i(11, 0)

const _COL_COUNT := 12


static func build_tileset() -> TileSet:
	var img := Image.create(TILE_SIZE * _COL_COUNT, TILE_SIZE, false, Image.FORMAT_RGBA8)
	_paint_tile(img, 0, Color(0.06, 0.05, 0.09, 1.0), Color(0.04, 0.03, 0.07, 1.0), 0.04)
	_paint_tile(img, 1, Color(0.18, 0.16, 0.20, 1.0), Color(0.12, 0.10, 0.14, 1.0), 0.12)
	_paint_tile(img, 2, Color(0.42, 0.38, 0.34, 1.0), Color(0.34, 0.30, 0.28, 1.0), 0.10)
	_paint_tile(img, 3, Color(0.38, 0.34, 0.32, 1.0), Color(0.30, 0.28, 0.26, 1.0), 0.10)
	_paint_tile(img, 4, Color(0.40, 0.44, 0.36, 1.0), Color(0.32, 0.36, 0.28, 1.0), 0.09)
	_paint_tile(img, 5, Color(0.36, 0.40, 0.32, 1.0), Color(0.28, 0.32, 0.26, 1.0), 0.09)
	_paint_tile(img, 6, Color(0.34, 0.36, 0.46, 1.0), Color(0.26, 0.28, 0.38, 1.0), 0.09)
	_paint_tile(img, 7, Color(0.30, 0.32, 0.42, 1.0), Color(0.22, 0.24, 0.34, 1.0), 0.09)
	_paint_tile(img, 8, Color(0.32, 0.30, 0.30, 1.0), Color(0.24, 0.22, 0.22, 1.0), 0.08)
	_paint_tile(img, 9, Color(0.28, 0.26, 0.26, 1.0), Color(0.22, 0.20, 0.20, 1.0), 0.08)
	_paint_tile(img, 10, Color(0.22, 0.20, 0.24, 1.0), Color(0.14, 0.12, 0.16, 1.0), 0.14)
	_paint_tile(img, 11, Color(0.20, 0.18, 0.22, 1.0), Color(0.12, 0.11, 0.14, 1.0), 0.14)

	var tex := ImageTexture.create_from_image(img)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for x in _COL_COUNT:
		var coords := Vector2i(x, 0)
		if not atlas.has_tile(coords):
			atlas.create_tile(coords)

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_source(atlas, SOURCE_ID)
	return tileset


static func floor_atlas(kind: String, x: int, y: int) -> Vector2i:
	var checker := ((x + y) & 1) == 0
	match kind:
		"safe":
			return ATLAS_SAFE_A if checker else ATLAS_SAFE_B
		"exit":
			return ATLAS_EXIT_A if checker else ATLAS_EXIT_B
		"corridor":
			return ATLAS_CORRIDOR_A if checker else ATLAS_CORRIDOR_B
		_:
			return ATLAS_FLOOR_A if checker else ATLAS_FLOOR_B


static func wall_fill_atlas(x: int, y: int) -> Vector2i:
	return ATLAS_WALL_FILL_A if ((x + y) & 1) == 0 else ATLAS_WALL_FILL_B


static func _paint_tile(
	img: Image,
	col: int,
	base: Color,
	alt: Color,
	noise: float
) -> void:
	var ox := col * TILE_SIZE
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var t := float((x * 17 + y * 31 + col * 13) % 97) / 97.0
			var c := base.lerp(alt, t)
			# Subtle brick / flagstone seams every 16 px.
			if x % 16 == 0 or y % 16 == 0:
				c = c.darkened(0.18)
			elif x % 16 == 1 or y % 16 == 1:
				c = c.lightened(0.06)
			# Pixel noise for stone grit.
			var n := float((x * 13 + y * 7 + col * 3) % 11) / 11.0
			c = c.lightened((n - 0.5) * noise)
			img.set_pixel(ox + x, y, c)
