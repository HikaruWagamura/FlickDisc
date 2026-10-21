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

	bias_button = _make_button("BIAS  CENTER", Vector2(148.0, 898.0), Vector2(200.0, 44.0))
	bias_button.pressed.connect(func() -> void: bias_cycle_requested.emit())

	next_button = _make_button("NEXT LEVEL", Vector2(360.0, 898.0), Vector2(162.0, 44.0))
	next_button.pressed.connect(func() -> void: next_level_requested.emit())
	next_button.visible = false


func set_power_ratio(power_ratio: float) -> void:
	if power_fill == null:
		return
	power_fill.size.x = POWER_WIDTH * clampf(power_ratio, 0.0, 1.0)


func show_ready(level_number: int, throws_left: int, difficulty: String) -> void:
	level_label.text = "LEVEL %02d" % level_number
	throws_label.text = "%d THROWS" % throws_left
	status_label.text = "LEVEL %02d  •  TOUCH YOUR DISC" % level_number
	score_label.text = "%s  •  %d THROWS REMAINING" % [difficulty.to_upper(), throws_left]
	reset_button.visible = true
	next_button.visible = false
	set_power_ratio(0.0)


func show_aiming(power_ratio: float) -> void:
	status_label.text = "AIMING  •  %d%% POWER  •  %s" % [roundi(power_ratio * 100.0), _bias_name()]
	set_power_ratio(power_ratio)


func show_in_motion(throws_left: int) -> void:
	throws_label.text = "%d THROWS" % throws_left
	status_label.text = "IN FLIGHT  •  %s BIAS" % _bias_name()
	score_label.text = "%d THROWS REMAINING" % throws_left


func show_throw_result(distance: float, throws_left: int) -> void:
	throws_label.text = "%d THROWS" % throws_left
	status_label.text = "SHOT COMPLETE  •  %.2f m TO JACK" % distance
	score_label.text = "%d THROWS REMAINING" % throws_left


func show_level_complete(score: int, closest_distance: float, has_next_level: bool) -> void:
	throws_label.text = "0 THROWS"
	status_label.text = "LEVEL COMPLETE  •  SCORE %04d" % score
	score_label.text = "BEST LINE  %.2f m TO JACK" % closest_distance
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
