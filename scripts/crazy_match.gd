extends Node3D

## Crazy Bowls: bowls golf on a wide lawn. Bias still bends. The cup is the hole.

signal tally_crazy(strokes: int, par: int)

const DiscScript := preload("res://scripts/disc_controller.gd")
const BowlScript := preload("res://scripts/bowl.gd")
const FeelScript := preload("res://scripts/feel.gd")
const GreenScript := preload("res://scripts/crazy_green.gd")
const Holes := preload("res://scripts/crazy_holes.gd")

const PLACE_HALF := 1.65
const MAX_OVER := 4

var disc
var ui
var green
var feel
var gesture
var fan
var cue
var cue_blocks
var cue_kind := 0
var course: Array = []
var hole_index := 0
var hole_strokes := 0
var card: Array = []
var round_seed := 0
var hand_sign := -1.0
var bias_index := 1
var place_x := 0.0
var line_z := 0.0
var shot_token := 0
var round_done := false
var on_tee := true
var cue_solid


func _ready() -> void:
	ui = get_node("UI")
	feel = FeelScript.new()
	feel.name = "Feel"
	add_child(feel)
	disc = DiscScript.new()
	disc.name = "PlayerDisc"
	add_child(disc)
	disc.aim_changed.connect(_on_aim)
	disc.shot_started.connect(_on_shot_started)
	disc.shot_stopped.connect(_on_shot_stopped)
	disc.impacted.connect(_on_impacted)
	ui.reset_requested.connect(_on_reset)
	ui.next_level_requested.connect(_on_next)
	ui.hand_selected.connect(_on_hand)
	ui.bias_selected.connect(_on_bias)
	ui.camera_requested.connect(_on_camera)
	ui.cue_cycle_requested.connect(_on_cue)
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	round_seed = Time.get_unix_time_from_system()
	if OS.get_cmdline_user_args().has("--crazytest"):
		round_seed = 18
	course = Holes.deal(round_seed)
	_wire_shot()
	_open_hole(0)
	if OS.get_cmdline_user_args().has("--crazytest"):
		call_deferred("_crazytest")


func _process(delta: float) -> void:
	if gesture != null:
		gesture.advance(delta)
	_sync_fan()
	if feel != null and disc != null:
		var speed: float = disc.velocity.length() if disc.shot_in_progress else 0.0
		feel.set_roll(speed / DiscScript.MAX_SPEED)
	if green != null and disc != null:
		green.note_delivery(
			disc.global_position,
			disc.velocity,
			disc.shot_in_progress,
			Vector3(place_x, 0.0, line_z),
			green.cup,
			disc.is_aiming
		)


func _wire_shot() -> void:
	var shot := preload("res://scripts/shot_gesture.gd").new()
	shot.name = "ShotGesture"
	shot.hit_test = _pointer_hits_disc
	shot.board_point = _board_point
	shot.place_at.connect(_on_place_at)
	shot.aim_set.connect(_on_aim_set)
	shot.kept_aim.connect(func() -> void: ui.show_aim_ready(false))
	shot.opened_take.connect(_on_take_opened)
	shot.cancelled_pull.connect(_on_pull_cancelled)
	shot.fired.connect(_on_shot_fired)
	shot.direct = true
	shot.blocks_pointer = ui.blocks_shot_at
	add_child(shot)
	gesture = shot
	fan = preload("res://scripts/shot_fan.gd").new()
	fan.name = "ShotFan"
	ui.add_child(fan)
	cue_blocks = preload("res://scripts/aim_cue.gd").new()
	add_child(cue_blocks)
	cue_solid = preload("res://scripts/aim_cue_solid.gd").new()
	add_child(cue_solid)
	cue = cue_blocks


