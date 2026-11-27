extends Node3D

signal goal_cleared
signal match_decided(you_won: bool)
signal tally_drive(metres: float, miss: float)
signal tally_solo(end_number: int)

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
const BOWLS_EACH := 4
const BOWLS_PER_END := BOWLS_EACH * 2
const MATCHES := [
	{"ends": 1, "points": 0, "label": "1 END"},
	{"ends": 4, "points": 0, "label": "4 ENDS"},
	{"ends": 0, "points": 10, "label": "TO 10"},
	{"ends": 0, "points": 21, "label": "TO 21"},
]

var throws_left := BOWLS_PER_END
var throw_index := 0
var shot_token := 0
var delivering_jack := true
var hand_sign := -1.0
var bias_index := 1
var player_hand := -1.0
var player_bias := 1
var ditch_mode := true
var jack_length := 0.0
var match_index := 1
var end_number := 1
var you_points := 0
var them_points := 0
var opponent := "local"
var difficulty := 1
var fast_play := false
var _ai_token := 0
var match_complete := false
var match_reported := false
var goal := ""
var goal_sent := false
var rack: Array = []
var gesture
var fan
var cue
var cue_blocks
var cue_solid
var cue_kind := 0
var _cue_compare := false
var _compare_label: Label
var _compare_power := 0.85
var _compare_aim := Vector3(0.10, 0.0, -1.0)
var distance_play := false
var solo_play := false
var solo_index := 0
var solo_won := false
var solo_tries := 0
var mark_at := Vector3(0.0, 0.0, -240.0)
var mark_root: Node3D
var drive_best := 9999.0
var drive_long := 0.0
var drive_left := 3
const DRIVE_BOWLS := 3
var place_x := 0.0
var aim_lock := 0.0
var line_z := 0.0
var _return_token := 0
var _freeze_cam := false
const PLACE_HALF := 1.65
const PULL_BACK := 0.62
const AIM_CONE := 0.26
const CURSOR_SPAN := 0.05
## Crystal Mark Fourth Edition. Law 10.1.3 minimum jack; Law 19.1.3 dead jack.
const MIN_JACK_LENGTH := 23.0
const MIN_LIVE_JACK := 20.0


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--kitshot"):
		get_tree().root.set_meta("flickdisc_kit", {
			"bowl_skin": "club",
			"bowl_color": 1,
			"disc_skin": "club",
			"disc_color": 0,
		})
	ui = get_node("UI")
	level_manager = LevelScript.new()
	score_manager = ScoreScript.new()
	feel = FeelScript.new()
	feel.name = "Feel"
	add_child(level_manager)
	add_child(score_manager)
	add_child(feel)

	if _wants_drive() or _wants_drivetest():
		distance_play = true
	elif _wants_solotest():
		solo_play = true
	rink = RinkScript.new()
	rink.name = "Rink"
	if distance_play:
		# Ten times a match rink, and wide enough that a full drive can wander.
		rink.prepare_span(680.0, 24.0)
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
	ui.camera_requested.connect(_on_camera_requested)
	ui.cue_cycle_requested.connect(_on_cue_cycle_requested)
	_wire_shot()
	_lock_portrait_on_device()
	if _wants_bowltest():
		fast_play = true
		match_index = 0
		opponent = "local"
	_build_rack()
	_new_match()
	if fast_play:
		call_deferred("_bowltest")
	elif _wants_showcase():
		call_deferred("_showcase")
	elif _wants_drivetest():
		call_deferred("_drivetest")
	elif _wants_solotest():
		call_deferred("_solotest")
	elif _wants_cuetest():
		call_deferred("_cuetest")
	elif OS.get_cmdline_user_args().has("--handtest"):
		call_deferred("_handtest")
	elif OS.get_cmdline_user_args().has("--fixtest"):
		call_deferred("_fixtest")
	elif OS.get_cmdline_user_args().has("--pulltest"):
		call_deferred("_pulltest")
	elif OS.get_cmdline_user_args().has("--drawtest"):
		call_deferred("_drawtest")
	elif OS.get_cmdline_user_args().has("--endtest"):
		call_deferred("_endtest")
	elif OS.get_cmdline_user_args().has("--kitshot"):
		call_deferred("_kitshot")
	elif OS.get_cmdline_user_args().has("--rollshot"):
		call_deferred("_rollshot")
	elif OS.get_cmdline_user_args().has("--aitest"):
		call_deferred("_aitest")


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
	if rink != null and disc != null and not _freeze_cam:
		var mat := Vector3(place_x, 0.0, line_z)
		var head_at: Vector3 = jack.global_position if jack != null and jack.visible else disc.global_position
		rink.note_delivery(disc.global_position, disc.velocity, disc.shot_in_progress, mat, head_at, disc.is_aiming)
		_sync_head_rings()


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
	shot.kept_aim.connect(_on_aim_kept)
	shot.opened_take.connect(_on_take_opened)
	shot.cancelled_pull.connect(_on_pull_cancelled)
	shot.fired.connect(_on_shot_fired)
	shot.direct = true
	add_child(shot)
	gesture = shot
	fan = preload("res://scripts/shot_fan.gd").new()
	fan.name = "ShotFan"
	ui.add_child(fan)
	cue_blocks = preload("res://scripts/aim_cue.gd").new()
	cue_blocks.name = "AimCueBlocks"
	add_child(cue_blocks)
	cue_solid = preload("res://scripts/aim_cue_solid.gd").new()
	cue_solid.name = "AimCueSolid"
	add_child(cue_solid)
	cue = cue_blocks
	cue_kind = 0
	if ui != null:
		ui.show_cue_kind(0)


func _begin_ready() -> void:
	line_z = disc.start_position.z
	place_x = 0.0
	aim_lock = 0.0
	disc.start_position = Vector3(0.0, 0.0, line_z)
	disc.global_position = disc.start_position
	if _computer_turn():
		if gesture != null:
			gesture.busy()
		disc.set_palette(1)
		ui.show_computer(_side_name(1), _bowls_left(1))
		_ai_token += 1
		_play_computer(_ai_token)
		return
	if gesture != null:
		gesture.arm()
		gesture.anchor = disc.start_position
	if not delivering_jack and not _computer_turn():
		bias_index = player_bias
		hand_sign = player_hand
		disc.configure_bowl(bias_index, hand_sign)
	ui.show_bowl_controls(not delivering_jack)
	if not delivering_jack:
		ui.show_bias(bias_index, _side())
		ui.show_hand(hand_sign < 0.0, _bowl_name(bias_index))
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


func _on_aim_kept() -> void:
	ui.show_aim_ready(delivering_jack)


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


func _on_shot_fired(power: float, _needle: float) -> void:
	disc.start_position = Vector3(place_x, 0.0, line_z)
	if gesture != null and gesture.direct:
		disc.global_position = gesture.direct_hold
		disc.fire_taken(gesture.direct_aim, power)
		return
	disc.fire_taken(_aim_from(_needle), power)


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


func _aim_nose(origin: Vector3, aim: Vector3) -> Vector3:
	var flat := Vector3(aim.x, 0.0, aim.z)
	if flat.length() < 0.01:
		flat = Vector3(0.0, 0.0, -1.0)
	flat = flat.normalized()
	return Vector3(origin.x, 0.028, origin.z) + flat * (disc.radius + 0.06)


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
	if _cue_compare:
		_sync_compare_cue()
		return
	if gesture.direct:
		_sync_direct(cam, placed)
		return
	var phase := str(gesture.phase)
	var live: bool = phase != "busy" and bool(disc.visible) and not bool(disc.shot_in_progress)
	var pulling: bool = phase == "pull"
	var show_cursor: bool = live and (phase == "take" or phase == "hold" or pulling)
	var show_arrow: bool = live and (phase == "idle" or phase == "place")
	var power: float = gesture.read_power() if pulling else 0.0
	var needle: float = gesture.read_needle() if pulling else 0.0
	if live:
		disc.global_position = placed + Vector3(0.0, 0.0, power * PULL_BACK)
		if show_arrow:
			disc.preview_take(_aim_from(0.0), 0.55)
		elif disc.is_aiming:
			disc.preview_take(Vector3(0.0, 0.0, -1.0), 0.0)
		if pulling:
			feel.aim(power)
			if delivering_jack:
				ui.show_jack_aim(power)
			else:
				ui.show_aiming(power)
	var live_pos: Vector3 = disc.global_position
	var cursor_at := cam.unproject_position(live_pos + Vector3(0.0, 0.16, 0.0))
	var rim := cam.unproject_position(live_pos + Vector3(disc.radius, 0.12, 0.0))
	var disc_px := cursor_at.distance_to(rim)
	var lift := disc_px + 86.0
	fan.present(cursor_at, power, needle, show_cursor, _facing(live_pos, _aim_from(0.0)), lift)
	if cue != null:
		cue.clear()
	fan.set_cue(PackedVector2Array(), PackedFloat32Array(), false)
	fan.set_line(Vector2.ZERO, Vector2.ZERO, false)
	fan.set_aim(Vector2.ZERO, Vector2.ZERO, false)
	fan.set_disc(cursor_at, false)


func _sync_direct(cam: Camera3D, placed: Vector3) -> void:
	var phase := str(gesture.phase)
	var live: bool = phase != "busy" and bool(disc.visible) and not bool(disc.shot_in_progress)
	var pulling: bool = live and phase == "pull"
	var power: float = gesture.direct_power if pulling else 0.0
	if ui != null:
		ui.lock_shot_hud(pulling)
	if live:
		if pulling:
			disc.global_position = gesture.direct_hold
			disc.preview_take(gesture.direct_aim, maxf(power, 0.12))
			feel.aim(power)
			ui.show_drag(disc.reach_for(power), distance_play)
			ui.set_power_ratio(power)
		else:
			disc.global_position = placed
			disc.preview_take(Vector3(0.0, 0.0, -1.0), 0.0)
	var live_pos: Vector3 = disc.global_position
	var bowl_px := cam.unproject_position(live_pos + Vector3(0.0, 0.16, 0.0))
	var centre := cam.unproject_position(live_pos)
	var bowl_r := 24.0
	for step in 8:
		var ang := TAU * float(step) / 8.0
		var rim := cam.unproject_position(live_pos + Vector3(cos(ang), 0.2, sin(ang)) * disc.radius)
		bowl_r = maxf(bowl_r, centre.distance_to(rim))
	fan.present(bowl_px, power, 0.0, false, -PI * 0.5, 120.0)
	if pulling:
		if cue != null:
			cue.present(disc.grass_cue(power), power, disc.aim_direction)
	elif cue != null:
		cue.clear()
	fan.set_cue(PackedVector2Array(), PackedFloat32Array(), false)
	fan.set_aim(Vector2.ZERO, Vector2.ZERO, false)
	fan.set_line(Vector2.ZERO, Vector2.ZERO, false)
	fan.set_disc(bowl_px, false)
	fan.set_bowl(centre, bowl_r * 1.18)
	fan.set_finger(gesture.finger, pulling)


