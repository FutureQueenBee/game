extends Node

@export var CHUNK_SIZE: int = 32
@export var TILE_SIZE: int = 16
@export var ACTIVE_RADIUS: int = 8
@export var WORLD_WIDTH_TILES: int = 4096
@export var WORLD_HEIGHT_TILES: int = 2048

var world: Dictionary = {}
var visible_chunks: Array = []
var _original_radius: int = ACTIVE_RADIUS

var world_time_days: float = 0.0
var time_scale: float = 1.0
var real_seconds_per_day: float = 1200.0

@onready var generator: Node = $"../ChunkGenerator"
@onready var renderer: Node = $"../ChunkRenderer"
@onready var player: Node2D = $"../Player"

func _ready() -> void:
	print("WorldManager: Optimized Sliding Window initialized")
	if player:
		player.position_changed.connect(_on_player_position_changed)

func world_to_chunk(pos: Vector2) -> Vector2i:
	var chunk_world_size = CHUNK_SIZE * TILE_SIZE
	return Vector2i(
		posmod(floor(pos.x / chunk_world_size), world_width_chunks()),
		clamp(floor(pos.y / chunk_world_size), 0, world_height_chunks() - 1)
	)

func world_width_chunks() -> int: return WORLD_WIDTH_TILES / CHUNK_SIZE
func world_height_chunks() -> int: return WORLD_HEIGHT_TILES / CHUNK_SIZE

func _on_player_position_changed(new_pos: Vector2) -> void:
	var center = world_to_chunk(new_pos)
	update_sliding_window(center)

func update_sliding_window(center: Vector2i) -> void:
	var world_width = world_width_chunks()
	var new_visible_keys = []

	# 1. Identify visibility
	for dx in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
		for dy in range(-ACTIVE_RADIUS, ACTIVE_RADIUS + 1):
			var wrapped_cx = posmod(center.x + dx, world_width)
			var clamped_cy = clamp(center.y + dy, 0, world_height_chunks() - 1)
			var key = Vector2i(wrapped_cx, clamped_cy)
			new_visible_keys.append(key)

			if not world.has(key):
				# Load data
				var tiles = generator.generate_chunk(wrapped_cx, clamped_cy)
				world[key] = {
					"tiles": tiles,
					"dirty": true,
					"sim_state": {"last_update_time": world_time_days}
				}

	# 2. SAFE UNLOAD: Clear visuals BEFORE erasing data to prevent memory leaks
	var to_remove = []
	for key in world.keys():
		if key not in new_visible_keys:
			to_remove.append(key)

	for key in to_remove:
		# Explicitly clear TileMap cells at this chunk's position
		# Note: This requires renderer to have a clear_chunk method
		if renderer.has_method("clear_chunk"):
			renderer.clear_chunk(key, center, world_width)
		world.erase(key)

	visible_chunks = new_visible_keys
	renderer.render_visible_chunks(world, center, world_width)

func toggle_mass_exploration(enabled: bool) -> void:
	if enabled:
		_original_radius = ACTIVE_RADIUS
		ACTIVE_RADIUS = 24
	else:
		ACTIVE_RADIUS = _original_radius
	if player: _on_player_position_changed(player.global_position)

func _process(delta: float) -> void:
	world_time_days += (delta * time_scale) / real_seconds_per_day
	simulate_chunks(delta)

func simulate_chunks(_dt: float) -> void:
	for key in world.keys():
		world[key]["sim_state"]["last_update_time"] = world_time_days
