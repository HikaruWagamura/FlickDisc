class_name Bowl
extends Node3D

## A bowl or the jack on the green. Motion is owned by the table in DiscController.
## Settled bowls stay where they stop, and later bowls can knock them.
## Red is one side, blue is the other. Each side bowls four in an end.
## Club bowls are the CGTrader set (main). The earlier sculpt stays as the
## WIDE bias look so that shape is not thrown away.

const DISC_RADIUS := 0.20
const JACK_RADIUS := 0.16
const DISC_MASS := 2.45
const JACK_MASS := 0.52
## Lawn bowls kiss and push. A high bounce reads as snooker, not grass.
const DISC_RESTITUTION := 0.30
const JACK_RESTITUTION := 0.42
const CONTACT_FRICTION := 0.58
## Tripo sculpt sits on Y=0 and stands 0.978 tall.
const WIDE_MESH_HEIGHT := 0.97834063
const WIDE_BIAS := 2
## Sink the running surface into the green. A round bowl on a flat plane
## reads as hovering unless the contact is buried for the rink camera.
const SIT_NEST := 0.03
const WIDE_SCENE := preload("res://assets/bowls/lawn_bowl.glb")
const CLUB_SCENE := preload("res://assets/bowls/modern_lawn_bowls.fbx")
const ALBEDO_BLUE := preload("res://assets/bowls/bowl_albedo_blue.jpg")

static var _club_meshes: Array[Mesh] = []
static var _jack_mesh: Mesh
static var _next_club_variant := 0
static var _maps_cache: Dictionary = {}

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
var bias_type := 1
var hand_sign := -1.0

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


static func is_wide(bias: int) -> bool:
	return bias % 4 == WIDE_BIAS


static func apply_team(mat: StandardMaterial3D, index: int, wide: bool = false) -> void:
	if mat == null:
		return
	if wide:
		if not mat.has_meta("albedo_red"):
			mat.set_meta("albedo_red", mat.albedo_texture)
		if index % 2 == 1:
			mat.albedo_texture = ALBEDO_BLUE
			mat.albedo_color = Color(0.82, 0.90, 1.0)
		else:
			mat.albedo_texture = mat.get_meta("albedo_red")
			mat.albedo_color = Color(1.0, 0.94, 0.92)
		return
	var maps := _club_maps()
	_apply_pbr(mat, maps)
	var team_tex: Texture2D = maps["blue"] if index % 2 == 1 else maps["red"]
	if team_tex != null:
		mat.albedo_texture = team_tex
		mat.albedo_color = Color(1.0, 1.0, 1.0)
	elif maps["albedo"] != null:
		mat.albedo_texture = maps["albedo"]
		mat.albedo_color = palette(index)[1]
	else:
		mat.albedo_texture = null
		mat.albedo_color = palette(index)[1]


static func _club_maps() -> Dictionary:
	if not _maps_cache.is_empty():
		return _maps_cache
	var maps := {
		"albedo": null,
		"normal": _load_tex("res://assets/bowls/textures/bowl_normal.jpg"),
		"roughness": _load_tex("res://assets/bowls/textures/bowl_scratches.jpg"),
		"metallic": null,
		"red": _load_tex("res://assets/bowls/textures/bowl_color_3.jpg"),
		"blue": _load_tex("res://assets/bowls/textures/bowl_color_1.jpg"),
		"jack": null,
	}
	if maps["red"] == null:
		maps["red"] = _load_tex("res://assets/bowls/textures/bowl_red.jpg")
	if maps["blue"] == null:
		maps["blue"] = _load_tex("res://assets/bowls/textures/bowl_blue.jpg")
	for path in _texture_paths():
		var kind := _classify_tex(path)
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		if maps.has(kind) and maps[kind] == null:
			maps[kind] = tex
	_maps_cache = maps
	return maps


static func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


static func _texture_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	var seen := {}
	for folder in ["res://assets/bowls/textures", "res://assets/bowls"]:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			var lower := fname.to_lower()
			if not dir.current_is_dir() and _is_image_name(lower) and not _is_wide_image(lower):
				var path := "%s/%s" % [folder, fname]
				if not seen.has(path) and ResourceLoader.exists(path):
					seen[path] = true
					paths.append(path)
			fname = dir.get_next()
	return paths


