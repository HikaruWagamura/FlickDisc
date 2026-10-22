class_name RinkView
extends Node3D

## Long lawn-bowls rink. The playing surface is 68 m by 11 m.
## Banks rebound unless ditch mode is on. Then a narrow ditch at each side
## and at the far end can take a bowl, and two spare jacks sit on the back bank.

const LENGTH := 68.0
const HALF_WIDTH := 5.5
const DITCH_W := 0.88
const SHORT_MIN := 14.0
const SHORT_MAX := 28.0
const LONG_MIN := 44.0
const NEAR_Z := 0.0
const FAR_Z := -LENGTH
const DISC_Z := -1.65
const SURFACE_Y := 0.0

var head: Node3D
var _camera: Camera3D
var _home_position := Vector3(0.0, 9.2, 10.8)
var _home_look := Vector3(0.0, 0.28, -18.0)
var _home_fov := 49.0
var _zoom_position := Vector3(0.0, 9.2, 10.8)
var _zoom_look := Vector3(0.0, 0.28, -18.0)
var _zoom_fov := 34.0
var _zoom_weight := 0.0
var _zoom_goal := 0.0
var _rebound_frame: Node3D
var _ditch_frame: Node3D
var _spare_dots: Array[MeshInstance3D] = []

var _grass_shader: Shader
var _wood_shader: Shader
var _path_shader: Shader
var _wood_mat: ShaderMaterial
var _path_mat: ShaderMaterial
var _leaf_mats: Array[StandardMaterial3D] = []
var _trunk_mat: StandardMaterial3D
var _flower_mats: Array[StandardMaterial3D] = []
var _stem_mat: StandardMaterial3D
var _white_line: StandardMaterial3D
var _gold: StandardMaterial3D


func _ready() -> void:
	_grass_shader = load("res://shaders/grass.gdshader")
	_wood_shader = load("res://shaders/wood.gdshader")
	_path_shader = load("res://shaders/path.gdshader")
	_prepare_materials()
	_build_environment()
	_build_lights()
	_build_camera()
	_build_grounds()
	_build_playing_surface()
	_build_surrounds()
	_build_clubhouse()
	_build_head()


func place_head(jack_xz: Vector2) -> void:
	if head == null:
		return
	head.position = Vector3(jack_xz.x, SURFACE_Y, jack_xz.y)
	head.visible = true


func set_head_visible(show_head: bool) -> void:
	if head != null:
		head.visible = show_head


func _prepare_materials() -> void:
	_wood_mat = ShaderMaterial.new()
	_wood_mat.shader = _wood_shader
	_path_mat = ShaderMaterial.new()
	_path_mat.shader = _path_shader
	_trunk_mat = _lit(Color(0.40, 0.26, 0.14), 0.86)
	_stem_mat = _lit(Color(0.22, 0.48, 0.20), 0.8)
	var greens := [
		Color(0.17, 0.42, 0.20),
		Color(0.12, 0.34, 0.16),
		Color(0.22, 0.48, 0.22),
		Color(0.10, 0.30, 0.14),
	]
	for green in greens:
		_leaf_mats.append(_lit(green, 0.9))
	var petals := [
		Color(0.94, 0.32, 0.46),
		Color(0.98, 0.82, 0.28),
		Color(0.97, 0.97, 0.95),
		Color(0.64, 0.38, 0.86),
		Color(1.0, 0.55, 0.22),
	]
	for petal in petals:
		_flower_mats.append(_lit(petal, 0.55))
	_white_line = _lit(Color(0.96, 0.98, 0.95), 0.42, 0.0, Color(0.95, 1.0, 0.96), 0.22)
	_gold = _lit(Color(0.95, 0.78, 0.32), 0.38, 0.45, Color(1.0, 0.86, 0.4), 0.15)


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.34, 0.60, 0.95)
	sky_mat.sky_horizon_color = Color(0.62, 0.80, 0.96)
	sky_mat.sky_curve = 0.38
	sky_mat.ground_bottom_color = Color(0.15, 0.32, 0.18)
	sky_mat.ground_horizon_color = Color(0.66, 0.78, 0.64)
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 26.0
	sky_mat.sun_curve = 0.07
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0026
	env.fog_light_color = Color(0.76, 0.86, 0.95)
	env.fog_aerial_perspective = 0.28
	env.fog_sun_scatter = 0.12
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.06
	world.environment = env
	add_child(world)

	var cloud_mat := ShaderMaterial.new()
	cloud_mat.shader = load("res://shaders/cloud.gdshader")
	var clouds := [
		[Vector3(-7.0, 16.0, -8.0), Vector2(16.0, 5.2)],
		[Vector3(8.5, 17.5, -18.0), Vector2(18.0, 4.6)],
		[Vector3(-2.0, 18.5, -30.0), Vector2(14.0, 4.0)],
		[Vector3(6.0, 15.5, 2.0), Vector2(12.0, 3.6)],
	]
	for cloud in clouds:
		var quad := QuadMesh.new()
		quad.size = cloud[1]
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.position = cloud[0]
		mi.material_override = cloud_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.08
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.4
	sun.shadow_blur = 1.15
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_blend_splits = true
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.42, -1.05, 0.48), Vector3.UP)
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = Color(0.70, 0.80, 1.0)
	fill.light_energy = 0.32
	fill.shadow_enabled = false
	fill.look_at_from_position(Vector3.ZERO, Vector3(-0.35, -0.9, -0.25), Vector3.UP)
	add_child(fill)


