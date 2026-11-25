class_name Bowl
extends Node3D

## A bowl or the jack on the green. Motion is owned by the table in DiscController.
## Settled bowls stay where they stop, and later bowls can knock them.
## Red is one side, blue is the other. Each side bowls four in an end.
## The running bowl is the sculpted lawn bowl: bias face, grip rings, and
## finger grooves, then team colour over the same mesh.

const DISC_RADIUS := 0.20
const JACK_RADIUS := 0.16
const DISC_MASS := 2.45
const JACK_MASS := 0.52
const DISC_RESTITUTION := 0.46
const JACK_RESTITUTION := 0.4
## Uploaded GLB sits on Y=0 and stands 0.978 tall, about 0.978 across.
const MESH_HEIGHT := 0.97834063
## Sink the running surface into the green. A round bowl on a flat plane
## reads as hovering unless the contact is buried for the rink camera.
const SIT_NEST := 0.05
const BOWL_SCENE := preload("res://assets/bowls/lawn_bowl.glb")
const ALBEDO_BLUE := preload("res://assets/bowls/bowl_albedo_blue.jpg")

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

var _spin: Node3D
var _shadow: MeshInstance3D
var _pip: Node3D
var _score_ring: MeshInstance3D
var _rim_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D
var _cap_mat: StandardMaterial3D
var _mark_mat: StandardMaterial3D


static func palette(index: int) -> Array:
	var looks := [
		[Color(0.55, 0.06, 0.08), Color(0.78, 0.10, 0.14), Color(0.62, 0.08, 0.12), Color(0.96, 0.90, 0.88)],
		[Color(0.08, 0.18, 0.48), Color(0.12, 0.32, 0.78), Color(0.10, 0.24, 0.62), Color(0.88, 0.92, 0.98)],
	]
	return looks[index % looks.size()]


static func apply_team(mat: StandardMaterial3D, index: int) -> void:
	if mat == null:
		return
	if not mat.has_meta("albedo_red"):
		mat.set_meta("albedo_red", mat.albedo_texture)
	if index % 2 == 1:
		mat.albedo_texture = ALBEDO_BLUE
		mat.albedo_color = Color(0.82, 0.90, 1.0)
	else:
		mat.albedo_texture = mat.get_meta("albedo_red")
		mat.albedo_color = Color(1.0, 0.94, 0.92)


static func hand_yaw(hand: float) -> float:
	# The sculpt's grip dimples sit on ±Z. Turn them to ±X so a bowl
	# running toward the jack is held left and right. The other hand
	# flips 180 so the bias face matches the curve.
	return 0.5 * PI if signf(hand) < 0.0 else 1.5 * PI


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
	if _spin == null:
		_build_disc(index, hand)
		return
	apply_team(_body_mat, index)
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
	var lift := clampf(speed / 21.5, 0.0, 1.0)
	# Jack mesh is already offset to the green. Bowls are centred on _spin
	# so the spin node has to sit at radius.
	var sit := 0.0 if is_jack else radius - SIT_NEST
	_spin.position.y = sit + lift * 0.03 + punch * 0.06
	_spin.transform.basis = roll_basis
	if _shadow != null:
		_shadow.position = Vector3(0.0, 0.003, 0.0)


func set_hand(hand: float) -> void:
	if _pip == null:
		return
	_pip.rotation = Vector3(0.0, hand_yaw(hand), 0.0)


func set_scoring(on: bool) -> void:
	if _score_ring != null:
		_score_ring.visible = on


func _build_disc(index: int, hand: float) -> void:
	_shadow = _make_shadow(0.18)
	add_child(_shadow)
	_spin = Node3D.new()
	add_child(_spin)
	var dressed: Dictionary = dress_stone(_spin, index, hand)
	_rim_mat = dressed["rim"]
	_body_mat = dressed["body"]
	_cap_mat = dressed["cap"]
	_mark_mat = dressed["mark"]
	_pip = dressed["weight"]
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
	ball.position = Vector3(0.0, JACK_RADIUS - SIT_NEST, 0.0)
	var mat := _mat(Color(0.98, 0.82, 0.28), 0.22, 0.72)
	mat.emission_enabled = true
	mat.emission = Color(0.62, 0.42, 0.08)
	mat.emission_energy_multiplier = 0.35
	ball.material_override = mat
	_spin.add_child(ball)
	var band := MeshInstance3D.new()
	band.mesh = _annulus(0.09, 0.125, 24)
	band.position = Vector3(0.0, JACK_RADIUS - SIT_NEST + 0.01, 0.0)
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
	shadow_mat.albedo_color = Color(0.0, 0.04, 0.02, 0.46)
	shadow.material_override = shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = Vector3(0.0, 0.003, 0.0)
	return shadow


static func dress_stone(parent: Node3D, index: int, hand: float) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "LawnBowl"
	parent.add_child(holder)
	var sculpt: Node = BOWL_SCENE.instantiate()
	var mesh_scale := (DISC_RADIUS * 2.0) / MESH_HEIGHT
	sculpt.scale = Vector3.ONE * mesh_scale
	# Scale is around the GLB origin (the green). Shift so the centre
	# sits on the spin origin and the bowl can roll without dipping.
	sculpt.position = Vector3(0.0, -DISC_RADIUS, 0.0)
	holder.add_child(sculpt)
	holder.rotation = Vector3(0.0, hand_yaw(hand), 0.0)
	var mesh := _first_mesh(sculpt)
	var mat := StandardMaterial3D.new()
	if mesh != null:
		var source: Material = mesh.material_override
		if source == null:
			source = mesh.get_active_material(0)
		if source is StandardMaterial3D:
			mat = (source as StandardMaterial3D).duplicate()
		mesh.material_override = mat
	mat.roughness = 0.52
	mat.metallic = 0.04
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	apply_team(mat, index)
	return {"rim": mat, "body": mat, "cap": mat, "mark": mat, "weight": holder}


static func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null


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
