extends Control

## Club wash behind the hub. Red left, blue right, gold in the logo belt.

const SCENE := preload("res://assets/club_backdrop.png")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var size := get_size()
	if size.x < 2.0:
		size = Vector2(540, 960)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#050814"), true)
	if SCENE != null:
		draw_texture_rect(SCENE, Rect2(Vector2.ZERO, size), false)
