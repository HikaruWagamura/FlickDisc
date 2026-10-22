extends CanvasLayer

## FlickDisc club. Splash, home, and the Classic 1v1 table select in front of the two rinks.

signal play_requested(setup: Dictionary)

const PINK := Color("#ff3d8a")
const PINK_DEEP := Color("#e21862")
const INK := Color("#09080d")
const CARD := Color(0.075, 0.05, 0.075, 0.94)
const MUTED := Color("#cbbcc6")
const CREAM := Color("#f6f3f7")

var profile
var root: Control
var backdrop: Control
var pages := {}
var screen := ""
var kind := "classic"
var rink := "crokinole"
var difficulty := 1
var race := 1
var room_code := ""
var splash_token := 0
var toast_token := 0
var online_channel := "casual"
var choice_pick := Callable()

var title_font: Font
var script_font: Font
var body_font: Font
var bold_font: Font
var logo_tex: Texture2D

var home_name: Label
var home_level: Label
var home_letter: Label
var home_record: Label
var home_xp: ColorRect
var chip_wins: Label
var chip_losses: Label
var title_label: Label
var sub_label: Label
var hint_label: Label
var difficulty_button: Button
var race_button: Button
var big_play: Button
var online_box: Control
var duo_note: Label
var crokin_card: Button
var lawn_card: Button
var crokin_tag: Label
var lawn_tag: Label
var code_label: Label
var join_edit: LineEdit
var name_edit: LineEdit
var sound_button: Button
var haptic_button: Button
var profile_letter: Label
var profile_name: Label
var profile_level: Label
var profile_record: Label
var profile_rounds: Label
var profile_disc: Label
var profile_xp: ColorRect
var rank_name: Label
var rank_record: Label
var friend_code: Label
var nav: Control
var nav_icons: Array = []
var nav_captions: Array = []
var choice_layer: Control
var choice_box: VBoxContainer
var online_layer: Control
var online_title: Label
var online_body: Label
var toast: Control
var toast_label: Label
var splash_bar: ColorRect
var challenge_trails := {}
var swatch_buttons: Array = []


func setup(player_profile) -> void:
	profile = player_profile
	room_code = _make_code()
	_prepare_fonts()
	logo_tex = _logo_texture()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	root.theme = theme
	add_child(root)
	backdrop = preload("res://scripts/flickdisc_backdrop.gd").new()
	root.add_child(backdrop)
	_build_splash()
	_build_home()
	_build_setup()
	_build_simple_pages()
	_build_nav()
	_build_choice_layer()
	_build_online_layer()
	_build_toast()
	_show("splash")


func set_open(is_open: bool) -> void:
	root.visible = is_open


func open_screen(screen_name: String) -> void:
	root.visible = true
	_show(screen_name)
	refresh()


func refresh() -> void:
	_sync_identity()
	_paint_swatches()
	_paint_challenges()
	_sync_settings()
	if code_label != null:
		code_label.text = room_code
	if friend_code != null:
		friend_code.text = room_code


func _prepare_fonts() -> void:
	title_font = _load_font("res://assets/fonts/Anton-Regular.ttf", 700, false)
	script_font = _load_font("res://assets/fonts/Pacifico-Regular.ttf", 700, true)
	body_font = _load_font("res://assets/fonts/Inter-Regular.ttf", 500, false)
	bold_font = _load_font("res://assets/fonts/Inter-Bold.ttf", 700, false)


func _load_font(path: String, weight: int, italic: bool) -> Font:
	var dynamic := FontFile.new()
	var loaded := false
	if dynamic.has_method("load_dynamic_font"):
		loaded = int(dynamic.call("load_dynamic_font", path)) == OK
	if loaded:
		return dynamic
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Inter"])
	system.font_weight = weight
	system.font_italic = italic
	return system


func _logo_texture() -> Texture2D:
	var image := Image.new()
	if image.load("res://assets/flickdisc_mark.png") != OK:
		return null
	return ImageTexture.create_from_image(image)


func _show(next: String) -> void:
	screen = next
	for key in pages.keys():
		var page := pages[key] as Control
		page.visible = str(key) == next
	var hub := next == "home" or next == "profile" or next == "customise" or next == "shop" or next == "settings"
	nav.visible = hub
	backdrop.visible = next != "splash"
	choice_layer.visible = false
	online_layer.visible = false
	_paint_nav(next)
	if next == "splash":
		_arm_splash()
	if next == "setup":
		_sync_setup()
	_sync_identity()


func _arm_splash() -> void:
	splash_token += 1
	var token := splash_token
	splash_bar.size = Vector2(0, 3)
	var tween := create_tween()
	tween.tween_property(splash_bar, "size:x", 540.0, 2.05)
	get_tree().create_timer(2.15).timeout.connect(func() -> void:
		if screen == "splash" and token == splash_token:
			_show("home")
	)


func _build_splash() -> void:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages["splash"] = page
	root.add_child(page)
	var black := ColorRect.new()
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color("#050507")
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(black)
	var hit := Button.new()
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.text = ""
	_paint_button(hit, Color(0, 0, 0, 0), Color(0, 0, 0, 0), CREAM, 0, 0)
	hit.pressed.connect(func() -> void:
		if screen == "splash":
			_show("home")
	)
	page.add_child(hit)
	var mark := _mark_rect()
	mark.position = Vector2(70, 230)
	mark.size = Vector2(400, 400)
	page.add_child(mark)
	var tag := _label("FLICK HARD. PLAY DIRTY.", 26, PINK, script_font)
	tag.position = Vector2(30, 660)
	tag.size = Vector2(480, 48)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(tag)
	splash_bar = ColorRect.new()
	splash_bar.position = Vector2(0, 0)
	splash_bar.size = Vector2(0, 3)
	splash_bar.color = Color("#4da3ff")
	splash_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(splash_bar)


