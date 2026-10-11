class_name TerrainType
extends RefCounted

enum Type {
	GRASS,
	JUNGLE,
	LAKE,
	SHORE,
	ROCK,
	DENSE_JUNGLE,
}


static func display_name(type: Type) -> String:
	match type:
		Type.GRASS:
			return "草地"
		Type.JUNGLE:
			return "丛林"
		Type.LAKE:
			return "湖泊"
		Type.SHORE:
			return "岸边"
		Type.ROCK:
			return "岩石"
		Type.DENSE_JUNGLE:
			return "密林"
		_:
			return "未知"


static func all_types() -> Array[Type]:
	return [
		Type.GRASS,
		Type.JUNGLE,
		Type.LAKE,
		Type.SHORE,
		Type.ROCK,
		Type.DENSE_JUNGLE,
	]
