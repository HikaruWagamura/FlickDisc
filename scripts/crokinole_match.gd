extends Node3D

signal goal_cleared
signal match_decided(you_won: bool)

## FlickDisc round board. Eight discs each, cream versus brown. Pull and
## the five bars stay. Legal shots, 20s, and the round score follow the
## posted rules.

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
var match_target := 4
var start_level := 0
var goal := ""
var goal_sent := false
var match_reported := false
var player_tint := Color("#d4222a")
var feel
var _hit_wait := 0.0
var gesture
var fan
var cue
var _cue_compare := false
var place_x := 0.0
var aim_lock := 0.0
var opponent_left := 0
var ai_turn := false
var _ai_token := 0
var end_number := 1
var shooting_puck
var required_hit := false
var required_inner := false
var shot_hit_opp := false
var shot_hit_speed := 0.0
var shot_struck: Array = []
var _test_hold_turns := false
const PULL_BACK := 0.42
const AIM_CONE := 0.58
const CURSOR_SPAN := 0.09

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
	if OS.get_cmdline_user_args().has("--crokshot") or OS.get_cmdline_user_args().has("--kitshot"):
		get_tree().root.set_meta("flickdisc_kit", {
			"bowl_skin": "camo",
			"bowl_color": 6,
			"disc_skin": "camo",
			"disc_color": 0,
		})
	_load_level(start_level)
	if OS.get_cmdline_user_args().has("--cuetest"):
		call_deferred("_cuetest")
	elif OS.get_cmdline_user_args().has("--crokshot"):
		call_deferred("_crokshot")
	elif OS.get_cmdline_user_args().has("--crokrules"):
		call_deferred("_crokrules")


func _process(delta: float) -> void:
	if gesture != null:
		gesture.advance(delta)
	_sync_fan()

func _setup_view() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#1A0C12")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#E8C8B0")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.96
	environment.glow_enabled = true
	environment.glow_intensity = 0.22
	environment.glow_strength = 0.52
	environment.glow_bloom = 0.03
	environment.glow_hdr_threshold = 1.18
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 50.0
	camera.near = 0.04
	camera.far = 24.0
	camera.current = true
	add_child(camera)
	# Sit behind the shooting disc with room under it to pull back.
	camera.position = Vector3(0.0, 1.88, 2.58)
	camera.look_at(Vector3(0.0, 0.02, 0.10), Vector3.UP)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	key.light_color = Color("#fff3e4")
	key.light_energy = 1.05
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
		if puck.removed or puck.sunk or not puck.moving:
			continue
		var speed: float = Vector2(puck.velocity.x, puck.velocity.z).length()
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
	if puck.removed or puck.sunk:
		return
	var distance: float = puck.flat().length()
	if not puck.in_ditch and distance > Metrics.SURFACE_RADIUS - Metrics.DISC_RADIUS * 0.25:
		puck.in_ditch = true
		if puck == shooting_puck and ui != null:
			ui.slap("out")
	if puck.in_ditch:
		puck.position.y = Metrics.DITCH_Y
	else:
		puck.position.y = Metrics.DISC_CENTER_Y

func _solve_pegs() -> void:
	for puck in pucks:
		if puck.removed or puck.sunk or puck.in_ditch:
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
				_hit(velocity.length(), "peg")
				puck.moving = true
				puck.stop_timer = 0.0

func _solve_pucks() -> void:
	for index in pucks.size():
		var first = pucks[index]
		if first.removed or first.sunk:
			continue
		for other_index in range(index + 1, pucks.size()):
			var second = pucks[other_index]
			if second.removed or second.sunk:
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
				_mark_struck(first)
				_mark_struck(second)
				var opposite: bool = bool(first.is_player) != bool(second.is_player)
				if opposite:
					shot_hit_opp = true
					shot_hit_speed = maxf(shot_hit_speed, approach)
				_hit(approach, "disc" if opposite else "own")
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
		if puck.removed or puck.sunk:
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
		if puck.removed or puck.sunk or puck.in_ditch:
			continue
		var speed: float = Vector2(puck.velocity.x, puck.velocity.z).length()
		# The cup is only a little wider than the disc, so the centre has to be over it.
		if puck.flat().length() + Metrics.DISC_RADIUS * 0.62 <= Metrics.HOLE_RADIUS and speed < 1.05:
			puck.sink_into_hole()
			if puck == shooting_puck and ui != null:
				ui.slap("hole")

