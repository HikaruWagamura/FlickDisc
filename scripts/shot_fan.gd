extends Control

## Premium strike fan. Centre gold is the line you placed. Pink is a push.
## The edges are a miss. The needle and the bar under it read the pull.

var _anchor := Vector2(270, 480)
var _power := 0.0
var _needle := 0.0
var _show := false
var _facing := -PI * 0.5
var _line_a := Vector2.ZERO
var _line_b := Vector2.ZERO
var _show_line := false
var _disc := Vector2.ZERO
var _show_disc := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3


func present(anchor: Vector2, power: float, needle: float, showing: bool, facing: float = -PI * 0.5) -> void:
	_anchor = anchor
	_power = clampf(power, 0.0, 1.0)
	_needle = clampf(needle, -1.0, 1.0)
	_show = showing
	_facing = facing
	queue_redraw()


func set_line(a: Vector2, b: Vector2, showing: bool) -> void:
	_line_a = a
	_line_b = b
	_show_line = showing
	queue_redraw()


func set_disc(at: Vector2, showing: bool) -> void:
	_disc = at
	_show_disc = showing
	queue_redraw()


func _draw() -> void:
	if _show_line and _line_a.distance_to(_line_b) > 4.0:
		_draw_line()
	if _show_disc:
		_draw_disc_ring()
	if _show:
		_draw_fan()


func _draw_line() -> void:
	draw_line(_line_a, _line_b, Color(1.0, 0.18, 0.48, 0.28), 10.0, true)
	draw_line(_line_a, _line_b, Color(1.0, 0.82, 0.42, 0.95), 2.0, true)
	draw_circle(_line_a, 5.0, Color(1.0, 0.84, 0.46, 0.95))
	draw_circle(_line_b, 5.0, Color(1.0, 0.84, 0.46, 0.95))
	var mid := (_line_a + _line_b) * 0.5
	draw_circle(mid, 3.0, Color(1.0, 0.95, 0.86, 0.9))


func _draw_disc_ring() -> void:
	draw_arc(_disc, 34.0, 0.0, TAU, 40, Color(1.0, 0.35, 0.62, 0.45), 3.0, true)
	draw_arc(_disc, 40.0, 0.0, TAU, 40, Color(1.0, 0.82, 0.42, 0.7), 1.5, true)


func _draw_fan() -> void:
	var origin := _anchor + Vector2(cos(_facing), sin(_facing)) * -150.0
	origin.x = clampf(origin.x, 108.0, 432.0)
	origin.y = clampf(origin.y, 188.0, 560.0)
	var radius := 128.0
	var spread := 0.78
	_plate(origin, radius + 16.0, spread + 0.1)
	_band(origin, radius, radius * 0.22, spread, Color(0.36, 0.03, 0.14, 0.94))
	_band(origin, radius - 2.0, radius * 0.22, spread * 0.58, Color(1.0, 0.24, 0.55, 0.97))
	_band(origin, radius - 2.0, radius * 0.22, spread * 0.16, Color(0.99, 0.8, 0.34, 0.99))
	var centre_tip := origin + Vector2(cos(_facing), sin(_facing)) * (radius - 8.0)
	var centre_root := origin + Vector2(cos(_facing), sin(_facing)) * (radius * 0.28)
	draw_line(centre_root, centre_tip, Color(1, 1, 1, 0.9), 2.0, true)
	var nang := _facing + _needle * spread
	var tip := origin + Vector2(cos(nang), sin(nang)) * (radius - 8.0)
	var root := origin + Vector2(cos(nang), sin(nang)) * 10.0
	draw_line(root, tip, Color(1.0, 0.72, 0.84, 0.4), 11.0, true)
	draw_line(root, tip, Color(1.0, 0.97, 0.9, 1.0), 3.0, true)
	draw_circle(tip, 7.0, Color(1.0, 0.96, 0.9, 1.0))
	draw_circle(origin, 6.0, Color(1.0, 0.84, 0.4, 1.0))
	var bar := Rect2(origin.x - 74.0, origin.y + 22.0, 148.0, 10.0)
	draw_rect(Rect2(bar.position.x - 2.0, bar.position.y - 2.0, bar.size.x + 4.0, bar.size.y + 4.0), Color(0.05, 0.03, 0.05, 0.88), true)
	draw_rect(bar, Color(0.1, 0.05, 0.08, 1.0), true)
	if _power > 0.01:
		draw_rect(Rect2(bar.position.x, bar.position.y, bar.size.x * _power, bar.size.y), Color(1.0, 0.28, 0.58, 1.0), true)
		draw_rect(Rect2(bar.position.x + bar.size.x * _power - 3.0, bar.position.y - 2.0, 6.0, bar.size.y + 4.0), Color(1.0, 0.86, 0.46, 1.0), true)


func _plate(origin: Vector2, radius: float, half: float) -> void:
	var pts := PackedVector2Array()
	pts.append(origin)
	for i in 20:
		var t := float(i) / 19.0
		var ang := _facing + lerpf(-half, half, t)
		pts.append(origin + Vector2(cos(ang), sin(ang)) * radius)
	draw_colored_polygon(pts, Color(0.04, 0.02, 0.05, 0.78))


func _band(origin: Vector2, outer: float, inner: float, half: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 18
	for i in steps + 1:
		var t := float(i) / float(steps)
		var ang := _facing + lerpf(-half, half, t)
		pts.append(origin + Vector2(cos(ang), sin(ang)) * outer)
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		var ang := _facing + lerpf(-half, half, t)
		pts.append(origin + Vector2(cos(ang), sin(ang)) * inner)
	draw_colored_polygon(pts, color)
