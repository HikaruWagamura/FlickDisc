class_name UIManager
extends CanvasLayer

const BowlScript := preload("res://scripts/bowl.gd")
const BiasChipScript := preload("res://scripts/bias_chip.gd")
const HandSwitchScript := preload("res://scripts/hand_switch.gd")
const HUD_FONT := preload("res://assets/fonts/Inter-Bold.ttf")

signal reset_requested
signal next_level_requested
signal bias_cycle_requested
signal ditch_option_requested
signal match_cycle_requested
signal hand_selected(forehand: bool)
signal bias_selected(index: int)
signal dial_pull(pull: Vector2)
signal dial_released(pull: Vector2)
signal mode_requested(mode_name: String)
signal leave_requested
signal camera_requested

var status_label: Label
var score_label: Label
var level_label: Label
var throws_label: Label
var reset_button: Button
var next_button: Button
var ditch_button: Button
var aim_dial: Control
var power_track: Panel
var power_cap: Panel
var power_label: Label
var match_button: Button
var camera_button: Button
var camera_chase := true
var hand_bar: Panel
var hand_label: Label
var fore_button: Button
var back_button: Button
var turn_mark: Control
var bias_buttons: Array = []
var bias_rail: Control
var hand_switch: Control
var bias_team := 0
var summary: Panel
var summary_title: Label
var summary_shots: Label
var summary_detail: Label
var power_fill: TextureRect
var power_max: Label
var current_bias := 0.0

const POWER_WIDTH := 250.0


func _ready() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.color = Color(1, 1, 1, 1)
	var scrim_mat := ShaderMaterial.new()
	scrim_mat.shader = load("res://shaders/hud_scrim.gdshader")
	scrim.material = scrim_mat
	add_child(scrim)

	var menu_button := _make_button("MENU", Vector2(16.0, 14.0), Vector2(96.0, 40.0))
	menu_button.add_theme_font_size_override("font_size", 14)
	_paint_sync(menu_button, true)
	menu_button.pressed.connect(func() -> void: leave_requested.emit())

	level_label = _make_label(Vector2(340.0, 18.0), Vector2(180.0, 26.0), 16, Color(0.96, 0.99, 0.97))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	throws_label = _make_label(Vector2(340.0, 44.0), Vector2(180.0, 22.0), 13, Color(0.55, 0.86, 0.9))
	throws_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	ditch_button = _make_button("REBOUND", Vector2(280.0, 62.0), Vector2(148.0, 40.0))
	ditch_button.add_theme_font_size_override("font_size", 13)
	_paint_sync(ditch_button, false)
	ditch_button.pressed.connect(func() -> void: ditch_option_requested.emit())

	match_button = _make_button("4 ENDS", Vector2(16.0, 62.0), Vector2(118.0, 40.0))
	match_button.add_theme_font_size_override("font_size", 13)
	_paint_sync(match_button, false)
	match_button.pressed.connect(func() -> void: match_cycle_requested.emit())

	camera_button = _make_button("FOLLOW", Vector2(144.0, 62.0), Vector2(124.0, 40.0))
	camera_button.add_theme_font_size_override("font_size", 13)
	camera_button.pressed.connect(func() -> void: camera_requested.emit())
	show_camera_mode(false)
	_build_summary()

	status_label = _make_label(Vector2(18.0, 116.0), Vector2(504.0, 22.0), 14, Color(0.95, 0.99, 0.96))
	score_label = _make_label(Vector2(18.0, 140.0), Vector2(504.0, 20.0), 13, Color(0.78, 0.92, 0.86))

	_build_aim_dial()
	_build_bias_row()
	_build_hand_bar()
	_build_power_meter()

	reset_button = _make_button("RESET", Vector2(122.0, 14.0), Vector2(96.0, 40.0))
	reset_button.add_theme_font_size_override("font_size", 14)
	_paint_sync(reset_button, false)
	reset_button.pressed.connect(func() -> void: reset_requested.emit())

	next_button = _make_button("NEXT END", Vector2(150.0, 888.0), Vector2(240.0, 48.0))
	next_button.pressed.connect(func() -> void: next_level_requested.emit())
	next_button.visible = false


