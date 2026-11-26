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
var _finger := Vector2.ZERO
var _show_finger := false
var _bowl := Vector2.ZERO
var _bowl_r := 0.0
var _half := PackedFloat32Array()
var _left := PackedVector2Array()
var _right := PackedVector2Array()
var _lift := 150.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3


func _process(_delta: float) -> void:
	if _show_dots:
		queue_redraw()


func present(anchor: Vector2, power: float, needle: float, showing: bool, facing: float = -PI * 0.5, lift: float = 150.0) -> void:
	_anchor = anchor
	_power = clampf(power, 0.0, 1.0)
	_needle = clampf(needle, -1.0, 1.0)
	_show = showing
	_facing = facing
	_lift = clampf(lift, 90.0, 280.0)
	queue_redraw()


static func project_cue(camera: Camera3D, world: PackedVector3Array, root_half: float, tip_half: float, avoid: Vector2 = Vector2(-1.0, -1.0), avoid_r: float = 0.0) -> Dictionary:
	var pts := PackedVector2Array()
	var half := PackedFloat32Array()
	var lefts := PackedVector2Array()
	var rights := PackedVector2Array()
	if camera == null or world.size() < 2:
		return {"pts": pts, "half": half, "left": lefts, "right": rights}
	for index in world.size():
		var point: Vector3 = world[index]
		if camera.is_position_behind(point):
			continue
		var tangent := Vector3(0.0, 0.0, -1.0)
		if index + 1 < world.size():
			tangent = world[index + 1] - point
		elif index > 0:
			tangent = point - world[index - 1]
		tangent.y = 0.0
		if tangent.length() < 0.001:
			continue
		tangent = tangent.normalized()
		var side := Vector3(-tangent.z, 0.0, tangent.x)
		var t := float(index) / float(maxi(world.size() - 1, 1))
		var width := lerpf(root_half, tip_half, t)
		var screen := camera.unproject_position(point)
		if screen.y < 118.0 or screen.y > 900.0 or screen.x < 8.0 or screen.x > 500.0:
			continue
		if avoid_r > 4.0 and screen.distance_to(avoid) < avoid_r * 1.04:
			continue
		var left := camera.unproject_position(point + side * width)
		var right := camera.unproject_position(point - side * width)
		pts.append(screen)
		lefts.append(left)
		rights.append(right)
		half.append(maxf(left.distance_to(right) * 0.5, 3.0))
	return {"pts": pts, "half": half, "left": lefts, "right": rights}


