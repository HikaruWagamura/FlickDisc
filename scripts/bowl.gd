class_name Bowl
extends Node3D

## A bowl or the jack on the green. Motion is owned by the table in DiscController.
## Settled bowls stay where they stop, and later bowls can knock them.
## Black is one side, red is the other. Each side bowls four in an end.

const DISC_RADIUS := 0.20
const JACK_RADIUS := 0.16
## The mesh sits slightly inside the contact radius so a lean still clears the grass.
const VISUAL_RADIUS := 0.19
const DISC_MASS := 2.45
const JACK_MASS := 0.52
const DISC_RESTITUTION := 0.55
const JACK_RESTITUTION := 0.48

var radius := DISC_RADIUS
var mass := DISC_MASS
var velocity := Vector3.ZERO
var moving := false
var is_jack := false
var side := 0
var spin_angle := 0.0
var roll_basis := Basis.IDENTITY
var stop_timer := 0.0
var punch := 0.0
var in_ditch := false
var palette_index := 0
## Visual only. The table still owns the path. Lean tips the bowl into its hand.
var lean := 0.0
var travel := Vector3(0.0, 0.0, -1.0)

var _spin: Node3D
var _stone: Node3D
var _shadow: MeshInstance3D
var _pip: Node3D
var _score_ring: MeshInstance3D
var _rim_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D
var _cap_mat: StandardMaterial3D
var _mark_mat: StandardMaterial3D


