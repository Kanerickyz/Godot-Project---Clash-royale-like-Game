class_name DungeonTilesetFactory
extends RefCounted
## Procedural stone / void TileSet for Skull Horde dungeon floors (GL Compatibility).
## Supports multiple dungeon-type palettes (crypt / aqueduct) without new art assets.


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


static func build_tileset(type_id: String = "crypt") -> TileSet:
	var p := _palette_for(type_id)
	var img := Image.create(TILE_SIZE * _COL_COUNT, TILE_SIZE, false, Image.FORMAT_RGBA8)
	_paint_tile(img, 0, p["void_a"], p["void_b"], 0.04)
	_paint_tile(img, 1, p["wall_a"], p["wall_b"], 0.12)
	_paint_tile(img, 2, p["floor_a"], p["floor_b"], 0.10)
	_paint_tile(img, 3, p["floor_b"], p["floor_c"], 0.10)
	_paint_tile(img, 4, p["safe_a"], p["safe_b"], 0.09)
	_paint_tile(img, 5, p["safe_b"], p["safe_c"], 0.09)
	_paint_tile(img, 6, p["exit_a"], p["exit_b"], 0.09)
	_paint_tile(img, 7, p["exit_b"], p["exit_c"], 0.09)
	_paint_tile(img, 8, p["corr_a"], p["corr_b"], 0.08)
	_paint_tile(img, 9, p["corr_b"], p["corr_c"], 0.08)
	_paint_tile(img, 10, p["fill_a"], p["fill_b"], 0.14)
	_paint_tile(img, 11, p["fill_b"], p["fill_c"], 0.14)

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


static func atmosphere_modulate(type_id: String) -> Color:
	match type_id:
		"aqueduct":
			return Color(0.16, 0.22, 0.32, 0.58)
		_:
			return Color(0.22, 0.18, 0.28, 0.55)


static func void_color(type_id: String) -> Color:
	match type_id:
		"aqueduct":
			return Color(0.04, 0.06, 0.10, 1.0)
		_:
			return Color(0.05, 0.04, 0.07, 1.0)


static func _palette_for(type_id: String) -> Dictionary:
	match type_id:
		"aqueduct":
			# Cool blue-stone / canal tint — second dungeon type without new PNG art.
			return {
				"void_a": Color(0.05, 0.07, 0.11, 1.0),
				"void_b": Color(0.03, 0.05, 0.08, 1.0),
				"wall_a": Color(0.14, 0.18, 0.24, 1.0),
				"wall_b": Color(0.10, 0.13, 0.18, 1.0),
				"floor_a": Color(0.32, 0.40, 0.46, 1.0),
				"floor_b": Color(0.28, 0.36, 0.42, 1.0),
				"floor_c": Color(0.24, 0.32, 0.38, 1.0),
				"safe_a": Color(0.30, 0.44, 0.42, 1.0),
				"safe_b": Color(0.26, 0.40, 0.38, 1.0),
				"safe_c": Color(0.22, 0.36, 0.34, 1.0),
				"exit_a": Color(0.28, 0.34, 0.52, 1.0),
				"exit_b": Color(0.24, 0.30, 0.46, 1.0),
				"exit_c": Color(0.20, 0.26, 0.40, 1.0),
				"corr_a": Color(0.26, 0.30, 0.36, 1.0),
				"corr_b": Color(0.22, 0.26, 0.32, 1.0),
				"corr_c": Color(0.18, 0.22, 0.28, 1.0),
				"fill_a": Color(0.16, 0.20, 0.26, 1.0),
				"fill_b": Color(0.12, 0.16, 0.22, 1.0),
				"fill_c": Color(0.10, 0.13, 0.18, 1.0),
			}
		_:
			# Default crypt / tomb warm stone (Phase B baseline).
			return {
				"void_a": Color(0.06, 0.05, 0.09, 1.0),
				"void_b": Color(0.04, 0.03, 0.07, 1.0),
				"wall_a": Color(0.18, 0.16, 0.20, 1.0),
				"wall_b": Color(0.12, 0.10, 0.14, 1.0),
				"floor_a": Color(0.42, 0.38, 0.34, 1.0),
				"floor_b": Color(0.38, 0.34, 0.32, 1.0),
				"floor_c": Color(0.30, 0.28, 0.26, 1.0),
				"safe_a": Color(0.40, 0.44, 0.36, 1.0),
				"safe_b": Color(0.36, 0.40, 0.32, 1.0),
				"safe_c": Color(0.28, 0.32, 0.26, 1.0),
				"exit_a": Color(0.34, 0.36, 0.46, 1.0),
				"exit_b": Color(0.30, 0.32, 0.42, 1.0),
				"exit_c": Color(0.22, 0.24, 0.34, 1.0),
				"corr_a": Color(0.32, 0.30, 0.30, 1.0),
				"corr_b": Color(0.28, 0.26, 0.26, 1.0),
				"corr_c": Color(0.22, 0.20, 0.20, 1.0),
				"fill_a": Color(0.22, 0.20, 0.24, 1.0),
				"fill_b": Color(0.20, 0.18, 0.22, 1.0),
				"fill_c": Color(0.12, 0.11, 0.14, 1.0),
			}


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