func _build_home() -> void:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages["home"] = page
	root.add_child(page)

	var pill := Button.new()
	_place(page, pill, Vector2(16, 16), Vector2(250, 58))
	_paint_button(pill, Color(0.09, 0.05, 0.1, 0.94), PINK, CREAM, 28, 12)
	pill.pressed.connect(_show.bind("profile"))
	var avatar := Panel.new()
	avatar.position = Vector2(8, 10)
	avatar.size = Vector2(38, 38)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_theme_stylebox_override("panel", _flat(PINK, PINK, 0, 19, 0))
	pill.add_child(avatar)
	home_letter = _label("F", 18, Color("#1a0a12"), bold_font)
	home_letter.position = Vector2(8, 16)
	home_letter.size = Vector2(38, 26)
	home_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(home_letter)
	home_name = _label("Flicker", 16, CREAM, bold_font)
	home_name.position = Vector2(54, 8)
	home_name.size = Vector2(180, 22)
	pill.add_child(home_name)
	home_level = _label("Level 1", 12, PINK, bold_font)
	home_level.position = Vector2(54, 30)
	home_level.size = Vector2(180, 16)
	pill.add_child(home_level)
	var track := ColorRect.new()
	track.position = Vector2(54, 48)
	track.size = Vector2(150, 3)
	track.color = Color(1, 1, 1, 0.14)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(track)
	home_xp = ColorRect.new()
	home_xp.position = Vector2(54, 48)
	home_xp.size = Vector2(8, 3)
	home_xp.color = PINK
	home_xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(home_xp)

	chip_wins = _chip(page, Vector2(392, 26))
	chip_losses = _chip(page, Vector2(436, 26))
	var gear := _button("⚙", 18)
	_place(page, gear, Vector2(484, 24), Vector2(40, 40))
	_paint_button(gear, Color(0.09, 0.05, 0.1, 0.94), PINK, CREAM, 12, 0)
	gear.pressed.connect(_show.bind("settings"))

	var server := _label("SERVER ONLINE", 11, PINK, bold_font)
	_place(page, server, Vector2(20, 80), Vector2(220, 16))

	var mark := _mark_rect()
	_place(page, mark, Vector2(145, 100), Vector2(250, 250))

	var play := _button("PLAY", 22)
	_place(page, play, Vector2(20, 362), Vector2(500, 64))
	_paint_button(play, PINK_DEEP, Color("#ff8ab6"), CREAM, 18, 0)
	var play_mark := _label("▶", 18, CREAM, bold_font)
	play_mark.position = Vector2(430, 18)
	play_mark.size = Vector2(40, 28)
	play.add_child(play_mark)
	play.pressed.connect(_open_setup.bind("classic"))

	home_record = _label("0W  ·  0L", 15, Color("#a894a0"), bold_font)
	_place(page, home_record, Vector2(20, 434), Vector2(500, 22))
	home_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_home_card(page, Rect2(16, 468, 164, 124), "1", "CLASSIC 1V1", "Skill. Strategy.\nVictory.", "classic")
	_home_card(page, Rect2(188, 468, 164, 124), "2", "CLASSIC 2V2", "Team up.\nTake control.", "duo")
	_home_card(page, Rect2(360, 468, 164, 124), "⚡", "CHAOS MODE", "Power-ups.\nNo mercy.", "chaos")
	_home_card(page, Rect2(16, 604, 249, 112), "", "PRACTICE", "Improve your game", "practice")
	_home_card(page, Rect2(275, 604, 249, 112), "", "CHALLENGES", "Daily shots. Big rewards.", "challenges")
	_home_card(page, Rect2(16, 726, 249, 112), "", "FRIENDS", "Play with mates", "friends")
	_home_card(page, Rect2(275, 726, 249, 112), "", "RANKINGS", "Climb the leaderboard", "rankings")


func _home_card(page: Control, rect: Rect2, kicker: String, title: String, body: String, target: String) -> void:
	var button := Button.new()
	button.text = ""
	_place(page, button, rect.position, rect.size)
	_paint_button(button, CARD, Color(1, 0.28, 0.55, 0.9), CREAM, 16, 12)
	var y := 12.0
	if kicker != "":
		var kick := _label(kicker, 13, PINK, bold_font)
		kick.position = Vector2(12, 8)
		kick.size = Vector2(rect.size.x - 24, 18)
		button.add_child(kick)
		y = 30.0
	var heading := _label(title, 15, CREAM, bold_font)
	heading.position = Vector2(12, y)
	heading.size = Vector2(rect.size.x - 24, 36)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_child(heading)
	var detail := _label(body, 12, MUTED, body_font)
	detail.position = Vector2(12, y + 38)
	detail.size = Vector2(rect.size.x - 24, 40)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_child(detail)
	button.pressed.connect(func() -> void:
		if target == "classic" or target == "duo":
			_open_setup(target)
		else:
			_show(target)
	)


