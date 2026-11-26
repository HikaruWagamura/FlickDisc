extends MeshInstance3D

## Raised block arrow on the grass. Faceted like the rest of the rink:
## a thick shaft, a sharp chevron, real lighting, and a shadow.

const RING_COUNT := 32
const PROFILE_COUNT := 6
const SHAFT_HALF := 0.20
const HEAD_HALF := 0.36
const HEIGHT := 0.15
const BOTTOM := 0.016
const SHADER_PATH := "res://shaders/aim_guide_3d.gdshader"

var _material: ShaderMaterial
var _showing := false


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	extra_cull_margin = 10.0
	sorting_offset = 0.0
	position = Vector3.ZERO
	var shader := load(SHADER_PATH) as Shader
	if shader == null:
		push_error("Aim cue shader missing: %s" % SHADER_PATH)
		return
	_material = ShaderMaterial.new()
	_material.shader = shader
	material_override = _material


func clear() -> void:
	if _showing:
		mesh = null
		_showing = false
	visible = false


func present(path: PackedVector3Array, power: float) -> void:
	if path.size() < 2:
		clear()
		return
	visible = true
	global_transform = Transform3D.IDENTITY
	var amount := clampf(power, 0.0, 1.0)
	if _material != null:
		_material.set_shader_parameter("power", amount)
		_material.set_shader_parameter("glow_enabled", true)
	_rebuild(path, amount)
	_showing = true


func _rebuild(path: PackedVector3Array, amount: float) -> void:
	var width_scale := lerpf(0.98, 1.05, amount)
	var height_scale := lerpf(0.96, 1.08, amount)
	var shake := 0.0
	if amount > 0.84:
		shake = sin(Time.get_ticks_msec() * 0.028) * (amount - 0.84) * 0.004
	var rings: Array[PackedVector3Array] = []
	var ring_uvs: Array[PackedVector2Array] = []
	for ring in range(RING_COUNT + 1):
		var t := float(ring) / float(RING_COUNT)
		var centre := _centre(path, t, shake)
		var tangent := _tangent(path, t)
		var side := tangent.cross(Vector3.UP)
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT
		else:
			side = side.normalized()
		var half_w := _half_width(t) * width_scale
		var height := HEIGHT * height_scale
		rings.append(_ring(centre, side, half_w, height))
		ring_uvs.append(_ring_uvs(t))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(RING_COUNT):
		var a: PackedVector3Array = rings[ring]
		var b: PackedVector3Array = rings[ring + 1]
		var ua: PackedVector2Array = ring_uvs[ring]
		var ub: PackedVector2Array = ring_uvs[ring + 1]
		for i in PROFILE_COUNT:
			var n := (i + 1) % PROFILE_COUNT
			_quad(tool, a[i], a[n], b[n], b[i], ua[i], ua[n], ub[n], ub[i])
	_cap(tool, rings[0], ring_uvs[0], true)
	_cap(tool, rings[RING_COUNT], ring_uvs[RING_COUNT], false)
	tool.generate_normals()
	mesh = tool.commit()
	if _material != null:
		material_override = _material


func _ring(centre: Vector3, side: Vector3, half_w: float, height: float) -> PackedVector3Array:
	var bevel := half_w * 0.10
	var top := height
	var wall := height * 0.92
	var pts := PackedVector2Array()
	pts.append(Vector2(-half_w, BOTTOM))
	pts.append(Vector2(-half_w, wall))
	pts.append(Vector2(-half_w + bevel, top))
	pts.append(Vector2(half_w - bevel, top))
	pts.append(Vector2(half_w, wall))
	pts.append(Vector2(half_w, BOTTOM))
	var out := PackedVector3Array()
	for p in pts:
		out.append(centre + side * p.x + Vector3.UP * p.y)
	return out


func _ring_uvs(t: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in PROFILE_COUNT:
		out.append(Vector2(float(i) / float(PROFILE_COUNT - 1), t))
	return out


func _half_width(t: float) -> float:
	# Shaft sits at the bowl. The chevron is the part you see on the grass.
	if t < 0.50:
		return SHAFT_HALF
	if t < 0.62:
		return lerpf(SHAFT_HALF, HEAD_HALF, smoothstep(0.50, 0.62, t))
	return lerpf(HEAD_HALF, 0.016, clampf((t - 0.62) / 0.38, 0.0, 1.0))


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	_tri(tool, a, b, c, ua, ub, uc)
	_tri(tool, a, c, d, ua, uc, ud)


func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	tool.set_uv(ua)
	tool.add_vertex(a)
	tool.set_uv(ub)
	tool.add_vertex(b)
	tool.set_uv(uc)
	tool.add_vertex(c)


func _cap(tool: SurfaceTool, ring: PackedVector3Array, uvs: PackedVector2Array, rear: bool) -> void:
	var centre := Vector3.ZERO
	var uv := Vector2(0.5, 0.0 if rear else 1.0)
	for p in ring:
		centre += p
	centre /= float(ring.size())
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var ua := uvs[i]
		var ub := uvs[(i + 1) % uvs.size()]
		if rear:
			_tri(tool, centre, b, a, uv, ub, ua)
		else:
			_tri(tool, centre, a, b, uv, ua, ub)


func _centre(path: PackedVector3Array, t: float, shake: float) -> Vector3:
	var point := _raw_sample(path, t)
	var tangent := _tangent(path, t)
	var side := tangent.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	return Vector3(point.x, 0.0, point.z) + side * shake


func _raw_sample(path: PackedVector3Array, t: float) -> Vector3:
	var last := path.size() - 1
	var index := clampi(int(t * float(last)), 0, last - 1)
	var local := t * float(last) - float(index)
	return path[index].lerp(path[index + 1], local)


func _tangent(path: PackedVector3Array, t: float) -> Vector3:
	var last := path.size() - 1
	var index := clampi(int(t * float(last)), 0, last - 1)
	var dir := path[index + 1] - path[index]
	dir.y = 0.0
	if dir.length() < 0.001:
		return Vector3(0.0, 0.0, -1.0)
	return dir.normalized()