func _all_stopped() -> bool:
	for puck in pucks:
		if puck.removed:
			continue
		if puck.moving and not puck.sunk:
			return false
	return true

func _side_total(player_side: bool) -> int:
	var total := 0
	for puck in pucks:
		if puck.removed:
			continue
		if bool(puck.is_player) != player_side:
			continue
		total += int(puck.ring_points())
	return total

func _side_items(player_side: bool) -> Array:
	var items: Array = []
	for puck in pucks:
		if puck.removed:
			continue
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
	shot.aim_set.connect(_on_aim_set)
	shot.kept_aim.connect(_on_aim_kept)
	shot.opened_take.connect(_on_take_opened)
	shot.cancelled_pull.connect(_on_pull_cancelled)
	shot.fired.connect(_on_shot_fired)
	add_child(shot)
	gesture = shot
	gesture.direct = true
	gesture.direct_runup = 0.34
	fan = preload("res://scripts/shot_fan.gd").new()
	fan.name = "ShotFan"
	ui.add_child(fan)
	cue = preload("res://scripts/aim_cue.gd").new()
	cue.name = "AimCue"
	cue.set_heads(5)
	cue.set_style(0)
	cue.set_path_start(0.06)
	cue.set_size_scale(0.98)
	add_child(cue)


func _on_place_at(spot: Vector3) -> void:
	place_x = clampf(atan2(spot.x, maxf(spot.z, 0.02)), -PI * 0.25, PI * 0.25)
	_snap_disc()
	ui.show_sliding()


func _on_aim_set(amount: float) -> void:
	aim_lock = amount
	ui.show_sliding()


func _on_aim_kept() -> void:
	ui.show_aim_ready()


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


func _on_shot_fired(power: float, _needle: float) -> void:
	_snap_disc()
	if gesture != null and gesture.direct:
		disc.fire_at(gesture.direct_aim, power)
		return
	disc.fire_at(_aim_from(0.0), power)


func _snap_disc() -> void:
	if active_puck == null:
		return
	active_puck.set_flat(_spot_on_arc(place_x, true))
	active_puck.rotation.y = 0.0
	disc.global_position = active_puck.global_position
	if gesture != null:
		gesture.anchor = disc.global_position


func _spot_on_arc(angle: float, south: bool) -> Vector2:
	var r := Metrics.start_radius()
	var a := clampf(angle, -PI * 0.25, PI * 0.25)
	if south:
		return Vector2(sin(a) * r, cos(a) * r)
	return Vector2(sin(a) * r, -cos(a) * r)


func _rest_flat() -> Vector2:
	return _spot_on_arc(place_x, true)


func _rest_pos() -> Vector3:
	var at := _rest_flat()
	return Vector3(at.x, 0.02, at.y)


func _pull_flat(power: float) -> Vector2:
	var at := _rest_flat()
	if at.length() < 0.001:
		return at + Vector2(0.0, power * PULL_BACK)
	return at + at.normalized() * power * PULL_BACK


func _aim_from(needle: float) -> Vector3:
	var at := _spot_on_arc(place_x, true)
	var toward := Vector2(-at.x, -at.y)
	if toward.length() < 0.001:
		toward = Vector2(0.0, -1.0)
	var base := Vector3(toward.x, 0.0, toward.y).normalized()
	var turn := aim_lock * AIM_CONE + needle * CURSOR_SPAN
	return base.rotated(Vector3.UP, -turn)


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
	if _cue_compare:
		return
	if gesture.direct:
		_sync_direct()
		return
	var placed := _rest_pos()
	gesture.anchor = placed
	var phase := str(gesture.phase)
	var live: bool = active_puck != null and not resolving and not bool(disc.shot_in_progress) and phase != "busy"
	var pulling: bool = phase == "pull"
	var power: float = gesture.read_power() if pulling else 0.0
	if live:
		active_puck.set_flat(_pull_flat(power))
		active_puck.rotation.y = 0.0
		disc.global_position = active_puck.global_position
		if pulling:
			disc.preview_take(_aim_from(0.0), maxf(power, 0.12))
			ui.show_aiming(power)
			ui.show_power(power)
			if feel != null:
				feel.aim(power)
		else:
			disc.show_aim_line(Vector3.ZERO, false)
			ui.show_power(0.0)
	var live_pos: Vector3 = placed
	if active_puck != null:
		live_pos = active_puck.global_position
	var cursor_at := camera.unproject_position(live_pos + Vector3(0.0, 0.06, 0.0))
	fan.present(cursor_at, power, 0.0, false, -PI * 0.5, 80.0)
	if cue != null:
		if live and pulling:
			var path: PackedVector3Array = disc.cue_points(power)
			if path.size() >= 2:
				cue.present(path, power)
			else:
				cue.clear()
		else:
			cue.clear()
	fan.set_dots(PackedVector2Array(), false)
	fan.set_line(Vector2.ZERO, Vector2.ZERO, false)
	fan.set_aim(Vector2.ZERO, Vector2.ZERO, false)
	fan.set_disc(cursor_at, false)