func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "GameCamera"
	camera.fov = 49.0
	camera.near = 0.08
	camera.far = 240.0
	camera.position = Vector3(0.0, 9.2, 10.8)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.28, -18.0), Vector3.UP)
	camera.current = true
	add_child(camera)
	_camera = camera
	_home_position = camera.position
	_home_look = Vector3(0.0, 0.28, -18.0)
	_home_fov = camera.fov
	_zoom_position = _home_position
	_zoom_look = _home_look


func _process(delta: float) -> void:
	if _camera == null:
		return
	var previous := _zoom_weight
	_zoom_weight = move_toward(_zoom_weight, _zoom_goal, delta * 0.85)
	if absf(_zoom_weight - previous) < 0.0001:
		return
	var blend := _zoom_weight * _zoom_weight * (3.0 - 2.0 * _zoom_weight)
	_camera.position = _home_position.lerp(_zoom_position, blend)
	_camera.fov = lerpf(_home_fov, _zoom_fov, blend)
	var look_at := _home_look.lerp(_zoom_look, blend)
	_camera.look_at(look_at, Vector3.UP)


func view_camera() -> Camera3D:
	return _camera


func focus_head(at: Vector3) -> void:
	# Wide enough to show a bowl that has taken its hand a few metres
	# off the jack, with the jack still in the middle.
	_zoom_look = at + Vector3(0.0, 0.2, 0.0)
	_zoom_position = at + Vector3(0.0, 14.0, 18.0)
	_zoom_fov = 42.0
	_zoom_goal = 1.0


func release_head() -> void:
	_zoom_goal = 0.0


func _build_grounds() -> void:
	var outfield := _grass_material(
		Color(0.22, 0.40, 0.16),
		Color(0.16, 0.32, 0.12),
		1.35,
		40.0,
		0.05
	)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100.0, 160.0)
	ground.mesh = plane
	ground.position = Vector3(0.0, -0.04, -48.0)
	ground.material_override = outfield
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	_hill(Vector3(-18.0, -4.5, -96.0), 16.0, Color(0.45, 0.58, 0.62))
	_hill(Vector3(2.0, -6.0, -104.0), 18.0, Color(0.40, 0.55, 0.50))
	_hill(Vector3(20.0, -5.0, -94.0), 15.0, Color(0.50, 0.62, 0.66))


func _build_playing_surface() -> void:
	var surface := MeshInstance3D.new()
	surface.name = "PlayingGreen"
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF_WIDTH * 2.0, LENGTH)
	surface.mesh = plane
	surface.position = Vector3(0.0, SURFACE_Y, -LENGTH * 0.5)
	surface.material_override = _grass_material(
		Color(0.26, 0.44, 0.15),
		Color(0.16, 0.32, 0.11),
		0.46,
		HALF_WIDTH,
		0.1
	)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)

	_timber_frame()
	_build_ditch_option()
	_markings()


