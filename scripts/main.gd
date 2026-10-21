extends Node3D

## Crokinole match. Buttons stay on the table, bounce off the eight pegs,
## and score 20 / 15 / 10 / 5 from the hole outward.

const Metrics = preload("res://scripts/table_metrics.gd")
const LevelScript = preload("res://scripts/level_manager.gd")
const ScoreScript = preload("res://scripts/score_manager.gd")
const PuckScript = preload("res://scripts/puck.gd")

var disc
var ui
var level_manager: Node
var score_manager: Node
var camera: Camera3D
var pucks_root: Node3D
var pucks: Array = []
var active_puck
var current_level_index := 0
var current_level: Dictionary
var discs_left := 0
var resolving := false

func _ready() -> void:
	disc = get_node("Shooter")
	ui = get_node("UI")
	level_manager = LevelScript.new()
	score_manager = ScoreScript.new()
	add_child(level_manager)
	add_child(score_manager)
	pucks_root = Node3D.new()
	pucks_root.name = "Pucks"
	add_child(pucks_root)
	_setup_view()
	disc.aim_changed.connect(_on_disc_aim_changed)
	disc.bias_changed.connect(_on_disc_bias_changed)
	disc.shot_started.connect(_on_disc_shot_started)
	ui.reset_requested.connect(_on_reset_requested)
	ui.next_level_requested.connect(_on_next_level_requested)
	ui.bias_cycle_requested.connect(_on_bias_cycle_requested)
	_load_level(0)

func _setup_view() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#7eb6e8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c4b49a")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.92
	environment.glow_enabled = true
	environment.glow_intensity = 0.18
	environment.glow_strength = 0.45
	environment.glow_bloom = 0.02
	environment.glow_hdr_threshold = 1.25
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 42.0
	camera.near = 0.04
	camera.far = 40.0
	camera.current = true
	add_child(camera)
	# The round board stays whole above the controls, and the long rink
	# sits behind it up to the clubhouse.
	camera.position = Vector3(0.0, 3.05, 2.42)
	camera.look_at(Vector3(0.0, 0.0, -0.28), Vector3.UP)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	key.light_color = Color("#fff3e4")
	key.light_energy = 0.95
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 8.0
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.1
	add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0.2, 1.5, 0.9)
	fill.light_color = Color("#ffe8d0")
	fill.light_energy = 0.22
	fill.omni_range = 4.5
	add_child(fill)

func _physics_process(delta: float) -> void:
	if not resolving:
		return
	var remaining := delta
	while remaining > 0.00001:
		var step := minf(1.0 / 120.0, remaining)
		_substep(step)
		remaining -= step
	if _all_stopped():
		resolving = false
		_on_table_settled()

func _substep(delta: float) -> void:
	for puck in pucks:
		if puck.sunk or not puck.moving:
			continue
		var speed: float = Vector2(puck.velocity.x, puck.velocity.z).length()
		if speed > Metrics.STOP_SPEED and absf(puck.shot_bias) > 0.01:
			var slowdown := clampf(1.0 - speed / Metrics.MAX_SPEED, 0.0, 1.0)
			var turn_rate := lerpf(0.1, 0.7, slowdown)
			var turned: Vector3 = puck.velocity.rotated(Vector3.UP, -puck.shot_bias * turn_rate * delta)
			puck.velocity = Vector3(turned.x, 0.0, turned.z)
		var friction: float = Metrics.DITCH_FRICTION if bool(puck.in_ditch) else Metrics.SURFACE_FRICTION
		puck.velocity *= pow(friction, delta)
		puck.position += puck.velocity * delta
		puck.spin(delta)
		_update_surface(puck)
		if Vector2(puck.velocity.x, puck.velocity.z).length() <= Metrics.STOP_SPEED:
			puck.velocity = Vector3.ZERO
			puck.stop_timer += delta
			if puck.stop_timer >= 0.08:
				puck.moving = false
				puck.shot_bias = 0.0
		else:
			puck.stop_timer = 0.0
	for _iteration in 4:
		_solve_pegs()
		_solve_pucks()
		_solve_rail()
	_solve_holes()

func _update_surface(puck) -> void:
	if puck.sunk:
		return
	var distance: float = puck.flat().length()
	if not puck.in_ditch and distance > Metrics.SURFACE_RADIUS - Metrics.DISC_RADIUS * 0.25:
		puck.in_ditch = true
	if puck.in_ditch:
		puck.position.y = Metrics.DITCH_Y
	else:
		puck.position.y = Metrics.DISC_CENTER_Y

