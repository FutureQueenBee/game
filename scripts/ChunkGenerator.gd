extends Node

@onready var world_manager: Node = get_node("../WorldManager")

var noise_alt := FastNoiseLite.new()
var noise_moist := FastNoiseLite.new()
var noise_temp := FastNoiseLite.new()

func _ready():
	noise_alt.seed = randi()
	noise_moist.seed = randi()
	noise_temp.seed = randi()
	
	noise_alt.frequency = 0.002
	noise_alt.fractal_octaves = 5
	noise_alt.fractal_lacunarity = 2.0
	noise_alt.fractal_gain = 0.5
	noise_moist.frequency = 0.004
	noise_temp.frequency = 0.01
	print("ChunkGenerator: High-fidelity streaming generator initialized.")

func generate_chunk(cx: int, cy: int) -> Array:
	var chunk_size = world_manager.CHUNK_SIZE
	var world_width_tiles = world_manager.WORLD_WIDTH_TILES
	var world_height = world_manager.WORLD_HEIGHT_TILES

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

			
			# Blend Macro (Skeleton) with Micro (Detail)
			var macro_alt = world_manager.get_macro_altitude(wx, wy)
			var micro_alt = noise_alt.get_noise_3d(sample_x, wy, sample_z)
			var alt = (macro_alt * 0.8) + (micro_alt * 0.4) # Preserve basin structure

			var moist_raw = noise_moist.get_noise_3d(sample_x, wy, sample_z)
			var temp_raw = noise_temp.get_noise_3d(sample_x, wy, sample_z)

			# Latitude Temperature Gradient
			
			# 1. Latitude factor (0 poles, 1 equator)
			# 1. Latitude factor
			var lat_factor = 1.0 - abs((float(wy) / world_height) * 2.0 - 1.0)
			
			# Polar Override: Force ice_ocean if at extreme latitudes and altitude < 0
			var is_polar = lat_factor < 0.15 # Extreme poles

			
			# 2. Temperature: 60% Latitude, 40% Noise
			var temp_final = clamp((lat_factor * 0.4) + ((temp_raw * 0.5 + 0.5) * 0.6), 0.0, 1.0)
			
			# 3. Moisture: Pure Noise (0-1 range)
			var moist_final = clamp(moist_raw * 0.5 + 0.5, 0.0, 1.0)
			
			var t = WorldTile.new()
			t.altitude = alt
			t.temperature = temp_final
			t.moisture = moist_final
			t.classify_biome()

			row.append(t)
		chunk.append(row)
	return chunk

func get_tile(chunk: Array, x: int, y: int) -> WorldTile:
	if x >= 0 and x < chunk.size() and y >= 0 and y < chunk[0].size():
		return chunk[x][y]
	return null
