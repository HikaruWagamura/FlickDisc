extends Node3D

## Playable clone of the purchased solid / rigged arrow.
## One shaft on the grass path. It grows with the pull, goes a
## darker red, and shakes when the weight is piled on.
## The 5+3 block cue stays in aim_cue.gd so both can be compared.

const RIGGED := preload("res://assets/arrows/rigged_arrow.glb")
const SHADER_PATH := "res://shaders/aim_solid_3d.gdshader"
const REST_LEN := 0.75
const SEAT := 0.010
const PERIOD := 0.55

var _rig: Node3D
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _showing := false
var _path := PackedVector3Array()
var _power := 0.0


func _ready() -> void:
	var packed: PackedScene = RIGGED
	if packed == null:
		push_error("Solid aim arrow missing")
		return
	_rig = packed.instantiate()
	_rig.name = "SolidArrow"
	_rig.visible = false
	add_child(_rig)
	_mesh = _find_mesh(_rig)
	if _mesh != null:
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_mesh.extra_cull_margin = 8.0
		var shader := load(SHADER_PATH) as Shader
		if shader != null:
			_mat = ShaderMaterial.new()
			_mat.shader = shader
			_mesh.material_override = _mat


func set_style(_which: int) -> void:
	pass


func present(path: PackedVector3Array, power: float) -> void:
	if path.size() < 2:
		clear()
		return
	visible = true
	_showing = true
	_path = path
	_power = clampf(power, 0.0, 1.0)
	_place()


func clear() -> void:
	_showing = false
	_path = PackedVector3Array()
	_power = 0.0
	visible = false
	if _rig != null:
		_rig.visible = false


func _process(_delta: float) -> void:
	if _showing and _path.size() >= 2:
		_place()


func _place() -> void:
	if _rig == null:
		return
	var amount := _power
	var length := _path_length()
	var start := _sample(_path, 0.0)
	var tan := _tangent(_path, 0.08)
	var grow := lerpf(0.70, 1.55, amount)
	var sx := 0.92 * grow
	var sy := lerpf(0.82, 1.28, amount)
	var sz := clampf(length / REST_LEN, 1.5, 3.2) * lerpf(0.78, 1.22, amount)
	var shake := clampf((amount - 0.62) / 0.38, 0.0, 1.0)
	shake = shake * shake
	var wave := float(Time.get_ticks_msec()) * 0.001
	var hop := 0.0
	var side := Vector3(-tan.z, 0.0, tan.x)
	if shake > 0.01:
		var amp := shake * 0.046
		start += side * sin(wave * 48.0) * amp
		hop = cos(wave * 61.0) * amp * 0.45
		tan = (tan + side * sin(wave * 38.0) * shake * 0.08).normalized()
	# Leave from the bowl centre on the grass, a little past the stone
	# so the shaft doesn't stand out of the top.
	var origin := start + tan * (0.22 + REST_LEN * sz * 0.12)
	origin.y = SEAT + hop + 0.006 * grow
	_rig.visible = true
	var xf := Transform3D()
	xf.origin = origin
	xf = xf.looking_at(origin + tan * maxf(length, 1.0), Vector3.UP)
	xf.basis = xf.basis.scaled(Vector3(sx, sy, sz))
	_rig.global_transform = xf
	if _mat != null:
		_mat.set_shader_parameter("power", amount)
		_mat.set_shader_parameter("shake", shake)


func _path_length() -> float:
	var total := 0.0
	for i in range(1, _path.size()):
		total += _path[i - 1].distance_to(_path[i])
	return maxf(total, 0.8)


func _sample(path: PackedVector3Array, t: float) -> Vector3:
	var last := path.size() - 1
	var index := clampi(int(t * float(last)), 0, last - 1)
	var local := t * float(last) - float(index)
	var point := path[index].lerp(path[index + 1], local)
	return Vector3(point.x, 0.0, point.z)


func _tangent(path: PackedVector3Array, t: float) -> Vector3:
	var last := path.size() - 1
	var index := clampi(int(t * float(last)), 0, last - 1)
	var dir := path[index + 1] - path[index]
	dir.y = 0.0
	if dir.length() < 0.001:
		return Vector3(0.0, 0.0, -1.0)
	return dir.normalized()


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null