func _timber_frame() -> void:
	var rail_h := 0.15
	var rail_w := 0.26
	var y := rail_h * 0.5
	var side_len := LENGTH + 0.36
	var side_z := -LENGTH * 0.5
	# The near bank always rebounds. Side and far banks are the rebound option.
	var end_w := HALF_WIDTH * 2.0 + rail_w * 1.7
	_box(self, Vector3(0.0, y, 0.12), Vector3(end_w, rail_h, rail_w), _wood_mat)
	_rebound_frame = Node3D.new()
	_rebound_frame.name = "ReboundBanks"
	add_child(_rebound_frame)
	_box(_rebound_frame, Vector3(HALF_WIDTH + rail_w * 0.35, y, side_z), Vector3(rail_w, rail_h, side_len), _wood_mat)
	_box(_rebound_frame, Vector3(-HALF_WIDTH - rail_w * 0.35, y, side_z), Vector3(rail_w, rail_h, side_len), _wood_mat)
	_box(_rebound_frame, Vector3(0.0, y, FAR_Z - 0.12), Vector3(end_w, rail_h, rail_w), _wood_mat)
	var cap := _lit(Color(0.94, 0.86, 0.68), 0.55)
	var cap_y := rail_h + 0.012
	_box(_rebound_frame, Vector3(HALF_WIDTH + rail_w * 0.35, cap_y, side_z), Vector3(rail_w * 0.72, 0.025, side_len), cap, Vector3.ZERO, false)
	_box(_rebound_frame, Vector3(-HALF_WIDTH - rail_w * 0.35, cap_y, side_z), Vector3(rail_w * 0.72, 0.025, side_len), cap, Vector3.ZERO, false)


func _build_ditch_option() -> void:
	_ditch_frame = Node3D.new()
	_ditch_frame.name = "DitchOption"
	_ditch_frame.visible = false
	add_child(_ditch_frame)
	var ditch_mat := _lit(Color(0.18, 0.13, 0.08), 0.98)
	var side_len := LENGTH + DITCH_W
	var side_z := -LENGTH * 0.5 - DITCH_W * 0.35
	_box(_ditch_frame, Vector3(HALF_WIDTH + DITCH_W * 0.5, -0.16, side_z), Vector3(DITCH_W, 0.08, side_len), ditch_mat, Vector3.ZERO, false)
	_box(_ditch_frame, Vector3(-HALF_WIDTH - DITCH_W * 0.5, -0.16, side_z), Vector3(DITCH_W, 0.08, side_len), ditch_mat, Vector3.ZERO, false)
	_box(_ditch_frame, Vector3(0.0, -0.16, FAR_Z - DITCH_W * 0.5), Vector3(HALF_WIDTH * 2.0 + DITCH_W * 2.0, 0.08, DITCH_W), ditch_mat, Vector3.ZERO, false)
	var rail_h := 0.15
	var rail_w := 0.22
	var y := rail_h * 0.5
	var outer := HALF_WIDTH + DITCH_W + rail_w * 0.5
	_box(_ditch_frame, Vector3(outer, y, side_z), Vector3(rail_w, rail_h, side_len), _wood_mat)
	_box(_ditch_frame, Vector3(-outer, y, side_z), Vector3(rail_w, rail_h, side_len), _wood_mat)
	var end_w := HALF_WIDTH * 2.0 + DITCH_W * 2.0 + rail_w * 2.0
	_box(_ditch_frame, Vector3(0.0, y, FAR_Z - DITCH_W - rail_w * 0.45), Vector3(end_w, rail_h, rail_w), _wood_mat)
	_build_spare_dots()


func _build_spare_dots() -> void:
	var plank := _lit(Color(0.62, 0.46, 0.28), 0.6)
	var spot_z := FAR_Z - DITCH_W - 0.08
	_box(_ditch_frame, Vector3(0.0, 0.18, spot_z), Vector3(1.7, 0.04, 0.36), plank, Vector3.ZERO, false)
	for side in [-0.48, 0.48]:
		var dot := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.2
		mesh.height = 0.4
		mesh.radial_segments = 16
		mesh.rings = 10
		dot.mesh = mesh
		dot.position = Vector3(side, 0.42, spot_z)
		var mat := _lit(Color(0.98, 0.82, 0.28), 0.28, 0.55, Color(0.7, 0.48, 0.1), 0.2)
		dot.material_override = mat
		_ditch_frame.add_child(dot)
		_spare_dots.append(dot)


func set_ditch_mode(enabled: bool) -> void:
	if _rebound_frame != null:
		_rebound_frame.visible = not enabled
	if _ditch_frame != null:
		_ditch_frame.visible = enabled


