class_name CrazyGreen
extends Node3D

## A bowls-golf hole: the club lawn, a bit wider, with rolls in the grass.

const SURFACE_Y := 0.0
const CUP_DEPTH := 0.32
const NEAR_Z := 2.2

var hole: Dictionary = {}
var tee := Vector3(0.0, 0.0, -1.55)
var cup := Vector3(0.0, 0.0, -22.0)
var cup_radius := 0.7
var LENGTH := 36.0
var HALF_WIDTH := 8.0
var FAR_Z := -36.0
var chase := true
var pose_lock := false
var water_spots: Array = []
var tree_spots: Array = []
var bumps: Array = []

var _camera: Camera3D
var _grass_shader: Shader
var _wood_shader: Shader
var _lawn_tex: Texture2D
var _wood_mat: ShaderMaterial
var _white_line: StandardMaterial3D
var _gold: StandardMaterial3D
var _leaf_mats: Array[StandardMaterial3D] = []
var _trunk_mat: StandardMaterial3D
var _cam_pos := Vector3(0.0, 0.78, 1.6)
var _cam_look := Vector3(0.0, 0.12, -12.0)
var _cam_fov := 46.0
var _cam_ready := false
var _shot_pos := Vector3.ZERO
var _shot_live := false
var _aiming := false
var _mat := Vector3.ZERO
var _head := Vector3.ZERO
var _head_hold := false


func setup_hole(next: Dictionary) -> void:
	hole = next
	tee = next["tee"]
	cup = next["cup"]
	cup_radius = float(next["cup_radius"])
	LENGTH = float(next["length"])
	HALF_WIDTH = float(next["half"])
	FAR_Z = -LENGTH
	bumps = next["bumps"]
	water_spots = next["waters"]
	tree_spots = next["trees"]
	_mat = tee
	_head = cup
	_shot_pos = tee


func height_at(x: float, z: float) -> float:
	var h := 0.0
	for bump in bumps:
		var at: Vector3 = bump["pos"]
		var radius: float = maxf(float(bump["radius"]), 0.4)
		var rise: float = float(bump["height"])
		var u := Vector2(x - at.x, z - at.z).length() / radius
		if u < 1.0:
			var w := 1.0 - u * u
			h += rise * w * w
	for pond in water_spots:
		var at: Vector3 = pond["pos"]
		var radius: float = float(pond["radius"])
		var u := Vector2(x - at.x, z - at.z).length() / maxf(radius, 0.4)
		if u < 1.0:
			h -= 0.28 * (1.0 - u * u)
	var cup_u := Vector2(x - cup.x, z - cup.z).length() / maxf(cup_radius * 1.7, 0.5)
	if cup_u < 1.0:
		h -= 0.07 * (1.0 - cup_u * cup_u)
	return h


func _ready() -> void:
	_grass_shader = load("res://shaders/grass.gdshader")
	_lawn_tex = load("res://assets/grass/lawn_cut.jpg")
	_wood_shader = load("res://shaders/wood.gdshader")
	_wood_mat = ShaderMaterial.new()
	_wood_mat.shader = _wood_shader
	_white_line = _lit(Color(0.96, 0.98, 0.95), 0.42, 0.0, Color(0.95, 1.0, 0.96), 0.22)
	_gold = _lit(Color(0.95, 0.78, 0.32), 0.38, 0.45, Color(1.0, 0.86, 0.4), 0.15)
	_trunk_mat = _lit(Color(0.40, 0.26, 0.14), 0.86)
	for green in [Color(0.20, 0.72, 0.28), Color(0.12, 0.55, 0.22), Color(0.32, 0.82, 0.30)]:
		_leaf_mats.append(_lit(green, 0.9))
	_build_environment()
	_build_lights()
	_build_camera()
	_build_outfield()
	_build_fairway()
	_build_rails()
	_build_cup()
	_build_water()
	_build_trees()
	_build_markings()


func view_camera() -> Camera3D:
	return _camera


func note_delivery(pos: Vector3, _vel: Vector3, live: bool, mat: Vector3, head_at: Vector3, aiming: bool = false) -> void:
	_shot_pos = pos
	_shot_live = live
	_mat = mat
	_aiming = aiming
	if not _head_hold:
		_head = head_at


func focus_pair(a: Vector3, b: Vector3) -> void:
	_head = (a + b) * 0.5
	_head_hold = true


func focus_cup() -> void:
	_head = cup
	_head_hold = true


func release_head() -> void:
	_head_hold = false


func reset_view() -> void:
	_head_hold = false
	_shot_live = false
	_aiming = false
	_cam_ready = false
	_mat = tee
	_head = cup
	_shot_pos = tee


