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
	# Stretch the two-tone wash to the real phone, including the strip
	# behind and below the tab, so the foot is never a black slab.
	var src := SCENE.get_size()
	if src.x < 2.0 or src.y < 2.0:
		return
	draw_texture_rect(SCENE, Rect2(Vector2.ZERO, size), false)
