extends MeshInstance3D

## A short ribbon on the grass. The bowl hides the start.
## Slim at the lip, thicker toward the end, then a point.

const FLOOR_Y := 0.07
const NOSE_Y := 0.12

var _mesh := ImmediateMesh.new()
var _showing := false


func _ready() -> void:
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 12.0
	sorting_offset = 4.0
	position = Vector3.ZERO
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.render_priority = 16
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	material_override = mat


func clear() -> void:
	if _showing:
		_mesh.clear_surfaces()
		_showing = false
	visible = false


func present(path: PackedVector3Array, power: float) -> void:
	if path.size() < 2:
		clear()
		return
	visible = true
	global_transform = Transform3D.IDENTITY
	if _showing:
		_mesh.clear_surfaces()
	_showing = true
	var amount := clampf(power, 0.0, 1.0)
	var time := Time.get_ticks_msec() * 0.001
	var shake := 0.0
	if amount > 0.78:
		shake = sin(time * 36.0) * (amount - 0.78) * 0.016
	var root := lerpf(0.032, 0.046, amount)
	var tip := lerpf(0.070, 0.108, amount)
	var head_len := lerpf(0.30, 0.44, amount)
	var cut := _cut(path, head_len)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_ribbon(path, root, tip, cut, amount, shake, 0.22, time, 1.42)
	_ribbon(path, root, tip, cut, amount, shake, 0.96, time, 1.0)
	_chevrons(path, root, tip, cut, amount, time)
	_head(path, _span(cut, cut, root, tip), head_len, amount, time)
	_mesh.surface_end()


func _ribbon(path: PackedVector3Array, root: float, tip: float, cut: float, power: float, shake: float, alpha: float, time: float, scale: float) -> void:
	var last := path.size() - 1
	for index in range(last):
		var t0 := float(index) / float(last)
		var t1 := float(index + 1) / float(last)
		if t0 >= cut:
			break
		var a_pt := path[index]
		var b_pt := path[index + 1]
		var b_t := t1
		if t1 > cut:
			b_pt = _raw_sample(path, cut)
			b_t = cut
		var a := _flat(a_pt, _side_at(path, t0), _span(t0, cut, root, tip) * scale, shake)
		var b := _flat(b_pt, _side_at(path, b_t), _span(b_t, cut, root, tip) * scale, shake)
		_quad(a["l"], b["l"], b["r"], a["r"], _heat(t0, power, alpha, time))


func _chevrons(path: PackedVector3Array, root: float, tip: float, cut: float, power: float, time: float) -> void:
	var travel := fposmod(time * lerpf(0.4, 0.9, power), 1.0)
	for mark in 3:
		var t := fposmod(travel + float(mark) / 3.0, 1.0)
		if t < 0.16 or t > cut * 0.88:
			continue
		var at := _sample(path, t)
		var dir := _tangent(path, t)
		var side := Vector3(-dir.z, 0.0, dir.x)
		var width := _span(t, cut, root, tip) * 0.92
		var reach := lerpf(0.12, 0.20, power)
		var nose := at + dir * reach * 0.34
		nose.y = FLOOR_Y + 0.012
		var left := at - dir * reach + side * width
		var right := at - dir * reach - side * width
		var color := _heat(t, power, 0.96, time).lerp(Color(1.0, 0.96, 0.9, 0.96), 0.32)
		_tri(left, nose, at + side * width * 0.16, color)
		_tri(right, at - side * width * 0.16, nose, color)


func _head(path: PackedVector3Array, tip: float, length: float, power: float, time: float) -> void:
	var last := path.size() - 1
	var at := _flat_point(path[last])
	var dir := _tangent(path, 1.0)
	var side := Vector3(-dir.z, 0.0, dir.x)
	var beat := 0.96 + 0.04 * sin(time * 10.0)
	var shoulder := tip * lerpf(1.58, 1.88, power)
	var nose := at + dir * (length * 0.38 * beat)
	nose.y = NOSE_Y
	var left := at - dir * (length * 0.70) + side * shoulder
	var right := at - dir * (length * 0.70) - side * shoulder
	left.y = FLOOR_Y
	right.y = FLOOR_Y
	var glow_l := left + side * (shoulder * 0.12) - dir * (length * 0.06)
	var glow_r := right - side * (shoulder * 0.12) - dir * (length * 0.06)
	var glow_n := nose + dir * 0.04
	glow_n.y = NOSE_Y + 0.01
	_tri(glow_l, glow_n, glow_r, _heat(1.0, power, 0.28, time))
	_tri(left, nose, right, _heat(0.98, power, 1.0, time))
	var inner := tip * 0.42
	var neck := at - dir * (length * 0.10)
	neck.y = FLOOR_Y + 0.02
	_tri(neck + side * inner, nose, neck - side * inner, Color(1.0, 0.93, 0.82, 0.95))


func _span(t: float, cut: float, root: float, tip: float) -> float:
	var along := clampf(t / maxf(cut, 0.001), 0.0, 1.0)
	along = along * along * (1.18 - 0.18 * along)
	# Farther marks shrink on the mat camera, so the world width grows a little.
	return lerpf(root, tip, along) * lerpf(1.0, 1.32, along)


func _cut(path: PackedVector3Array, length: float) -> float:
	var total := 0.0
	for index in range(path.size() - 1):
		total += path[index].distance_to(path[index + 1])
	if total < 0.05:
		return 0.76
	return clampf(1.0 - (length * 0.74) / total, 0.60, 0.88)


func _flat(point: Vector3, side: Vector3, half: float, shake: float) -> Dictionary:
	var centre := _flat_point(point) + side * shake
	return {"l": centre + side * half, "r": centre - side * half}


func _flat_point(point: Vector3) -> Vector3:
	return Vector3(point.x, FLOOR_Y, point.z)


func _raw_sample(path: PackedVector3Array, t: float) -> Vector3:
	var last := path.size() - 1
	var index := clampi(int(t * float(last)), 0, last - 1)
	var local := t * float(last) - float(index)
	return path[index].lerp(path[index + 1], local)


func _side_at(path: PackedVector3Array, t: float) -> Vector3:
	var dir := _tangent(path, t)
	return Vector3(-dir.z, 0.0, dir.x)


func _sample(path: PackedVector3Array, t: float) -> Vector3:
	return _flat_point(_raw_sample(path, t))


func _tangent(path: PackedVector3Array, t: float) -> Vector3:
	var last := path.size() - 1
	var index := clampi(int(t * float(last)), 0, last - 1)
	var dir := path[index + 1] - path[index]
	dir.y = 0.0
	if dir.length() < 0.001:
		return Vector3(0.0, 0.0, -1.0)
	return dir.normalized()


func _heat(along: float, power: float, alpha: float, time: float) -> Color:
	var cyan := Color(0.22, 0.98, 1.0)
	var violet := Color(0.62, 0.28, 1.0)
	var red := Color(1.0, 0.32, 0.08)
	var color := cyan.lerp(violet, smoothstep(0.12, 0.52, along))
	color = color.lerp(red, smoothstep(0.52, 1.0, along) * lerpf(0.35, 1.0, power))
	if power > 0.82:
		var flash := 0.5 + 0.5 * sin(time * 22.0)
		color = color.lerp(Color(1.0, 0.45, 0.12), flash * (power - 0.82) * 1.4)
	color.a = alpha
	return color


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(a, b, c, color)
	_tri(a, c, d, color)


func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(b)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(c)