func _build_setup() -> void:
	var built: Dictionary = _column_page(72, 28)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["setup"] = page
	root.add_child(page)
	_back_on(page, "home")

	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, 156)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ghost := _mark_rect()
	ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
	ghost.modulate = Color(1, 1, 1, 0.32)
	hero.add_child(ghost)
	title_label = _label("CLASSIC 1V1", 42, CREAM, title_font)
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero.add_child(title_label)
	box.add_child(hero)

	sub_label = _label("FlickDisc classic. First to 100, net scoring.", 15, MUTED, body_font)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 142)
	crokin_card = _rink_card("CROKINMODE", "Classic round board")
	lawn_card = _rink_card("LONG RINK", "Bowls and curling style.\nAbout 10 seconds to the jack.")
	crokin_tag = crokin_card.get_node("Tag") as Label
	lawn_tag = lawn_card.get_node("Tag") as Label
	crokin_card.pressed.connect(func() -> void:
		rink = "crokinole"
		_sync_setup()
	)
	lawn_card.pressed.connect(func() -> void:
		rink = "lawn"
		_sync_setup()
	)
	row.add_child(crokin_card)
	row.add_child(lawn_card)
	box.add_child(row)
	box.add_child(_gap(8))

	hint_label = _label("The original round board and scoring rules.", 14, MUTED, body_font)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint_label)
	box.add_child(_kicker("AI DIFFICULTY"))
	difficulty_button = _choice_button()
	difficulty_button.pressed.connect(func() -> void:
		_open_choices(_difficulty_options(), difficulty, _set_difficulty)
	)
	box.add_child(difficulty_button)
	box.add_child(_kicker("RACE TO"))
	race_button = _choice_button()
	race_button.pressed.connect(func() -> void:
		_open_choices(_race_options(), race, _set_race)
	)
	box.add_child(race_button)
	box.add_child(_gap(6))
	big_play = _primary("PLAY VERSUS AI", func() -> void: _launch("ai"))
	box.add_child(big_play)

	duo_note = _label("Both teams play on this device. Pass the phone each shot.", 14, MUTED, body_font)
	duo_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	duo_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(duo_note)

	online_box = VBoxContainer.new()
	online_box.add_theme_constant_override("separation", 10)
	online_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	online_box.add_child(_row_button("Local match", func() -> void: _launch("local")))
	online_box.add_child(_row_button("Online casual", func() -> void: _show_online("casual")))
	online_box.add_child(_row_button("Online ranked", func() -> void: _show_online("ranked")))
	online_box.add_child(_row_button("Create private room", _create_room))
	online_box.add_child(_kicker("ROOM CODE"))
	online_box.add_child(_code_row())
	join_edit = LineEdit.new()
	join_edit.placeholder_text = "ROOM CODE"
	join_edit.max_length = 5
	join_edit.custom_minimum_size = Vector2(0, 52)
	_style_edit(join_edit)
	join_edit.text_changed.connect(func(value: String) -> void:
		var upper := value.to_upper()
		if upper != value:
			join_edit.text = upper
			join_edit.caret_column = upper.length()
	)
	online_box.add_child(join_edit)
	online_box.add_child(_primary("JOIN ROOM", _join_room))
	box.add_child(online_box)


func _build_simple_pages() -> void:
	_build_chaos()
	_build_practice()
	_build_challenges()
	_build_friends()
	_build_rankings()
	_build_profile()
	_build_customise()
	_build_shop()
	_build_settings()


func _build_chaos() -> void:
	var built: Dictionary = _column_page(72, 28)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["chaos"] = page
	root.add_child(page)
	_back_on(page, "home")
	box.add_child(_title("CHAOS MODE"))
	var blurb := _label("Power-ups. No mercy.\nThe chaos table is the round board, first to 50. The discs, the pegs, and the count-up are live. Power-ups come in a later build.", 15, MUTED, body_font)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(blurb)
	box.add_child(_wide_card("EXTRA DISC", "A ninth button is the first power-up on the list.", "NEXT"))
	box.add_child(_wide_card("HEAVY HOOK", "A shot that bends harder than a normal bias.", "NEXT"))
	box.add_child(_wide_card("OPEN HOLE", "The 20 is the shot everyone is hunting.", "NEXT"))
	box.add_child(_gap(8))
	box.add_child(_primary("PLAY THE ROUND BOARD", func() -> void:
		play_requested.emit({
			"rink": "crokinole",
			"target": 50,
			"level": 2,
			"match_index": 1,
			"ditch": false,
			"goal": "",
			"challenge": "",
			"back": "chaos",
			"channel": "chaos",
		})
	))


func _build_practice() -> void:
	var built: Dictionary = _column_page(72, 28)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["practice"] = page
	root.add_child(page)
	_back_on(page, "home")
	box.add_child(_title("PRACTICE"))
	box.add_child(_wrapped("Improve your game. These tables keep score, and nothing is on the line except the shot."))
	box.add_child(_wide_card("OPEN BOARD", "Crokinmode with a clear road to the hole.", "PLAY"))
	box.get_child(box.get_child_count() - 1).pressed.connect(_practice.bind("open"))
	box.add_child(_wide_card("PEG GUARD", "The far side is sitting on the pegs.", "PLAY"))
	box.get_child(box.get_child_count() - 1).pressed.connect(_practice.bind("guard"))
	box.add_child(_wide_card("DRAW TO THE JACK", "Long rink. Place the jack, then bowl.", "PLAY"))
	box.get_child(box.get_child_count() - 1).pressed.connect(_practice.bind("jack"))