func _process(delta: float) -> void:
	if _camera == null or pose_lock:
		return
	var goal_pos := Vector3.ZERO
	var goal_look := Vector3.ZERO
	var goal_fov := 46.0
	var response := 5.0
	if _head_hold:
		goal_pos = _head + Vector3(0.35, 3.4, 5.4)
		goal_look = _head + Vector3(0.0, 0.1, 0.0)
		goal_fov = 38.0
		response = 2.8
	elif _aiming and not _shot_live:
		goal_pos = Vector3(_shot_pos.x, 1.12, _shot_pos.z + 2.85)
		goal_look = Vector3(cup.x * 0.28, 0.1, _shot_pos.z - 10.0)
		goal_fov = 44.0
		response = 3.6
	elif _shot_live and chase:
		var cam_x := clampf(_shot_pos.x, -HALF_WIDTH + 1.1, HALF_WIDTH - 1.1)
		goal_pos = Vector3(cam_x, 1.22, _shot_pos.z + 3.0)
		goal_look = Vector3(cam_x, 0.14, _shot_pos.z - 5.6)
		var to_cup := _shot_pos.distance_to(cup)
		if to_cup < 9.0:
			var ease := 1.0 - clampf(to_cup / 9.0, 0.0, 1.0)
			goal_pos.y = lerpf(1.22, 1.85, ease)
			goal_pos.z = _shot_pos.z + lerpf(3.0, 4.0, ease)
		goal_fov = 42.0
		response = 5.4
	else:
		goal_pos = Vector3(tee.x, 0.78, tee.z + 2.35)
		goal_look = Vector3(cup.x * 0.18, 0.14, tee.z - minf(18.0, LENGTH * 0.48))
		goal_fov = 44.0
		response = 7.0
	if not _cam_ready:
		_cam_pos = goal_pos
		_cam_look = goal_look
		_cam_fov = goal_fov
		_cam_ready = true
	var blend := 1.0 - exp(-response * delta)
	_cam_pos = _cam_pos.lerp(goal_pos, blend)
	_cam_look = _cam_look.lerp(goal_look, blend)
	_cam_fov = lerpf(_cam_fov, goal_fov, blend)
	_camera.position = _cam_pos
	_camera.fov = _cam_fov
	var toward := _cam_look - _cam_pos
	if toward.length() > 0.5 and absf(toward.normalized().dot(Vector3.UP)) < 0.96:
		_camera.look_at(_cam_look, Vector3.UP)


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.34, 0.60, 0.95)
	sky_mat.sky_horizon_color = Color(0.62, 0.80, 0.96)
	sky_mat.ground_bottom_color = Color(0.15, 0.32, 0.18)
	sky_mat.ground_horizon_color = Color(0.66, 0.78, 0.64)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.90, 0.98)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.05
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0028
	env.fog_light_color = Color(0.76, 0.86, 0.95)
	world.environment = env
	add_child(world)


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.26
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.28, -1.2, -0.18), Vector3.UP)
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.70, 0.80, 1.0)
	fill.light_energy = 0.46
	fill.look_at_from_position(Vector3.ZERO, Vector3(-0.35, -0.9, -0.25), Vector3.UP)
	add_child(fill)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "GameCamera"
	_camera.fov = 46.0
	_camera.near = 0.08
	_camera.far = 280.0
	_camera.current = true
	add_child(_camera)


func _build_outfield() -> void:
	var rough := _grass_material(Color(0.28, 0.62, 0.18), Color(0.16, 0.46, 0.12), 1.5, 28.0, 0.04, true, 1.7)
	var span := maxf(36.0, HALF_WIDTH * 5.0)
	_quad(Vector3(0.0, -0.06, -LENGTH * 0.45), Vector2(span, LENGTH + 22.0), rough)


func _build_fairway() -> void:
	var nx := 52
	var nz := 70
	var min_x := -HALF_WIDTH
	var max_x := HALF_WIDTH
	var min_z := FAR_Z
	var max_z := NEAR_Z
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idxs := PackedInt32Array()
	for j in nz + 1:
		var tz := float(j) / float(nz)
		var z := lerpf(max_z, min_z, tz)
		for i in nx + 1:
			var tx := float(i) / float(nx)
			var x := lerpf(min_x, max_x, tx)
			var y := height_at(x, z)
			verts.append(Vector3(x, y, z))
			uvs.append(Vector2(x * 0.28, z * 0.28))
			var hx := height_at(x + 0.25, z) - y
			var hz := height_at(x, z + 0.25) - y
			var n := Vector3(-hx, 0.25, -hz)
			if n.length() < 0.001:
				n = Vector3.UP
			norms.append(n.normalized())
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			idxs.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := MeshInstance3D.new()
	surface.name = "PlayingGreen"
	surface.mesh = mesh
	surface.material_override = _grass_material(
		Color(0.40, 0.82, 0.20),
		Color(0.16, 0.60, 0.16),
		0.48,
		HALF_WIDTH,
		0.08,
		true,
		0.88
	)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)