func set_power_ratio(power_ratio: float) -> void:
	if power_fill == null:
		return
	var ratio := clampf(power_ratio, 0.0, 1.0)
	var inner := 500.0
	if power_track != null:
		inner = power_track.size.y - 20.0
	var tall := maxf(inner * ratio, 4.0)
	power_fill.size = Vector2(16.0, tall)
	power_fill.position = Vector2(8.0, 10.0 + inner - tall)
	_paint_power_fill(ratio)
	if power_cap != null:
		power_cap.visible = true
		var heat := Color(0.36, 1.0, 0.95).lerp(Color(1.0, 0.12, 0.18), smoothstep(0.35, 1.0, ratio))
		var cap := StyleBoxFlat.new()
		cap.bg_color = heat.lerp(Color(1.0, 0.96, 0.94), 0.35)
		cap.border_color = heat
		cap.set_border_width_all(3)
		cap.set_corner_radius_all(14)
		cap.shadow_color = Color(heat.r, heat.g, heat.b, 0.45)
		cap.shadow_size = 8
		power_cap.add_theme_stylebox_override("panel", cap)
		power_cap.position = Vector2(-2.0, power_fill.position.y - 8.0)
	if power_max != null:
		power_max.visible = ratio >= 0.94
		if power_max.visible:
			var pulse := 0.72 + 0.28 * sin(Time.get_ticks_msec() * 0.012)
			power_max.self_modulate = Color(1.0, 0.22, 0.28, pulse)


func show_jack_prompt(end_number: int, match_label: String, score_line: String) -> void:
	level_label.text = "END %d" % end_number
	throws_label.text = "4 EACH"
	status_label.text = "DRAG THE JACK BACK  •  LET GO TO BOWL"
	score_label.text = "%s  •  %s" % [match_label, score_line]
	reset_button.visible = true
	next_button.visible = false
	show_bowl_controls(false)
	hide_summary()
	set_power_ratio(0.0)


func show_match(match_label: String) -> void:
	match_button.text = match_label


func show_ditch_mode(enabled: bool) -> void:
	ditch_button.text = "DITCH ON" if enabled else "REBOUND"


func show_camera_mode(chase: bool) -> void:
	camera_chase = chase
	if camera_button == null:
		return
	camera_button.text = "FOLLOWING" if chase else "FOLLOW"
	if chase:
		_paint_selected(camera_button)
	else:
		_paint_sync(camera_button, false)


func show_place_line(jack: bool) -> void:
	if jack:
		status_label.text = "DRAG THE JACK BACK  •  LET GO TO BOWL"
	else:
		status_label.text = "DRAG THE BOWL BACK  •  LET GO TO BOWL"


func show_sliding(jack: bool) -> void:
	show_place_line(jack)


func show_aiming_line(jack: bool) -> void:
	show_place_line(jack)


func show_drag(metres: float, long_green: bool) -> void:
	var reach := int(round(metres))
	if long_green:
		status_label.text = "DRAG BACK  •  ABOUT %d m" % reach
	else:
		status_label.text = "THE LINE IS YOUR DRAG  •  ABOUT %d m" % reach


func show_aim_ready(jack: bool) -> void:
	if jack:
		status_label.text = "DRAG THE JACK BACK  •  LET GO TO BOWL"
	else:
		status_label.text = "DRAG THE BOWL BACK  •  LET GO TO BOWL"


func show_take_shot(_jack: bool = false) -> void:
	status_label.text = "DRAG THE BOWL BACK  •  LET GO TO BOWL"


func show_jack_aim(_power_ratio: float) -> void:
	status_label.text = "LET GO TO BOWL"


func show_jack_running() -> void:
	status_label.text = "JACK RUNNING"
	score_label.text = "FOLLOWING THE JACK" if camera_chase else "DOWN THE LINE"


