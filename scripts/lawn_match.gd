extends Node3D

signal goal_cleared
signal match_decided(you_won: bool)

const RinkScript := preload("res://scripts/rink_view.gd")
const DiscScript := preload("res://scripts/disc_controller.gd")
const LevelScript := preload("res://scripts/level_manager.gd")
const ScoreScript := preload("res://scripts/score_manager.gd")
const BowlScript := preload("res://scripts/bowl.gd")
const FeelScript := preload("res://scripts/feel.gd")

var disc
var ui
var rink
var level_manager
var score_manager
var feel
var jack
var settled: Array = []
var jack_home := Vector3.ZERO
const BOWLS_PER_END := 4
const SHOT_METRES := 2.0
const MATCHES := [
	{"ends": 2, "points": 0, "label": "2 ENDS"},
	{"ends": 4, "points": 0, "label": "4 ENDS"},
	{"ends": 6, "points": 0, "label": "6 ENDS"},
	{"ends": 0, "points": 11, "label": "TO 11"},
	{"ends": 0, "points": 21, "label": "TO 21"},
]

var throws_left := BOWLS_PER_END
var throw_index := 0
var shot_token := 0
var delivering_jack := true
var hand_sign := -1.0
var bias_index := 1
var ditch_mode := false
var jack_length := 0.0
var match_index := 1
var end_number := 1
var match_points := 0
var match_complete := false
var match_reported := false
var goal := ""
var goal_sent := false
var rack: Array = []
var gesture
var fan
var place_x := 0.0
var aim_lock := 0.0
var line_z := 0.0
var _return_token := 0
const PLACE_HALF := 1.65
const PULL_BACK := 1.15
const AIM_CONE := 0.26
const CURSOR_SPAN := 0.05


func _ready() -> void:
	ui = get_node("UI")
	level_manager = LevelScript.new()
	score_manager = ScoreScript.new()
	feel = FeelScript.new()
	feel.name = "Feel"
	add_child(level_manager)
	add_child(score_manager)
	add_child(feel)

	rink = RinkScript.new()
	rink.name = "Rink"
	add_child(rink)

	jack = BowlScript.new()
	jack.name = "Jack"
	jack.setup_jack()
	add_child(jack)

	disc = DiscScript.new()
	disc.name = "PlayerDisc"
	add_child(disc)

	disc.aim_changed.connect(_on_disc_aim_changed)
	disc.bias_changed.connect(_on_disc_bias_changed)
	disc.shot_started.connect(_on_disc_shot_started)
	disc.shot_stopped.connect(_on_disc_shot_stopped)
	disc.impacted.connect(_on_disc_impacted)
	ui.reset_requested.connect(_on_reset_requested)
	ui.next_level_requested.connect(_on_next_level_requested)
	ui.bias_cycle_requested.connect(_on_bias_cycle_requested)
	ui.ditch_option_requested.connect(_on_ditch_option_requested)
	ui.match_cycle_requested.connect(_on_match_cycle_requested)
	ui.hand_selected.connect(_on_hand_selected)
	ui.bias_selected.connect(_on_bias_selected)
	_wire_shot()
	_lock_portrait_on_device()
	_build_rack()
	_new_match()


func _process(delta: float) -> void:
	if gesture != null:
		gesture.advance(delta)
	_sync_fan()
	var fastest := 0.0
	if disc != null and disc.shot_in_progress:
		fastest = disc.velocity.length()
		for body in disc.obstacles:
			fastest = maxf(fastest, body.velocity.length())
	if feel != null:
		feel.set_roll(fastest / DiscScript.MAX_SPEED)


func _lock_portrait_on_device() -> void:
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)


func _input(event: InputEvent) -> void:
	if feel != null and (event is InputEventMouseButton or event is InputEventScreenTouch):
		feel.unlock()


func _wire_shot() -> void:
	var shot := preload("res://scripts/shot_gesture.gd").new()
	shot.name = "ShotGesture"
	shot.camera = rink.view_camera()
	shot.hit_test = _pointer_hits_disc
	shot.board_point = _board_point
	shot.place_at.connect(_on_place_at)
	shot.aim_set.connect(_on_aim_set)
	shot.opened_take.connect(_on_take_opened)
	shot.cancelled_pull.connect(_on_pull_cancelled)
	shot.fired.connect(_on_shot_fired)
	add_child(shot)
	gesture = shot
	fan = preload("res://scripts/shot_fan.gd").new()
	fan.name = "ShotFan"
	ui.add_child(fan)


