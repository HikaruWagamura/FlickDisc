extends Control

## Navy club night behind the hub. Red left, blue right, gold in the middle.

const SPACE := preload("res://assets/syncsphere_space.png")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var size := get_size()
	if size.x < 2.0:
		size = Vector2(540, 960)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#050814"), true)
	if SPACE != null:
		draw_texture_rect(SPACE, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.06, 0.14, 0.78), true)
	draw_circle(Vector2(size.x * 0.12, size.y * 0.22), 210.0, Color(0.82, 0.08, 0.14, 0.22))
	draw_circle(Vector2(size.x * 0.88, size.y * 0.28), 230.0, Color(0.08, 0.28, 0.92, 0.24))
	draw_circle(Vector2(size.x * 0.5, size.y * 0.12), 90.0, Color(0.95, 0.72, 0.18, 0.10))
	draw_circle(Vector2(size.x * 0.18, size.y * 0.78), 180.0, Color(0.72, 0.06, 0.12, 0.14))
	draw_circle(Vector2(size.x * 0.82, size.y * 0.82), 200.0, Color(0.10, 0.22, 0.78, 0.16))
