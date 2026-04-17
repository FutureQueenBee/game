class_name WorldTile

# Climate Fields
var altitude: float
var moisture: float
var temperature: float
var biome: String
var tile_id: int
var temp_final: float
var moisture_final: float
var altitude_band: int = 0
var temp_band: int = 0
var moisture_band: int = 0
var biome_weights: Dictionary = {}

func classify_biome():
	# Logic based on noise values
	if altitude < -0.2:
		biome = "ocean"
		tile_id = 0
	elif moisture < -0.3:
		biome = "desert"
		tile_id = 1
	elif moisture > 0.4:
		biome = "forest"
		tile_id = 3
	else:
		biome = "grassland"
		tile_id = 2
