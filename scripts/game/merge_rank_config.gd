class_name MergeRankConfig
extends Resource
## Phase C tunables: rank stat multipliers, revive timers, damage-share queue extend.


@export_group("Rank Multipliers")
## Applied to base max_hp / attack_damage at spawn. Index 0=新兵 1=老兵 2=冠军.
@export var rank_stat_multipliers: PackedFloat32Array = PackedFloat32Array([1.0, 1.35, 1.75])

@export_group("Revive")
@export var revive_base_sec: float = 8.0
## Extra seconds added to every queued remaining time when captain damage is shared.
@export var share_queue_extend_sec: float = 1.5
@export var revive_spawn_radius: float = 48.0


func multiplier_for_rank(rank: int) -> float:
	var idx := clampi(rank, 0, 2)
	if idx < rank_stat_multipliers.size():
		return maxf(0.05, rank_stat_multipliers[idx])
	match idx:
		1:
			return 1.35
		2:
			return 1.75
		_:
			return 1.0


func base_revive_time() -> float:
	return maxf(0.1, revive_base_sec)


func share_extend() -> float:
	return maxf(0.0, share_queue_extend_sec)
