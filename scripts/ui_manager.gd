class_name UIManager
extends CanvasLayer

signal reset_requested
signal next_level_requested

var status_label: Label
var score_label: Label
var reset_button: Button
var next_button: Button

func _ready() -> void:
	status_label = _make_label(Vector2(30.0, 91.0), Vector2(320.0, 24.0), 13, Color("#d9f5e8"))
	score_label = _make_label(Vector2(30.0, 111.0), Vector2(330.0, 22.0), 11, Color("#8fc9bf"))

	reset_button = _make_button("RESET", Vector2(24.0, 915.0), Vector2(112.0, 36.0))
	reset_button.pressed.connect(func() -> void: reset_requested.emit())

	next_button = _make_button("NEXT LEVEL", Vector2(342.0, 915.0), Vector2(174.0, 36.0))
	next_button.pressed.connect(func() -> void: next_level_requested.emit())
	next_button.visible = false

func show_ready(level_number: int, throws_left: int) -> void:
	status_label.text = "LEVEL %02d  •  TOUCH YOUR DISC" % level_number
	score_label.text = "%d THROWS REMAINING" % throws_left
	reset_button.visible = true
	next_button.visible = false

func show_aiming(power_ratio: float) -> void:
	status_label.text = "AIMING  •  %d%% POWER" % roundi(power_ratio * 100.0)

func show_in_motion() -> void:
	status_label.text = "IN PLAY  •  TRACK THE LINE"

func show_throw_result(distance: float, throws_left: int) -> void:
	status_label.text = "SHOT COMPLETE  •  %.1f m TO JACK" % (distance / 10.0)
	score_label.text = "%d THROWS REMAINING" % throws_left

func show_level_complete(score: int, closest_distance: float, has_next_level: bool) -> void:
	status_label.text = "LEVEL COMPLETE  •  SCORE %04d" % score
	score_label.text = "BEST LINE  %.1f m TO JACK" % (closest_distance / 10.0)
	reset_button.visible = true
	next_button.visible = has_next_level

func _make_label(label_position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
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