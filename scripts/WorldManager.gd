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

# --- GLOBAL MACRO DATA (PHASE 2) ---
var macro_altitude_map: Array = [] # 2D Array of floats
var macro_grid_width: int = 128
var macro_grid_height: int = 64

func generate_global_pre_pass() -> void:
	print("WorldManager: Generating Global Macro Pass...")
	macro_altitude_map.clear()
	
	var radius = WORLD_WIDTH_TILES / TAU
	var x_step = float(WORLD_WIDTH_TILES) / macro_grid_width
	var y_step = float(WORLD_HEIGHT_TILES) / macro_grid_height

	for y in range(macro_grid_height):
		var row = []
		for x in range(macro_grid_width):
			var wx = x * x_step
			var wy = y * y_step
			var angle = (float(wx) / WORLD_WIDTH_TILES) * TAU
			
			# Sample at very low frequency to get core basins
			var alt = generator.noise_alt.get_noise_3d(cos(angle) * radius * 0.001, wy * 0.001, sin(angle) * radius * 0.001)
			row.append(alt)
		macro_altitude_map.append(row)
	print("WorldManager: Macro Pass Complete.")

func get_macro_altitude(world_x: float, world_y: float) -> float:
	var gx = int(posmod(world_x / (float(WORLD_WIDTH_TILES) / macro_grid_width), macro_grid_width))
	var gy = int(clamp(world_y / (float(WORLD_HEIGHT_TILES) / macro_grid_height), 0, macro_grid_height - 1))
	return macro_altitude_map[gy][gx]