func _sync_direct() -> void:
	var placed := _rest_pos()
	gesture.anchor = placed
	var phase := str(gesture.phase)
	var live: bool = active_puck != null and not resolving and not bool(disc.shot_in_progress) and phase != "busy"
	var pulling: bool = live and phase == "pull"
	var power: float = gesture.direct_power if pulling else 0.0
	if live:
		if pulling:
			var hold: Vector3 = gesture.direct_hold
			active_puck.set_flat(Vector2(hold.x, hold.z))
			active_puck.rotation.y = 0.0
			disc.global_position = active_puck.global_position
			disc.preview_take(gesture.direct_aim, maxf(power, 0.12))
			ui.show_aiming(power)
			ui.show_power(power)
			if feel != null:
				feel.aim(power)
		else:
			active_puck.set_flat(_rest_flat())
			active_puck.rotation.y = 0.0
			disc.global_position = active_puck.global_position
			disc.show_aim_line(Vector3.ZERO, false)
			ui.show_power(0.0)
	var live_pos: Vector3 = placed
	if active_puck != null:
		live_pos = active_puck.global_position
	var cursor_at := camera.unproject_position(live_pos + Vector3(0.0, 0.06, 0.0))
	fan.present(cursor_at, power, 0.0, false, -PI * 0.5, 80.0)
	if cue != null:
		if pulling:
			var path: PackedVector3Array = disc.cue_points(power)
			if path.size() >= 2:
				cue.present(path, power)
			else:
				cue.clear()
		else:
			cue.clear()
	fan.set_dots(PackedVector2Array(), false)
	fan.set_line(Vector2.ZERO, Vector2.ZERO, false)
	fan.set_aim(Vector2.ZERO, Vector2.ZERO, false)
	fan.set_disc(cursor_at, false)


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
	var tint_color := Metrics.YOU_TINT if player_disc else Metrics.THEM_TINT
	var kit_index := 0
	for other in pucks:
		if bool(other.is_player) == player_disc:
			kit_index += 1
	puck.setup(player_disc, tint_color, kit_index)
	puck.set_flat(spot)
	puck.add_to_group("crokinole_puck")
	pucks_root.add_child(puck)
	pucks.append(puck)
	return puck

func _spot_free(spot: Vector2) -> bool:
	if spot.length() > Metrics.start_radius() + 0.004:
		return false
	for peg in Metrics.peg_positions():
		if spot.distance_to(Vector2(peg.x, peg.z)) < Metrics.PEG_RADIUS + Metrics.DISC_RADIUS + 0.02:
			return false
	for puck in pucks:
		if puck.removed or puck.sunk:
			continue
		if spot.distance_to(puck.flat()) < Metrics.DISC_RADIUS * 2.15:
			return false
	return true

func _start_spot() -> Vector2:
	var angles := [0.0, 0.12, -0.12, 0.22, -0.22, 0.35, -0.35]
	for angle in angles:
		var candidate := _spot_on_arc(float(angle), true)
		if _spot_free(candidate):
			return candidate
	return _spot_on_arc(0.0, true)

func _begin_ready() -> void:
	place_x = 0.0
	aim_lock = 0.0
	_snap_disc()
	if gesture != null:
		gesture.arm()
		var at := _spot_on_arc(place_x, true)
		gesture.anchor = Vector3(at.x, 0.02, at.y)
	ui.show_touch(end_number, discs_left, _side_total(true), _side_total(false), match_you, match_them, opponent_left, _rule_prompt(false))


