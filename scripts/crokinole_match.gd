extends Node3D

signal goal_cleared
signal match_decided(you_won: bool)

## Crokinole match. Buttons stay on the table and bounce off the eight pegs.
## An end is eight discs. Both colors count, a disc on a line scores the
## lower ring, and only the difference is added to the match.

const Metrics = preload("res://scripts/table_metrics.gd")
const LevelScript = preload("res://scripts/crokinole_levels.gd")
const ScoreScript = preload("res://scripts/crokinole_score.gd")
const PuckScript = preload("res://scripts/puck.gd")
const FeelScript = preload("res://scripts/feel.gd")

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
var match_you := 0
var match_them := 0
var end_applied := false
var last_award_you := 0
var last_award_them := 0
var match_target := 100
var start_level := 0
var goal := ""
var goal_sent := false
var match_reported := false
var player_tint := Color("#ff3d9a")
var feel
var _hit_wait := 0.0
var gesture
var fan
var place_x := 0.0
const PULL_BACK := 0.34
const AIM_SPAN := 0.42

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
	feel = FeelScript.new()
	feel.name = "Feel"
	add_child(feel)
	_setup_view()
	disc.aim_changed.connect(_on_disc_aim_changed)
	disc.bias_changed.connect(_on_disc_bias_changed)
	disc.shot_started.connect(_on_disc_shot_started)
	ui.reset_requested.connect(_on_reset_requested)
	ui.next_level_requested.connect(_on_next_level_requested)
	ui.bias_cycle_requested.connect(_on_bias_cycle_requested)
	_wire_shot()
	_load_level(start_level)


func _process(delta: float) -> void:
	if gesture != null:
		gesture.advance(delta)
	_sync_fan()

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
	camera.fov = 28.0
	camera.near = 0.04
	camera.far = 40.0
	camera.current = true
	add_child(camera)
	# Close over the round board so the hole and pegs fill the portrait.
	# The near lane stays above the buttons, and the far discs stay under the header.
	camera.position = Vector3(0.0, 2.5, 2.2)
	camera.look_at(Vector3(0.0, 0.0, 0.12), Vector3.UP)

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
	_hit_wait = maxf(0.0, _hit_wait - delta)
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
				_hit(velocity.length())
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
				_hit(approach)
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

func _side_total(player_side: bool) -> int:
	var total := 0
	for puck in pucks:
		if bool(puck.is_player) != player_side:
			continue
		total += int(puck.ring_points())
	return total

func _side_items(player_side: bool) -> Array:
	var items: Array = []
	for puck in pucks:
		if bool(puck.is_player) != player_side:
			continue
		var value: int = puck.ring_points()
		if value > 0:
			items.append(value)
	items.sort()
	items.reverse()
	return items

func _sum(items: Array) -> int:
	var total := 0
	for value in items:
		total += int(value)
	return total

func _pointer_hits_disc(screen_position: Vector2) -> bool:
	if active_puck == null or resolving or disc.shot_in_progress or camera == null:
		return false
	var disc_screen := camera.unproject_position(active_puck.global_position)
	var edge_screen := camera.unproject_position(active_puck.global_position + Vector3(Metrics.DISC_RADIUS * 2.8, 0.0, 0.0))
	var grab_radius := maxf(disc_screen.distance_to(edge_screen), 96.0)
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


func _wire_shot() -> void:
	var shot := preload("res://scripts/shot_gesture.gd").new()
	shot.name = "ShotGesture"
	shot.camera = camera
	shot.hit_test = _pointer_hits_disc
	shot.board_point = _board_point
	shot.place_at.connect(_on_place_at)
	shot.opened_take.connect(_on_take_opened)
	shot.cancelled_pull.connect(_on_pull_cancelled)
	shot.fired.connect(_on_shot_fired)
	add_child(shot)
	gesture = shot
	fan = preload("res://scripts/shot_fan.gd").new()
	fan.name = "ShotFan"
	ui.add_child(fan)


