extends Node
class_name ClimateModel

# Rolling climate samples (now chunk-level, not tile-level)
var temperature_samples: Array[float] = []
var moisture_samples: Array[float] = []
var altitude_samples: Array[float] = []

const MAX_SAMPLES := 20000

# Thresholds for 7-band classification (computed periodically)
var temp_thresholds: Array[float] = []
var moisture_thresholds: Array[float] = []
var altitude_thresholds: Array[float] = []

# Timer for periodic threshold computation
var _time_since_last_compute: float = 0.0


func _ready() -> void:
	set_process(true)


# ---------------------------------------------------------
# SAMPLE COLLECTION (ONE SAMPLE PER CHUNK)
# ---------------------------------------------------------
func add_sample(altitude: float, moisture: float, temp_final: float) -> void:
	altitude_samples.append(altitude)
	moisture_samples.append(moisture)
	temperature_samples.append(temp_final)

	# Trim arrays if they exceed max size
	if altitude_samples.size() > MAX_SAMPLES:
		altitude_samples.pop_front()
	if moisture_samples.size() > MAX_SAMPLES:
		moisture_samples.pop_front()
	if temperature_samples.size() > MAX_SAMPLES:
		temperature_samples.pop_front()


func has_enough_data() -> bool:
	return altitude_samples.size() > 200


# ---------------------------------------------------------
# PERIODIC THRESHOLD COMPUTATION (NOT DURING CHUNK LOAD)
# ---------------------------------------------------------
func _process(delta: float) -> void:
	_time_since_last_compute += delta

	# Compute thresholds every 2 seconds
	if _time_since_last_compute >= 2.0 and has_enough_data():
		_compute_thresholds()
		_time_since_last_compute = 0.0


func _compute_thresholds() -> void:
	temp_thresholds = _compute_quantiles(temperature_samples)
	moisture_thresholds = _compute_quantiles(moisture_samples)
	altitude_thresholds = _compute_quantiles(altitude_samples)


func _compute_quantiles(values: Array[float]) -> Array[float]:
	if values.is_empty():
		return []

	var sorted := values.duplicate()
	sorted.sort()

	var thresholds: Array[float] = []
	var count := sorted.size()

	# 7 bands = 6 thresholds
	for i in range(1, 7):
		var q := float(i) / 7.0
		var idx := int(q * count)
		idx = clamp(idx, 0, count - 1)
		thresholds.append(sorted[idx])

	return thresholds


# ---------------------------------------------------------
# BAND LOOKUP
# ---------------------------------------------------------
func get_band(value: float, thresholds: Array[float]) -> int:
	if thresholds.size() < 6:
		return 3  # fallback: middle band

	for i in range(thresholds.size()):
		if value < thresholds[i]:
			return i

	return 6


func get_temp_band(value: float) -> int:
	return get_band(value, temp_thresholds)


func get_moisture_band(value: float) -> int:
	return get_band(value, moisture_thresholds)


func get_altitude_band(value: float) -> int:
	return get_band(value, altitude_thresholds)
