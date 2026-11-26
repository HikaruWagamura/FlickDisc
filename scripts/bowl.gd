class_name Bowl
extends Node3D

## A bowl or the jack on the green. Motion is owned by the table in DiscController.
## Settled bowls stay where they stop, and later bowls can knock them.
## Red is one side, blue is the other. Each side bowls four in an end.
## Playable bowls are the purchased CGTrader set: four full lawn-bowl
## meshes (LAZER / BLAZE / ACE / CLASSIC) plus a half-size jack, with the
## four pack colours. The earlier Tripo sculpt is not used on the green.

const DISC_RADIUS := 0.20
const JACK_RADIUS := 0.16
const DISC_MASS := 2.45
const JACK_MASS := 0.52
## Lawn bowls kiss and push. A high bounce reads as snooker, not grass.
const DISC_RESTITUTION := 0.55
const JACK_RESTITUTION := 0.48
const CONTACT_FRICTION := 0.34
const WIDE_BIAS := 2
## The running surface kisses the grass. A few millimetres of contact,
## so the bowl sits on the green and the shade falls beside it.
const SIT_NEST := 0.0
const GROUND_CLEAR := 0.002
const CLUB_SCENE := preload("res://assets/bowls/modern_lawn_bowls.fbx")
const Kit := preload("res://scripts/kit.gd")
const CLUB_NAMES := ["ball_1", "ball_2", "ball_3", "ball_4"]
const JACK_NAME := "ball_1_1"

static var _club_meshes: Array[Mesh] = []
static var _jack_mesh: Mesh
static var _next_club_variant := 0
static var _maps_cache: Dictionary = {}
static var _chip_cache: Dictionary = {}
var _bowl_sit := DISC_RADIUS + GROUND_CLEAR

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
var is_toucher := false
var palette_index := 0
var bias_type := 1
var hand_sign := -1.0
## Kept so a finished bowl can remember the delivery. The mesh stays on the grass.
var lean := 0.0
var travel := Vector3.ZERO

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


static func team_color(index: int) -> Color:
	return Color(0.14, 0.34, 0.88) if index % 2 == 1 else Color(0.82, 0.08, 0.14)


static func apply_team(mat: StandardMaterial3D, index: int, _wide: bool = false) -> void:
	if mat == null:
		return
	var maps := _club_maps()
	_apply_pbr(mat, maps)
	var tex: Texture2D = maps["red"] if index % 2 == 0 else maps["blue"]
	if tex == null:
		tex = maps["albedo"]
	if tex != null:
		mat.albedo_texture = tex
		mat.albedo_color = Color(1.0, 1.0, 1.0)
	else:
		mat.albedo_texture = null
		mat.albedo_color = team_color(index)
	mat.roughness = 0.5


static func tint_band(mat: StandardMaterial3D, index: int) -> void:
	if mat == null:
		return
	# Rings and dimples are modelled in the pack mesh. Keep them pale so
	# the terrazzo body stays the team colour.
	var cream := Color(0.93, 0.90, 0.84) if index % 2 == 0 else Color(0.88, 0.92, 0.97)
	mat.albedo_texture = null
	mat.albedo_color = cream
	mat.roughness = 0.32


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
		"green": _load_tex("res://assets/bowls/textures/bowl_color_2.jpg"),
		"orange": _load_tex("res://assets/bowls/textures/bowl_color_4.jpg"),
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
	# No mipmaps: spinning with mips is what made the pack grain go fuzzy.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	# Pack albedo keeps the square bite. The baked normal reprints that
	# grid and shimmers while the bowl rolls, which reads as blur.
	mat.normal_enabled = false
	mat.normal_texture = null
	# Scratch/rough maps shimmer while the bowl rolls. Keep the body smooth.
	mat.roughness_texture = null
	mat.roughness = 0.5
	if maps["metallic"] != null:
		mat.metallic_texture = maps["metallic"]
		mat.metallic = 1.0


static func hand_yaw(hand: float) -> float:
	# The coloured grip faces the bowler, so the grooves read from the mat.
	# The other hand turns half a turn and the bias still follows the hand.
	return 1.5 * PI if signf(hand) < 0.0 else 0.5 * PI


static func bowl_type(index: int) -> Dictionary:
	var types := [
		# Bias is the draw for the whole run. Finish is the late cut.
		# Pace is extra weight; shop fire bowls will raise this later.
		# Hand (fore/back) still flips the side.
		{"name": "LAZER", "bias": 1.05, "finish": 0.20, "pace": 1.00},
		{"name": "BLAZE", "bias": 1.42, "finish": 1.05, "pace": 1.04},
		{"name": "ACE", "bias": 1.82, "finish": 0.75, "pace": 1.08},
		{"name": "CLASSIC", "bias": 2.18, "finish": 1.50, "pace": 1.12},
	]
	return types[index % types.size()]


