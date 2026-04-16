extends Node2D

var enabled := true

@onready var world_manager: Node = $"../WorldManager"
@onready var player: Node2D = $"../Player"
@onready var camera: Camera2D = $"../Player/Camera2D"

# ---------------------------------------------------------
# TILE-LEVEL PREVIEW MODES
# ---------------------------------------------------------
var tile_preview_modes := [
	"none",
	"altitude",
	"moisture",
	"temperature",
	"temperature_final",
    "biome"
]
var tile_preview_index := 0

# ---------------------------------------------------------
# CHUNK-LEVEL PREVIEW MODES
# ---------------------------------------------------------
var chunk_preview_modes := [
	"none",
	"altitude",
	"moisture",
	"temperature",
	"temperature_final",
	"biome",
	"roughness",
    "chunk_info"
]
var chunk_preview_index := 0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		enabled = !enabled
		queue_redraw()

	if event.is_action_pressed("debug_cycle_mode"):
		tile_preview_index = (tile_preview_index + 1) % tile_preview_modes.size()
		print("Tile Preview Mode:", tile_preview_modes[tile_preview_index])
		queue_redraw()

	if event.is_action_pressed("debug_cycle_chunk_mode"):
		chunk_preview_index = (chunk_preview_index + 1) % chunk_preview_modes.size()
		print("Chunk Preview Mode:", chunk_preview_modes[chunk_preview_index])
		queue_redraw()


func _physics_process(delta: float) -> void:
	if enabled:
		queue_redraw()


func get_tile_preview_mode() -> String:
	return tile_preview_modes[tile_preview_index]

func get_chunk_preview_mode() -> String:
	return chunk_preview_modes[chunk_preview_index]


func _draw() -> void:
	if not enabled:
		return

	var tile_mode: String = get_tile_preview_mode()
	var chunk_mode: String = get_chunk_preview_mode()

	if chunk_mode != "none":
		draw_chunk_preview(chunk_mode)

	if tile_mode != "none":
		draw_tile_preview(tile_mode)

	draw_chunk_borders()
	draw_active_radius()


# ---------------------------------------------------------
# TILE-LEVEL PREVIEW
# ---------------------------------------------------------
func draw_tile_preview(mode: String) -> void:
	var chunk_world_size: int = world_manager.CHUNK_SIZE * world_manager.TILE_SIZE
	var tile_size: int = world_manager.TILE_SIZE

	for chunk_coord in world_manager.world.keys():
		var chunk = world_manager.world[chunk_coord]
		var tiles = chunk["tiles"]

		var cx: int = chunk_coord.x
		var cy: int = chunk_coord.y

		for x in range(world_manager.CHUNK_SIZE):
			for y in range(world_manager.CHUNK_SIZE):

				var tile: WorldTile = tiles[x][y]
				var color: Color = Color(0, 0, 0, 0)

				match mode:
					"altitude":
						var v: float = (tile.altitude + 1.0) / 2.0
						color = Color(v, v, v, 0.55)

					"moisture":
						var v: float = (tile.moisture + 1.0) / 2.0
						color = Color(0.0, v, 1.0 - v, 0.55)

					"temperature":
						var v: float = (tile.temperature + 1.0) / 2.0
						color = Color(v, 0.0, 1.0 - v, 0.55)

					"temperature_final":
						var v: float = (tile.temp_final + 1.0) / 2.0
						color = Color(v, 0.0, 1.0 - v, 0.55)

					"biome":
						color = biome_color(tile.biome)

				var world_x: float = cx * chunk_world_size + x * tile_size
				var world_y: float = cy * chunk_world_size + y * tile_size

				draw_rect(Rect2(world_x, world_y, tile_size, tile_size), color, true)


# ---------------------------------------------------------
# CHUNK-LEVEL PREVIEW
# ---------------------------------------------------------
func draw_chunk_preview(mode: String) -> void:
	var chunk_world_size: int = world_manager.CHUNK_SIZE * world_manager.TILE_SIZE

	for chunk_coord in world_manager.world.keys():
		var chunk = world_manager.world[chunk_coord]
		var tiles = chunk["tiles"]

		var cx: int = chunk_coord.x
		var cy: int = chunk_coord.y

		var alt_sum: float = 0.0
		var moist_sum: float = 0.0
		var temp_raw_sum: float = 0.0
		var temp_final_sum: float = 0.0
		var count: int = 0

		for x in range(world_manager.CHUNK_SIZE):
			for y in range(world_manager.CHUNK_SIZE):
				var t: WorldTile = tiles[x][y]
				alt_sum += t.altitude
				moist_sum += t.moisture
				temp_raw_sum += t.temperature
				temp_final_sum += t.temp_final
				count += 1

		var alt_avg: float = alt_sum / count
		var moist_avg: float = moist_sum / count
		var temp_raw_avg: float = temp_raw_sum / count
		var temp_final_avg: float = temp_final_sum / count

		if mode == "chunk_info":
			draw_chunk_info(chunk_coord, alt_avg, moist_avg, temp_raw_avg, temp_final_avg)
			continue

		var color: Color = Color(0,0,0,0)

		match mode:
			"altitude":
				var v: float = (alt_avg + 1.0) / 2.0
				color = Color(v, v, v, 0.55)

			"moisture":
				var v: float = (moist_avg + 1.0) / 2.0
				color = Color(0.0, v, 1.0 - v, 0.55)

			"temperature":
				var v: float = (temp_raw_avg + 1.0) / 2.0
				color = Color(v, 0.0, 1.0 - v, 0.55)

			"temperature_final":
				var v: float = (temp_final_avg + 1.0) / 2.0
				color = Color(v, 0.0, 1.0 - v, 0.55)

			"biome":
				var mid: WorldTile = tiles[world_manager.CHUNK_SIZE/2][world_manager.CHUNK_SIZE/2]
				color = biome_color(mid.biome)

			"roughness":
				color = roughness_color(tiles)

		var world_pos := Vector2(cx * chunk_world_size, cy * chunk_world_size)
		draw_rect(Rect2(world_pos, Vector2(chunk_world_size, chunk_world_size)), color, true)


