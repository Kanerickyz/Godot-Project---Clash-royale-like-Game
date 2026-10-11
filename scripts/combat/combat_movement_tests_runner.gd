extends SceneTree

const MoveTest := preload("res://scripts/combat/effect_resolver_move_test.gd")
const GridTest := preload("res://scripts/combat/grid_movement_test.gd")
const LineTest := preload("res://scripts/combat/grid_line_test.gd")
const SpawnTest := preload("res://scripts/combat/combat_start_spawn_test.gd")
const AssassinTest := preload("res://scripts/combat/effect_resolver_assassin_test.gd")
const CritTest := preload("res://scripts/combat/damage_pipeline_crit_test.gd")
const BatchTest := preload("res://scripts/combat/effect_resolver_batch_test.gd")
const GunnerTest := preload("res://scripts/combat/effect_resolver_gunner_test.gd")
const AttackRangeTest := preload("res://scripts/combat/attack_range_preview_test.gd")
const SplitTest := preload("res://scripts/combat/effect_resolver_split_test.gd")


func _initialize() -> void:
	var move_ok: bool = MoveTest.run_all()
	var grid_ok: bool = GridTest.run_all()
	var line_ok: bool = LineTest.run_all()
	var spawn_ok: bool = SpawnTest.run_all()
	var assassin_ok: bool = AssassinTest.run_all()
	var crit_ok: bool = CritTest.run_all()
	var batch_ok: bool = BatchTest.run_all()
	var gunner_ok: bool = GunnerTest.run_all()
	var attack_range_ok: bool = AttackRangeTest.run_all()
	var split_ok: bool = SplitTest.run_all()
	quit(
		0
		if (
			move_ok
			and grid_ok
			and line_ok
			and spawn_ok
			and assassin_ok
			and crit_ok
			and batch_ok
			and gunner_ok
			and attack_range_ok
			and split_ok
		)
		else 1
	)
