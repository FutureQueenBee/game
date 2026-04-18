extends Node2D

var enabled := true

@onready var world_manager: Node = $"../WorldManager"
@onready var player: Node2D = $"../Player"
@onready var camera: Camera2D = $"../Player/Camera2D"

var tile_preview_modes := ["none", "altitude", "moisture", "temperature", "biome"]
var tile_preview_index := 0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_CAPSLOCK:
		var is_mass_loading = (world_manager.ACTIVE_RADIUS > 10)
		world_manager.toggle_mass_exploration(!is_mass_loading)
		print("Mass Exploration Mode: ", !is_mass_loading)

	if event.is_action_pressed("debug_toggle"):
		enabled = !enabled
		queue_redraw()
	if event.is_action_pressed("debug_cycle_mode"):
		tile_preview_index = (tile_preview_index + 1) % tile_preview_modes.size()
		queue_redraw()

func _physics_process(_delta: float) -> void:
	if enabled: queue_redraw()

func get_tile_preview_mode() -> String:
	return tile_preview_modes[tile_preview_index]

func get_chunk_preview_mode() -> String:
	return "none"

func _draw() -> void:
	if not enabled or player == null: return

	var mode = get_tile_preview_mode()
	if mode != "none":
		draw_tile_preview(mode)

	draw_chunk_borders()

func draw_tile_preview(mode: String) -> void:
	var chunk_size = world_manager.CHUNK_SIZE
	var tile_size = world_manager.TILE_SIZE
	var chunk_world_size = chunk_size * tile_size

	for chunk_coord in world_manager.world.keys():
		var chunk = world_manager.world[chunk_coord]
		var tiles = chunk["tiles"]

		var player_chunk = world_manager.world_to_chunk(player.global_position)
		var dx = chunk_coord.x - player_chunk.x
		var world_width_chunks = world_manager.WORLD_WIDTH_TILES / chunk_size
		dx = posmod(dx + int(world_width_chunks / 2), world_width_chunks) - int(world_width_chunks / 2)

		var base_x = (player_chunk.x + dx) * chunk_world_size
		var base_y = int(chunk_coord.y) * chunk_world_size

		for x in range(chunk_size):
			for y in range(chunk_size):
				var t = tiles[x][y]
				var color = Color(0,0,0,0)

				match mode:
					"altitude":
						if t.altitude < 0: color = Color(0, 0, 0.5 + clamp(t.altitude, -0.5, 0.0), 0.5)
						else: color = Color(0, clamp(t.altitude, 0.0, 1.0), 0, 0.5)
					"moisture":
						color = Color(0.2, 0.2, 1.0, clamp(t.moisture, 0.0, 1.0) * 0.8)
					"temperature":
						color = Color(clamp(t.temperature, 0.0, 1.0), 0.2, 1.0 - clamp(t.temperature, 0.0, 1.0), 0.6)
					"biome":
						color = biome_color(t.biome)

				draw_rect(Rect2(Vector2(base_x + x*tile_size, base_y + y*tile_size), Vector2(tile_size, tile_size)), color)

func biome_color(b_name: String) -> Color:
	match b_name:
		"ocean_deep": return Color(0.0, 0.05, 0.3, 0.75)
		"ocean_mid": return Color(0.0, 0.15, 0.5, 0.75)
		"ocean_shelf": return Color(0.1, 0.3, 0.7, 0.75)
		"coast": return Color(0.7, 0.7, 0.3, 0.75)
		"lowland": return Color(0.3, 0.6, 0.2, 0.75)
		"grassland": return Color(0.4, 0.8, 0.2, 0.75)
		"forest": return Color(0.0, 0.4, 0.0, 0.75)
		"highland": return Color(0.4, 0.4, 0.2, 0.75)
		"mountain": return Color(0.5, 0.5, 0.5, 0.75)
		"peak": return Color(0.85, 0.85, 0.85, 0.85)
		"desert": return Color(0.9, 0.8, 0.2, 0.75)
		"tundra": return Color(0.5, 0.6, 0.7, 0.75)
		"snow": return Color(1.0, 1.0, 1.0, 0.85)
		"river": return Color(0.2, 0.4, 1.0, 0.8)
		"lake": return Color(0.1, 0.2, 0.9, 0.8)
		_: return Color(1, 0, 1, 0.5)

func draw_chunk_borders() -> void:
	var chunk_world_size = world_manager.CHUNK_SIZE * world_manager.TILE_SIZE
	for chunk_coord in world_manager.world.keys():
		var player_chunk = world_manager.world_to_chunk(player.global_position)
		var dx = chunk_coord.x - player_chunk.x
		var world_width_chunks = world_manager.WORLD_WIDTH_TILES / world_manager.CHUNK_SIZE
		dx = posmod(dx + int(world_width_chunks / 2), world_width_chunks) - int(world_width_chunks / 2)
		var world_pos = Vector2((player_chunk.x + dx) * chunk_world_size, chunk_coord.y * chunk_world_size)
		draw_rect(Rect2(world_pos, Vector2(chunk_world_size, chunk_world_size)), Color(0,0,0,1), false, 2)
