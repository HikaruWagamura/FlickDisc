extends MeshInstance3D

## Procedural 3D aiming guide. A rounded, bevelled ribbon on the grass,
## tucked under the bowl, thickening into a real arrowhead.

const RING_COUNT := 40
const SIDES := 12
const SHADER_PATH := "res://shaders/aim_guide_3d.gdshader"
const HEIGHT := 0.042
const BASE_WIDTH := 0.090
const BASE_THICKNESS := 0.056

var _material: ShaderMaterial
var _showing := false


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 12.0
	sorting_offset = 4.0
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
	var power_width := lerpf(0.94, 1.34, amount)
	var power_thickness := lerpf(0.92, 1.42, amount)
	var shake := 0.0
	if amount > 0.78:
		shake = sin(Time.get_ticks_msec() * 0.034) * (amount - 0.78) * 0.012
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for ring in range(RING_COUNT + 1):
		var t := float(ring) / float(RING_COUNT)
		var centre := _centre(path, t, shake)
		var tangent := _tangent(path, t)
		var side := tangent.cross(Vector3.UP)
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT
		else:
			side = side.normalized()
		var half_width := _shaft_width(t, power_width)
		var half_height := BASE_THICKNESS * 0.5 * power_thickness
		for side_index in range(SIDES):
			var angle := TAU * float(side_index) / float(SIDES)
			var point := centre + side * (cos(angle) * half_width) + Vector3.UP * (sin(angle) * half_height)
			vertices.append(point)
			uvs.append(Vector2(float(side_index) / float(SIDES), t))
	for ring in range(RING_COUNT):
		for side_index in range(SIDES):
			var next_side := (side_index + 1) % SIDES
			var a := ring * SIDES + side_index
			var b := ring * SIDES + next_side
			var c := (ring + 1) * SIDES + next_side
			var d := (ring + 1) * SIDES + side_index
			indices.append_array(PackedInt32Array([a, c, b, a, d, c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tool := SurfaceTool.new()
	tool.create_from(array_mesh, 0)
	tool.generate_normals()
	mesh = tool.commit()
	if _material != null:
		material_override = _material


func _shaft_width(t: float, power_scale: float) -> float:
	var shaft := BASE_WIDTH * power_scale
	var head_width := shaft * 1.72
	if t < 0.76:
		return shaft * (0.92 + 0.08 * sin((t / 0.76) * PI))
	if t < 0.86:
		return lerpf(shaft, head_width, smoothstep(0.76, 0.86, t))
	return lerpf(head_width, 0.002, smoothstep(0.0, 1.0, (t - 0.86) / 0.14))


func _centre(path: PackedVector3Array, t: float, shake: float) -> Vector3:
	var point := _raw_sample(path, t)
	var tangent := _tangent(path, t)
	var side := tangent.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	return Vector3(point.x, HEIGHT, point.z) + side * shake


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
