extends Node3D

## DISC QUEST table view.
## The crokinole board is a real 3D mesh. Shots still slide on the flat playing
## surface, and the camera sits at the player's seat so the near rail reads larger
## than the far rail.

const Metrics = preload("res://scripts/table_metrics.gd")
const LevelScript = preload("res://scripts/level_manager.gd")
const ScoreScript = preload("res://scripts/score_manager.gd")

var disc: Node3D
var ui: CanvasLayer
var level_manager: Node
var score_manager: Node
var camera: Camera3D
var jack: Node3D
var current_level_index := 0
var current_level: Dictionary
var throws_left := 3

func _ready() -> void:
	disc = get_node("PlayerDisc")
	ui = get_node("UI")
	level_manager = LevelScript.new()
	score_manager = ScoreScript.new()
	add_child(level_manager)
	add_child(score_manager)
	_setup_view()
	_build_jack()
	disc.aim_changed.connect(_on_disc_aim_changed)
	disc.bias_changed.connect(_on_disc_bias_changed)
	disc.shot_started.connect(_on_disc_shot_started)
	disc.shot_stopped.connect(_on_disc_shot_stopped)
	ui.reset_requested.connect(_on_reset_requested)
	ui.next_level_requested.connect(_on_next_level_requested)
	ui.bias_cycle_requested.connect(_on_bias_cycle_requested)
	_load_level(0)

func _setup_view() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#07060b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#5c463c")
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.98
	environment.glow_enabled = true
	environment.glow_intensity = 0.26
	environment.glow_strength = 0.5
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.2
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 40.0
	camera.near = 0.05
	camera.current = true
	add_child(camera)
	# Seated at the near rail: the far side of the table is visibly smaller.
	camera.position = Vector3(0.0, 0.92, 2.42)
	camera.look_at(Vector3(0.0, 0.0, 0.06), Vector3.UP)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58.0, -36.0, 0.0)
	key.light_color = Color("#fff6ec")
	key.light_energy = 1.12
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 10.0
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 0.8
	add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0.35, 1.35, 1.15)
	fill.light_color = Color("#d5ecff")
	fill.light_energy = 0.28
	fill.omni_range = 5.0
	add_child(fill)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.85, 0.55, -0.2)
	rim.light_color = Color("#ff4d9a")
	rim.light_energy = 0.3
	rim.omni_range = 3.2
	add_child(rim)

