extends CanvasLayer

signal reset_requested
signal next_level_requested
signal bias_cycle_requested
signal stop_requested
signal mode_requested(mode_name: String)
signal leave_requested

var status_label: Label
var score_label: Label
var level_label: Label
var throws_label: Label
var reset_button: Button
var next_button: Button
var bias_button: Button
var stop_button: Button
var power_fill: ColorRect
var current_bias := 0.0
var overview: Control
var overview_panel: ColorRect
var overview_title: Label
var overview_rules: Label
var overview_body: RichTextLabel
var _count_token := 0

func _ready() -> void:
	_make_scrim(Rect2(0.0, 0.0, 540.0, 108.0), Color(0.03, 0.02, 0.04, 0.72))

	var menu_button := _make_button("MENU", Vector2(16.0, 10.0), Vector2(104.0, 32.0))
	menu_button.add_theme_stylebox_override("normal", _button_style(Color("#ff4d9a"), Color("#ffd0e8")))
	menu_button.add_theme_color_override("font_color", Color("#1a0a12"))
	menu_button.pressed.connect(func() -> void: leave_requested.emit())
	level_label = _make_label(Vector2(300.0, 10.0), Vector2(216.0, 22.0), 16, Color("#f7fbff"), "LEVEL 01")
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	throws_label = _make_label(Vector2(300.0, 34.0), Vector2(216.0, 18.0), 12, Color("#8fd7ea"), "8 DISCS")
	throws_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	status_label = _make_label(Vector2(22.0, 58.0), Vector2(496.0, 22.0), 13, Color("#d9f5e8"), "")
	score_label = _make_label(Vector2(22.0, 80.0), Vector2(496.0, 20.0), 11, Color("#8fc9bf"), "")

	reset_button = _make_button("RESET", Vector2(128.0, 10.0), Vector2(96.0, 32.0))
	reset_button.pressed.connect(func() -> void: reset_requested.emit())

	next_button = _make_button("NEXT END", Vector2(150.0, 852.0), Vector2(240.0, 48.0))
	next_button.pressed.connect(func() -> void: next_level_requested.emit())
	next_button.visible = false

	stop_button = _make_button("STOP", Vector2(144.0, 852.0), Vector2(250.0, 40.0))
	stop_button.add_theme_font_size_override("font_size", 20)
	stop_button.add_theme_stylebox_override("normal", _button_style(Color("#ff2f86"), Color("#ffd0e8")))
	stop_button.add_theme_stylebox_override("hover", _button_style(Color("#ff5aa3"), Color("#ffe4f2")))
	stop_button.add_theme_stylebox_override("pressed", _button_style(Color("#c41068"), Color("#ffd0e8")))
	stop_button.add_theme_color_override("font_color", Color("#fff7fb"))
	stop_button.add_theme_color_override("font_hover_color", Color("#fff7fb"))
	stop_button.add_theme_color_override("font_pressed_color", Color("#fff7fb"))
	stop_button.pressed.connect(func() -> void: stop_requested.emit())
	stop_button.visible = false
	next_button.text = "NEXT END"
	_build_overview()

func show_touch(level_number: int, discs_left: int, you_board: int = 0, far_board: int = 0, match_you: int = 0, match_them: int = 0) -> void:
	hide_overview()
	status_label.text = "TOUCH TO AIM  •  TAP THE DISC TO LOCK"
	show_match_status(level_number, discs_left, you_board, far_board, match_you, match_them)
	reset_button.text = "RESET"
	reset_button.visible = true
	next_button.visible = false
	_show_stop(false)
	show_power(0.0)

func show_sliding() -> void:
	status_label.text = "TOUCH TO AIM  •  TAP THE DISC TO LOCK"


func show_aim_ready() -> void:
	status_label.text = "TAP THE DISC TO LOCK"

func show_take() -> void:
	status_label.text = "PULL THE PUCK  •  RELEASE ON THE GREEN"
	_show_stop(false)

func show_lane(level_number: int, discs_left: int, difficulty: String = "", you_board: int = 0, far_board: int = 0, match_you: int = 0, match_them: int = 0) -> void:
	show_touch(level_number, discs_left, you_board, far_board, match_you, match_them)