func _new_match() -> void:
	end_number = 1
	you_points = 0
	them_points = 0
	match_complete = false
	match_reported = false
	player_hand = -1.0
	player_bias = 1
	hand_sign = player_hand
	bias_index = player_bias
	_begin_end()


func _begin_end() -> void:
	if distance_play:
		_begin_drive()
		return
	if solo_play:
		_begin_solo()
		return
	_return_token += 1
	shot_token += 1
	delivering_jack = true
	jack_length = 0.0
	match_complete = false
	rink.reset_view()
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
		Vector2(-rink.HALF_WIDTH, rink.FAR_Z),
		Vector2(rink.HALF_WIDTH, rink.NEAR_Z)
	)
	disc.obstacles = []
	disc.configure_jack()
	disc.reset_to_start()
	_place_rack()
	ui.set_power_ratio(0.0)
	ui.show_ditch_mode(ditch_mode)
	ui.show_camera_mode(rink.chase)
	ui.show_match(_match_label())
	ui.show_jack_prompt(end_number, _match_label(), _score_line())
	_begin_ready()


func _build_rack() -> void:
	for i in BOWLS_EACH:
		var bowl = BowlScript.new()
		bowl.name = "Rack%d" % (i + 1)
		bowl.setup_disc(0, hand_sign)
		add_child(bowl)
		rack.append(bowl)


func _place_rack() -> void:
	var side := 0 if delivering_jack else _side()
	var left := BOWLS_EACH if delivering_jack else _bowls_left(side)
	if distance_play or solo_play:
		side = 0
		left = 1
	for i in rack.size():
		var bowl = rack[i]
		bowl.paint(side, hand_sign)
		bowl.set_scoring(false)
		bowl.roll_basis = Basis.IDENTITY
		bowl.visible = i < left
		if bowl.visible:
			bowl.rest_at(Vector3(1.7, 0.0, -0.45 - float(i) * 0.58))


func _match_label() -> String:
	return str(MATCHES[match_index]["label"])


func _is_match_over() -> bool:
	var fmt: Dictionary = MATCHES[match_index]
	var ends_target := int(fmt["ends"])
	var points_target := int(fmt["points"])
	if points_target > 0:
		var lead := maxi(you_points, them_points)
		return lead >= points_target and you_points != them_points
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
	if power_ratio > 0.02:
		rink.release_head()
	if gesture == null or str(gesture.phase) != "pull":
		return
	if gesture.direct:
		feel.aim(power_ratio)
		return
	feel.aim(power_ratio)
	if delivering_jack:
		ui.show_jack_aim(power_ratio)
	else:
		ui.show_aiming(power_ratio)


func _on_disc_bias_changed(_bias_ratio: float) -> void:
	if delivering_jack or _computer_turn():
		return
	ui.show_hand(disc.hand_sign < 0.0, _bowl_name(bias_index))


func _on_bias_cycle_requested() -> void:
	if delivering_jack or disc.shot_in_progress:
		return
	feel.tap()
	disc.toggle_hand()
	hand_sign = disc.hand_sign
	player_hand = hand_sign
	_place_rack()


func _on_hand_selected(forehand: bool) -> void:
	if delivering_jack or disc.shot_in_progress:
		return
	feel.tap()
	disc.set_hand(-1.0 if forehand else 1.0)
	hand_sign = disc.hand_sign
	player_hand = hand_sign
	_place_rack()
	ui.show_hand(forehand, _bowl_name(bias_index))


func _on_bias_selected(index: int) -> void:
	if delivering_jack or disc.shot_in_progress:
		return
	feel.tap()
	bias_index = clampi(index, 0, 3)
	player_bias = bias_index
	disc.configure_bowl(bias_index, hand_sign)
	ui.show_bias(bias_index, _side())
	ui.show_hand(hand_sign < 0.0, _bowl_name(bias_index))


func _on_cue_cycle_requested() -> void:
	feel.tap()
	_use_cue_kind(1 if cue_kind == 0 else 0)


func _use_cue_kind(kind: int) -> void:
	if cue != null:
		cue.clear()
	cue_kind = 1 if kind == 1 else 0
	cue = cue_solid if cue_kind == 1 else cue_blocks
	if ui != null:
		ui.show_cue_kind(cue_kind)
	if _cue_compare:
		_sync_compare_cue()


func _on_camera_requested() -> void:
	feel.tap()
	rink.chase = not rink.chase
	ui.show_camera_mode(rink.chase)
	if not disc.shot_in_progress:
		return
	if delivering_jack:
		ui.show_jack_running()
	else:
		ui.show_in_motion(_side_name(_side()), _bowl_name(bias_index), hand_sign < 0.0, _score_line())


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
	if disc.shot_in_progress or not delivering_jack or end_number > 1 or you_points > 0 or them_points > 0:
		return
	feel.tap()
	match_index = (match_index + 1) % MATCHES.size()
	ui.show_match(_match_label())
	ui.show_jack_prompt(end_number, _match_label(), _score_line())


func _on_disc_shot_started() -> void:
	if delivering_jack:
		ui.set_power_ratio(0.0)
		ui.show_jack_running()
	else:
		throws_left -= 1
		ui.set_power_ratio(0.0)
		ui.show_in_motion(_side_name(_side()), _bowl_name(bias_index), hand_sign < 0.0, _score_line())
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
	if distance_play:
		_finish_drive(rest_pos)
		return
	if solo_play:
		_finish_solo(rest_pos)
		return
	if delivering_jack:
		_finish_jack(rest_pos)
		return
	var thrown = BowlScript.new()
	thrown.name = "Bowl%d" % (throw_index + 1)
	thrown.setup_disc(throw_index % 2, hand_sign)
	thrown.side = throw_index % 2
	thrown.roll_basis = disc.roll_basis
	thrown.lean = disc.rest_lean
	thrown.travel = disc.travel_facing
	add_child(thrown)
	var bowl_ditched: bool = disc.in_ditch
	if bowl_ditched:
		thrown.drop_in_ditch(rest_pos)
	else:
		thrown.rest_at(rest_pos)
	thrown.is_toucher = disc.touched_jack
	settled.append(thrown)
	throw_index += 1
	var respotted := false
	var spares: int = rink.spares_remaining()
	if _jack_needs_respot():
		spares = _respot_jack()
		respotted = true
	disc.reset_to_start()
	if throws_left > 0:
		if _computer_turn():
			disc.configure_bowl(1, -1.0)
			disc.set_palette(_side())
			ui.show_bias(1, _side())
			ui.show_hand(true, _bowl_name(1))
		else:
			bias_index = player_bias
			hand_sign = player_hand
			disc.configure_bowl(bias_index, hand_sign)
			disc.set_palette(_side())
			ui.show_bias(bias_index, _side())
			ui.show_hand(hand_sign < 0.0, _bowl_name(bias_index))
			ui.show_bowl_controls(true)
	_place_rack()
	disc.obstacles = _table()
	var jack_pos: Vector3 = jack.global_position
	var distances: Array[float] = []
	for body in settled:
		if not _bowl_is_live(body):
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
		ui.show_throw_result(disc_distance, closest, _side_name(_side()), jack_moved, bowl_ditched, respotted, spares, _score_line())
		if gesture != null:
			gesture.busy()
		if fast_play:
			rink.release_head()
			_begin_ready()
			return
		_return_token += 1
		var return_token := _return_token
		await get_tree().create_timer(2.2).timeout
		if return_token != _return_token or not is_inside_tree() or disc.shot_in_progress:
			return
		rink.release_head()
		_begin_ready()
		return
	else:
		var count := _count_end()
		var shots: int = count["shots"]
		var holder: int = count["side"]
		if holder == 0:
			you_points += shots
		elif holder == 1:
			them_points += shots
		match_complete = _is_match_over()
		if match_complete and not match_reported and you_points != them_points:
			match_reported = true
			match_decided.emit(you_points > them_points)
		disc.visible = false
		_place_rack()
		feel.settled(0.2 if shots > 0 else 9.0)
		var holder_name := "TIED" if shots <= 0 else _side_name(holder)
		ui.show_end_summary(end_number, holder_name, shots, closest, _score_line(), match_complete)
		if gesture != null:
			gesture.busy()


func _finish_jack(rest_pos: Vector3) -> void:
	var ditched: bool = disc.in_ditch
	# The jack only sets the length. Any offline roll is pulled back
	# onto the centre line before the first bowl.
	var centred := Vector3(0.0, 0.0, rest_pos.z)
	var travelled := _distance(centred, disc.start_position)
	var note := ""
	# Law 10.1.3 / 9.2 / 10.1.1. Short, too long, or in the ditch: sit on the T.
	if ditched or travelled + 0.05 < MIN_JACK_LENGTH or centred.z < rink.tee_z() + 0.05:
		centred = _tee_spot()
		if ditched:
			note = "JACK IN THE DITCH  •  PLACED ON THE T"
		elif travelled + 0.05 < MIN_JACK_LENGTH:
			note = "SHORT JACK  •  PLACED ON THE T"
		else:
			note = "LONG JACK  •  PLACED ON THE T"
	delivering_jack = false
	jack_length = _distance(centred, disc.start_position)
	jack_home = centred
	jack.rest_at(jack_home)
	jack.visible = true
	rink.place_head(Vector2(centred.x, centred.z))
	disc.configure_bowl(bias_index, hand_sign)
	disc.set_palette(throw_index % 2)
	disc.reset_to_start()
	disc.obstacles = _table()
	ui.show_bias(bias_index, _side())
	ui.show_hand(hand_sign < 0.0, _bowl_name(bias_index))
	_place_rack()
	ui.show_jack_set(jack_length, _bowl_name(bias_index), _side_name(0), note)
	_begin_ready()


func _tee_spot() -> Vector3:
	return Vector3(0.0, 0.0, rink.tee_z())


func _jack_needs_respot() -> bool:
	if jack == null:
		return false
	if jack.in_ditch:
		return true
	# Law 19.1.3: a jack knocked back inside 20 m of the mat is dead.
	return _distance(jack.global_position, disc.start_position) + 0.05 < MIN_LIVE_JACK


func _bowl_is_live(body) -> bool:
	# Law 17.1.1: a non-toucher in the ditch is dead. A toucher stays live.
	if body.in_ditch:
		return bool(body.is_toucher)
	return true