func _arm_next_disc(_announce := true) -> void:
	if discs_left <= 0:
		if gesture != null:
			gesture.busy()
		active_puck = null
		disc.bind_puck(null)
		return
	active_puck = _spawn_puck(true, _spot_on_arc(0.0, true))
	disc.bind_puck(active_puck)
	_show_board()
	_begin_ready()

func _load_level(level_index: int) -> void:
	var clamped := clampi(level_index, 0, level_manager.get_level_count() - 1)
	if end_applied:
		match_you = maxi(0, match_you - last_award_you)
		match_them = maxi(0, match_them - last_award_them)
	current_level_index = clamped
	current_level = level_manager.get_level(current_level_index)
	_start_round()

func _start_round() -> void:
	resolving = false
	end_applied = false
	last_award_you = 0
	last_award_them = 0
	_ai_token += 1
	ai_turn = false
	shooting_puck = null
	discs_left = Metrics.DISCS_PER_PLAYER
	opponent_left = Metrics.DISCS_PER_PLAYER
	_clear_pucks()
	_arm_next_disc()

func _on_disc_aim_changed(_direction: Vector3, power_ratio: float) -> void:
	if gesture == null or str(gesture.phase) != "pull":
		return
	if feel != null:
		feel.aim(power_ratio)
	if power_ratio > 0.0:
		ui.show_aiming(power_ratio)
		ui.show_power(power_ratio)

func _on_disc_bias_changed(bias_ratio: float) -> void:
	ui.show_bias(bias_ratio)
	if disc.is_aiming:
		ui.show_aiming(disc.power_ratio)

func _on_bias_cycle_requested() -> void:
	pass

func _on_disc_shot_started() -> void:
	if gesture != null:
		gesture.busy()
	discs_left -= 1
	_begin_shot_rules(active_puck)
	resolving = true
	if feel != null:
		feel.release(disc.power_ratio)
	ui.show_power(0.0)
	ui.show_in_motion()
	_show_board()

func _on_table_settled() -> void:
	disc.mark_shot_finished()
	var foul := _apply_shot_rules()
	var shot_points := 0
	var sunk := false
	var ditched := false
	if shooting_puck != null:
		shot_points = int(shooting_puck.ring_points())
		sunk = bool(shooting_puck.sunk) and foul == ""
		ditched = bool(shooting_puck.in_ditch) or bool(shooting_puck.removed)
	if feel != null:
		feel.settled(0.2 if sunk or shot_points >= 15 else 2.5)
	ui.show_landed(shot_points, sunk, ditched, foul)
	_show_board()
	_check_shot_goal()
	if _test_hold_turns:
		return
	if ai_turn:
		ai_turn = false
		if discs_left > 0:
			_arm_next_disc(false)
		else:
			_present_end()
			active_puck = null
			disc.bind_puck(null)
		return
	active_puck = null
	disc.bind_puck(null)
	if opponent_left > 0:
		_begin_opponent_shot()
		return
	if discs_left > 0:
		_arm_next_disc(false)
	else:
		_present_end()


func _begin_opponent_shot() -> void:
	_ai_token += 1
	var token := _ai_token
	ai_turn = true
	if gesture != null:
		gesture.busy()
	ui.show_opponent()
	await get_tree().create_timer(0.45).timeout
	if token != _ai_token or not is_inside_tree():
		return
	opponent_left = maxi(0, opponent_left - 1)
	var spot := _spot_on_arc(randf_range(-PI * 0.18, PI * 0.18), false)
	var puck = _spawn_puck(false, spot)
	var plan := _ai_plan(puck.global_position)
	var aim: Vector3 = plan["aim"]
	var power: float = plan["power"]
	puck.velocity = aim * lerpf(Metrics.MIN_SPEED, Metrics.MAX_SPEED, power)
	puck.velocity.y = 0.0
	puck.moving = true
	puck.played = true
	puck.shot_bias = 0.0
	puck.stop_timer = 0.0
	_begin_shot_rules(puck)
	resolving = true
	_show_board()

