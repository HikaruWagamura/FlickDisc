extends Control

## Club wash behind the hub. Red left, blue right, gold in the logo belt.
## The art is painted for a tall phone so extra height stays two-tone.

const SCENE := preload("res://assets/club_backdrop.png")
const DEEP := Color("#0f1a36")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var size := get_size()
	if size.x < 2.0:
		size = Vector2(540, 960)
	draw_rect(Rect2(Vector2.ZERO, size), DEEP, true)
	if SCENE == null:
		return
	# Cover the whole control. The PNG is already a full-length wash,
	# so we never leave a black foot or a letterbox.
	var src := SCENE.get_size()
	if src.x < 2.0 or src.y < 2.0:
		return
	var scale := maxf(size.x / src.x, size.y / src.y)
	var draw := src * scale
	var origin := Vector2((size.x - draw.x) * 0.5, (size.y - draw.y) * 0.5)
	draw_texture_rect(SCENE, Rect2(origin, draw), false)