func _respot_jack() -> int:
	# Law 56.5.3: one re-spot, the T, 2 m from the ditch on the centre line.
	var spares: int = rink.take_spare()
	var spot := _clear_spot(_tee_spot())
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


func _count_end() -> Dictionary:
	var jack_pos: Vector3 = jack.global_position
	var nearest := [-1.0, -1.0]
	for body in settled:
		body.set_scoring(false)
		if not _bowl_is_live(body):
			continue
		var dist := _distance(body.global_position, jack_pos)
		var side := int(body.side)
		if nearest[side] < 0.0 or dist < nearest[side]:
			nearest[side] = dist
	var closest := -1.0
	if nearest[0] >= 0.0 and nearest[1] >= 0.0:
		closest = minf(nearest[0], nearest[1])
	elif nearest[0] >= 0.0:
		closest = nearest[0]
	elif nearest[1] >= 0.0:
		closest = nearest[1]
	var holder := -1
	if nearest[0] >= 0.0 and (nearest[1] < 0.0 or nearest[0] + 0.01 < nearest[1]):
		holder = 0
	elif nearest[1] >= 0.0 and (nearest[0] < 0.0 or nearest[1] + 0.01 < nearest[0]):
		holder = 1
	var shots := 0
	if holder >= 0:
		var other := 1 - holder
		var limit: float = nearest[other]
		for body in settled:
			if not _bowl_is_live(body) or int(body.side) != holder:
				continue
			var dist := _distance(body.global_position, jack_pos)
			if limit < 0.0 or dist + 0.01 < limit:
				body.set_scoring(true)
				shots += 1
	return {"side": holder, "shots": shots, "closest": closest}


func _check_draw(distance: float, ditched: bool) -> void:
	if goal_sent or goal != "draw" or ditched:
		return
	if distance <= 1.0:
		goal_sent = true
		goal_cleared.emit()


func _sync_head_rings() -> void:
	if rink == null or jack == null or not jack.visible or delivering_jack:
		return
	rink.place_head(Vector2(jack.global_position.x, jack.global_position.z))


func _bowl_name(index: int) -> String:
	return str(BowlScript.bowl_type(index)["name"])


func _side() -> int:
	return throw_index % 2


func _side_name(side: int) -> String:
	return "RED" if side == 0 else "BLUE"


func _bowls_left(side: int) -> int:
	var left := 0
	for i in range(throw_index, BOWLS_PER_END):
		if i % 2 == side:
			left += 1
	return left


func _score_line() -> String:
	return "RED %d   BLUE %d" % [you_points, them_points]


func _computer_turn() -> bool:
	return opponent == "ai" and not delivering_jack and _side() == 1


func _play_computer(token: int) -> void:
	await get_tree().create_timer(0.7 if fast_play else 0.9).timeout
	if token != _ai_token or not is_inside_tree() or not _computer_turn() or disc.shot_in_progress:
		return
	var pick: Dictionary = _ai_pick()
	disc.configure_bowl(int(pick["bias"]), float(pick["hand"]))
	disc.set_palette(1)
	ui.show_hand(float(pick["hand"]) < 0.0, _bowl_name(int(pick["bias"])))
	ui.show_bias(int(pick["bias"]), 1)
	disc.fire_taken(pick["aim"], float(pick["power"]))


func _ai_ring() -> float:
	# Painted head is 1.32 m. Sit in those rings, not on the jack.
	if difficulty == 0:
		return 2.05
	if difficulty >= 2:
		return 0.98
	return 1.28


func _ai_want() -> float:
	# Near the rings, not too close. Crashing the jack threw every end wide.
	if difficulty == 0:
		return 1.55
	if difficulty >= 2:
		return 0.68
	return 0.95


func _ai_nearest(side: int) -> float:
	var best := -1.0
	if jack == null:
		return best
	var jack_at: Vector3 = jack.global_position
	for body in settled:
		if int(body.side) != side or not _bowl_is_live(body):
			continue
		var dist := _distance(body.global_position, jack_at)
		if best < 0.0 or dist < best:
			best = dist
	return best


func _ai_hold(from: Vector3, jack_at: Vector3, _along: float, bias: float, power: float) -> float:
	# A drawing bowl that is sent at the jack finishes on the draw side.
	# Aim up the hold by that same amount so the rest sits in front of it.
	var rest: Vector3 = disc.predict_rest(from, Vector3(0.0, 0.0, -1.0), power, bias)
	var keep: float = float(rink.HALF_WIDTH) - 1.35
	return clampf(jack_at.x - rest.x, -keep, keep)


func _ai_pick() -> Dictionary:
	var jack_at: Vector3 = jack.global_position
	var from := Vector3(0.0, 0.0, line_z)
	place_x = from.x
	disc.start_position = from
	disc.global_position = from
	var along := maxf(from.z - jack_at.z, 8.0)
	var ring := _ai_ring()
	var want := _ai_want()
	var keep: float = float(rink.HALF_WIDTH) - 1.35
	var lip: float = float(rink.HALF_WIDTH) - 0.72
	var far_lip: float = rink.FAR_Z + 0.65
	var near_lip: float = rink.NEAR_Z - 0.35
	var they := _ai_nearest(0)
	var best_aim := Vector3(0.0, 0.0, -1.0)
	var best_power := 0.55
	var best_hand := -1.0
	var best_bias := 1
	var best_score := 9999.0
	var best_err := 9999.0
	var best_short := -99.0
	var found := false
	# Lazer, then Blaze (middle weight), then Ace. Classic draws too wide.
	for bowl_i in [0, 1, 2]:
		for hand in [-1.0, 1.0]:
			disc.configure_bowl(bowl_i, hand)
			var bias: float = disc.bias_ratio
			var weight: float = disc.weight_for_length(maxf(along - 0.85, 8.0), bias)
			var hold := _ai_hold(from, jack_at, along, bias, weight)
			for p_off in [-0.08, -0.04, 0.0, 0.03]:
				var power: float = clampf(weight + p_off, 0.18, 0.88)
				for sample in 13:
					var line := hold + (float(sample) - 6.0) * 0.30
					var aim := Vector3(line - from.x, 0.0, -along)
					if aim.length() < 0.01:
						continue
					aim = aim.normalized()
					var rest: Vector3 = disc.predict_rest(from, aim, power, bias)
					if absf(rest.x) > lip or rest.z < far_lip or rest.z > near_lip:
						continue
					var err := Vector2(rest.x, rest.z).distance_to(Vector2(jack_at.x, jack_at.z))
					var short := rest.z - jack_at.z
					var past := jack_at.z - rest.z
					var score := absf(err - want)
					if err < 0.42:
						score += 8.0
					if err > ring:
						score += 3.4 + (err - ring) * 1.25
					if past > 0.12:
						score += 2.6 + past * 3.0
					if short > 0.30 and short < 1.70:
						score -= 0.42
					var edge: float = absf(rest.x) - keep
					if edge > 0.0:
						score += 4.0 + edge * 6.0
					if they >= 0.0 and err >= 0.45:
						if err + 0.05 < they:
							score -= 0.38
						elif err > they + 0.15:
							score += 0.18
					if score < best_score:
						best_score = score
						best_err = err
						best_short = short
						best_aim = aim
						best_power = power
						best_hand = hand
						best_bias = bowl_i
						found = true
		if found and best_err <= ring and best_err >= 0.45 and best_short > 0.20:
			break
	if not found:
		best_bias = 1
		best_hand = -1.0
		disc.configure_bowl(best_bias, best_hand)
		var bias: float = disc.bias_ratio
		best_power = disc.weight_for_length(maxf(along - 0.85, 8.0), bias)
		var hold := _ai_hold(from, jack_at, along, bias, best_power)
		best_aim = Vector3(hold - from.x, 0.0, -along)
		if best_aim.length() < 0.01:
			best_aim = Vector3(-signf(bias) * 1.8, 0.0, -1.0)
		best_aim = best_aim.normalized()
	disc.configure_bowl(best_bias, best_hand)
	var try_aim := best_aim
	var try_power := best_power
	var live_rest: Vector3 = disc.predict_rest(from, try_aim, try_power, disc.bias_ratio)
	if live_rest.z < jack_at.z - 0.12 or Vector2(live_rest.x, live_rest.z).distance_to(Vector2(jack_at.x, jack_at.z)) < 0.42:
		try_power = clampf(try_power - 0.05, 0.18, 0.88)
		live_rest = disc.predict_rest(from, try_aim, try_power, disc.bias_ratio)
	if absf(live_rest.x) > lip or disc.will_ditch(from, try_aim, try_power, disc.bias_ratio):
		try_aim = best_aim
		try_power = best_power
	return {"aim": try_aim, "power": try_power, "hand": best_hand, "bias": best_bias}


func _begin_drive() -> void:
	_return_token += 1
	shot_token += 1
	delivering_jack = false
	match_complete = false
	drive_best = 9999.0
	drive_long = 0.0
	drive_left = DRIVE_BOWLS
	throws_left = DRIVE_BOWLS
	throw_index = 0
	ditch_mode = true
	rink.reset_view()
	rink.set_head_visible(false)
	rink.set_ditch_mode(true)
	_clear_settled()
	jack.visible = false
	disc.set_pace(2.55, 1.12)
	disc.ditch_mode = true
	disc.set_green(Vector2(-rink.HALF_WIDTH, rink.FAR_Z), Vector2(rink.HALF_WIDTH, rink.NEAR_Z))
	disc.start_position = Vector3(0.0, 0.0, RinkScript.DISC_Z - 2.4)
	line_z = disc.start_position.z
	place_x = 0.0
	disc.configure_bowl(1, -1.0)
	disc.set_palette(0)
	hand_sign = -1.0
	bias_index = 1
	disc.reset_to_start()
	_place_drive_mark(false)
	_place_rack()
	ui.show_ditch_mode(true)
	ui.show_camera_mode(rink.chase)
	ui.show_match("LONG GREEN")
	ui.show_bias(1, 0)
	ui.show_hand(true, _bowl_name(1))
	_begin_ready()
	ui.show_drive_prompt(drive_left, drive_long, drive_best)


func _place_drive_mark(fixed: bool) -> void:
	var rng := RandomNumberGenerator.new()
	if fixed:
		rng.seed = 11
	else:
		rng.randomize()
	var along := rng.randf_range(180.0, 520.0)
	var side := rng.randf_range(-7.0, 7.0)
	mark_at = Vector3(side, 0.0, disc.start_position.z - along)
	rink.place_mark(mark_at)