func reset_spares() -> void:
	for dot in _spare_dots:
		dot.visible = true


func take_spare() -> int:
	for dot in _spare_dots:
		if dot.visible:
			dot.visible = false
			break
	return spares_remaining()


func spares_remaining() -> int:
	var count := 0
	for dot in _spare_dots:
		if dot.visible:
			count += 1
	return count


func _markings() -> void:
	var y := 0.018
	var line_h := 0.012
	# Side strings.
	_box(self, Vector3(HALF_WIDTH - 0.16, y, -LENGTH * 0.5), Vector3(0.045, line_h, LENGTH - 0.7), _white_line, Vector3.ZERO, false)
	_box(self, Vector3(-HALF_WIDTH + 0.16, y, -LENGTH * 0.5), Vector3(0.045, line_h, LENGTH - 0.7), _white_line, Vector3.ZERO, false)
	# End lines.
	_box(self, Vector3(0.0, y, -0.55), Vector3(HALF_WIDTH * 2.0 - 0.45, line_h, 0.045), _white_line, Vector3.ZERO, false)
	_box(self, Vector3(0.0, y, FAR_Z + 0.55), Vector3(HALF_WIDTH * 2.0 - 0.45, line_h, 0.045), _white_line, Vector3.ZERO, false)
	# Delivery mat and the line the player bowls from.
	var mat := _lit(Color(0.93, 0.89, 0.78), 0.7)
	_box(self, Vector3(0.0, 0.012, DISC_Z), Vector3(0.62, 0.01, 0.42), mat, Vector3.ZERO, false)
	var cream := _lit(Color(0.96, 0.9, 0.62), 0.5, 0.0, Color(1.0, 0.92, 0.6), 0.12)
	_box(self, Vector3(0.0, y, DISC_Z - 0.55), Vector3(HALF_WIDTH * 2.0 - 0.7, line_h, 0.035), cream, Vector3.ZERO, false)
	# Dashed center line. Gaps keep the stripe from turning into a solid wall.
	var dash_z := -3.1
	while dash_z > FAR_Z + 1.2:
		_box(self, Vector3(0.0, y, dash_z), Vector3(0.04, line_h, 0.58), _white_line, Vector3.ZERO, false)
		dash_z -= 1.18
	# Corner pegs.
	for corner in [Vector2(HALF_WIDTH - 0.08, -0.35), Vector2(-HALF_WIDTH + 0.08, -0.35), Vector2(HALF_WIDTH - 0.08, FAR_Z + 0.35), Vector2(-HALF_WIDTH + 0.08, FAR_Z + 0.35)]:
		_cylinder(self, Vector3(corner.x, 0.22, corner.y), 0.035, 0.44, _white_line, Vector3.ZERO, 8, false)
		_sphere(self, Vector3(corner.x, 0.46, corner.y), 0.05, _gold, 8, false)