func _open_hole(index: int) -> void:
	hole_index = clampi(index, 0, course.size() - 1)
	hole_strokes = 0
	on_tee = true
	round_done = false
	if green != null:
		green.queue_free()
		green = null
	var hole: Dictionary = course[hole_index]
	green = GreenScript.new()
	green.name = "Green"
	green.setup_hole(hole)
	add_child(green)
	if gesture != null:
		gesture.camera = green.view_camera()
	disc.set_pace(0.55, 2.52)
	disc.ditch_mode = false
	disc.set_green(Vector2(-green.HALF_WIDTH, green.FAR_Z), Vector2(green.HALF_WIDTH, 2.2))
	disc.set_cup(green.cup, green.cup_radius)
	disc.set_course(Callable(green, "height_at"), green.water_spots, green.tree_spots)
	disc.configure_bowl(bias_index, hand_sign)
	disc.set_palette(0)
	place_x = hole["tee"].x
	line_z = hole["tee"].z
	disc.start_position = Vector3(place_x, green.height_at(place_x, line_z), line_z)
	disc.reset_to_start()
	green.reset_view()
	ui.hide_summary()
	ui.show_ditch_mode(false)
	if ui.ditch_button != null:
		ui.ditch_button.visible = false
	ui.show_camera_mode(green.chase)
	ui.show_match("HOLE %d" % int(hole["number"]))
	ui.show_bias(bias_index, 0)
	ui.show_hand(hand_sign < 0.0, _bowl_name())
	ui.show_crazy_prompt(hole, _to_par(), hole_strokes)
	_begin_ready()


func _begin_ready() -> void:
	shot_token += 1
	var y := 0.0
	if green != null:
		y = green.height_at(place_x, line_z)
	disc.start_position = Vector3(place_x, y, line_z)
	disc.global_position = disc.start_position
	disc.configure_bowl(bias_index, hand_sign)
	if gesture != null:
		gesture.arm()
		gesture.anchor = disc.start_position
		if green != null:
			gesture.camera = green.view_camera()
	ui.show_bowl_controls(true)
	ui.show_bias(bias_index, 0)
	ui.show_hand(hand_sign < 0.0, _bowl_name())
	ui.show_place_line(false)


func _on_place_at(spot: Vector3) -> void:
	if not on_tee:
		return
	place_x = clampf(spot.x, -PLACE_HALF, PLACE_HALF)
	var y: float = green.height_at(place_x, line_z) if green != null else 0.0
	disc.start_position = Vector3(place_x, y, line_z)
	disc.global_position = disc.start_position
	if green != null:
		green.release_head()
	ui.show_sliding(false)


func _on_aim_set(_amount: float) -> void:
	ui.show_aiming_line(false)


func _on_take_opened() -> void:
	ui.show_take_shot(false)
	ui.set_power_ratio(0.0)
	feel.tap()


func _on_pull_cancelled() -> void:
	var y: float = green.height_at(place_x, line_z) if green != null else 0.0
	disc.global_position = Vector3(place_x, y, line_z)
	if disc.is_aiming:
		disc.preview_take(Vector3(0.0, 0.0, -1.0), 0.0)
	ui.show_take_shot(false)
	ui.set_power_ratio(0.0)


func _on_shot_fired(power: float, _needle: float) -> void:
	var y: float = green.height_at(place_x, line_z) if green != null else 0.0
	disc.start_position = Vector3(place_x, y, line_z)
	if gesture != null and gesture.direct:
		disc.global_position = gesture.direct_hold
		disc.fire_taken(gesture.direct_aim, power)
		return
	disc.fire_taken(Vector3(0.0, 0.0, -1.0), power)


func _on_shot_started() -> void:
	hole_strokes += 1
	on_tee = false
	ui.set_power_ratio(0.0)
	ui.show_in_motion("YOU", _bowl_name(), hand_sign < 0.0, _score_line())
	feel.release(disc.power_ratio)


func _on_impacted(speed: float, hit_jack: bool, hit_bank: bool) -> void:
	feel.contact(speed, hit_jack, hit_bank)


func _on_shot_stopped() -> void:
	call_deferred("_finish_shot", shot_token)


