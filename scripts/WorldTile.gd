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

# --- WHITTAKER MATRIX (5x5) ---
# Rows (Temp): 0:Cold -> 4:Hot | Cols (Moist): 0:Arid -> 4:Wet
const WHITTAKER_LAND = [
	[TILE_SNOW,   TILE_SNOW,      TILE_TUNDRA,    TILE_TUNDRA,    TILE_TUNDRA],    # 0: Cold
	[TILE_DESERT, TILE_GRASSLAND, TILE_GRASSLAND, TILE_FOREST,    TILE_FOREST],    # 1
	[TILE_DESERT, TILE_GRASSLAND, TILE_HIGHLAND,  TILE_FOREST,    TILE_FOREST],    # 2: Mid
	[TILE_DESERT, TILE_GRASSLAND, TILE_GRASSLAND, TILE_FOREST,    TILE_FOREST],    # 3
	[TILE_DESERT, TILE_DESERT,    TILE_GRASSLAND, TILE_FOREST,    TILE_FOREST]     # 4: Hot
]

func classify_biome():
	# 1. HYDROSPHERE (Altitude Tiers)
	if altitude < 0.0:
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
		return

	# 2. OROGRAPHY (High Altitude Overrides)
	if altitude > 0.8:
		tile_id = TILE_PEAK
		biome = "peak"
		return
	if altitude > 0.5:
		tile_id = TILE_MOUNTAIN
		biome = "mountain"
		return

	# 3. BIOSPHERE (Whittaker Matrix Lookup)
	# Map 0.0-1.0 to 0-4 indices
	var t_idx = clampi(int(temperature * 5), 0, 4)
	var m_idx = clampi(int(moisture * 5), 0, 4)

	tile_id = WHITTAKER_LAND[t_idx][m_idx]

	# Semantic Naming for Debugging
	match tile_id:
		TILE_SNOW: biome = "snow"
		TILE_TUNDRA: biome = "tundra"
		TILE_DESERT: biome = "desert"
		TILE_GRASSLAND: biome = "grassland"
		TILE_FOREST: biome = "forest"
		TILE_HIGHLAND: biome = "highland"
		_: biome = "land"
