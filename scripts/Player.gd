extends CharacterBody2D
signal position_changed(new_pos: Vector2)

@export var SPEED := 10000.0

# Zoom constants
@export var ZOOM_MIN := 0.01
@export var ZOOM_MAX := 30.0
@export var ZOOM_SPEED := 0.1

@onready var anim := $AnimatedSprite2D
@onready var cam := $Camera2D
@onready var world_manager: Node = $"../WorldManager"

var zoom_level := 1.0
const DEBUG_LOG_PATH := "res://debug-cd6f1c.log"

func _debug_log(hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "cd6f1c",
		"runId": "post-fix-camera",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()


func _ready() -> void:
	if world_manager != null:
		cam.limit_enabled = false
		cam.position_smoothing_enabled = false
	# #region agent log
	_debug_log(
		"H10",
		"Player.gd:_ready",
		"Applied camera centering mode",
		{
			"position_smoothing_enabled": cam.position_smoothing_enabled,
			"limit_left": cam.limit_left,
			"limit_top": cam.limit_top,
			"limit_right": cam.limit_right,
			"limit_bottom": cam.limit_bottom,
			"limit_enabled": cam.limit_enabled
		}
	)
	# #endregion


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_level -= ZOOM_SPEED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_level += ZOOM_SPEED

		zoom_level = clamp(zoom_level, ZOOM_MIN, ZOOM_MAX)


func _physics_process(delta: float) -> void:
	# Movement input
	var input_vec := Vector2.ZERO
	input_vec.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vec.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vec = input_vec.normalized()

	velocity = input_vec * SPEED
	move_and_slide()
	emit_signal("position_changed", global_position)

	if world_manager != null:
		var world_width_px: float = float(world_manager.WORLD_WIDTH_TILES * world_manager.TILE_SIZE)
		var world_height_px: float = float(world_manager.WORLD_HEIGHT_TILES * world_manager.TILE_SIZE)
		var pre_constrain_pos: Vector2 = global_position
		var wrapped_x: float = fposmod(global_position.x, world_width_px)
		var changed: bool = false
		if global_position.x < 0.0:
			global_position.x += world_width_px
		elif global_position.x >= world_width_px:
			global_position.x -= world_width_px
			# Snap camera to prevent interpolation jump across world
			cam.global_position.x = wrapped_x
			cam.reset_smoothing()
			cam.force_update_scroll()
			cam.force_update_scroll() # Force immediate update to prevent lag
			changed = true
		var clamped_y: float = clamp(global_position.y, 0.0, world_height_px - 1.0)
		if clamped_y != global_position.y:
			global_position.y = clamped_y
			changed = true
		if changed:
			# #region agent log
			_debug_log(
				"H9",
				"Player.gd:_physics_process",
				"Applied player world confinement",
				{
					"pre_constrain_pos": pre_constrain_pos,
					"post_constrain_pos": global_position,
					"world_width_px": world_width_px,
					"world_height_px": world_height_px
				}
			)
			# #endregion
		var out_x: bool = global_position.x < 0.0 or global_position.x >= world_width_px
		var out_y: bool = global_position.y < 0.0 or global_position.y >= world_height_px
		if out_x or out_y:
			# #region agent log
			_debug_log(
				"H6",
				"Player.gd:_physics_process",
				"Player outside world pixel bounds",
				{
					"player_pos": global_position,
					"world_width_px": world_width_px,
					"world_height_px": world_height_px,
					"out_x": out_x,
					"out_y": out_y
				}
			)
			# #endregion

	# Smooth zoom interpolation
	cam.zoom = cam.zoom.lerp(Vector2(zoom_level, zoom_level), 0.15)
	if world_manager != null:
		var camera_delta: Vector2 = cam.global_position - global_position
		if camera_delta.length() > 1.0:
			# #region agent log
			_debug_log(
				"H7",
				"Player.gd:_physics_process",
				"Camera drifting from player",
				{
					"player_pos": global_position,
					"camera_pos": cam.global_position,
					"camera_delta": camera_delta,
					"camera_zoom": cam.zoom
				}
			)
			# #endregion

	# Animation logic (simple)
	if input_vec == Vector2.ZERO:
		anim.play("idle")
	else:
		anim.play("walk")

		# Flip horizontally when moving left/right
		if input_vec.x > 0:
			anim.flip_h = false
		elif input_vec.x < 0:
			anim.flip_h = true
