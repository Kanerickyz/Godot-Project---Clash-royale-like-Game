class_name MapNodeData
extends Resource

@export var id: int = -1
@export var floor: int = 0
@export var column: int = 0
@export var node_type: MapNodeType.Type = MapNodeType.Type.COMBAT
@export var encounter: EncounterData
@export var event_data: EventData
@export var outgoing_ids: Array[int] = []

var visited: bool = false
var available: bool = false
var completed: bool = false
## MYSTERY 节点进入时解析出的实际类型
var resolved_type: MapNodeType.Type = MapNodeType.Type.COMBAT


func is_combat_node() -> bool:
	return MapNodeType.is_combat(get_effective_type())


func get_effective_type() -> MapNodeType.Type:
	if node_type == MapNodeType.Type.MYSTERY and resolved_type != MapNodeType.Type.MYSTERY:
		return resolved_type
	return node_type


func duplicate_runtime() -> MapNodeData:
	var copy := duplicate(true) as MapNodeData
	copy.visited = visited
	copy.available = available
	copy.completed = completed
	copy.resolved_type = resolved_type
	return copy