func _finish_drive(rest_pos: Vector3) -> void:
	var travelled := _distance(rest_pos, disc.start_position)
	var miss := _distance(rest_pos, mark_at)
	var ditched: bool = disc.in_ditch
	if travelled > drive_long:
		drive_long = travelled
	if miss < drive_best:
		drive_best = miss
	tally_drive.emit(travelled, miss)
	var thrown = BowlScript.new()
	thrown.setup_disc(0, hand_sign)
	thrown.side = 0
	thrown.roll_basis = disc.roll_basis
	thrown.lean = disc.rest_lean
	thrown.travel = disc.travel_facing
	add_child(thrown)
	if ditched:
		thrown.drop_in_ditch(rest_pos)
	else:
		thrown.rest_at(rest_pos)
	settled.append(thrown)
	disc.reset_to_start()
	disc.configure_bowl(bias_index, hand_sign)
	disc.set_palette(0)
	_place_rack()
	ui.set_power_ratio(0.0)
	rink.focus_pair(rest_pos, mark_at)
	feel.mark_found(miss)
	if throws_left > 0:
		ui.show_drive_result(travelled, miss, throws_left, ditched)
		if gesture != null:
			gesture.busy()
		_return_token += 1
		var token := _return_token
		await get_tree().create_timer(2.4).timeout
		if token != _return_token or not is_inside_tree():
			return
		rink.release_head()
		_begin_ready()
		ui.show_drive_prompt(throws_left, drive_long, drive_best)
		return
	if gesture != null:
		gesture.busy()
	ui.show_drive_done(drive_long, drive_best)


func _begin_solo() -> void:
	_return_token += 1
	shot_token += 1
	delivering_jack = false
	solo_won = false
	match_complete = false
	throws_left = 1
	throw_index = 0
	var ends: Array = _solo_ends()
	var layout: Dictionary = ends[clampi(solo_index, 0, ends.size() - 1)]
	rink.reset_view()
	rink.set_head_visible(false)
	rink.set_ditch_mode(true)
	ditch_mode = true
	_clear_settled()
	disc.set_pace(1.0, DiscScript.DECEL)
	disc.ditch_mode = false
	disc.set_green(
		Vector2(-rink.HALF_WIDTH, rink.FAR_Z),
		Vector2(rink.HALF_WIDTH, rink.NEAR_Z)
	)
	disc.start_position = Vector3(0.0, 0.0, RinkScript.DISC_Z - 2.4)
	line_z = disc.start_position.z
	place_x = 0.0
	var jack_at := Vector3(float(layout["x"]), 0.0, line_z - float(layout["metres"]))
	jack.rest_at(jack_at)
	jack.visible = true
	jack_home = jack_at
	rink.place_head(Vector2(jack_at.x, jack_at.z))
	for offset in layout["bowls"]:
		var spot: Vector3 = jack_at + offset
		var bowl = BowlScript.new()
		bowl.setup_disc(1, 1.0)
		bowl.side = 1
		add_child(bowl)
		bowl.rest_at(spot)
		settled.append(bowl)
	var hand := float(layout["hand"])
	bias_index = int(layout["bias"])
	disc.configure_bowl(bias_index, hand)
	disc.set_palette(0)
	hand_sign = disc.hand_sign
	disc.reset_to_start()
	disc.obstacles = _table()
	_place_rack()
	ui.show_ditch_mode(false)
	ui.show_camera_mode(rink.chase)
	ui.show_match("SOLO")
	ui.show_bias(bias_index, _side())
	ui.show_hand(hand < 0.0, _bowl_name(bias_index))
	_begin_ready()
	ui.show_solo_prompt(solo_index + 1, ends.size(), str(layout["name"]), str(layout["blurb"]))


func _finish_solo(rest_pos: Vector3) -> void:
	solo_tries += 1
	var ditched: bool = disc.in_ditch
	var miss := _distance(rest_pos, jack.global_position)
	solo_won = _player_is_shot(rest_pos, ditched)
	var thrown = BowlScript.new()
	thrown.setup_disc(0, hand_sign)
	thrown.side = 0
	thrown.roll_basis = disc.roll_basis
	thrown.lean = disc.rest_lean
	thrown.travel = disc.travel_facing
	add_child(thrown)
	if ditched:
		thrown.drop_in_ditch(rest_pos)
	else:
		thrown.rest_at(rest_pos)
	settled.append(thrown)
	disc.reset_to_start()
	disc.visible = false
	_place_rack()
	ui.set_power_ratio(0.0)
	rink.focus_head(jack.global_position)
	if solo_won:
		tally_solo.emit(solo_index + 1)
		feel.mark_found(miss)
		goal_cleared.emit()
	else:
		feel.settled(9.0)
	if gesture != null:
		gesture.busy()
	var ends: Array = _solo_ends()
	var layout: Dictionary = ends[clampi(solo_index, 0, ends.size() - 1)]
	ui.show_solo_result(solo_won, str(layout["name"]), miss, ditched)


func _player_is_shot(player_pos: Vector3, ditched: bool) -> bool:
	if ditched:
		return false
	var mine := _distance(player_pos, jack.global_position)
	var theirs := false
	for body in settled:
		if int(body.side) != 1 or body.in_ditch:
			continue
		theirs = true
		if _distance(body.global_position, jack.global_position) <= mine + 0.015:
			return false
	return theirs


func _solo_ends() -> Array:
	# Offsets are from the jack. Positive z sits short, toward the mat.
	return [
		{
			"name": "THE DRAW",
			"blurb": "The front is open. Draw onto the jack.",
			"metres": 21.0, "x": 0.0, "hand": -1.0, "bias": 1,
			"bowls": [Vector3(1.35, 0.0, 1.7), Vector3(-1.45, 0.0, 0.5), Vector3(0.2, 0.0, -1.7)],
		},
		{
			"name": "FOREHAND GAP",
			"blurb": "The straight line is closed. Take the forehand.",
			"metres": 23.0, "x": 0.4, "hand": -1.0, "bias": 2,
			"bowls": [Vector3(0.15, 0.0, 2.2), Vector3(-0.9, 0.0, 1.1), Vector3(1.5, 0.0, -0.8)],
		},
		{
			"name": "BACKHAND",
			"blurb": "The forehand is covered. Come in the other way.",
			"metres": 20.0, "x": -0.6, "hand": 1.0, "bias": 2,
			"bowls": [Vector3(-0.2, 0.0, 2.0), Vector3(1.1, 0.0, 0.9), Vector3(-1.6, 0.0, -1.1)],
		},
		{
			"name": "REST SHORT",
			"blurb": "They are all past the jack. Stop in front.",
			"metres": 24.0, "x": 0.2, "hand": -1.0, "bias": 0,
			"bowls": [Vector3(0.7, 0.0, -1.3), Vector3(-0.8, 0.0, -1.8), Vector3(0.1, 0.0, -2.6)],
		},
		{
			"name": "THE WALL",
			"blurb": "Three bowls short. You need enough weight to arrive.",
			"metres": 22.0, "x": 0.0, "hand": -1.0, "bias": 1,
			"bowls": [Vector3(-0.7, 0.0, 1.5), Vector3(0.15, 0.0, 1.7), Vector3(0.9, 0.0, 1.45)],
		},
		{
			"name": "WIDE JACK",
			"blurb": "The jack is off the centre line. Find the angle.",
			"metres": 26.0, "x": 2.2, "hand": -1.0, "bias": 2,
			"bowls": [Vector3(-1.2, 0.0, 1.2), Vector3(0.8, 0.0, 1.8), Vector3(0.3, 0.0, -1.4)],
		},
		{
			"name": "ON THE DOT",
			"blurb": "One of theirs is touching distance. Move it and stay.",
			"metres": 19.0, "x": 0.0, "hand": -1.0, "bias": 3,
			"bowls": [Vector3(0.28, 0.0, 0.15), Vector3(-1.4, 0.0, 1.6), Vector3(1.3, 0.0, -1.5)],
		},
		{
			"name": "THE LONG ONE",
			"blurb": "A full length, and the head is thin. Hold the line.",
			"metres": 31.0, "x": -0.4, "hand": 1.0, "bias": 1,
			"bowls": [Vector3(1.2, 0.0, 2.4), Vector3(-0.4, 0.0, -1.2), Vector3(0.9, 0.0, -2.0)],
		},
	]


func _sync_compare_cue() -> void:
	if disc == null or cue == null:
		return
	disc.global_position = Vector3(place_x, 0.0, line_z)
	disc.preview_take(_compare_aim, _compare_power)
	cue.present(disc.grass_cue(_compare_power), _compare_power, disc.aim_direction)
	ui.set_power_ratio(_compare_power)
	if fan != null:
		fan.present(Vector2.ZERO, 0.0, 0.0, false)
		fan.set_disc(Vector2.ZERO, false)
		fan.set_finger(Vector2.ZERO, false)
		fan.set_aim(Vector2.ZERO, Vector2.ZERO, false)
		fan.set_line(Vector2.ZERO, Vector2.ZERO, false)


func _set_compare_banner(title: String) -> void:
	if _compare_label == null:
		_compare_label = Label.new()
		_compare_label.position = Vector2(24.0, 168.0)
		_compare_label.size = Vector2(492.0, 88.0)
		_compare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_compare_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_compare_label.add_theme_font_size_override("font_size", 22)
		_compare_label.add_theme_color_override("font_color", Color(0.98, 0.99, 0.96))
		_compare_label.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.04, 0.85))
		_compare_label.add_theme_constant_override("outline_size", 8)
		ui.add_child(_compare_label)
	_compare_label.text = title
	ui.status_label.text = ""


func _dump_compare_shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex: Texture2D = get_viewport().get_texture()
	if tex == null:
		print("CUE_SHOT skip %s" % name)
		return
	var img := tex.get_image()
	if img == null:
		print("CUE_SHOT skip %s" % name)
		return
	DirAccess.make_dir_recursive_absolute("/tmp/cue_compare")
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	img.save_png("/tmp/cue_compare/%s.png" % name)
	img.save_png("/opt/cursor/artifacts/%s.png" % name)
	print("CUE_SHOT %s" % name)


