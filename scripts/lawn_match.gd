extends Node3D

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
var rack: Array = []


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
	ui.dial_pull.connect(_on_dial_pull)
	ui.dial_released.connect(_on_dial_release)
	_lock_portrait_on_device()
	_build_rack()
	_new_match()


func _process(_delta: float) -> void:
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


func _on_dial_pull(pull: Vector2) -> void:
	if disc == null or disc.shot_in_progress or not disc.visible:
		return
	if not disc.is_aiming:
		if not disc.begin_dial():
			return
	disc.update_dial(pull)


func _on_dial_release(pull: Vector2) -> void:
	if disc == null or not disc.is_aiming:
		return
	disc.update_dial(pull)
	disc.release_dial()


func _new_match() -> void:
	end_number = 1
	match_points = 0
	match_complete = false
	_begin_end()


func _begin_end() -> void:
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
	var closest: float = score_manager.get_closest_distance()
	var jack_moved: bool = jack_pos.distance_to(jack_home) > 0.2
	ui.set_power_ratio(0.0)
	if throws_left > 0:
		feel.settled(closest if closest >= 0.0 else 9.0)
		ui.show_throw_result(disc_distance, closest, throws_left, jack_moved, bowl_ditched, respotted, spares)
	else:
		var shots := _mark_shots()
		match_points += shots
		match_complete = _is_match_over()
		disc.visible = false
		_place_rack()
		rink.focus_head(jack_pos)
		feel.settled(0.2 if shots > 0 else 9.0)
		ui.show_end_summary(end_number, shots, closest, match_points, match_complete)


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
