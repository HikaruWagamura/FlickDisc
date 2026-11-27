extends CanvasLayer

## Bowl & Roll club. Splash, home, and the 1v1 table select in front of the two rinks.

signal play_requested(setup: Dictionary)

const GOLD := Color("#F5C84B")
const GOLD_DEEP := Color("#E0A21A")
const GOLD_GLOW := Color("#FFE08A")
const BLUE := Color("#1C6CFF")
const BLUE_LIT := Color("#2A7BFF")
const RED := Color("#E12A32")
const INK := Color("#050814")
const CARD := Color(0.06, 0.13, 0.26, 0.94)
const PLUM := Color(0.08, 0.16, 0.34, 0.96)
const MUTED := Color("#A9C6EA")
const CREAM := Color("#F4F7FF")
const CHROME := Color("#E8EEF8")
const NAVY := Color("#07101C")

var profile
var feel
var root: Control
var backdrop: Control
var pages := {}
var screen := ""
var kind := "classic"
var rink := "lawn"
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
var bowl_tex: Texture2D

var home_name: Label
var home_level: Label
var home_letter: Label
var home_record: Label
var home_tally: Label
var home_play: Button
var home_mark: TextureRect
var home_pill: Button
var home_gear: Button
var home_cards: Array = []
var splash_mark: TextureRect
var splash_line: Label
var starting: Control
var home_xp: ColorRect
var chip_wins: Label
var chip_losses: Label
var title_label: Label
var sub_label: Label
var hint_label: Label
var difficulty_button: Button
var race_button: Button
var big_play: Button
var friend_button: Button
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
var board_solo: Label
var board_drive: Label
var board_mark: Label
var board_recent: Label
var friend_code: Label
var nav: Control
var nav_row: HBoxContainer
var nav_glow: ColorRect
var nav_icons: Array = []
var nav_captions: Array = []
var nav_buttons: Array = []
var nav_glyphs: Array = []
var match_chips: Array = []
var skill_chips: Array = []
var match_kicker: Label
var skill_kicker: Label
var emoji_font: Font
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
var kit_tab := "bowl"
var kit_preview_bowl: TextureRect
var kit_preview_disc: TextureRect
var kit_skin_row: GridContainer
var kit_caption: Label
var kit_bowl_tab: Button
var kit_disc_tab: Button
var customize_button: Button
var guide := 0
var ditch_on := true
var guide_kicker: Label
var ditch_kicker: Label
var guide_chips: Array = []
var ditch_chips: Array = []
var photo_kicker: Label
var photo_blurb: Label
var photo_a_button: Button
var photo_b_button: Button
var photo_place_row: Control
var photo_place_chips: Array = []
var photo_picker: FileDialog
var photo_slot := "a"
var studio
var studio_box: Control
var theme_kicker: Label
var look_panel: VBoxContainer
var disc_block: VBoxContainer
var disc_look_host: VBoxContainer
var hub_page_margins: Array = []
var profile_bowl: TextureRect


func setup(player_profile) -> void:
	profile = player_profile
	feel = preload("res://scripts/feel.gd").new()
	feel.name = "MenuFeel"
	add_child(feel)
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
	_build_starting()
	get_viewport().size_changed.connect(_layout_shell)
	call_deferred("_layout_shell")
	_show("splash")


func set_open(is_open: bool) -> void:
	root.visible = is_open
	if starting != null:
		starting.visible = false


func open_screen(screen_name: String) -> void:
	root.visible = true
	if starting != null:
		starting.visible = false
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


const FONT_ANTON := preload("res://assets/fonts/Anton-Regular.ttf")
const FONT_PACIFICO := preload("res://assets/fonts/Pacifico-Regular.ttf")
const FONT_INTER := preload("res://assets/fonts/Inter-Regular.ttf")
const FONT_INTER_BOLD := preload("res://assets/fonts/Inter-Bold.ttf")


func _prepare_fonts() -> void:
	# Preload packs the font files into the web export. A runtime file load
	# does not, which is why the hosted menu was missing these four faces.
	title_font = FONT_ANTON
	script_font = FONT_PACIFICO
	body_font = FONT_INTER
	bold_font = FONT_INTER_BOLD
	emoji_font = SystemFont.new()
	emoji_font.font_names = PackedStringArray(["Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji"])
	var marks := SystemFont.new()
	marks.font_names = PackedStringArray(["Noto Sans Symbols2", "DejaVu Sans"])
	var stack: Array[Font] = [emoji_font, marks]
	var faces: Array[FontFile] = [FONT_ANTON, FONT_INTER, FONT_INTER_BOLD, FONT_PACIFICO]
	for face in faces:
		face.fallbacks = stack


const LOGO := preload("res://assets/bowl_and_roll_logo.png")
const BOWLS_ART := preload("res://assets/bowls_card.png")
const CROCK_ART := preload("res://assets/crock_and_hole_card.png")
const Kit := preload("res://scripts/kit.gd")
const StudioScript := preload("res://scripts/bowl_studio.gd")


func _logo_texture() -> Texture2D:
	# preload packs the mark into the phone export. Image.load does not.
	return LOGO


func _show(next: String) -> void:
	screen = next
	for key in pages.keys():
		var page := pages[key] as Control
		page.visible = str(key) == next
	var hub := next == "home" or next == "profile" or next == "customise" or next == "shop" or next == "settings"
	nav.visible = hub
	backdrop.visible = true
	choice_layer.visible = false
	online_layer.visible = false
	_paint_nav(next)
	if next == "splash":
		_arm_splash()
	if next == "setup":
		_sync_setup()
	if next == "customise":
		if studio != null:
			studio.refresh()
		_paint_kit()
	_sync_identity()
	_layout_shell()


func _view_size() -> Vector2:
	var size := Vector2(540, 960)
	if is_inside_tree():
		size = get_viewport().get_visible_rect().size
	if size.x < 2.0:
		size.x = 540.0
	if size.y < 2.0:
		size.y = 960.0
	return size


func _safe_pad() -> Vector2:
	# About 15px from the glass. If a system bar is actually showing,
	# sit above that instead of adding a second cushion.
	var min_top := 15.0
	var min_bottom := 15.0
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x < 1 or win.y < 1:
		return Vector2(min_top, min_bottom)
	var scale := float(win.x) / 540.0
	if scale <= 0.001:
		return Vector2(min_top, min_bottom)
	var top := maxf(min_top, float(safe.position.y) / scale)
	var bottom_px := float(win.y) - float(safe.position.y + safe.size.y)
	var bottom := maxf(min_bottom, bottom_px / scale)
	return Vector2(top, bottom)


func _layout_shell() -> void:
	if root == null:
		return
	var view := _view_size()
	var pad := _safe_pad()
	var wide := view.x
	var tall := view.y
	if splash_bar != null:
		splash_bar.position = Vector2(0, pad.x)
	if splash_mark != null:
		var mark_h := minf(360.0, tall * 0.38)
		splash_mark.position = Vector2(40.0, pad.x + (tall - pad.x - pad.y - mark_h) * 0.28)
		splash_mark.size = Vector2(wide - 80.0, mark_h)
	if splash_line != null and splash_mark != null:
		splash_line.position = Vector2(30.0, splash_mark.position.y + splash_mark.size.y + 8.0)
		splash_line.size = Vector2(wide - 60.0, 36.0)
	if nav != null:
		nav.size = Vector2(wide - 28.0, 104.0)
		nav.position = Vector2(14.0, tall - pad.y - 104.0)
		if nav_glow != null:
			nav_glow.position = Vector2(28.0, 2.0)
			nav_glow.size = Vector2(nav.size.x - 56.0, 3.0)
		if nav_row != null:
			nav_row.position = Vector2(8.0, 8.0)
			nav_row.size = Vector2(nav.size.x - 16.0, 90.0)
	if toast != null:
		toast.position = Vector2(40.0, maxf(80.0, nav.position.y - 56.0))
		toast.size = Vector2(wide - 80.0, 48.0)
	if backdrop != null:
		backdrop.queue_redraw()
	var top_m := int(round(pad.x + 6.0))
	var bot_m := 120
	if nav != null:
		bot_m = int(round(view.y - nav.position.y + 18.0))
	for margin in hub_page_margins:
		if margin is MarginContainer:
			(margin as MarginContainer).add_theme_constant_override("margin_top", top_m)
			(margin as MarginContainer).add_theme_constant_override("margin_bottom", bot_m)
	_layout_home(view, pad)