func _solve_pegs() -> void:
	for puck in pucks:
		if puck.sunk or puck.in_ditch:
			continue
		var spot: Vector2 = puck.flat()
		for peg in Metrics.peg_positions():
			var peg_flat := Vector2(peg.x, peg.z)
			var offset := spot - peg_flat
			var distance := offset.length()
			var minimum := Metrics.DISC_RADIUS + Metrics.PEG_RADIUS
			if distance >= minimum or distance <= 0.0001:
				continue
			var normal := offset / distance
			spot = peg_flat + normal * minimum
			puck.set_flat(spot)
			var velocity := Vector2(puck.velocity.x, puck.velocity.z)
			var into := velocity.dot(normal)
			if into < 0.0:
				velocity -= normal * into * (1.0 + Metrics.PEG_RESTITUTION)
				puck.velocity = Vector3(velocity.x, 0.0, velocity.y)
				puck.moving = true
				puck.stop_timer = 0.0

func _solve_pucks() -> void:
	for index in pucks.size():
		var first = pucks[index]
		if first.sunk:
			continue
		for other_index in range(index + 1, pucks.size()):
			var second = pucks[other_index]
			if second.sunk:
				continue
			if first.in_ditch != second.in_ditch:
				continue
			var delta: Vector2 = second.flat() - first.flat()
			var distance := delta.length()
			var minimum := Metrics.DISC_RADIUS * 2.0
			if distance >= minimum or distance <= 0.0001:
				continue
			var normal := delta / distance
			var overlap := minimum - distance
			first.set_flat(first.flat() - normal * overlap * 0.5)
			second.set_flat(second.flat() + normal * overlap * 0.5)
			var relative := Vector2(first.velocity.x - second.velocity.x, first.velocity.z - second.velocity.z)
			var approach := relative.dot(normal)
			if approach > 0.0:
				var impulse := approach * (1.0 + Metrics.DISC_RESTITUTION) * 0.5
				first.velocity -= Vector3(normal.x, 0.0, normal.y) * impulse
				second.velocity += Vector3(normal.x, 0.0, normal.y) * impulse
				first.moving = true
				second.moving = true
				first.stop_timer = 0.0
				second.stop_timer = 0.0

func _solve_rail() -> void:
	var limit := Metrics.DITCH_OUTER - Metrics.DISC_RADIUS
	for puck in pucks:
		if puck.sunk:
			continue
		var spot: Vector2 = puck.flat()
		if spot.length() <= limit or spot.length() <= 0.0001:
			continue
		var normal := spot.normalized()
		puck.set_flat(normal * limit)
		if not puck.in_ditch:
			puck.in_ditch = true
			puck.position.y = Metrics.DITCH_Y
		var velocity := Vector2(puck.velocity.x, puck.velocity.z)
		var outward := velocity.dot(normal)
		if outward > 0.0:
			velocity -= normal * outward * (1.0 + Metrics.RAIL_RESTITUTION)
			puck.velocity = Vector3(velocity.x, 0.0, velocity.y)
			puck.moving = true
			puck.stop_timer = 0.0

func _solve_holes() -> void:
	for puck in pucks:
		if puck.sunk or puck.in_ditch:
			continue
		var speed: float = Vector2(puck.velocity.x, puck.velocity.z).length()
		if puck.flat().length() <= Metrics.HOLE_RADIUS * 0.78 and speed < 1.05:
			puck.sink_into_hole()

func _all_stopped() -> bool:
	for puck in pucks:
		if puck.moving and not puck.sunk:
			return false
	return true

func _player_score() -> int:
	var total := 0
	for puck in pucks:
		if puck.is_player:
			total += puck.points()
	return total

func _unhandled_input(event: InputEvent) -> void:
	if disc.shot_in_progress or disc.is_aiming or not _is_press(event):
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
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO

func _pointer_down(screen_position: Vector2) -> void:
	if active_puck == null or resolving or not _pointer_hits_disc(screen_position):
		return
	disc.begin_aim(_board_point(screen_position))

func _pointer_move(screen_position: Vector2) -> void:
	if disc.is_aiming:
		disc.update_aim(_board_point(screen_position))

func _pointer_up(screen_position: Vector2) -> void:
	if disc.is_aiming:
		disc.release_aim(_board_point(screen_position))

func _pointer_hits_disc(screen_position: Vector2) -> bool:
	if active_puck == null:
		return false
	var disc_screen := camera.unproject_position(active_puck.global_position)
	var edge_screen := camera.unproject_position(active_puck.global_position + Vector3(Metrics.DISC_RADIUS * 2.4, 0.0, 0.0))
	var grab_radius := maxf(disc_screen.distance_to(edge_screen), 72.0)
	return disc_screen.distance_to(screen_position) <= grab_radius

