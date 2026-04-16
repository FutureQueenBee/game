extends Control

var enabled: bool = true

@onready var root: Node = get_parent().get_parent()
@onready var world_manager: Node = root.get_node("WorldManager")
@onready var player: Node2D = root.get_node("Player")

func _input(event):
	if event.is_action_pressed("debug_toggle"):
		enabled = !enabled
		visible = enabled

func _process(delta):
	# DebugPanel no longer draws anything itself.
	# All screen-space text is handled by DebugLabel.
	pass
