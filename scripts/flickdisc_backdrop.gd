extends Control

## Dark club backdrop. The logo carries the colour; the ground stays quiet.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var size := get_size()
	if size.x < 2.0:
		size = Vector2(540, 960)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#09080d"))
	var hero := Vector2(size.x * 0.5, 228.0)
	draw_circle(hero, 250.0, Color(0.42, 0.04, 0.16, 0.55))
	draw_circle(hero, 156.0, Color(1.0, 0.16, 0.42, 0.16))
	draw_circle(hero, 86.0, Color(1.0, 0.62, 0.78, 0.08))
	draw_arc(hero, 138.0, 0.0, TAU, 80, Color(1.0, 0.62, 0.78, 0.34), 1.5, true)
	draw_arc(hero, 176.0, -0.4, 2.4, 48, Color(1.0, 0.84, 0.46, 0.4), 2.0, true)
	draw_rect(Rect2(0.0, 0.0, size.x, 92.0), Color(0.03, 0.01, 0.04, 0.55))
	draw_rect(Rect2(0.0, size.y - 130.0, size.x, 130.0), Color(0.02, 0.0, 0.03, 0.78))
	draw_rect(Rect2(0.0, 0.0, 16.0, size.y), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(size.x - 16.0, 0.0, 16.0, size.y), Color(0.0, 0.0, 0.0, 0.45))
