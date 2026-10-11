class_name WaveSpawnController
extends RefCounted

var _grid: BoardGrid
var _rng: RandomNumberGenerator
var _entries: Array[SpawnScheduleEntry] = []
var _fixed_placements: Array = []
var _spawned: bool = false


func setup(
	grid: BoardGrid,
	wave: WaveData,
	wave_index: int,
	enemy_pool: Array[UnitData],
	rng: RandomNumberGenerator,
	pre_rolled_entries: Array[SpawnScheduleEntry] = [],
	fixed_placements: Array = [],
) -> void:
	_grid = grid
	_rng = rng
	_entries.clear()
	_fixed_placements = fixed_placements.duplicate(true) if not fixed_placements.is_empty() else []
	_spawned = false

	if not pre_rolled_entries.is_empty():
		_entries = pre_rolled_entries
	elif wave != null and rng != null:
		_entries = wave.roll_spawn_entries(enemy_pool, wave_index, rng)


func process_tick(combat_tick: int) -> void:
	if _spawned or combat_tick != 0:
		return
	_spawn_wave()


func spawn_wave_enemies() -> void:
	process_tick(0)


func is_spawned() -> bool:
	return _spawned


func has_pending_spawn() -> bool:
	if _spawned:
		return false
	return not _entries.is_empty() or not _fixed_placements.is_empty()


func _spawn_wave() -> void:
	_spawned = true
	if not _fixed_placements.is_empty():
		SpawnSystem.spawn_at_placements(_grid, _fixed_placements)
		return
	for entry in _entries:
		if entry != null:
			SpawnSystem.spawn_entry(_grid, entry, _rng)