func _layout_home(view: Vector2, pad: Vector2) -> void:
	if home_pill == null or home_mark == null or home_play == null:
		return
	var wide := view.x
	var chrome_y := pad.x
	home_pill.position = Vector2(16.0, chrome_y)
	if chip_wins != null and chip_wins.get_parent() is Control:
		(chip_wins.get_parent() as Control).position = Vector2(wide - 148.0, chrome_y + 10.0)
	if chip_losses != null and chip_losses.get_parent() is Control:
		(chip_losses.get_parent() as Control).position = Vector2(wide - 104.0, chrome_y + 10.0)
	if home_gear != null:
		home_gear.position = Vector2(wide - 56.0, chrome_y + 8.0)
	var y := chrome_y + 58.0 + 8.0
	var floor := view.y - pad.y - 12.0
	if nav != null:
		floor = nav.position.y - 12.0
	var extra := maxf(0.0, view.y - 960.0)
	var play_h := clampf(64.0 + extra * 0.04, 64.0, 72.0)
	var rec_h := 48.0
	var gap := 10.0
	var logo_h := clampf(220.0 + extra * 0.22, 208.0, 272.0)
	var card_h := clampf(128.0 + extra * 0.30, 128.0, 188.0)
	var inner := floor - y - play_h - rec_h - 8.0 - gap * 3.0
	var slack := inner - logo_h - card_h * 2.0 - gap
	if extra > 0.0 and slack > 20.0:
		var bump := minf(slack * 0.50, 36.0)
		card_h += bump
		slack -= bump
	if logo_h + card_h * 2.0 + gap > inner:
		logo_h = clampf(inner - card_h * 2.0 - gap, 168.0, logo_h)
	var after_cards := gap
	home_mark.position = Vector2(40.0, y)
	home_mark.size = Vector2(wide - 80.0, logo_h)
	y += logo_h + 8.0
	home_play.position = Vector2(28.0, y)
	home_play.size = Vector2(wide - 56.0, play_h)
	home_play.add_theme_font_size_override("font_size", int(round(clampf(22.0 + extra * 0.02, 22.0, 26.0))))
	y += play_h + gap
	var card_w := (wide - 28.0 - 16.0 - 12.0) * 0.5
	if home_cards.size() >= 4:
		_place_home_card(home_cards[0] as Button, Vector2(28.0, y), Vector2(card_w, card_h))
		_place_home_card(home_cards[1] as Button, Vector2(28.0 + card_w + 12.0, y), Vector2(card_w, card_h))
		_place_home_card(home_cards[2] as Button, Vector2(28.0, y + card_h + gap), Vector2(card_w, card_h))
		_place_home_card(home_cards[3] as Button, Vector2(28.0 + card_w + 12.0, y + card_h + gap), Vector2(card_w, card_h))
	y += card_h + gap + card_h + after_cards
	if home_record != null:
		home_record.position = Vector2(20.0, minf(y, floor - rec_h))
		home_record.size = Vector2(wide - 40.0, 24.0)
	if home_tally != null:
		home_tally.position = Vector2(20.0, minf(y + 24.0, floor - 22.0))
		home_tally.size = Vector2(wide - 40.0, 18.0)


func _place_home_card(card: Button, pos: Vector2, box: Vector2) -> void:
	card.position = pos
	card.size = box
	card.custom_minimum_size = box
	var s := clampf(box.y / 124.0, 1.0, 1.55)
	var inset := 14.0
	var stacked := box.y >= 150.0
	var title_h := clampf(26.0 * s, 26.0, 36.0)
	var stamp := clampf(64.0 * s, 64.0, 76.0)
	if stacked:
		stamp = clampf(box.y - title_h - 62.0, 78.0, 108.0)
	var heading := card.get_node_or_null("Heading") as Label
	if heading != null:
		heading.position = Vector2(inset, 10.0)
		heading.size = Vector2(box.x - inset * 2.0, title_h)
		heading.add_theme_font_size_override("font_size", int(round(clampf(24.0 * s, 24.0, 30.0))))
		heading.autowrap_mode = TextServer.AUTOWRAP_OFF
		heading.clip_text = true
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var detail := card.get_node_or_null("Detail") as Label
	if detail != null:
		detail.position = Vector2(inset, 8.0 + title_h)
		if stacked:
			detail.size = Vector2(box.x - inset * 2.0, 36.0)
		else:
			detail.size = Vector2(box.x - inset * 2.0 - stamp - 8.0, maxf(36.0, box.y - title_h - 20.0))
		detail.add_theme_font_size_override("font_size", int(round(clampf(15.0 * s, 15.0, 18.0))))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var art_x := box.x - inset - stamp
	var art_y := 8.0 + title_h + maxf(0.0, (box.y - title_h - 18.0 - stamp) * 0.5)
	if stacked:
		art_x = (box.x - stamp) * 0.5
		art_y = box.y - inset - stamp
	var art := card.get_node_or_null("Art") as Control
	if art != null:
		art.position = Vector2(art_x, art_y)
		art.size = Vector2(stamp, stamp)
		art.queue_redraw()
	var badge := card.get_node_or_null("Badge") as Label
	if badge != null:
		badge.visible = false


func _process(_delta: float) -> void:
	# The play button used to scale under the finger, so the first press
	# slid off and felt like it had not landed.
	pass


func _arm_splash() -> void:
	splash_token += 1
	var token := splash_token
	splash_bar.size = Vector2(0, 3)
	var tween := create_tween()
	tween.tween_property(splash_bar, "size:x", _view_size().x, 2.05)
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
	black.color = Color(0, 0, 0, 0)
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
	splash_mark = _mark_rect()
	splash_mark.position = Vector2(40, 150)
	splash_mark.size = Vector2(460, 360)
	page.add_child(splash_mark)
	splash_line = _label("Pick the table. Then bowl.", 22, CREAM, script_font)
	splash_line.position = Vector2(30, 530)
	splash_line.size = Vector2(480, 36)
	splash_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(splash_line)
	splash_bar = ColorRect.new()
	splash_bar.position = Vector2(0, 0)
	splash_bar.size = Vector2(0, 3)
	splash_bar.color = GOLD
	splash_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(splash_bar)


func _build_home() -> void:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages["home"] = page
	root.add_child(page)

	home_pill = Button.new()
	_place(page, home_pill, Vector2(16, 16), Vector2(250, 58))
	_paint_button(home_pill, PLUM, GOLD, CREAM, 28, 12)
	home_pill.pressed.connect(_show.bind("profile"))
	var avatar := Panel.new()
	avatar.position = Vector2(8, 10)
	avatar.size = Vector2(38, 38)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_theme_stylebox_override("panel", _flat(GOLD, GOLD, 0, 19, 0))
	home_pill.add_child(avatar)
	home_letter = _label("B", 18, Color("#07101C"), bold_font)
	home_letter.position = Vector2(8, 16)
	home_letter.size = Vector2(38, 26)
	home_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_pill.add_child(home_letter)
	home_name = _label("Flicker", 16, CREAM, bold_font)
	home_name.position = Vector2(54, 8)
	home_name.size = Vector2(180, 22)
	home_pill.add_child(home_name)
	home_level = _label("Level 1", 12, CREAM, bold_font)
	home_level.position = Vector2(54, 30)
	home_level.size = Vector2(180, 16)
	home_pill.add_child(home_level)
	var track := ColorRect.new()
	track.position = Vector2(54, 48)
	track.size = Vector2(150, 3)
	track.color = Color(1, 1, 1, 0.14)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_pill.add_child(track)
	home_xp = ColorRect.new()
	home_xp.position = Vector2(54, 48)
	home_xp.size = Vector2(8, 3)
	home_xp.color = GOLD
	home_xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_pill.add_child(home_xp)

	chip_wins = _chip(page, Vector2(392, 26))
	chip_losses = _chip(page, Vector2(436, 26))
	home_gear = _button("⚙", 18)
	_place(page, home_gear, Vector2(484, 24), Vector2(40, 40))
	_paint_button(home_gear, PLUM, GOLD, CREAM, 12, 0)
	home_gear.pressed.connect(_show.bind("settings"))

	home_mark = _mark_rect()
	_place(page, home_mark, Vector2(40, 82), Vector2(460, 220))

	var play := _button("▶  PLAY A MATCH", 22)
	_place(page, play, Vector2(28, 360), Vector2(484, 64))
	_paint_button(play, GOLD, Color("#FFE9A0"), Color("#1A1208"), 20, 0, 2)
	home_play = play
	play.pressed.connect(func() -> void:
		_tap()
		_open_setup("classic")
	)

	home_cards = [
		_home_card(page, Rect2(28, 444, 236, 124), "CRAZY BOWLS", "18 holes · par 70", "crazy", "⛳", "crazy"),
		_home_card(page, Rect2(276, 444, 236, 124), "SOLO ENDS", "One bowl · the jack", "solo", "🎯", "solo"),
		_home_card(page, Rect2(28, 584, 236, 124), "PRACTICE", "You and the jack", "practice", "🔥", "practice"),
		_home_card(page, Rect2(276, 584, 236, 124), "THE BOARD", "Wins · ends · runs", "board", "🏆", "rankings"),
	]

	home_record = _label("0W  ·  0L", 18, CREAM, bold_font)
	_place(page, home_record, Vector2(20, 720), Vector2(500, 24))
	home_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_tally = _label("ENDS 0  ·  NO DRIVE YET", 13, MUTED, bold_font)
	_place(page, home_tally, Vector2(20, 744), Vector2(500, 18))
	home_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _home_card(page: Control, rect: Rect2, title: String, body: String, stamp_kind: String, glyph: String, target: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.clip_contents = true
	_place(page, button, rect.position, rect.size)
	_paint_button(button, PLUM, Color("#3A78E8"), CREAM, 20, 14, 2)
	var heading := _label(title, 20, CREAM, title_font)
	heading.name = "Heading"
	heading.position = Vector2(14, 18)
	heading.size = Vector2(rect.size.x - 96, 32)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(heading)
	var detail := _label(body, 13, MUTED, body_font)
	detail.name = "Detail"
	detail.position = Vector2(14, 54)
	detail.size = Vector2(rect.size.x - 96, 56)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(detail)
	var art := Stamp.new()
	art.name = "Art"
	art.kind = stamp_kind
	art.lit = true
	art.position = Vector2(rect.size.x - 90, 26)
	art.size = Vector2(72, 72)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art)
	var badge := _glyph(glyph, 32)
	badge.name = "Badge"
	badge.position = Vector2(rect.size.x - 84, 38)
	badge.size = Vector2(60, 48)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(badge)
	button.pressed.connect(func() -> void:
		if target == "solo":
			_launch_solo()
		elif target == "crazy":
			_launch_crazy()
		elif target == "drive":
			_launch_crazy()
		else:
			_tap()
			if target == "classic" or target == "duo":
				_open_setup(target)
			else:
				_show(target)
	)
	return button