func _on_place_at(spot: Vector3) -> void:
	place_x = clampf(spot.x, -Metrics.LANE_HALF, Metrics.LANE_HALF)
	_snap_disc()
	ui.show_sliding()


func _on_take_opened() -> void:
	_snap_disc()
	ui.show_take()
	ui.show_power(0.0)
	if feel != null:
		feel.tap()


func _on_pull_cancelled() -> void:
	_snap_disc()
	ui.show_take()
	ui.show_power(0.0)


func _on_shot_fired(power: float, needle: float) -> void:
	_snap_disc()
	disc.fire_at(_aim_from(needle), power)


func _snap_disc() -> void:
	if active_puck == null:
		return
	active_puck.set_flat(Vector2(place_x, Metrics.PLAYER_START_Z))
	active_puck.rotation.y = 0.0
	disc.global_position = active_puck.global_position


func _aim_from(needle: float) -> Vector3:
	var toward := Vector2(-place_x, -Metrics.PLAYER_START_Z)
	if toward.length() < 0.001:
		toward = Vector2(0.0, -1.0)
	var base := Vector3(toward.x, 0.0, toward.y).normalized()
	return base.rotated(Vector3.UP, -needle * AIM_SPAN)


func _facing(origin: Vector3, aim: Vector3) -> float:
	if camera == null:
		return -PI * 0.5
	var from := camera.unproject_position(origin)
	var toward := camera.unproject_position(origin + aim * 0.45)
	var delta := toward - from
	if delta.length() < 3.0:
		return -PI * 0.5
	return delta.angle()


func _sync_fan() -> void:
	if gesture == null or fan == null or camera == null:
		return
	var placed := Vector3(place_x, 0.02, Metrics.PLAYER_START_Z)
	gesture.anchor = placed
	var phase := str(gesture.phase)
	var live: bool = active_puck != null and not resolving and not bool(disc.shot_in_progress) and phase != "busy"
	var pulling: bool = phase == "pull"
	var show_fan: bool = live and (phase == "take" or phase == "hold" or pulling)
	var power: float = gesture.read_power() if pulling else 0.0
	var needle: float = gesture.read_needle() if pulling else 0.0
	if live:
		active_puck.set_flat(Vector2(place_x, Metrics.PLAYER_START_Z + power * PULL_BACK))
		active_puck.rotation.y = 0.0
		disc.global_position = active_puck.global_position
		if pulling:
			ui.show_power(power)
			ui.show_aiming(power)
			if feel != null:
				feel.aim(power)
	var anchor := camera.unproject_position(placed + Vector3(0.0, 0.08, 0.0))
	fan.present(anchor, power, needle, show_fan, _facing(placed, _aim_from(0.0)))
	var line_a := camera.unproject_position(Vector3(-Metrics.LANE_HALF, 0.03, Metrics.PLAYER_START_Z))
	var line_b := camera.unproject_position(Vector3(Metrics.LANE_HALF, 0.03, Metrics.PLAYER_START_Z))
	fan.set_line(line_a, line_b, live)
	var disc_at := anchor
	if active_puck != null:
		disc_at = camera.unproject_position(active_puck.global_position + Vector3(0.0, 0.05, 0.0))
	fan.set_disc(disc_at, live)


func _clear_pucks() -> void:
	if gesture != null:
		gesture.busy()
	for puck in pucks:
		puck.queue_free()
	pucks.clear()
	active_puck = null
	disc.bind_puck(null)

func _spawn_puck(player_disc: bool, spot: Vector2):
	var puck = PuckScript.new()
	var tint_color := player_tint if player_disc else Color("#6b3e28")
	puck.setup(player_disc, tint_color)
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

func _begin_ready() -> void:
	place_x = 0.0
	_snap_disc()
	if gesture != null:
		gesture.arm()
		gesture.anchor = Vector3(0.0, 0.02, Metrics.PLAYER_START_Z)
	ui.show_touch(int(current_level["number"]), discs_left, _side_total(true), _side_total(false), match_you, match_them)