func _begin_ready() -> void:
	line_z = disc.start_position.z
	place_x = 0.0
	aim_lock = 0.0
	disc.start_position = Vector3(0.0, 0.0, line_z)
	disc.global_position = disc.start_position
	if gesture != null:
		gesture.arm()
		gesture.anchor = disc.start_position
	ui.show_place_line(delivering_jack)


func _on_place_at(spot: Vector3) -> void:
	place_x = clampf(spot.x, -PLACE_HALF, PLACE_HALF)
	disc.start_position = Vector3(place_x, 0.0, line_z)
	disc.global_position = disc.start_position
	rink.release_head()
	ui.show_sliding(delivering_jack)


func _on_aim_set(amount: float) -> void:
	aim_lock = amount
	ui.show_aiming_line(delivering_jack)


func _on_take_opened() -> void:
	disc.global_position = Vector3(place_x, 0.0, line_z)
	ui.show_take_shot(delivering_jack)
	ui.set_power_ratio(0.0)
	feel.tap()


func _on_pull_cancelled() -> void:
	disc.global_position = Vector3(place_x, 0.0, line_z)
	if disc.is_aiming:
		disc.preview_take(Vector3(0.0, 0.0, -1.0), 0.0)
	ui.show_take_shot(delivering_jack)
	ui.set_power_ratio(0.0)


func _on_shot_fired(power: float, needle: float) -> void:
	disc.start_position = Vector3(place_x, 0.0, line_z)
	disc.fire_taken(_aim_from(needle), power)


func _aim_from(needle: float) -> Vector3:
	var turn := aim_lock * AIM_CONE + needle * CURSOR_SPAN
	return Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, -turn)


func _pointer_hits_disc(screen_position: Vector2) -> bool:
	if disc == null or not disc.visible or disc.shot_in_progress:
		return false
	var cam: Camera3D = rink.view_camera()
	if cam == null:
		return false
	var disc_screen := cam.unproject_position(disc.global_position)
	var edge := cam.unproject_position(disc.global_position + Vector3(disc.radius * 2.4, 0.0, 0.0))
	return disc_screen.distance_to(screen_position) <= maxf(disc_screen.distance_to(edge), 110.0)


func _board_point(screen_position: Vector2) -> Vector3:
	var cam: Camera3D = rink.view_camera()
	if cam == null:
		return disc.global_position
	var origin := cam.project_ray_origin(screen_position)
	var direction := cam.project_ray_normal(screen_position)
	if absf(direction.y) < 0.00001:
		return disc.global_position
	var distance := (0.0 - origin.y) / direction.y
	if distance < 0.0:
		return disc.global_position
	return origin + direction * distance


func _facing(origin: Vector3, aim: Vector3) -> float:
	var cam: Camera3D = rink.view_camera()
	if cam == null:
		return -PI * 0.5
	var from := cam.unproject_position(origin)
	var toward := cam.unproject_position(origin + aim * 0.8)
	var delta := toward - from
	if delta.length() < 3.0:
		return -PI * 0.5
	return delta.angle()


