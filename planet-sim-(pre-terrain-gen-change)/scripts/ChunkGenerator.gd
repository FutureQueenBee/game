extends Node


@onready var climate_model: ClimateModel = get_node("../WorldManager/ClimateModel")
@onready var world_manager: Node = get_node("../WorldManager")

const CHUNK_SIZE := 32

# Virtual planet height in tiles (for latitude)
const PLANET_LAT_HEIGHT_TILES: float = 2048.0
const LAT_CENTER: float = PLANET_LAT_HEIGHT_TILES / 2.0
const LAT_RANGE: float = PLANET_LAT_HEIGHT_TILES / 2.0

var noise_alt := FastNoiseLite.new()
var noise_moist := FastNoiseLite.new()
var noise_temp := FastNoiseLite.new()

const DEBUG_LOG_PATH := "res://debug-cd6f1c.log"

func _debug_log(hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "cd6f1c",
		"runId": "pre-fix",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()


func _ready() -> void:
	noise_alt.seed = randi()
	noise_moist.seed = randi()
	noise_temp.seed = randi()

	noise_alt.frequency = 0.005
	noise_moist.frequency = 0.01
	noise_temp.frequency = 0.01
	if climate_model == null:
		push_error("ChunkGenerator: ClimateModel NOT FOUND at path ../WorldManager/ClimateModel")
	else:
		print("ChunkGenerator: ClimateModel found successfully")


func _chunk_size() -> int:
	if world_manager != null and world_manager.has_method("world_width_chunks"):
		return int(world_manager.CHUNK_SIZE)
	return CHUNK_SIZE


func _world_width_tiles() -> int:
	if world_manager != null and world_manager.has_method("world_width_chunks"):
		return int(world_manager.WORLD_WIDTH_TILES)
	return _chunk_size() * 64


func _world_height_tiles() -> int:
	if world_manager != null and world_manager.has_method("world_height_chunks"):
		return int(world_manager.WORLD_HEIGHT_TILES)
	return int(PLANET_LAT_HEIGHT_TILES)


func _wrap_tile_x(x: int) -> int:
	return posmod(x, max(1, _world_width_tiles()))


func _clamp_tile_y(y: int) -> int:
	return clamp(y, 0, max(1, _world_height_tiles()) - 1)


func generate_chunk(cx: int, cy: int) -> Array:
	# #region agent log
	_debug_log(
		"H3",
		"ChunkGenerator.gd:generate_chunk",
		"Chunk generation start",
		{
			"chunk_coord": Vector2i(cx, cy),
			"generator_chunk_size": _chunk_size(),
			"lat_height_tiles": _world_height_tiles()
		}
	)
	# #endregion
	var tiles: Array = []
	var chunk_size: int = _chunk_size()
	tiles.resize(chunk_size)
	var edge_left_alt_sum: float = 0.0
	var edge_right_alt_sum: float = 0.0
	var top_row_alt_sum: float = 0.0
	var top_row_alt_sq_sum: float = 0.0

	# Per-chunk climate accumulation (NEW)
	var chunk_alt_sum: float = 0.0
	var chunk_moist_sum: float = 0.0
	var chunk_temp_sum: float = 0.0
	var sample_count: int = 0

	for x in range(chunk_size):
		tiles[x] = []
		for y in range(chunk_size):

			var wx_raw: int = cx * chunk_size + x
			var wy_raw: int = cy * chunk_size + y
			var wx: int = _wrap_tile_x(wx_raw)
			var wy: int = _clamp_tile_y(wy_raw)
			if x == 0 and y == 0:
				# #region agent log
				_debug_log(
					"H3",
					"ChunkGenerator.gd:generate_chunk",
					"First world tile sample for chunk",
					{
						"chunk_coord": Vector2i(cx, cy),
						"first_world_tile_raw": Vector2i(wx_raw, wy_raw),
						"first_world_tile": Vector2i(wx, wy)
					}
				)
				# #endregion

			# --- Raw noise fields ---
			var alt: float = noise_alt.get_noise_2d(wx, wy)
			var moist_raw: float = noise_moist.get_noise_2d(wx, wy)
			var temp_raw: float = noise_temp.get_noise_2d(wx, wy)

			# --- Latitude in -1..1 (south to north) ---
			var lat_height: float = float(max(1, _world_height_tiles()))
			var lat_center: float = lat_height / 2.0
			var lat_range: float = max(1.0, lat_height / 2.0)
			var lat: float = clamp((float(wy) - lat_center) / lat_range, -1.0, 1.0)

			# --- Climate adjustments ---
			var temp_lat: float = -abs(lat)
			var temp_alt: float = -alt * 0.5
			var season_offset: float = 0.0

			var temp_final: float = temp_raw + temp_lat * 0.5 + temp_alt + season_offset
			var moist_final: float = moist_raw

			# Accumulate per-chunk averages (NEW)
			chunk_alt_sum += alt
			chunk_moist_sum += moist_final
			chunk_temp_sum += temp_final
			sample_count += 1

			# --- Biome classification (current simple version) ---
			var biome: String = classify_biome(alt, moist_raw, temp_raw)
			var tile_id: int = biome_to_tile(biome)

			var t := WorldTile.new()
			t.altitude = alt
			t.moisture = moist_raw
			t.temperature = temp_raw
			t.biome = biome
			t.tile_id = tile_id

			# Climate fields for later use
			t.temp_final = temp_final
			t.moisture_final = moist_final
			t.temp_band = 0
			t.moisture_band = 0
			t.altitude_band = 0
			t.biome_weights = {}

			tiles[x].append(t)
			if x == 0:
				edge_left_alt_sum += alt
			if x == chunk_size - 1:
				edge_right_alt_sum += alt
			if y == 0:
				top_row_alt_sum += alt
				top_row_alt_sq_sum += alt * alt

	# One sample per chunk into ClimateModel (NEW)
	if sample_count > 0 and climate_model != null:
		var avg_alt := chunk_alt_sum / sample_count
		var avg_moist := chunk_moist_sum / sample_count
		var avg_temp := chunk_temp_sum / sample_count
		climate_model.add_sample(avg_alt, avg_moist, avg_temp)

	if world_manager != null and world_manager.has_method("world_width_chunks"):
		var world_chunks_x: int = int(world_manager.world_width_chunks())
		var world_chunks_y: int = int(world_manager.world_height_chunks())
		var is_seam_chunk: bool = (cx == 0 or cx == world_chunks_x - 1)
		var is_polar_chunk: bool = (cy == 0 or cy == world_chunks_y - 1)
		if is_seam_chunk or is_polar_chunk:
			var top_count: float = float(max(1, chunk_size))
			var top_mean: float = top_row_alt_sum / top_count
			var top_var: float = max(0.0, (top_row_alt_sq_sum / top_count) - (top_mean * top_mean))
			# #region agent log
			_debug_log(
				"H12",
				"ChunkGenerator.gd:generate_chunk",
				"Edge stats for seam/polar chunk",
				{
					"chunk_coord": Vector2i(cx, cy),
					"is_seam_chunk": is_seam_chunk,
					"is_polar_chunk": is_polar_chunk,
					"edge_left_alt_avg": edge_left_alt_sum / float(max(1, chunk_size)),
					"edge_right_alt_avg": edge_right_alt_sum / float(max(1, chunk_size)),
					"top_row_alt_mean": top_mean,
					"top_row_alt_var": top_var
				}
			)
			# #endregion

	return tiles


func classify_biome(alt: float, moist: float, temp: float) -> String:
	if alt < -0.2:
		return "ocean"
	if moist < -0.3:
		return "desert"
	if moist > 0.4:
		return "forest"
	return "grassland"


func biome_to_tile(biome: String) -> int:
	match biome:
		"ocean": return 0
		"desert": return 1
		"grassland": return 2
		"forest": return 3
	return 2
