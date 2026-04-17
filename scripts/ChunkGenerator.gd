extends Node

@onready var world_manager: Node = get_node("../WorldManager")

# Note: Assuming noise variables are declared similarly to original script
var noise_alt := FastNoiseLite.new()
var noise_moist := FastNoiseLite.new()
var noise_temp := FastNoiseLite.new()

func _ready():
	# Initialize noise with random seeds for variety
	noise_alt.seed = randi()
	noise_moist.seed = randi()
	noise_temp.seed = randi()
	
	noise_alt.frequency = 0.005
	noise_moist.frequency = 0.01
	noise_temp.frequency = 0.01
	
	print("ChunkGenerator: High-fidelity streaming generator initialized.")

func generate_chunk(cx: int, cy: int) -> Array:
	var chunk_size = world_manager.CHUNK_SIZE
	var world_width_tiles = world_manager.WORLD_WIDTH_TILES
	
	var chunk = []
	for x in range(chunk_size):
		var row = []
		for y in range(chunk_size):
			var wx = cx * chunk_size + x
			var wy = cy * chunk_size + y
			
			# 3D Cylindrical wrapping math
			var angle = (float(wx) / world_width_tiles) * TAU
			var radius = world_width_tiles / TAU
			
			var sample_x = cos(angle) * radius
			var sample_z = sin(angle) * radius
			
						var world_height = world_manager.WORLD_HEIGHT_TILES
			# Normalize Y to 0.0 (poles) -> 1.0 (equator) -> 0.0 (poles)
			var lat_factor = 1.0 - abs((float(wy) / world_height) * 2.0 - 1.0)
			
			# Combine Noise with Latitude (0.0 to 1.0 range)
			var temp_final = clamp((temp_raw * 0.5 + 0.5) * 0.4 + (lat_factor * 0.6), 0.0, 1.0)

			var t = WorldTile.new()
			t.altitude = alt
			t.moisture = moist_raw * 0.5 + 0.5 # Normalize to 0-1
			t.temperature = temp_final
			t.classify_biome()
			
			row.append(t)
		chunk.append(row)
	
	return chunk

func get_tile(chunk: Array, x: int, y: int) -> WorldTile:
	if x >= 0 and x < chunk.size() and y >= 0 and y < chunk[0].size():
		return chunk[x][y]
	return null
