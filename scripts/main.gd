extends Node2D

## DISC QUEST - game manager and rink renderer
## The scene intentionally keeps the rink visuals here while gameplay systems
## live in their own scripts for easier expansion.

const DESIGN_SIZE := Vector2(540.0, 960.0)
const RINK_RECT := Rect2(42.0, 166.0, 456.0, 730.0)
const RINK_RADIUS := 28.0

const BACKGROUND := Color("#081a32")
const RINK_EDGE := Color("#b8efb5")
const RINK_GREEN := Color("#5cbf74")
const RINK_GREEN_DARK := Color("#3b9a60")
const RINK_LINE := Color(0.85, 1.0, 0.78, 0.44)
const WHITE := Color("#f5fff3")
const MUTED_WHITE := Color(0.75, 0.88, 0.80, 1.0)
const ACCENT_BLUE := Color("#55a9e8")
const JACK_GOLD := Color("#f4c95d")
const JACK_GOLD_DARK := Color("#c78c31")

const JACK_POSITION := Vector2(270.0, 270.0)
const DISC_POSITION := Vector2(270.0, 782.0)
const JACK_RADIUS := 17.0

var screen_size := DESIGN_SIZE
var disc: DiscController
var ui: UIManager
var level_manager: LevelManager
var score_manager: ScoreManager
var current_level_index := 0
var current_level: Dictionary
var jack_position := JACK_POSITION
var throws_left := 3

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	disc = get_node("PlayerDisc") as DiscController
	ui = get_node("UI") as UIManager
	level_manager = LevelManager.new()
	score_manager = ScoreManager.new()
	add_child(level_manager)
	add_child(score_manager)
	disc.aim_changed.connect(_on_disc_aim_changed)
	disc.shot_started.connect(_on_disc_shot_started)
	disc.shot_stopped.connect(_on_disc_shot_stopped)
	ui.reset_requested.connect(_on_reset_requested)
	ui.next_level_requested.connect(_on_next_level_requested)
	_on_viewport_size_changed()
	_load_level(0)
	queue_redraw()

func _on_viewport_size_changed() -> void:
	screen_size = get_viewport_rect().size
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			disc.begin_aim(event.position)
		else:
			disc.release_aim(event.position)
	elif event is InputEventScreenDrag:
		disc.update_aim(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			disc.begin_aim(event.position)
		else:
			disc.release_aim(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		disc.update_aim(event.position)

func _draw() -> void:
	var scale_factor: float = minf(screen_size.x / DESIGN_SIZE.x, screen_size.y / DESIGN_SIZE.y)
	var offset: Vector2 = (screen_size - DESIGN_SIZE * scale_factor) * 0.5
	draw_set_transform(offset, 0.0, Vector2.ONE * scale_factor)

	_draw_background()
	_draw_header()
	_draw_rink()
	_draw_jack()
	_draw_footer_hint()

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN_SIZE), BACKGROUND)

	# Large, quiet colour fields make the flat 2D scene feel more like a
	# polished mobile game without adding any external image assets.
	draw_circle(Vector2(76.0, 102.0), 190.0, Color(0.07, 0.22, 0.36, 0.34))
	draw_circle(Vector2(500.0, 810.0), 240.0, Color(0.03, 0.12, 0.25, 0.44))

func _draw_header() -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(42.0, 70.0),
		"DISC QUEST",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		30,
		WHITE
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(44.0, 99.0),
		"THE PERFECT LINE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		MUTED_WHITE
	)

	# Small status pill reserved for the level and throw counter.
	draw_style_box(
		_make_panel_style(Color(0.07, 0.19, 0.31, 0.86), Color(0.32, 0.66, 0.84, 0.5), 16.0),
		Rect2(365.0, 44.0, 133.0, 56.0)
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(383.0, 68.0),
		"LEVEL %02d" % (current_level_index + 1),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		WHITE
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(383.0, 87.0),
		"%d THROWS" % throws_left,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		11,
		ACCENT_BLUE
	)

