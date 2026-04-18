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
const POLE_THRESHOLD: float = 0.25

# --- HYDRAULIC DATA ---
var flow_accumulation: float = 0.0
var flow_direction: Vector2 = Vector2.ZERO


# --- WHITTAKER MATRIX (5x5) ---
# Rows (Temp): 0:Polar, 1:Cold, 2:Temperate, 3:Warm, 4:Tropical
# Cols (Moist): 0:Arid, 1:Dry, 2:Sub-Humid, 3:Humid, 4:Wet
const WHITTAKER_LAND = [
	[TILE_SNOW,   TILE_SNOW,      TILE_TUNDRA,    TILE_TUNDRA,    TILE_TUNDRA],    # 0: Polar
	[TILE_DESERT, TILE_GRASSLAND, TILE_GRASSLAND, TILE_FOREST,    TILE_FOREST],    # 1: Cold
	[TILE_DESERT, TILE_GRASSLAND, TILE_HIGHLAND,  TILE_FOREST,    TILE_FOREST],    # 2: Temperate
	[TILE_DESERT, TILE_GRASSLAND, TILE_GRASSLAND, TILE_FOREST,    TILE_FOREST],    # 3: Warm
	[TILE_DESERT, TILE_DESERT,    TILE_GRASSLAND, TILE_FOREST,    TILE_FOREST]     # 4: Tropical
]

func classify_biome():
	# 1. HYDROSPHERE (Water Tiers)
	if altitude < 0.0:
		_classify_water()
		return

	# 2. OROGRAPHY (High Altitude Overrides)
	if altitude > 0.8:
		tile_id = TILE_PEAK
		biome = "peak"
		return
	if altitude > 0.6:
		tile_id = TILE_MOUNTAIN
		biome = "mountain"
		return

	# 3. BIOSPHERE (Whittaker Matrix)
	_classify_land_matrix()

func _classify_water():
	# Polar Override
	var world_height = 2048.0 # Default fallback
	# We check latitude via WorldTile's position in future, but for now we rely on the override
	if biome == "ice_ocean":
		tile_id = 12 # TILE_SNOW/ICE
		return

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
	# Map 0.0-1.0 to 0-4 indices
	var t_idx = clampi(int(temperature * 5), 0, 4)
	var m_idx = clampi(int(pow(moisture, 1.2) * 5), 0, 4) # Applying your aridity bias
	
	tile_id = WHITTAKER_LAND[t_idx][m_idx]
	
	# Semantic Naming
	match tile_id:
		TILE_SNOW: biome = "snow"
		TILE_TUNDRA: biome = "tundra"
		TILE_DESERT: biome = "desert"
		TILE_GRASSLAND: biome = "grassland"
		TILE_FOREST: biome = "forest"
		TILE_HIGHLAND: biome = "highland"
		_: biome = "land"
