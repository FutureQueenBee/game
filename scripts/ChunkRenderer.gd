extends TileMap

const CHUNK_SIZE: int = 32
@onready var world_manager: Node = get_node("../WorldManager")

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
	var dx: int = chunk_coord.x - center.x
	if world_width_chunks > 0:
		dx = posmod(dx + int(world_width_chunks / 2), world_width_chunks) - int(world_width_chunks / 2)

	var draw_x: int = int(center.x) + dx
	var base_x: int = draw_x * chunk_size
	var base_y: int = int(chunk_coord.y) * chunk_size

	if world_width_chunks > 0:
		base_x = posmod(base_x, world_width_chunks * chunk_size)

	for x: int in range(chunk_size):
		for y: int in range(chunk_size):
			var t = tiles[x][y]
			set_cell(0, Vector2i(base_x + x, base_y + y), 0, Vector2i(int(t.tile_id), 0))

# NEW: Explicitly clear cells for unloaded chunks to free memory
func clear_chunk(chunk_coord: Vector2i, center: Vector2i, world_width_chunks: int) -> void:
	var chunk_size: int = _chunk_size()
	var dx: int = chunk_coord.x - center.x
	if world_width_chunks > 0:
		dx = posmod(dx + int(world_width_chunks / 2), world_width_chunks) - int(world_width_chunks / 2)

	var draw_x: int = int(center.x) + dx
	var base_x: int = draw_x * chunk_size
	var base_y: int = int(chunk_coord.y) * chunk_size

	if world_width_chunks > 0:
		base_x = posmod(base_x, world_width_chunks * chunk_size)

	for x: int in range(chunk_size):
		for y: int in range(chunk_size):
			# Set to -1 to remove the tile and its data from the TileMap
			set_cell(0, Vector2i(base_x + x, base_y + y), -1)
