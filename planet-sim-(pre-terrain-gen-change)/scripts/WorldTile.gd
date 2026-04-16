# scripts/TileData.gd
class_name WorldTile

# ---------------------------------------------------------
# RAW CLIMATE FIELDS (from noise)
# ---------------------------------------------------------
var altitude: float
var moisture: float
var temperature: float

# ---------------------------------------------------------
# BIOME (current simple version)
# Will later be derived from climate bands + biome matrix
# ---------------------------------------------------------
var biome: String
var tile_id: int

# ---------------------------------------------------------
# CLIMATE ENGINE FIELDS (Stage 1)
# ---------------------------------------------------------

# Temperature after climate adjustments (lat/alt/season)
var temp_final: float

# Moisture after future adjustments (currently same as moisture)
var moisture_final: float

# ---------------------------------------------------------
# CLIMATE BANDS (Stage 2)
# These MUST be ints (0–6), not strings
# ---------------------------------------------------------
var altitude_band: int = 0
var temp_band: int = 0
var moisture_band: int = 0

# ---------------------------------------------------------
# SOFT BIOME CLASSIFICATION (Stage 3+)
# Example: { "forest": 0.7, "grassland": 0.3 }
# ---------------------------------------------------------
var biome_weights: Dictionary = {}
