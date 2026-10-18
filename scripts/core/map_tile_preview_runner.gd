extends SceneTree
## Headless smoke: generate tiled map visuals once.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var cfg := load("res://resources/world/world_spawn.tres") as WorldSpawnConfig
	if cfg == null:
		push_error("missing world_spawn.tres")
		quit(1)
		return
	var gen := RoguelikeMapGenerator.new()
	gen.generate(cfg, rng)
	var host := Node2D.new()
	host.name = "PreviewHost"
	root.add_child(host)
	gen.build_visuals(host, rng)
	var ground := host.get_node_or_null("GroundTiles") as TileMapLayer
	if ground == null:
		push_error("GroundTiles missing")
		quit(1)
		return
	var used := ground.get_used_cells().size()
	print("MAP_TILE_PREVIEW_OK cells=", used, " rooms=", gen.rooms.size())
	if used < 10:
		push_error("too few ground cells")
		quit(1)
		return
	quit(0)