func _build_challenges() -> void:
	var built: Dictionary = _column_page(72, 28)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["challenges"] = page
	root.add_child(page)
	_back_on(page, "home")
	box.add_child(_title("CHALLENGES"))
	box.add_child(_wrapped("Daily shots. Big rewards. Clear one and it stays on your profile."))
	_challenge_card(box, "hole", "HOLE SHOT", "Sink the 20 on the round board.", "+25 XP")
	_challenge_card(box, "fifteen", "RING FIFTEEN", "Land a disc in the 15 or better.", "+15 XP")
	_challenge_card(box, "draw", "DRAW THE JACK", "Finish a bowl within a metre of the jack.", "+20 XP")


func _challenge_card(box: VBoxContainer, ident: String, title: String, body: String, reward: String) -> void:
	var card := _wide_card(title, body, reward)
	challenge_trails[ident] = card.get_node("Trail")
	card.pressed.connect(_challenge.bind(ident))
	box.add_child(card)


func _build_friends() -> void:
	var built: Dictionary = _column_page(72, 28)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["friends"] = page
	root.add_child(page)
	_back_on(page, "home")
	box.add_child(_title("FRIENDS"))
	box.add_child(_wrapped("Play with mates on this device. Share the room code when a club server is connected."))
	box.add_child(_kicker("YOUR ROOM"))
	friend_code = _label(room_code, 36, CREAM, title_font)
	friend_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(friend_code)
	box.add_child(_row_button("Copy room code", _copy_code))
	box.add_child(_wrapped("No mates are stored on this device yet."))


func _build_rankings() -> void:
	var built: Dictionary = _column_page(72, 28)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["rankings"] = page
	root.add_child(page)
	_back_on(page, "home")
	box.add_child(_title("RANKINGS"))
	box.add_child(_wrapped("Climb the leaderboard. This board is the record on this device."))
	var row := _wide_card("1    FLICKER", "This device", "0W  0L")
	rank_name = row.get_node("Heading") as Label
	rank_record = row.get_node("Trail") as Label
	row.disabled = true
	box.add_child(row)


func _build_profile() -> void:
	var built: Dictionary = _column_page(24, 120)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["profile"] = page
	root.add_child(page)
	var avatar_row := CenterContainer.new()
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(96, 96)
	var disc := _flat(PINK, Color("#ffd0ea"), 2, 48, 0)
	avatar.add_theme_stylebox_override("panel", disc)
	profile_letter = _label("F", 36, Color("#1a0a12"), bold_font)
	profile_letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	profile_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(profile_letter)
	avatar_row.add_child(avatar)
	box.add_child(avatar_row)
	profile_name = _label("Flicker", 32, CREAM, title_font)
	profile_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(profile_name)
	profile_level = _label("Level 1", 16, PINK, bold_font)
	profile_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(profile_level)
	var bar_row := CenterContainer.new()
	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(220, 6)
	track.size = Vector2(220, 6)
	track.color = Color(1, 1, 1, 0.14)
	profile_xp = ColorRect.new()
	profile_xp.color = PINK
	profile_xp.size = Vector2(8, 6)
	track.add_child(profile_xp)
	bar_row.add_child(track)
	box.add_child(bar_row)
	profile_record = _label("0W  ·  0L", 22, CREAM, bold_font)
	profile_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(profile_record)
	profile_rounds = _label("0 rounds", 14, MUTED, body_font)
	profile_rounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(profile_rounds)
	profile_disc = _label("Disc  ·  Club pink", 14, MUTED, body_font)
	profile_disc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(profile_disc)
	box.add_child(_row_button("Change disc", _show.bind("customise")))
	box.add_child(_row_button("Settings", _show.bind("settings")))


func _build_customise() -> void:
	var built: Dictionary = _column_page(24, 120)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["customise"] = page
	root.add_child(page)
	box.add_child(_title("CUSTOMISE"))
	box.add_child(_wrapped("Your disc colour is the centre of every button you flick on the round board."))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in profile.COLORS.size():
		var swatch := Button.new()
		swatch.text = ""
		swatch.custom_minimum_size = Vector2(86, 86)
		swatch.pressed.connect(_pick_swatch.bind(i))
		swatch_buttons.append(swatch)
		grid.add_child(swatch)
	var center := CenterContainer.new()
	center.add_child(grid)
	box.add_child(center)
	_paint_swatches()


func _build_shop() -> void:
	var built: Dictionary = _column_page(24, 120)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["shop"] = page
	root.add_child(page)
	box.add_child(_title("SHOP"))
	box.add_child(_kicker("FLICK COINS    0"))
	box.add_child(_shop_row("Club pink disc", "OWNED", true))
	box.add_child(_shop_row("Ice rim", "LOCKED", false))
	box.add_child(_shop_row("Gold centre", "LOCKED", false))
	box.add_child(_shop_row("Lawn whites", "LOCKED", false))