func _board_point(screen_position: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.00001:
		return active_puck.global_position if active_puck != null else Vector3.ZERO
	var distance := (0.0 - origin.y) / direction.y
	if distance < 0.0:
		return active_puck.global_position if active_puck != null else Vector3.ZERO
	return origin + direction * distance

func _clear_pucks() -> void:
	for puck in pucks:
		puck.queue_free()
	pucks.clear()
	active_puck = null
	disc.bind_puck(null)

func _spawn_puck(player_disc: bool, spot: Vector2):
	var puck = PuckScript.new()
	puck.setup(player_disc)
	puck.set_flat(spot)
	puck.add_to_group("crokinole_puck")
	pucks_root.add_child(puck)
	pucks.append(puck)
	return puck

func _spot_free(spot: Vector2) -> bool:
	if spot.length() > Metrics.SURFACE_RADIUS - Metrics.DISC_RADIUS - 0.01:
		return false
	for peg in Metrics.peg_positions():
		if spot.distance_to(Vector2(peg.x, peg.z)) < Metrics.PEG_RADIUS + Metrics.DISC_RADIUS + 0.02:
			return false
	for puck in pucks:
		if puck.sunk:
			continue
		if spot.distance_to(puck.flat()) < Metrics.DISC_RADIUS * 2.15:
			return false
	return true

func _start_spot() -> Vector2:
	var candidates: Array[Vector2] = [
		Vector2(0.0, Metrics.PLAYER_START_Z),
		Vector2(0.14, 0.66),
		Vector2(-0.14, 0.66),
		Vector2(0.26, 0.62),
		Vector2(-0.26, 0.62),
		Vector2(0.36, 0.64),
		Vector2(-0.36, 0.64),
	]
	for candidate in candidates:
		if _spot_free(candidate):
			return candidate
	return candidates[0]

func _arm_next_disc(announce := true) -> void:
	if discs_left <= 0:
		active_puck = null
		disc.bind_puck(null)
		return
	active_puck = _spawn_puck(true, _start_spot())
	disc.bind_puck(active_puck)
	ui.show_match_status(int(current_level["number"]), discs_left, _player_score())
	if announce:
		ui.show_ready(int(current_level["number"]), discs_left, str(current_level["difficulty"]), _player_score())

func _load_level(level_index: int) -> void:
	resolving = false
	current_level_index = clampi(level_index, 0, level_manager.get_level_count() - 1)
	current_level = level_manager.get_level(current_level_index)
	discs_left = int(current_level["discs"])
	_clear_pucks()
	for opponent in current_level["opponents"]:
		var spot: Vector2 = opponent
		if _spot_free(spot):
			_spawn_puck(false, spot)
	_arm_next_disc()

func _on_disc_aim_changed(_direction: Vector3, power_ratio: float) -> void:
	ui.show_power(power_ratio)
	if power_ratio > 0.0:
		ui.show_aiming(power_ratio)

func _on_disc_bias_changed(bias_ratio: float) -> void:
	ui.show_bias(bias_ratio)
	if disc.is_aiming:
		ui.show_aiming(disc.power_ratio)

func _on_bias_cycle_requested() -> void:
	if not resolving:
		disc.cycle_bias()

func _on_disc_shot_started() -> void:
	discs_left -= 1
	resolving = true
	ui.show_power(0.0)
	ui.show_in_motion(discs_left, _player_score())
	ui.show_match_status(int(current_level["number"]), discs_left, _player_score())

func _on_table_settled() -> void:
	disc.mark_shot_finished()
	var shot_points := 0
	if active_puck != null and active_puck.is_player:
		shot_points = active_puck.points()
	var total := _player_score()
	var sunk: bool = active_puck != null and bool(active_puck.sunk)
	if discs_left > 0:
		ui.show_landed(shot_points, total, discs_left, sunk)
		_arm_next_disc(false)
	else:
		ui.show_round_complete(total, shot_points, current_level_index < level_manager.get_level_count() - 1)
		ui.show_match_status(int(current_level["number"]), 0, total)
		active_puck = null
		disc.bind_puck(null)

func _on_reset_requested() -> void:
	_load_level(current_level_index)

func _on_next_level_requested() -> void:
	if current_level_index < level_manager.get_level_count() - 1:
		_load_level(current_level_index + 1)
