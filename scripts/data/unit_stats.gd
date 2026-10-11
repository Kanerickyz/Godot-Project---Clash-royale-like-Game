class_name UnitStats
extends Resource

enum MovementPattern {
	ORTHOGONAL,
	LINE,
	ROOK,
	KNIGHT,
	DIAGONAL,
	BISHOP,
	QUEEN,
	TELEPORT,
}

@export var max_hp: int = 10
@export var attack: int = 3
@export var attack_range: int = 1
@export var movement_pattern: MovementPattern = MovementPattern.ORTHOGONAL
@export_range(1, 8, 1) var steps_per_turn: int = 1
@export_range(0, 100, 1) var crit_rate_percent: int = 5


func duplicate_stats() -> UnitStats:
	var copy := UnitStats.new()
	copy.max_hp = max_hp
	copy.attack = attack
	copy.attack_range = attack_range
	copy.movement_pattern = movement_pattern
	copy.steps_per_turn = steps_per_turn
	copy.crit_rate_percent = crit_rate_percent
	return copy
