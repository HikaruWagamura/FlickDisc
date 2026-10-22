class_name UIManager
extends CanvasLayer

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
var hand_bar: Panel
var hand_label: Label
var fore_button: Button
var back_button: Button
var turn_mark: Control
var bias_buttons: Array[Button] = []
var bias_rail: Panel
var summary: Panel
var summary_title: Label
var summary_shots: Label
var summary_detail: Label
var power_fill: TextureRect
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

	var menu_button := _make_button("MENU", Vector2(16.0, 12.0), Vector2(104.0, 32.0))
	menu_button.add_theme_font_size_override("font_size", 13)
	menu_button.add_theme_stylebox_override("normal", _button_style(Color("#ff4d9a"), Color("#ffd0e8")))
	menu_button.add_theme_color_override("font_color", Color("#1a0a12"))
	menu_button.pressed.connect(func() -> void: leave_requested.emit())

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

	status_label = _make_label(Vector2(18.0, 116.0), Vector2(504.0, 22.0), 14, Color(0.95, 0.99, 0.96))
	score_label = _make_label(Vector2(18.0, 140.0), Vector2(504.0, 20.0), 13, Color(0.78, 0.92, 0.86))

	_build_aim_dial()
	_build_bias_row()
	_build_hand_bar()

	reset_button = _make_button("RESET", Vector2(128.0, 12.0), Vector2(96.0, 32.0))
	reset_button.add_theme_font_size_override("font_size", 12)
	reset_button.pressed.connect(func() -> void: reset_requested.emit())

	next_button = _make_button("NEXT END", Vector2(150.0, 888.0), Vector2(240.0, 48.0))
	next_button.pressed.connect(func() -> void: next_level_requested.emit())
	next_button.visible = false


func set_power_ratio(power_ratio: float) -> void:
	if power_fill == null:
		return
	var ratio := clampf(power_ratio, 0.0, 1.0)
	var inner := 352.0
	if power_track != null:
		inner = power_track.size.x - 8.0
	power_fill.size.x = inner * ratio
	if power_cap != null:
		power_cap.visible = ratio > 0.04
		power_cap.position = Vector2(4.0 + power_fill.size.x - 7.0, 4.0)


func show_jack_prompt(end_number: int, match_label: String, match_points: int) -> void:
	level_label.text = "END %d" % end_number
	throws_label.text = "%d PTS" % match_points
	status_label.text = "TOUCH TO AIM  •  TAP THE JACK TO LOCK"
	score_label.text = match_label
	reset_button.visible = true
	next_button.visible = false
	show_bowl_controls(false)
	hide_summary()
	set_power_ratio(0.0)


func show_match(match_label: String) -> void:
	match_button.text = match_label


func show_ditch_mode(enabled: bool) -> void:
	ditch_button.text = "DITCH ON" if enabled else "REBOUND"


func show_place_line(jack: bool) -> void:
	if jack:
		status_label.text = "TOUCH TO AIM  •  TAP THE JACK TO LOCK"
	else:
		status_label.text = "TOUCH TO AIM  •  TAP THE BOWL TO LOCK"


func show_sliding(jack: bool) -> void:
	show_place_line(jack)


func show_aiming_line(jack: bool) -> void:
	show_place_line(jack)


func show_aim_ready(jack: bool) -> void:
	if jack:
		status_label.text = "TAP THE JACK TO LOCK"
	else:
		status_label.text = "TAP THE BOWL TO LOCK"


func show_take_shot(_jack: bool = false) -> void:
	status_label.text = "PULL THE PUCK  •  RELEASE ON THE GREEN"


func show_jack_aim(_power_ratio: float) -> void:
	status_label.text = "RELEASE ON THE GREEN"


func show_jack_running() -> void:
	status_label.text = "JACK RUNNING"
	score_label.text = "LET IT STOP TO READ THE LENGTH"


func show_jack_illegal(reason: String, travelled: float, detail: String) -> void:
	throws_label.text = "JACK"
	status_label.text = reason
	score_label.text = "%.1f m  •  %s" % [travelled, detail]


func show_jack_set(travelled: float, _bowl_name: String, throws_left: int) -> void:
	throws_label.text = "%d BOWLS" % throws_left
	status_label.text = "JACK AT %.1f m" % travelled
	score_label.text = "%d BOWLS" % throws_left
	show_bowl_controls(true)
	set_power_ratio(0.0)


func show_aiming(_power_ratio: float) -> void:
	status_label.text = "RELEASE ON THE GREEN"


func show_in_motion(throws_left: int, bowl_name: String, forehand: bool) -> void:
	throws_label.text = "%d BOWLS" % throws_left
	status_label.text = "%s  •  %s" % [bowl_name, "FOREHAND" if forehand else "BACKHAND"]
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
	show_bowl_controls(false)


