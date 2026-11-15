class_name OathDefinition
extends Resource
## Phase D: one oath bond — keyword thresholds + effect values (resourceized).


enum EffectKind {
	DAMAGE_REDUCTION = 0, ## primary = fraction damage reduced (0.1 → take 90%)
	REVIVE_SHORTEN = 1, ## primary = fraction revive time shortened
	RANGED_COMBAT = 2, ## primary = damage bonus fraction; secondary = AS (interval shorten)
}

enum Scope {
	ARMY = 0,
	KEYWORD = 1,
}

@export var id: StringName = &""
@export var display_name: String = "誓约"
@export var keyword: StringName = &""
## Champion counts that unlock tier 1, tier 2, ... (e.g. 2/4).
@export var thresholds: PackedInt32Array = PackedInt32Array([2, 4])
@export var effect_kind: EffectKind = EffectKind.DAMAGE_REDUCTION
@export var scope: Scope = Scope.ARMY
## Per-tier primary values; index 0 = first lit tier.
@export var tier_primary: PackedFloat32Array = PackedFloat32Array([0.1, 0.2])
## Per-tier secondary (RANGED_COMBAT attack-interval shorten).
@export var tier_secondary: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])


func max_tier() -> int:
	return thresholds.size()


func tier_for_count(count: int) -> int:
	if count <= 0 or thresholds.is_empty():
		return 0
	var tier := 0
	for i in thresholds.size():
		if count >= thresholds[i]:
			tier = i + 1
		else:
			break
	return tier


func primary_for_tier(tier: int) -> float:
	if tier <= 0 or tier_primary.is_empty():
		return 0.0
	var idx := clampi(tier - 1, 0, tier_primary.size() - 1)
	return maxf(0.0, tier_primary[idx])


func secondary_for_tier(tier: int) -> float:
	if tier <= 0 or tier_secondary.is_empty():
		return 0.0
	var idx := clampi(tier - 1, 0, tier_secondary.size() - 1)
	return maxf(0.0, tier_secondary[idx])


func next_threshold(count: int) -> int:
	## Next unlock count, or last threshold if already max.
	if thresholds.is_empty():
		return 0
	for t in thresholds:
		if count < t:
			return t
	return thresholds[thresholds.size() - 1]
