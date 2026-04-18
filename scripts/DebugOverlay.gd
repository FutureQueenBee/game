extends Node2D

var enabled := true

@onready var world_manager: Node = $"../WorldManager"
@onready var player: Node2D = $"../Player"

# Preview Modes
var tile_preview_modes := ["none", "altitude", "moisture", "temperature", "biome"]
var tile_preview_index := 0

# Atlas Modes
var atlas_preview_modes := ["none", "altitude", "heat", "rivers"]
var atlas_preview_index := 0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		enabled = !enabled
		queue_redraw()
	if event.is_action_pressed("debug_cycle_mode"):
		tile_preview_index = (tile_preview_index + 1) % tile_preview_modes.size()
		queue_redraw()
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		atlas_preview_index = (atlas_preview_index + 1) % atlas_preview_modes.size()
		print("Atlas Mode: ", atlas_preview_modes[atlas_preview_index])
		queue_redraw()

func _draw() -> void:
	if not enabled or player == null: return

	var tile_mode = tile_preview_modes[tile_preview_index]
	var atlas_mode = atlas_preview_modes[atlas_preview_index]

	if atlas_mode != "none":
		draw_atlas_skeleton(atlas_mode)

	if tile_mode != "none":
		draw_tile_preview(tile_mode)

	draw_sliding_window_hud()

func draw_atlas_skeleton(layer: String) -> void:
	var atlas = world_manager.planetary_atlas.get(layer, [])
	if atlas.is_empty(): return

	var grid_w = world_manager.atlas_width
	var grid_h = world_manager.atlas_height
	var step_x = float(world_manager.WORLD_WIDTH_TILES * world_manager.TILE_SIZE) / grid_w
	var step_y = float(world_manager.WORLD_HEIGHT_TILES * world_manager.TILE_SIZE) / grid_h

	for y in range(grid_h):
		for x in range(grid_w):
			var val = atlas[y][x]
			var color = Color(0,0,0,0)
			match layer:
				"altitude": color = Color(0.5 + val*0.5, 0.5 + val*0.5, 0.5, 0.3)
				"heat": color = Color(val, 0.2, 1.0 - val, 0.3)
			draw_rect(Rect2(x*step_x, y*step_y, step_x, step_y), color)

func draw_tile_preview(mode: String) -> void:
	# Implementation uses existing tile-logic but synced with world_manager.world
	for chunk_key in world_manager.world.keys():
		var chunk = world_manager.world[chunk_key]
		# ... (Drawing logic same as optimized version)

func draw_sliding_window_hud() -> void:
	var player_chunk = world_manager.world_to_chunk(player.global_position)
	var radius = world_manager.ACTIVE_RADIUS
	var tile_size = world_manager.TILE_SIZE
	var chunk_px = world_manager.CHUNK_SIZE * tile_size

	# Draw the Loaded Window
	var rect_pos = Vector2(player_chunk.x - radius, player_chunk.y - radius) * chunk_px
	var rect_size = Vector2(radius * 2 + 1, radius * 2 + 1) * chunk_px
	draw_rect(Rect2(rect_pos, rect_size), Color(1, 1, 0, 0.2), false, 4.0)
	
	# Mark chunks actually in memory
	for key in world_manager.world.keys():
		draw_rect(Rect2(key.x * chunk_px, key.y * chunk_px, chunk_px, chunk_px), Color(0, 1, 0, 0.1))