func _build_surrounds() -> void:
	var path_w := 0.72
	var path_x := HALF_WIDTH + DITCH_W + 0.95
	var path_len := LENGTH + 1.4
	_box(self, Vector3(path_x, 0.025, -LENGTH * 0.5 + 0.2), Vector3(path_w, 0.05, path_len), _path_mat, Vector3.ZERO, false)
	_box(self, Vector3(-path_x, 0.025, -LENGTH * 0.5 + 0.2), Vector3(path_w, 0.05, path_len), _path_mat, Vector3.ZERO, false)
	# Approach from the far ditch up to the clubhouse door.
	_box(self, Vector3(0.0, 0.03, FAR_Z - DITCH_W - 1.9), Vector3(2.1, 0.05, 2.0), _path_mat, Vector3.ZERO, false)

	var hedge := _leaf_mats[1]
	_hedge(HALF_WIDTH + DITCH_W + 1.45, -2.4, FAR_Z + 1.0, hedge)
	_hedge(-HALF_WIDTH - DITCH_W - 1.45, -2.4, FAR_Z + 1.0, hedge)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4041
	var tree_x := HALF_WIDTH + DITCH_W + 1.85
	for i in 16:
		var z := -4.2 - float(i) * 3.9
		var scale_a := rng.randf_range(0.86, 1.16)
		var scale_b := rng.randf_range(0.86, 1.16)
		_tree(self, Vector3(tree_x, 0.0, z), scale_a, rng)
		_tree(self, Vector3(-tree_x, 0.0, z + 0.8), scale_b, rng)
		if i % 2 == 0:
			_bench(self, Vector3(path_x - 0.05, 0.0, z + 1.5), 1.0)
			_bench(self, Vector3(-path_x + 0.05, 0.0, z + 1.2), -1.0)
		if i % 3 == 0:
			_lamp(self, Vector3(tree_x - 0.55, 0.0, z - 1.1))
			_lamp(self, Vector3(-tree_x + 0.55, 0.0, z - 0.6))
		_flowers(self, Vector3(path_x + 0.28, 0.0, z + 0.4), rng)
		_flowers(self, Vector3(-path_x - 0.28, 0.0, z - 0.2), rng)

	# Outer row fills the upper corners once the green narrows.
	for i in 6:
		var z := -14.0 - float(i) * 5.2
		_tree(self, Vector3(9.4, 0.0, z), rng.randf_range(1.05, 1.35), rng)
		_tree(self, Vector3(-9.6, 0.0, z + 1.6), rng.randf_range(1.05, 1.35), rng)

	var banner_x := HALF_WIDTH + DITCH_W + 0.35
	_banner(self, Vector3(banner_x, 0.0, -LENGTH * 0.36), "PLAY\nSLIDE\nCOMPETE", Color(0.11, 0.32, 0.58))
	_banner(self, Vector3(-banner_x, 0.0, -LENGTH * 0.36), "PLAY\nSLIDE\nCOMPETE", Color(0.11, 0.32, 0.58))
	_banner(self, Vector3(banner_x, 0.0, -LENGTH * 0.58), "DISC\nQUEST", Color(0.08, 0.24, 0.46))
	_banner(self, Vector3(-banner_x, 0.0, -LENGTH * 0.58), "DISC\nQUEST", Color(0.08, 0.24, 0.46))

	_flowers(self, Vector3(1.35, 0.0, FAR_Z - 1.3), rng)
	_flowers(self, Vector3(-1.35, 0.0, FAR_Z - 1.5), rng)
	_flowers(self, Vector3(1.5, 0.0, -0.15), rng)
	_flowers(self, Vector3(-1.55, 0.0, -0.05), rng)


