extends Node

@onready var world_manager: Node = get_node("../WorldManager")

var noise_alt := FastNoiseLite.new()
var noise_moist := FastNoiseLite.new()
var noise_temp := FastNoiseLite.new()

func _ready():
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
	
			var world_height = world_manager.WORLD_HEIGHT_TILES
			# 1. Latitude Gradient (0.0 poles, 1.0 equator)
			var lat_factor = 1.0 - abs((float(wy) / world_height) * 2.0 - 1.0)
			
			# 2. Altitude Cooling (Lapse Rate)
			# As altitude increases from 0.0 to 1.0, temperature drops
			var alt_cooling = clamp(alt * 0.5, 0.0, 0.5) if alt > 0 else 0.0
			
			# 3. Final Temperature Calculation
			# We give latitude high weight (0.7) and noise lower weight (0.3) for distinct zones
			var temp_base = (lat_factor * 0.7) + (temp_raw * 0.5 + 0.5) * 0.3
			var temp_final = clamp(temp_base - alt_cooling, 0.0, 1.0)

			var t = WorldTile.new()
			t.altitude = alt
			t.moisture = moist_raw * 0.5 + 0.5
			t.temperature = temp_final
			t.classify_biome()

			row.append(t)
		chunk.append(row)
	return chunk

func get_tile(chunk: Array, x: int, y: int) -> WorldTile:
	if x >= 0 and x < chunk.size() and y >= 0 and y < chunk[0].size():
		return chunk[x][y]
	return null