func _sync_fan() -> void:
	if gesture == null or fan == null or disc == null:
		return
	var cam: Camera3D = rink.view_camera()
	if cam == null:
		return
	gesture.camera = cam
	var placed := Vector3(place_x, 0.05, line_z)
	gesture.anchor = placed
	var phase := str(gesture.phase)
	var live: bool = phase != "busy" and bool(disc.visible) and not bool(disc.shot_in_progress)
	var pulling: bool = phase == "pull"
	var show_cursor: bool = live and (phase == "take" or phase == "hold" or pulling)
	var show_arrow: bool = live and (phase == "idle" or phase == "place")
	var power: float = gesture.read_power() if pulling else 0.0
	var needle: float = gesture.read_needle() if pulling else 0.0
	if live:
		disc.global_position = placed + Vector3(0.0, 0.0, power * PULL_BACK)
		if pulling:
			ui.set_power_ratio(power)
			feel.aim(power)
			if delivering_jack:
				ui.show_jack_aim(power)
			else:
				ui.show_aiming(power)
			if power >= 0.08:
				disc.preview_take(_aim_from(needle), power)
			elif disc.is_aiming:
				disc.preview_take(Vector3(0.0, 0.0, -1.0), 0.0)
	var live_pos: Vector3 = disc.global_position
	var cursor_at := cam.unproject_position(live_pos + Vector3(0.0, 0.16, 0.0))
	fan.present(cursor_at, power, needle, show_cursor, _facing(live_pos, _aim_from(0.0)))
	var line_a := cam.unproject_position(Vector3(-PLACE_HALF, 0.06, line_z))
	var line_b := cam.unproject_position(Vector3(PLACE_HALF, 0.06, line_z))
	fan.set_line(line_a, line_b, live and not show_cursor)
	var aim_tip := placed + _aim_from(0.0) * 4.5
	var aim_from := cam.unproject_position(placed + Vector3(0.0, 0.12, 0.0))
	var aim_to := cam.unproject_position(aim_tip + Vector3(0.0, 0.12, 0.0))
	fan.set_aim(aim_from, aim_to, show_arrow)
	fan.set_disc(cursor_at, live)


func _new_match() -> void:
	end_number = 1
	match_points = 0
	match_complete = false
	match_reported = false
	_begin_end()


func _begin_end() -> void:
	_return_token += 1
	shot_token += 1
	delivering_jack = true
	jack_length = 0.0
	match_complete = false
	rink.release_head()
	rink.set_head_visible(false)
	rink.set_ditch_mode(ditch_mode)
	rink.reset_spares()
	_clear_settled()
	jack.visible = false
	jack.velocity = Vector3.ZERO
	jack.moving = false
	jack.in_ditch = false
	throws_left = BOWLS_PER_END
	throw_index = 0
	score_manager.reset()
	disc.start_position = Vector3(0.0, 0.0, RinkScript.DISC_Z - 2.4)
	disc.ditch_mode = ditch_mode
	disc.set_green(
		Vector2(-RinkScript.HALF_WIDTH, RinkScript.FAR_Z),
		Vector2(RinkScript.HALF_WIDTH, RinkScript.NEAR_Z)
	)
	disc.obstacles = []
	disc.configure_jack()
	disc.reset_to_start()
	_place_rack()
	ui.set_power_ratio(0.0)
	ui.show_ditch_mode(ditch_mode)
	ui.show_match(_match_label())
	ui.show_jack_prompt(end_number, _match_label(), match_points)
	_begin_ready()


func _build_rack() -> void:
	for i in BOWLS_PER_END:
		var bowl = BowlScript.new()
		bowl.name = "Rack%d" % (i + 1)
		bowl.setup_disc(0, hand_sign)
		add_child(bowl)
		rack.append(bowl)


func _place_rack() -> void:
	for i in rack.size():
		var bowl = rack[i]
		bowl.set_hand(hand_sign)
		bowl.set_scoring(false)
		var slot := -0.69 + float(i) * 0.46
		bowl.rest_at(Vector3(slot, 0.0, RinkScript.DISC_Z - 2.2))
		if delivering_jack:
			bowl.visible = true
		else:
			bowl.visible = i > throw_index


func _match_label() -> String:
	return str(MATCHES[match_index]["label"])


func _is_match_over() -> bool:
	var fmt: Dictionary = MATCHES[match_index]
	var ends_target := int(fmt["ends"])
	var points_target := int(fmt["points"])
	if points_target > 0:
		return match_points >= points_target
	return end_number >= ends_target


func _clear_settled() -> void:
	for body in settled:
		body.queue_free()
	settled.clear()


func _table() -> Array:
	var bodies: Array = []
	for body in settled:
		bodies.append(body)
	bodies.append(jack)
	return bodies


func _on_disc_aim_changed(_direction: Vector2, power_ratio: float) -> void:
	ui.set_power_ratio(power_ratio)
	feel.aim(power_ratio)
	if power_ratio > 0.02:
		rink.release_head()
	if power_ratio <= 0.0:
		return
	if delivering_jack:
		ui.show_jack_aim(power_ratio)
	else:
		ui.show_aiming(power_ratio)