static func project_aim(camera: Camera3D, nose: Vector3, path: PackedVector3Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if camera == null:
		return out
	if not camera.is_position_behind(nose):
		out.append(camera.unproject_position(nose))
	if path.size() < 2:
		return out
	var lengths: Array[float] = [0.0]
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
		lengths.append(total)
	if total < 0.15:
		return out
	var previous := out[0] if not out.is_empty() else Vector2(-999.0, -999.0)
	for step in 56:
		var distance := total * (float(step) + 1.0) / 56.0
		if distance < 0.22:
			continue
		var point := _point_at(path, lengths, distance)
		if camera.is_position_behind(point):
			continue
		var screen := camera.unproject_position(point)
		if screen.y < 110.0 or screen.y > 940.0 or screen.x < -40.0 or screen.x > 580.0:
			continue
		if previous.distance_to(screen) < 7.0:
			continue
		out.append(screen)
		previous = screen
	return out


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


func set_finger(at: Vector2, showing: bool) -> void:
	_finger = at
	_show_finger = showing
	queue_redraw()


func set_disc(at: Vector2, showing: bool) -> void:
	_disc = at
	_show_disc = showing
	queue_redraw()


func set_bowl(centre: Vector2, radius: float) -> void:
	_bowl = centre
	_bowl_r = radius


func set_aim(from: Vector2, to: Vector2, showing: bool) -> void:
	_aim_from = from
	_aim_to = to
	_show_aim = showing
	queue_redraw()


func set_dots(points: PackedVector2Array, showing: bool) -> void:
	_dots = points
	_half = PackedFloat32Array()
	_left = PackedVector2Array()
	_right = PackedVector2Array()
	_show_dots = showing and points.size() > 1
	queue_redraw()


func set_cue(points: PackedVector2Array, half: PackedFloat32Array, showing: bool, lefts: PackedVector2Array = PackedVector2Array(), rights: PackedVector2Array = PackedVector2Array()) -> void:
	_dots = points
	_half = half
	_left = lefts
	_right = rights
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
	if _show_finger:
		_draw_finger()
	if _show:
		_draw_cursor()


func _draw_dots() -> void:
	var pts := _dots
	var half := _half
	if pts.size() < 2:
		return
	if half.size() != pts.size():
		pts = _even_points(_aim_span(_dots), 5.5)
		if pts.size() < 2:
			return
		half = PackedFloat32Array()
		var power_w := clampf(_power, 0.0, 1.0)
		for index in pts.size():
			var t := float(index) / float(pts.size() - 1)
			half.append(lerpf(lerpf(5.0, 10.0, power_w), lerpf(12.0, 28.0, power_w), t))
	var time := Time.get_ticks_msec() * 0.001
	var power := clampf(_power, 0.0, 1.0)
	if power > 0.78:
		var amp := (power - 0.78) * 5.5
		var shake := sin(time * 42.0) * amp
		var shaken := PackedVector2Array()
		for index in pts.size():
			var dir := _point_dir(pts, index)
			var side := Vector2(-dir.y, dir.x)
			shaken.append(pts[index] + side * shake)
		pts = shaken
	_strip(pts, half, 2.35, 0.20, time, true)
	_strip(pts, half, 1.0, 0.96, time, false)
	_flow_chevrons_half(pts, half, power, time)
	_arrow_head_half(pts, half, power, time)


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
	draw_line(_aim_from, tip, Color(0.96, 0.86, 0.55, 0.35), 10.0, true)
	draw_line(_aim_from, tip, Color(1.0, 0.97, 0.88, 0.98), 3.0, true)
	draw_circle(_aim_to, 11.0, Color(0.98, 0.94, 0.84, 0.95))
	draw_circle(_aim_to, 5.0, Color(0.16, 0.28, 0.18, 0.95))
	var side := Vector2(-dir.y, dir.x)
	var head := PackedVector2Array([
		tip,
		tip - dir * 16.0 + side * 8.0,
		tip - dir * 16.0 - side * 8.0,
	])
	draw_colored_polygon(head, Color(1.0, 0.96, 0.88, 1.0))


func _draw_disc_ring() -> void:
	# A touch mark on the ball, so the finger knows where to take hold.
	draw_arc(_disc, 34.0, 0.0, TAU, 40, Color(1.0, 0.22, 0.55, 0.35), 7.0, true)
	draw_arc(_disc, 34.0, 0.0, TAU, 40, Color(1.0, 0.78, 0.9, 0.95), 2.2, true)
	draw_circle(_disc, 5.0, Color(1.0, 0.95, 0.98, 0.9))


func _draw_finger() -> void:
	draw_circle(_finger, 16.0, Color(0.08, 0.02, 0.08, 0.35))
	draw_arc(_finger, 13.0, 0.0, TAU, 32, Color(0.36, 1.0, 0.95, 0.95), 2.4, true)
	draw_circle(_finger, 4.0, Color(1.0, 0.95, 0.98, 0.95))


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


func _aim_span(source: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if source.is_empty():
		return out
	var nose := source[0]
	out.append(nose)
	var aim := Vector2(0.0, -1.0)
	if source.size() > 1:
		var furthest := source[0]
		for point in source:
			if point.y < furthest.y:
				furthest = point
		if furthest.distance_to(nose) > 8.0:
			aim = (furthest - nose).normalized()
	for index in range(1, source.size()):
		var point := source[index]
		if (point - nose).dot(aim) < 6.0:
			continue
		if point.x < 18.0 or point.x > 522.0 or point.y < 150.0 or point.y > 880.0:
			break
		out.append(point)
	var power := clampf(_power, 0.0, 1.0)
	var want := lerpf(156.0, 390.0, power)
	if _bowl_r > 12.0:
		var rim := _bowl + aim * (_bowl_r * 1.08)
		var cleared := PackedVector2Array()
		cleared.append(rim)
		for point in out:
			if (point - rim).dot(aim) > 5.0:
				cleared.append(point)
		out = cleared
	var length := 0.0
	for index in range(1, out.size()):
		length += out[index - 1].distance_to(out[index])
	var dir := aim
	if out.size() >= 2:
		dir = (out[out.size() - 1] - out[out.size() - 2]).normalized()
	var guard := 0
	while length < want and guard < 48:
		var next := out[out.size() - 1] + dir * 8.0
		if next.y < 156.0 or next.x < 28.0 or next.x > 512.0:
			break
		out.append(next)
		length += 8.0
		guard += 1
	return out


func _even_points(source: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if source.is_empty():
		return out
	out.append(source[0])
	var carry := 0.0
	for index in range(1, source.size()):
		var a := source[index - 1]
		var b := source[index]
		var span := a.distance_to(b)
		if span < 0.5:
			continue
		var dir := (b - a) / span
		var walked := spacing - carry
		while walked <= span:
			out.append(a + dir * walked)
			walked += spacing
		carry = span - (walked - spacing)
	if out[out.size() - 1].distance_to(source[source.size() - 1]) > 3.0:
		out.append(source[source.size() - 1])
	return out


func _heat(along: float, alpha: float) -> Color:
	var cyan := Color(0.28, 1.0, 0.98)
	var violet := Color(0.72, 0.28, 1.0)
	var red := Color(1.0, 0.08, 0.12)
	var power := clampf(_power, 0.0, 1.0)
	var color := cyan.lerp(violet, smoothstep(0.0, lerpf(0.72, 0.32, power), along))
	color = color.lerp(red, smoothstep(lerpf(0.88, 0.22, power), 1.0, along) * lerpf(0.18, 1.0, power))
	color.a = alpha
	return color


func _strip(pts: PackedVector2Array, half: PackedFloat32Array, scale: float, alpha: float, time: float, glow: bool) -> void:
	var use_edges := _left.size() == pts.size() and _right.size() == pts.size()
	for index in range(pts.size() - 1):
		var t := float(index) / float(pts.size() - 1)
		var pulse := 0.94 + 0.06 * sin(t * 10.0 - time * 7.0)
		var color := _heat(t, alpha)
		if not glow:
			var shine := smoothstep(0.78, 1.0, sin((t * 2.8 - time * 1.6) * TAU) * 0.5 + 0.5)
			color = color.lerp(Color(1.0, 0.97, 0.94, alpha), shine * 0.48)
		if use_edges:
			var a := pts[index]
			var b := pts[index + 1]
			var l0: Vector2 = a + (_left[index] - a) * scale * pulse
			var r0: Vector2 = a + (_right[index] - a) * scale * pulse
			var l1: Vector2 = b + (_left[index + 1] - b) * scale * pulse
			var r1: Vector2 = b + (_right[index + 1] - b) * scale * pulse
			draw_colored_polygon(PackedVector2Array([l0, l1, r1, r0]), color)
			continue
		var dir := pts[index + 1] - pts[index]
		if dir.length() < 0.4:
			continue
		dir = dir.normalized()
		var side := Vector2(-dir.y, dir.x)
		var w0 := half[index] * scale * pulse
		var w1 := half[mini(index + 1, half.size() - 1)] * scale * pulse
		draw_colored_polygon(PackedVector2Array([
			pts[index] + side * w0,
			pts[index + 1] + side * w1,
			pts[index + 1] - side * w1,
			pts[index] - side * w0,
		]), color)


func _flow_chevrons_half(pts: PackedVector2Array, half: PackedFloat32Array, power: float, time: float) -> void:
	var travel := fposmod(time * lerpf(0.55, 1.15, power), 1.0)
	for mark in 5:
		var t := fposmod(travel + float(mark) / 5.0, 1.0)
		if t < 0.08 or t > 0.86:
			continue
		var at := _sample(pts, t)
		var dir := _sample_dir(pts, t)
		var side := Vector2(-dir.y, dir.x)
		var width := _sample_half(half, t) * 0.82
		var reach := lerpf(8.0, 16.0, power)
		var tail := at - dir * reach
		var color := _heat(t, 0.96).lerp(Color(1.0, 0.98, 0.96), 0.4)
		draw_line(tail + side * width, at, color, 2.8, true)
		draw_line(tail - side * width, at, color, 2.8, true)


func _arrow_head_half(pts: PackedVector2Array, half: PackedFloat32Array, power: float, time: float) -> void:
	var tip := pts[pts.size() - 1]
	var dir := (tip - pts[pts.size() - 2]).normalized()
	var side := Vector2(-dir.y, dir.x)
	var width := half[half.size() - 1] * lerpf(1.15, 1.45, power)
	var length := lerpf(14.0, 34.0, power)
	var beat := 0.94 + 0.06 * sin(time * 11.0)
	draw_colored_polygon(PackedVector2Array([
		tip + dir * 4.0 * beat,
		tip - dir * length + side * width * 1.2,
		tip - dir * length - side * width * 1.2,
	]), _heat(1.0, 0.32))
	draw_colored_polygon(PackedVector2Array([
		tip,
		tip - dir * length * 0.88 + side * width,
		tip - dir * length * 0.88 - side * width,
	]), _heat(0.98, 1.0))
	draw_colored_polygon(PackedVector2Array([
		tip + dir * 2.0,
		tip + side * width * 0.22,
		tip - side * width * 0.22,
	]), Color(1.0, 0.96, 0.92, 0.9))


func _sample_half(half: PackedFloat32Array, t: float) -> float:
	if half.is_empty():
		return 8.0
	var index := clampi(int(t * float(half.size() - 1)), 0, half.size() - 2)
	var local := t * float(half.size() - 1) - float(index)
	return lerpf(half[index], half[index + 1], local)


func _point_dir(pts: PackedVector2Array, index: int) -> Vector2:
	if pts.size() < 2:
		return Vector2(0.0, -1.0)
	if index >= pts.size() - 1:
		return (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	var dir := pts[index + 1] - pts[index]
	if dir.length() < 0.001:
		return Vector2(0.0, -1.0)
	return dir.normalized()


func _ribbon(pts: PackedVector2Array, root_w: float, tip_w: float, alpha: float, time: float, glow: bool) -> void:
	for index in range(pts.size() - 1):
		var t := float(index) / float(pts.size() - 1)
		var nxt := float(index + 1) / float(pts.size() - 1)
		var dir := pts[index + 1] - pts[index]
		if dir.length() < 0.4:
			continue
		dir = dir.normalized()
		var side := Vector2(-dir.y, dir.x)
		var pulse := 0.92 + 0.08 * sin(t * 12.0 - time * 8.0)
		var w0 := lerpf(root_w, tip_w, t) * pulse
		var w1 := lerpf(root_w, tip_w, nxt) * pulse
		w0 *= lerpf(1.0, 0.62, smoothstep(0.78, 1.0, t))
		w1 *= lerpf(1.0, 0.62, smoothstep(0.78, 1.0, nxt))
		var quad := PackedVector2Array([
			pts[index] + side * w0,
			pts[index + 1] + side * w1,
			pts[index + 1] - side * w1,
			pts[index] - side * w0,
		])
		var color := _heat(t, alpha)
		if not glow:
			var shine := smoothstep(0.82, 1.0, sin((t * 3.2 - time * 1.4) * TAU) * 0.5 + 0.5)
			color = color.lerp(Color(1.0, 0.96, 0.9, alpha), shine * 0.55)
		draw_colored_polygon(quad, color)


func _flow_chevrons(pts: PackedVector2Array, root_w: float, tip_w: float, power: float, time: float) -> void:
	var travel := fposmod(time * 0.92, 1.0)
	for mark in 6:
		var t := fposmod(travel + float(mark) / 6.0, 1.0)
		if t < 0.06 or t > 0.84:
			continue
		var at := _sample(pts, t)
		var dir := _sample_dir(pts, t)
		var side := Vector2(-dir.y, dir.x)
		var width := lerpf(root_w, tip_w, t) * 0.78
		var reach := lerpf(9.0, 18.0, power)
		var tail := at - dir * reach
		var color := _heat(t, 0.95).lerp(Color(1.0, 0.97, 0.94), 0.35)
		draw_line(tail + side * width, at, color, 2.6, true)
		draw_line(tail - side * width, at, color, 2.6, true)


func _arrow_head(pts: PackedVector2Array, power: float, time: float) -> void:
	var tip := pts[pts.size() - 1]
	var dir := (tip - pts[pts.size() - 2]).normalized()
	var side := Vector2(-dir.y, dir.x)
	var length := lerpf(22.0, 54.0, power)
	var width := lerpf(16.0, 58.0, power)
	var beat := 0.94 + 0.06 * sin(time * 9.0)
	var head_tip := tip
	if head_tip.y - length < 150.0:
		head_tip.y = 150.0 + length
	draw_colored_polygon(PackedVector2Array([
		head_tip + dir * length * 0.15 * beat,
		head_tip - dir * length + side * width * 1.15,
		head_tip - dir * length - side * width * 1.15,
	]), _heat(1.0, 0.34))
	draw_colored_polygon(PackedVector2Array([
		head_tip,
		head_tip - dir * length * 0.92 + side * width,
		head_tip - dir * length * 0.92 - side * width,
	]), _heat(0.98, 1.0))
	draw_colored_polygon(PackedVector2Array([
		tip + dir * length * 0.48,
		tip + side * width * 0.22,
		tip - side * width * 0.22,
	]), Color(1.0, 0.94, 0.9, 0.92))


func _sample(pts: PackedVector2Array, t: float) -> Vector2:
	var index := clampi(int(t * float(pts.size() - 1)), 0, pts.size() - 2)
	var local := t * float(pts.size() - 1) - float(index)
	return pts[index].lerp(pts[index + 1], local)


func _sample_dir(pts: PackedVector2Array, t: float) -> Vector2:
	var index := clampi(int(t * float(pts.size() - 1)), 0, pts.size() - 2)
	var dir := pts[index + 1] - pts[index]
	if dir.length() < 0.001:
		return Vector2(0.0, -1.0)
	return dir.normalized()
