class_name TerrainTileset
extends Resource

const DEFAULT_PATH := "res://resources/terrain/default_tileset.tres"

@export var tiles: Array[TerrainTile] = []
@export var default_type: TerrainType.Type = TerrainType.Type.GRASS
@export_range(0.0, 1.0, 0.01) var min_walkable_ratio: float = 0.70
@export_range(1, 64, 1) var max_retries: int = 12
@export_range(0, 10000, 1) var max_backtracks: int = 256


func get_tile(type: TerrainType.Type) -> TerrainTile:
	for tile in tiles:
		if tile != null and tile.type == type:
			return tile
	return null


func is_walkable(type: TerrainType.Type) -> bool:
	var tile := get_tile(type)
	if tile == null:
		return type == TerrainType.Type.GRASS
	return tile.walkable


func get_weight(type: TerrainType.Type) -> float:
	var tile := get_tile(type)
	if tile == null:
		return 0.0
	return maxf(0.0, tile.weight)


func get_color(type: TerrainType.Type) -> Color:
	var tile := get_tile(type)
	if tile == null:
		return Color.WHITE
	return tile.color


func are_compatible(a: TerrainType.Type, b: TerrainType.Type) -> bool:
	var tile_a := get_tile(a)
	if tile_a == null:
		return false
	return tile_a.is_compatible_with(b)


func get_all_types() -> Array[TerrainType.Type]:
	var result: Array[TerrainType.Type] = []
	for tile in tiles:
		if tile != null:
			result.append(tile.type)
	return result


func build_adjacency() -> Dictionary:
	## type -> Dictionary of allowed neighbor types (as keys with true)
	var adj: Dictionary = {}
	for tile in tiles:
		if tile == null:
			continue
		var allowed: Dictionary = {}
		for other in tile.compatible:
			allowed[other] = true
		adj[tile.type] = allowed
	return adj


static func create_default() -> TerrainTileset:
	var set := TerrainTileset.new()
	set.default_type = TerrainType.Type.GRASS
	set.min_walkable_ratio = 0.70
	set.max_retries = 12
	set.max_backtracks = 256
	set.tiles = [
		_make_tile(
			TerrainType.Type.GRASS,
			"草地",
			true,
			10.0,
			Color(0.486, 0.702, 0.259, 1.0), # #7CB342
			[
				TerrainType.Type.GRASS,
				TerrainType.Type.SHORE,
				TerrainType.Type.JUNGLE,
				TerrainType.Type.ROCK,
			],
		),
		_make_tile(
			TerrainType.Type.JUNGLE,
			"丛林",
			true,
			5.0,
			Color(0.180, 0.490, 0.196, 1.0), # #2E7D32
			[
				TerrainType.Type.JUNGLE,
				TerrainType.Type.GRASS,
				TerrainType.Type.DENSE_JUNGLE,
			],
		),
		_make_tile(
			TerrainType.Type.LAKE,
			"湖泊",
			false,
			3.0,
			Color(0.098, 0.463, 0.824, 1.0), # #1976D2
			[
				TerrainType.Type.LAKE,
				TerrainType.Type.SHORE,
			],
		),
		_make_tile(
			TerrainType.Type.SHORE,
			"岸边",
			true,
			4.0,
			Color(1.0, 0.878, 0.510, 1.0), # #FFE082
			[
				TerrainType.Type.SHORE,
				TerrainType.Type.GRASS,
				TerrainType.Type.LAKE,
				TerrainType.Type.ROCK,
			],
		),
		_make_tile(
			TerrainType.Type.ROCK,
			"岩石",
			false,
			1.5,
			Color(0.471, 0.565, 0.612, 1.0), # #78909C
			[
				TerrainType.Type.GRASS,
				TerrainType.Type.SHORE,
			],
		),
		_make_tile(
			TerrainType.Type.DENSE_JUNGLE,
			"密林",
			false,
			1.5,
			Color(0.106, 0.369, 0.125, 1.0), # #1B5E20
			[
				TerrainType.Type.JUNGLE,
				TerrainType.Type.DENSE_JUNGLE,
			],
		),
	]
	return set


static func load_or_default(path: String = DEFAULT_PATH) -> TerrainTileset:
	if ResourceLoader.exists(path):
		var loaded := load(path) as TerrainTileset
		if loaded != null and not loaded.tiles.is_empty():
			return loaded
	return create_default()


static func _make_tile(
	type: TerrainType.Type,
	name: String,
	walkable: bool,
	weight: float,
	color: Color,
	compatible: Array,
) -> TerrainTile:
	var tile := TerrainTile.new()
	tile.type = type
	tile.display_name = name
	tile.walkable = walkable
	tile.weight = weight
	tile.color = color
	var compat: Array[TerrainType.Type] = []
	for item in compatible:
		compat.append(item as TerrainType.Type)
	tile.compatible = compat
	return tile