func _cuetest() -> void:
	# Hold a real delivery on the live green so both purchased cues can be
	# compared on the same bias path, not on a mock board.
	await get_tree().process_frame
	await get_tree().process_frame
	_cue_compare = true
	if gesture != null:
		gesture.busy()
	delivering_jack = false
	bias_index = 3
	hand_sign = -1.0
	var jack_at := Vector3(0.35, 0.0, line_z - 21.0)
	jack.rest_at(jack_at)
	jack.visible = true
	jack_home = jack_at
	rink.place_head(Vector2(jack_at.x, jack_at.z))
	disc.configure_bowl(bias_index, hand_sign)
	disc.set_palette(0)
	disc.reset_to_start()
	disc.obstacles = _table()
	_place_rack()
	ui.show_bias(bias_index, 0)
	ui.show_bowl_controls(true)
	ui.show_hand(true, _bowl_name(bias_index))
	ui.show_match("AIM CUE")
	_use_cue_kind(0)
	if cue_blocks != null and cue_blocks.has_method("set_style"):
		cue_blocks.set_style(0)
	var steps := [
		{"power": 0.18, "bias": 3, "hand": -1.0, "aim": Vector3(0.22, 0.0, -1.0), "file": "blocks_light", "title": "5 + 3  •  LIGHT  •  ICE", "kind": 0},
		{"power": 0.52, "bias": 3, "hand": -1.0, "aim": Vector3(0.22, 0.0, -1.0), "file": "blocks_mid", "title": "5 + 3  •  MID  •  PINK", "kind": 0},
		{"power": 0.92, "bias": 3, "hand": -1.0, "aim": Vector3(0.22, 0.0, -1.0), "file": "blocks_heavy", "title": "5 + 3  •  FULL  •  RED", "kind": 0},
		{"power": 0.92, "bias": 3, "hand": 1.0, "aim": Vector3(0.22, 0.0, -1.0), "file": "blocks_backhand", "title": "5 + 3  •  BACKHAND", "kind": 0},
		{"power": 0.90, "bias": 3, "hand": 1.0, "aim": Vector3(-0.22, 0.0, -1.0), "file": "blocks_left", "title": "5 + 3  •  AIM LEFT", "kind": 0},
		{"power": 0.90, "bias": 1, "hand": -1.0, "aim": Vector3(0.0, 0.0, -1.0), "file": "blocks_jack", "title": "JACK  •  STRAIGHT", "kind": 0, "jack": true},
		{"power": 0.96, "bias": 3, "hand": -1.0, "aim": Vector3(0.22, 0.0, -1.0), "file": "solid_heavy", "title": "SOLID  •  FULL WEIGHT", "kind": 1},
	]
	for step in steps:
		_use_cue_kind(int(step["kind"]))
		_compare_power = float(step["power"])
		var aim: Vector3 = step["aim"]
		_compare_aim = aim.normalized()
		delivering_jack = bool(step.get("jack", false))
		if delivering_jack:
			disc.configure_jack()
			ui.show_bowl_controls(false)
		else:
			disc.configure_bowl(int(step["bias"]), float(step["hand"]))
			disc.set_palette(0)
			ui.show_bowl_controls(true)
			ui.show_hand(float(step["hand"]) < 0.0, _bowl_name(int(step["bias"])))
		_set_compare_banner(str(step["title"]))
		_sync_compare_cue()
		await get_tree().create_timer(1.8).timeout
		await _dump_compare_shot(str(step["file"]))
		await get_tree().create_timer(2.2).timeout
	print("CUETEST done")
	_use_cue_kind(0)
	delivering_jack = false
	disc.delivering_jack = false
	_compare_power = 0.90
	_compare_aim = Vector3(0.22, 0.0, -1.0).normalized()
	disc.configure_bowl(3, -1.0)
	_set_compare_banner("5 + 3  •  FULL  •  RED")
	_sync_compare_cue()
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)


func _fixtest() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 30
	await get_tree().process_frame
	await get_tree().process_frame
	if gesture != null:
		gesture.busy()
	print("FIXTEST rink=%.1fx%.1f chase=%s" % [rink.LENGTH, rink.HALF_WIDTH * 2.0, rink.chase])
	ui.show_camera_mode(rink.chase)
	await _dump_compare_shot("fix_follow_idle")
	disc.configure_jack()
	disc.reset_to_start()
	disc.fire_taken(Vector3(0.0, 0.0, -1.0), disc.weight_for_length(23.0, 0.0))
	var low := 999.0
	var high := -999.0
	for _i in 36:
		await get_tree().process_frame
		var bottom: float = disc.visual_bottom()
		low = minf(low, bottom)
		high = maxf(high, bottom)
		if _i == 8:
			await _dump_compare_shot("fix_jack_roll")
	print("FIXTEST jack_bottom min=%.3f max=%.3f span=%.3f" % [low, high, high - low])
	await _wait_jack()
	ui._open_pause()
	await get_tree().create_timer(0.25).timeout
	await _dump_compare_shot("fix_pause")
	ui._resume_game()
	var from := Vector3(0.0, 0.0, line_z)
	var jack_at: Vector3 = jack.global_position
	var along := maxf(from.z - jack_at.z, 8.0)
	var best := 999.0
	for hand in [-1.0, 1.0]:
		disc.configure_bowl(1, hand)
		var bias: float = disc.bias_ratio
		var power: float = disc.weight_for_length(along, bias)
		for sample in 13:
			var aim := Vector3((float(sample) - 6.0) * 0.32, 0.0, -along).normalized()
			var rest: Vector3 = disc.predict_rest(from, aim, power, bias)
			best = minf(best, Vector2(rest.x, rest.z).distance_to(Vector2(jack_at.x, jack_at.z)))
	print("FIXTEST ai_draw=%.2f chase=%s cam=%s" % [best, rink.chase, ui.camera_button.text])
	for bias in [0.0, 0.78, 1.28, 1.72]:
		for power in [0.55, 0.70, 0.85, 1.0]:
			var rest: Vector3 = disc.predict_rest(from, Vector3(0.0, 0.0, -1.0), power, bias)
			var along_m := from.z - rest.z
			print("FIXTEST reach bias=%.2f power=%.2f along=%.1f x=%.2f" % [bias, power, along_m, rest.x])
	print("FIXTEST weight23 blaze=%.2f classic=%.2f" % [disc.weight_for_length(23.0, 0.78), disc.weight_for_length(23.0, 1.72)])
	var peak := 0.0
	var pos := from
	var vel: Vector3 = disc._delivery_velocity(Vector3(0.0, 0.0, -1.0), 1.0)
	var axis := Vector2(0.0, -1.0)
	disc.configure_bowl(3, -1.0)
	for _s in 400:
		var moved: Array = disc._move_planar(pos, vel, disc.radius, disc.bias_ratio, true, 0.05, 1.0, axis)
		pos = moved[0]
		vel = moved[1]
		peak = maxf(peak, absf(pos.x))
		if bool(moved[3]) or vel.length() < 0.15:
			break
	print("FIXTEST hook100 peak_x=%.2f rest_x=%.2f rink_half=%.1f" % [peak, pos.x, rink.HALF_WIDTH])
	disc.configure_bowl(1, -1.0)
	disc.set_palette(0)
	disc.reset_to_start()
	if gesture != null:
		gesture.phase = "pull"
		gesture.direct_hold = disc.start_position + Vector3(0.0, 0.0, 0.42)
		gesture._raw_hold = gesture.direct_hold
		gesture.direct_aim = Vector3(0.07, 0.0, -1.0).normalized()
		gesture._raw_aim = gesture.direct_aim
		gesture.direct_power = 0.58
		gesture._raw_power = 0.58
		gesture.finger = Vector2(270.0, 620.0)
	for _i in 10:
		await get_tree().process_frame
	await _dump_compare_shot("fix_pull_aim")
	if gesture != null:
		gesture.busy()
		gesture.direct_power = 0.0
	disc.reset_to_start()
	disc.fire_taken(Vector3(0.0, 0.0, -1.0), 0.70)
	for _i in 36:
		await get_tree().process_frame
		if _i == 6:
			await _dump_compare_shot("fix_bowl_roll_a")
		elif _i == 18:
			await _dump_compare_shot("fix_bowl_roll")
		elif _i == 30:
			await _dump_compare_shot("fix_bowl_roll_b")
	ui.show_bowl_controls(true)
	ui.show_bias(1, 0)
	ui.show_hand(true, "BLAZE")
	await _dump_compare_shot("fix_hand_fore")
	disc.set_hand(1.0)
	ui.show_hand(false, "BLAZE")
	await _dump_compare_shot("fix_hand_back")
	print("FIXTEST done")
	get_tree().quit(0)


func _pull_snap(screen: Vector2) -> void:
	if gesture == null:
		return
	gesture._from = Vector2(270.0, 620.0)
	gesture._apply_direct(screen)
	gesture.direct_aim = gesture._raw_aim
	gesture.direct_power = gesture._raw_power
	gesture.direct_hold = gesture._raw_hold