func show_jack_illegal(reason: String, travelled: float, detail: String) -> void:
	throws_label.text = "JACK"
	status_label.text = reason
	score_label.text = "%.1f m  •  %s" % [travelled, detail]


func show_jack_set(travelled: float, bowl_name: String, side_name: String) -> void:
	throws_label.text = "4 EACH"
	status_label.text = "JACK AT %.1f m" % travelled
	score_label.text = "%s TO BOWL  •  %s" % [side_name, bowl_name]
	show_bowl_controls(true)
	set_power_ratio(0.0)


func show_aiming(_power_ratio: float) -> void:
	status_label.text = "LET GO TO BOWL"


func show_drive_prompt(left: int, longest: float, best_miss: float) -> void:
	level_label.text = "LONG GREEN"
	throws_label.text = "%d BOWLS" % left
	status_label.text = "DRAG BACK  •  FIND THE MARK"
	var far := "NO DRIVE YET" if longest < 1.0 else "LONGEST  %d m" % int(round(longest))
	var near := "MARK IS OUT THERE" if best_miss > 500.0 else "BEST MARK  %.1f m" % best_miss
	score_label.text = "%s  •  %s" % [far, near]
	hide_summary()
	next_button.visible = false
	show_bowl_controls(true)


func show_drive_result(travelled: float, miss: float, left: int, in_ditch: bool) -> void:
	throws_label.text = "%d LEFT" % left
	if in_ditch:
		status_label.text = "IN THE DITCH  •  %d m" % int(round(travelled))
	else:
		status_label.text = "%d m  •  %.1f m FROM THE MARK" % [int(round(travelled)), miss]
	score_label.text = "THE MARK STAYS FOR THIS ROUND"


func show_drive_done(longest: float, best_miss: float) -> void:
	summary.visible = true
	summary_title.text = "THE LONG GREEN"
	summary_shots.text = "%d m" % int(round(longest))
	summary_detail.text = "LONGEST BOWL\nNEAREST MARK  %.1f m" % best_miss
	status_label.text = "ROUND COMPLETE"
	score_label.text = "TRY ANOTHER THREE"
	next_button.text = "NEW ROUND"
	next_button.visible = true
	reset_button.visible = true
	show_bowl_controls(false)


func show_solo_prompt(end_number: int, end_count: int, end_name: String, blurb: String) -> void:
	level_label.text = "END %d / %d" % [end_number, end_count]
	throws_label.text = "ONE BOWL"
	status_label.text = end_name
	score_label.text = blurb
	hide_summary()
	next_button.visible = false
	show_bowl_controls(true)


func show_solo_result(won: bool, end_name: String, miss: float, in_ditch: bool) -> void:
	summary.visible = true
	summary_title.text = end_name
	if in_ditch:
		summary_shots.text = "DITCH"
		summary_detail.text = "That bowl is dead.\nDrag again."
	elif won:
		summary_shots.text = "SHOT"
		summary_detail.text = "Your bowl is closest.\n%.2f m from the jack." % miss
	else:
		summary_shots.text = "SHORT"
		summary_detail.text = "Theirs is closer.\nYou finished %.2f m off." % miss
	status_label.text = "END WON" if won else "HAVE ANOTHER GO"
	score_label.text = "ONE BOWL  •  BE THE SHOT"
	next_button.text = "NEXT END" if won else "TRY AGAIN"
	next_button.visible = true
	reset_button.visible = true
	show_bowl_controls(false)


func show_in_motion(side_name: String, bowl_name: String, forehand: bool, score_line: String) -> void:
	throws_label.text = score_line
	status_label.text = "%s  •  %s  •  %s" % [side_name, bowl_name, "FOREHAND" if forehand else "BACKHAND"]
	score_label.text = "FOLLOWING THE BOWL" if camera_chase else "DOWN THE LINE"


