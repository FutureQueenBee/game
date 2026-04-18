class_name WorldTile

# Climate Fields
var altitude: float
var moisture: float
var temperature: float

# Discrete Bands (0-4)
var temp_band: int = 0
var moisture_band: int = 0

# Output Metadata
var biome: String
var tile_id: int

# The Whittaker Matrix Blueprint
# Rows: Temperature (0=Cold, 4=Hot)
# Cols: Moisture (0=Arid, 4=Wet)
const BIOME_MATRIX = [
	[12, 12, 11, 11, 11], # 0: Cold
	[8,  9,  9,  10, 10], # 1
	[8,  9,  5,  10, 13], # 2: Mid (Highland at center)
	[8,  14, 14, 13, 13], # 3
	[8,  14, 14, 13, 13]  # 4: Hot
]

const BIOME_NAMES = {
	0: "ocean", 5: "highland", 8: "desert", 9: "grassland", 
	10: "forest", 11: "tundra", 12: "snow", 13: "rainforest", 14: "savanna"
}

func classify_biome():
	if altitude < 0.0:
		biome = "ocean"
		tile_id = 0
		return
	
	# Clamp bands to valid matrix indices
	temp_band = clampi(int(temperature * 5), 0, 4)
	moisture_band = clampi(int(moisture * 5), 0, 4)
	
	tile_id = BIOME_MATRIX[temp_band][moisture_band]
	biome = BIOME_NAMES.get(tile_id, "unknown")