func _on_disc_bias_changed(_bias_ratio: float) -> void:
	if delivering_jack:
		return
	ui.show_hand(hand_sign < 0.0, _bowl_name(bias_index))


func _on_bias_cycle_requested() -> void:
	if delivering_jack or disc.shot_in_progress:
		return
	feel.tap()
	disc.toggle_hand()
	hand_sign = disc.hand_sign
	_place_rack()


func _on_hand_selected(forehand: bool) -> void:
	if delivering_jack or disc.shot_in_progress:
		return
	feel.tap()
	disc.set_hand(-1.0 if forehand else 1.0)
	hand_sign = disc.hand_sign
	_place_rack()
	ui.show_hand(forehand, _bowl_name(bias_index))


func _on_bias_selected(index: int) -> void:
	if delivering_jack or disc.shot_in_progress:
		return
	feel.tap()
	bias_index = clampi(index, 0, 3)
	disc.configure_bowl(bias_index, hand_sign)
	ui.show_bias(bias_index)
	ui.show_hand(hand_sign < 0.0, _bowl_name(bias_index))


func _on_ditch_option_requested() -> void:
	if disc.shot_in_progress or throw_index > 0:
		return
	feel.tap()
	ditch_mode = not ditch_mode
	disc.ditch_mode = ditch_mode
	rink.set_ditch_mode(ditch_mode)
	rink.reset_spares()
	ui.show_ditch_mode(ditch_mode)


func _on_match_cycle_requested() -> void:
	if disc.shot_in_progress or not delivering_jack or end_number > 1 or match_points > 0:
		return
	feel.tap()
	match_index = (match_index + 1) % MATCHES.size()
	ui.show_match(_match_label())
	ui.show_jack_prompt(end_number, _match_label(), match_points)


func _on_disc_shot_started() -> void:
	if delivering_jack:
		ui.set_power_ratio(0.0)
		ui.show_jack_running()
	else:
		throws_left -= 1
		ui.set_power_ratio(0.0)
		ui.show_in_motion(throws_left, _bowl_name(bias_index), hand_sign < 0.0)
	feel.release(disc.power_ratio)


func _on_disc_impacted(speed: float, hit_jack: bool, hit_bank: bool) -> void:
	feel.contact(speed, hit_jack, hit_bank)
	if not hit_bank:
		ui.show_contact(hit_jack)


func _on_disc_shot_stopped() -> void:
	call_deferred("_finish_shot", shot_token)


func _finish_shot(token: int) -> void:
	if token != shot_token or not is_inside_tree():
		return
	var rest_pos: Vector3 = disc.global_position
	if delivering_jack:
		_finish_jack(rest_pos)
		return
	var thrown = BowlScript.new()
	thrown.name = "Bowl%d" % (throw_index + 1)
	thrown.setup_disc(0, hand_sign)
	add_child(thrown)
	var bowl_ditched: bool = disc.in_ditch
	if bowl_ditched:
		thrown.drop_in_ditch(rest_pos)
	else:
		thrown.rest_at(rest_pos)
	thrown.spin_angle = disc.spin_angle
	thrown.present(0.0)
	settled.append(thrown)
	throw_index += 1
	var respotted := false
	var spares: int = rink.spares_remaining()
	if jack.in_ditch:
		spares = _respot_jack()
		respotted = true
	disc.reset_to_start()
	if throws_left > 0:
		disc.configure_bowl(bias_index, hand_sign)
		ui.show_bias(bias_index)
		ui.show_hand(hand_sign < 0.0, _bowl_name(bias_index))
	_place_rack()
	disc.obstacles = _table()
	var jack_pos: Vector3 = jack.global_position
	var distances: Array[float] = []
	for body in settled:
		if body.in_ditch:
			continue
		distances.append(_distance(body.global_position, jack_pos))
	score_manager.set_table(distances)
	var disc_distance := _distance(rest_pos, jack_pos)
	_check_draw(disc_distance, bowl_ditched)
	var closest: float = score_manager.get_closest_distance()
	var jack_moved: bool = jack_pos.distance_to(jack_home) > 0.2
	ui.set_power_ratio(0.0)
	rink.focus_head(jack_pos)
	if throws_left > 0:
		feel.settled(closest if closest >= 0.0 else 9.0)
		ui.show_throw_result(disc_distance, closest, throws_left, jack_moved, bowl_ditched, respotted, spares)
		if gesture != null:
			gesture.busy()
		_return_token += 1
		var return_token := _return_token
		await get_tree().create_timer(2.2).timeout
		if return_token != _return_token or not is_inside_tree() or disc.shot_in_progress:
			return
		rink.release_head()
		_begin_ready()
		return
	else:
		var shots := _mark_shots()
		match_points += shots
		match_complete = _is_match_over()
		if match_complete and not match_reported:
			match_reported = true
			match_decided.emit(true)
		disc.visible = false
		_place_rack()
		feel.settled(0.2 if shots > 0 else 9.0)
		ui.show_end_summary(end_number, shots, closest, match_points, match_complete)
		if gesture != null:
			gesture.busy()