# ---------------------------------------------------------
# CHUNK INFO MODE (numbers)
# ---------------------------------------------------------
func draw_chunk_info(chunk_coord: Vector2i, alt_avg: float, moist_avg: float, temp_raw_avg: float, temp_final_avg: float) -> void:
	var chunk_world_size: int = world_manager.CHUNK_SIZE * world_manager.TILE_SIZE
	var cx: int = chunk_coord.x
	var cy: int = chunk_coord.y

	var world_pos := Vector2(cx * chunk_world_size, cy * chunk_world_size)

	var rough: float = compute_chunk_roughness(chunk_coord)

	var lines: Array[String] = []
	lines.append("A: %.2f" % alt_avg)
	lines.append("M: %.2f" % moist_avg)
	lines.append("T: %.2f" % temp_raw_avg)
	lines.append("TF: %.2f" % temp_final_avg)
	lines.append("R: %.2f" % rough)

	var font := ThemeDB.fallback_font
	var base_pos := world_pos + Vector2(6, 32) # below "(cx, cy)" label
	var line_height: float = 14.0

	for i in range(lines.size()):
		var line_pos := base_pos + Vector2(0, i * line_height)
		draw_string(
			font,
			line_pos,
			lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			14,
			Color(0,0,0,1),
			0
		)


# ---------------------------------------------------------
# ROUGHNESS
# ---------------------------------------------------------
func compute_chunk_roughness(chunk_coord: Vector2i) -> float:
	var tiles = world_manager.world[chunk_coord]["tiles"]
	var values: Array[float] = []

	for x in range(world_manager.CHUNK_SIZE):
		for y in range(world_manager.CHUNK_SIZE):
			values.append(tiles[x][y].altitude)

	var mean: float = 0.0
	for v in values:
		mean += v
	mean /= values.size()

	var variance: float = 0.0
	for v in values:
		variance += pow(v - mean, 2)
	variance /= values.size()

	return sqrt(variance)


func roughness_color(tiles: Array) -> Color:
	var values: Array[float] = []
	for x in range(world_manager.CHUNK_SIZE):
		for y in range(world_manager.CHUNK_SIZE):
			values.append(tiles[x][y].altitude)

	var mean: float = 0.0
	for v in values:
		mean += v
	mean /= values.size()

	var variance: float = 0.0
	for v in values:
		variance += pow(v - mean, 2)
	variance /= values.size()

	var stddev: float = sqrt(variance)
	var r: float = clamp(stddev * 3.0, 0.0, 1.0)
	return Color(r, 0.0, 1.0 - r, 0.55)


# ---------------------------------------------------------
# BIOME COLOR
# ---------------------------------------------------------
func biome_color(biome: String) -> Color:
	match biome:
		"ocean": return Color(0.0, 0.3, 0.8, 0.55)
		"desert": return Color(0.9, 0.8, 0.2, 0.55)
		"grassland": return Color(0.4, 0.9, 0.4, 0.55)
		"forest": return Color(0.0, 0.5, 0.0, 0.55)
		_:
			return Color(1.0, 0.0, 1.0, 0.55)


# ---------------------------------------------------------
# CHUNK BORDERS
# ---------------------------------------------------------
func draw_chunk_borders() -> void:
	var chunk_world_size: int = world_manager.CHUNK_SIZE * world_manager.TILE_SIZE

	for chunk_coord in world_manager.world.keys():
		var cx: int = chunk_coord.x
		var cy: int = chunk_coord.y

		var world_pos := Vector2(cx * chunk_world_size, cy * chunk_world_size)

		draw_rect(Rect2(world_pos, Vector2(chunk_world_size, chunk_world_size)), Color(0,0,0,1), false, 2)

		var label := "(" + str(cx) + ", " + str(cy) + ")"
		var label_pos := world_pos + Vector2(6, 14)

		draw_string(
			ThemeDB.fallback_font,
			label_pos,
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			16,
			Color(0,0,0,1),
			0
		)


# ---------------------------------------------------------
# ACTIVE CHUNK RADIUS
# ---------------------------------------------------------
func draw_active_radius() -> void:
	if player == null:
		return

	var chunk_world_size: int = world_manager.CHUNK_SIZE * world_manager.TILE_SIZE
	var player_chunk: Vector2i = world_manager.world_to_chunk(player.global_position)
	var r: int = world_manager.ACTIVE_RADIUS

	var top_left := Vector2(
		(player_chunk.x - r) * chunk_world_size,
		(player_chunk.y - r) * chunk_world_size
	)

	var size := Vector2(
		(r * 2 + 1) * chunk_world_size,
		(r * 2 + 1) * chunk_world_size
	)

	draw_rect(
		Rect2(top_left, size),
		Color(1, 0, 0, 1),
		false,
		3
	)
