extends Node3D

## Playable solid arrow. Sits on the bowl's centre line and faces
## the same way the bowl is aiming. Grows with the pull, runs ice
## blue → lilac → pink → red → dark red, and shakes at full weight.

const RIGGED := preload("res://assets/arrows/rigged_arrow.glb")
const SHADER_PATH := "res://shaders/aim_solid_3d.gdshader"
const REST_LEN := 0.75
const SEAT := 0.008

var _rig: Node3D
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _showing := false
var _path := PackedVector3Array()
var _power := 0.0
var _facing := Vector3(0.0, 0.0, -1.0)


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


func present(path: PackedVector3Array, power: float, facing: Vector3 = Vector3.ZERO) -> void:
	if path.size() < 2:
		clear()
		return
	visible = true
	_showing = true
	_path = path
	_power = clampf(power, 0.0, 1.0)
	if facing.length() > 0.001:
		_facing = Vector3(facing.x, 0.0, facing.z).normalized()
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
	var face := _facing
	if face.length() < 0.001:
		face = Vector3(0.0, 0.0, -1.0)
	else:
		face = Vector3(face.x, 0.0, face.z).normalized()
	var start := _sample(_path, 0.0)
	# Short ends stay small. Full weight stretches the shaft so the
	# whole power scale is readable, from a yard to a long end.
	var shaft := lerpf(0.82, 4.15, amount)
	var sx := lerpf(0.36, 0.82, amount)
	var sy := lerpf(0.40, 0.90, amount)
	var sz := shaft / REST_LEN
	var shake := clampf((amount - 0.94) / 0.06, 0.0, 1.0)
	shake = shake * shake
	var wave := float(Time.get_ticks_msec()) * 0.001
	var hop := 0.0
	var side := Vector3(-face.z, 0.0, face.x)
	if shake > 0.01:
		var amp := shake * 0.028
		hop = sin(wave * 58.0) * amp
		face = (face + side * sin(wave * 46.0) * shake * 0.03).normalized()
	# Mesh origin is the shaft centre. Put the tail on the bowl centre
	# so the arrow IS the bowl's middle line, facing the same way.
	var origin := start + face * (shaft * 0.50)
	origin.y = SEAT + hop
	_rig.visible = true
	var xf := Transform3D()
	xf.origin = origin
	xf = xf.looking_at(origin + face, Vector3.UP)
	xf.basis = xf.basis.scaled(Vector3(sx, sy, sz))
	_rig.global_transform = xf
	if _mat != null:
		_mat.set_shader_parameter("power", amount)
		_mat.set_shader_parameter("shake", shake)


func _sample(path: PackedVector3Array, t: float) -> Vector3:
	var last := path.size() - 1
	var index := clampi(int(t * float(last)), 0, last - 1)
	var local := t * float(last) - float(index)
	var point := path[index].lerp(path[index + 1], local)
	return Vector3(point.x, 0.0, point.z)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null
