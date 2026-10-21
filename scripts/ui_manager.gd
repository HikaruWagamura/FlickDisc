class_name UIManager
extends CanvasLayer

signal reset_requested
signal next_level_requested
signal bias_cycle_requested
signal ditch_option_requested
signal match_cycle_requested

var status_label: Label
var score_label: Label
var level_label: Label
var throws_label: Label
var reset_button: Button
var next_button: Button
var bias_button: Button
var ditch_button: Button
var match_button: Button
var summary: Panel
var summary_title: Label
var summary_shots: Label
var summary_detail: Label
var power_fill: ColorRect
var current_bias := 0.0

const POWER_WIDTH := 210.0


func _ready() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.color = Color(1, 1, 1, 1)
	var scrim_mat := ShaderMaterial.new()
	scrim_mat.shader = load("res://shaders/hud_scrim.gdshader")
	scrim.material = scrim_mat
	add_child(scrim)

	var title := _make_label(Vector2(22.0, 16.0), Vector2(280.0, 36.0), 28, Color(0.96, 0.99, 0.97))
	title.text = "DISC QUEST"
	var subtitle := _make_label(Vector2(24.0, 50.0), Vector2(260.0, 20.0), 12, Color(0.67, 0.86, 0.78))
	subtitle.text = "LONG LAWN RINK"

	level_label = _make_label(Vector2(340.0, 18.0), Vector2(180.0, 26.0), 16, Color(0.96, 0.99, 0.97))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	throws_label = _make_label(Vector2(340.0, 44.0), Vector2(180.0, 22.0), 13, Color(0.55, 0.86, 0.9))
	throws_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	ditch_button = _make_button("REBOUND", Vector2(372.0, 70.0), Vector2(148.0, 34.0))
	ditch_button.add_theme_font_size_override("font_size", 12)
	ditch_button.pressed.connect(func() -> void: ditch_option_requested.emit())

	match_button = _make_button("4 ENDS", Vector2(22.0, 74.0), Vector2(156.0, 34.0))
	match_button.add_theme_font_size_override("font_size", 12)
	match_button.pressed.connect(func() -> void: match_cycle_requested.emit())
	_build_summary()

	status_label = _make_label(Vector2(22.0, 820.0), Vector2(496.0, 20.0), 13, Color(0.95, 0.99, 0.96))
	score_label = _make_label(Vector2(22.0, 838.0), Vector2(496.0, 18.0), 12, Color(0.78, 0.92, 0.86))

	var power_label := _make_label(Vector2(78.0, 858.0), Vector2(70.0, 18.0), 11, Color(0.78, 0.9, 0.84))
	power_label.text = "POWER"
	var power_track := ColorRect.new()
	power_track.position = Vector2(156.0, 862.0)
	power_track.size = Vector2(POWER_WIDTH, 8.0)
	power_track.color = Color(0.02, 0.05, 0.08, 0.72)
	power_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(power_track)
	power_fill = ColorRect.new()
	power_fill.position = power_track.position
	power_fill.size = Vector2(0.0, 8.0)
	power_fill.color = Color(0.45, 0.86, 0.9)
	power_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(power_fill)

	reset_button = _make_button("RESET", Vector2(18.0, 898.0), Vector2(118.0, 44.0))
	reset_button.pressed.connect(func() -> void: reset_requested.emit())

	bias_button = _make_button("FOREHAND", Vector2(148.0, 898.0), Vector2(200.0, 44.0))
	bias_button.pressed.connect(func() -> void: bias_cycle_requested.emit())

	next_button = _make_button("NEXT END", Vector2(360.0, 898.0), Vector2(162.0, 44.0))
	next_button.pressed.connect(func() -> void: next_level_requested.emit())
	next_button.visible = false


func set_power_ratio(power_ratio: float) -> void:
	if power_fill == null:
		return
	power_fill.size.x = POWER_WIDTH * clampf(power_ratio, 0.0, 1.0)


