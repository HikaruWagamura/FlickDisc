class_name UIManager
extends CanvasLayer

signal reset_requested
signal next_level_requested

var status_label: Label
var score_label: Label
var reset_button: Button
var next_button: Button

func _ready() -> void:
	status_label = _make_label(Vector2(42.0, 112.0), Vector2(310.0, 32.0), 14, Color("#d8f4df"))
	score_label = _make_label(Vector2(42.0, 132.0), Vector2(330.0, 32.0), 12, Color("#a6d7c1"))

	reset_button = _make_button("RESET", Vector2(382.0, 906.0), Vector2(116.0, 38.0))
	reset_button.pressed.connect(func() -> void: reset_requested.emit())

	next_button = _make_button("NEXT LEVEL", Vector2(349.0, 906.0), Vector2(149.0, 38.0))
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
	status_label.text = "ROLLING  •  WATCH THE LINE"

func show_throw_result(distance: float, throws_left: int) -> void:
	status_label.text = "DISTANCE TO JACK  •  %.1f px" % distance
	score_label.text = "%d THROWS REMAINING" % throws_left

func show_level_complete(score: int, closest_distance: float, has_next_level: bool) -> void:
	status_label.text = "LEVEL COMPLETE  •  SCORE %04d" % score
	score_label.text = "BEST THROW  %.1f px" % closest_distance
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
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	add_child(button)
	return button