static func chip_texture(team: int, bias: int) -> Texture2D:
	var key := "%d_%d" % [team % 2, bias % 4]
	if _chip_cache.has(key):
		return _chip_cache[key]
	var maps := _club_maps()
	var src: Texture2D = maps["blue"] if team % 2 == 1 else maps["red"]
	var src_img: Image = src.get_image() if src != null else null
	if src_img != null and src_img.is_compressed():
		src_img.decompress()
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var open := 0.16 + float(bias % 4) * 0.13
	for y in size:
		for x in size:
			var nx := (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(size) * 2.0 - 1.0
			var r2 := nx * nx + ny * ny
			if r2 > 1.0:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - r2))
			var u := 0.5 + atan2(nx, nz) / TAU
			var v := 0.5 - ny * 0.48
			var col := team_color(team)
			if src_img != null:
				var sx := clampi(int(clampf(u, 0.0, 0.999) * float(src_img.get_width())), 0, src_img.get_width() - 1)
				var sy := clampi(int(clampf(v, 0.0, 0.999) * float(src_img.get_height())), 0, src_img.get_height() - 1)
				col = src_img.get_pixel(sx, sy)
			var ring := absf(ny)
			if ring > 0.20 and ring < 0.28:
				col = col.lerp(Color(0.94, 0.91, 0.84), 0.78)
			if ring > 0.32 and ring < 0.39:
				col = col.lerp(Color(0.94, 0.91, 0.84), 0.52)
			var pip := Vector2(open, -0.05)
			if Vector2(nx, ny).distance_to(pip) < 0.20:
				col = col.lerp(Color(0.97, 0.95, 0.90), 0.72)
			var light := clampf(0.40 + nz * 0.72 + nx * 0.14 - ny * 0.08, 0.22, 1.18)
			var alpha := 1.0
			if r2 > 0.90:
				alpha = clampf((1.0 - r2) / 0.10, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r * light, col.g * light, col.b * light, alpha))
	var tex := ImageTexture.create_from_image(img)
	_chip_cache[key] = tex
	return tex


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
	var bias_changed := false
	if bias >= 0 and bias != bias_type:
		bias_type = bias
		bias_changed = true
	elif bias >= 0:
		bias_type = bias
	radius = DISC_RADIUS
	mass = DISC_MASS
	is_jack = false
	if _spin == null:
		_build_disc(index, hand)
		return
	if bias_changed:
		for child in _spin.get_children():
			_spin.remove_child(child)
			child.free()
		var dressed: Dictionary = dress_stone(_spin, index, hand, false, bias_type)
		_rim_mat = dressed["rim"]
		_body_mat = dressed["body"]
		_cap_mat = dressed["cap"]
		_mark_mat = dressed["mark"]
		_pip = dressed["weight"]
		_paint_club_if_custom(index)
		_bowl_sit = DISC_RADIUS - SIT_NEST + GROUND_CLEAR
		set_hand(hand)
		return
	apply_team(_body_mat, index, false)
	tint_band(_rim_mat, index)
	tint_band(_cap_mat, index)
	tint_band(_mark_mat, index)
	_paint_club_if_custom(index)
	_bowl_sit = DISC_RADIUS - SIT_NEST + GROUND_CLEAR
	set_hand(hand)


func _paint_club_if_custom(index: int) -> void:
	if index % 2 != 0:
		return
	var holder := _spin.get_node_or_null("ClubBowl") if _spin != null else null
	if holder is Node3D:
		Kit.paint_holder(holder, Kit.from_meta(Engine.get_main_loop() as SceneTree), false)


static func roll_basis_by(current: Basis, travel: Vector3, body_radius: float) -> Basis:
	var flat := Vector3(travel.x, 0.0, travel.z)
	var dist := flat.length()
	if dist < 0.00005 or body_radius < 0.001:
		return current
	var axis := Vector3.UP.cross(flat / dist)
	if axis.length() < 0.001:
		return current
	# A full roll strobes the terrazzo. Keep the spin readable.
	return Basis(axis.normalized(), dist / body_radius * 0.58) * current


func setup_jack() -> void:
	radius = JACK_RADIUS
	mass = JACK_MASS
	is_jack = true
	_build_jack()


func rest_at(where: Vector3) -> void:
	in_ditch = false
	is_toucher = false
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
	_spin.position.y = _bowl_sit
	_spin.transform.basis = roll_basis
	_seat_shadow(radius)


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
	# The paid pack is the bowl you play. Each bias uses one of the four meshes.
	var dressed: Dictionary = dress_stone(_spin, index, hand, false, bias_type)
	_rim_mat = dressed["rim"]
	_body_mat = dressed["body"]
	_cap_mat = dressed["cap"]
	_mark_mat = dressed["mark"]
	_pip = dressed["weight"]
	_paint_club_if_custom(index)
	_bowl_sit = DISC_RADIUS - SIT_NEST + GROUND_CLEAR
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
		_fit_mesh(ball, JACK_RADIUS * 2.0, true)
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
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(ball)