func _build_settings() -> void:
	var built: Dictionary = _column_page(24, 120)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["settings"] = page
	root.add_child(page)
	box.add_child(_title("SETTINGS"))
	box.add_child(_kicker("PLAYER NAME"))
	name_edit = LineEdit.new()
	name_edit.text = profile.player_name
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(0, 52)
	_style_edit(name_edit)
	name_edit.text_changed.connect(_on_name_changed)
	box.add_child(name_edit)
	sound_button = _row_button("Sound on", _toggle_sound)
	haptic_button = _row_button("Haptics on", _toggle_haptics)
	box.add_child(sound_button)
	box.add_child(haptic_button)
	box.add_child(_kicker("HOW A ROUND WORKS"))
	box.add_child(_wrapped("Crokinmode. Eight discs. Both colours score. 20 is only the hole. 15, 10 and 5 need the disc clear of that line. A disc on the line scores the lower ring. The ditch is nothing. Only the difference is added. First to the race wins.\n\nLong rink. Deliver the jack, then four bowls. Choose the hand and the bias. Bowls inside two metres of the jack count. Banks rebound unless the ditch is open."))


func _build_nav() -> void:
	nav = Panel.new()
	nav.position = Vector2(0, 868)
	nav.size = Vector2(540, 92)
	nav.add_theme_stylebox_override("panel", _flat(Color("#0c0a10"), Color(1, 0.3, 0.55, 0.45), 1, 0, 0))
	root.add_child(nav)
	var row := HBoxContainer.new()
	row.position = Vector2(0, 8)
	row.size = Vector2(540, 80)
	row.add_theme_constant_override("separation", 0)
	nav.add_child(row)
	_nav_item(row, "home", "HOME")
	_nav_item(row, "profile", "PROFILE")
	_nav_item(row, "customise", "CUSTOMISE")
	_nav_item(row, "shop", "SHOP")
	_nav_item(row, "settings", "SETTINGS")


