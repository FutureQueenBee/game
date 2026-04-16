extends Label

@onready var world_manager: Node = $"../../../WorldManager"
@onready var debug_overlay: Node = $"../../../DebugOverlay"


func _process(delta: float) -> void:
	if world_manager == null:
		text = "WorldManager not found"
		return

	# Explicitly typed to avoid inference errors
	var total_days: float = world_manager.world_time_days

	# ---------------------------------------------------------
	# Memory usage with automatic MB/GB switching
	# ---------------------------------------------------------
	var mem_bytes: float = float(OS.get_static_memory_usage())
	var mem_mb: float = mem_bytes / (1024.0 * 1024.0)
	var mem_text: String

	if mem_mb < 1024.0:
		# Display in MB
		mem_text = str(round(mem_mb * 10.0) / 10.0) + " MB"
	else:
		# Convert to GB
		var mem_gb: float = mem_mb / 1024.0
		mem_text = str(round(mem_gb * 100.0) / 100.0) + " GB"

	# ---------------------------------------------------------
	# Build the debug text
	# ---------------------------------------------------------
	var t := ""
	t += "World Size: " + str(world_manager.world.size()) + "\n"
	t += "World Time (days): " + str(round(total_days * 1000.0) / 1000.0) + "\n"
	t += "Time Scale: " + str(world_manager.time_scale) + "\n"
	t += "Tile Preview: " + debug_overlay.get_tile_preview_mode() + "\n"
	t += "Chunk Preview: " + debug_overlay.get_chunk_preview_mode() + "\n"


	# Derived time
	var year := int(total_days) / 365
	var day_of_year := int(total_days) % 365
	t += "Year: " + str(year) + "   Day: " + str(day_of_year) + "\n"

	# Memory usage
	t += "Memory: " + mem_text + "\n"

	text = t