static func palette(index: int) -> Array:
	var ivory := Color(0.94, 0.91, 0.84)
	var gold := Color(0.96, 0.78, 0.26)
	# Band, body, inner ring, bias rings. Ivory and gold stay readable on the grass.
	var looks := [
		[ivory, Color(0.10, 0.10, 0.12), Color(0.22, 0.20, 0.18), gold],
		[ivory, Color(0.86, 0.07, 0.09), Color(0.55, 0.04, 0.06), gold],
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
			var friction_impulse := minf(impulse * 0.34, tangent_len / inv_sum)
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
	paint(index, hand)


func paint(index: int, hand: float = -1.0) -> void:
	palette_index = index
	side = index % 2
	radius = DISC_RADIUS
	mass = DISC_MASS
	is_jack = false
	var colors := palette(index)
	if _spin == null:
		_build_disc(colors, hand)
		return
	_rim_mat.albedo_color = colors[0]
	_body_mat.albedo_color = colors[1]
	_cap_mat.albedo_color = colors[2]
	_mark_mat.albedo_color = colors[3]
	set_hand(hand)


static func roll_basis_by(current: Basis, travel: Vector3, body_radius: float) -> Basis:
	var flat := Vector3(travel.x, 0.0, travel.z)
	var dist := flat.length()
	if dist < 0.00005 or body_radius < 0.001:
		return current
	var axis := Vector3.UP.cross(flat / dist)
	if axis.length() < 0.001:
		return current
	return Basis(axis.normalized(), dist / body_radius) * current


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
	var lift := clampf(speed / 15.2, 0.0, 1.0)
	var center := JACK_RADIUS if is_jack else VISUAL_RADIUS
	_spin.position = Vector3(0.0, center + lift * 0.018 + punch * 0.05, 0.0)
	_spin.transform.basis = _posed_basis(travel, lean, roll_basis)
	if _shadow != null:
		_shadow.visible = global_position.y > -0.06
		_shadow.position = Vector3(0.05, 0.012, 0.03)


static func _posed_basis(travel: Vector3, lean_angle: float, rolled: Basis) -> Basis:
	var tilt := Basis.IDENTITY
	if absf(lean_angle) > 0.001:
		var flat := Vector3(travel.x, 0.0, travel.z)
		if flat.length() > 0.05:
			tilt = Basis(flat.normalized(), lean_angle)
	return tilt * rolled


func set_hand(hand: float) -> void:
	if _pip == null:
		return
	var side := signf(hand)
	# Rings are built on +X. Turn the anchor so they sit on the heavy side.
	# The shell is nudged the other way, so the bowl wobbles as that side rolls under.
	_pip.rotation = Vector3(0.0, 0.0 if side > 0.0 else PI, 0.0)
	if _stone != null:
		_stone.position = Vector3(-side * 0.012, 0.0, 0.0)


func set_scoring(on: bool) -> void:
	if _score_ring != null:
		_score_ring.visible = on


func _build_disc(colors: Array, hand: float) -> void:
	_shadow = _make_shadow(0.22)
	add_child(_shadow)
	_spin = Node3D.new()
	add_child(_spin)
	var dressed: Dictionary = dress_stone(_spin, colors, hand)
	_rim_mat = dressed["rim"]
	_body_mat = dressed["body"]
	_cap_mat = dressed["cap"]
	_mark_mat = dressed["mark"]
	_pip = dressed["weight"]
	_stone = dressed["stone"]
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
	mesh.radial_segments = 28
	mesh.rings = 14
	ball.mesh = mesh
	var mat := _mat(Color(0.96, 0.91, 0.78), 0.28, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.42, 0.18)
	mat.emission_energy_multiplier = 0.22
	ball.material_override = mat
	_spin.add_child(ball)
	# Cream stays the jack colour. The band is what makes the roll readable.
	_bowl_ring(_spin, JACK_RADIUS * 0.92, 0.012, Vector3.ZERO, Vector3.ZERO, _flat(Color(0.98, 0.96, 0.9)))


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


static func dress_stone(parent: Node3D, colors: Array, hand: float) -> Dictionary:
	var rim := _stone_mat(colors[0], 0.32, 0.06)
	var body := _stone_mat(colors[1], 0.36, 0.05)
	var cap := _stone_mat(colors[2], 0.3, 0.1)
	var mark := StandardMaterial3D.new()
	mark.albedo_color = colors[3]
	mark.roughness = 0.28
	mark.metallic = 0.22
	mark.emission_enabled = true
	mark.emission = Color(0.72, 0.52, 0.12)
	mark.emission_energy_multiplier = 0.35
	# A lawn bowl: a sphere, an ivory running band, and rings on the heavy side.
	# The mesh is centred so the roll spins in place instead of tumbling the shell.
	var stone := Node3D.new()
	stone.name = "Stone"
	parent.add_child(stone)
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = VISUAL_RADIUS
	mesh.height = VISUAL_RADIUS * 2.0
	mesh.radial_segments = 36
	mesh.rings = 18
	ball.mesh = mesh
	ball.material_override = body
	stone.add_child(ball)
	_bowl_ring(stone, VISUAL_RADIUS * 0.98, 0.011, Vector3.ZERO, Vector3.ZERO, rim)
	var anchor := Node3D.new()
	anchor.name = "Bias"
	stone.add_child(anchor)
	var face := Vector3(0.0, 0.0, PI * 0.5)
	_bias_ring(anchor, 0.074, 0.009, face, mark)
	_bias_ring(anchor, 0.046, 0.008, face, cap)
	_bias_ring(anchor, 0.022, 0.007, face, mark)
	return {"rim": rim, "body": body, "cap": cap, "mark": mark, "weight": anchor, "stone": stone}


static func _stone_mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return mat


static func _bias_ring(parent: Node3D, radius: float, tube: float, rot: Vector3, mat: Material) -> void:
	var on_shell := sqrt(maxf(VISUAL_RADIUS * VISUAL_RADIUS - radius * radius, 0.0))
	_bowl_ring(parent, radius, tube, Vector3(on_shell, 0.0, 0.0), rot, mat)


static func _bowl_ring(parent: Node3D, radius: float, tube: float, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - tube, 0.004)
	mesh.outer_radius = radius + tube
	mesh.rings = 28
	mesh.ring_segments = 8
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)


static func _stone_cylinder(parent: Node3D, pos: Vector3, bottom_r: float, top_r: float, height: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_r
	mesh.top_radius = top_r
	mesh.height = height
	mesh.radial_segments = 36
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)


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