func _ai_plan(from: Vector3) -> Dictionary:
	var foes: Array = _surface_pucks(true)
	var target := Vector3.ZERO
	var power := 0.76
	var miss := 0.10
	if start_level <= 0:
		miss = 0.20
	elif start_level >= 4:
		miss = 0.04
	if _test_hold_turns:
		miss = 0.0
	if foes.size() > 0:
		var nearest = foes[0]
		var best := INF
		for foe in foes:
			var dist: float = from.distance_to(foe.global_position)
			if dist < best:
				best = dist
				nearest = foe
		target = nearest.global_position
		target.x += randf_range(-miss, miss)
		target.z += randf_range(-miss * 0.35, miss * 0.35)
		power = clampf(best / 2.35 + randf_range(-0.04, 0.06), 0.48, 0.92)
	else:
		target = Vector3(randf_range(-miss * 0.25, miss * 0.25), 0.0, randf_range(-miss * 0.25, miss * 0.25))
		if start_level >= 4:
			power = randf_range(0.74, 0.82)
		elif start_level <= 0:
			power = randf_range(0.58, 0.80)
		else:
			power = randf_range(0.70, 0.82)
	var aim := target - from
	aim.y = 0.0
	if aim.length() < 0.001:
		aim = Vector3(0.0, 0.0, 1.0)
	return {"aim": aim.normalized(), "power": power, "target": target}

func _surface_pucks(player_side: bool, except = null) -> Array:
	var found: Array = []
	for puck in pucks:
		if puck == except or puck.removed:
			continue
		if bool(puck.is_player) != player_side:
			continue
		if not puck.on_playing_surface():
			continue
		found.append(puck)
	return found

func _mark_struck(puck) -> void:
	if puck == null or puck in shot_struck:
		return
	shot_struck.append(puck)


func _begin_shot_rules(puck) -> void:
	shooting_puck = puck
	shot_hit_opp = false
	shot_hit_speed = 0.0
	shot_struck.clear()
	required_hit = false
	required_inner = false
	if puck != null:
		puck.played = true
		puck.mark_start()
		var foes := _surface_pucks(not bool(puck.is_player), puck)
		required_hit = foes.size() > 0
		required_inner = foes.size() == 0
	for other in pucks:
		other.mark_start()
	if ui != null:
		ui.reset_callouts()

func _shot_touched_opponent() -> bool:
	if shot_hit_opp:
		return true
	if shooting_puck == null:
		return false
	for puck in pucks:
		if puck == shooting_puck or puck.removed:
			continue
		if bool(puck.is_player) == bool(shooting_puck.is_player):
			continue
		if puck in shot_struck:
			return true
		if puck.displaced_from_start() > Metrics.MOVE_THRESHOLD:
			return true
	return false

func _apply_shot_rules() -> String:
	if shooting_puck == null:
		return ""
	if required_inner and not _inner_satisfied():
		_take_off_struck()
		if ui != null:
			ui.slap("foul")
		return "not_inner"
	if required_hit and not _shot_touched_opponent():
		_take_off_struck()
		if ui != null:
			ui.slap("foul")
		return "no_hit"
	_park_twenties()
	return ""


func _inner_satisfied() -> bool:
	if shooting_puck != null and shooting_puck.in_15_or_20():
		return true
	for puck in shot_struck:
		if puck != null and puck.in_15_or_20():
			return true
	return false


func _take_off_struck() -> void:
	if shooting_puck != null:
		shooting_puck.take_off()
	for puck in shot_struck:
		if puck == null or puck == shooting_puck:
			continue
		puck.take_off()


func _park_twenties() -> void:
	var you_n := 0
	var them_n := 0
	for puck in pucks:
		if puck == null or not bool(puck.sunk) or bool(puck.removed):
			continue
		if bool(puck.is_player):
			puck.park_twenty(you_n)
			you_n += 1
		else:
			puck.park_twenty(them_n)
			them_n += 1


func _rule_prompt(for_opponent: bool) -> String:
	var foes := _surface_pucks(for_opponent)
	if foes.size() > 0:
		return "THEIR DISC IS ON  •  YOU MUST HIT IT"
	return "BOARD CLEAR  •  REACH 15 OR THE 20"

func _show_board() -> void:
	ui.show_match_status(end_number, discs_left, _side_total(true), _side_total(false), match_you, match_them, opponent_left)

