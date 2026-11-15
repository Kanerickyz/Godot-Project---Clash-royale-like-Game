class_name PhaseFRunVictoryTest
extends RefCounted
## Phase F pure logic: floor length, final index, dungeon type cycling.


static func test_floor_run_config_helpers() -> bool:
	var cfg := FloorRunConfig.new()
	cfg.total_floors = 3
	cfg.dungeon_type_ids = PackedStringArray(["crypt", "aqueduct"])
	cfg.dungeon_type_labels = PackedStringArray(["地下墓穴", "水道"])
	if cfg.resolved_total_floors() != 3:
		push_error("PhaseF: resolved_total_floors expected 3")
		return false
	if cfg.is_final_floor_index(1) or cfg.is_final_floor_index(2):
		push_error("PhaseF: floors 1–2 should not be final")
		return false
	if not cfg.is_final_floor_index(3):
		push_error("PhaseF: floor 3 should be final")
		return false
	if cfg.dungeon_type_id_for_floor(1) != "crypt":
		push_error("PhaseF: floor 1 type expected crypt")
		return false
	if cfg.dungeon_type_id_for_floor(2) != "aqueduct":
		push_error("PhaseF: floor 2 type expected aqueduct")
		return false
	if cfg.dungeon_type_id_for_floor(3) != "crypt":
		push_error("PhaseF: floor 3 type cycles to crypt")
		return false
	if cfg.dungeon_type_label_for_floor(2) != "水道":
		push_error("PhaseF: floor 2 label expected 水道")
		return false
	print("PHASE_F_CONFIG_OK total=3 types=crypt/aqueduct")
	return true


static func test_tileset_palettes_differ() -> bool:
	var a := DungeonTilesetFactory.build_tileset("crypt")
	var b := DungeonTilesetFactory.build_tileset("aqueduct")
	if a == null or b == null:
		push_error("PhaseF: tileset build failed")
		return false
	var src_a := a.get_source(DungeonTilesetFactory.SOURCE_ID) as TileSetAtlasSource
	var src_b := b.get_source(DungeonTilesetFactory.SOURCE_ID) as TileSetAtlasSource
	if src_a == null or src_b == null or src_a.texture == null or src_b.texture == null:
		push_error("PhaseF: tileset atlas missing")
		return false
	var img_a: Image = src_a.texture.get_image()
	var img_b: Image = src_b.texture.get_image()
	if img_a == null or img_b == null:
		push_error("PhaseF: tileset image missing")
		return false
	# Sample a floor pixel; palettes must differ.
	var ca := img_a.get_pixel(DungeonTilesetFactory.TILE_SIZE * 2 + 8, 8)
	var cb := img_b.get_pixel(DungeonTilesetFactory.TILE_SIZE * 2 + 8, 8)
	if ca.is_equal_approx(cb):
		push_error("PhaseF: crypt/aqueduct floor colors should differ")
		return false
	print("PHASE_F_PALETTE_OK crypt=", ca, " aqueduct=", cb)
	return true