func _make_shadow(size: float) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = size * 0.42
	shadow_mesh.bottom_radius = size * 0.62
	shadow_mesh.height = 0.003
	shadow_mesh.radial_segments = 24
	shadow.mesh = shadow_mesh
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.albedo_color = Color(0.02, 0.05, 0.03, 0.32)
	shadow.material_override = shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = Vector3(size * 0.22, 0.002, size * 0.28)
	return shadow


func _seat_shadow(body_radius: float) -> void:
	if _shadow == null:
		return
	var mesh := _shadow.mesh as CylinderMesh
	if mesh != null:
		mesh.top_radius = body_radius * 0.7
		mesh.bottom_radius = body_radius * 0.92
		mesh.height = 0.002
	_shadow.position = Vector3(0.0, 0.001, body_radius * 0.04)
	_shadow.visible = global_position.y > -0.06


static func dress_stone(parent: Node3D, index: int, hand: float, wide: bool = false, variant: int = 0) -> Dictionary:
	# The four pack meshes are the four biases. The old sculpt is not used.
	return _dress_club(parent, index, hand, variant)


static func _dress_club(parent: Node3D, index: int, hand: float, variant: int = 0) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "ClubBowl"
	parent.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = club_mesh(variant)
	if mi.mesh != null:
		_fit_mesh(mi, DISC_RADIUS * 2.0, true)
	else:
		var sphere := SphereMesh.new()
		sphere.radius = DISC_RADIUS
		sphere.height = DISC_RADIUS * 2.0
		sphere.radial_segments = 28
		sphere.rings = 14
		mi.mesh = sphere
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	holder.rotation = Vector3(0.0, hand_yaw(hand), 0.0)
	var body := StandardMaterial3D.new()
	body.roughness = 0.38
	body.metallic = 0.06
	body.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	apply_team(body, index, false)
	var ring := StandardMaterial3D.new()
	ring.roughness = 0.32
	ring.metallic = 0.04
	ring.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	tint_band(ring, index)
	var mark := StandardMaterial3D.new()
	mark.roughness = 0.3
	mark.metallic = 0.04
	tint_band(mark, index)
	if mi.mesh != null and mi.mesh.get_surface_count() > 1:
		mi.set_surface_override_material(0, body)
		mi.set_surface_override_material(1, ring)
		if mi.mesh.get_surface_count() > 2:
			mi.set_surface_override_material(2, mark)
	else:
		mi.material_override = body
	return {"rim": ring, "body": body, "cap": mark, "mark": mark, "weight": holder}


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
	if CLUB_SCENE == null:
		return
	var root: Node = CLUB_SCENE.instantiate()
	for name in CLUB_NAMES:
		var mi := _named_mesh(root, PackedStringArray([name]))
		if mi != null and mi.mesh != null:
			_club_meshes.append(mi.mesh)
	var jack_mi := _named_mesh(root, PackedStringArray([JACK_NAME, "Sphere"]))
	if jack_mi != null:
		_jack_mesh = jack_mi.mesh
	if _club_meshes.is_empty():
		_collect_club_meshes(root, jack_mi)
	root.free()


static func _collect_club_meshes(node: Node, jack_mi: MeshInstance3D) -> void:
	if node is MeshInstance3D and node != jack_mi and (node as MeshInstance3D).mesh != null:
		_club_meshes.append((node as MeshInstance3D).mesh)
	for child in node.get_children():
		_collect_club_meshes(child, jack_mi)


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


static func sit_from_holder(holder: Node3D) -> float:
	if holder == null:
		return DISC_RADIUS + GROUND_CLEAR
	var mi := _first_mesh(holder)
	if mi == null or mi.mesh == null:
		return DISC_RADIUS + GROUND_CLEAR
	var box: AABB = mi.mesh.get_aabb()
	var xf := mi.transform
	if holder.is_inside_tree() and mi.is_inside_tree():
		xf = holder.global_transform.affine_inverse() * mi.global_transform
	var bottom := INF
	for i in 8:
		var corner := box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)
		bottom = minf(bottom, (xf * corner).y)
	if bottom == INF or is_nan(bottom):
		return DISC_RADIUS + GROUND_CLEAR
	return -bottom + GROUND_CLEAR


static func _fit_mesh(mi: MeshInstance3D, target_span: float, keep_bias: bool = false) -> void:
	if mi.mesh == null:
		return
	var aabb := mi.mesh.get_aabb()
	var span := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if keep_bias:
		span = maxf(aabb.size.x, aabb.size.z)
	if span < 0.0001:
		return
	mi.scale = Vector3.ONE * (target_span / span)
	mi.position = -aabb.get_center() * mi.scale.x


static func apply_jack(mat: StandardMaterial3D) -> void:
	if mat == null:
		return
	var maps := _club_maps()
	_apply_pbr(mat, maps)
	mat.normal_enabled = false
	mat.normal_texture = null
	mat.roughness = 0.56
	if maps["jack"] != null:
		mat.albedo_texture = maps["jack"]
		mat.albedo_color = Color(1.0, 1.0, 1.0)
	else:
		mat.albedo_texture = null
		mat.albedo_color = Color(0.93, 0.90, 0.82)


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
