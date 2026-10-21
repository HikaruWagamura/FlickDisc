extends Node3D

const RinkScript := preload("res://scripts/rink_view.gd")
const DiscScript := preload("res://scripts/disc_controller.gd")
const LevelScript := preload("res://scripts/level_manager.gd")
const ScoreScript := preload("res://scripts/score_manager.gd")

var disc
var ui
var rink
var level_manager
var score_manager
var current_level_index := 0
var current_level: Dictionary
var jack_position := Vector3.ZERO
var throws_left := 3


func _ready() -> void:
	ui = get_node("UI")
	level_manager = LevelScript.new()
	score_manager = ScoreScript.new()
	add_child(level_manager)
	add_child(score_manager)

	rink = RinkScript.new()
	rink.name = "Rink"
	add_child(rink)

	disc = DiscScript.new()
	disc.name = "PlayerDisc"
	add_child(disc)

	disc.aim_changed.connect(_on_disc_aim_changed)
	disc.bias_changed.connect(_on_disc_bias_changed)
	disc.shot_started.connect(_on_disc_shot_started)
	disc.shot_stopped.connect(_on_disc_shot_stopped)
	ui.reset_requested.connect(_on_reset_requested)
	ui.next_level_requested.connect(_on_next_level_requested)
	ui.bias_cycle_requested.connect(_on_bias_cycle_requested)
	_lock_portrait_on_device()
	_load_level(0)


func _lock_portrait_on_device() -> void:
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)


func _unhandled_input(event: InputEvent) -> void:
	# On a phone, Godot also synthesizes mouse events from touches. Handling
	# both would start and release the same shot twice.
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
	current_level_index = clampi(level_index, 0, level_manager.get_level_count() - 1)
	current_level = level_manager.get_level(current_level_index)
	var jack_xz: Vector2 = current_level["jack_position"]
	jack_position = Vector3(jack_xz.x, 0.0, jack_xz.y)
	rink.place_head(jack_xz)
	throws_left = current_level["throws"]
	score_manager.reset()
	disc.start_position = Vector3(0.0, 0.0, RinkScript.DISC_Z)
	disc.set_rink_bounds(
		Vector2(-RinkScript.HALF_WIDTH, RinkScript.FAR_Z),
		Vector2(RinkScript.HALF_WIDTH, RinkScript.NEAR_Z - 0.2)
	)
	disc.reset_to_start()
	ui.set_power_ratio(0.0)
	ui.show_ready(current_level["number"], throws_left, str(current_level["difficulty"]))


func _on_disc_aim_changed(_direction: Vector2, power_ratio: float) -> void:
	ui.set_power_ratio(power_ratio)
	if power_ratio > 0.0:
		ui.show_aiming(power_ratio)


func _on_disc_bias_changed(bias_ratio: float) -> void:
	ui.show_bias(bias_ratio)


func _on_bias_cycle_requested() -> void:
	disc.cycle_bias()


func _on_disc_shot_started() -> void:
	throws_left -= 1
	ui.set_power_ratio(0.0)
	ui.show_in_motion(throws_left)


func _on_disc_shot_stopped() -> void:
	ui.set_power_ratio(0.0)
	var flat_disc := Vector2(disc.global_position.x, disc.global_position.z)
	var flat_jack := Vector2(jack_position.x, jack_position.z)
	var distance := flat_disc.distance_to(flat_jack)
	score_manager.record_throw(distance)
	if throws_left > 0:
		disc.reset_to_start()
		ui.show_throw_result(distance, throws_left)
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