func show_jack_prompt(end_number: int, match_label: String, long_jack: bool, match_points: int) -> void:
	level_label.text = "END %d" % end_number
	throws_label.text = "%d PTS" % match_points
	status_label.text = "THROW A %s JACK" % ("LONG" if long_jack else "SHORT")
	var band := "14–28 m"
	if long_jack:
		band = "44 m OR MORE"
	score_label.text = "%s  •  %s" % [match_label, band]
	reset_button.visible = true
	next_button.visible = false
	bias_button.text = "LONG JACK" if long_jack else "SHORT JACK"
	hide_summary()
	set_power_ratio(0.0)


func show_match(match_label: String) -> void:
	match_button.text = match_label


func show_jack_length(long_jack: bool) -> void:
	bias_button.text = "LONG JACK" if long_jack else "SHORT JACK"


func show_ditch_mode(enabled: bool) -> void:
	ditch_button.text = "DITCH ON" if enabled else "REBOUND"


func show_jack_aim(power_ratio: float, long_jack: bool) -> void:
	var length_name := "SHORT"
	if long_jack:
		length_name = "LONG"
	status_label.text = "AIMING %s JACK  •  %d%%" % [length_name, roundi(power_ratio * 100.0)]
	set_power_ratio(power_ratio)


func show_jack_running() -> void:
	status_label.text = "JACK RUNNING"
	score_label.text = "LET IT STOP TO READ THE LENGTH"


func show_jack_illegal(reason: String, travelled: float, detail: String) -> void:
	throws_label.text = "JACK"
	status_label.text = reason
	score_label.text = "%.1f m  •  %s" % [travelled, detail]


func show_jack_set(travelled: float, bowl_name: String, throws_left: int) -> void:
	throws_label.text = "%d BOWLS" % throws_left
	status_label.text = "JACK AT %.1f m" % travelled
	score_label.text = "NOW THE %s BOWL" % bowl_name
	set_power_ratio(0.0)


func show_aiming(power_ratio: float) -> void:
	status_label.text = "AIMING  •  %d%%  •  %s" % [roundi(power_ratio * 100.0), _hand_name()]
	set_power_ratio(power_ratio)


func show_in_motion(throws_left: int, bowl_name: String, forehand: bool) -> void:
	throws_label.text = "%d BOWLS" % throws_left
	status_label.text = "%s  •  %s  •  DRAWING IN" % [bowl_name, "FOREHAND" if forehand else "BACKHAND"]
	score_label.text = "%d BOWLS REMAINING" % throws_left


func show_contact(hit_jack: bool) -> void:
	status_label.text = "JACK STRUCK" if hit_jack else "DISCS MEET"


func show_throw_result(disc_distance: float, closest: float, throws_left: int, jack_moved: bool, in_ditch: bool, respotted: bool, spares: int) -> void:
	throws_label.text = "%d BOWLS" % throws_left
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
		score_label.text = "NO BOWL ON THE GREEN%s" % note
	else:
		score_label.text = "CLOSEST %.2f m%s" % [closest, note]


func show_end_summary(end_number: int, shots: int, closest: float, match_points: int, match_over: bool) -> void:
	summary.visible = true
	if match_over:
		summary_title.text = "MATCH"
	else:
		summary_title.text = "END %d" % end_number
	if shots == 1:
		summary_shots.text = "1 SHOT"
	else:
		summary_shots.text = "%d SHOTS" % shots
	var nearest := "NO BOWL ON THE GREEN"
	if closest >= 0.0:
		nearest = "CLOSEST  %.2f m" % closest
	var total := "FINAL  %d" if match_over else "MATCH  %d"
	summary_detail.text = "%s\n%s" % [nearest, total % match_points]
	throws_label.text = "%d PTS" % match_points
	status_label.text = "END COMPLETE"
	score_label.text = nearest
	next_button.text = "NEW MATCH" if match_over else "NEXT END"
	next_button.visible = true
	reset_button.visible = true


func hide_summary() -> void:
	if summary != null:
		summary.visible = false


func show_hand(forehand: bool, bowl_name: String) -> void:
	current_bias = -1.0 if forehand else 1.0
	bias_button.text = "%s  %s" % [_hand_name(), bowl_name]


func _hand_name() -> String:
	return "FOREHAND" if current_bias < 0.0 else "BACKHAND"


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
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 0.72))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _make_button(button_text: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 13)
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
	style.set_corner_radius_all(12)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