func show_computer(side_name: String, left: int) -> void:
	throws_label.text = "%s %d LEFT" % [side_name, left]
	status_label.text = "COMPUTER  •  %s BOWL" % side_name
	score_label.text = "DRAWING TO THE JACK"
	show_bowl_controls(false)


func show_contact(hit_jack: bool) -> void:
	status_label.text = "JACK STRUCK" if hit_jack else "BOWLS MEET"


func show_throw_result(disc_distance: float, closest: float, next_side: String, jack_moved: bool, in_ditch: bool, respotted: bool, spares: int, score_line: String) -> void:
	throws_label.text = score_line
	if in_ditch:
		status_label.text = "IN THE DITCH"
	else:
		status_label.text = "AT REST  •  THIS BOWL %.2f m" % disc_distance
	var note := ""
	if respotted:
		note = "  •  JACK RE-SPOTTED  •  SPARES %d" % spares
	elif jack_moved:
		note = "  •  JACK MOVED"
	if closest < 0.0:
		score_label.text = "%s TO BOWL  •  NO BOWL ON THE GREEN%s" % [next_side, note]
	else:
		score_label.text = "%s TO BOWL  •  CLOSEST %.2f m%s" % [next_side, closest, note]


func show_end_summary(end_number: int, side_name: String, shots: int, closest: float, score_line: String, match_over: bool) -> void:
	summary.visible = true
	if match_over:
		summary_title.text = "MATCH"
	else:
		summary_title.text = "END %d" % end_number
	if shots <= 0:
		summary_shots.text = "TIED END"
	elif shots == 1:
		summary_shots.text = "%s  1" % side_name
	else:
		summary_shots.text = "%s  %d" % [side_name, shots]
	var nearest := "NO BOWL ON THE GREEN"
	if closest >= 0.0:
		nearest = "CLOSEST  %.2f m" % closest
	summary_detail.text = "%s\n%s" % [nearest, score_line]
	throws_label.text = score_line
	status_label.text = "MATCH COMPLETE" if match_over else "END COMPLETE"
	score_label.text = score_line
	next_button.text = "NEW MATCH" if match_over else "NEXT END"
	next_button.visible = true
	reset_button.visible = true
	show_bowl_controls(false)


func hide_summary() -> void:
	if summary != null:
		summary.visible = false


func show_hand(forehand: bool, bowl_name: String) -> void:
	current_bias = -1.0 if forehand else 1.0
	if hand_switch != null and hand_switch.has_method("set_forehand"):
		hand_switch.set_forehand(forehand)
	if score_label != null and "TO BOWL" in score_label.text:
		var side := score_label.text.split(" TO BOWL")[0]
		score_label.text = "%s TO BOWL  •  %s" % [side, bowl_name]


func show_bias(index: int, team: int = -1) -> void:
	if team >= 0:
		bias_team = team % 2
	for i in bias_buttons.size():
		var chip = bias_buttons[i]
		if chip.has_method("set_chip"):
			chip.set_chip(i, bias_team, BowlScript.chip_texture(bias_team, i), i == index)


func show_bowl_controls(enabled: bool) -> void:
	if bias_rail != null:
		bias_rail.visible = enabled
	if hand_switch != null:
		hand_switch.visible = enabled
	if fore_button != null:
		fore_button.visible = false
	for chip in bias_buttons:
		chip.visible = enabled


func _hand_name() -> String:
	return "FOREHAND" if current_bias < 0.0 else "BACKHAND"


