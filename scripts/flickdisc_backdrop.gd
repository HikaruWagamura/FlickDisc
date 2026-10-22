extends Control

## Dark club backdrop: target rings, a pink glow, and paint specks.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(540, 960))
	draw_rect(rect, Color("#09080d"))
	draw_circle(Vector2(270, 250), 230, Color(1.0, 0.08, 0.32, 0.16))
	draw_circle(Vector2(270, 240), 120, Color(1.0, 0.16, 0.42, 0.10))
	var origin := Vector2(270, 220)
	for i in 8:
		var radius := 28.0 + float(i) * 32.0
		draw_arc(origin, radius, 0.0, TAU, 80, Color(1.0, 0.25, 0.55, 0.045), 1.4, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9546
	for i in 56:
		var spot := Vector2(rng.randf_range(12.0, 528.0), rng.randf_range(16.0, 860.0))
		var speck := rng.randf_range(1.2, 3.4)
		var pink := rng.randf() > 0.35
		var color := Color(1.0, 0.25, 0.58, rng.randf_range(0.18, 0.55)) if pink else Color(1, 1, 1, rng.randf_range(0.08, 0.28))
		draw_circle(spot, speck, color)
	draw_rect(Rect2(0, 900, 540, 60), Color(0, 0, 0, 0.35))
