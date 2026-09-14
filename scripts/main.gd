extends Node2D

## DISC QUEST - game manager and rink renderer
## The scene intentionally keeps the rink visuals here while gameplay systems
## live in their own scripts for easier expansion.

const DESIGN_SIZE := Vector2(540.0, 960.0)
const RINK_RECT := Rect2(24.0, 136.0, 492.0, 744.0)
const RINK_RADIUS := 24.0

const BACKGROUND := Color("#07131e")
const RINK_EDGE := Color("#8cd9c1")
const RINK_GREEN := Color("#25846d")
const RINK_GREEN_DARK := Color("#104d4d")
const RINK_RAIL := Color("#122c3b")
const RINK_LINE := Color(0.76, 0.96, 0.88, 0.34)
const WHITE := Color("#f3faf8")
const MUTED_WHITE := Color("#98b6b6")
const ACCENT_BLUE := Color("#6dd6e5")
const JACK_GOLD := Color("#f3bd56")
const JACK_GOLD_DARK := Color("#95541f")

const JACK_POSITION := Vector2(270.0, 210.0)
const DISC_POSITION := Vector2(270.0, 818.0)
const JACK_RADIUS := 19.0

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
	draw_circle(Vector2(70.0, 105.0), 230.0, Color(0.06, 0.25, 0.30, 0.24))
	draw_circle(Vector2(500.0, 820.0), 280.0, Color(0.04, 0.12, 0.22, 0.50))

func _draw_header() -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(30.0, 48.0),
		"DISC QUEST",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		27,
		WHITE
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(32.0, 72.0),
		"LONG LINE • PRECISION SPORT",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		11,
		MUTED_WHITE
	)

	# Small status pill reserved for the level and throw counter.
	draw_style_box(
		_make_panel_style(Color(0.05, 0.15, 0.21, 0.96), Color(0.25, 0.70, 0.69, 0.7), 14.0),
		Rect2(354.0, 32.0, 162.0, 55.0)
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(371.0, 56.0),
		"LEVEL %02d" % (current_level_index + 1),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		WHITE
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(371.0, 75.0),
		"%d THROWS" % throws_left,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		11,
		ACCENT_BLUE
	)

func _draw_rink() -> void:
	var shadow_rect := Rect2(RINK_RECT.position + Vector2(0.0, 14.0), RINK_RECT.size)
	draw_style_box(
		_make_panel_style(Color(0.0, 0.0, 0.0, 0.40), Color(0.0, 0.0, 0.0, 0.0), RINK_RADIUS),
		shadow_rect
	)

	draw_style_box(
		_make_panel_style(RINK_RAIL, RINK_EDGE, RINK_RADIUS),
		RINK_RECT
	)
	draw_style_box(
		_make_panel_style(RINK_GREEN, Color(0.0, 0.0, 0.0, 0.0), RINK_RADIUS - 7.0),
		Rect2(RINK_RECT.position + Vector2(15.0, 15.0), RINK_RECT.size - Vector2(30.0, 30.0))
	)

	var inner := Rect2(RINK_RECT.position + Vector2(25.0, 25.0), RINK_RECT.size - Vector2(50.0, 50.0))
	draw_line(
		Vector2(inner.position.x - 10.0, inner.position.y),
		Vector2(inner.position.x - 10.0, inner.end.y),
		Color(0.60, 0.93, 0.82, 0.24),
		2.0
	)
	draw_line(
		Vector2(inner.end.x + 10.0, inner.position.y),
		Vector2(inner.end.x + 10.0, inner.end.y),
		Color(0.03, 0.20, 0.25, 0.50),
		3.0
	)
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
		Color(0.76, 0.96, 0.88, 0.16),
		2.0
	)

	for band_index in range(11):
		var band_y: float = inner.position.y + 28.0 + band_index * 63.0
		draw_line(
			Vector2(inner.position.x + 4.0, band_y),
			Vector2(inner.end.x - 4.0, band_y),
			Color(0.85, 1.0, 0.92, 0.075 if band_index % 2 == 0 else 0.035),
			1.0
		)

	_draw_throw_line(inner)
	_draw_target_zone(inner)

func _draw_target_zone(inner: Rect2) -> void:
	var target_zone := Rect2(inner.position.x + 4.0, inner.position.y + 16.0, inner.size.x - 8.0, 145.0)
	draw_style_box(
		_make_panel_style(Color(0.04, 0.31, 0.29, 0.34), Color(0.77, 0.95, 0.84, 0.28), 18.0),
		target_zone
	)
	draw_arc(
		Vector2(inner.position.x + inner.size.x * 0.5, target_zone.end.y - 25.0),
		104.0,
		PI,
		TAU,
		32,
		Color(0.93, 0.78, 0.37, 0.24),
		2.0
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(target_zone.position.x, target_zone.end.y - 18.0),
		"JACK ZONE",
		HORIZONTAL_ALIGNMENT_CENTER,
		target_zone.size.x,
		11,
		Color(0.90, 1.0, 0.92, 0.72)
	)

func _draw_throw_line(inner: Rect2) -> void:
	var throw_y: float = inner.end.y - 46.0
	draw_line(
		Vector2(inner.position.x + 18.0, throw_y),
		Vector2(inner.end.x - 18.0, throw_y),
		Color(0.95, 0.80, 0.39, 0.78),
		2.0
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(inner.position.x, throw_y + 24.0),
		"THROW LINE",
		HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x,
		10,
		Color(0.97, 0.86, 0.53, 0.78)
	)

func _draw_jack() -> void:
	# Shadow
	draw_circle(jack_position + Vector2(0.0, 9.0), JACK_RADIUS + 3.0, Color(0.0, 0.12, 0.07, 0.30))
	# Dark lower rim, gold body, and a small highlight make the target easy to
	# read without needing a texture.
	draw_circle(jack_position, JACK_RADIUS + 2.0, JACK_GOLD_DARK)
	draw_circle(jack_position + Vector2(0.0, -2.0), JACK_RADIUS, JACK_GOLD)
	draw_circle(jack_position + Vector2(-5.0, -7.0), 5.0, Color(1.0, 0.98, 0.72, 0.78))
	draw_arc(jack_position + Vector2(0.0, -2.0), JACK_RADIUS - 4.0, 0.0, TAU, 32, Color(1.0, 0.95, 0.65, 0.34), 2.0)
	draw_string(
		ThemeDB.fallback_font,
		jack_position + Vector2(-28.0, -34.0),
		"JACK",
		HORIZONTAL_ALIGNMENT_CENTER,
		56.0,
		11,
		Color(0.97, 1.0, 0.92, 0.82)
	)

func _draw_footer_hint() -> void:
	var footer := Rect2(24.0, 888.0, 492.0, 28.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(footer.position.x, footer.position.y + 19.0),
		"DRAG BACK • AIM UP THE LANE • RELEASE",
		HORIZONTAL_ALIGNMENT_CENTER,
		footer.size.x,
		13,
		Color(0.58, 0.82, 0.80, 0.90)
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