func _arm_next_disc(_announce := true) -> void:
	if discs_left <= 0:
		if gesture != null:
			gesture.busy()
		active_puck = null
		disc.bind_puck(null)
		return
	active_puck = _spawn_puck(true, Vector2(0.0, Metrics.PLAYER_START_Z))
	disc.bind_puck(active_puck)
	_show_board(int(current_level["number"]), discs_left)
	_begin_ready()

func _load_level(level_index: int) -> void:
	var clamped := clampi(level_index, 0, level_manager.get_level_count() - 1)
	if clamped == current_level_index and end_applied:
		match_you = maxi(0, match_you - last_award_you)
		match_them = maxi(0, match_them - last_award_them)
	resolving = false
	end_applied = false
	last_award_you = 0
	last_award_them = 0
	current_level_index = clamped
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
	if feel != null:
		feel.aim(power_ratio)
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
	if gesture != null:
		gesture.busy()
	discs_left -= 1
	resolving = true
	if feel != null:
		feel.release(disc.power_ratio)
	ui.show_power(0.0)
	ui.show_in_motion()
	_show_board(int(current_level["number"]), discs_left)

func _on_table_settled() -> void:
	disc.mark_shot_finished()
	var shot_points := 0
	var sunk := false
	var ditched := false
	if active_puck != null and active_puck.is_player:
		shot_points = int(active_puck.ring_points())
		sunk = bool(active_puck.sunk)
		ditched = bool(active_puck.in_ditch)
	if discs_left > 0:
		if feel != null:
			feel.settled(0.2 if sunk or shot_points >= 15 else 2.5)
		ui.show_landed(shot_points, sunk, ditched)
		_show_board(int(current_level["number"]), discs_left)
		_check_shot_goal()
		_arm_next_disc(false)
	else:
		_present_end()
		active_puck = null
		disc.bind_puck(null)

func _show_board(level_number: int, remaining: int) -> void:
	ui.show_match_status(level_number, remaining, _side_total(true), _side_total(false), match_you, match_them)

func _present_end() -> void:
	var you_items := _side_items(true)
	var them_items := _side_items(false)
	var you := _sum(you_items)
	var them := _sum(them_items)
	var award_you := 0
	var award_them := 0
	if you > them:
		award_you = you - them
	elif them > you:
		award_them = them - you
	if not end_applied:
		match_you += award_you
		match_them += award_them
		last_award_you = award_you
		last_award_them = award_them
		end_applied = true
	var has_next: bool = current_level_index < level_manager.get_level_count() - 1
	if feel != null:
		feel.settled(0.4)
	ui.show_end_overview(int(current_level["number"]), str(current_level["difficulty"]), you_items, them_items, award_you, award_them, match_you, match_them, match_target, has_next)
	_show_board(int(current_level["number"]), 0)
	_check_shot_goal()
	_check_match_winner()

func _hit(speed: float) -> void:
	if feel == null or _hit_wait > 0.0:
		return
	_hit_wait = 0.12
	feel.contact(speed, false, false)


func _check_shot_goal() -> void:
	if goal_sent or (goal != "hole" and goal != "fifteen"):
		return
	for puck in pucks:
		if not bool(puck.is_player):
			continue
		var met := false
		if goal == "hole" and bool(puck.sunk):
			met = true
		elif goal == "fifteen" and int(puck.ring_points()) >= 15:
			met = true
		if met:
			goal_sent = true
			goal_cleared.emit()
			return


func _check_match_winner() -> void:
	var you_won := match_you >= match_target and match_you >= match_them
	var they_won := match_them >= match_target and match_them > match_you
	if (you_won or they_won) and not match_reported:
		match_reported = true
		match_decided.emit(you_won)


func _on_reset_requested() -> void:
	_load_level(current_level_index)

func _on_next_level_requested() -> void:
	if current_level_index < level_manager.get_level_count() - 1:
		_load_level(current_level_index + 1)
