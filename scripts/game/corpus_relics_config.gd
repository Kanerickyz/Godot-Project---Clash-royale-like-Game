class_name CorpusRelicsConfig
extends Resource
## Phase E tunables: corpus wallet, drop pools, relic shop, floor loot density.


@export_group("Wallet")
@export var starting_corpus: int = 0

@export_group("Kill Drop Pool")
## Separate pool from ducats: grunt kill corpus range.
@export var kill_corpus_min: int = 1
@export var kill_corpus_max: int = 2

@export_group("Chest Drop Pool")
@export var chest_corpus_min: int = 2
@export var chest_corpus_max: int = 4
## Chance [0..1] that a smashed chest also drops corpus (ducats always).
@export var chest_corpus_chance: float = 0.85

@export_group("Elite")
@export var start_elite_count: int = 1
@export var elite_corpus_min: int = 4
@export var elite_corpus_max: int = 7
## Multiplier on elite ducat drop vs scaled grunt roll.
@export var elite_ducat_multiplier: float = 2.0
@export var elite_hp_multiplier: float = 2.2
@export var elite_damage_multiplier: float = 1.4

@export_group("Shrine")
@export var start_shrine_count: int = 1
@export var shrine_interact_radius: float = 90.0
@export var shrine_corpus_reward: int = 3
@export var shrine_buff_duration_sec: float = 12.0
## Temporary army attack damage bonus while shrine buff is active.
@export var shrine_attack_bonus: float = 0.25

@export_group("Relic Shop")
@export var max_relic_slots: int = 3
@export var relic_shelf_slot_count: int = 3
@export var relic_refresh_cost: int = 2
@export var relic_pool_paths: PackedStringArray = PackedStringArray([
	"res://resources/relics/relic_bone_hourglass.tres",
	"res://resources/relics/relic_iron_shard.tres",
	"res://resources/relics/relic_greed_tooth.tres",
])


func roll_kill_corpus(rng: RandomNumberGenerator, is_elite: bool = false) -> int:
	var lo := elite_corpus_min if is_elite else kill_corpus_min
	var hi := elite_corpus_max if is_elite else kill_corpus_max
	lo = mini(lo, hi)
	hi = maxi(lo, hi)
	if hi <= 0:
		return 0
	if rng != null:
		return rng.randi_range(lo, hi)
	return lo


func roll_chest_corpus(rng: RandomNumberGenerator) -> int:
	var chance := clampf(chest_corpus_chance, 0.0, 1.0)
	var roll := rng.randf() if rng != null else 0.0
	if roll > chance:
		return 0
	var lo := mini(chest_corpus_min, chest_corpus_max)
	var hi := maxi(chest_corpus_min, chest_corpus_max)
	if hi <= 0:
		return 0
	if rng != null:
		return rng.randi_range(lo, hi)
	return lo