func _finish_shot(token: int) -> void:
	if token != shot_token or not is_inside_tree() or green == null:
		return
	var rest: Vector3 = disc.global_position
	var hole: Dictionary = course[hole_index]
	var par := int(hole["par"])
	if disc.in_cup:
		card.append(hole_strokes)
		ui.show_crazy_holed(hole, hole_strokes, _to_par())
		if green != null:
			green.focus_cup()
		if gesture != null:
			gesture.busy()
		return
	if disc.in_ditch:
		hole_strokes += 1
		var drop := _drop_from_water(rest)
		place_x = drop.x
		line_z = drop.z
		disc.in_ditch = false
		disc.reset_to_start()
		ui.show_crazy_water(hole, hole_strokes, _to_par())
		if hole_strokes >= par + MAX_OVER:
			_pick_up(hole, par)
			return
		_begin_ready()
		return
	if hole_strokes >= par + MAX_OVER:
		_pick_up(hole, par)
		return
	place_x = rest.x
	line_z = rest.z
	disc.start_position = rest
	disc.reset_to_start()
	disc.global_position = rest
	ui.show_crazy_rest(hole, hole_strokes, _to_par(), rest.distance_to(green.cup))
	_begin_ready()


func _pick_up(hole: Dictionary, par: int) -> void:
	card.append(par + MAX_OVER)
	ui.show_crazy_holed(hole, par + MAX_OVER, _to_par())
	if gesture != null:
		gesture.busy()


func _drop_from_water(rest: Vector3) -> Vector3:
	var mid := Vector3(0.0, 0.0, (green.tee.z + green.cup.z) * 0.5)
	var away := rest + (mid - rest).normalized() * 1.8
	away.x = clampf(away.x, -green.HALF_WIDTH + 0.6, green.HALF_WIDTH - 0.6)
	away.z = clampf(away.z, green.FAR_Z + 1.2, -1.2)
	away.y = green.height_at(away.x, away.z)
	return away


func _to_par() -> int:
	var strokes := 0
	var par := 0
	for i in card.size():
		strokes += int(card[i])
		par += int(course[i]["par"])
	return strokes - par


func _score_line() -> String:
	var hole: Dictionary = course[hole_index]
	return "HOLE %d  •  STROKE %d  •  PAR %d" % [int(hole["number"]), hole_strokes, int(hole["par"])]


func _bowl_name() -> String:
	return str(BowlScript.bowl_type(bias_index)["name"])


func _on_reset() -> void:
	feel.tap()
	_open_hole(hole_index)


func _on_next() -> void:
	feel.tap()
	if round_done:
		round_seed = Time.get_unix_time_from_system()
		course = Holes.deal(round_seed)
		card.clear()
		_open_hole(0)
		return
	if hole_index >= course.size() - 1:
		_finish_round()
		return
	_open_hole(hole_index + 1)


func _finish_round() -> void:
	round_done = true
	var strokes := 0
	for n in card:
		strokes += int(n)
	tally_crazy.emit(strokes, Holes.COURSE_PAR)
	ui.show_crazy_done(strokes, Holes.COURSE_PAR, card)
	if gesture != null:
		gesture.busy()


func _on_hand(forehand: bool) -> void:
	if disc.shot_in_progress:
		return
	feel.tap()
	disc.set_hand(-1.0 if forehand else 1.0)
	hand_sign = disc.hand_sign
	ui.show_hand(forehand, _bowl_name())


func _on_bias(index: int) -> void:
	if disc.shot_in_progress:
		return
	feel.tap()
	bias_index = clampi(index, 0, 3)
	disc.configure_bowl(bias_index, hand_sign)
	ui.show_bias(bias_index, 0)
	ui.show_hand(hand_sign < 0.0, _bowl_name())


func _on_camera() -> void:
	feel.tap()
	if green != null:
		green.chase = not green.chase
		ui.show_camera_mode(green.chase)


func _on_cue() -> void:
	feel.tap()
	cue_kind = (cue_kind + 1) % 4
	if cue_blocks != null and cue_blocks.has_method("set_heads"):
		var heads := 8
		if cue_kind == 1:
			heads = 5
		elif cue_kind == 2:
			heads = 3
		cue_blocks.set_heads(heads)
	ui.show_cue_kind(cue_kind)


func _on_aim(_direction: Vector2, power_ratio: float) -> void:
	ui.set_power_ratio(power_ratio)


