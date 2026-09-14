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
const COURSE_BACKGROUND := preload("res://assets/course_background.png")
const LANE_TOP_Y := 156.0
const LANE_BOTTOM_Y := 872.0
const LANE_TOP_LEFT := 114.0
const LANE_TOP_RIGHT := 426.0
const LANE_BOTTOM_LEFT := 34.0
const LANE_BOTTOM_RIGHT := 506.0

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
	draw_texture_rect_region(
		COURSE_BACKGROUND,
		Rect2(Vector2.ZERO, DESIGN_SIZE),
		Rect2(224.0, 0.0, 576.0, 1024.0),
		Color(1.0, 1.0, 1.0, 0.96)
	)
	draw_rect(Rect2(0.0, 0.0, DESIGN_SIZE.x, 138.0), Color(0.02, 0.08, 0.13, 0.68))
	draw_rect(Rect2(0.0, 848.0, DESIGN_SIZE.x, 112.0), Color(0.02, 0.08, 0.12, 0.16))

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
	var outer_lane := PackedVector2Array([
		_lane_point(LANE_TOP_Y - 10.0, 0.0, 46.0),
		_lane_point(LANE_TOP_Y - 10.0, 1.0, 46.0),
		_lane_point(LANE_BOTTOM_Y + 10.0, 1.0, 46.0),
		_lane_point(LANE_BOTTOM_Y + 10.0, 0.0, 46.0),
	])
	var shadow_lane := PackedVector2Array([
		outer_lane[0] + Vector2(0.0, 14.0),
		outer_lane[1] + Vector2(0.0, 14.0),
		outer_lane[2] + Vector2(0.0, 14.0),
		outer_lane[3] + Vector2(0.0, 14.0),
	])
	draw_colored_polygon(shadow_lane, Color(0.0, 0.0, 0.0, 0.42))
	draw_colored_polygon(outer_lane, RINK_RAIL)
	draw_polyline(outer_lane, RINK_EDGE, 3.0)

	var surface := PackedVector2Array([
		_lane_point(LANE_TOP_Y, 0.0, 24.0),
		_lane_point(LANE_TOP_Y, 1.0, 24.0),
		_lane_point(LANE_BOTTOM_Y, 1.0, 24.0),
		_lane_point(LANE_BOTTOM_Y, 0.0, 24.0),
	])
	draw_colored_polygon(surface, Color(0.10, 0.52, 0.36, 0.24))
	draw_polyline(surface, Color(0.52, 0.92, 0.77, 0.58), 2.0)

	var inner_top := LANE_TOP_Y + 14.0
	var inner_bottom := LANE_BOTTOM_Y - 14.0
	for band_index in range(12):
		var band_y: float = lerpf(inner_top, inner_bottom, float(band_index) / 12.0)
		var band_color := Color(0.88, 1.0, 0.94, 0.075 if band_index % 2 == 0 else 0.025)
		draw_line(_lane_point(band_y, 0.03), _lane_point(band_y, 0.97), band_color, 2.0)

	for lane_index in range(1, 4):
		var lane_fraction: float = float(lane_index) / 4.0
		draw_line(
			_lane_point(inner_top, lane_fraction),
			_lane_point(inner_bottom, lane_fraction),
			Color(0.76, 0.96, 0.88, 0.14 if lane_index == 2 else 0.07),
			2.0
		)

	draw_line(_lane_point(inner_top, 0.03), _lane_point(inner_bottom, 0.03), RINK_LINE, 2.0)
	draw_line(_lane_point(inner_top, 0.97), _lane_point(inner_bottom, 0.97), RINK_LINE, 2.0)
	_draw_throw_line()
	_draw_target_zone()

func _draw_target_zone() -> void:
	var target_top := LANE_TOP_Y + 18.0
	var target_bottom := LANE_TOP_Y + 160.0
	var target_zone := PackedVector2Array([
		_lane_point(target_top, 0.06),
		_lane_point(target_top, 0.94),
		_lane_point(target_bottom, 0.94),
		_lane_point(target_bottom, 0.06),
	])
	draw_colored_polygon(target_zone, Color(0.04, 0.31, 0.29, 0.42))
	draw_polyline(target_zone, Color(0.77, 0.95, 0.84, 0.30), 2.0)
	draw_arc(
		Vector2(270.0, target_bottom - 34.0),
		102.0,
		PI,
		TAU,
		32,
		Color(0.93, 0.78, 0.37, 0.24),
		2.0
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(120.0, target_bottom - 18.0),
		"JACK ZONE",
		HORIZONTAL_ALIGNMENT_CENTER,
		300.0,
		11,
		Color(0.90, 1.0, 0.92, 0.72)
	)

func _draw_throw_line() -> void:
	var throw_y: float = LANE_BOTTOM_Y - 48.0
	draw_line(
		_lane_point(throw_y, 0.04),
		_lane_point(throw_y, 0.96),
		Color(0.95, 0.80, 0.39, 0.78),
		2.0
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(80.0, throw_y + 24.0),
		"THROW LINE",
		HORIZONTAL_ALIGNMENT_CENTER,
		380.0,
		10,
		Color(0.97, 0.86, 0.53, 0.78)
	)

func _lane_point(y: float, across: float, inset: float = 0.0) -> Vector2:
	var depth: float = clampf((y - LANE_TOP_Y) / (LANE_BOTTOM_Y - LANE_TOP_Y), 0.0, 1.0)
	var left: float = lerpf(LANE_TOP_LEFT, LANE_BOTTOM_LEFT, depth) + inset
	var right: float = lerpf(LANE_TOP_RIGHT, LANE_BOTTOM_RIGHT, depth) - inset
	return Vector2(lerpf(left, right, clampf(across, 0.0, 1.0)), y)

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