class_name WorldTile

# TILE IDS (Sync with Atlas)
const TILE_OCEAN_DEEP: int = 0
const TILE_OCEAN_MID: int = 1
const TILE_OCEAN_SHELF: int = 2
const TILE_COAST: int = 3
const TILE_DESERT: int = 8
const TILE_GRASSLAND: int = 9
const TILE_FOREST: int = 10
const TILE_TUNDRA: int = 11
const TILE_SNOW: int = 12
const TILE_TROPICAL_RAINFOREST: int = 13
const TILE_SAVANNA: int = 14

# Climate Fields
var altitude: float
var moisture: float
var temperature: float
var biome: String
var tile_id: int

func classify_biome():
	# 1. Water vs Land
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
		# 2. Whittaker 2D Biome Matrix (Temp vs Moisture)
		# Temp Categories: Cold (<0.25), Moderate (0.25-0.7), Hot (>0.7)
		# Moisture Categories: Arid (<0.3), Humid (0.3-0.7), Wet (>0.7)
		
		if temperature < 0.25:
			if moisture < 0.3:
				tile_id = TILE_SNOW
				biome = "snow"
			else:
				tile_id = TILE_TUNDRA
				biome = "tundra"
		elif temperature > 0.7:
			if moisture < 0.3:
				tile_id = TILE_DESERT
				biome = "desert"
			elif moisture > 0.7:
				tile_id = TILE_TROPICAL_RAINFOREST
				biome = "rainforest"
			else:
				tile_id = TILE_SAVANNA
				biome = "savanna"
		else:
			if moisture < 0.3:
				tile_id = TILE_GRASSLAND
				biome = "grassland"
			else:
				tile_id = TILE_FOREST
				biome = "forest"