func _finish_jack(rest_pos: Vector3) -> void:
	var travelled := _distance(rest_pos, disc.start_position)
	var ditched: bool = disc.in_ditch
	var reason := ""
	var detail := ""
	if ditched:
		reason = "JACK IN THE DITCH"
		detail = "THROW AGAIN"
	if reason != "":
		feel.settled(9.0)
		disc.configure_jack()
		disc.reset_to_start()
		ui.show_jack_illegal(reason, travelled, detail)
		_begin_ready()
		return
	delivering_jack = false
	jack_length = travelled
	jack_home = Vector3(rest_pos.x, 0.0, rest_pos.z)
	jack.rest_at(jack_home)
	jack.visible = true
	rink.place_head(Vector2(rest_pos.x, rest_pos.z))
	disc.configure_bowl(bias_index, hand_sign)
	disc.reset_to_start()
	disc.obstacles = _table()
	ui.show_bias(bias_index)
	ui.show_hand(hand_sign < 0.0, _bowl_name(bias_index))
	_place_rack()
	ui.show_jack_set(travelled, _bowl_name(bias_index), throws_left)
	_begin_ready()


func _respot_jack() -> int:
	var spares: int = rink.take_spare()
	var spot := Vector3(0.0, 0.0, disc.start_position.z - jack_length)
	spot = _clear_spot(spot)
	jack.in_ditch = false
	jack.rest_at(spot)
	jack.visible = true
	jack_home = spot
	rink.place_head(Vector2(spot.x, spot.z))
	return spares


func _clear_spot(spot: Vector3) -> Vector3:
	var guard := 0
	while guard < 14:
		var blocked := false
		for body in settled:
			if body.in_ditch:
				continue
			if _distance(body.global_position, spot) < body.radius + jack.radius + 0.08:
				blocked = true
				break
		if not blocked:
			return spot
		spot.z += 0.75
		guard += 1
	return spot


func _mark_shots() -> int:
	var jack_pos: Vector3 = jack.global_position
	var shots := 0
	var best := -1.0
	for body in settled:
		body.set_scoring(false)
		if body.in_ditch:
			continue
		var dist := _distance(body.global_position, jack_pos)
		if best < 0.0 or dist < best:
			best = dist
		if dist <= SHOT_METRES:
			body.set_scoring(true)
			shots += 1
	if shots == 0:
		for body in settled:
			if body.in_ditch:
				continue
			if absf(_distance(body.global_position, jack_pos) - best) < 0.001:
				body.set_scoring(true)
				break
	return shots


func _check_draw(distance: float, ditched: bool) -> void:
	if goal_sent or goal != "draw" or ditched:
		return
	if distance <= 1.0:
		goal_sent = true
		goal_cleared.emit()


func _bowl_name(index: int) -> String:
	return str(BowlScript.bowl_type(index)["name"])


func _distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _on_reset_requested() -> void:
	feel.tap()
	_new_match()


func _on_next_level_requested() -> void:
	feel.tap()
	if match_complete:
		_new_match()
		return
	end_number += 1
	_begin_end()
