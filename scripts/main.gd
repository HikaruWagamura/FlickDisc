extends Node

## Bowl & Roll. The club menu is home. Crock & Hole and the long green are the two tables.

const CROKINOLE_SCENE := preload("res://scenes/Crokinole.tscn")
const LAWN_SCENE := preload("res://scenes/Lawn.tscn")
const CRAZY_SCENE := preload("res://scenes/CrazyBowls.tscn")
const MenuScript := preload("res://scripts/flickdisc_menu.gd")
const ProfileScript := preload("res://scripts/flickdisc_profile.gd")
const Kit := preload("res://scripts/kit.gd")

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
	call_deferred("_apply_host")


func _apply_host() -> void:
	if OS.get_cmdline_user_args().has("--menutest"):
		_menutest()
		return
	if OS.get_cmdline_user_args().has("--crazytest"):
		_play({"rink": "crazy", "back": "home"})
		return
	if OS.get_cmdline_user_args().has("--crokshot") or OS.get_cmdline_user_args().has("--crokrules"):
		_play({"rink": "crokinole", "back": "home", "level": 0})
		return
	if OS.get_cmdline_user_args().has("--graphtest") or OS.get_cmdline_user_args().has("--cuetest") or OS.get_cmdline_user_args().has("--pulltest"):
		_play({"rink": "lawn", "ditch": true, "back": "home", "match_index": 1, "opponent": "local"})
		return
	if OS.get_cmdline_user_args().has("--livetest"):
		_play({
			"rink": "lawn",
			"live": true,
			"live_host": true,
			"opponent": "ai",
			"rival": "Vesper",
			"difficulty": 1,
			"ditch": true,
			"back": "home",
			"match_index": 1,
		})
		return
	if OS.has_feature("web"):
		menu.rink = "lawn"
		menu.open_screen("setup")
		print("HOST_SETUP rink=lawn")
		return
	var host := _host_launch()
	if bool(host["play"]):
		_play({
			"rink": host["rink"],
			"match_index": host["match_index"],
			"back": "home",
			"goal": "",
			"target": 100,
			"level": 0,
			"ditch": true,
		})
		print("HOST_PLAY rink=%s" % str(host["rink"]))
		return
	if bool(host["direct"]):
		menu.rink = str(host["rink"])
		menu.open_screen("setup")
		print("HOST_SETUP rink=%s" % str(host["rink"]))


func _host_launch() -> Dictionary:
	var table := ""
	var embed := false
	var play_now := false
	var match_index := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--table="):
			table = arg.trim_prefix("--table=")
		elif arg == "--embed" or arg == "--embed=1":
			embed = true
		elif arg == "--play":
			play_now = true
		elif arg.begins_with("--match="):
			match_index = int(arg.trim_prefix("--match="))
	var rink_name := table if table != "" else "lawn"
	if rink_name != "lawn" and rink_name != "crokinole" and rink_name != "crazy":
		rink_name = "lawn"
	return {
		"direct": embed or table != "",
		"play": play_now,
		"rink": rink_name,
		"match_index": match_index,
	}


func _play(setup: Dictionary) -> void:
	_close_game()
	return_screen = str(setup.get("back", "home"))
	pending_challenge = str(setup.get("challenge", ""))
	profile.note_round()
	var rink_name := str(setup.get("rink", "lawn"))
	var packed: PackedScene = CROKINOLE_SCENE
	if rink_name == "crazy":
		packed = CRAZY_SCENE
	elif rink_name != "crokinole":
		packed = LAWN_SCENE
	current = packed.instantiate()
	if current.get("goal") != null:
		current.goal = str(setup.get("goal", ""))
	if rink_name == "crokinole":
		current.match_target = 4
		current.start_level = int(setup.get("level", 0))
		current.set_meta("flickdisc_kit", profile.kit())
	elif rink_name == "lawn":
		current.match_index = int(setup.get("match_index", 1))
		current.opponent = str(setup.get("opponent", "local"))
		current.difficulty = int(setup.get("difficulty", 1))
		current.ditch_mode = bool(setup.get("ditch", true))
		current.cue_kind = int(setup.get("guide", 0))
		current.distance_play = bool(setup.get("distance", false))
		current.solo_play = bool(setup.get("solo", false))
		current.live_play = bool(setup.get("live", false))
		current.live_host = bool(setup.get("live_host", true))
		if current.get("live_rival") != null:
			current.live_rival = str(setup.get("rival", ""))
	get_tree().root.set_meta("flickdisc_sound", profile.sound)
	get_tree().root.set_meta("flickdisc_haptics", profile.haptics)
	get_tree().root.set_meta("flickdisc_kit", profile.kit())
	menu.set_open(false)
	add_child(current)
	if current.has_signal("goal_cleared"):
		current.goal_cleared.connect(_on_goal)
	if current.has_signal("match_decided"):
		current.match_decided.connect(_on_match)
	if current.has_signal("tally_drive"):
		current.tally_drive.connect(_on_drive)
	if current.has_signal("tally_solo"):
		current.tally_solo.connect(_on_solo)
	if current.has_signal("tally_crazy"):
		current.tally_crazy.connect(_on_crazy)
	var ui := current.get_node_or_null("UI")
	if ui != null and ui.has_signal("leave_requested"):
		ui.leave_requested.connect(_leave)


