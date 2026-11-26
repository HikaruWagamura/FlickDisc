extends Control

## Pink-black club night behind the hub. The space photo is only a spark
## layer; the logo colours do the rest.

const SPACE := preload("res://assets/syncsphere_space.png")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var size := get_size()
	if size.x < 2.0:
		size = Vector2(540, 960)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#090008"), true)
	if SPACE != null:
		draw_texture_rect(SPACE, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.72, 0.02, 0.34, 0.78), true)
	draw_circle(Vector2(size.x * 0.78, size.y * 0.18), 160.0, Color(1.0, 0.18, 0.58, 0.16))
	draw_circle(Vector2(size.x * 0.18, size.y * 0.72), 220.0, Color(0.85, 0.04, 0.38, 0.18))
	draw_circle(Vector2(size.x * 0.5, size.y * 0.42), 90.0, Color(1.0, 0.45, 0.78, 0.10))