func _build_power_meter() -> void:
	power_track = Panel.new()
	power_track.position = Vector2(500.0, 148.0)
	power_track.size = Vector2(32.0, 520.0)
	power_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.05, 0.03, 0.12, 0.88)
	track.border_color = Color(0.72, 0.42, 1.0, 0.95)
	track.set_border_width_all(2)
	track.set_corner_radius_all(16)
	track.shadow_color = Color(0.55, 0.18, 1.0, 0.32)
	track.shadow_size = 8
	power_track.add_theme_stylebox_override("panel", track)
	power_track.clip_contents = false
	add_child(power_track)
	for tick in 5:
		var mark := ColorRect.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.color = Color(1.0, 1.0, 1.0, 0.18)
		mark.size = Vector2(10.0, 2.0)
		mark.position = Vector2(11.0, 18.0 + float(tick) * 96.0)
		power_track.add_child(mark)
	power_fill = TextureRect.new()
	power_fill.position = Vector2(8.0, 10.0)
	power_fill.size = Vector2(16.0, 4.0)
	power_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	power_fill.stretch_mode = TextureRect.STRETCH_SCALE
	power_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_track.add_child(power_fill)
	_paint_power_fill(0.0)
	power_cap = Panel.new()
	power_cap.size = Vector2(28.0, 28.0)
	power_cap.position = Vector2(-2.0, 490.0)
	power_cap.visible = true
	power_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := StyleBoxFlat.new()
	cap.bg_color = Color(0.85, 1.0, 1.0)
	cap.border_color = Color(0.36, 1.0, 0.95)
	cap.set_border_width_all(3)
	cap.set_corner_radius_all(14)
	power_cap.add_theme_stylebox_override("panel", cap)
	power_track.add_child(power_cap)
	power_label = Label.new()
	power_label.text = "POWER"
	power_label.position = Vector2(478.0, 672.0)
	power_label.size = Vector2(76.0, 18.0)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.add_theme_font_override("font", HUD_FONT)
	power_label.add_theme_font_size_override("font_size", 11)
	power_label.add_theme_color_override("font_color", Color(0.92, 0.82, 1.0, 0.95))
	power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(power_label)
	power_max = Label.new()
	power_max.text = "MAX"
	power_max.position = Vector2(-22.0, -24.0)
	power_max.size = Vector2(76.0, 22.0)
	power_max.visible = false
	power_max.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_max.add_theme_font_override("font", HUD_FONT)
	power_max.add_theme_font_size_override("font_size", 14)
	power_max.add_theme_color_override("font_color", Color(1.0, 0.22, 0.32))
	power_max.add_theme_color_override("font_outline_color", Color(0.18, 0.02, 0.06, 0.85))
	power_max.add_theme_constant_override("outline_size", 4)
	power_max.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_track.add_child(power_max)


func _paint_power_fill(ratio: float) -> void:
	if power_fill == null:
		return
	var gradient := Gradient.new()
	var cyan := Color(0.22, 0.95, 1.0)
	var violet := Color(0.78, 0.28, 1.0)
	var red := Color(1.0, 0.12, 0.18)
	gradient.set_color(0, cyan)
	if ratio < 0.45:
		gradient.set_color(gradient.get_point_count() - 1, cyan.lerp(violet, clampf(ratio / 0.45, 0.0, 1.0)))
	else:
		gradient.add_point(0.42, violet)
		gradient.set_color(gradient.get_point_count() - 1, violet.lerp(red, clampf((ratio - 0.45) / 0.55, 0.0, 1.0)))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 16
	texture.height = 256
	texture.fill_from = Vector2(0.5, 1.0)
	texture.fill_to = Vector2(0.5, 0.0)
	power_fill.texture = texture


func _build_aim_dial() -> void:
	var dial := preload("res://scripts/aim_dial.gd").new()
	dial.name = "AimDial"
	dial.position = Vector2(412.0, 600.0)
	dial.size = Vector2(118.0, 118.0)
	add_child(dial)
	aim_dial = dial
	dial.visible = false
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_bias_row() -> void:
	bias_rail = Control.new()
	bias_rail.position = Vector2(400.0, 168.0)
	bias_rail.size = Vector2(76.0, 400.0)
	bias_rail.visible = false
	bias_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bias_rail)
	for i in 4:
		var chip := BiasChipScript.new()
		chip.position = Vector2(2.0, float(i) * 98.0)
		chip.size = Vector2(72.0, 96.0)
		chip.visible = false
		chip.picked.connect(_emit_bias)
		bias_rail.add_child(chip)
		bias_buttons.append(chip)
	show_bias(1, 0)