func _pulltest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	delivering_jack = false
	disc.configure_bowl(1, -1.0)
	disc.set_palette(0)
	disc.reset_to_start()
	if gesture != null:
		gesture.arm()
		gesture.direct = true
		gesture.phase = "pull"
		gesture.anchor = disc.start_position
		gesture.direct_hold = disc.start_position
		gesture._raw_hold = disc.start_position
	_pull_snap(Vector2(270.0, 700.0))
	for _i in 4:
		await get_tree().process_frame
	print("PULLTEST modest 80px power=%.2f" % [gesture.direct_power if gesture != null else 0.0])
	_set_compare_banner("SHORT PULL • ON SCREEN")
	await _dump_compare_shot("pull_modest")
	_pull_snap(Vector2(150.0, 840.0))
	for _i in 4:
		await get_tree().process_frame
	var left_x: float = gesture.direct_aim.x if gesture != null else 0.0
	var left_pow: float = gesture.direct_power if gesture != null else 0.0
	print("PULLTEST left aim_x=%.3f power=%.2f yaw=%.3f" % [left_x, left_pow, disc.roll_basis.get_euler().y])
	_set_compare_banner("PULL BOTTOM LEFT • AIM RIGHT")
	await _dump_compare_shot("pull_bottom_left")
	_pull_snap(Vector2(390.0, 840.0))
	for _i in 4:
		await get_tree().process_frame
	var right_x: float = gesture.direct_aim.x if gesture != null else 0.0
	var right_pow: float = gesture.direct_power if gesture != null else 0.0
	print("PULLTEST right aim_x=%.3f power=%.2f yaw=%.3f" % [right_x, right_pow, disc.roll_basis.get_euler().y])
	print("PULLTEST opposite dx=%.3f pow_diff=%.3f" % [absf(left_x + right_x), absf(left_pow - right_pow)])
	_set_compare_banner("PULL BOTTOM RIGHT • AIM LEFT")
	await _dump_compare_shot("pull_bottom_right")
	_pull_snap(Vector2(450.0, 720.0))
	for _i in 4:
		await get_tree().process_frame
	print("PULLTEST far_right aim_x=%.3f power=%.2f fire=%s" % [gesture.direct_aim.x if gesture != null else 0.0, gesture.direct_power if gesture != null else 0.0, str((gesture.direct_power if gesture != null else 0.0) >= 0.07)])
	_set_compare_banner("PULL FAR RIGHT • STILL FIRES")
	await _dump_compare_shot("pull_far_right")
	_pull_snap(Vector2(270.0, 840.0))
	for _i in 4:
		await get_tree().process_frame
	print("PULLTEST straight 220px power=%.2f" % [gesture.direct_power if gesture != null else 0.0])
	_set_compare_banner("FULL POWER ON SCREEN")
	await _dump_compare_shot("pull_straight_full")
	DirAccess.make_dir_recursive_absolute("/tmp/pull_anim")
	var frames := 0
	for i in 8:
		var t := float(i) / 7.0
		_pull_snap(Vector2(270.0, 620.0).lerp(Vector2(150.0, 840.0), t))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var tex: Texture2D = get_viewport().get_texture()
		if tex != null:
			var img := tex.get_image()
			if img != null:
				img.save_png("/tmp/pull_anim/%03d.png" % frames)
				frames += 1
	for i in 8:
		var t := float(i) / 7.0
		_pull_snap(Vector2(150.0, 840.0).lerp(Vector2(390.0, 840.0), t))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var tex: Texture2D = get_viewport().get_texture()
		if tex != null:
			var img := tex.get_image()
			if img != null:
				img.save_png("/tmp/pull_anim/%03d.png" % frames)
				frames += 1
	print("PULLTEST frames=%d" % frames)
	player_hand = 1.0
	player_bias = 3
	hand_sign = player_hand
	bias_index = player_bias
	jack.rest_at(Vector3(0.0, 0.0, line_z - 28.0))
	jack.visible = true
	var saved_hand := player_hand
	var pick: Dictionary = _ai_pick()
	disc.configure_bowl(int(pick["bias"]), float(pick["hand"]))
	var from := Vector3(0.0, 0.0, line_z)
	var ai_rest: Vector3 = disc.predict_rest(from, pick["aim"], float(pick["power"]), disc.bias_ratio)
	var straight: Vector3 = disc.predict_rest(from, Vector3(0.0, 0.0, -1.0), float(pick["power"]), disc.bias_ratio)
	print("AITEST bowl=%s aim_x=%.3f power=%.2f rest_x=%.2f rest_z=%.1f dist=%.2f ring=%.2f in_ring=%s in_rink=%s ditch=%s straight_x=%.2f ai_hand=%.0f player_hand=%.0f kept=%s" % [
		_bowl_name(int(pick["bias"])),
		pick["aim"].x,
		float(pick["power"]),
		ai_rest.x,
		ai_rest.z,
		Vector2(ai_rest.x, ai_rest.z).distance_to(Vector2(jack.global_position.x, jack.global_position.z)),
		_ai_ring(),
		str(Vector2(ai_rest.x, ai_rest.z).distance_to(Vector2(jack.global_position.x, jack.global_position.z)) <= _ai_ring()),
		str(absf(ai_rest.x) < rink.HALF_WIDTH - 0.55),
		str(disc.will_ditch(from, pick["aim"], float(pick["power"]), disc.bias_ratio)),
		straight.x,
		float(pick["hand"]),
		player_hand,
		str(is_equal_approx(player_hand, saved_hand)),
	])
	ui.show_bowl_controls(true)
	ui.show_bias(int(pick["bias"]), 1)
	ui.show_hand(float(pick["hand"]) < 0.0, _bowl_name(int(pick["bias"])))
	_set_compare_banner("FOREHAND • RIGHT TO LEFT")
	await _dump_compare_shot("hand_fore")
	ui.show_hand(false, _bowl_name(int(pick["bias"])))
	_set_compare_banner("BACKHAND • LEFT TO RIGHT")
	await _dump_compare_shot("hand_back")
	ui.show_hand(float(pick["hand"]) < 0.0, _bowl_name(int(pick["bias"])))
	if gesture != null:
		gesture.busy()
	disc.reset_to_start()
	rink.chase = true
	disc.fire_taken(pick["aim"], float(pick["power"]))
	var chase_n := 0
	while (disc.shot_in_progress or chase_n < 40) and chase_n < 720:
		await get_tree().physics_frame
		chase_n += 1
		if chase_n == 40:
			_set_compare_banner("AI HOLD LINE • STILL ON THE GREEN")
			await _dump_compare_shot("ai_chase_early")
		elif chase_n == 140:
			await _dump_compare_shot("ai_chase_mid")
		elif chase_n == 280:
			await _dump_compare_shot("ai_chase_late")
	var live_bowl = settled[settled.size() - 1] if not settled.is_empty() else disc
	print("AITEST live_x=%.2f live_z=%.1f ditched=%s frames=%d" % [live_bowl.global_position.x, live_bowl.global_position.z, str(live_bowl.in_ditch), chase_n])
	_set_compare_banner("AI REST • ON THE GREEN")
	await _dump_compare_shot("ai_chase_rest")
	print("PULLTEST done")
	get_tree().quit(0)


func _endtest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_set_compare_banner("END 1  •  SAME LIGHT")
	await _dump_compare_shot("end1_mat")
	var jack_at := Vector3(0.0, 0.0, line_z - 28.0)
	jack.rest_at(jack_at)
	jack.visible = true
	rink.place_head(Vector2(jack_at.x, jack_at.z))
	rink.focus_head(jack_at)
	for _i in 36:
		await get_tree().process_frame
	_set_compare_banner("END 1  •  HEAD LOOK")
	await _dump_compare_shot("end1_head")
	end_number = 2
	_begin_end()
	for _i in 12:
		await get_tree().process_frame
	_set_compare_banner("END 2  •  SAME LIGHT AS END 1")
	await _dump_compare_shot("end2_mat")
	print("ENDTEST end1_cam=%.2f end2_ready_reset" % rink._cam_pos.y)
	print("ENDTEST done")
	get_tree().quit(0)


func _drawtest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	delivering_jack = false
	var from := Vector3(0.0, 0.0, line_z)
	disc.start_position = from
	disc.reset_to_start()
	for index in 4:
		disc.configure_bowl(index, -1.0)
		var bias: float = disc.bias_ratio
		var power: float = disc.weight_for_length(23.0, bias)
		var rest: Vector3 = disc.predict_rest(from, Vector3(0.0, 0.0, -1.0), power, bias)
		print("DRAWTEST %s bias=%.2f finish=%.2f pace=%.2f power=%.2f rest_x=%.2f along=%.1f" % [_bowl_name(index), bias, disc.bowl_finish, disc.bowl_pace, power, rest.x, from.z - rest.z])
		var long_power: float = disc.weight_for_length(40.0, bias)
		var long_rest: Vector3 = disc.predict_rest(from, Vector3(0.0, 0.0, -1.0), long_power, bias)
		print("DRAWTEST %s 40m rest_x=%.2f along=%.1f" % [_bowl_name(index), long_rest.x, from.z - long_rest.z])
		if gesture != null:
			gesture.arm()
			gesture.direct = true
			gesture.phase = "pull"
			gesture.anchor = from
			gesture._from = Vector2(270.0, 620.0)
			_pull_snap(Vector2(270.0, 780.0))
		_compare_aim = Vector3(0.18, 0.0, -1.0).normalized()
		_compare_power = 0.82
		_cue_compare = true
		ui.show_hand(true, _bowl_name(index))
		_set_compare_banner("%s  •  DRAW" % _bowl_name(index))
		_sync_compare_cue()
		await get_tree().create_timer(0.35).timeout
		await _dump_compare_shot("draw_cue_%s" % _bowl_name(index).to_lower())
	disc.configure_bowl(1, -1.0)
	print("DRAWTEST reach cruise=%.1f fire=%.1f green=%.1f" % [disc.reach_for(0.86), disc.reach_for(1.0), -rink.FAR_Z + line_z])
	disc.configure_bowl(3, 1.0)
	_compare_aim = Vector3(-0.18, 0.0, -1.0).normalized()
	_compare_power = 0.82
	_cue_compare = true
	ui.show_hand(false, "CLASSIC")
	_set_compare_banner("CLASSIC  •  BACKHAND")
	_sync_compare_cue()
	await get_tree().create_timer(0.35).timeout
	await _dump_compare_shot("draw_cue_classic_back")
	_cue_compare = false
	for index in 4:
		disc.configure_bowl(index, -1.0)
		var bias: float = disc.bias_ratio
		var power: float = disc.weight_for_length(23.0, bias)
		var pos := from
		var vel: Vector3 = disc._delivery_velocity(Vector3(0.0, 0.0, -1.0), power)
		var axis := Vector2(0.0, -1.0)
		var path: Array[Vector3] = []
		for _s in 500:
			var moved: Array = disc._move_planar(pos, vel, disc.radius, bias, true, 0.04, power, axis)
			pos = moved[0]
			vel = moved[1]
			path.append(pos)
			if bool(moved[3]) or vel.length() < 0.15:
				break
		var travelled := 0.0
		var i := path.size() - 1
		while i > 0 and travelled < 0.6:
			travelled += path[i].distance_to(path[i - 1])
			i -= 1
		var dx: float = path[path.size() - 1].x - path[i].x
		var dz: float = path[path.size() - 1].z - path[i].z
		print("DRAWTEST tail %s last0.6 dx=%.2f dz=%.2f ratio=%.2f" % [_bowl_name(index), dx, dz, absf(dx) / maxf(absf(dz), 0.01)])
	# Offline jack snaps onto the centre line.
	delivering_jack = true
	disc.configure_jack()
	var offline := Vector3(2.35, 0.0, line_z - 23.0)
	jack.rest_at(offline)
	jack.visible = true
	rink.place_head(Vector2(offline.x, offline.z))
	rink.focus_head(offline)
	_set_compare_banner("JACK OFF THE LINE")
	await get_tree().create_timer(0.8).timeout
	await _dump_compare_shot("draw_jack_offline")
	_finish_jack(offline)
	print("DRAWTEST jack_x=%.3f length=%.1f" % [jack.global_position.x, jack_length])
	rink.focus_head(jack.global_position)
	_set_compare_banner("JACK CENTRED")
	await get_tree().create_timer(0.8).timeout
	await _dump_compare_shot("draw_jack_centred")
	# Knocked jack takes the rings with it.
	var knocked := Vector3(1.55, 0.0, jack.global_position.z - 0.4)
	jack.rest_at(knocked)
	jack.visible = true
	_sync_head_rings()
	rink.focus_head(knocked)
	_set_compare_banner("RINGS FOLLOW THE JACK")
	await get_tree().create_timer(0.8).timeout
	await _dump_compare_shot("draw_rings_follow")
	# Short jack (under 23 m) is lifted onto the T.
	delivering_jack = true
	disc.in_ditch = false
	var short_at := Vector3(0.0, 0.0, line_z - 8.0)
	jack.rest_at(short_at)
	jack.visible = true
	rink.place_head(Vector2(short_at.x, short_at.z))
	rink.focus_head(short_at)
	_set_compare_banner("SHORT JACK  •  8 m")
	await get_tree().create_timer(0.7).timeout
	await _dump_compare_shot("draw_jack_short")
	_finish_jack(short_at)
	print("DRAWTEST short->tee z=%.2f length=%.1f tee=%.2f" % [jack.global_position.z, jack_length, rink.tee_z()])
	rink.focus_head(jack.global_position)
	_set_compare_banner("PLACED ON THE T")
	await get_tree().create_timer(0.8).timeout
	await _dump_compare_shot("draw_jack_tee")
	# Jack in the end ditch re-spots onto the T (Law 56.5).
	delivering_jack = false
	jack.drop_in_ditch(Vector3(0.0, -0.18, rink.FAR_Z - 0.35))
	jack.visible = true
	rink.focus_head(jack.global_position)
	_set_compare_banner("JACK IN THE END DITCH")
	await get_tree().create_timer(0.7).timeout
	await _dump_compare_shot("draw_jack_ditch")
	_respot_jack()
	print("DRAWTEST ditch->tee z=%.2f in_ditch=%s" % [jack.global_position.z, jack.in_ditch])
	rink.focus_head(jack.global_position)
	_set_compare_banner("RE-SPOTTED ON THE T")
	await get_tree().create_timer(0.8).timeout
	await _dump_compare_shot("draw_jack_respot")
	# Put a legal jack back for the hook roll.
	var legal := Vector3(0.0, 0.0, line_z - 23.0)
	jack.rest_at(legal)
	jack.visible = true
	jack_home = legal
	jack_length = _distance(legal, disc.start_position)
	rink.place_head(Vector2(legal.x, legal.z))
	# Roll a hook so the last metres run sideways.
	delivering_jack = false
	if gesture != null:
		gesture.busy()
	disc.configure_bowl(3, -1.0)
	disc.set_palette(0)
	disc.reset_to_start()
	rink.release_head()
	var hook_power: float = disc.weight_for_length(23.0, disc.bias_ratio)
	disc.fire_taken(Vector3(0.20, 0.0, -1.0).normalized(), hook_power)
	DirAccess.make_dir_recursive_absolute("/tmp/hook_anim")
	var frames := 0
	var ticks := 0
	var last_x: float = disc.global_position.x
	var last_z: float = disc.global_position.z
	while disc.shot_in_progress and ticks < 400:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		ticks += 1
		last_x = disc.global_position.x
		last_z = disc.global_position.z
		if disc.velocity.length() < 5.8 and ticks % 2 == 0:
			var tex: Texture2D = get_viewport().get_texture()
			if tex != null:
				var img := tex.get_image()
				if img != null:
					img.save_png("/tmp/hook_anim/%03d.png" % frames)
					frames += 1
	print("DRAWTEST hook_rest x=%.2f z=%.2f frames=%d ticks=%d" % [last_x, last_z, frames, ticks])
	await _dump_compare_shot("draw_hook_rest")
	print("DRAWTEST done")
	get_tree().quit(0)