func _build_setup() -> void:
	# One clean play sheet. Online lives on Friends, not here.
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages["setup"] = page
	root.add_child(page)
	_back_on(page, "home")

	title_label = _label("PLAY", 40, CREAM, title_font)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(page, title_label, Vector2(16, 128), Vector2(508, 44))
	sub_label = _label("Pick the table. Then bowl.", 16, CREAM, script_font)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(page, sub_label, Vector2(16, 170), Vector2(508, 26))

	lawn_card = _rink_card("BOWLS", "The long green.", BOWLS_ART)
	crokin_card = _rink_card("CROCK & HOLE", "The round board.", CROCK_ART)
	lawn_tag = lawn_card.get_node("Tag") as Label
	crokin_tag = crokin_card.get_node("Tag") as Label
	lawn_card.pressed.connect(func() -> void:
		rink = "lawn"
		_sync_setup()
	)
	crokin_card.pressed.connect(func() -> void:
		rink = "crokinole"
		_sync_setup()
	)
	_place(page, lawn_card, Vector2(20, 202), Vector2(244, 210))
	_place(page, crokin_card, Vector2(276, 202), Vector2(244, 210))

	hint_label = _label("", 13, MUTED, body_font)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.visible = false
	_place(page, hint_label, Vector2(20, 360), Vector2(500, 18))

	customize_button = _button("CUSTOMIZE", 11)
	customize_button.focus_mode = Control.FOCUS_NONE
	customize_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	customize_button.position = Vector2(12, 164)
	customize_button.size = Vector2(220, 36)
	customize_button.custom_minimum_size = Vector2(220, 36)
	_paint_button(customize_button, BLUE_LIT, Color("#8EC4FF"), CREAM, 10, 8, 2)
	customize_button.pressed.connect(func() -> void:
		_tap()
		rink = "lawn"
		_open_kit(kind if kind != "" else "classic")
	)
	lawn_card.add_child(customize_button)

	guide_kicker = _kicker("AIM GUIDE")
	_place(page, guide_kicker, Vector2(28, 426), Vector2(240, 16))
	guide_chips = _chip_row(page, Vector2(20, 446), PackedStringArray(["5 + 3", "5", "3", "NONE"]), func(i: int) -> void:
		guide = i
		_sync_setup()
	)
	ditch_kicker = _kicker("DITCH")
	_place(page, ditch_kicker, Vector2(28, 508), Vector2(200, 16))
	ditch_chips = _chip_row(page, Vector2(20, 528), PackedStringArray(["ON", "OFF"]), func(i: int) -> void:
		ditch_on = i == 0
		_sync_setup()
	)

	match_kicker = _kicker("MATCH")
	_place(page, match_kicker, Vector2(28, 590), Vector2(200, 16))
	match_chips = _chip_row(page, Vector2(20, 610), PackedStringArray(["1 END", "4 ENDS", "TO 10", "TO 21"]), func(i: int) -> void:
		race = i
		_sync_setup()
	)
	skill_kicker = _kicker("AI")
	_place(page, skill_kicker, Vector2(28, 672), Vector2(200, 16))
	skill_chips = _chip_row(page, Vector2(20, 692), PackedStringArray(["EASY", "MEDIUM", "HARD"]), func(i: int) -> void:
		difficulty = i
		_sync_setup()
	)

	big_play = _primary("▶  PLAY VERSUS AI", func() -> void: _launch("ai"))
	_place(page, big_play, Vector2(20, 770), Vector2(500, 64))
	friend_button = _row_button("PLAY A FRIEND", func() -> void: _launch("local"))
	_place(page, friend_button, Vector2(20, 848), Vector2(500, 56))

	duo_note = _label("Both teams play on this device. Pass the phone each shot.", 13, MUTED, body_font)
	duo_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	duo_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	duo_note.visible = false
	_place(page, duo_note, Vector2(20, 752), Vector2(500, 40))

	difficulty_button = _choice_button()
	difficulty_button.visible = false
	_place(page, difficulty_button, Vector2(20, 900), Vector2(20, 20))
	race_button = _choice_button()
	race_button.visible = false
	_place(page, race_button, Vector2(48, 900), Vector2(20, 20))

	online_box = Control.new()
	online_box.visible = false
	online_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(page, online_box, Vector2(20, 900), Vector2(20, 20))
	join_edit = LineEdit.new()
	join_edit.visible = false
	_place(online_box, join_edit, Vector2(0, 0), Vector2(20, 20))


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
	var built: Dictionary = _column_page(122, 28)
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
		_emit_play({
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
	var built: Dictionary = _column_page(122, 28)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["practice"] = page
	root.add_child(page)
	_back_on(page, "home")
	box.add_child(_title("PRACTICE"))
	box.add_child(_wrapped("Nothing is on the line except the shot. Solo ends and Crazy Bowls keep a tally."))
	box.add_child(_wide_card("SOLO ENDS", "Three bowls are already down. One bowl to be the shot.", "PLAY"))
	box.get_child(box.get_child_count() - 1).pressed.connect(_launch_solo)
	box.add_child(_wide_card("CRAZY BOWLS", "Eighteen holes on a wide green. Bowl it, as it lies.", "PLAY"))
	box.get_child(box.get_child_count() - 1).pressed.connect(_launch_crazy)
	box.add_child(_wide_card("OPEN BOARD", "Crokinmode with a clear road to the hole.", "PLAY"))
	box.get_child(box.get_child_count() - 1).pressed.connect(_practice.bind("open"))
	box.add_child(_wide_card("PEG GUARD", "The far side is sitting on the pegs.", "PLAY"))
	box.get_child(box.get_child_count() - 1).pressed.connect(_practice.bind("guard"))
	box.add_child(_wide_card("DRAW TO THE JACK", "Long rink. Place the jack, then bowl.", "PLAY"))
	box.get_child(box.get_child_count() - 1).pressed.connect(_practice.bind("jack"))


func _build_challenges() -> void:
	var built: Dictionary = _column_page(122, 28)
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
	var built: Dictionary = _column_page(122, 28)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["friends"] = page
	root.add_child(page)
	_back_on(page, "home")
	box.add_child(_title("FRIENDS"))
	box.add_child(_wrapped("Head-to-head on two phones is not live yet. A room code stays on this device. PLAY A FRIEND is pass-the-phone on one handset."))
	box.add_child(_kicker("YOUR ROOM"))
	friend_code = _label(room_code, 36, CREAM, title_font)
	friend_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(friend_code)
	box.add_child(_row_button("Copy room code", _copy_code))
	box.add_child(_wrapped("No mates are stored on this device yet."))


func _build_rankings() -> void:
	var built: Dictionary = _column_page(122, 28)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["rankings"] = page
	root.add_child(page)
	_back_on(page, "home")
	box.add_child(_title("THE BOARD"))
	box.add_child(_wrapped("The tally on this device. Matches won, solo ends cleared, the longest bowl, and the nearest you have been to the mark."))
	var row := _wide_card("PLAYER", "Most matches won", "0 WINS")
	rank_name = row.get_node("Heading") as Label
	rank_record = row.get_node("Trail") as Label
	row.disabled = true
	box.add_child(row)
	var solo_row := _wide_card("SOLO ENDS", "Ends you have won", "0 / 8")
	board_solo = solo_row.get_node("Trail") as Label
	solo_row.disabled = true
	box.add_child(solo_row)
	var drive_row := _wide_card("CRAZY BOWLS", "Best 18 on the wide green", "NO ROUND YET")
	board_drive = drive_row.get_node("Trail") as Label
	drive_row.disabled = true
	box.add_child(drive_row)
	var mark_row := _wide_card("NEAREST MARK", "How close on a match rink", "MARK NOT FOUND")
	board_mark = mark_row.get_node("Trail") as Label
	mark_row.disabled = true
	box.add_child(mark_row)
	var recent_row := _wide_card("LATEST", "The last thing this device recorded", "NO ROUNDS YET")
	board_recent = recent_row.get_node("Trail") as Label
	recent_row.disabled = true
	box.add_child(recent_row)


func _build_profile() -> void:
	var built: Dictionary = _column_page(24, 140, true)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["profile"] = page
	root.add_child(page)
	var avatar_row := CenterContainer.new()
	var stack := HBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(96, 96)
	var disc := _flat(GOLD, Color("#FFE9A0"), 2, 48, 0)
	avatar.add_theme_stylebox_override("panel", disc)
	profile_letter = _label("B", 36, Color("#07101C"), bold_font)
	profile_letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	profile_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(profile_letter)
	stack.add_child(avatar)
	profile_bowl = TextureRect.new()
	profile_bowl.custom_minimum_size = Vector2(96, 96)
	profile_bowl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_bowl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile_bowl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(profile_bowl)
	avatar_row.add_child(stack)
	box.add_child(avatar_row)
	profile_name = _label("Flicker", 32, CREAM, title_font)
	profile_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(profile_name)
	profile_level = _label("Level 1", 16, GOLD, bold_font)
	profile_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(profile_level)
	var bar_row := CenterContainer.new()
	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(220, 6)
	track.size = Vector2(220, 6)
	track.color = Color(1, 1, 1, 0.14)
	profile_xp = ColorRect.new()
	profile_xp.color = GOLD
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
	profile_disc = _label("Disc  ·  Match red", 14, MUTED, body_font)
	profile_disc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(profile_disc)
	box.add_child(_row_button("Change disc", _show.bind("customise")))
	box.add_child(_row_button("Settings", _show.bind("settings")))


func _build_customise() -> void:
	var built: Dictionary = _column_page(24, 140, true)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["customise"] = page
	root.add_child(page)
	box.add_child(_title("YOUR BOWLS"))
	box.add_child(_wrapped("A theme wraps the whole bowl. Half and half opens the other face."))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	kit_bowl_tab = _button("BOWLS", 14)
	kit_bowl_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit_bowl_tab.custom_minimum_size = Vector2(0, 44)
	kit_bowl_tab.pressed.connect(func() -> void:
		kit_tab = "bowl"
		_paint_kit()
	)
	tabs.add_child(kit_bowl_tab)
	kit_disc_tab = _button("DISCS", 14)
	kit_disc_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit_disc_tab.custom_minimum_size = Vector2(0, 44)
	kit_disc_tab.pressed.connect(func() -> void:
		kit_tab = "disc"
		_paint_kit()
	)
	tabs.add_child(kit_disc_tab)
	studio = StudioScript.new()
	studio.setup(profile)
	studio.kit_changed.connect(_on_studio_changed)
	box.add_child(studio)
	studio_box = studio
	disc_block = VBoxContainer.new()
	disc_block.add_theme_constant_override("separation", 12)
	disc_block.visible = false
	box.add_child(disc_block)
	var previews := HBoxContainer.new()
	previews.alignment = BoxContainer.ALIGNMENT_CENTER
	previews.add_theme_constant_override("separation", 28)
	disc_block.add_child(previews)
	kit_preview_bowl = TextureRect.new()
	kit_preview_bowl.custom_minimum_size = Vector2(132, 132)
	kit_preview_bowl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kit_preview_bowl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	previews.add_child(kit_preview_bowl)
	kit_preview_disc = TextureRect.new()
	kit_preview_disc.custom_minimum_size = Vector2(132, 132)
	kit_preview_disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kit_preview_disc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	previews.add_child(kit_preview_disc)
	kit_caption = _wrapped("CLUB  ·  Match red")
	disc_block.add_child(kit_caption)
	disc_look_host = VBoxContainer.new()
	disc_look_host.add_theme_constant_override("separation", 8)
	disc_block.add_child(disc_look_host)
	look_panel = VBoxContainer.new()
	look_panel.add_theme_constant_override("separation", 8)
	theme_kicker = _kicker("THEMES")
	look_panel.add_child(theme_kicker)
	kit_skin_row = GridContainer.new()
	kit_skin_row.columns = 4
	kit_skin_row.add_theme_constant_override("h_separation", 8)
	kit_skin_row.add_theme_constant_override("v_separation", 10)
	kit_skin_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	look_panel.add_child(kit_skin_row)
	for item in Kit.SKINS:
		if Kit.is_photo_skin(str(item["id"])):
			continue
		if str(item["id"]) == "club" or str(item["id"]) == "split":
			continue
		kit_skin_row.add_child(_theme_orb(str(item["id"]), str(item["name"])))
	look_panel.add_child(_kicker("COLOUR"))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in Kit.PALETTES.size():
		var swatch := Button.new()
		swatch.text = ""
		swatch.custom_minimum_size = Vector2(44, 44)
		swatch.pressed.connect(_pick_swatch.bind(i))
		swatch_buttons.append(swatch)
		grid.add_child(swatch)
	var center := CenterContainer.new()
	center.add_child(grid)
	look_panel.add_child(center)
	if studio != null and studio.look_box != null:
		studio.look_box.add_child(look_panel)
	else:
		box.add_child(look_panel)
	var play_kit := _button("USE THIS BOWL", 16)
	play_kit.custom_minimum_size = Vector2(0, 52)
	_paint_button(play_kit, GOLD, Color("#FFE9A0"), Color("#1A1208"), 16, 12, 2)
	play_kit.pressed.connect(func() -> void:
		_open_setup(kind if kind != "" else "classic")
	)
	box.add_child(play_kit)
	_paint_kit()


func _build_shop() -> void:
	var built: Dictionary = _column_page(24, 140, true)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["shop"] = page
	root.add_child(page)
	box.add_child(_title("SHOP"))
	var coins := PanelContainer.new()
	coins.add_theme_stylebox_override("panel", _flat(PLUM, GOLD, 1, 16, 14))
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 10)
	var coin_mark := _label("●", 22, GOLD, title_font)
	coin_row.add_child(coin_mark)
	var coin_copy := VBoxContainer.new()
	coin_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coin_copy.add_child(_label("FLICK COINS", 12, MUTED, bold_font))
	coin_copy.add_child(_label("0", 28, CREAM, title_font))
	coin_row.add_child(coin_copy)
	coins.add_child(coin_row)
	box.add_child(coins)
	box.add_child(_wrapped("Board colours for Crock and Hole. The match-red disc is yours."))
	box.add_child(_shop_row("Match red disc", "OWNED", true, 1))
	box.add_child(_shop_row("Ice rim", "LOCKED", false, 8))
	box.add_child(_shop_row("Gold centre", "LOCKED", false, 4))
	box.add_child(_shop_row("Lawn whites", "LOCKED", false, 17))


func _build_settings() -> void:
	var built: Dictionary = _column_page(24, 140, true)
	var page := built["page"] as Control
	var box := built["box"] as VBoxContainer
	pages["settings"] = page
	root.add_child(page)
	box.add_child(_title("SETTINGS"))
	var name_card := PanelContainer.new()
	name_card.add_theme_stylebox_override("panel", _flat(PLUM, GOLD, 1, 16, 14))
	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 8)
	name_col.add_child(_kicker("PLAYER NAME"))
	name_edit = LineEdit.new()
	name_edit.text = profile.player_name
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(0, 52)
	_style_edit(name_edit)
	name_edit.text_changed.connect(_on_name_changed)
	name_col.add_child(name_edit)
	name_card.add_child(name_col)
	box.add_child(name_card)
	sound_button = _row_button("Sound on", _toggle_sound)
	haptic_button = _row_button("Haptics on", _toggle_haptics)
	box.add_child(sound_button)
	box.add_child(haptic_button)
	box.add_child(_kicker("YOUR BOWLS"))
	box.add_child(_row_button("Customise bowls", _show.bind("customise")))
	var how := PanelContainer.new()
	how.add_theme_stylebox_override("panel", _flat(CARD, GOLD, 1, 16, 14))
	var how_col := VBoxContainer.new()
	how_col.add_theme_constant_override("separation", 8)
	how_col.add_child(_kicker("HOW A ROUND WORKS"))
	how_col.add_child(_wrapped("Drag the bowl back. The cream line is your finger. The blocks are where it will run. Let go — it leaves your hand and takes its bias as it slows.\n\nA match is four bowls each. Solo ends put three bowls around the jack. You have one bowl, and as many tries as you want, to finish closer than all of them.\n\nCrazy Bowls is eighteen holes on a wider green. Par 70. Play it as it lies.\n\nThis device stores matches won, ends cleared, and your nearest mark."))
	how.add_child(how_col)
	box.add_child(how)