func _build_clubhouse() -> void:
	var club := Node3D.new()
	club.name = "Clubhouse"
	club.position = Vector3(0.0, 0.0, FAR_Z - 5.6)
	add_child(club)

	var wall := _lit(Color(0.95, 0.93, 0.88), 0.72)
	var trim := _lit(Color(0.86, 0.84, 0.78), 0.65)
	var roof_mat := _lit(Color(0.28, 0.36, 0.48), 0.55, 0.08)
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glass := _lit(Color(0.16, 0.28, 0.40), 0.18, 0.35, Color(0.45, 0.65, 0.85), 0.28)
	var door_mat := _lit(Color(0.42, 0.24, 0.16), 0.6)
	var step_mat := _lit(Color(0.78, 0.76, 0.70), 0.8)

	_box(club, Vector3(0.0, 0.22, 0.0), Vector3(9.4, 0.44, 6.4), trim)
	_box(club, Vector3(0.0, 2.05, 0.0), Vector3(8.5, 3.3, 5.5), wall)

	var roof := MeshInstance3D.new()
	roof.mesh = _roof_mesh(9.6, 6.6, 1.85)
	roof.position = Vector3(0.0, 3.72, 0.0)
	roof.material_override = roof_mat
	club.add_child(roof)
	# Gold eaves line.
	_box(club, Vector3(0.0, 3.78, 2.85), Vector3(9.3, 0.08, 0.16), _gold, Vector3.ZERO, false)

	# Clock gable on the front face (+Z, toward the mat).
	_box(club, Vector3(0.0, 4.55, 2.55), Vector3(2.3, 1.7, 0.55), wall)
	_clock(club, Vector3(0.0, 4.72, 2.9))

	var front_z := 2.78
	_box(club, Vector3(0.0, 1.25, front_z), Vector3(1.25, 2.15, 0.12), door_mat)
	_box(club, Vector3(0.0, 2.42, front_z + 0.04), Vector3(1.45, 0.1, 0.28), _wood_mat)
	for i in 3:
		var tread := 2.95 + float(i) * 0.32
		_box(club, Vector3(0.0, 0.1 + float(i) * 0.07, tread), Vector3(1.9 - float(i) * 0.08, 0.14, 0.36), step_mat, Vector3.ZERO, false)

	var window_xs := [-2.7, -1.55, 1.55, 2.7]
	for wx in window_xs:
		_box(club, Vector3(wx, 1.35, front_z), Vector3(0.78, 1.05, 0.1), glass, Vector3.ZERO, false)
		_box(club, Vector3(wx, 2.85, front_z), Vector3(0.78, 0.72, 0.1), glass, Vector3.ZERO, false)
		_box(club, Vector3(wx, 0.72, front_z + 0.16), Vector3(0.95, 0.16, 0.28), trim)
		_flowers(club, Vector3(wx, 0.88, front_z + 0.28), _seeded_rng(int(absf(wx) * 10.0)))

	# Side windows so the building has volume when the angle isn't dead-on.
	for side in [-1.0, 1.0]:
		_box(club, Vector3(4.28 * side, 1.5, 0.4), Vector3(0.1, 1.1, 0.8), glass, Vector3.ZERO, false)
		_box(club, Vector3(4.28 * side, 1.5, -1.3), Vector3(0.1, 1.1, 0.8), glass, Vector3.ZERO, false)

	var plaque := _lit(Color(0.10, 0.22, 0.38), 0.45, 0.1)
	_box(club, Vector3(0.0, 3.15, front_z + 0.02), Vector3(4.4, 0.62, 0.08), plaque, Vector3.ZERO, false)
	var sign := _label("RIVERSIDE DISC CLUB", 0.42)
	sign.position = Vector3(0.0, 3.15, front_z + 0.1)
	club.add_child(sign)

	_cylinder(club, Vector3(3.4, 4.5, -1.6), 0.28, 1.5, _lit(Color(0.55, 0.32, 0.26), 0.7), Vector3.ZERO, 10)
	_pot(club, Vector3(-1.7, 0.0, 3.15))
	_pot(club, Vector3(1.7, 0.0, 3.15))

	# Flagpoles flank the approach.
	for side in [-1.0, 1.0]:
		var pole_pos := Vector3(side * 3.6, 0.0, 4.4)
		_cylinder(club, pole_pos + Vector3(0.0, 1.7, 0.0), 0.035, 3.4, _gold, Vector3.ZERO, 8)
		var flag_mat := _lit(Color(0.12, 0.34, 0.62) if side > 0.0 else Color(0.75, 0.18, 0.22), 0.55)
		_box(club, pole_pos + Vector3(side * 0.38, 3.05, 0.0), Vector3(0.7, 0.42, 0.03), flag_mat, Vector3.ZERO, false)

	# Trees nestled behind the building.
	var rng := _seeded_rng(9)
	for i in 5:
		var side := -1.0 if i < 2 or i == 4 else 1.0
		var x := side * rng.randf_range(5.5, 8.5)
		var z := rng.randf_range(-1.5, 2.5)
		_tree(club, Vector3(x, 0.0, z), rng.randf_range(1.1, 1.45), rng)


func _build_head() -> void:
	head = Node3D.new()
	head.name = "Head"
	add_child(head)

	var white := _lit(Color(0.97, 0.98, 0.96), 0.4, 0.0, Color(1, 1, 1), 0.35)
	var blue := _lit(Color(0.16, 0.42, 0.92), 0.35, 0.05, Color(0.30, 0.55, 1.0), 0.4)
	var red := _lit(Color(0.86, 0.14, 0.18), 0.35, 0.05, Color(1.0, 0.28, 0.28), 0.35)
	_ring(head, 1.32, 1.16, white)
	_ring(head, 1.02, 0.84, blue)
	_ring(head, 0.70, 0.48, red)
	# The gold ring marks where the jack was delivered. The jack itself is a
	# live bowl and can be knocked off this mark.
	_ring(head, 0.34, 0.29, _gold)


func _hedge(x: float, z_start: float, z_end: float, mat: Material) -> void:
	var length := absf(z_end - z_start)
	var z := (z_start + z_end) * 0.5
	_box(self, Vector3(x, 0.42, z), Vector3(0.46, 0.78, length), mat)
	_cylinder(self, Vector3(x, 0.86, z), 0.24, length, mat, Vector3(PI * 0.5, 0.0, 0.0), 8)


