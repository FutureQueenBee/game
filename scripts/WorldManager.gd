extends Node

@export var CHUNK_SIZE: int = 32
@export var TILE_SIZE: int = 16
@export var ACTIVE_RADIUS: int = 8
@export var WORLD_WIDTH_TILES: int = 4096
@export var WORLD_HEIGHT_TILES: int = 2048

# --- PLANETARY ATLAS (GLOBAL SIMULATION) ---
var planetary_atlas: Dictionary = {
	"altitude": [],
	"heat": [],
	"rivers": []
}
var atlas_width: int = 128
var atlas_height: int = 64

var world: Dictionary = {}
var visible_chunks: Array = []

var world_time_days: float = 0.0
var time_scale: float = 1.0
var real_seconds_per_day: float = 1200.0

@onready var generator: Node = $"../ChunkGenerator"
@onready var renderer: Node = $"../ChunkRenderer"
@onready var player: Node2D = $"../Player"

func _ready() -> void:
	print("WorldManager: Initializing Atlas architecture...")
	generate_planetary_atlas()
	if player:
		player.position_changed.connect(_on_player_position_changed)

func generate_planetary_atlas() -> void:
	# Initialize all channels to avoid null access errors
	for layer in planetary_atlas.keys():
		planetary_atlas[layer] = []
		for y in range(atlas_height):
			var row = []
			row.resize(atlas_width)
			row.fill(0.0)
			planetary_atlas[layer].append(row)

	var radius = float(WORLD_WIDTH_TILES) / TAU

	# 1. Primary Simulation Pass
	for y in range(atlas_height):
		for x in range(atlas_width):
			var wx = x * (float(WORLD_WIDTH_TILES) / atlas_width)
			var wy = y * (float(WORLD_HEIGHT_TILES) / atlas_height)
			var angle = (float(wx) / WORLD_WIDTH_TILES) * TAU

			# Altitude Macro-Basins
			var a = generator.noise_alt.get_noise_3d(cos(angle)*300, wy, sin(angle)*300)
			planetary_atlas["altitude"][y][x] = a

			# Latitude Heat Gradient
			var lat_f = 1.0 - abs((float(wy) / WORLD_HEIGHT_TILES) * 2.0 - 1.0)
			planetary_atlas["heat"][y][x] = lat_f

	print("WorldManager: Atlas Generation Complete.")

func get_atlas_value(layer: String, world_x: float, world_y: float) -> float:
	if not planetary_atlas.has(layer): return 0.0
	var gx = int(posmod(world_x / (float(WORLD_WIDTH_TILES) / atlas_width), atlas_width))
	var gy = int(clamp(world_y / (float(WORLD_HEIGHT_TILES) / atlas_height), 0, atlas_height - 1))
	return planetary_atlas[layer][gy][gx]

func world_width_chunks() -> int: return WORLD_WIDTH_TILES / CHUNK_SIZE
func world_height_chunks() -> int: return WORLD_HEIGHT_TILES / CHUNK_SIZE

func _on_player_position_changed(new_pos: Vector2) -> void:
	var chunk_world_size = CHUNK_SIZE * TILE_SIZE
	var center = Vector2i(
		posmod(floor(new_pos.x / chunk_world_size), world_width_chunks()),
		clamp(floor(new_pos.y / chunk_world_size), 0, world_height_chunks() - 1)
	)
	update_sliding_window(center)

func update_sliding_window(center: Vector2i) -> void:
	var world_width = world_width_chunks()
	var new_visible_keys = []

	for dx in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for dy in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			var wrapped_cx = posmod(center.x + dx, world_width)
			var clamped_cy = clamp(center.y + dy, 0, world_height_chunks() - 1)
			var key = Vector2i(wrapped_cx, clamped_cy)
			new_visible_keys.append(key)

			if not world.has(key):
				world[key] = {
					"tiles": generator.generate_chunk(wrapped_cx, clamped_cy),
					"dirty": true,
					"sim_state": {"last_update_time": world_time_days}
				}

	var to_remove = []
	for key in world.keys():
		if key not in new_visible_keys:
			to_remove.append(key)
	for key in to_remove: world.erase(key)

	visible_chunks = new_visible_keys
	renderer.render_visible_chunks(world, center, world_width)

func _process(delta: float) -> void:
	world_time_days += (delta * time_scale) / real_seconds_per_day
	simulate_chunks(delta)

func simulate_chunks(_dt: float) -> void:
	for key in world.keys():
		world[key]["sim_state"]["last_update_time"] = world_time_days

func world_to_chunk(pos: Vector2) -> Vector2i:
	var chunk_world_size = CHUNK_SIZE * TILE_SIZE
	return Vector2i(
		posmod(floor(pos.x / chunk_world_size), world_width_chunks()),
		clamp(floor(pos.y / chunk_world_size), 0, world_height_chunks() - 1)
	)
