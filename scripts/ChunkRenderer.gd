extends TileMap

const CHUNK_SIZE: int = 32
const DEBUG_LOG_PATH := "res://debug-cd6f1c.log"
@onready var world_manager: Node = get_node("../WorldManager")

func _debug_log(hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null: f = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE_READ)
	if f == null: return
	f.seek_end()
	var payload := {
		"sessionId": "cd6f1c",
		"runId": "post-fix",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()

func _chunk_size() -> int:
	if world_manager != null and world_manager.has_method("world_width_chunks"):
		return int(world_manager.CHUNK_SIZE)
	return CHUNK_SIZE

func render_visible_chunks(world: Dictionary, center: Vector2i, world_width_chunks: int) -> void:
	for key in world.keys():
		var chunk: Dictionary = world[key]

		if chunk.get("dirty", false):
			var tiles: Array = chunk["tiles"]
			draw_chunk(key, center, world_width_chunks, tiles)
			chunk["dirty"] = false

func draw_chunk(chunk_coord: Vector2i, center: Vector2i, world_width_chunks: int, tiles: Array) -> void:
	var chunk_size: int = _chunk_size()
	# Determine if chunk should be drawn to the left or right of player based on proximity
	var dx = chunk_coord.x - center.x
	if world_width_chunks > 0:
		dx = posmod(dx + world_width_chunks / 2, world_width_chunks) - (world_width_chunks / 2)
	var draw_x = center.x + dx
	var base_x: int = draw_x * chunk_size
	var base_y: int = chunk_coord.y * chunk_size

	for x: int in range(chunk_size):
		for y: int in range(chunk_size):
			var t = tiles[x][y]
			# Layer 0, Grid Pos, Source ID 0, Atlas Coords
			set_cell(0, Vector2i(base_x + x, base_y + y), 0, Vector2i(t.tile_id, 0)), 0, Vector2i(t.tile_id, 0))
