class_name WorldTile

# --- TILE ATLAS MAPPING ---
const TILE_OCEAN_DEEP: int = 0
const TILE_OCEAN_MID: int = 1
const TILE_OCEAN_SHELF: int = 2
const TILE_COAST: int = 3
const TILE_LOWLAND: int = 4
const TILE_HIGHLAND: int = 5
const TILE_MOUNTAIN: int = 6
const TILE_PEAK: int = 7
const TILE_DESERT: int = 8
const TILE_GRASSLAND: int = 9
const TILE_FOREST: int = 10
const TILE_TUNDRA: int = 11
const TILE_SNOW: int = 12
const TILE_RIVER: int = 13
const TILE_LAKE: int = 14

# --- DATA FIELDS ---
var altitude: float
var moisture: float
var temperature: float
var biome: String
var tile_id: int

# --- HYDRAULIC DATA (PHASE 2) ---
var flow_accumulation: float = 0.0
var flow_direction: Vector2 = Vector2.ZERO

func classify_biome():
	if altitude < 0.0:
		_classify_water()
		return

	if altitude < 0.15:
		tile_id = TILE_LOWLAND
		biome = "floodplain"
		return

	# Fallback to standard Whittaker logic...
	_classify_land_matrix()

func _classify_water():
	if altitude < -0.5:
		tile_id = TILE_OCEAN_DEEP
		biome = "ocean_deep"
	elif altitude < -0.25:
		tile_id = TILE_OCEAN_MID
		biome = "ocean_mid"
	elif altitude < -0.05:
		tile_id = TILE_OCEAN_SHELF
		biome = "ocean_shelf"
	else:
		tile_id = TILE_COAST
		biome = "coast"

func _classify_land_matrix():
	var t_idx = clampi(int(temperature * 5), 0, 4)
	var m_idx = clampi(int(moisture * 5), 0, 4)
	# Logic continues with WHITTAKER_LAND matrix...
