extends Node

@export var CHUNK_SIZE: int = 32
@export var TILE_SIZE: int = 16
@export var ACTIVE_RADIUS: int = 5
@export var UNLOAD_BUFFER: int = 2
@export var WORLD_WIDTH_TILES: int = 2048
@export var WORLD_HEIGHT_TILES: int = 1024

# ---------------------------------------------------------
# WORLD + SIMULATION STATE
# ---------------------------------------------------------
var world: Dictionary = {}   # { Vector2i: { "tiles": Array, "dirty": bool, "sim_state": Dictionary } }

# Master time in DAYS
var world_time_days: float = 0.0

# How fast time moves (multiplier on real time)
var time_scale: float = 1.0

# How many real seconds correspond to 1 in-game day (tunable)
var real_seconds_per_day: float = 1200.0  # 20 minutes per day as a starting point


@onready var generator: Node = $"../ChunkGenerator"
@onready var renderer: Node = $"../ChunkRenderer"
@onready var player: Node2D = $"../Player"

const DEBUG_LOG_PATH := "res://debug-cd6f1c.log"
const DEBUG_RUN_ID := "post-fix"

func _debug_log(hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "cd6f1c",
		"runId": DEBUG_RUN_ID,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()


func _ready() -> void:
	print("WorldManager player = ", player)


func _process(delta: float) -> void:
	# TEMP: you may want to remove this spam later
	#print("WORLD SIZE: ", world.size())

	if player == null:
		return

	# 1) Advance global time
	var dt_days: float = advance_time(delta)

	# 2) Run simulation for chunks (stub for now)
	simulate_chunks(dt_days)

	# 3) Chunk management + rendering
	var player_chunk: Vector2i = world_to_chunk(player.global_position)
	# #region agent log
	_debug_log(
		"H1",
		"WorldManager.gd:_process",
		"Player chunk from world_to_chunk",
		{
			"player_global_pos": player.global_position,
			"player_chunk": player_chunk
		}
	)
	# #endregion

	update_active_chunks(player_chunk)
	unload_far_chunks(player_chunk)

	renderer.render_visible_chunks(world, player_chunk, world_width_chunks())


# ---------------------------------------------------------
# TIME SYSTEM
# ---------------------------------------------------------
func advance_time(delta: float) -> float:
	# Convert real-time delta (seconds) into in-game days
	# world_time_days += (delta * time_scale) / real_seconds_per_day
	var dt_days := (delta * time_scale) / real_seconds_per_day
	world_time_days += dt_days
	return dt_days


func set_time_scale(new_scale: float) -> void:
	time_scale = max(new_scale, 0.0)
	print("Time scale set to: ", time_scale)


func jump_days(days: float) -> void:
	world_time_days += days
	print("Jumped world time by ", days, " days. Now: ", world_time_days)


# ---------------------------------------------------------
# INPUT: TIME CONTROLS (BASIC)
# ---------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P:
				# Toggle pause
				if time_scale != 0.0:
					time_scale = 0.0
					print("Time paused")
				else:
					time_scale = 1.0
					print("Time resumed (scale = 1.0)")
			KEY_BRACKETLEFT:
				# Slow down time
				time_scale = max(time_scale / 2.0, 0.0)
				print("Time scale decreased to: ", time_scale)
			KEY_BRACKETRIGHT:
				# Speed up time
				if time_scale == 0.0:
					time_scale = 1.0
				else:
					time_scale *= 2.0
				print("Time scale increased to: ", time_scale)
			KEY_J:
				# Jump forward 1 day
				jump_days(1.0)
			KEY_K:
				# Jump forward 365 days (1 year)
				jump_days(365.0)


# ---------------------------------------------------------
# WORLD / CHUNK COORDINATES
# ---------------------------------------------------------
func world_to_chunk(pos: Vector2) -> Vector2i:
	var raw_chunk := Vector2i(
		floor(pos.x / (CHUNK_SIZE * TILE_SIZE)),
		floor(pos.y / (CHUNK_SIZE * TILE_SIZE))
	)
	return Vector2i(
		posmod(raw_chunk.x, world_width_chunks()),
		clamp(raw_chunk.y, 0, world_height_chunks() - 1)
	)


func world_width_chunks() -> int:
	return max(1, int(ceil(float(max(1, WORLD_WIDTH_TILES)) / float(CHUNK_SIZE))))


func world_height_chunks() -> int:
	return max(1, int(ceil(float(max(1, WORLD_HEIGHT_TILES)) / float(CHUNK_SIZE))))


func wrap_chunk_x(cx: int) -> int:
	return posmod(cx, world_width_chunks())


func clamp_chunk_y(cy: int) -> int:
	return clamp(cy, 0, world_height_chunks() - 1)


# ---------------------------------------------------------
# LOAD CHUNKS INSIDE ACTIVE RADIUS
# ---------------------------------------------------------





func update_active_chunks(center: Vector2i) -> void:
	var world_width = world_width_chunks()
	# Load up to ACTIVE_RADIUS + 1 to ensure a buffer for the unloader
	for dx in range(-(ACTIVE_RADIUS + 1), ACTIVE_RADIUS + 2):
		for dy in range(-(ACTIVE_RADIUS + 1), ACTIVE_RADIUS + 2):
			var wrapped_cx = posmod(center.x + dx, world_width)
			var clamped_cy = clamp(center.y + dy, 0, world_height_chunks() - 1)
			var key = Vector2i(wrapped_cx, clamped_cy)

			if not world.has(key):
				var tiles = generator.generate_chunk(wrapped_cx, clamped_cy)
				world[key] = {
					"tiles": tiles,
					"dirty": true,
					"sim_state": {"last_update_time": world_time_days}
				}

func unload_far_chunks(center: Vector2i) -> void:
	# Unloader buffer must be strictly > loader range to prevent flicker
	var max_dist = ACTIVE_RADIUS + UNLOAD_BUFFER
	var world_width = world_width_chunks()
	var to_unload = []

	for key in world.keys():
		var dx_linear = abs(key.x - center.x)
		var dx = min(dx_linear, world_width - dx_linear)
		var dy = abs(key.y - center.y)

		if dx > max_dist or dy > max_dist:
			to_unload.append(key)

	for key in to_unload:
		world.erase(key)

func simulate_chunks(dt_days: float) -> void:
	# For now, just update last_update_time so the structure is correct.
	for raw_key in world.keys():
		var key: Vector2i = raw_key as Vector2i
		if key == null:
			continue

		var chunk: Dictionary = world[key]
		if not chunk.has("sim_state"):
			continue

		var sim_state: Dictionary = chunk["sim_state"]

		var last_time: float = sim_state.get("last_update_time", world_time_days)
		var local_dt: float = world_time_days - last_time

		# Placeholder: just advance last_update_time
		sim_state["last_update_time"] = world_time_days

		# Later: use local_dt to update fire, biomass, moisture, etc.

func test_git_sync() -> void:
	print("Git Sync Successful: Connection is working!")

# Manual sync update: Thu Apr 16 05:11:05 2026

# Manual sync update: Thu Apr 16 05:24:31 2026

# Manual sync update: Thu Apr 16 05:24:33 2026
