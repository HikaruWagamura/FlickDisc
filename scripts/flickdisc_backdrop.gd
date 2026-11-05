extends Control

## The same space image as the SyncSphere hub. The FlickDisc mark sits on top of it.

const SPACE := preload("res://assets/syncsphere_space.png")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var size := get_size()
	if size.x < 2.0:
		size = Vector2(540, 960)
	draw_texture_rect(SPACE, Rect2(Vector2.ZERO, size), false)
