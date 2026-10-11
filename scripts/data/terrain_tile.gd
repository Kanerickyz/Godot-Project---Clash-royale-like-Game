class_name TerrainTile
extends Resource

@export var type: TerrainType.Type = TerrainType.Type.GRASS
@export var display_name: String = "草地"
@export var walkable: bool = true
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export var color: Color = Color(0.486, 0.702, 0.259, 1.0)
## Compatible neighbor terrain types (undirected adjacency for simple tiled WFC).
@export var compatible: Array[TerrainType.Type] = []


func is_compatible_with(other: TerrainType.Type) -> bool:
	return compatible.has(other)
