class_name HandSwitch
extends Control

## Big forehand / backhand toggle. The curve on each side is the way
## that hand bends, so the player can see the shot before they pull.

signal chosen(forehand: bool)

var forehand := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func set_forehand(on: bool) -> void:
	forehand = on
	queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		var left: bool = mouse.position.x < size.x * 0.5
		if left == forehand:
			chosen.emit(not forehand)
		else:
			chosen.emit(left)
		accept_event()


func _draw() -> void:
	var mid := size.x * 0.5
	var left_box := Rect2(0.0, 0.0, mid - 3.0, size.y)
	var right_box := Rect2(mid + 3.0, 0.0, mid - 3.0, size.y)
	_plate(left_box, forehand)
	_plate(right_box, not forehand)
	_hook(left_box, true, forehand)
	_hook(right_box, false, not forehand)
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(left_box.position.x + 10.0, size.y - 10.0), "FOREHAND", HORIZONTAL_ALIGNMENT_LEFT, left_box.size.x - 16.0, 11, _ink(forehand))
		draw_string(font, Vector2(right_box.position.x + 10.0, size.y - 10.0), "BACKHAND", HORIZONTAL_ALIGNMENT_LEFT, right_box.size.x - 16.0, 11, _ink(not forehand))


func _plate(box: Rect2, on: bool) -> void:
	var fill := Color("#f3bd56") if on else Color(0.05, 0.07, 0.08, 0.82)
	var border := Color("#ffe9a4") if on else Color(0.78, 0.64, 0.34, 0.55)
	draw_rect(box, fill, true)
	draw_rect(box, border, false, 2.0)


func _ink(on: bool) -> Color:
	return Color("#1a1408") if on else Color(0.96, 0.93, 0.84, 0.92)


func _hook(box: Rect2, turns_left: bool, on: bool) -> void:
	var color := Color("#1a1408") if on else Color("#f3bd56")
	var origin := Vector2(box.position.x + box.size.x * 0.5, box.position.y + 16.0)
	var hook_sign: float = -1.0 if turns_left else 1.0
	var points := PackedVector2Array()
	for i in 10:
		var t := float(i) / 9.0
		var along := lerpf(0.0, 22.0, t)
		var sway: float = hook_sign * lerpf(0.0, 16.0, t * t)
		points.append(origin + Vector2(sway, along))
	draw_polyline(points, color, 3.4, true)
	var tip: Vector2 = points[points.size() - 1]
	var prev: Vector2 = points[points.size() - 2]
	var dir: Vector2 = (tip - prev).normalized()
	var perp := Vector2(-dir.y, dir.x)
	draw_line(tip, tip - dir * 8.0 + perp * 5.0, color, 3.2, true)
	draw_line(tip, tip - dir * 8.0 - perp * 5.0, color, 3.2, true)