func _nav_item(row: HBoxContainer, ident: String, caption: String) -> void:
	var button := Button.new()
	button.text = ""
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 78)
	_paint_button(button, Color(0, 0, 0, 0), Color(0, 0, 0, 0), CREAM, 8, 0)
	var icon := Mark.new()
	icon.kind = ident
	icon.custom_minimum_size = Vector2(26, 26)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := _label(caption, 10, MUTED, bold_font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	box.add_child(icon)
	box.add_child(label)
	button.add_child(box)
	button.pressed.connect(_show.bind(ident))
	row.add_child(button)
	nav_icons.append(icon)
	nav_captions.append(label)


func _build_choice_layer() -> void:
	choice_layer = Control.new()
	choice_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_layer.visible = false
	root.add_child(choice_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			choice_layer.visible = false
	)
	choice_layer.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(36, 280)
	panel.size = Vector2(468, 280)
	panel.add_theme_stylebox_override("panel", _flat(Color("#120c14"), PINK, 2, 18, 16))
	choice_layer.add_child(panel)
	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(16, 16)
	choice_box.size = Vector2(436, 248)
	choice_box.add_theme_constant_override("separation", 8)
	panel.add_child(choice_box)


func _build_online_layer() -> void:
	online_layer = Control.new()
	online_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	online_layer.visible = false
	root.add_child(online_layer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.72)
	online_layer.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(30, 300)
	panel.size = Vector2(480, 300)
	panel.add_theme_stylebox_override("panel", _flat(Color("#120c14"), PINK, 2, 18, 16))
	online_layer.add_child(panel)
	online_title = _label("ONLINE CASUAL", 28, CREAM, title_font)
	online_title.position = Vector2(20, 18)
	online_title.size = Vector2(440, 40)
	panel.add_child(online_title)
	online_body = _label("", 15, MUTED, body_font)
	online_body.position = Vector2(20, 68)
	online_body.size = Vector2(440, 90)
	online_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(online_body)
	var play_here := _primary("PLAY ON THIS DEVICE", func() -> void:
		online_layer.visible = false
		_launch(online_channel)
	)
	play_here.position = Vector2(20, 170)
	play_here.size = Vector2(440, 58)
	panel.add_child(play_here)
	var back := _row_button("Back", func() -> void: online_layer.visible = false)
	back.position = Vector2(20, 236)
	back.size = Vector2(440, 48)
	panel.add_child(back)


func _build_toast() -> void:
	toast = Panel.new()
	toast.position = Vector2(40, 800)
	toast.size = Vector2(460, 48)
	toast.visible = false
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_theme_stylebox_override("panel", _flat(Color("#1a1020"), PINK, 1, 14, 12))
	root.add_child(toast)
	toast_label = _label("", 14, CREAM, bold_font)
	toast_label.position = Vector2(12, 8)
	toast_label.size = Vector2(436, 32)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_child(toast_label)


func _open_setup(next_kind: String) -> void:
	kind = next_kind
	_show("setup")


func _sync_setup() -> void:
	if title_label == null:
		return
	var classic := kind == "classic"
	title_label.text = "CLASSIC 1V1" if classic else "CLASSIC 2V2"
	sub_label.text = "FlickDisc classic. First to 100, net scoring." if classic else "Two teams on one phone. Pass it each shot."
	big_play.text = "PLAY VERSUS AI" if classic else "PLAY LOCAL"
	online_box.visible = classic
	duo_note.visible = not classic
	hint_label.text = "The original round board and scoring rules." if rink == "crokinole" else "Bowls and curling style. About 10 seconds to the jack."
	difficulty_button.text = _difficulty_options()[difficulty]
	race_button.text = _race_options()[race]
	_paint_rinks()
	if code_label != null:
		code_label.text = room_code
	if join_edit != null and join_edit.text == "":
		join_edit.text = room_code


func _paint_rinks() -> void:
	_paint_choice_card(crokin_card, crokin_tag, rink == "crokinole")
	_paint_choice_card(lawn_card, lawn_tag, rink == "lawn")


func _paint_choice_card(card: Button, tag: Label, selected: bool) -> void:
	var border := PINK if selected else Color(1, 0.28, 0.55, 0.55)
	var width := 2 if selected else 1
	_paint_button(card, CARD, border, CREAM, 16, 12, width)
	tag.visible = selected


func _difficulty_options() -> PackedStringArray:
	if rink == "lawn":
		return PackedStringArray(["Easy — a gentle draw", "Medium — takes the obvious shot", "Hard — ditch is open"])
	return PackedStringArray(["Easy — leaves a gap", "Medium — takes the obvious shot", "Hard — guards the hole"])


func _race_options() -> PackedStringArray:
	if rink == "lawn":
		return PackedStringArray(["Quick — 2 ends", "Standard — 4 ends", "Long — first to 21"])
	return PackedStringArray(["Quick — first to 50", "Standard — first to 100", "Long — first to 150"])


func _set_difficulty(index: int) -> void:
	difficulty = index
	_sync_setup()


func _set_race(index: int) -> void:
	race = index
	_sync_setup()


func _open_choices(options: PackedStringArray, current: int, pick: Callable) -> void:
	choice_pick = pick
	for child in choice_box.get_children():
		child.queue_free()
	for i in options.size():
		var option := _row_button(options[i], _pick_choice.bind(i))
		if i == current:
			_paint_button(option, PINK_DEEP, Color("#ff8ab6"), CREAM, 12, 12)
		choice_box.add_child(option)
	choice_layer.visible = true


func _pick_choice(index: int) -> void:
	choice_layer.visible = false
	if choice_pick.is_valid():
		choice_pick.call(index)


func _show_online(channel: String) -> void:
	online_channel = channel
	if channel == "ranked":
		online_title.text = "ONLINE RANKED"
		online_body.text = "Ranked rooms need a club server. Play this setup on this device and a win still lands on your record."
	else:
		online_title.text = "ONLINE CASUAL"
		online_body.text = "Casual matchmaking needs a club server. This device can play the same Crokinmode or long rink now."
	online_layer.visible = true


func _launch(channel: String) -> void:
	var setup := {
		"channel": channel,
		"back": "setup",
		"rink": rink,
		"goal": "",
		"challenge": "",
		"ditch": false,
		"level": 0,
		"target": 100,
		"match_index": 1,
	}
	if rink == "lawn":
		setup["match_index"] = [0, 1, 4][race]
		setup["ditch"] = difficulty == 2
	else:
		setup["target"] = [50, 100, 150][race]
		setup["level"] = [0, 1, 4][difficulty]
	play_requested.emit(setup)


func _practice(which: String) -> void:
	var setup := {
		"channel": "practice",
		"back": "practice",
		"goal": "",
		"challenge": "",
		"ditch": false,
		"match_index": 0,
		"target": 100,
		"level": 0,
		"rink": "crokinole",
	}
	if which == "guard":
		setup["level"] = 1
	elif which == "jack":
		setup["rink"] = "lawn"
		setup["match_index"] = 0
	play_requested.emit(setup)


func _challenge(ident: String) -> void:
	var setup := {
		"channel": "challenge",
		"back": "challenges",
		"goal": ident,
		"challenge": ident,
		"ditch": false,
		"match_index": 0,
		"target": 100,
		"level": 0,
		"rink": "crokinole",
	}
	if ident == "draw":
		setup["rink"] = "lawn"
		setup["goal"] = "draw"
	play_requested.emit(setup)


func _create_room() -> void:
	room_code = _make_code()
	if code_label != null:
		code_label.text = room_code
	if friend_code != null:
		friend_code.text = room_code
	if join_edit != null:
		join_edit.text = room_code
	_toast("Room %s is open on this device." % room_code)


func _join_room() -> void:
	var entered := join_edit.text.strip_edges().to_upper()
	if entered == "" or entered == room_code:
		_launch("room")
		return
	_toast("That room is not open on this device.")


func _copy_code() -> void:
	DisplayServer.clipboard_set(room_code)
	_toast("Copied %s" % room_code)


func _toast(message: String) -> void:
	toast_token += 1
	var token := toast_token
	toast_label.text = message
	toast.visible = true
	get_tree().create_timer(2.3).timeout.connect(func() -> void:
		if token == toast_token:
			toast.visible = false
	)


func _make_code() -> String:
	var alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for _i in 5:
		code += alphabet[randi() % alphabet.length()]
	return code


func _sync_identity() -> void:
	if profile == null or home_name == null:
		return
	var initial := _initial()
	home_name.text = profile.player_name
	home_level.text = "Level %d" % profile.level()
	home_letter.text = initial
	home_record.text = profile.record_text()
	chip_wins.text = str(profile.wins)
	chip_losses.text = str(profile.losses)
	home_xp.size.x = 150.0 * profile.xp_ratio()
	if profile_name != null:
		profile_name.text = profile.player_name
		profile_level.text = "Level %d" % profile.level()
		profile_letter.text = initial
		profile_record.text = profile.record_text()
		profile_rounds.text = "%d rounds on this device" % profile.rounds
		profile_disc.text = "Disc  ·  %s" % profile.disc_name()
		profile_xp.size.x = 220.0 * profile.xp_ratio()
	if rank_name != null:
		rank_name.text = "1    %s" % profile.player_name.to_upper()
		rank_record.text = "%dW  %dL" % [profile.wins, profile.losses]


func _sync_settings() -> void:
	if sound_button != null:
		sound_button.text = "Sound on" if profile.sound else "Sound off"
	if haptic_button != null:
		haptic_button.text = "Haptics on" if profile.haptics else "Haptics off"
	if name_edit != null and not name_edit.has_focus():
		name_edit.text = profile.player_name


func _on_name_changed(value: String) -> void:
	var trimmed := value.strip_edges()
	if trimmed == "":
		return
	profile.player_name = trimmed.substr(0, 16)
	profile.save_profile()
	_sync_identity()


func _toggle_sound() -> void:
	profile.sound = not profile.sound
	profile.save_profile()
	get_tree().root.set_meta("flickdisc_sound", profile.sound)
	_sync_settings()


func _toggle_haptics() -> void:
	profile.haptics = not profile.haptics
	profile.save_profile()
	get_tree().root.set_meta("flickdisc_haptics", profile.haptics)
	_sync_settings()


func _pick_swatch(index: int) -> void:
	profile.disc_index = index
	profile.save_profile()
	_paint_swatches()
	_sync_identity()


func _paint_swatches() -> void:
	if profile == null:
		return
	for i in swatch_buttons.size():
		var swatch := swatch_buttons[i] as Button
		var selected: bool = int(profile.disc_index) == i
		var border := Color("#ffe4f4") if selected else Color(1, 1, 1, 0.18)
		_paint_button(swatch, profile.COLORS[i], border, CREAM, 40, 0, 3 if selected else 1)


func _paint_challenges() -> void:
	if profile == null:
		return
	var rewards := {"hole": "+25 XP", "fifteen": "+15 XP", "draw": "+20 XP"}
	for ident in challenge_trails.keys():
		var trail := challenge_trails[ident] as Label
		if profile.is_cleared(str(ident)):
			trail.text = "CLEARED"
			trail.add_theme_color_override("font_color", Color("#ffe27a"))
		else:
			trail.text = str(rewards[str(ident)])
			trail.add_theme_color_override("font_color", PINK)


func _paint_nav(current: String) -> void:
	for i in nav_icons.size():
		var icon: Mark = nav_icons[i]
		var caption := nav_captions[i] as Label
		var lit := icon.kind == current
		icon.set_lit(lit)
		caption.add_theme_color_override("font_color", PINK if lit else Color("#8d7d88"))


func _initial() -> String:
	var trimmed: String = str(profile.player_name).strip_edges()
	if trimmed == "":
		return "F"
	return trimmed.substr(0, 1).to_upper()


func _column_page(top: float, bottom: float) -> Dictionary:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", int(top))
	margin.add_theme_constant_override("margin_bottom", int(bottom))
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(508, 0)
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return {"page": page, "box": box}


func _back_on(page: Control, target: String) -> void:
	var shield := ColorRect.new()
	shield.position = Vector2(0, 0)
	shield.size = Vector2(540, 68)
	shield.color = Color(0.035, 0.031, 0.051, 0.96)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(shield)
	var button := _button("‹   Back", 15)
	button.position = Vector2(16, 16)
	button.size = Vector2(124, 40)
	_paint_button(button, Color(0.08, 0.05, 0.09, 0.94), PINK, CREAM, 18, 10)
	button.pressed.connect(_show.bind(target))
	page.add_child(button)


func _code_row() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color("#120c14"), PINK, 1, 14, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	code_label = _label(room_code, 28, CREAM, title_font)
	code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(code_label)
	var copy := _button("COPY", 14)
	copy.custom_minimum_size = Vector2(96, 44)
	_paint_button(copy, PINK_DEEP, Color("#ff8ab6"), CREAM, 12, 8)
	copy.pressed.connect(_copy_code)
	row.add_child(copy)
	panel.add_child(row)
	return panel


func _rink_card(title: String, body: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.custom_minimum_size = Vector2(150, 142)
	var tag := _label("SELECTED", 10, PINK, bold_font)
	tag.name = "Tag"
	tag.position = Vector2(12, 8)
	tag.size = Vector2(200, 16)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(tag)
	var heading := _label(title, 15, CREAM, bold_font)
	heading.position = Vector2(12, 28)
	heading.size = Vector2(210, 24)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(heading)
	var detail := _label(body, 12, MUTED, body_font)
	detail.position = Vector2(12, 54)
	detail.size = Vector2(210, 76)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(detail)
	return button


func _wide_card(title: String, body: String, trailing: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, 86)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_button(button, CARD, Color(1, 0.28, 0.55, 0.85), CREAM, 16, 14)
	var heading := _label(title, 16, CREAM, bold_font)
	heading.name = "Heading"
	heading.position = Vector2(14, 12)
	heading.size = Vector2(320, 24)
	button.add_child(heading)
	var detail := _label(body, 13, MUTED, body_font)
	detail.position = Vector2(14, 40)
	detail.size = Vector2(330, 36)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_child(detail)
	var trail := _label(trailing, 13, PINK, bold_font)
	trail.name = "Trail"
	trail.anchor_left = 1.0
	trail.anchor_right = 1.0
	trail.offset_left = -150.0
	trail.offset_right = -12.0
	trail.offset_top = 14.0
	trail.offset_bottom = 36.0
	trail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_child(trail)
	return button


func _shop_row(title: String, trailing: String, owned: bool) -> Button:
	var button := _wide_card(title, "Round-board colour", trailing)
	button.pressed.connect(func() -> void:
		if owned:
			_toast("Club pink is the disc you own.")
		else:
			_toast("Locked. Flick coins are not on this build.")
	)
	if not owned:
		button.modulate = Color(1, 1, 1, 0.78)
	return button


func _title(text: String) -> Label:
	var label := _label(text, 40, CREAM, title_font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _kicker(text: String) -> Label:
	return _label(text, 12, PINK, bold_font)


func _wrapped(text: String) -> Label:
	var label := _label(text, 15, MUTED, body_font)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _choice_button() -> Button:
	var button := _row_button("", Callable())
	return button


func _row_button(text: String, on_press: Callable) -> Button:
	var button := _button(text, 16)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_button(button, Color("#120c14"), Color(1, 0.28, 0.55, 0.85), CREAM, 14, 16)
	_chevron(button)
	if on_press.is_valid():
		button.pressed.connect(on_press)
	return button


func _primary(text: String, on_press: Callable) -> Button:
	var button := _button(text, 18)
	button.custom_minimum_size = Vector2(0, 62)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_button(button, PINK_DEEP, Color("#ff8ab6"), CREAM, 16, 8)
	var disc := _label("●", 16, CREAM, bold_font)
	disc.position = Vector2(16, 18)
	disc.size = Vector2(28, 24)
	button.add_child(disc)
	_chevron(button)
	button.pressed.connect(on_press)
	return button


func _chevron(button: Button) -> void:
	var mark := _label("›", 22, PINK, bold_font)
	mark.anchor_left = 1.0
	mark.anchor_right = 1.0
	mark.offset_left = -36.0
	mark.offset_right = -8.0
	mark.offset_top = 0.0
	mark.offset_bottom = 0.0
	mark.anchor_bottom = 1.0
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(mark)


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", bold_font)
	button.add_theme_font_size_override("font_size", font_size)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _chip(page: Control, pos: Vector2) -> Label:
	var panel := Panel.new()
	_place(page, panel, pos, Vector2(38, 38))
	panel.add_theme_stylebox_override("panel", _flat(Color("#120c14"), PINK, 1, 10, 0))
	var label := _label("0", 16, CREAM, bold_font)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return label


func _mark_rect() -> TextureRect:
	var mark := TextureRect.new()
	mark.texture = logo_tex
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return mark


func _place(parent: Control, node: Control, pos: Vector2, box: Vector2) -> void:
	node.position = pos
	node.size = box
	node.custom_minimum_size = box
	parent.add_child(node)


func _paint_button(button: Button, fill: Color, border: Color, font_color: Color, radius: int, side: int, width: int = 1) -> void:
	button.add_theme_stylebox_override("normal", _flat(fill, border, width, radius, side))
	button.add_theme_stylebox_override("hover", _flat(fill.lightened(0.12), border, width, radius, side))
	button.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.08), Color("#ffd0ea"), width, radius, side))
	button.add_theme_stylebox_override("disabled", _flat(fill, border, width, radius, side))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", font_color)