func _pointer_hits_disc(screen_position: Vector2) -> bool:
	if disc == null or not disc.visible or disc.shot_in_progress or green == null:
		return false
	var cam: Camera3D = green.view_camera()
	if cam == null:
		return false
	var disc_screen := cam.unproject_position(disc.global_position)
	var edge := cam.unproject_position(disc.global_position + Vector3(disc.radius * 2.4, 0.0, 0.0))
	return disc_screen.distance_to(screen_position) <= maxf(disc_screen.distance_to(edge), 110.0)


func _board_point(screen_position: Vector2) -> Vector3:
	if green == null:
		return disc.global_position
	var cam: Camera3D = green.view_camera()
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


func _sync_fan() -> void:
	if gesture == null or fan == null or disc == null or green == null:
		return
	var cam: Camera3D = green.view_camera()
	if cam == null:
		return
	gesture.camera = cam
	var placed := Vector3(place_x, disc.global_position.y, line_z)
	gesture.anchor = placed
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
			ui.show_drag(disc.reach_for(power), false)
			ui.set_power_ratio(power)
		else:
			disc.global_position = placed
			disc.preview_take(Vector3(0.0, 0.0, -1.0), 0.0)
	var live_pos: Vector3 = disc.global_position
	var bowl_px := cam.unproject_position(live_pos + Vector3(0.0, 0.16, 0.0))
	var centre := cam.unproject_position(live_pos)
	fan.present(bowl_px, power, 0.0, false, -PI * 0.5, 120.0)
	if cue != null and cue_kind != 3:
		if pulling:
			cue.present(disc.grass_cue(power), power, disc.aim_direction)
		else:
			cue.clear()
	elif cue != null:
		cue.clear()
	fan.set_cue(PackedVector2Array(), PackedFloat32Array(), false)
	fan.set_aim(Vector2.ZERO, Vector2.ZERO, false)
	fan.set_line(Vector2.ZERO, Vector2.ZERO, false)
	fan.set_disc(bowl_px, false)
	fan.set_bowl(centre, 28.0)
	fan.set_finger(gesture.finger, pulling)


func _crazytest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	_dump("crazy_hero_tee")
	if green != null:
		green.pose_lock = true
		var cam: Camera3D = green.view_camera()
		if cam != null:
			cam.current = true
			cam.position = Vector3(1.2, 16.0, 7.5)
			cam.look_at(Vector3(0.6, 0.0, -15.0), Vector3.UP)
			cam.fov = 46.0
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump("crazy_hero_overview")
	if green != null:
		var cup_cam: Camera3D = green.view_camera()
		if cup_cam != null:
			cup_cam.position = Vector3(green.cup.x + 2.6, 5.4, green.cup.z + 2.8)
			cup_cam.look_at(Vector3(green.cup.x, 0.04, green.cup.z), Vector3.UP)
			cup_cam.fov = 34.0
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump("crazy_hero_cup")
	if green != null:
		var water_cam: Camera3D = green.view_camera()
		if water_cam != null:
			var pond_at := Vector3(3.85, 0.0, -14.8)
			if green.water_spots.size() > 0:
				pond_at = green.water_spots[0]["pos"]
			water_cam.position = pond_at + Vector3(-2.2, 4.4, 3.4)
			water_cam.look_at(pond_at + Vector3(0.0, 0.08, 0.0), Vector3.UP)
			water_cam.fov = 42.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump("crazy_hero_water")
	if green != null:
		green.pose_lock = false
		green.reset_view()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump("crazy_hole1")
	disc.fire_taken(Vector3(-0.18, 0.0, -1.0), 0.78)
	var waited := 0.0
	while disc.shot_in_progress and waited < 14.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await RenderingServer.frame_post_draw
	_dump("crazy_hole1_rest")
	print("CRAZYTEST done")
	get_tree().quit(0)


func _dump(name: String) -> void:
	var tex: Texture2D = get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	img.save_png("/opt/cursor/artifacts/%s.png" % name)
	print("CRAZY_SHOT %s" % name)