static func _is_image_name(lower: String) -> bool:
	return lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".png") or lower.ends_with(".webp")


static func _is_wide_image(lower: String) -> bool:
	return "tripo" in lower or lower.begins_with("lawn_bowl_") or lower.begins_with("bowl_albedo_blue")


static func _classify_tex(path: String) -> String:
	var n := path.get_file().to_lower()
	if "normal" in n or "_nor" in n or n.contains("_n."):
		return "normal"
	if "rough" in n or "scratch" in n:
		return "roughness"
	if "metal" in n:
		return "metallic"
	if "jack" in n:
		return "jack"
	if "blue" in n:
		return "blue"
	if "red" in n:
		return "red"
	if "basecolor" in n or "base_color" in n or "albedo" in n or "diffuse" in n or "color" in n:
		return "albedo"
	return "albedo"


static func _apply_pbr(mat: StandardMaterial3D, maps: Dictionary) -> void:
	if maps["normal"] != null:
		mat.normal_enabled = true
		mat.normal_scale = 0.55
		mat.normal_texture = maps["normal"]
	if maps["roughness"] != null:
		mat.roughness_texture = maps["roughness"]
		mat.roughness = 0.42
	if maps["metallic"] != null:
		mat.metallic_texture = maps["metallic"]
		mat.metallic = 1.0


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
			var friction_impulse := minf(impulse * CONTACT_FRICTION, tangent_len / inv_sum)
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


func setup_disc(index: int, hand: float = -1.0, bias: int = 1) -> void:
	bias_type = bias
	paint(index, hand, bias)


func paint(index: int, hand: float = -1.0, bias: int = -1) -> void:
	palette_index = index
	side = index % 2
	hand_sign = -1.0 if signf(hand) < 0.0 else 1.0
	if bias >= 0:
		bias_type = bias
	radius = DISC_RADIUS
	mass = DISC_MASS
	is_jack = false
	if _spin == null:
		_build_disc(index, hand)
		return
	apply_team(_body_mat, index, is_wide(bias_type))
	set_hand(hand)


static func roll_basis_by(current: Basis, travel: Vector3, body_radius: float) -> Basis:
	var flat := Vector3(travel.x, 0.0, travel.z)
	var dist := flat.length()
	if dist < 0.00005 or body_radius < 0.001:
		return current
	var axis := Vector3.UP.cross(flat / dist)
	if axis.length() < 0.001:
		return current
	# Less than a pure roll so the last metres still read as a grass slide.
	return Basis(axis.normalized(), dist / body_radius * 0.78) * current


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
	_spin.position.y = radius - SIT_NEST + lift * 0.03 + punch * 0.06
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
	var variant := _next_club_variant
	_next_club_variant += 1
	# The paid pack is the bowl you play. WIDE is still a stronger bias,
	# not a swap back to the earlier sculpt.
	var dressed: Dictionary = dress_stone(_spin, index, hand, false, variant)
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
	var mesh := jack_mesh()
	var ball := MeshInstance3D.new()
	if mesh != null:
		ball.mesh = mesh
		_fit_mesh(ball, JACK_RADIUS * 2.0)
	else:
		var sphere := SphereMesh.new()
		sphere.radius = JACK_RADIUS
		sphere.height = JACK_RADIUS * 2.0
		sphere.radial_segments = 24
		sphere.rings = 12
		ball.mesh = sphere
	var mat := _mat(Color(0.96, 0.94, 0.88), 0.28, 0.08)
	apply_jack(mat)
	ball.material_override = mat
	_spin.add_child(ball)


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


static func dress_stone(parent: Node3D, index: int, hand: float, wide: bool = false, variant: int = 0) -> Dictionary:
	if wide:
		return _dress_wide(parent, index, hand)
	return _dress_club(parent, index, hand, variant)