func show_stopped() -> void:
	show_take()

func _show_stop(_rolling: bool) -> void:
	if stop_button != null:
		stop_button.visible = false

func show_ready(level_number: int, discs_left: int, difficulty: String = "", you_board: int = 0, far_board: int = 0, match_you: int = 0, match_them: int = 0) -> void:
	hide_overview()
	var layout := difficulty.to_upper() if difficulty != "" else "CROKINOLE"
	status_label.text = "LEVEL %02d  •  %s  •  TAP YOUR DISC" % [level_number, layout]
	show_match_status(level_number, discs_left, you_board, far_board, match_you, match_them)
	reset_button.text = "RESET"
	reset_button.visible = true
	next_button.visible = false

func show_match_status(level_number: int, discs_left: int, you_board: int = 0, far_board: int = 0, match_you: int = 0, match_them: int = 0) -> void:
	level_label.text = "LEVEL %02d" % level_number
	if discs_left <= 0:
		throws_label.text = "END"
	else:
		throws_label.text = "%d LEFT" % discs_left
	score_label.text = "BOARD %d–%d    MATCH %d–%d" % [you_board, far_board, match_you, match_them]

func show_aiming(_power_ratio: float) -> void:
	status_label.text = "RELEASE ON THE GREEN"

func show_power(_ratio: float) -> void:
	pass

func show_in_motion() -> void:
	_show_stop(false)
	status_label.text = "IN FLIGHT  •  PEGS AND DISCS ARE LIVE"

func show_landed(shot_points: int, sunk: bool, ditched: bool) -> void:
	if sunk:
		status_label.text = "20 IN THE HOLE"
	elif shot_points > 0:
		status_label.text = "LANDED FOR %d" % shot_points
	elif ditched:
		status_label.text = "IN THE DITCH  •  NO POINTS"
	else:
		status_label.text = "ON THE LINE  •  NO POINTS"
	next_button.visible = false

func hide_overview() -> void:
	_count_token += 1
	if overview != null:
		overview.visible = false

func show_end_overview(end_number: int, layout_name: String, you_items: Array, them_items: Array, award_you: int, award_them: int, match_you: int, match_them: int, match_target: int, has_next: bool) -> void:
	_count_token += 1
	var token := _count_token
	_show_stop(false)
	overview.visible = true
	overview_title.text = "END %d" % end_number
	overview_rules.text = "%s\n20 IN THE HOLE   •   15   •   10   •   5\nA DISC ON A LINE SCORES THE LOWER RING.\nTHE END SCORES THE DIFFERENCE." % layout_name.to_upper()
	overview_body.text = ""
	_set_overview_height(230.0)
	status_label.text = "END %d  •  COUNTING THE BOARD" % end_number
	reset_button.text = "REPLAY"
	reset_button.visible = true
	next_button.visible = false
	_play_end_count(token, end_number, you_items, them_items, award_you, award_them, match_you, match_them, match_target, has_next)

func show_bias(value: float) -> void:
	current_bias = value

func show_opponent() -> void:
	status_label.text = "OPPONENT TO PLAY"

func _play_end_count(token: int, end_number: int, you_items: Array, them_items: Array, award_you: int, award_them: int, match_you: int, match_them: int, match_target: int, has_next: bool) -> void:
	var built := ""
	built = await _count_side(token, built, "YOUR DISCS", you_items)
	if token != _count_token:
		return
	built = await _count_side(token, built, "FAR SIDE", them_items)
	if token != _count_token:
		return
	await get_tree().create_timer(0.4).timeout
	if token != _count_token:
		return
	var verdict := "END IS LEVEL    +0"
	if award_you > 0:
		verdict = "YOU TAKE THE END    +%d" % award_you
	elif award_them > 0:
		verdict = "FAR SIDE TAKES THE END    +%d" % award_them
	var match_line := "[color=#ffe27a]%s[/color]\n\n[color=#f7fbff]MATCH TO %d[/color]\n[color=#f7fbff]YOU %d[/color]          [color=#8fd7ea]FAR %d[/color]" % [verdict, match_target, match_you, match_them]
	if match_you >= match_target and match_you >= match_them:
		match_line += "\n[color=#ffe27a]YOU WIN THE MATCH[/color]"
	elif match_them >= match_target and match_them > match_you:
		match_line += "\n[color=#ffe27a]FAR SIDE WINS THE MATCH[/color]"
	overview_body.text = built + match_line
	await _fit_overview()
	if token != _count_token:
		return
	status_label.text = "END %d  •  %s" % [end_number, verdict]
	next_button.visible = has_next
	next_button.text = "NEXT END"