func _tree(parent: Node3D, pos: Vector3, scale: float, rng: RandomNumberGenerator) -> void:
	var leaf: StandardMaterial3D = _leaf_mats[rng.randi() % _leaf_mats.size()]
	var shade: StandardMaterial3D = _leaf_mats[(rng.randi() + 1) % _leaf_mats.size()]
	var trunk_h := 1.25 * scale
	_cylinder(parent, pos + Vector3(0.0, trunk_h * 0.5, 0.0), 0.09 * scale, trunk_h, _trunk_mat, Vector3.ZERO, 8)
	var crown_y := trunk_h + 0.15 * scale
	_sphere(parent, pos + Vector3(0.0, crown_y + 0.55 * scale, 0.0), 0.78 * scale, leaf, 14)
	_sphere(parent, pos + Vector3(0.0, crown_y + 0.28 * scale, 0.0), 0.95 * scale, leaf, 14)
	_sphere(parent, pos + Vector3(0.4 * scale, crown_y + 0.22 * scale, 0.12 * scale), 0.58 * scale, leaf, 12)
	_sphere(parent, pos + Vector3(-0.38 * scale, crown_y + 0.26 * scale, -0.08 * scale), 0.55 * scale, shade, 12)


func _bench(parent: Node3D, pos: Vector3, side_sign: float) -> void:
	var leg := _lit(Color(0.28, 0.18, 0.12), 0.6)
	_box(parent, pos + Vector3(0.0, 0.46, 0.0), Vector3(0.46, 0.07, 1.2), _wood_mat)
	_box(parent, pos + Vector3(0.18 * side_sign, 0.7, 0.0), Vector3(0.06, 0.4, 1.2), _wood_mat)
	for dz in [-0.46, 0.46]:
		for dx in [-0.16, 0.16]:
			_box(parent, pos + Vector3(dx, 0.22, dz), Vector3(0.06, 0.44, 0.06), leg, Vector3.ZERO, false)


func _lamp(parent: Node3D, pos: Vector3) -> void:
	var metal := _lit(Color(0.22, 0.24, 0.28), 0.35, 0.55)
	var glow := _lit(Color(1.0, 0.92, 0.7), 0.3, 0.0, Color(1.0, 0.86, 0.45), 1.4)
	_cylinder(parent, pos + Vector3(0.0, 1.15, 0.0), 0.04, 2.3, metal, Vector3.ZERO, 8)
	_sphere(parent, pos + Vector3(0.0, 2.35, 0.0), 0.13, glow, 8, false)