func _menutest() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_splash")
	menu.open_screen("home")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_home")
	DisplayServer.window_set_size(Vector2i(540, 1170))
	await get_tree().process_frame
	await get_tree().process_frame
	if menu.has_method("_layout_shell"):
		menu._layout_shell()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_home_tall")
	if menu.has_method("_launch_live"):
		menu._launch_live()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_dump_menu("menu_live_search")
		await get_tree().create_timer(0.45).timeout
		await RenderingServer.frame_post_draw
		_dump_menu("menu_live_reel")
		if menu.has_method("_lock_live_rival"):
			menu._lock_live_rival(false, "Vesper", {"name": "Vesper", "mark": "VE", "skill": 1, "color": 2}, false)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_dump_menu("menu_live_matched")
		if menu.has_method("_cancel_live_search"):
			menu._cancel_live_search()
		elif menu.live_layer != null:
			menu.live_layer.visible = false
			if menu.live_net != null:
				menu.live_net.stop_search()
	DisplayServer.window_set_size(Vector2i(540, 960))
	await get_tree().process_frame
	if menu.has_method("_layout_shell"):
		menu._layout_shell()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	menu.open_screen("profile")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_profile")
	if menu.has_method("_open_face_sheet"):
		menu._open_face_sheet()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_dump_menu("menu_face")
		if menu.face_layer != null:
			menu.face_layer.visible = false
	menu.open_screen("shop")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_shop")
	menu.open_screen("settings")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_settings")
	menu.open_screen("customise")
	if menu.studio != null and menu.studio.has_method("set_coverage"):
		menu.studio.set_coverage("whole")
		menu._pick_skin("both")
		menu._pick_swatch(1)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_kit")
	menu._pick_skin("camo")
	menu._pick_swatch(6)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_kit_camo")
	if menu.studio != null and menu.studio.has_method("set_coverage"):
		menu.studio.set_coverage("half")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_dump_menu("menu_kit_half")
		menu._pick_skin("metal")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_dump_menu("menu_kit_half_metal")
		menu.studio.set_coverage("whole")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_dump_menu("menu_kit_whole")
		menu._pick_skin("marble")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_dump_menu("menu_kit_marble")
	menu._pick_skin("arctic")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_kit_arctic")
	Kit.seed_demo_photos()
	menu._pick_skin("photo_split")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_kit_photo")
	if menu.studio != null:
		menu.studio.demo_paint()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_dump_menu("menu_studio")
		menu.studio.pick_place("right")
		menu.studio.apply_photo(Kit._demo_face())
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_dump_menu("menu_studio_photo")
		menu.studio.pick_place("split")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_dump_menu("menu_studio_split")
		var kit_page := menu.pages["customise"] as Control
		if kit_page != null and kit_page.get_child_count() > 0:
			var scroll := kit_page.get_child(0) as ScrollContainer
			if scroll != null:
				scroll.scroll_vertical = 560
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				_dump_menu("menu_studio_tools")
	menu._pick_skin("club")
	menu._pick_swatch(1)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_kit_club")
	menu.rink = "lawn"
	menu.open_screen("setup")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_setup")
	menu.rink = "crokinole"
	menu.open_screen("setup")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_setup_board")
	menu.rink = "lawn"
	menu.open_screen("setup")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_dump_menu("menu_setup_after_board")
	print("MENUTEST done")
	get_tree().quit(0)


func _dump_menu(name: String) -> void:
	var tex: Texture2D = get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	img.save_png("/opt/cursor/artifacts/%s.png" % name)
	print("MENU_SHOT %s" % name)


func _leave() -> void:
	_close_game()
	menu.open_screen(return_screen)


func _on_goal() -> void:
	profile.clear_challenge(pending_challenge)


func _on_match(you_won: bool) -> void:
	if current != null and bool(current.get("live_play")):
		var rival := str(current.get("live_rival"))
		if rival == "":
			rival = "Club AI" if str(current.get("opponent")) == "ai" else "a live player"
		profile.record_live(you_won, rival)
	else:
		profile.record_match(you_won)


func _on_drive(metres: float, miss: float) -> void:
	profile.note_drive(metres, miss)


func _on_solo(end_number: int) -> void:
	profile.note_solo(end_number)


func _on_crazy(strokes: int, par: int) -> void:
	profile.note_crazy(strokes, par)


func _close_game() -> void:
	get_tree().paused = false
	if current == null:
		return
	var old_camera := current.find_child("Camera3D", true, false) as Camera3D
	if old_camera != null:
		old_camera.current = false
	current.queue_free()
	current = null