func _draw_rink() -> void:
	var shadow_rect := Rect2(RINK_RECT.position + Vector2(0.0, 12.0), RINK_RECT.size)
	draw_style_box(
		_make_panel_style(Color(0.0, 0.0, 0.0, 0.28), Color(0.0, 0.0, 0.0, 0.0), RINK_RADIUS),
		shadow_rect
	)

	# Dark inset border, soft outer edge, and two green layers create a
	# simple 2.5D "tabletop" presentation.
	draw_style_box(
		_make_panel_style(RINK_GREEN_DARK, RINK_EDGE, RINK_RADIUS),
		RINK_RECT
	)
	draw_style_box(
		_make_panel_style(RINK_GREEN, Color(0.0, 0.0, 0.0, 0.0), RINK_RADIUS - 7.0),
		Rect2(RINK_RECT.position + Vector2(8.0, 8.0), RINK_RECT.size - Vector2(16.0, 16.0))
	)

	var inner := Rect2(RINK_RECT.position + Vector2(28.0, 28.0), RINK_RECT.size - Vector2(56.0, 56.0))
	draw_line(
		Vector2(inner.position.x, inner.position.y + 18.0),
		Vector2(inner.end.x, inner.position.y + 18.0),
		RINK_LINE,
		2.0
	)
	draw_line(
		Vector2(inner.position.x, inner.end.y - 18.0),
		Vector2(inner.end.x, inner.end.y - 18.0),
		RINK_LINE,
		2.0
	)
	draw_line(
		Vector2(inner.position.x + inner.size.x * 0.5, inner.position.y),
		Vector2(inner.position.x + inner.size.x * 0.5, inner.end.y),
		Color(0.85, 1.0, 0.78, 0.16),
		2.0
	)

	# Subtle lane bands help the player read depth before gameplay exists.
	for band_index in range(5):
		var band_y := inner.position.y + 58.0 + band_index * 116.0
		draw_line(
			Vector2(inner.position.x + 4.0, band_y),
			Vector2(inner.end.x - 4.0, band_y),
			Color(0.95, 1.0, 0.86, 0.07),
			1.0
		)

	_draw_target_zone(inner)

func _draw_target_zone(inner: Rect2) -> void:
	var target_zone := Rect2(inner.position.x + 4.0, inner.position.y + 16.0, inner.size.x - 8.0, 132.0)
	draw_style_box(
		_make_panel_style(Color(0.20, 0.53, 0.34, 0.12), Color(0.86, 1.0, 0.80, 0.18), 18.0),
		target_zone
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(target_zone.position.x, target_zone.end.y - 18.0),
		"TARGET ZONE",
		HORIZONTAL_ALIGNMENT_CENTER,
		target_zone.size.x,
		11,
		Color(0.91, 1.0, 0.88, 0.60)
	)

func _draw_jack() -> void:
	# Shadow
	draw_circle(jack_position + Vector2(0.0, 8.0), JACK_RADIUS + 2.0, Color(0.0, 0.12, 0.07, 0.24))
	# Dark lower rim, gold body, and a small highlight make the target easy to
	# read without needing a texture.
	draw_circle(jack_position, JACK_RADIUS + 2.0, JACK_GOLD_DARK)
	draw_circle(jack_position + Vector2(0.0, -2.0), JACK_RADIUS, JACK_GOLD)
	draw_circle(jack_position + Vector2(-5.0, -7.0), 5.0, Color(1.0, 0.98, 0.72, 0.78))
	draw_arc(jack_position + Vector2(0.0, -2.0), JACK_RADIUS - 4.0, 0.0, TAU, 32, Color(1.0, 0.95, 0.65, 0.34), 2.0)
	draw_string(
		ThemeDB.fallback_font,
		jack_position + Vector2(-22.0, -32.0),
		"JACK",
		HORIZONTAL_ALIGNMENT_CENTER,
		44.0,
		11,
		Color(0.97, 1.0, 0.88, 0.74)
	)

func _draw_footer_hint() -> void:
	var footer := Rect2(42.0, 918.0, 456.0, 28.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(footer.position.x, footer.position.y + 19.0),
		"TOUCH • AIM • RELEASE",
		HORIZONTAL_ALIGNMENT_CENTER,
		footer.size.x,
		13,
		Color(0.73, 0.86, 0.86, 0.86)
	)

func _make_panel_style(fill: Color, border: Color, corner_radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0.0 else 0)
	style.set_corner_radius_all(int(corner_radius))
	return style

func _load_level(level_index: int) -> void:
	current_level_index = clampi(level_index, 0, level_manager.get_level_count() - 1)
	current_level = level_manager.get_level(current_level_index)
	jack_position = current_level["jack_position"]
	throws_left = current_level["throws"]
	score_manager.reset()
	disc.start_position = DISC_POSITION
	disc.set_rink_bounds(RINK_RECT)
	disc.reset_to_start()
	ui.show_ready(current_level["number"], throws_left)
	queue_redraw()

func _on_disc_aim_changed(_direction: Vector2, power_ratio: float) -> void:
	if power_ratio > 0.0:
		ui.show_aiming(power_ratio)

func _on_disc_shot_started() -> void:
	throws_left -= 1
	ui.show_in_motion()
	queue_redraw()

func _on_disc_shot_stopped() -> void:
	var distance := disc.position.distance_to(jack_position)
	score_manager.record_throw(distance)
	if throws_left > 0:
		disc.reset_to_start()
		ui.show_throw_result(distance, throws_left)
	else:
		ui.show_level_complete(
			score_manager.get_score(),
			score_manager.get_closest_distance(),
			current_level_index < level_manager.get_level_count() - 1
		)
	queue_redraw()

func _on_reset_requested() -> void:
	_load_level(current_level_index)

func _on_next_level_requested() -> void:
	if current_level_index < level_manager.get_level_count() - 1:
		_load_level(current_level_index + 1)