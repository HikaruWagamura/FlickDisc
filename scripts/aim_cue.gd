extends MeshInstance3D

## A short ribbon that lives on the grass. The bowl hides the start.
## From overhead it still sits on the green, along the line of the shot.

var _mesh := ImmediateMesh.new()
var _showing := false


func _ready() -> void:
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 12.0
	position = Vector3.ZERO
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
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
		shake = sin(time * 36.0) * (amount - 0.78) * 0.018
	var root := lerpf(0.04, 0.058, amount)
	var tip := lerpf(0.06, 0.09, amount)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_ribbon(path, root * 1.55, tip * 1.55, amount, shake, 0.18, time)
	_ribbon(path, root, tip, amount, shake, 0.94, time)
	_chevrons(path, root, tip, amount, time)
	_head(path, tip, amount, time)
	_mesh.surface_end()


func _ribbon(path: PackedVector3Array, root: float, tip: float, power: float, shake: float, alpha: float, time: float) -> void:
	for index in range(path.size() - 1):
		var t0 := float(index) / float(path.size() - 1)
		var t1 := float(index + 1) / float(path.size() - 1)
		var a := _flat(path[index], _side(path, index), lerpf(root, tip, t0), shake, t0)
		var b := _flat(path[index + 1], _side(path, index + 1), lerpf(root, tip, t1), shake, t1)
		var color := _heat(t0, power, alpha, time)
		_quad(a["l"], b["l"], b["r"], a["r"], color)


func _chevrons(path: PackedVector3Array, root: float, tip: float, power: float, time: float) -> void:
	var travel := fposmod(time * lerpf(0.4, 0.9, power), 1.0)
	for mark in 4:
		var t := fposmod(travel + float(mark) / 4.0, 1.0)
		if t < 0.22 or t > 0.8:
			continue
		var at := _sample(path, t)
		var dir := _tangent(path, t)
		var side := Vector3(-dir.z, 0.0, dir.x)
		var width := lerpf(root, tip, t) * 1.05
		var reach := lerpf(0.16, 0.26, power)
		var nose := at + dir * reach * 0.35
		var left := at - dir * reach + side * width
		var right := at - dir * reach - side * width
		var color := _heat(t, power, 0.96, time).lerp(Color(1.0, 0.96, 0.9, 0.96), 0.35)
		_tri(left, nose, at + side * width * 0.18, color)
		_tri(right, at - side * width * 0.18, nose, color)


func _head(path: PackedVector3Array, tip: float, power: float, time: float) -> void:
	var last := path.size() - 1
	var at := _flat_point(path[last])
	var dir := (path[last] - path[last - 1])
	dir.y = 0.0
	if dir.length() < 0.001:
		dir = Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	var length := lerpf(0.42, 0.72, power)
	var width := tip * lerpf(0.95, 1.15, power)
	var nose := at + dir * length
	var left := at + side * width
	var right := at - side * width
	_tri(left, nose, right, _heat(0.98, power, 1.0, time))


func _flat(point: Vector3, side: Vector3, half: float, shake: float, t: float) -> Dictionary:
	var centre := _flat_point(point) + side * shake
	return {"l": centre + side * half, "r": centre - side * half}


func _flat_point(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.03, point.z)


func _side(path: PackedVector3Array, index: int) -> Vector3:
	var dir := Vector3(0.0, 0.0, -1.0)
	if index + 1 < path.size():
		dir = path[index + 1] - path[index]
	elif index > 0:
		dir = path[index] - path[index - 1]
	dir.y = 0.0
	if dir.length() < 0.001:
		dir = Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()
	return Vector3(-dir.z, 0.0, dir.x)


func _sample(path: PackedVector3Array, t: float) -> Vector3:
	var index := clampi(int(t * float(path.size() - 1)), 0, path.size() - 2)
	var local := t * float(path.size() - 1) - float(index)
	return _flat_point(path[index].lerp(path[index + 1], local))


func _tangent(path: PackedVector3Array, t: float) -> Vector3:
	var index := clampi(int(t * float(path.size() - 1)), 0, path.size() - 2)
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