func _handtest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if gesture != null:
		gesture.busy()
	delivering_jack = false
	disc.configure_bowl(3, -1.0)
	disc.set_palette(0)
	ui.show_bowl_controls(true)
	ui.show_hand(true, "CLASSIC")
	_set_compare_banner("FOREHAND")
	_compare_power = 0.9
	_compare_aim = Vector3(0.22, 0.0, -1.0).normalized()
	_cue_compare = true
	_sync_compare_cue()
	await get_tree().create_timer(0.8).timeout
	await _dump_compare_shot("hand_fore")
	disc.set_hand(1.0)
	hand_sign = disc.hand_sign
	ui.show_hand(false, "CLASSIC")
	_set_compare_banner("BACKHAND")
	_sync_compare_cue()
	await get_tree().create_timer(0.6).timeout
	await _dump_compare_shot("hand_back")
	print("HANDTEST done")
	get_tree().quit(0)


func _kitshot() -> void:
	_freeze_cam = true
	if rink != null:
		rink.pose_lock = true
	await get_tree().process_frame
	await get_tree().process_frame
	delivering_jack = false
	if disc != null:
		disc.configure_bowl(1, -1.0)
		disc.set_palette(0)
		disc.global_position = Vector3(0.0, 0.0, line_z)
		disc.start_position = disc.global_position
		disc.seat_visual()
	if ui != null:
		ui.visible = true
	if gesture != null:
		gesture.busy()
	var cam: Camera3D = rink.view_camera() if rink != null else null
	if cam != null and disc != null:
		var at: Vector3 = disc.global_position
		cam.fov = 42.0
		cam.position = at + Vector3(0.0, 0.55, 1.35)
		cam.look_at(at + Vector3(0.0, 0.10, -0.4), Vector3.UP)
	var looks := [
		{"file": "kit_bowl_club", "skin": "club", "color": 1},
		{"file": "kit_bowl_camo", "skin": "camo", "color": 6},
		{"file": "kit_bowl_split", "skin": "split", "color": 1},
	]
	for look in looks:
		_apply_test_kit(str(look["skin"]), int(look["color"]))
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().create_timer(0.45).timeout
		await _dump_compare_shot(str(look["file"]))
	if disc != null:
		var holder: Node3D = disc.get_node_or_null("ClubBowl")
		if holder == null:
			holder = disc.find_child("ClubBowl", true, false) as Node3D
		var mi := BowlScript._first_mesh(holder) if holder != null else null
		if mi != null and mi.mesh != null:
			var box: AABB = mi.global_transform * mi.mesh.get_aabb()
			print("BOWL_AABB size=%.3f,%.3f,%.3f sit=%.3f pole=%s" % [
				box.size.x, box.size.y, box.size.z, disc._bowl_sit, str(BowlScript.pole_of(mi))
			])
	if cam != null and disc != null:
		var at: Vector3 = disc.global_position
		cam.fov = 40.0
		cam.position = at + Vector3(0.55, 0.20, 0.78)
		cam.look_at(at + Vector3(0.0, 0.06, 0.0), Vector3.UP)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await _dump_compare_shot("kit_bowl_side")
		cam.position = at + Vector3(0.0, 1.15, 0.05)
		cam.look_at(at + Vector3(0.0, 0.0, 0.0), Vector3.FORWARD)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await _dump_compare_shot("kit_bowl_top")
	print("KITSHOT done")
	get_tree().quit(0)


func _rollshot() -> void:
	# Dump the first second of a live delivery so the chase sit can be
	# checked for smear without a phone in hand.
	await get_tree().process_frame
	await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	delivering_jack = false
	if ui != null:
		ui.visible = true
	if gesture != null:
		gesture.busy()
	if disc == null or rink == null:
		print("ROLLSHOT skip")
		get_tree().quit(2)
		return
	disc.configure_bowl(1, -1.0)
	disc.set_palette(0)
	disc.start_position = Vector3(0.0, 0.0, line_z)
	disc.reset_to_start()
	if jack != null:
		jack.rest_at(Vector3(0.0, 0.0, line_z - 23.0))
		jack.visible = true
	if ui != null:
		ui.show_bowl_controls(true)
	disc.is_aiming = true
	rink.chase = true
	rink.note_delivery(disc.global_position, Vector3.ZERO, false, Vector3(0.0, 0.0, line_z), disc.global_position, true)
	await get_tree().process_frame
	await get_tree().process_frame
	await _dump_compare_shot("roll_aim")
	disc.is_aiming = false
	var power: float = disc.weight_for_length(23.0, disc.bias_ratio)
	disc.fire_taken(Vector3(0.22, 0.0, -1.0).normalized(), power)
	DirAccess.make_dir_recursive_absolute("/tmp/roll_anim")
	var frames := 0
	for i in 36:
		await get_tree().create_timer(0.04).timeout
		await RenderingServer.frame_post_draw
		var tex: Texture2D = get_viewport().get_texture()
		if tex != null:
			var img := tex.get_image()
			if img != null:
				img.save_png("/tmp/roll_anim/%03d.png" % frames)
				if i == 0 or i == 4 or i == 10 or i == 20 or i == 28 or i == 30:
					img.save_png("/opt/cursor/artifacts/roll_%02d.png" % i)
				frames += 1
	print("ROLLSHOT frames=%d pos=%.2f,%.2f" % [frames, disc.global_position.x, disc.global_position.z])
	get_tree().quit(0)


func _aitest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	delivering_jack = false
	opponent = "local"
	difficulty = 1
	fast_play = true
	if ui != null:
		ui.visible = true
	if gesture != null:
		gesture.busy()
	if disc == null or jack == null:
		print("AITEST skip")
		get_tree().quit(2)
		return
	jack.rest_at(Vector3(0.0, 0.0, line_z - 23.0))
	jack.visible = true
	jack_home = jack.global_position
	rink.place_head(Vector2(jack.global_position.x, jack.global_position.z))
	disc.obstacles = _table()
	throw_index = 1
	for n in 3:
		var pick: Dictionary = _ai_pick()
		disc.configure_bowl(int(pick["bias"]), float(pick["hand"]))
		disc.set_palette(1)
		ui.show_hand(float(pick["hand"]) < 0.0, _bowl_name(int(pick["bias"])))
		var from := Vector3(0.0, 0.0, line_z)
		var predicted: Vector3 = disc.predict_rest(from, pick["aim"], float(pick["power"]), disc.bias_ratio)
		var pred_dist := Vector2(predicted.x, predicted.z).distance_to(Vector2(jack.global_position.x, jack.global_position.z))
		print("AITEST pick%d bowl=%s power=%.2f pred_dist=%.2f pred_short=%.2f ring=%.2f" % [
			n,
			_bowl_name(int(pick["bias"])),
			float(pick["power"]),
			pred_dist,
			predicted.z - jack.global_position.z,
			_ai_ring(),
		])
		disc.reset_to_start()
		disc.fire_taken(pick["aim"], float(pick["power"]))
		var hung := true
		for _i in 900:
			await get_tree().process_frame
			if not disc.shot_in_progress and settled.size() >= n + 1:
				hung = false
				break
		if hung:
			print("AITEST hung %d" % n)
			get_tree().quit(2)
			return
		var rest: Vector3 = settled[n].global_position
		var dist := _distance(rest, jack.global_position)
		print("AITEST rest%d x=%.2f z=%.1f dist=%.2f in_ring=%s ditched=%s" % [
			n,
			rest.x,
			rest.z,
			dist,
			str(dist <= _ai_ring()),
			str(settled[n].in_ditch),
		])
		await _dump_compare_shot("ai_rest_%d" % n)
	get_tree().quit(0)


