extends Control

## Club wash behind the hub. Red left, blue right, gold in the logo belt.
## The art file is a 9:16 fade with a dead-black foot. We only keep the
## colourful belt and stretch it to the real phone height.

const SCENE := preload("res://assets/club_backdrop.png")
const DEEP := Color("#0a1428")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var size := get_size()
	if size.x < 2.0:
		size = Vector2(540, 960)
	draw_rect(Rect2(Vector2.ZERO, size), DEEP, true)
	if SCENE != null:
		var src := SCENE.get_size()
		# The vivid red / gold / blue lives in the top third. Map that
		# belt onto the whole screen so extra height stays two-tone.
		draw_texture_rect_region(
			SCENE,
			Rect2(0.0, 0.0, size.x, size.y),
			Rect2(0.0, 0.0, src.x, src.y * 0.30)
		)
	# Corner tints keep red/blue alive at the tab without a centre oval.
	draw_circle(Vector2(-size.x * 0.12, size.y * 0.94), size.x * 0.52, Color(0.50, 0.06, 0.10, 0.14))
	draw_circle(Vector2(size.x * 1.12, size.y * 0.94), size.x * 0.52, Color(0.06, 0.16, 0.55, 0.16))