func _present_end() -> void:
	var you_items := _side_items(true)
	var them_items := _side_items(false)
	var you := _sum(you_items)
	var them := _sum(them_items)
	var award_you := 0
	var award_them := 0
	if you > them:
		award_you = 2
	elif them > you:
		award_them = 2
	else:
		award_you = 1
		award_them = 1
	if not end_applied:
		match_you += award_you
		match_them += award_them
		last_award_you = award_you
		last_award_them = award_them
		end_applied = true
	var has_next := end_number < Metrics.ROUNDS_PER_GAME
	if feel != null:
		feel.settled(0.4)
	ui.show_end_overview(end_number, "CROCK & HOLE", you_items, them_items, award_you, award_them, match_you, match_them, Metrics.ROUNDS_PER_GAME, has_next)
	_show_board()
	_check_shot_goal()
	_check_match_winner()

func _hit(speed: float, kind: String = "disc") -> void:
	if feel != null and _hit_wait <= 0.0:
		_hit_wait = 0.12
		feel.contact(speed, false, false)
	if ui == null:
		return
	if kind == "peg":
		ui.slap("peg")
	elif kind == "disc":
		ui.slap("disc", speed)


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
	if end_number < Metrics.ROUNDS_PER_GAME:
		return
	if match_reported:
		return
	match_reported = true
	match_decided.emit(match_you >= match_them)


func _on_reset_requested() -> void:
	_load_level(current_level_index)

func _on_next_level_requested() -> void:
	if end_number >= Metrics.ROUNDS_PER_GAME:
		match_you = 0
		match_them = 0
		match_reported = false
		end_number = 1
	else:
		end_number += 1
	end_applied = false
	last_award_you = 0
	last_award_them = 0
	_start_round()


func _crokshot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _dump_cue_shot("crok_lounge")
	if active_puck == null:
		_arm_next_disc()
	_snap_disc()
	await RenderingServer.frame_post_draw
	await _dump_cue_shot("crok_hole_open")
	if gesture != null and active_puck != null:
		gesture.direct = true
		gesture.anchor = active_puck.global_position
		gesture.direct_aim = Vector3(0.0, 0.0, -1.0)
		gesture.direct_power = 0.92
		gesture.direct_hold = active_puck.global_position + Vector3(0.0, 0.0, 0.30)
		gesture._raw_aim = Vector3(0.0, 0.0, -1.0)
		gesture._raw_power = 0.92
		gesture._raw_hold = gesture.direct_hold
		gesture.phase = "pull"
	disc.preview_take(Vector3(0.0, 0.0, -1.0), 0.92)
	if cue != null:
		cue.set_heads(5)
		cue.present(disc.cue_points(0.92), 0.92)
	ui.show_power(0.92)
	ui.show_aiming(0.92)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _dump_cue_shot("crok_pull_room")
	_test_hold_turns = true
	if gesture != null:
		gesture.busy()
	_snap_disc()
	disc.fire_at(Vector3(0.0, 0.0, -1.0), 0.78)
	var waited := 0.0
	while waited < 2.4:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if shooting_puck != null and bool(shooting_puck.sunk):
			break
	await RenderingServer.frame_post_draw
	await _dump_cue_shot("crok_hole_drop")
	var dropped: bool = shooting_puck != null and bool(shooting_puck.sunk)
	print("CROKSHOT hole_drop=%s" % dropped)
	print("CROKSHOT done")
	get_tree().quit(0)


