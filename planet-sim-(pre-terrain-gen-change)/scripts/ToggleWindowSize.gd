extends Node

var screen_modes := [
	"windowed",
	"borderless",
    "fullscreen"
]

var current_mode_index := 0

func _input(event):
	if event.is_action_pressed("toggle_screen_mode"):
		cycle_screen_mode()

func cycle_screen_mode():
	current_mode_index = (current_mode_index + 1) % screen_modes.size()
	apply_screen_mode(screen_modes[current_mode_index])

func apply_screen_mode(mode: String):
	match mode:
		"windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(Vector2i(1600, 900))

		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func get_current_mode() -> String:
	return screen_modes[current_mode_index]