func hide_summary() -> void:
	if summary != null:
		summary.visible = false


func show_hand(forehand: bool, _bowl_name: String) -> void:
	current_bias = -1.0 if forehand else 1.0
	if fore_button != null:
		fore_button.text = "FORE" if forehand else "BACK"
		_style_arrow(fore_button, true)


func show_bias(index: int) -> void:
	for i in bias_buttons.size():
		var selected := i == index
		var fill := Color("#f3bd56") if selected else Color(0.10, 0.07, 0.09, 0.94)
		var border := Color("#ffe9a4") if selected else Color("#c6a15a")
		var font := Color("#1a1408") if selected else Color("#f8f1e4")
		bias_buttons[i].add_theme_stylebox_override("normal", _premium_style(fill, border))
		bias_buttons[i].add_theme_stylebox_override("hover", _premium_style(Color("#ffe09a"), Color("#fff4d2")))
		bias_buttons[i].add_theme_color_override("font_color", font)


func show_bowl_controls(enabled: bool) -> void:
	if bias_rail != null:
		bias_rail.visible = enabled
	if fore_button != null:
		fore_button.visible = enabled
	for button in bias_buttons:
		button.visible = enabled


func _hand_name() -> String:
	return "FOREHAND" if current_bias < 0.0 else "BACKHAND"


func _build_power_meter() -> void:
	power_track = Panel.new()
	power_track.position = Vector2(70.0, 912.0)
	power_track.size = Vector2(400.0, 28.0)
	power_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.03, 0.07, 0.1, 0.92)
	track.border_color = Color(0.9, 0.76, 0.38)
	track.set_border_width_all(2)
	track.set_corner_radius_all(11)
	power_track.add_theme_stylebox_override("panel", track)
	power_track.clip_contents = true
	add_child(power_track)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.16, 0.55, 0.66))
	gradient.add_point(0.62, Color(0.55, 0.9, 0.78))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.98, 0.78, 0.32))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 16
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	power_fill = TextureRect.new()
	power_fill.position = Vector2(4.0, 4.0)
	power_fill.size = Vector2(0.0, 20.0)
	power_fill.texture = texture
	power_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	power_fill.stretch_mode = TextureRect.STRETCH_SCALE
	power_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_track.add_child(power_fill)
	power_cap = Panel.new()
	power_cap.size = Vector2(14.0, 20.0)
	power_cap.position = Vector2(4.0, 4.0)
	power_cap.visible = false
	power_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := StyleBoxFlat.new()
	cap.bg_color = Color(0.98, 0.9, 0.62)
	cap.set_corner_radius_all(7)
	power_cap.add_theme_stylebox_override("panel", cap)
	power_track.add_child(power_cap)
	power_label = Label.new()
	power_label.text = "POWER"
	power_label.position = Vector2(70.0, 892.0)
	power_label.size = Vector2(400.0, 18.0)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	power_label.add_theme_font_size_override("font_size", 11)
	power_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 0.95))
	power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(power_label)


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
	bias_rail = Panel.new()
	bias_rail.position = Vector2(444.0, 168.0)
	bias_rail.size = Vector2(84.0, 328.0)
	bias_rail.visible = false
	bias_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.05, 0.03, 0.05, 0.62)
	rail.border_color = Color(0.86, 0.68, 0.38, 0.85)
	rail.set_border_width_all(1)
	rail.set_corner_radius_all(22)
	bias_rail.add_theme_stylebox_override("panel", rail)
	add_child(bias_rail)
	var names := ["NARROW", "MEDIUM", "WIDE", "HOOK"]
	for i in names.size():
		var button := _make_button(names[i], Vector2(451.0, 178.0 + float(i) * 78.0), Vector2(70.0, 66.0))
		button.add_theme_font_size_override("font_size", 11)
		button.visible = false
		button.pressed.connect(_emit_bias.bind(i))
		bias_buttons.append(button)
	show_bias(1)


func _emit_bias(index: int) -> void:
	bias_selected.emit(index)


func _build_hand_bar() -> void:
	fore_button = _make_button("FORE", Vector2(448.0, 900.0), Vector2(76.0, 40.0))
	fore_button.add_theme_font_size_override("font_size", 12)
	fore_button.visible = false
	fore_button.pressed.connect(func() -> void: hand_selected.emit(current_bias >= 0.0))


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


func _paint_selected(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_style(Color(0.95, 0.74, 0.34), Color(1.0, 0.91, 0.64)))
	button.add_theme_stylebox_override("hover", _button_style(Color(1.0, 0.86, 0.55), Color(1.0, 0.95, 0.75)))
	button.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	button.add_theme_color_override("font_hover_color", Color(0.1, 0.08, 0.05))

func _premium_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := _button_style(fill, border)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 5
	return style


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