func _apply_test_kit(skin_id: String, color: int) -> void:
	var kit := {
		"bowl_skin": skin_id,
		"bowl_color": color,
		"disc_skin": skin_id,
		"disc_color": color,
	}
	get_tree().root.set_meta("flickdisc_kit", kit)
	if disc != null:
		disc.set_palette(0)
		disc.seat_visual()
	for bowl in rack:
		bowl.paint(0, hand_sign)


func _wants_cuetest() -> bool:
	return OS.get_cmdline_user_args().has("--cuetest")


func _wants_bowltest() -> bool:
	return OS.get_cmdline_user_args().has("--bowltest")


func _wants_showcase() -> bool:
	return OS.get_cmdline_user_args().has("--showcase")


func _wants_drive() -> bool:
	return OS.get_cmdline_user_args().has("--drive")


func _wants_drivetest() -> bool:
	return OS.get_cmdline_user_args().has("--drivetest")


func _wants_solotest() -> bool:
	return OS.get_cmdline_user_args().has("--solotest")


func _drivetest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var reach: float = disc.reach_for(1.0)
	disc.bias_ratio = 0.0
	var power: float = disc.weight_for_length(220.0, 0.0)
	var rest: Vector3 = disc.predict_rest(disc.start_position, Vector3(0.0, 0.0, -1.0), power, 0.0)
	var travelled := _distance(rest, disc.start_position)
	var ok: bool = reach > 500.0 and travelled > 160.0 and mark_root_visible()
	print("DRIVETEST reach=%.1f travelled=%.1f mark=%.1f ok=%s" % [reach, travelled, absf(mark_at.z), ok])
	get_tree().quit(0 if ok else 2)


func mark_root_visible() -> bool:
	return rink != null and rink.has_mark()


func _solotest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var guards := 0
	for body in settled:
		if int(body.side) == 1:
			guards += 1
	var on_jack: bool = _player_is_shot(jack.global_position, false)
	var wide: bool = not _player_is_shot(jack.global_position + Vector3(4.0, 0.0, 0.0), false)
	var named: bool = str(_solo_ends()[0]["name"]) == "THE DRAW"
	var showing: bool = bool(jack.visible)
	var ok: bool = guards == 3 and showing and on_jack and wide and named and _solo_ends().size() >= 8
	print("SOLOTEST guards=%d on_jack=%s wide=%s ends=%d" % [guards, on_jack, wide, _solo_ends().size()])
	get_tree().quit(0 if ok else 2)


func _showcase() -> void:
	# The same delivery the finger uses, played out so the chase, the mat camera, and the ditch can be watched.
	await get_tree().process_frame
	await get_tree().process_frame
	_on_ditch_option_requested()
	await get_tree().create_timer(3.2).timeout
	var jack_power: float = disc.weight_for_length(23.0, 0.0)
	disc.fire_taken(Vector3(0.0, 0.0, -1.0), jack_power)
	if not await _wait_jack():
		_fail_test("showcase jack")
		return
	await get_tree().create_timer(0.7).timeout
	_play_shown(3, -1.0, Vector3(0.12, 0.0, -1.0), maxf(jack_length - 0.5, 8.0), 0)
	if not await _wait_shown(1):
		_fail_test("showcase hook")
		return
	_on_camera_requested()
	await get_tree().create_timer(0.45).timeout
	_play_shown(2, 1.0, Vector3(-0.08, 0.0, -1.0), maxf(jack_length - 0.2, 8.0), 1)
	if not await _wait_shown(2):
		_fail_test("showcase mat")
		return
	_on_camera_requested()
	await get_tree().create_timer(0.35).timeout
	disc.configure_bowl(2, -1.0)
	disc.set_palette(0)
	bias_index = 2
	hand_sign = disc.hand_sign
	ui.show_bias(bias_index, _side())
	ui.show_hand(true, _bowl_name(bias_index))
	# Wide, on the forehand, with a little line. It runs, draws, and leaves by the side ditch.
	disc.fire_taken(Vector3(-0.34, 0.0, -1.0).normalized(), 0.78)
	if not await _wait_shown(3):
		_fail_test("showcase ditch")
		return
	await get_tree().create_timer(1.6).timeout
	var ditched: bool = settled.size() == 3 and bool(settled[2].in_ditch)
	print("SHOWCASE hook_x=%.2f ditch=%s" % [settled[0].global_position.x, ditched])
	get_tree().quit(0 if ditched else 2)


func _play_shown(bowl_index: int, hand: float, aim: Vector3, metres: float, side: int) -> void:
	disc.configure_bowl(bowl_index, hand)
	disc.set_palette(side)
	bias_index = bowl_index
	hand_sign = disc.hand_sign
	ui.show_bias(bias_index, side)
	ui.show_hand(hand < 0.0, _bowl_name(bias_index))
	var power: float = disc.weight_for_length(metres, disc.bias_ratio)
	disc.fire_taken(aim.normalized(), power)


func _wait_shown(expected: int) -> bool:
	var saw_head := false
	for _i in 1800:
		await get_tree().process_frame
		if settled.size() >= expected and rink._head_hold:
			saw_head = true
		if saw_head and not rink._head_hold and not disc.shot_in_progress:
			if gesture != null and str(gesture.phase) == "idle":
				return true
	return false


func _bowltest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not _assert_hands():
		return
	var jack_power: float = disc.weight_for_length(22.0, 0.0)
	disc.fire_taken(Vector3(0.0, 0.0, -1.0), jack_power)
	if not await _wait_jack():
		_fail_test("jack never settled")
		return
	if jack_length < 16.0 or jack_length > 30.0:
		_fail_test("jack length %.2f" % jack_length)
		return
	var first_rest := Vector3.ZERO
	var knock := 0.0
	var rolled := false
	for n in BOWLS_PER_END:
		if delivering_jack or disc.shot_in_progress or not disc.visible:
			_fail_test("not ready for bowl %d" % n)
			return
		var side := n % 2
		var hand := -1.0 if n < 2 or side == 0 else 1.0
		disc.configure_bowl(1, hand)
		disc.set_palette(side)
		var aim_x := 0.65 if n < 2 else (0.35 if side == 0 else -0.45)
		var power: float = disc.weight_for_length(maxf(jack_length - 0.35, 8.0), disc.bias_ratio)
		if n == 1:
			first_rest = settled[0].global_position
		disc.fire_taken(Vector3(aim_x, 0.0, -1.0).normalized(), power)
		if not await _wait_bowls(n + 1):
			_fail_test("bowl %d hung" % n)
			return
		var basis: Basis = settled[n].roll_basis
		if basis.get_rotation_quaternion().get_angle() > 0.4:
			rolled = true
		if n == 1:
			knock = settled[0].global_position.distance_to(first_rest)
	var black := 0
	var red := 0
	for body in settled:
		if int(body.side) == 0:
			black += 1
		else:
			red += 1
	var saved_you := you_points
	var saved_them := them_points
	var saved_end := end_number
	var saved_index := match_index
	match_index = 2
	you_points = 10
	them_points = 4
	var to10: bool = _is_match_over()
	you_points = 9
	var short10: bool = not _is_match_over()
	you_points = 10
	them_points = 10
	var tied10: bool = not _is_match_over()
	match_index = 3
	you_points = 21
	them_points = 18
	var to21: bool = _is_match_over()
	match_index = 0
	end_number = 1
	var one_end: bool = _is_match_over()
	you_points = saved_you
	them_points = saved_them
	end_number = saved_end
	match_index = saved_index
	var formats_ok := to10 and short10 and tied10 and to21 and one_end
	var ok := black == 4 and red == 4 and match_complete and rolled and knock > 0.05 and formats_ok
	print("BOWLTEST jack=%.2f black=%d red=%d you=%d them=%d over=%s rolled=%s knock=%.3f" % [jack_length, black, red, you_points, them_points, match_complete, rolled, knock])
	get_tree().quit(0 if ok else 2)


func _assert_hands() -> bool:
	# The hand has to be obvious, and a bowl aimed off the rink has to fall in.
	ditch_mode = true
	disc.ditch_mode = true
	rink.set_ditch_mode(true)
	disc.configure_bowl(0, -1.0)
	var narrow_bias: float = disc.bias_ratio
	var narrow_power: float = disc.weight_for_length(24.0, narrow_bias)
	var narrow: Vector3 = disc.predict_rest(Vector3.ZERO, Vector3(0.0, 0.0, -1.0), narrow_power, narrow_bias)
	disc.configure_bowl(3, -1.0)
	var hook_bias: float = disc.bias_ratio
	var hook_power: float = disc.weight_for_length(24.0, hook_bias)
	var hook: Vector3 = disc.predict_rest(Vector3.ZERO, Vector3(0.0, 0.0, -1.0), hook_power, hook_bias)
	var spread := narrow.x - hook.x
	var ditched: bool = disc.will_ditch(Vector3(0.0, 0.0, -2.0), Vector3(0.9, 0.0, -0.35).normalized(), 0.9, 0.0)
	var stayed: bool = not disc.will_ditch(Vector3.ZERO, Vector3(0.0, 0.0, -1.0), narrow_power, 0.0)
	ditch_mode = true
	disc.ditch_mode = true
	rink.set_ditch_mode(true)
	disc.configure_jack()
	disc.reset_to_start()
	print("HANDTEST narrow=%.2f hook=%.2f spread=%.2f ditch=%s stay=%s" % [narrow.x, hook.x, spread, ditched, stayed])
	if spread < 0.8 or not ditched or not stayed:
		_fail_test("hands spread=%.2f ditch=%s stay=%s" % [spread, ditched, stayed])
		return false
	return true


func _wait_jack() -> bool:
	for _i in 1200:
		await get_tree().process_frame
		if not delivering_jack and not disc.shot_in_progress and jack.visible:
			return true
	return false


func _wait_bowls(expected: int) -> bool:
	for _i in 1200:
		await get_tree().process_frame
		if disc.shot_in_progress or settled.size() < expected:
			continue
		if match_complete or (gesture != null and str(gesture.phase) == "idle"):
			return true
	return false


func _fail_test(reason: String) -> void:
	print("BOWLTEST FAIL %s" % reason)
	get_tree().quit(2)


func _distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _on_reset_requested() -> void:
	feel.tap()
	_new_match()


func _on_next_level_requested() -> void:
	feel.tap()
	if distance_play:
		_begin_drive()
		return
	if solo_play:
		if solo_won:
			solo_index = mini(solo_index + 1, _solo_ends().size() - 1)
			solo_tries = 0
		_begin_solo()
		return
	if match_complete:
		_new_match()
		return
	end_number += 1
	_begin_end()