func _emit_bias(index: int) -> void:
	bias_selected.emit(index)


func _build_hand_bar() -> void:
	hand_switch = HandSwitchScript.new()
	hand_switch.position = Vector2(16.0, 820.0)
	hand_switch.size = Vector2(210.0, 64.0)
	hand_switch.visible = false
	hand_switch.chosen.connect(func(fore: bool) -> void: hand_selected.emit(fore))
	add_child(hand_switch)
	fore_button = _make_button("FORE", Vector2(448.0, 900.0), Vector2(76.0, 40.0))
	fore_button.visible = false
	fore_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _style_arrow(button: Button, selected: bool) -> void:
	if button == null:
		return
	var fill := Color("#f3bd56") if selected else Color("#123849")
	var border := Color("#ffe9a4") if selected else Color("#397d88")
	var font := Color("#1a1408") if selected else Color("#e9fbff")
	button.add_theme_stylebox_override("normal", _button_style(fill, border))
	button.add_theme_color_override("font_color", font)


func _build_summary() -> void:
	summary = Panel.new()
	summary.position = Vector2(70.0, 122.0)
	summary.size = Vector2(400.0, 156.0)
	summary.visible = false
	summary.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.09, 0.12, 0.9)
	style.border_color = Color(0.9, 0.76, 0.38)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	summary.add_theme_stylebox_override("panel", style)
	add_child(summary)
	summary_title = _panel_label(Vector2(16.0, 10.0), Vector2(368.0, 24.0), 14, Color(0.78, 0.9, 0.84))
	summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_shots = _panel_label(Vector2(16.0, 36.0), Vector2(368.0, 54.0), 40, Color(0.98, 0.9, 0.55))
	summary_shots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_detail = _panel_label(Vector2(16.0, 96.0), Vector2(368.0, 48.0), 14, Color(0.9, 0.96, 0.93))
	summary_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _panel_label(label_position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(label)
	return label


func _make_label(label_position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.add_theme_font_override("font", HUD_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.18, 0.02, 0.16, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _make_button(button_text: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = button_position
	button.size = button_size
	button.add_theme_font_override("font", HUD_FONT)
	button.add_theme_font_size_override("font_size", 13)
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.add_theme_color_override("font_color", Color("#FFF6FF"))
	button.add_theme_color_override("font_hover_color", Color("#07131e"))
	button.add_theme_color_override("font_pressed_color", Color("#07131e"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#123849"), Color("#397d88")))
	button.add_theme_stylebox_override("hover", _button_style(Color("#6bd9e6"), Color("#baf7f2")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#f3bd56"), Color("#ffe9a4")))
	add_child(button)
	return button


func _paint_sync(button: Button, hot: bool) -> void:
	var fill := Color("#FF2E8A") if hot else Color(0.30, 0.08, 0.48, 0.94)
	var border := Color("#FFE4F6") if hot else Color("#5CFFF2")
	button.add_theme_stylebox_override("normal", _pill(fill, border))
	button.add_theme_stylebox_override("hover", _pill(fill.lightened(0.12), border))
	button.add_theme_stylebox_override("pressed", _pill(Color("#FF5CAA"), Color("#FFFFFF")))
	button.add_theme_color_override("font_color", Color("#FFF6FF"))
	button.add_theme_color_override("font_hover_color", Color("#FFF6FF"))
	button.add_theme_color_override("font_pressed_color", Color("#1A0610"))


func _paint_selected(button: Button) -> void:
	_paint_sync(button, true)

func _premium_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := _button_style(fill, border)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 5
	return style


func _pill(fill: Color, border: Color) -> StyleBoxFlat:
	var style := _button_style(fill, border)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(1.0, 0.15, 0.45, 0.28)
	style.shadow_size = 6
	return style


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