func _build_jack() -> void:
	jack = Node3D.new()
	jack.name = "Jack"
	add_child(jack)

	var base := CylinderMesh.new()
	base.top_radius = Metrics.JACK_RADIUS
	base.bottom_radius = Metrics.JACK_RADIUS * 0.92
	base.height = Metrics.JACK_HEIGHT
	base.radial_segments = 32
	Metrics.add_mesh(jack, base, Metrics.plastic(Color("#8a4b16"), 0.38, 0.05))

	Metrics.add_mesh(
		jack,
		Metrics.cylinder(Metrics.JACK_RADIUS * 0.7, 0.008, 28),
		Metrics.plastic(Color("#f3bd56"), 0.26, 0.35),
		Vector3(0.0, Metrics.JACK_HEIGHT * 0.42, 0.0)
	)
	Metrics.add_mesh(
		jack,
		Metrics.cylinder(Metrics.JACK_RADIUS * 0.24, 0.01, 20),
		Metrics.plastic(Color("#fff6cc"), 0.2, 0.45),
		Vector3(0.0, Metrics.JACK_HEIGHT * 0.5, 0.0)
	)

	var target := TorusMesh.new()
	target.inner_radius = 0.09
	target.outer_radius = 0.112
	target.rings = 32
	target.ring_segments = 8
	var target_material := StandardMaterial3D.new()
	target_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	target_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target_material.albedo_color = Color(0.97, 0.78, 0.35, 0.7)
	var target_mesh := Metrics.add_mesh(jack, target, target_material, Vector3(0.0, -Metrics.JACK_CENTER_Y + 0.006, 0.0))
	target_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var label := Label3D.new()
	label.text = "JACK"
	label.font_size = 64
	label.pixel_size = 0.0006
	label.position = Vector3(0.0, 0.1, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("#ffe7a8")
	label.outline_size = 8
	label.outline_modulate = Color("#2a160c")
	jack.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	# Presses start only when the pointer is not on a HUD button.
	# Once a flick has started, motion and release are taken in _input so the
	# drag can finish over the buttons without clicking them.
	if disc.is_aiming or not _is_press(event):
		return
	_pointer_down(_event_position(event))

func _input(event: InputEvent) -> void:
	if not disc.is_aiming:
		return
	if _is_drag(event):
		_pointer_move(_event_position(event))
		get_viewport().set_input_as_handled()
	elif _is_release(event):
		_pointer_up(_event_position(event))
		get_viewport().set_input_as_handled()

func _is_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed

func _is_release(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return not event.pressed
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed

func _is_drag(event: InputEvent) -> bool:
	if event is InputEventScreenDrag:
		return true
	return event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return event.position
	if event is InputEventScreenTouch:
		return event.position
	if event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO

func _pointer_down(screen_position: Vector2) -> void:
	if not _pointer_hits_disc(screen_position):
		return
	disc.begin_aim(_board_point(screen_position))

func _pointer_move(screen_position: Vector2) -> void:
	if disc.is_aiming:
		disc.update_aim(_board_point(screen_position))

func _pointer_up(screen_position: Vector2) -> void:
	if disc.is_aiming:
		disc.release_aim(_board_point(screen_position))

func _pointer_hits_disc(screen_position: Vector2) -> bool:
	var disc_screen := camera.unproject_position(disc.global_position)
	return disc_screen.distance_to(screen_position) <= 96.0

func _board_point(screen_position: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.00001:
		return disc.global_position
	var distance := (Metrics.SURFACE_Y - origin.y) / direction.y
	if distance < 0.0:
		return disc.global_position
	return origin + direction * distance

func _jack_world(level_position: Vector2) -> Vector3:
	var x_norm := clampf((level_position.x - 270.0) / 150.0, -1.0, 1.0)
	var depth := clampf((level_position.y - 180.0) / 220.0, 0.0, 1.0)
	var flat := Vector2(x_norm * 0.34, lerpf(-0.74, -0.46, depth))
	var limit := Metrics.PLAY_RADIUS * 0.8
	if flat.length() > limit:
		flat = flat.normalized() * limit
	return Vector3(flat.x, Metrics.JACK_CENTER_Y, flat.y)

func _load_level(level_index: int) -> void:
	current_level_index = clampi(level_index, 0, level_manager.get_level_count() - 1)
	current_level = level_manager.get_level(current_level_index)
	jack.position = _jack_world(current_level["jack_position"])
	throws_left = int(current_level["throws"])
	score_manager.reset()
	disc.start_position = Metrics.PLAYER_START
	disc.reset_to_start()
	ui.show_ready(int(current_level["number"]), throws_left, str(current_level["difficulty"]))
	ui.show_match_status(int(current_level["number"]), throws_left)
	ui.show_power(0.0)

func _on_disc_aim_changed(_direction: Vector3, power_ratio: float) -> void:
	ui.show_power(power_ratio)
	if power_ratio > 0.0:
		ui.show_aiming(power_ratio)

func _on_disc_bias_changed(bias_ratio: float) -> void:
	ui.show_bias(bias_ratio)
	if disc.is_aiming:
		ui.show_aiming(disc.power_ratio)

func _on_bias_cycle_requested() -> void:
	disc.cycle_bias()

func _on_disc_shot_started() -> void:
	ui.show_power(0.0)
	throws_left -= 1
	ui.show_in_motion(throws_left)
	ui.show_match_status(int(current_level["number"]), throws_left)

func _on_disc_shot_stopped() -> void:
	ui.show_power(0.0)
	var disc_flat := Vector2(disc.position.x, disc.position.z)
	var jack_flat := Vector2(jack.position.x, jack.position.z)
	var distance_meters := disc_flat.distance_to(jack_flat) * Metrics.METERS_PER_UNIT
	score_manager.record_throw(distance_meters)
	if throws_left > 0:
		disc.reset_to_start()
		ui.show_throw_result(distance_meters, throws_left)
	else:
		ui.show_level_complete(
			score_manager.get_score(),
			score_manager.get_closest_distance(),
			current_level_index < level_manager.get_level_count() - 1
		)

func _on_reset_requested() -> void:
	_load_level(current_level_index)

func _on_next_level_requested() -> void:
	if current_level_index < level_manager.get_level_count() - 1:
		_load_level(current_level_index + 1)