func _build_rails() -> void:
	var y := 0.08
	var rail_w := 0.24
	var side_len := LENGTH + NEAR_Z + 0.4
	var side_z := -LENGTH * 0.5 + NEAR_Z * 0.5
	_box(self, Vector3(HALF_WIDTH + rail_w * 0.35, y, side_z), Vector3(rail_w, 0.16, side_len), _wood_mat)
	_box(self, Vector3(-HALF_WIDTH - rail_w * 0.35, y, side_z), Vector3(rail_w, 0.16, side_len), _wood_mat)
	_box(self, Vector3(0.0, y, FAR_Z - 0.12), Vector3(HALF_WIDTH * 2.0 + rail_w * 1.6, 0.16, rail_w), _wood_mat)
	_box(self, Vector3(0.0, y, NEAR_Z + 0.08), Vector3(HALF_WIDTH * 2.0 + rail_w * 1.6, 0.16, rail_w), _wood_mat)


func _build_cup() -> void:
	var well := _lit(Color(0.06, 0.04, 0.03), 0.95)
	var y := height_at(cup.x, cup.z)
	_cylinder(self, Vector3(cup.x, y - CUP_DEPTH * 0.45, cup.z), cup_radius * 0.96, CUP_DEPTH, well, Vector3.ZERO, 24, false)
	_ring(Vector3(cup.x, y + 0.02, cup.z), cup_radius * 1.14, cup_radius * 0.92, _white_line)
	var flag := Node3D.new()
	flag.position = Vector3(cup.x, y, cup.z)
	add_child(flag)
	_cylinder(flag, Vector3(0.0, 0.85, 0.0), 0.018, 1.7, _gold, Vector3.ZERO, 8, false)
	_box(flag, Vector3(0.28, 1.55, 0.0), Vector3(0.52, 0.28, 0.02), _lit(Color(0.88, 0.16, 0.18), 0.48))


func _build_water() -> void:
	var water := _lit(Color(0.18, 0.42, 0.62, 0.86), 0.12, 0.08, Color(0.25, 0.55, 0.72), 0.18)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for pond in water_spots:
		var at: Vector3 = pond["pos"]
		var radius: float = float(pond["radius"])
		_cylinder(self, Vector3(at.x, -0.04, at.z), radius, 0.08, water, Vector3.ZERO, 22, false)


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + int(hole.get("number", 1)) * 13
	for tree in tree_spots:
		var at: Vector3 = tree["pos"]
		var scale: float = float(tree.get("scale", 1.0))
		var leaf: StandardMaterial3D = _leaf_mats[rng.randi() % _leaf_mats.size()]
		var y := height_at(at.x, at.z)
		_cylinder(self, Vector3(at.x, y + 0.7 * scale, at.z), 0.09 * scale, 1.35 * scale, _trunk_mat, Vector3.ZERO, 8)
		_sphere(self, Vector3(at.x, y + 1.6 * scale, at.z), 0.84 * scale, leaf, 12)


func _build_markings() -> void:
	var y := 0.03
	_box(self, Vector3(0.0, y, tee.z + 0.35), Vector3(2.2, 0.012, 0.06), _white_line, Vector3.ZERO, false)
	_box(self, Vector3(0.0, y, tee.z + 0.02), Vector3(0.06, 0.012, 0.7), _white_line, Vector3.ZERO, false)


func _quad(pos: Vector3, size: Vector2, mat: Material) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	ground.mesh = plane
	ground.position = pos
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _grass_material(a: Color, b: Color, stripe: float, half: float, fade: float, cut: bool, cut_scale: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _grass_shader
	mat.set_shader_parameter("stripe_a", a)
	mat.set_shader_parameter("stripe_b", b)
	mat.set_shader_parameter("stripe_width", stripe)
	mat.set_shader_parameter("half_width", half)
	mat.set_shader_parameter("depth_fade", fade)
	if cut and _lawn_tex != null:
		mat.set_shader_parameter("grass_tex", _lawn_tex)
		mat.set_shader_parameter("grass_tex_scale", cut_scale)
		mat.set_shader_parameter("use_grass_tex", true)
	return mat


func _lit(color: Color, roughness: float, metallic: float = 0.0, emission: Color = Color(0, 0, 0), emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, shadows: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, rot: Vector3 = Vector3.ZERO, segments: int = 16, shadows: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material, segments: int = 12) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(4, segments / 2)
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _ring(at: Vector3, outer_r: float, inner_r: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 40
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var o0 := Vector3(cos(a0) * outer_r, 0.0, sin(a0) * outer_r)
		var o1 := Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r)
		var i0 := Vector3(cos(a0) * inner_r, 0.0, sin(a0) * inner_r)
		var i1 := Vector3(cos(a1) * inner_r, 0.0, sin(a1) * inner_r)
		st.set_normal(Vector3.UP)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i1)
		st.add_vertex(o0)
		st.add_vertex(i1)
		st.add_vertex(i0)
	mi.mesh = st.commit()
	mi.position = at
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
