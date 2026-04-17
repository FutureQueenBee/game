class_name WorldTile

# TILE IDS
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

# Climate Fields (Raw)
var altitude: float
var moisture: float
var temperature: float

# Climate Engine Fields (Processed)
var temp_final: float
var moisture_final: float

# Biome Metadata
var biome: String
var tile_id: int

func classify_biome():
	# 1. Altitude Tiering (Water vs Land)
	if altitude < -0.5:
		tile_id = TILE_OCEAN_DEEP
		biome = "ocean_deep"
	elif altitude < -0.25:
		tile_id = TILE_OCEAN_MID
		biome = "ocean_mid"
	elif altitude < -0.05:
		tile_id = TILE_OCEAN_SHELF
		biome = "ocean_shelf"
	elif altitude < 0.0:
		tile_id = TILE_COAST
		biome = "coast"
	else:
		# 2. Land Classification (Temperature + Moisture)
		if temperature < 0.2: # Cold Zones
			if altitude > 0.6:
				tile_id = TILE_SNOW
				biome = "snow"
			else:
				tile_id = TILE_TUNDRA
				biome = "tundra"
		elif altitude > 0.8:
			tile_id = TILE_PEAK
			biome = "peak"
		elif altitude > 0.5:
			tile_id = TILE_MOUNTAIN
			biome = "mountain"
		else:
			# Main Biome Matrix
			if moisture < 0.3:
				tile_id = TILE_DESERT
				biome = "desert"
			elif moisture > 0.7:
				tile_id = TILE_FOREST
				biome = "forest"
			else:
				if altitude > 0.3:
					tile_id = TILE_HIGHLAND
					biome = "highland"
				else:
					tile_id = TILE_GRASSLAND
					biome = "grassland"
