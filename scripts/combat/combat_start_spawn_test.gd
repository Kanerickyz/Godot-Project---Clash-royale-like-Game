class_name CombatStartSpawnTest
extends RefCounted

const ENEMY_UNIT := preload("res://resources/units/fish.tres")
const MOSQUITO_UNIT := preload("res://resources/units/mosquito.tres")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_spawn_before_combat_start()
	_test_pending_spawn_guard()
	if _failures == 0:
		print("CombatStartSpawnTest: all tests passed")
	else:
		push_error("CombatStartSpawnTest: %d failure(s)" % _failures)
	return _failures == 0


static func _grid() -> BoardGrid:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(6, 6))
	return grid


static func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	return rng


static func _enemy_entry() -> SpawnScheduleEntry:
	var entry := SpawnScheduleEntry.new()
	entry.unit = ENEMY_UNIT
	entry.count = 1
	return entry


static func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("CombatStartSpawnTest FAIL: %s" % message)


static func _test_spawn_before_combat_start() -> void:
	var grid := _grid()
	var rng := _rng()
	var spawn := WaveSpawnController.new()
	spawn.setup(grid, null, 0, [], rng, [_enemy_entry()], [])

	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline, rng)
	bus.combat_event.connect(resolver.on_event)

	var player := UnitInstance.from_unit_data(MOSQUITO_UNIT, Vector2i(1, 1), UnitInstance.Team.PLAYER)
	grid.place(player, Vector2i(1, 1))

	spawn.spawn_wave_enemies()
	_assert_true(
		not grid.get_units_by_team(UnitInstance.Team.ENEMY, true).is_empty(),
		"enemies exist on grid before combat-start skills resolve",
	)

	bus.emit_event(CombatEvents.ON_COMBAT_START, CombatEventPayload.new())
	while resolver.has_pending_steps():
		resolver.process_next_step()

	_assert_true(
		not grid.get_units_by_team(UnitInstance.Team.ENEMY, true).is_empty(),
		"enemies remain after combat-start skill resolution",
	)


static func _test_pending_spawn_guard() -> void:
	var grid := _grid()
	var rng := _rng()
	var spawn := WaveSpawnController.new()
	spawn.setup(grid, null, 0, [], rng, [_enemy_entry()], [])

	_assert_true(spawn.has_pending_spawn(), "wave spawn pending before tick 0")
	_assert_true(not spawn.is_spawned(), "wave not spawned yet")

	spawn.spawn_wave_enemies()
	_assert_true(spawn.is_spawned(), "wave marked spawned")
	_assert_true(not spawn.has_pending_spawn(), "no pending spawn after wave spawned")
