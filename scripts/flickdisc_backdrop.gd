extends Control

## Dark club backdrop. The logo carries the colour; the ground stays quiet.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(540, 960)), Color("#09080d"))
