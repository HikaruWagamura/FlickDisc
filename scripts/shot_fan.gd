extends Control

## The strike dial sits ahead of the puck. The green line is the release.

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
var _dots := PackedVector2Array()
var _show_dots := false
var _lift := 150.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3


func present(anchor: Vector2, power: float, needle: float, showing: bool, facing: float = -PI * 0.5, lift: float = 150.0) -> void:
	_anchor = anchor
	_power = clampf(power, 0.0, 1.0)
	_needle = clampf(needle, -1.0, 1.0)
	_show = showing
	_facing = facing
	_lift = clampf(lift, 90.0, 280.0)
	queue_redraw()


static func project_dots(camera: Camera3D, origin: Vector3, path: PackedVector3Array, skip_distance: float, avoid: Vector2 = Vector2(-1.0, -1.0), avoid_radius: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	if camera == null or path.size() < 2:
		return out
	var lengths: Array[float] = [0.0]
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
		lengths.append(total)
	if total < 0.2:
		return out
	var previous := Vector2(-999.0, -999.0)
	for step in 36:
		var distance := total * (float(step) + 0.5) / 36.0
		if distance < skip_distance:
			continue
		var point := _point_at(path, lengths, distance)
		if camera.is_position_behind(point):
			continue
		var screen := camera.unproject_position(point)
		if screen.y < 148.0 or screen.y > 900.0 or screen.x < 16.0 or screen.x > 524.0:
			continue
		if avoid_radius > 0.0 and screen.distance_to(avoid) < avoid_radius:
			continue
		if previous.distance_to(screen) < 22.0:
			continue
		out.append(screen)
		previous = screen
		if out.size() >= 14:
			break
	return out


static func _point_at(path: PackedVector3Array, lengths: Array[float], distance: float) -> Vector3:
	for index in range(1, path.size()):
		if lengths[index] < distance:
			continue
		var span := lengths[index] - lengths[index - 1]
		var t := 0.0 if span < 0.0001 else (distance - lengths[index - 1]) / span
		return path[index - 1].lerp(path[index], t)
	return path[path.size() - 1]


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


func set_dots(points: PackedVector2Array, showing: bool) -> void:
	_dots = points
	_show_dots = showing and points.size() > 1
	queue_redraw()


func _draw() -> void:
	if _show_dots:
		_draw_dots()
	if _show_line and _line_a.distance_to(_line_b) > 4.0:
		_draw_line()
	if _show_aim:
		_draw_aim()
	if _show_disc:
		_draw_disc_ring()
	if _show:
		_draw_cursor()


func _draw_dots() -> void:
	var last := _dots.size() - 1
	for i in _dots.size():
		var spot := _dots[i]
		var along := float(i) / float(maxi(last, 1))
		var near := clampf((spot.y - 160.0) / 620.0, 0.0, 1.0)
		var radius := lerpf(5.0, 8.2, near) * lerpf(1.0, 0.82, along)
		draw_circle(spot, radius + 2.6, Color(0.05, 0.07, 0.08, 0.88))
		draw_circle(spot, radius, Color(0.98, 0.99, 1.0, 0.98))


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
	# The arc sits up the green so the puck itself stays free to pull.
	var aim_dir := Vector2(cos(_facing), sin(_facing))
	var origin := _anchor + aim_dir * _lift
	origin.x = clampf(origin.x, 70.0, 470.0)
	origin.y = clampf(origin.y, 150.0, 780.0)
	var radius := 92.0
	var spread := 0.72
	draw_circle(origin, 28.0, Color(0.04, 0.05, 0.06, 0.82))
	draw_arc(origin, 28.0, 0.0, TAU, 40, Color(0.78, 0.64, 0.32, 0.85), 1.4, true)
	_plate(origin, radius + 8.0, spread + 0.08, Color(0.03, 0.04, 0.05, 0.42))
	_band(origin, radius + 1.0, radius * 0.56, spread, Color(0.07, 0.09, 0.08, 0.94))
	draw_arc(origin, radius + 3.0, _facing - spread, _facing + spread, 36, Color(0.86, 0.72, 0.38, 0.7), 1.6, true)
	if _power > 0.015:
		_span(origin, radius, radius * 0.56, -spread, lerpf(-spread, spread, _power), Color(0.95, 0.38, 0.58, 0.92))
	var green_dir := Vector2(cos(_facing), sin(_facing))
	var green_near := origin + green_dir * (radius * 0.5)
	var green_far := origin + green_dir * (radius + 8.0)
	draw_line(green_near, green_far, Color(0.12, 0.38, 0.22, 0.95), 9.0, true)
	draw_line(green_near, green_far, Color(0.55, 1.0, 0.72, 1.0), 3.2, true)
	var nang := _facing + _needle * spread
	var needle_dir := Vector2(cos(nang), sin(nang))
	var tip := origin + needle_dir * (radius - 2.0)
	var root := origin + needle_dir * (radius * 0.48)
	draw_line(root, tip, Color(0.1, 0.1, 0.1, 0.45), 5.0, true)
	draw_line(root, tip, Color(1.0, 0.98, 0.94, 1.0), 2.6, true)
	draw_circle(tip, 6.0, Color(0.08, 0.1, 0.09, 0.9))
	draw_circle(tip, 3.4, Color(0.55, 1.0, 0.72, 1.0))
	var font := ThemeDB.fallback_font
	if font != null:
		var label := "%d" % roundi(_power * 100.0)
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, origin + Vector2(-width * 0.5, 7.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 1.0, 0.94))


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
