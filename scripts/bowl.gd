class_name Bowl
extends Node3D

## A disc or the jack on the green. Motion is owned by the table in DiscController.
## These stay where they stop, and later bowls can knock them.

const DISC_RADIUS := 0.18
const JACK_RADIUS := 0.16
const DISC_MASS := 1.0
const JACK_MASS := 0.7
const DISC_RESTITUTION := 0.4
const JACK_RESTITUTION := 0.52

var radius := DISC_RADIUS
var mass := DISC_MASS
var velocity := Vector3.ZERO
var moving := false
var is_jack := false
var spin_angle := 0.0
var stop_timer := 0.0
var punch := 0.0
var in_ditch := false
var palette_index := 0

var _spin: Node3D
var _shadow: MeshInstance3D
var _pip: MeshInstance3D
var _score_ring: MeshInstance3D


static func palette(index: int) -> Array:
	var looks := [
		[Color(0.40, 0.06, 0.10), Color(0.82, 0.12, 0.18), Color(0.93, 0.22, 0.26), Color(0.97, 0.96, 0.93)],
		[Color(0.55, 0.52, 0.46), Color(0.93, 0.90, 0.82), Color(0.98, 0.96, 0.90), Color(0.12, 0.22, 0.38)],
		[Color(0.04, 0.08, 0.16), Color(0.10, 0.22, 0.46), Color(0.20, 0.38, 0.72), Color(0.93, 0.78, 0.38)],
		[Color(0.10, 0.28, 0.16), Color(0.16, 0.46, 0.28), Color(0.55, 0.72, 0.42), Color(0.96, 0.92, 0.72)],
	]
	return looks[index % looks.size()]


static func bowl_type(index: int) -> Dictionary:
	var types := [
		{"name": "NARROW", "bias": 0.55},
		{"name": "MEDIUM", "bias": 0.85},
		{"name": "WIDE", "bias": 1.15},
		{"name": "HOOK", "bias": 1.45},
	]
	return types[index % types.size()]


static func restitution_for(jack_involved: bool) -> float:
	return JACK_RESTITUTION if jack_involved else DISC_RESTITUTION


static func resolve(a_pos: Vector3, a_vel: Vector3, a_radius: float, a_mass: float, b_pos: Vector3, b_vel: Vector3, b_radius: float, b_mass: float, restitution: float) -> Dictionary:
	var delta := Vector2(a_pos.x - b_pos.x, a_pos.z - b_pos.z)
	var dist := delta.length()
	var min_dist := a_radius + b_radius
	if dist >= min_dist:
		return {"hit": false, "a_pos": a_pos, "a_vel": a_vel, "b_pos": b_pos, "b_vel": b_vel, "impact": 0.0}
	var normal := Vector2(1.0, 0.0) if dist < 0.0001 else delta / dist
	var overlap := min_dist - maxf(dist, 0.0001)
	var inv_a := 1.0 / a_mass
	var inv_b := 1.0 / b_mass
	var inv_sum := inv_a + inv_b
	a_pos.x += normal.x * overlap * (inv_a / inv_sum)
	a_pos.z += normal.y * overlap * (inv_a / inv_sum)
	b_pos.x -= normal.x * overlap * (inv_b / inv_sum)
	b_pos.z -= normal.y * overlap * (inv_b / inv_sum)
	var relative := Vector2(a_vel.x - b_vel.x, a_vel.z - b_vel.z)
	var closing := relative.dot(normal)
	var impact := 0.0
	if closing < 0.0:
		var impulse := -(1.0 + restitution) * closing / inv_sum
		a_vel.x += normal.x * impulse * inv_a
		a_vel.z += normal.y * impulse * inv_a
		b_vel.x -= normal.x * impulse * inv_b
		b_vel.z -= normal.y * impulse * inv_b
		var tangent := relative - normal * closing
		var tangent_len := tangent.length()
		if tangent_len > 0.001:
			var friction_impulse := minf(impulse * 0.25, tangent_len / inv_sum)
			var tangent_dir := tangent / tangent_len
			a_vel.x -= tangent_dir.x * friction_impulse * inv_a
			a_vel.z -= tangent_dir.y * friction_impulse * inv_a
			b_vel.x += tangent_dir.x * friction_impulse * inv_b
			b_vel.z += tangent_dir.y * friction_impulse * inv_b
		impact = absf(closing)
	a_vel.y = 0.0
	b_vel.y = 0.0
	a_pos.y = 0.0
	b_pos.y = 0.0
	return {"hit": impact > 0.0, "a_pos": a_pos, "a_vel": a_vel, "b_pos": b_pos, "b_vel": b_vel, "impact": impact}


func setup_disc(index: int, hand: float = -1.0) -> void:
	palette_index = index
	radius = DISC_RADIUS
	mass = DISC_MASS
	is_jack = false
	_build_disc(palette(index), hand)


