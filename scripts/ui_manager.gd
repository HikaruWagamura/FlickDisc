class_name UIManager
extends CanvasLayer

signal reset_requested
signal next_level_requested
signal bias_cycle_requested

var status_label: Label
var score_label: Label
var level_label: Label
var throws_label: Label
var reset_button: Button
var next_button: Button
var bias_button: Button
var power_fill: ColorRect
var current_bias := 0.0

func _ready() -> void:
	_make_scrim(Rect2(0.0, 0.0, 540.0, 108.0), Color(0.03, 0.02, 0.04, 0.72))
	_make_scrim(Rect2(0.0, 848.0, 540.0, 112.0), Color(0.03, 0.02, 0.04, 0.78))

	_make_label(Vector2(22.0, 8.0), Vector2(280.0, 28.0), 24, Color("#f7fbff"), "DISC QUEST")
	_make_label(Vector2(24.0, 36.0), Vector2(280.0, 18.0), 11, Color("#ff8ec4"), "ROUND BOARD  •  LONG RINK")
	level_label = _make_label(Vector2(300.0, 10.0), Vector2(216.0, 22.0), 16, Color("#f7fbff"), "LEVEL 01")
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	throws_label = _make_label(Vector2(300.0, 34.0), Vector2(216.0, 18.0), 12, Color("#8fd7ea"), "8 DISCS")
	throws_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	status_label = _make_label(Vector2(22.0, 58.0), Vector2(496.0, 22.0), 13, Color("#d9f5e8"), "")
	score_label = _make_label(Vector2(22.0, 80.0), Vector2(496.0, 20.0), 11, Color("#8fc9bf"), "")

	_make_label(Vector2(24.0, 864.0), Vector2(70.0, 18.0), 10, Color("#9fd8cc"), "POWER")
	var track := ColorRect.new()
	track.position = Vector2(96.0, 868.0)
	track.size = Vector2(160.0, 8.0)
	track.color = Color(0.02, 0.05, 0.08, 0.9)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	power_fill = ColorRect.new()
	power_fill.position = Vector2(96.0, 868.0)
	power_fill.size = Vector2(0.0, 8.0)
	power_fill.color = Color("#6bd9e6")
	power_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(power_fill)

	reset_button = _make_button("RESET", Vector2(24.0, 900.0), Vector2(112.0, 40.0))
	reset_button.pressed.connect(func() -> void: reset_requested.emit())

	next_button = _make_button("NEXT LEVEL", Vector2(342.0, 900.0), Vector2(174.0, 40.0))
	next_button.pressed.connect(func() -> void: next_level_requested.emit())
	next_button.visible = false

	bias_button = _make_button("BIAS  CENTER", Vector2(144.0, 900.0), Vector2(174.0, 40.0))
	bias_button.pressed.connect(func() -> void: bias_cycle_requested.emit())

func show_ready(level_number: int, discs_left: int, difficulty: String = "", score: int = 0) -> void:
	status_label.text = "LEVEL %02d  •  DRAG BACK AND FLICK AROUND THE PEGS" % level_number
	var layout := difficulty.to_upper() if difficulty != "" else "CROKINOLE"
	score_label.text = "%s  •  YOU %d  •  20 IN THE HOLE" % [layout, score]
	show_match_status(level_number, discs_left, score)
	reset_button.visible = true
	next_button.visible = false

func show_match_status(level_number: int, discs_left: int, score: int = 0) -> void:
	level_label.text = "LEVEL %02d" % level_number
	throws_label.text = "%d LEFT  •  %d" % [discs_left, score]

func show_aiming(power_ratio: float) -> void:
	status_label.text = "RELEASE TO FLICK  •  %d%%  •  %s" % [roundi(power_ratio * 100.0), _bias_name()]

func show_power(ratio: float) -> void:
	power_fill.size.x = 160.0 * clampf(ratio, 0.0, 1.0)

func show_in_motion(discs_left: int, score: int) -> void:
	status_label.text = "IN FLIGHT  •  PEGS AND DISCS ARE LIVE"
	score_label.text = "YOU %d  •  %d DISCS LEFT" % [score, discs_left]

func show_landed(shot_points: int, total: int, discs_left: int, sunk: bool) -> void:
	if sunk:
		status_label.text = "20 IN THE HOLE"
	elif shot_points > 0:
		status_label.text = "LANDED FOR %d" % shot_points
	else:
		status_label.text = "IN THE DITCH  •  NO POINTS"
	score_label.text = "YOU %d  •  %d DISCS LEFT" % [total, discs_left]
	next_button.visible = false

func show_round_complete(total: int, last_points: int, has_next_level: bool) -> void:
	status_label.text = "ROUND OVER  •  LAST DISC %d" % last_points
	score_label.text = "YOU %d    •    20 HOLE   15   10   5" % total
	reset_button.visible = true
	next_button.visible = has_next_level

func show_bias(value: float) -> void:
	current_bias = value
	bias_button.text = "BIAS  %s" % _bias_name()

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
