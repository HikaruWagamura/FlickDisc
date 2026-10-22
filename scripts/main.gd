extends Node

## Flick Chaos shell. Crokinole is the main mode. Lawn bowls is the other.

const CROKINOLE_SCENE := preload("res://scenes/Crokinole.tscn")
const LAWN_SCENE := preload("res://scenes/Lawn.tscn")

var mode := ""
var current: Node = null


func _ready() -> void:
	_open("crokinole")


func _open(next_mode: String) -> void:
	if next_mode == mode:
		return
	mode = next_mode
	if current != null:
		var old_camera := current.find_child("Camera3D", true, false) as Camera3D
		if old_camera != null:
			old_camera.current = false
		current.queue_free()
		current = null
	var packed: PackedScene = CROKINOLE_SCENE if next_mode == "crokinole" else LAWN_SCENE
	current = packed.instantiate()
	add_child(current)
	var ui := current.get_node_or_null("UI")
	if ui != null and ui.has_signal("mode_requested"):
		ui.mode_requested.connect(_open)