func _count_side(token: int, built: String, title: String, items: Array) -> String:
	var block := "[color=#9fd8cc]%s[/color]\n" % title
	if items.is_empty():
		block += "[color=#d7e7df]NONE ON THE BOARD[/color]\n[color=#f7fbff]= 0[/color]"
		overview_body.text = built + block
		await get_tree().create_timer(0.4).timeout
		await _fit_overview()
		return built + block + "\n\n"
	var chips := ""
	var total := 0
	for value in items:
		if token != _count_token:
			return built
		await get_tree().create_timer(0.4).timeout
		if token != _count_token:
			return built
		var points := int(value)
		total += points
		if chips != "":
			chips += "   +   "
		chips += "[color=%s]%d[/color]" % [_point_color(points), points]
		overview_body.text = built + block + chips + "\n[color=#f7fbff]= %d[/color]" % total
		await _fit_overview()
	return built + block + chips + "\n[color=#f7fbff]= %d[/color]\n\n" % total

func _point_color(points: int) -> String:
	if points >= 20:
		return "#ffe27a"
	if points >= 15:
		return "#ff8ec4"
	if points >= 10:
		return "#8fd7ea"
	return "#d7e7df"

func _build_overview() -> void:
	overview = Control.new()
	overview.position = Vector2(24.0, 124.0)
	overview.size = Vector2(492.0, 700.0)
	overview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overview.clip_contents = true
	overview.visible = false
	add_child(overview)

	overview_panel = ColorRect.new()
	overview_panel.size = overview.size
	overview_panel.color = Color(0.035, 0.07, 0.1, 0.94)
	overview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overview.add_child(overview_panel)

	var accent := ColorRect.new()
	accent.position = Vector2(0.0, 0.0)
	accent.size = Vector2(492.0, 4.0)
	accent.color = Color("#ff2f9a")
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overview.add_child(accent)

	overview_title = _owned_label(overview, Vector2(20.0, 16.0), Vector2(452.0, 36.0), 28, Color("#f7fbff"))
	overview_rules = _owned_label(overview, Vector2(20.0, 56.0), Vector2(452.0, 78.0), 12, Color("#9fd8cc"))
	overview_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	overview_body = RichTextLabel.new()
	overview_body.position = Vector2(20.0, 142.0)
	overview_body.size = Vector2(452.0, 520.0)
	overview_body.bbcode_enabled = true
	overview_body.scroll_active = false
	overview_body.fit_content = true
	overview_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overview_body.add_theme_font_size_override("normal_font_size", 20)
	overview_body.add_theme_color_override("default_color", Color("#f7fbff"))
	overview.add_child(overview_body)

func _fit_overview() -> void:
	await get_tree().process_frame
	if overview == null or overview_body == null:
		return
	var height := overview_body.position.y + overview_body.get_content_height() + 28.0
	_set_overview_height(clampf(height, 240.0, 700.0))

func _set_overview_height(height: float) -> void:
	overview.size.y = height
	if overview_panel != null:
		overview_panel.size.y = height

func _owned_label(parent: Control, label_position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _bias_name() -> String:
	if current_bias < -0.5:
		return "LEFT"
	if current_bias > 0.5:
		return "RIGHT"
	return "CENTER"

func _make_scrim(rect: Rect2, color: Color) -> void:
	var panel := ColorRect.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.color = color
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

func _make_label(label_position: Vector2, label_size: Vector2, font_size: int, color: Color, text: String) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _make_button(button_text: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("#e9fbff"))
	button.add_theme_color_override("font_hover_color", Color("#07131e"))
	button.add_theme_color_override("font_pressed_color", Color("#07131e"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#123849"), Color("#397d88")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#6bd9e6"), Color("#baf7f2")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#f3bd56"), Color("#ffe9a4")))
	add_child(button)
	return button

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style