func _flowers(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	for i in 5:
		var offset := Vector3(rng.randf_range(-0.16, 0.16), 0.0, rng.randf_range(-0.16, 0.16))
		var petal: StandardMaterial3D = _flower_mats[rng.randi() % _flower_mats.size()]
		_cylinder(parent, pos + offset + Vector3(0.0, 0.08, 0.0), 0.012, 0.16, _stem_mat, Vector3.ZERO, 5, false)
		_sphere(parent, pos + offset + Vector3(0.0, 0.18, 0.0), 0.055, petal, 6, false)


func _banner(parent: Node3D, pos: Vector3, title: String, tint: Color) -> void:
	var brass := _lit(Color(0.78, 0.64, 0.30), 0.4, 0.45)
	var cloth := _lit(tint, 0.62)
	_cylinder(parent, pos + Vector3(0.0, 1.35, 0.0), 0.04, 2.7, brass, Vector3.ZERO, 8)
	_sphere(parent, pos + Vector3(0.0, 2.75, 0.0), 0.07, _gold, 8, false)
	_box(parent, pos + Vector3(0.0, 1.9, -0.02), Vector3(0.92, 1.5, 0.03), _gold, Vector3.ZERO, false)
	_box(parent, pos + Vector3(0.0, 1.9, 0.0), Vector3(0.78, 1.36, 0.035), cloth, Vector3.ZERO, false)
	var label := _label(title, 0.22)
	label.position = pos + Vector3(0.0, 1.9, 0.045)
	parent.add_child(label)


func _pot(parent: Node3D, pos: Vector3) -> void:
	var pot := _lit(Color(0.62, 0.28, 0.22), 0.7)
	_cylinder(parent, pos + Vector3(0.0, 0.22, 0.0), 0.22, 0.32, pot, Vector3.ZERO, 10, false)
	_sphere(parent, pos + Vector3(0.0, 0.5, 0.0), 0.32, _leaf_mats[0], 8)


func _hill(pos: Vector3, radius: float, color: Color) -> void:
	_sphere(self, pos, radius, _lit(color, 1.0), 12, false)


func _label(text: String, height_m: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.pixel_size = height_m / 96.0
	label.modulate = Color(0.98, 0.97, 0.93)
	label.outline_modulate = Color(0.05, 0.10, 0.18)
	label.outline_size = 18
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return label


func _grass_material(stripe_a: Color, stripe_b: Color, stripe_width: float, half_width: float, depth_fade: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _grass_shader
	mat.set_shader_parameter("stripe_a", stripe_a)
	mat.set_shader_parameter("stripe_b", stripe_b)
	mat.set_shader_parameter("stripe_width", stripe_width)
	mat.set_shader_parameter("half_width", half_width)
	mat.set_shader_parameter("depth_fade", depth_fade)
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


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, shadows: bool = true) -> MeshInstance3D:
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
	return mi


func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, rot: Vector3 = Vector3.ZERO, segments: int = 16, shadows: bool = true) -> MeshInstance3D:
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
	return mi


func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material, segments: int = 12, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(4, segments / 2)
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _ring(parent: Node3D, outer_r: float, inner_r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _annulus(inner_r, outer_r, 56)
	mi.position = Vector3(0.0, 0.03, 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


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
		_flat_tri(st, i0, o0, o1)
		_flat_tri(st, i0, o1, i1)
	return st.commit()


func _flat_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal(Vector3.UP)
	st.add_vertex(a)
	st.set_normal(Vector3.UP)
	st.add_vertex(b)
	st.set_normal(Vector3.UP)
	st.add_vertex(c)


func _roof_mesh(width: float, depth: float, rise: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var hd := depth * 0.5
	var fl := Vector3(-hw, 0.0, hd)
	var fr := Vector3(hw, 0.0, hd)
	var bl := Vector3(-hw, 0.0, -hd)
	var br := Vector3(hw, 0.0, -hd)
	var rl := Vector3(-hw, rise, 0.0)
	var rr := Vector3(hw, rise, 0.0)
	_shaded_tri(st, fl, fr, rr)
	_shaded_tri(st, fl, rr, rl)
	_shaded_tri(st, br, bl, rl)
	_shaded_tri(st, br, rl, rr)
	_shaded_tri(st, bl, fl, rl)
	_shaded_tri(st, fr, br, rr)
	return st.commit()


func _shaded_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)


func _clock(parent: Node3D, pos: Vector3) -> void:
	var rim_mat := _lit(Color(0.14, 0.17, 0.22), 0.4, 0.25)
	var face_mat := _lit(Color(0.98, 0.96, 0.90), 0.4)
	var hand_mat := _lit(Color(0.12, 0.13, 0.16), 0.35)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.46
	rim.bottom_radius = 0.46
	rim.height = 0.08
	rim.radial_segments = 28
	var rim_mi := MeshInstance3D.new()
	rim_mi.mesh = rim
	rim_mi.position = pos
	rim_mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	rim_mi.material_override = rim_mat
	rim_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rim_mi)
	var face := CylinderMesh.new()
	face.top_radius = 0.36
	face.bottom_radius = 0.36
	face.height = 0.02
	face.radial_segments = 28
	var face_mi := MeshInstance3D.new()
	face_mi.mesh = face
	face_mi.position = pos + Vector3(0.0, 0.0, 0.05)
	face_mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	face_mi.material_override = face_mat
	face_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(face_mi)
	# 10:10, so the hands don't read as a letter.
	var minute := MeshInstance3D.new()
	var minute_box := BoxMesh.new()
	minute_box.size = Vector3(0.045, 0.24, 0.015)
	minute.mesh = minute_box
	minute.position = pos + Vector3(-0.06, 0.07, 0.08)
	minute.rotation_degrees = Vector3(0.0, 0.0, 40.0)
	minute.material_override = hand_mat
	minute.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(minute)
	var hour := MeshInstance3D.new()
	var hour_box := BoxMesh.new()
	hour_box.size = Vector3(0.05, 0.16, 0.015)
	hour.mesh = hour_box
	hour.position = pos + Vector3(0.05, 0.04, 0.08)
	hour.rotation_degrees = Vector3(0.0, 0.0, -50.0)
	hour.material_override = hand_mat
	hour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(hour)


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
