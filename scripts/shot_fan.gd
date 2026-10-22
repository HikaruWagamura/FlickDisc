extends Control

## Aim arrow while the line is open. The strike dial sits on the disc
## and the number in it is the power.

var _anchor := Vector2(270, 640)
var _power := 0.0
var _needle := 0.0
var _show := false
var _facing := -PI * 0.5
var _line_a := Vector2.ZERO
var _line_b := Vector2.ZERO
var _show_line := false
var _disc := Vector2.ZERO
var _show_disc := false
var _aim_from := Vector2.ZERO
var _aim_to := Vector2.ZERO
var _show_aim := false


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


func set_aim(from: Vector2, to: Vector2, showing: bool) -> void:
	_aim_from = from
	_aim_to = to
	_show_aim = showing
	queue_redraw()


func _draw() -> void:
	if _show_line and _line_a.distance_to(_line_b) > 4.0:
		_draw_line()
	if _show_aim:
		_draw_aim()
	if _show_disc:
		_draw_disc_ring()
	if _show:
		_draw_cursor()


func _draw_line() -> void:
	draw_line(_line_a, _line_b, Color(1.0, 0.84, 0.46, 0.9), 2.0, true)
	draw_circle(_line_a, 3.5, Color(1.0, 0.84, 0.46, 0.95))
	draw_circle(_line_b, 3.5, Color(1.0, 0.84, 0.46, 0.95))


func _draw_aim() -> void:
	var delta := _aim_to - _aim_from
	var length := delta.length()
	if length < 10.0:
		return
	var dir := delta / length
	var tip := _aim_from + dir * minf(length, 168.0)
	draw_line(_aim_from, tip, Color(1.0, 0.55, 0.72, 0.35), 8.0, true)
	draw_line(_aim_from, tip, Color(1.0, 0.9, 0.55, 0.98), 3.0, true)
	var side := Vector2(-dir.y, dir.x)
	var head := PackedVector2Array([
		tip,
		tip - dir * 16.0 + side * 8.0,
		tip - dir * 16.0 - side * 8.0,
	])
	draw_colored_polygon(head, Color(1.0, 0.96, 0.88, 1.0))


func _draw_disc_ring() -> void:
	draw_arc(_disc, 22.0, 0.0, TAU, 36, Color(1.0, 0.35, 0.62, 0.55), 2.0, true)
	draw_arc(_disc, 28.0, 0.0, TAU, 36, Color(1.0, 0.86, 0.48, 0.75), 1.25, true)


func _draw_cursor() -> void:
	# Glass dial on the disc. The arc fills with power and the needle is the mark.
	var origin := _anchor
	origin.y = clampf(origin.y, 140.0, 900.0)
	var radius := 102.0
	var spread := 0.7
	draw_circle(origin, 34.0, Color(0.05, 0.03, 0.06, 0.72))
	draw_arc(origin, 34.0, 0.0, TAU, 40, Color(0.93, 0.76, 0.4, 0.95), 2.0, true)
	_plate(origin, radius + 12.0, spread + 0.12, Color(0.04, 0.02, 0.05, 0.48))
	_band(origin, radius + 2.0, radius * 0.6, spread, Color(0.10, 0.05, 0.07, 0.94))
	draw_arc(origin, radius + 3.0, _facing - spread, _facing + spread, 28, Color(0.95, 0.8, 0.42, 0.95), 2.5, true)
	if _power > 0.015:
		_span(origin, radius, radius * 0.6, -spread, lerpf(-spread, spread, _power), Color(1.0, 0.42, 0.62, 0.96))
	_span(origin, radius - 1.0, radius * 0.62, -spread * 0.12, spread * 0.12, Color(0.99, 0.84, 0.38, 1.0))
	var centre_dir := Vector2(cos(_facing), sin(_facing))
	draw_line(origin + centre_dir * (radius * 0.64), origin + centre_dir * (radius - 4.0), Color(1, 1, 1, 0.95), 2.0, true)
	var nang := _facing + _needle * spread
	var needle_dir := Vector2(cos(nang), sin(nang))
	var tip := origin + needle_dir * (radius - 4.0)
	var root := origin + needle_dir * (radius * 0.52)
	draw_line(root, tip, Color(1.0, 0.97, 0.9, 1.0), 3.5, true)
	draw_circle(tip, 6.0, Color(1.0, 0.97, 0.92, 1.0))
	draw_circle(tip, 3.0, Color(1.0, 0.45, 0.62, 1.0))
	var font := ThemeDB.fallback_font
	if font != null:
		var label := "%d" % roundi(_power * 100.0)
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, origin + Vector2(-width * 0.5, 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.95, 0.82))


func _plate(origin: Vector2, radius: float, half: float, color: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(origin)
	for i in 18:
		var t := float(i) / 17.0
		var ang := _facing + lerpf(-half, half, t)
		pts.append(origin + Vector2(cos(ang), sin(ang)) * radius)
	draw_colored_polygon(pts, color)


func _band(origin: Vector2, outer: float, inner: float, half: float, color: Color) -> void:
	_span(origin, outer, inner, -half, half, color)


func _span(origin: Vector2, outer: float, inner: float, start: float, end: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var t := float(i) / float(steps)
		var ang := _facing + lerpf(start, end, t)
		pts.append(origin + Vector2(cos(ang), sin(ang)) * outer)
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		var ang := _facing + lerpf(start, end, t)
		pts.append(origin + Vector2(cos(ang), sin(ang)) * inner)
	draw_colored_polygon(pts, color)
