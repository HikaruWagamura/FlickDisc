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
var current_level_index := 0
var current_level: Dictionary
var jack_home := Vector3.ZERO
var throws_left := 3
var throw_index := 0
var shot_token := 0


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
	_lock_portrait_on_device()
	_load_level(0)


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


func _unhandled_input(event: InputEvent) -> void:
	# On a phone, Godot also synthesizes mouse events from touches. Handling
	# both would start and release the same shot twice.
	if feel != null:
		feel.unlock()
	var on_device := OS.has_feature("android") or OS.has_feature("ios")
	if on_device and event is InputEventScreenTouch:
		if event.pressed:
			disc.begin_aim(event.position)
		else:
			disc.release_aim(event.position)
	elif on_device and event is InputEventScreenDrag:
		disc.update_aim(event.position)
	elif not on_device and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			disc.begin_aim(event.position)
		else:
			disc.release_aim(event.position)
	elif not on_device and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		disc.update_aim(event.position)


func _load_level(level_index: int) -> void:
	shot_token += 1
	current_level_index = clampi(level_index, 0, level_manager.get_level_count() - 1)
	current_level = level_manager.get_level(current_level_index)
	var jack_xz: Vector2 = current_level["jack_position"]
	jack_home = Vector3(jack_xz.x, 0.0, jack_xz.y)
	rink.place_head(jack_xz)
	_clear_settled()
	jack.rest_at(jack_home)
	throws_left = current_level["throws"]
	throw_index = 0
	score_manager.reset()
	disc.start_position = Vector3(0.0, 0.0, RinkScript.DISC_Z)
	disc.set_green(
		Vector2(-RinkScript.HALF_WIDTH, RinkScript.FAR_Z),
		Vector2(RinkScript.HALF_WIDTH, RinkScript.NEAR_Z - 0.2)
	)
	disc.obstacles = _table()
	disc.set_palette(0)
	disc.reset_to_start()
	ui.set_power_ratio(0.0)
	ui.show_ready(current_level["number"], throws_left, str(current_level["difficulty"]))


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
	if power_ratio > 0.0:
		ui.show_aiming(power_ratio)


func _on_disc_bias_changed(bias_ratio: float) -> void:
	ui.show_bias(bias_ratio)


func _on_bias_cycle_requested() -> void:
	feel.tap()
	disc.cycle_bias()


func _on_disc_shot_started() -> void:
	throws_left -= 1
	ui.set_power_ratio(0.0)
	ui.show_in_motion(throws_left)
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
	var thrown = BowlScript.new()
	thrown.name = "Bowl%d" % (throw_index + 1)
	thrown.setup_disc(disc.palette_index)
	add_child(thrown)
	thrown.rest_at(rest_pos)
	thrown.spin_angle = disc.spin_angle
	thrown.present(0.0)
	settled.append(thrown)
	throw_index += 1
	disc.reset_to_start()
	disc.set_palette(throw_index)
	disc.obstacles = _table()
	var jack_pos: Vector3 = jack.global_position
	var distances: Array[float] = []
	for body in settled:
		distances.append(_distance(body.global_position, jack_pos))
	score_manager.set_table(distances)
	var disc_distance := _distance(rest_pos, jack_pos)
	var closest: float = score_manager.get_closest_distance()
	var jack_moved: bool = jack_pos.distance_to(jack_home) > 0.2
	feel.settled(closest)
	ui.set_power_ratio(0.0)
	if throws_left > 0:
		ui.show_throw_result(disc_distance, closest, throws_left, jack_moved)
	else:
		disc.visible = false
		ui.show_level_complete(
			score_manager.get_score(),
			closest,
			current_level_index < level_manager.get_level_count() - 1,
			jack_moved
		)


func _distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _on_reset_requested() -> void:
	feel.tap()
	_load_level(current_level_index)


func _on_next_level_requested() -> void:
	feel.tap()
	if current_level_index < level_manager.get_level_count() - 1:
		_load_level(current_level_index + 1)