func setup_jack() -> void:
	radius = JACK_RADIUS
	mass = JACK_MASS
	is_jack = true
	_build_jack()


func rest_at(where: Vector3) -> void:
	in_ditch = false
	global_position = Vector3(where.x, 0.0, where.z)
	velocity = Vector3.ZERO
	moving = false
	stop_timer = 0.0
	punch = 0.0
	present(0.0)


func drop_in_ditch(where: Vector3) -> void:
	in_ditch = true
	global_position = where
	velocity = Vector3.ZERO
	moving = false
	stop_timer = 0.0
	punch = 0.0
	present(0.0)


func add_punch(amount: float) -> void:
	punch = maxf(punch, amount)


func present(speed: float) -> void:
	if _spin == null:
		return
	punch = move_toward(punch, 0.0, 0.08)
	var lift := clampf(speed / 21.5, 0.0, 1.0)
	_spin.position.y = lift * 0.04 + punch * 0.07
	_spin.rotation.y = spin_angle
	if _shadow != null:
		_shadow.position = Vector3(0.08 + lift * 0.05, 0.012, 0.05)


func set_hand(hand: float) -> void:
	if _pip == null:
		return
	_pip.position = Vector3(signf(hand) * 0.13, 0.02, 0.0)


func set_scoring(on: bool) -> void:
	if _score_ring != null:
		_score_ring.visible = on


func _build_disc(colors: Array, hand: float) -> void:
	_shadow = _make_shadow(0.16)
	add_child(_shadow)
	_spin = Node3D.new()
	add_child(_spin)
	var rim := _mat(colors[0], 0.42, 0.12)
	var body := _mat(colors[1], 0.34, 0.08)
	var mark := _flat(colors[3])
	_puck(_spin, rim, body)
	_pip = MeshInstance3D.new()
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 0.02
	pip_mesh.height = 0.04
	pip_mesh.radial_segments = 10
	pip_mesh.rings = 6
	_pip.mesh = pip_mesh
	_pip.material_override = mark
	_pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(_pip)
	set_hand(hand)
	_score_ring = MeshInstance3D.new()
	_score_ring.mesh = _annulus(0.2, 0.26, 28)
	_score_ring.position = Vector3(0.0, 0.02, 0.0)
	var ring_mat := _flat(Color(0.98, 0.84, 0.32))
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color.a = 0.9
	_score_ring.material_override = ring_mat
	_score_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_score_ring.visible = false
	add_child(_score_ring)


func _build_jack() -> void:
	_shadow = _make_shadow(0.15)
	add_child(_shadow)
	_spin = Node3D.new()
	add_child(_spin)
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = JACK_RADIUS
	mesh.height = JACK_RADIUS * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	ball.mesh = mesh
	ball.position = Vector3(0.0, JACK_RADIUS, 0.0)
	var mat := _mat(Color(0.98, 0.82, 0.28), 0.22, 0.72)
	mat.emission_enabled = true
	mat.emission = Color(0.62, 0.42, 0.08)
	mat.emission_energy_multiplier = 0.35
	ball.material_override = mat
	_spin.add_child(ball)
	var band := MeshInstance3D.new()
	band.mesh = _annulus(0.09, 0.125, 24)
	band.position = Vector3(0.0, JACK_RADIUS + 0.01, 0.0)
	band.material_override = _flat(Color(0.98, 0.96, 0.9))
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(band)


func _make_shadow(size: float) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = size
	shadow_mesh.bottom_radius = size
	shadow_mesh.height = 0.008
	shadow_mesh.radial_segments = 20
	shadow.mesh = shadow_mesh
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.albedo_color = Color(0.0, 0.05, 0.02, 0.34)
	shadow.material_override = shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = Vector3(0.08, 0.012, 0.05)
	return shadow


func _puck(parent: Node3D, rim: Material, body: Material) -> void:
	_cylinder(parent, Vector3(0.0, 0.014, 0.0), 0.18, 0.172, 0.02, rim)
	_cylinder(parent, Vector3(0.0, 0.026, 0.0), 0.132, 0.132, 0.006, body)


func _cylinder(parent: Node3D, pos: Vector3, bottom_r: float, top_r: float, height: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_r
	mesh.top_radius = top_r
	mesh.height = height
	mesh.radial_segments = 28
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)


func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return mat


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


func _annulus(inner_r: float, outer_r: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var i0 := Vector3(cos(a0) * inner_r, 0.0, sin(a0) * inner_r)
		var i1 := Vector3(cos(a1) * inner_r, 0.0, sin(a1) * inner_r)
		var o0 := Vector3(cos(a0) * outer_r, 0.0, sin(a0) * outer_r)
		var o1 := Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r)
		for vertex in [i0, o0, o1, i0, o1, i1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	return st.commit()
