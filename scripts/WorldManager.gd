extends Node

@export var CHUNK_SIZE: int = 32
@export var ACTIVE_RADIUS: int = 8

var world: Dictionary = {}
var visible_chunks: Array = []

@onready var generator: Node = $"../ChunkGenerator"
@onready var renderer: Node = $"../ChunkRenderer"

func update_sliding_window(center: Vector2i) -> void:
	var world_width = world_width_chunks()
	var new_visible_keys = []

	# 1. LOAD PASS
	for dx in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for dy in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			var wrapped_cx = posmod(center.x + dx, world_width)
			var clamped_cy = clamp(center.y + dy, 0, world_height_chunks() - 1)
			var key = Vector2i(wrapped_cx, clamped_cy)
			new_visible_keys.append(key)

			if not world.has(key):
				var tiles = generator.generate_chunk(wrapped_cx, clamped_cy)
				world[key] = {
					"tiles": tiles,
					"dirty": true,
					"neighbors_ready": false # Set true once 8-neighbors are loaded
				}

	# 2. NEIGHBOR SYNC PASS (Phase 2 Hydraulic requirement)
	for key in new_visible_keys:
		if not world[key].get("neighbors_ready", false):
			if _all_neighbors_loaded(key):
				world[key]["neighbors_ready"] = true
				# This is where we will trigger calculate_rivers(key)

	renderer.render_visible_chunks(world, center, world_width)

func _all_neighbors_loaded(center: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0: continue
			var n_key = Vector2i(posmod(center.x + dx, world_width_chunks()), clamp(center.y + dy, 0, world_height_chunks() - 1))
			if not world.has(n_key): return false
	return true

func world_width_chunks() -> int: return 4096 / CHUNK_SIZE
func world_height_chunks() -> int: return 2048 / CHUNK_SIZE

func calculate_hydraulic_flow(chunk_key: Vector2i) -> void:
	var chunk = world[chunk_key]
	var tiles = chunk["tiles"]
	var world_width = world_width_chunks()
	var chunk_size = CHUNK_SIZE

	for x in range(chunk_size):
		for y in range(chunk_size):
			var current_tile = tiles[x][y]
			var best_neighbor_dir = Vector2i.ZERO
			var max_drop = 0.0

			# Check 8 neighbors (D8 algorithm)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0: continue
					
					var target_tile = _get_tile_at_global_offset(chunk_key, x + dx, y + dy)
					if target_tile:
						var drop = current_tile.altitude - target_tile.altitude
						if drop > max_drop:
							max_drop = drop
							best_neighbor_dir = Vector2i(dx, dy)
			
			current_tile.flow_direction = best_neighbor_dir
	chunk["hydraulic_ready"] = true
	chunk["dirty"] = true

# Helper to resolve tile access across chunk boundaries with X-wrapping
func _get_tile_at_global_offset(origin_chunk: Vector2i, local_x: int, local_y: int) -> WorldTile:
	var world_width = world_width_chunks()
	var world_height = world_height_chunks()
	
	var tx = local_x
	var ty = local_y
	var cx = origin_chunk.x
	var cy = origin_chunk.y

	# Handle Local -> Neighbor Chunk transition
	if tx < 0:
		cx -= 1
		tx = CHUNK_SIZE - 1
	elif tx >= CHUNK_SIZE:
		cx += 1
		tx = 0
		
	if ty < 0:
		cy -= 1
		ty = CHUNK_SIZE - 1
	elif ty >= CHUNK_SIZE:
		cy += 1
		ty = 0

	var target_chunk_key = Vector2i(posmod(cx, world_width), clamp(cy, 0, world_height - 1))
	
	if world.has(target_chunk_key):
		return world[target_chunk_key]["tiles"][tx][ty]
	return null

func calculate_flow_accumulation(chunk_key: Vector2i) -> void:
	var chunk = world[chunk_key]
	var tiles = chunk["tiles"]
	var chunk_size = CHUNK_SIZE
	
	# 1. Initialize all land tiles with a base volume of 1.0 (unit of rainfall)
	for x in range(chunk_size):
		for y in range(chunk_size):
			var t = tiles[x][y]
			if t.altitude >= 0.0:
				t.flow_accumulation = 1.0
			else:
				t.flow_accumulation = 0.0

	# 2. Sort tiles by altitude (descending) to ensure we push water 'down' correctly
	var flat_tiles = []
	for x in range(chunk_size):
		for y in range(chunk_size):
			flat_tiles.append({"tile": tiles[x][y], "cx": chunk_key.x, "cy": chunk_key.y, "lx": x, "ly": y})
	
	flat_tiles.sort_custom(func(a, b): return a.tile.altitude > b.tile.altitude)

	# 3. Redistribute volume along D8 paths
	for item in flat_tiles:
		var t = item.tile
		if t.flow_direction != Vector2i.ZERO:
			var target = _get_tile_at_global_offset(chunk_key, item.lx + t.flow_direction.x, item.ly + t.flow_direction.y)
			if target:
				target.flow_accumulation += t.flow_accumulation

	chunk["accumulation_ready"] = true
	chunk["dirty"] = true


# --- PLANETARY ATLAS (GLOBAL SIMULATION) ---
var planetary_atlas: Dictionary = {
	"altitude": [],
	"heat": [],
	"moisture": [],
	"activity": [] # For traders/herds
}
var atlas_width: int = 128
var atlas_height: int = 64

func generate_planetary_atlas() -> void:
	print("WorldManager: Building Multi-Layer Atlas...")
	for key in planetary_atlas.keys():
		planetary_atlas[key].clear()
	
	# Generate Layers
	for y in range(atlas_height):
		var row_alt = []
		var row_temp = []
		for x in range(atlas_width):
			var wx = x * (float(WORLD_WIDTH_TILES) / atlas_width)
			var wy = y * (float(WORLD_HEIGHT_TILES) / atlas_height)
			var angle = (float(wx) / WORLD_WIDTH_TILES) * TAU
			
			# Altitude Skeleton
			var a = generator.noise_alt.get_noise_3d(cos(angle)*300, wy, sin(angle)*300)
			row_alt.append(a)
			
			# Temperature Skeleton (Latitude + Macro Noise)
			var lat_f = 1.0 - abs((float(wy) / WORLD_HEIGHT_TILES) * 2.0 - 1.0)
			row_temp.append(lat_f)
		
		planetary_atlas["altitude"].append(row_alt)
		planetary_atlas["heat"].append(row_temp)
	print("WorldManager: Atlas Ready for Global Simulation.")

func get_atlas_value(layer: String, world_x: float, world_y: float) -> float:
	if not planetary_atlas.has(layer): return 0.0
	var gx = int(posmod(world_x / (float(WORLD_WIDTH_TILES) / atlas_width), atlas_width))
	var gy = int(clamp(world_y / (float(WORLD_HEIGHT_TILES) / atlas_height), 0, atlas_height - 1))
	return planetary_atlas[layer][gy][gx]

