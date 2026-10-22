extends Control

## Curved arrow for the hand. Forehand bends to the player's left.

var turns_left := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_turn(left: bool) -> void:
	turns_left = left
	queue_redraw()


func _draw() -> void:
	var color := Color(0.98, 0.86, 0.42)
	var origin := Vector2(30.0, 36.0) if turns_left else Vector2(size.x - 30.0, 36.0)
	var bend := -1.0 if turns_left else 1.0
	var points := PackedVector2Array()
	for i in 8:
		var t := float(i) / 7.0
		var along := lerpf(0.0, -28.0, t)
		var side := bend * lerpf(0.0, 16.0, t * t)
		points.append(origin + Vector2(side, along))
	draw_polyline(points, color, 3.2, true)
	var tip: Vector2 = points[points.size() - 1]
	var prev: Vector2 = points[points.size() - 2]
	var dir := (tip - prev).normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_line(tip, tip - dir * 9.0 + side * 5.5, color, 3.2, true)
	draw_line(tip, tip - dir * 9.0 - side * 5.5, color, 3.2, true)