func _crokrules() -> void:
	_test_hold_turns = true
	await get_tree().process_frame
	await get_tree().process_frame
	if active_puck == null:
		_arm_next_disc()
	ui.status_label.text = _rule_prompt(false)
	if ui != null:
		ui.show_rules(true)
	_show_board()
	await RenderingServer.frame_post_draw
	await _dump_cue_shot("crok_rules")
	if ui != null:
		ui.show_rules(false)
	_show_board()
	await RenderingServer.frame_post_draw
	await _dump_cue_shot("crok_board_clear")
	var foe = _spawn_puck(false, Vector2(0.62, 0.18))
	foe.played = true
	foe.mark_start()
	_begin_ready()
	print("RULETEST start required_hit=%s required_inner=%s foes=%d" % [true, false, _surface_pucks(false, active_puck).size()])
	_snap_disc()
	disc.fire_at(Vector3(0.0, 0.0, -1.0), 0.62)
	await _wait_settled(8.0)
	var miss_off: bool = active_puck != null and bool(active_puck.removed)
	print("RULETEST miss_removed=%s hit=%s foul_expected=true foe_live=%s" % [miss_off, shot_hit_opp, foe.on_playing_surface()])
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	await _dump_cue_shot("crok_no_hit")
	end_applied = false
	_start_round()
	await get_tree().process_frame
	if active_puck == null:
		_arm_next_disc()
	var target_foe = _spawn_puck(false, Vector2(0.0, 0.22))
	target_foe.played = true
	_begin_ready()
	_snap_disc()
	disc.fire_at(Vector3(0.0, 0.0, -1.0), 0.78)
	await get_tree().create_timer(0.42).timeout
	await RenderingServer.frame_post_draw
	await _dump_cue_shot("crok_hit")
	await _wait_settled(8.0)
	var hit_ok: bool = shot_hit_opp
	var stayed: bool = active_puck != null and not bool(active_puck.removed)
	print("RULETEST hit=%s stayed=%s" % [hit_ok, stayed])
	end_applied = false
	_start_round()
	await get_tree().process_frame
	if active_puck == null:
		_arm_next_disc()
	active_puck.played = true
	active_puck.set_flat(Vector2(0.55, 0.38))
	var from := Vector3(0.0, 0.0, -Metrics.PLAYER_START_Z)
	var plan := _ai_plan(from)
	var aim: Vector3 = plan["aim"]
	var target: Vector3 = plan["target"]
	print("RULETEST ai_aim_x=%.3f ai_target_x=%.3f ai_power=%.2f toward_player=%s" % [aim.x, target.x, plan["power"], target.x > 0.2])
	ui.slap("disc", 2.4)
	ui.status_label.text = "THEIR DISC IS ON  •  YOU MUST HIT IT"
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _dump_cue_shot("crok_callout_bighit")
	await get_tree().create_timer(0.8).timeout
	print("RULETEST done miss_ok=%s hit_ok=%s ai_ok=%s" % [miss_off, hit_ok, target.x > 0.2])
	get_tree().quit(0)


func _wait_settled(timeout: float = 8.0) -> void:
	var elapsed := 0.0
	while elapsed < timeout:
		if not resolving and _all_stopped():
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if resolving:
		resolving = false
		_on_table_settled()


func _cuetest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_cue_compare = true
	if gesture != null:
		gesture.busy()
	if active_puck == null:
		_arm_next_disc()
	_snap_disc()
	ui.status_label.text = ""
	var steps := [
		{"power": 0.18, "aim": Vector3(0.0, 0.0, -1.0), "file": "crok_blocks_light", "title": "CROCK & HOLE  •  LIGHT  •  STRAIGHT"},
		{"power": 0.52, "aim": Vector3(0.12, 0.0, -1.0), "file": "crok_blocks_mid", "title": "CROCK & HOLE  •  MID  •  STRAIGHT"},
		{"power": 0.94, "aim": Vector3(0.0, 0.0, -1.0), "file": "crok_blocks_ahead", "title": "CROCK & HOLE  •  FULL  •  STRAIGHT"},
		{"power": 0.94, "aim": Vector3(-0.18, 0.0, -1.0), "file": "crok_blocks_left", "title": "CROCK & HOLE  •  FULL  •  AIM LEFT"},
	]
	for step in steps:
		var aim: Vector3 = step["aim"]
		disc.preview_take(aim.normalized(), float(step["power"]))
		if cue != null:
			cue.present(disc.cue_points(float(step["power"])), float(step["power"]))
		ui.status_label.text = str(step["title"])
		await get_tree().create_timer(1.4).timeout
		await _dump_cue_shot(str(step["file"]))
		await get_tree().create_timer(0.6).timeout
	print("CROK CUETEST done")
	get_tree().quit(0)


func _dump_cue_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var tex: Texture2D = get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute("/tmp/cue_compare")
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	img.save_png("/tmp/cue_compare/%s.png" % name)
	img.save_png("/opt/cursor/artifacts/%s.png" % name)
	print("CUE_SHOT %s" % name)
