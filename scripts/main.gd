extends Node

## FlickDisc. The club menu is home. Crokinmode and the long rink are the two tables.

const CROKINOLE_SCENE := preload("res://scenes/Crokinole.tscn")
const LAWN_SCENE := preload("res://scenes/Lawn.tscn")
const MenuScript := preload("res://scripts/flickdisc_menu.gd")
const ProfileScript := preload("res://scripts/flickdisc_profile.gd")

var profile
var menu
var current: Node = null
var return_screen := "home"
var pending_challenge := ""


func _ready() -> void:
	profile = ProfileScript.new()
	profile.load_profile()
	get_tree().root.set_meta("flickdisc_sound", profile.sound)
	get_tree().root.set_meta("flickdisc_haptics", profile.haptics)
	menu = MenuScript.new()
	menu.name = "Menu"
	add_child(menu)
	menu.play_requested.connect(_play)
	menu.setup(profile)


func _play(setup: Dictionary) -> void:
	_close_game()
	return_screen = str(setup.get("back", "home"))
	pending_challenge = str(setup.get("challenge", ""))
	profile.note_round()
	var rink_name := str(setup.get("rink", "crokinole"))
	var packed: PackedScene = CROKINOLE_SCENE if rink_name == "crokinole" else LAWN_SCENE
	current = packed.instantiate()
	current.goal = str(setup.get("goal", ""))
	if rink_name == "crokinole":
		current.match_target = int(setup.get("target", 100))
		current.start_level = int(setup.get("level", 0))
		current.player_tint = profile.disc_color()
	else:
		current.match_index = int(setup.get("match_index", 1))
		current.ditch_mode = bool(setup.get("ditch", false))
	get_tree().root.set_meta("flickdisc_sound", profile.sound)
	get_tree().root.set_meta("flickdisc_haptics", profile.haptics)
	menu.set_open(false)
	add_child(current)
	if current.has_signal("goal_cleared"):
		current.goal_cleared.connect(_on_goal)
	if current.has_signal("match_decided"):
		current.match_decided.connect(_on_match)
	var ui := current.get_node_or_null("UI")
	if ui != null and ui.has_signal("leave_requested"):
		ui.leave_requested.connect(_leave)


func _leave() -> void:
	_close_game()
	menu.open_screen(return_screen)


func _on_goal() -> void:
	profile.clear_challenge(pending_challenge)


func _on_match(you_won: bool) -> void:
	profile.record_match(you_won)


func _close_game() -> void:
	if current == null:
		return
	var old_camera := current.find_child("Camera3D", true, false) as Camera3D
	if old_camera != null:
		old_camera.current = false
	current.queue_free()
	current = null