func _build_nav() -> void:
	nav = Panel.new()
	nav.position = Vector2(14, 842)
	nav.size = Vector2(512, 104)
	nav.add_theme_stylebox_override("panel", _flat(Color(0.04, 0.08, 0.16, 0.96), GOLD, 2, 28, 0))
	root.add_child(nav)
	nav_glow = ColorRect.new()
	nav_glow.position = Vector2(28, 2)
	nav_glow.size = Vector2(456, 3)
	nav_glow.color = GOLD_GLOW
	nav_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_child(nav_glow)
	nav_row = HBoxContainer.new()
	nav_row.position = Vector2(8, 8)
	nav_row.size = Vector2(496, 90)
	nav_row.add_theme_constant_override("separation", 2)
	nav.add_child(nav_row)
	_nav_item(nav_row, "home", "HOME", "🏠")
	_nav_item(nav_row, "profile", "ME", "😎")
	_nav_item(nav_row, "customise", "BOWLS", "🎳")
	_nav_item(nav_row, "shop", "SHOP", "🛍️")
	_nav_item(nav_row, "settings", "GEAR", "⚙️")


func _nav_item(row: HBoxContainer, ident: String, caption: String, glyph: String) -> void:
	var button := Button.new()
	button.text = ""
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 90)
	_paint_button(button, Color(0, 0, 0, 0), Color(0, 0, 0, 0), CREAM, 18, 0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 2)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(52, 52)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := Stamp.new()
	icon.kind = ident
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(icon)
	var face := _glyph(glyph, 26)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(face)
	var label := _label(caption, 11, MUTED, bold_font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(stack)
	box.add_child(label)
	button.add_child(box)
	button.pressed.connect(_show.bind(ident))
	row.add_child(button)
	nav_icons.append(icon)
	nav_captions.append(label)
	nav_buttons.append(button)
	nav_glyphs.append(face)


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
	panel.add_theme_stylebox_override("panel", _flat(PLUM, GOLD, 2, 18, 16))
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
	panel.add_theme_stylebox_override("panel", _flat(PLUM, GOLD, 2, 18, 16))
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
	toast.add_theme_stylebox_override("panel", _flat(Color("#0B1528"), GOLD, 1, 14, 12))
	root.add_child(toast)
	toast_label = _label("", 14, CREAM, bold_font)
	toast_label.position = Vector2(12, 8)
	toast_label.size = Vector2(436, 32)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_child(toast_label)


func _open_kit(next_kind: String) -> void:
	kind = next_kind
	kit_tab = "bowl"
	_show("customise")


func _open_setup(next_kind: String) -> void:
	kind = next_kind
	_show("setup")


func _sync_setup() -> void:
	if title_label == null:
		return
	var classic := kind == "classic"
	title_label.text = "PLAY" if classic else "2 v 2"
	sub_label.text = "Pick the table. Then bowl." if classic else "Two teams. Pass the phone each shot."
	big_play.text = "▶  PLAY VERSUS AI" if classic else "▶  PLAY LOCAL"
	online_box.visible = false
	duo_note.visible = not classic
	if friend_button != null:
		friend_button.visible = classic
	if hint_label != null:
		hint_label.visible = false
	if difficulty_button != null:
		difficulty_button.text = _difficulty_options()[difficulty]
	var match_captions := PackedStringArray(["1 END", "4 ENDS", "TO 10", "TO 21"])
	if rink == "crokinole":
		match_captions = PackedStringArray(["4 ROUNDS"])
		race = 0
	if race >= match_captions.size():
		race = mini(1, match_captions.size() - 1)
	if race_button != null:
		race_button.text = _race_options()[race]
	var lawn := rink == "lawn"
	if customize_button != null:
		customize_button.visible = lawn
		customize_button.text = "CUSTOMIZE"
		_paint_button(customize_button, BLUE_LIT, Color("#8EC4FF"), CREAM, 10, 8, 2)
	_layout_setup_rows(lawn, classic, match_captions)
	_paint_rinks()
	if code_label != null:
		code_label.text = room_code
	if join_edit != null and join_edit.text == "":
		join_edit.text = room_code


func _layout_setup_rows(lawn: bool, classic: bool, match_captions: PackedStringArray) -> void:
	var match_y := 590.0 if lawn else 426.0
	var skill_y := 672.0 if lawn else 508.0
	var lawn_art := lawn_card.get_node_or_null("Art") as Control if lawn_card != null else null
	if lawn_art != null:
		lawn_art.position = Vector2(8, 76)
		lawn_art.size = Vector2(228, 82)
	var crock_art := crokin_card.get_node_or_null("Art") as Control if crokin_card != null else null
	if crock_art != null:
		crock_art.position = Vector2(8, 76)
		crock_art.size = Vector2(228, 122)
	if guide_kicker != null:
		guide_kicker.visible = lawn
		guide_kicker.position = Vector2(28, 426)
	if ditch_kicker != null:
		ditch_kicker.visible = lawn
		ditch_kicker.position = Vector2(28, 508)
	if lawn:
		_layout_chips(guide_chips, PackedStringArray(["5 + 3", "5", "3", "NONE"]), Vector2(20, 446))
		_paint_chips(guide_chips, guide)
		_layout_chips(ditch_chips, PackedStringArray(["ON", "OFF"]), Vector2(20, 528))
		_paint_chips(ditch_chips, 0 if ditch_on else 1)
	else:
		for chip in guide_chips:
			chip.visible = false
		for chip in ditch_chips:
			chip.visible = false
	if match_kicker != null:
		match_kicker.visible = true
		match_kicker.text = "GAME" if not lawn else "MATCH"
		match_kicker.position = Vector2(28, match_y)
	_layout_chips(match_chips, match_captions, Vector2(20, match_y + 20.0))
	_paint_chips(match_chips, race)
	if skill_kicker != null:
		skill_kicker.visible = classic
		skill_kicker.position = Vector2(28, skill_y)
	if classic:
		_layout_chips(skill_chips, PackedStringArray(["EASY", "MEDIUM", "HARD"]), Vector2(20, skill_y + 20.0))
		_paint_chips(skill_chips, difficulty)
	else:
		for chip in skill_chips:
			chip.visible = false
	if big_play != null:
		big_play.position = Vector2(20, 770)
	if friend_button != null:
		friend_button.position = Vector2(20, 848)
	if duo_note != null:
		duo_note.position = Vector2(20, 848)


func _paint_rinks() -> void:
	_paint_choice_card(crokin_card, crokin_tag, rink == "crokinole")
	_paint_choice_card(lawn_card, lawn_tag, rink == "lawn")


func _paint_choice_card(card: Button, tag: Label, selected: bool) -> void:
	var border := GOLD if selected else Color(0.28, 0.48, 0.88, 0.55)
	var width := 3 if selected else 1
	_paint_button(card, CARD, border, CREAM, 16, 12, width)
	tag.visible = selected
	if tag != null:
		tag.add_theme_color_override("font_color", GOLD)


func _difficulty_options() -> PackedStringArray:
	if rink == "lawn":
		return PackedStringArray(["Easy — can sit wide of the head", "Medium — around the head", "Hard — in the rings"])
	return PackedStringArray(["Easy — leaves a gap", "Medium — takes the obvious shot", "Hard — guards the hole"])


func _race_options() -> PackedStringArray:
	if rink == "lawn":
		return PackedStringArray(["1 end", "4 ends", "First to 10", "First to 21"])
	return PackedStringArray(["Four rounds make a game"])


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
			_paint_button(option, BLUE_LIT, Color("#8EC4FF"), CREAM, 12, 12)
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


func _launch_solo() -> void:
	_tap()
	_emit_play({
		"rink": "lawn",
		"solo": true,
		"distance": false,
		"back": "home",
		"opponent": "local",
		"match_index": 0,
		"ditch": true,
		"goal": "solo",
		"challenge": "",
		"difficulty": 0,
		"level": 0,
		"target": 100,
	})


func _launch_drive() -> void:
	_launch_crazy()


func _launch_crazy() -> void:
	_tap()
	_emit_play({
		"rink": "crazy",
		"back": "home",
		"goal": "",
		"challenge": "",
	})


func _tap() -> void:
	if feel != null:
		feel.tap()


func _emit_play(setup: Dictionary) -> void:
	# Paint the acknowledgement before the rink is built, so the press
	# does not look like it missed while the green loads.
	if starting != null:
		starting.visible = true
	await get_tree().process_frame
	play_requested.emit(setup)


func _build_starting() -> void:
	starting = Control.new()
	starting.set_anchors_preset(Control.PRESET_FULL_RECT)
	starting.visible = false
	starting.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(starting)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color("#07101C")
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	starting.add_child(dim)
	var mark := _mark_rect()
	_place(starting, mark, Vector2(120, 280), Vector2(300, 240))
	var brand := _label("BOWL & ROLL", 28, CREAM, title_font)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(starting, brand, Vector2(20, 530), Vector2(500, 40))
	var label := _label("LOADING", 16, GOLD, bold_font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(starting, label, Vector2(20, 578), Vector2(500, 32))


func _launch(channel: String) -> void:
	var setup := {
		"channel": channel,
		"back": "home",
		"rink": rink,
		"goal": "",
		"challenge": "",
		"ditch": false,
		"level": 0,
		"target": 100,
		"match_index": 1,
	}
	if rink == "lawn":
		setup["match_index"] = mini(race, 3)
		setup["opponent"] = "ai" if channel == "ai" else "local"
		setup["difficulty"] = difficulty
		setup["ditch"] = ditch_on
		setup["guide"] = guide
	else:
		setup["target"] = [50, 100, 150][mini(race, 2)]
		setup["level"] = [0, 1, 4][mini(difficulty, 2)]
	_emit_play(setup)


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
		setup["ditch"] = true
	_emit_play(setup)


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
		setup["ditch"] = true
	_emit_play(setup)


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
	_toast("That code is not on this phone. Two devices cannot share a room yet.")


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
	if home_tally != null:
		home_tally.text = "ENDS %d / 8   ·   CRAZY %s" % [profile.solo_cleared, profile.crazy_text()]
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
	if profile_bowl != null:
		profile_bowl.texture = Kit.preview(profile.kit(), false)
	if rank_name != null:
		rank_name.text = profile.player_name.to_upper()
		rank_record.text = "%d WINS" % profile.wins
	if board_solo != null:
		board_solo.text = "%d / 8" % profile.solo_cleared
	if board_drive != null:
		board_drive.text = profile.crazy_text()
	if board_mark != null:
		board_mark.text = profile.mark_text()
	if board_recent != null:
		board_recent.text = profile.results[0] if profile.results.size() > 0 else "NO ROUNDS YET"


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
	if kit_tab == "bowl":
		profile.bowl_color = index
		profile.set_slot(profile.bowl_slot, profile.bowl_skin, index)
	else:
		profile.disc_index = index
	profile.save_profile()
	if studio != null and kit_tab == "bowl":
		studio.refresh()
	_paint_kit()
	_sync_identity()


func _pick_skin(skin_id: String) -> void:
	if kit_tab == "bowl":
		if studio != null and studio.has_method("apply_theme"):
			studio.apply_theme(skin_id)
		else:
			profile.bowl_skin = skin_id
			profile.set_slot(profile.bowl_slot, skin_id, profile.bowl_color)
			profile.save_profile()
	else:
		if Kit.is_photo_skin(skin_id):
			return
		profile.disc_skin = skin_id
		profile.save_profile()
	_paint_kit()
	_sync_identity()


func _on_studio_changed() -> void:
	_paint_kit()
	_sync_identity()


func _build_photo_picker() -> void:
	if photo_picker != null:
		return
	photo_picker = FileDialog.new()
	photo_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	photo_picker.access = FileDialog.ACCESS_FILESYSTEM
	photo_picker.title = "Choose a photo"
	photo_picker.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Photos"])
	photo_picker.use_native_dialog = true
	photo_picker.size = Vector2i(720, 520)
	photo_picker.visible = false
	photo_picker.file_selected.connect(_on_photo_picked)
	root.add_child(photo_picker)


func _pick_photo(slot: String) -> void:
	_tap()
	photo_slot = slot
	kit_tab = "bowl"
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show(
			"Choose a photo",
			OS.get_system_dir(OS.SYSTEM_DIR_PICTURES),
			"",
			false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Photos"]),
			_on_native_photo
		)
		return
	_build_photo_picker()
	if photo_picker != null:
		photo_picker.popup_centered()


func _on_native_photo(status: bool, selected_paths: PackedStringArray, _filter_index: int) -> void:
	if not status or selected_paths.is_empty():
		return
	_on_photo_picked(selected_paths[0])


func _on_photo_picked(path: String) -> void:
	var image := Image.new()
	if image.load(path) != OK:
		return
	Kit.save_user_photo(photo_slot, image)
	if photo_slot == "b":
		profile.bowl_skin = "photo_split"
	elif not Kit.is_photo_skin(profile.bowl_skin):
		profile.bowl_skin = "photo_left"
	profile.save_profile()
	_paint_kit()
	_sync_identity()


func _paint_swatches() -> void:
	_paint_kit()


func _paint_kit() -> void:
	if profile == null:
		return
	var kit: Dictionary = profile.kit()
	if kit_preview_bowl != null:
		kit_preview_bowl.texture = Kit.preview(kit, false)
	if kit_preview_disc != null:
		kit_preview_disc.texture = Kit.preview(kit, true)
	if profile_bowl != null:
		profile_bowl.texture = Kit.preview(kit, false)
	var color_index: int = profile.bowl_color if kit_tab == "bowl" else profile.disc_index
	var pal: Dictionary = Kit.palette(color_index)
	var skin_id: String = profile.bowl_skin if kit_tab == "bowl" else profile.disc_skin
	var look: Dictionary = Kit.skin(skin_id)
	if kit_caption != null:
		kit_caption.text = "%s  ·  %s" % [look["name"], pal["name"]]
	if kit_bowl_tab != null:
		_paint_button(kit_bowl_tab, GOLD if kit_tab == "bowl" else PLUM, Color("#FFE9A0") if kit_tab == "bowl" else Color(1, 1, 1, 0.18), Color("#1A1208") if kit_tab == "bowl" else CREAM, 14, 8, 2 if kit_tab == "bowl" else 1)
	if kit_disc_tab != null:
		_paint_button(kit_disc_tab, GOLD if kit_tab == "disc" else PLUM, Color("#FFE9A0") if kit_tab == "disc" else Color(1, 1, 1, 0.18), Color("#1A1208") if kit_tab == "disc" else CREAM, 14, 8, 2 if kit_tab == "disc" else 1)
	if kit_skin_row != null:
		for i in kit_skin_row.get_child_count():
			var chip := kit_skin_row.get_child(i) as Button
			if chip == null:
				continue
			var id := str(chip.get_meta("skin_id")) if chip.has_meta("skin_id") else ""
			var mark := skin_id
			if studio != null and str(studio.picked_theme) != "" and Kit.is_photo_skin(skin_id):
				mark = str(studio.picked_theme)
			var on: bool = id == mark
			_paint_button(chip, GOLD if on else Color(0.07, 0.14, 0.30, 0.96), Color("#FFE9A0") if on else Color(1, 1, 1, 0.16), Color("#1A1208") if on else MUTED, 14, 6, 2 if on else 1)
			var orb := chip.find_child("Orb", true, false)
			if orb is TextureRect:
				var orb_kit := {
					"bowl_skin": id,
					"bowl_color": color_index,
					"disc_skin": id,
					"disc_color": color_index,
				}
				(orb as TextureRect).texture = Kit.preview(orb_kit, kit_tab != "bowl")
	var bowls := kit_tab == "bowl"
	if studio != null:
		studio.visible = bowls
	if disc_block != null:
		disc_block.visible = not bowls
	if look_panel != null:
		var host: Node = null
		if bowls and studio != null:
			host = studio.look_box
		elif disc_look_host != null:
			host = disc_look_host
		if host != null and look_panel.get_parent() != host:
			var old := look_panel.get_parent()
			if old != null:
				old.remove_child(look_panel)
			host.add_child(look_panel)
	if photo_kicker != null:
		photo_kicker.visible = false
	if photo_blurb != null:
		photo_blurb.visible = false
	if photo_a_button != null:
		photo_a_button.visible = false
	if photo_b_button != null:
		photo_b_button.visible = false
	if photo_place_row != null:
		photo_place_row.visible = false
	var selected: int = color_index
	for i in swatch_buttons.size():
		var swatch := swatch_buttons[i] as Button
		var border := Color("#FFE9A0") if i == selected else Color(1, 1, 1, 0.18)
		var swatch_pal: Dictionary = Kit.palette(i)
		var swatch_color: Color = swatch_pal["a"]
		_paint_button(swatch, swatch_color, border, CREAM, 22, 0, 3 if i == selected else 1)


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
			trail.add_theme_color_override("font_color", GOLD)


func _paint_nav(current: String) -> void:
	for i in nav_icons.size():
		var icon: Stamp = nav_icons[i]
		var caption := nav_captions[i] as Label
		var lit := icon.kind == current
		icon.set_lit(lit)
		caption.add_theme_color_override("font_color", CREAM if lit else Color("#7A9BC4"))
		if i < nav_glyphs.size():
			nav_glyphs[i].modulate = Color(1, 1, 1, 1.0 if lit else 0.72)
		if i < nav_buttons.size():
			var fill := Color(0.12, 0.32, 0.78, 0.38) if lit else Color(0, 0, 0, 0)
			var border := GOLD if lit else Color(0, 0, 0, 0)
			_paint_button(nav_buttons[i], fill, border, CREAM, 18, 0)


func _initial() -> String:
	var trimmed: String = str(profile.player_name).strip_edges()
	if trimmed == "":
		return "F"
	return trimmed.substr(0, 1).to_upper()


func _column_page(top: float, bottom: float, hub: bool = false) -> Dictionary:
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
	if hub:
		hub_page_margins.append(margin)
	return {"page": page, "box": box}


func _back_on(page: Control, target: String) -> void:
	var button := _button("‹  Back", 14)
	button.position = Vector2(16, 16)
	button.size = Vector2(110, 40)
	_paint_button(button, Color(0.06, 0.12, 0.24, 0.72), BLUE, CREAM, 18, 10)
	button.pressed.connect(_show.bind(target))
	page.add_child(button)
	var mark := _mark_rect()
	mark.position = Vector2(80, 2)
	mark.size = Vector2(380, 118)
	page.add_child(mark)


func _code_row() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(PLUM, GOLD, 1, 14, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	code_label = _label(room_code, 28, CREAM, title_font)
	code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(code_label)
	var copy := _button("COPY", 14)
	copy.custom_minimum_size = Vector2(96, 44)
	_paint_button(copy, BLUE_LIT, Color("#8EC4FF"), CREAM, 12, 8)
	copy.pressed.connect(_copy_code)
	row.add_child(copy)
	panel.add_child(row)
	return panel


func _rink_card(title: String, body: String, art_tex: Texture2D) -> Button:
	var button := Button.new()
	button.text = ""
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.custom_minimum_size = Vector2(150, 210)
	var tag := _label("SELECTED", 11, GOLD, bold_font)
	tag.name = "Tag"
	tag.position = Vector2(14, 8)
	tag.size = Vector2(216, 16)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(tag)
	var heading := _label(title, 20, CREAM, title_font)
	heading.position = Vector2(14, 26)
	heading.size = Vector2(216, 28)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(heading)
	var detail := _label(body, 13, MUTED, body_font)
	detail.position = Vector2(14, 52)
	detail.size = Vector2(216, 22)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(detail)
	var art := TextureRect.new()
	art.name = "Art"
	art.texture = art_tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(8, 76)
	art.size = Vector2(228, 122)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.add_child(art)
	return button


func _wide_card(title: String, body: String, trailing: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, 86)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_button(button, CARD, GOLD, CREAM, 16, 14)
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
	var trail := _label(trailing, 13, GOLD, bold_font)
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


func _shop_row(title: String, trailing: String, owned: bool, pal_index: int = 1) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_button(button, CARD, GOLD, CREAM, 16, 12, 2)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.offset_top = 10
	row.offset_bottom = -10
	var orb := TextureRect.new()
	orb.custom_minimum_size = Vector2(64, 64)
	orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.texture = Kit.preview({
		"bowl_skin": "both",
		"bowl_color": pal_index,
		"disc_skin": "both",
		"disc_color": pal_index,
	}, true)
	row.add_child(orb)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	var heading := _label(title, 16, CREAM, bold_font)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(heading)
	copy.add_child(_label("Round-board colour", 13, MUTED, body_font))
	row.add_child(copy)
	var badge := _label(trailing, 13, GOLD, bold_font)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(badge)
	button.add_child(row)
	button.pressed.connect(func() -> void:
		if owned:
			_toast("Match red is the disc you own.")
		else:
			_toast("Locked. Flick coins are not on this build.")
	)
	if not owned:
		button.modulate = Color(1, 1, 1, 0.82)
	return button


func _theme_orb(skin_id: String, caption: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(0, 92)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.set_meta("skin_id", skin_id)
	button.pressed.connect(_pick_skin.bind(skin_id))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 4
	col.offset_right = -4
	col.offset_top = 6
	col.offset_bottom = -6
	var orb := TextureRect.new()
	orb.name = "Orb"
	orb.custom_minimum_size = Vector2(56, 56)
	orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(orb)
	var label := _label(caption, 10, MUTED, bold_font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(label)
	button.add_child(col)
	return button


func _title(text: String) -> Label:
	var label := _label(text, 40, CREAM, title_font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _kicker(text: String) -> Label:
	return _label(text, 12, CREAM, bold_font)


func _glyph(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if emoji_font != null:
		label.add_theme_font_override("font", emoji_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", CREAM)
	return label


func _chip_row(page: Control, pos: Vector2, captions: PackedStringArray, pick: Callable) -> Array:
	var chips: Array = []
	var gap := 12.0
	var wide := (500.0 - gap * float(captions.size() - 1)) / float(captions.size())
	for i in captions.size():
		var button := _button(captions[i], 13)
		_place(page, button, Vector2(pos.x + float(i) * (wide + gap), pos.y), Vector2(wide, 48))
		var idx := i
		button.pressed.connect(func() -> void:
			_tap()
			pick.call(idx)
		)
		chips.append(button)
	return chips


func _paint_chips(chips: Array, current: int) -> void:
	for i in chips.size():
		if not chips[i].visible:
			continue
		var on := i == current
		var fill := BLUE_LIT if on else Color(0.07, 0.14, 0.30, 0.96)
		var border := Color("#8EC4FF") if on else Color(0.28, 0.48, 0.88, 0.45)
		_paint_button(chips[i], fill, border, CREAM, 14, 4, 2 if on else 1)


func _layout_chips(chips: Array, captions: PackedStringArray, pos: Vector2) -> void:
	var gap := 12.0
	var count := captions.size()
	if count <= 0:
		return
	var wide := (500.0 - gap * float(count - 1)) / float(count)
	for i in chips.size():
		var chip: Button = chips[i]
		if i < count:
			chip.visible = true
			chip.text = captions[i]
			chip.clip_text = true
			chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			# Min size first: a leftover 500px min from "4 ROUNDS" would
			# clamp size and stack 1 END under 4 ENDS.
			chip.custom_minimum_size = Vector2(wide, 48)
			chip.size = Vector2(wide, 48)
			chip.position = Vector2(pos.x + float(i) * (wide + gap), pos.y)
		else:
			chip.visible = false
			chip.custom_minimum_size = Vector2(0, 48)
			chip.size = Vector2(0, 48)


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
	button.custom_minimum_size = Vector2(0, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_button(button, PLUM, GOLD, CREAM, 16, 18, 2)
	button.pressed.connect(_tap)
	_chevron(button)
	if on_press.is_valid():
		button.pressed.connect(on_press)
	return button


func _primary(text: String, on_press: Callable) -> Button:
	var button := _button(text, 18)
	button.custom_minimum_size = Vector2(0, 68)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_button(button, GOLD, Color("#FFE9A0"), Color("#1A1208"), 18, 12, 2)
	button.add_theme_color_override("font_hover_color", Color("#1A1208"))
	button.add_theme_color_override("font_pressed_color", Color("#1A1208"))
	button.pressed.connect(_tap)
	button.pressed.connect(on_press)
	return button


func _chevron(button: Button) -> void:
	var mark := _label("›", 22, GOLD, bold_font)
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
	# Fire on the press. Waiting for release made a small finger move
	# cancel the tap, so it felt like the button clicked off.
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
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
	panel.add_theme_stylebox_override("panel", _flat(PLUM, GOLD, 1, 10, 0))
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


func _bowl_portrait() -> Texture2D:
	if bowl_tex != null:
		return bowl_tex
	var src: Image = null
	var packed: Texture2D = load("res://assets/bowls/textures/bowl_color_1.jpg")
	if packed != null:
		src = packed.get_image()
		if src != null and src.is_compressed():
			src.decompress()
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var light := Vector3(-0.32, 0.78, 0.54).normalized()
	var spec_dir := Vector3(-0.12, 0.62, 0.78).normalized()
	for y in size:
		for x in size:
			var nx := (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(size) * 2.0 - 1.0
			var sy := ny * 1.06
			var r2 := nx * nx + sy * sy
			if r2 > 1.0:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - r2))
			var n := Vector3(nx, -sy, nz).normalized()
			var wrap := 0.16 + 0.84 * clampf(n.dot(light), 0.0, 1.0)
			var spec := pow(clampf(n.dot(spec_dir), 0.0, 1.0), 32.0)
			var u := 0.5 + atan2(n.x, n.z) / TAU
			var v := 0.5 - asin(clampf(n.y, -1.0, 1.0)) / PI
			var col := Color("#1A3A88")
			if src != null and not src.is_empty():
				var px := Vector2i(
					posmod(int(u * float(src.get_width())), src.get_width()),
					posmod(int(v * float(src.get_height())), src.get_height())
				)
				col = src.get_pixelv(px)
			col = Color(col.r * wrap, col.g * wrap, col.b * wrap, 1.0)
			col = col.lerp(Color(0.95, 0.97, 1.0), spec * 0.58)
			var ring := absf(fmod(v * 7.0, 1.0) - 0.5)
			if ring < 0.055 and absf(n.y) < 0.62:
				col = col.lerp(Color(0.92, 0.94, 0.98), 0.28)
			var a := clampf((1.0 - r2) / 0.07, 0.0, 1.0)
			col.a = a
			img.set_pixel(x, y, col)
	bowl_tex = ImageTexture.create_from_image(img)
	return bowl_tex


func _place(parent: Control, node: Control, pos: Vector2, box: Vector2) -> void:
	node.position = pos
	node.size = box
	node.custom_minimum_size = box
	parent.add_child(node)


func _paint_button(button: Button, fill: Color, border: Color, font_color: Color, radius: int, side: int, width: int = 1) -> void:
	button.add_theme_stylebox_override("normal", _flat(fill, border, width, radius, side))
	button.add_theme_stylebox_override("hover", _flat(fill.lightened(0.12), border, width, radius, side))
	button.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.08), GOLD, width, radius, side))
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
	if radius >= 12 and fill.a > 0.5:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 3)
		style.anti_aliasing = true
	return style


func _style_edit(edit: LineEdit) -> void:
	edit.add_theme_font_override("font", bold_font)
	edit.add_theme_font_size_override("font_size", 18)
	edit.add_theme_color_override("font_color", CREAM)
	edit.add_theme_color_override("font_placeholder_color", Color("#8d7d88"))
	edit.add_theme_color_override("caret_color", GOLD)
	var box := _flat(PLUM, GOLD, 1, 14, 14)
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", _flat(PLUM, GOLD, 2, 14, 14))


class Stamp extends Control:
	var kind := "home"
	var lit := false

	func set_lit(value: bool) -> void:
		lit = value
		queue_redraw()

	func _draw() -> void:
		var box := size
		if box.x < 2.0:
			box = Vector2(52, 52)
		var mid := box * 0.5
		var r := minf(mid.x, mid.y) - 1.0
		var accent := Color("#F5C84B")
		var cream := Color("#F4F7FF")
		var grass := Color("#2E9A4A")
		var gold := Color("#F5C84B")
		var ink := Color("#07101C")
		var navy := Color("#163A88")
		draw_circle(mid, r, Color(navy.r, navy.g, navy.b, 0.95 if lit else 0.55))
		draw_circle(mid, r * 0.86, Color(0.04, 0.10, 0.22, 0.92 if lit else 0.72))
		draw_circle(mid + Vector2(-r * 0.22, -r * 0.28), r * 0.38, Color(1, 1, 1, 0.08))
		if lit:
			var ring := clampf(r * 0.07, 2.2, 3.4)
			draw_arc(mid, r - ring * 0.45, 0.0, TAU, 64, gold, ring, true)
		match kind:
			"home":
				_house(mid, r * 0.62, cream)
			"profile":
				_face(mid, r * 0.58, cream, accent)
			"customise":
				_bowl(mid, r * 0.58, cream, accent, ink)
			"shop":
				_bag(mid, r * 0.58, cream, gold)
			"settings":
				_gear(mid, r * 0.52, cream)
				draw_circle(mid, r * 0.18, ink)
				draw_circle(mid, r * 0.08, gold)
			"green", "lawn":
				_rink(mid, r * 0.7, grass, cream, Color("#E12A32"))
			"crazy":
				_crazy_stamp(mid, r * 0.7, grass, cream, gold)
			"solo":
				_target(mid, r * 0.62, cream, navy, gold)
			"practice":
				_jack(mid, r * 0.42, cream, gold)
			"board":
				_cup(mid, r * 0.62, gold, cream)
			"crokin":
				_board(mid, r * 0.68, cream, navy, gold)
			_:
				draw_circle(mid, r * 0.28, cream)

	func _house(mid: Vector2, span: float, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2(mid.x, mid.y - span),
			Vector2(mid.x + span, mid.y - span * 0.18),
			Vector2(mid.x - span, mid.y - span * 0.18),
		]), color)
		draw_rect(Rect2(mid.x - span * 0.62, mid.y - span * 0.18, span * 1.24, span * 0.92), color, true)
		draw_rect(Rect2(mid.x - span * 0.14, mid.y + span * 0.08, span * 0.28, span * 0.66), Color("#1A0610"), true)

	func _face(mid: Vector2, span: float, color: Color, pink: Color) -> void:
		draw_circle(Vector2(mid.x, mid.y - span * 0.38), span * 0.42, color)
		draw_colored_polygon(PackedVector2Array([
			Vector2(mid.x, mid.y - span * 0.05),
			Vector2(mid.x + span * 0.82, mid.y + span * 0.92),
			Vector2(mid.x - span * 0.82, mid.y + span * 0.92),
		]), color)
		draw_circle(Vector2(mid.x, mid.y + span * 0.55), span * 0.16, pink)

	func _bowl(mid: Vector2, span: float, cream: Color, pink: Color, ink: Color) -> void:
		draw_circle(mid, span, cream)
		draw_circle(mid, span * 0.72, ink)
		draw_circle(mid, span * 0.28, pink)
		draw_arc(mid, span * 0.88, -0.7, 1.1, 12, Color(1, 1, 1, 0.55), 2.4, true)

	func _bag(mid: Vector2, span: float, cream: Color, gold: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2(mid.x - span * 0.72, mid.y - span * 0.12),
			Vector2(mid.x + span * 0.72, mid.y - span * 0.12),
			Vector2(mid.x + span * 0.58, mid.y + span * 0.92),
			Vector2(mid.x - span * 0.58, mid.y + span * 0.92),
		]), cream)
		draw_arc(Vector2(mid.x, mid.y - span * 0.12), span * 0.42, PI, TAU, 14, cream, 3.0, true)
		draw_circle(mid + Vector2(0, span * 0.28), span * 0.16, gold)

	func _crazy_stamp(mid: Vector2, span: float, grass: Color, cream: Color, gold: Color) -> void:
		draw_rect(Rect2(mid.x - span * 0.82, mid.y - span * 0.92, span * 1.64, span * 1.84), Color("#163C22"), true)
		draw_rect(Rect2(mid.x - span * 0.58, mid.y - span * 0.86, span * 1.16, span * 1.68), grass, true)
		draw_circle(Vector2(mid.x + span * 0.12, mid.y - span * 0.28), span * 0.22, Color("#0A1208"))
		draw_circle(Vector2(mid.x + span * 0.12, mid.y - span * 0.28), span * 0.1, Color("#07101C"))
		draw_line(Vector2(mid.x + span * 0.12, mid.y - span * 0.48), Vector2(mid.x + span * 0.12, mid.y - span * 0.92), gold, 2.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(mid.x + span * 0.12, mid.y - span * 0.92),
			Vector2(mid.x + span * 0.58, mid.y - span * 0.78),
			Vector2(mid.x + span * 0.12, mid.y - span * 0.64),
		]), Color("#E12A32"))
		draw_circle(Vector2(mid.x - span * 0.22, mid.y + span * 0.42), span * 0.2, cream)

	func _rink(mid: Vector2, span: float, grass: Color, cream: Color, pink: Color) -> void:
		draw_rect(Rect2(mid.x - span * 0.72, mid.y - span * 0.92, span * 1.44, span * 1.84), Color("#163C22"), true)
		draw_rect(Rect2(mid.x - span * 0.28, mid.y - span * 0.88, span * 0.56, span * 1.72), grass, true)
		draw_rect(Rect2(mid.x - span * 0.22, mid.y - span * 0.78, span * 0.44, span * 1.52), Color("#1F6B34"), true)
		draw_circle(Vector2(mid.x, mid.y - span * 0.48), span * 0.14, cream)
		draw_circle(Vector2(mid.x - span * 0.08, mid.y + span * 0.18), span * 0.24, pink)
		draw_circle(Vector2(mid.x + span * 0.16, mid.y + span * 0.42), span * 0.22, Color("#2A6AD4"))
		draw_arc(Vector2(mid.x - span * 0.08, mid.y + span * 0.18), span * 0.24, -0.6, 1.2, 10, Color(1, 1, 1, 0.45), 1.8, true)

	func _target(mid: Vector2, span: float, cream: Color, pink: Color, gold: Color) -> void:
		draw_circle(mid, span, cream)
		draw_circle(mid, span * 0.72, pink)
		draw_circle(mid, span * 0.46, cream)
		draw_circle(mid, span * 0.22, gold)

	func _jack(mid: Vector2, span: float, cream: Color, gold: Color) -> void:
		draw_circle(mid, span, cream)
		draw_circle(mid, span * 0.62, gold)
		draw_arc(mid + Vector2(-span * 0.15, -span * 0.55), span * 1.15, -0.2, 1.4, 10, Color("#FF8A3A"), 3.2, true)
		draw_arc(mid + Vector2(span * 0.2, -span * 0.7), span * 1.05, 1.8, 3.2, 10, Color("#FF5C2A"), 2.6, true)

	func _cup(mid: Vector2, span: float, gold: Color, cream: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2(mid.x - span * 0.55, mid.y - span * 0.55),
			Vector2(mid.x + span * 0.55, mid.y - span * 0.55),
			Vector2(mid.x + span * 0.28, mid.y + span * 0.22),
			Vector2(mid.x - span * 0.28, mid.y + span * 0.22),
		]), gold)
		draw_rect(Rect2(mid.x - span * 0.12, mid.y + span * 0.18, span * 0.24, span * 0.38), gold, true)
		draw_rect(Rect2(mid.x - span * 0.38, mid.y + span * 0.52, span * 0.76, span * 0.16), cream, true)
		draw_arc(Vector2(mid.x - span * 0.55, mid.y - span * 0.22), span * 0.32, PI * 0.45, PI * 1.45, 10, gold, 2.6, true)
		draw_arc(Vector2(mid.x + span * 0.55, mid.y - span * 0.22), span * 0.32, -PI * 0.45, PI * 0.55, 10, gold, 2.6, true)

	func _board(mid: Vector2, span: float, cream: Color, pink: Color, gold: Color) -> void:
		draw_circle(mid, span, Color("#7A3A18"))
		draw_circle(mid, span * 0.78, Color("#C4783A"))
		draw_circle(mid, span * 0.52, cream)
		draw_circle(mid, span * 0.28, pink)
		draw_circle(mid, span * 0.12, gold)

	func _gear(mid: Vector2, radius: float, color: Color) -> void:
		var pts := PackedVector2Array()
		for i in 16:
			var ang := float(i) * TAU / 16.0 - PI * 0.5
			var r := radius if i % 2 == 0 else radius * 0.62
			pts.append(mid + Vector2(cos(ang), sin(ang)) * r)
		draw_colored_polygon(pts, color)