func _flat(fill: Color, border: Color, width: int, radius: int, side: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = side
	style.content_margin_right = side
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _style_edit(edit: LineEdit) -> void:
	edit.add_theme_font_override("font", bold_font)
	edit.add_theme_font_size_override("font_size", 18)
	edit.add_theme_color_override("font_color", CREAM)
	edit.add_theme_color_override("font_placeholder_color", Color("#8d7d88"))
	edit.add_theme_color_override("caret_color", PINK)
	var box := _flat(Color("#120c14"), PINK, 1, 14, 14)
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", _flat(Color("#120c14"), Color("#ffd0ea"), 2, 14, 14))


class Mark extends Control:
	var kind := "home"
	var lit := false

	func set_lit(value: bool) -> void:
		lit = value
		queue_redraw()

	func _draw() -> void:
		var color := Color("#ff3d8a") if lit else Color("#8d7d88")
		var box := size
		if box.x < 2.0:
			box = Vector2(26, 26)
		var mid := box * 0.5
		if kind == "home":
			draw_colored_polygon(PackedVector2Array([
				Vector2(mid.x, 3),
				Vector2(box.x - 2, mid.y + 1),
				Vector2(box.x - 6, mid.y + 1),
				Vector2(box.x - 6, box.y - 3),
				Vector2(6, box.y - 3),
				Vector2(6, mid.y + 1),
				Vector2(2, mid.y + 1),
			]), color)
		elif kind == "profile":
			draw_arc(Vector2(mid.x, 8), 4.2, 0, TAU, 16, color, 1.7, true)
			draw_arc(Vector2(mid.x, 24), 8, PI + 0.4, TAU - 0.4, 16, color, 1.7, true)
		elif kind == "customise":
			draw_arc(mid, 8, 0, TAU, 24, color, 1.7, true)
			draw_circle(mid, 2.4, color)
		elif kind == "shop":
			draw_rect(Rect2(6, 10, box.x - 12, box.y - 14), color, false, 1.7)
			draw_arc(Vector2(mid.x, 10), 4, PI, TAU, 12, color, 1.7, true)
		else:
			draw_arc(mid, 7, 0, TAU, 20, color, 1.7, true)
			draw_circle(mid, 2.2, color)