static func _dress_club(parent: Node3D, index: int, hand: float, variant: int = 0) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "ClubBowl"
	parent.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = club_mesh(variant)
	if mi.mesh != null:
		_fit_mesh(mi, DISC_RADIUS * 2.0)
	else:
		var sphere := SphereMesh.new()
		sphere.radius = DISC_RADIUS
		sphere.height = DISC_RADIUS * 2.0
		sphere.radial_segments = 28
		sphere.rings = 14
		mi.mesh = sphere
	holder.add_child(mi)
	holder.rotation = Vector3(0.0, hand_yaw(hand), 0.0)
	var body := StandardMaterial3D.new()
	body.roughness = 0.38
	body.metallic = 0.06
	body.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	apply_team(body, index, false)
	var ring := StandardMaterial3D.new()
	ring.albedo_color = Color(0.94, 0.91, 0.84)
	ring.roughness = 0.26
	ring.metallic = 0.14
	ring.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	var mark := StandardMaterial3D.new()
	mark.albedo_color = Color(0.98, 0.97, 0.93)
	mark.roughness = 0.22
	mark.metallic = 0.04
	if mi.mesh != null and mi.mesh.get_surface_count() > 1:
		mi.set_surface_override_material(0, body)
		mi.set_surface_override_material(1, ring)
		if mi.mesh.get_surface_count() > 2:
			mi.set_surface_override_material(2, mark)
	else:
		mi.material_override = body
	return {"rim": ring, "body": body, "cap": mark, "mark": mark, "weight": holder}


static func _dress_wide(parent: Node3D, index: int, hand: float) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "WideBowl"
	parent.add_child(holder)
	var sculpt: Node = WIDE_SCENE.instantiate()
	var mesh_scale := (DISC_RADIUS * 2.0) / WIDE_MESH_HEIGHT
	sculpt.scale = Vector3.ONE * mesh_scale
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
	apply_team(mat, index, true)
	return {"rim": mat, "body": mat, "cap": mat, "mark": mat, "weight": holder}


static func club_mesh(variant: int = 0) -> Mesh:
	_ensure_club_meshes()
	if _club_meshes.is_empty():
		return null
	return _club_meshes[variant % _club_meshes.size()]


static func jack_mesh() -> Mesh:
	_ensure_club_meshes()
	return _jack_mesh


static func _ensure_club_meshes() -> void:
	if not _club_meshes.is_empty():
		return
	var root: Node = CLUB_SCENE.instantiate()
	for name in PackedStringArray(["ball_1", "ball_2", "ball_3", "ball_4", "ball_1_2"]):
		var mi := _named_mesh(root, PackedStringArray([name]))
		if mi != null and mi.mesh != null:
			_club_meshes.append(mi.mesh)
	var jack_mi := _named_mesh(root, PackedStringArray(["Sphere"]))
	if jack_mi != null:
		_jack_mesh = jack_mi.mesh
	root.free()


static func _extract_mesh(scene: PackedScene, names: PackedStringArray) -> Mesh:
	var root: Node = scene.instantiate()
	var mi := _named_mesh(root, names)
	var mesh: Mesh = mi.mesh if mi != null else null
	root.free()
	return mesh


static func _named_mesh(node: Node, names: PackedStringArray) -> MeshInstance3D:
	if node is MeshInstance3D:
		for name in names:
			if node.name == StringName(name) or str(node.name) == name:
				return node
	for child in node.get_children():
		var found := _named_mesh(child, names)
		if found != null:
			return found
	return null


static func _fit_mesh(mi: MeshInstance3D, target_span: float) -> void:
	if mi.mesh == null:
		return
	var aabb := mi.mesh.get_aabb()
	var span := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if span < 0.0001:
		return
	mi.scale = Vector3.ONE * (target_span / span)
	mi.position = -aabb.get_center() * mi.scale.x


static func apply_jack(mat: StandardMaterial3D) -> void:
	if mat == null:
		return
	var maps := _club_maps()
	_apply_pbr(mat, maps)
	if maps["jack"] != null:
		mat.albedo_texture = maps["jack"]
		mat.albedo_color = Color(1.0, 1.0, 1.0)
	else:
		mat.albedo_texture = null
		mat.albedo_color = Color(0.96, 0.94, 0.88)


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
