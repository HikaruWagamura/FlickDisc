class_name DiscController
extends RigidBody2D

signal aim_changed(direction: Vector2, power_ratio: float)
signal bias_changed(bias_ratio: float)
signal shot_started
signal shot_stopped

const DISC_RADIUS := 27.0
const MAX_DRAG_DISTANCE := 230.0
const MAX_SPEED := 1050.0
const FRICTION_PER_SECOND := 0.30
const STOP_SPEED := 14.0
const STOP_GRACE_SECONDS := 0.12

const DISC_BLUE := Color("#6bd9e6")
const DISC_BLUE_DARK := Color("#125a79")
const DISC_HIGHLIGHT := Color(0.88, 0.98, 1.0, 0.82)

var start_position := Vector2.ZERO
var rink_bounds := Rect2()
var is_aiming := false
var shot_in_progress := false
var aim_direction := Vector2.UP
var power_ratio := 0.0
var bias_ratio := 0.0
var shot_bias := 0.0
var stop_timer := 0.0
var spin_angle := 0.0

func _ready() -> void:
	start_position = position
	freeze = true
	queue_redraw()

func _physics_process(delta: float) -> void:
	if shot_in_progress:
		var speed: float = linear_velocity.length()
		if speed > STOP_SPEED:
			var slowdown_ratio: float = clampf(1.0 - speed / MAX_SPEED, 0.0, 1.0)
			var turn_rate: float = lerpf(0.10, 0.75, slowdown_ratio)
			linear_velocity = linear_velocity.rotated(shot_bias * turn_rate * delta)
			var spin_direction: float = -1.0 if shot_bias < 0.0 else 1.0
			spin_angle += spin_direction * lerpf(3.0, 16.0, speed / MAX_SPEED) * delta
		linear_velocity *= pow(FRICTION_PER_SECOND, delta)
		_keep_inside_rink()
		if linear_velocity.length() <= STOP_SPEED:
			linear_velocity = Vector2.ZERO
			stop_timer += delta
			if stop_timer >= STOP_GRACE_SECONDS:
				shot_in_progress = false
				emit_signal("shot_stopped")
		else:
			stop_timer = 0.0
	queue_redraw()

func set_bias(value: float) -> void:
	bias_ratio = clampf(value, -1.0, 1.0)
	emit_signal("bias_changed", bias_ratio)
	queue_redraw()

func cycle_bias() -> void:
	if bias_ratio < -0.5:
		set_bias(0.0)
	elif bias_ratio > 0.5:
		set_bias(-1.0)
	else:
		set_bias(1.0)

func begin_aim(pointer_position: Vector2) -> bool:
	if shot_in_progress or pointer_position.distance_to(global_position) > DISC_RADIUS + 30.0:
		return false
	is_aiming = true
	update_aim(pointer_position)
	return true

func update_aim(pointer_position: Vector2) -> void:
	if not is_aiming:
		return
	var pull: Vector2 = pointer_position - global_position
	var drag_distance: float = minf(pull.length(), MAX_DRAG_DISTANCE)
	power_ratio = drag_distance / MAX_DRAG_DISTANCE
	if drag_distance > 1.0:
		aim_direction = -pull.normalized()
	emit_signal("aim_changed", aim_direction, power_ratio)
	queue_redraw()

func release_aim(pointer_position: Vector2) -> void:
	if not is_aiming:
		return
	update_aim(pointer_position)
	is_aiming = false
	if power_ratio < 0.08:
		power_ratio = 0.0
		emit_signal("aim_changed", aim_direction, power_ratio)
		queue_redraw()
		return
	launch()

func launch() -> void:
	freeze = false
	shot_bias = bias_ratio
	linear_velocity = aim_direction * lerpf(150.0, MAX_SPEED, power_ratio)
	shot_in_progress = true
	stop_timer = 0.0
	emit_signal("shot_started")
	queue_redraw()

func reset_to_start() -> void:
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	position = start_position
	is_aiming = false
	shot_in_progress = false
	power_ratio = 0.0
	stop_timer = 0.0
	shot_bias = 0.0
	spin_angle = 0.0
	queue_redraw()

func set_rink_bounds(bounds: Rect2) -> void:
	rink_bounds = bounds

func _keep_inside_rink() -> void:
	if rink_bounds.size == Vector2.ZERO:
		return
	var min_x := rink_bounds.position.x + DISC_RADIUS
	var max_x := rink_bounds.end.x - DISC_RADIUS
	var min_y := rink_bounds.position.y + DISC_RADIUS
	var max_y := rink_bounds.end.y - DISC_RADIUS
	var clamped_position := Vector2(
		clampf(position.x, min_x, max_x),
		clampf(position.y, min_y, max_y)
	)
	if clamped_position != position:
		position = clamped_position
		linear_velocity *= Vector2(
			-0.18 if position.x == min_x or position.x == max_x else 1.0,
			-0.18 if position.y == min_y or position.y == max_y else 1.0
		)

func _draw() -> void:
	var depth: float = clampf((global_position.y - 156.0) / 716.0, 0.0, 1.0)
	var visual_scale: float = lerpf(0.80, 1.16, depth)
	var lift: float = clampf(linear_velocity.length() / MAX_SPEED, 0.0, 1.0) * 10.0
	var disc_center := Vector2(0.0, -3.0 - lift)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * visual_scale)
	draw_circle(Vector2(0.0, 11.0 + lift * 0.35), DISC_RADIUS + 3.0, Color(0.0, 0.10, 0.17, 0.30))
	draw_circle(Vector2(0.0, 13.0 + lift * 0.35), DISC_RADIUS + 8.0, Color(0.42, 0.95, 0.90, 0.08))
	draw_set_transform(Vector2.ZERO, spin_angle, Vector2.ONE * visual_scale)
	draw_circle(disc_center + Vector2(0.0, 3.0), DISC_RADIUS + 3.0, DISC_BLUE_DARK)
	draw_circle(disc_center, DISC_RADIUS, DISC_BLUE)
	draw_circle(disc_center + Vector2(-9.0, -8.0), 7.0, DISC_HIGHLIGHT)
	draw_arc(disc_center, DISC_RADIUS - 5.0, 0.0, TAU, 40, Color(0.88, 0.98, 1.0, 0.45), 2.0)
	for spoke_index in range(4):
		var spoke_angle: float = float(spoke_index) * PI * 0.5
		var spoke_direction := Vector2.from_angle(spoke_angle)
		draw_line(
			disc_center + spoke_direction * 5.0,
			disc_center + spoke_direction * 17.0,
			Color(0.90, 1.0, 0.98, 0.62),
			2.0
		)

	if is_aiming and power_ratio > 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * visual_scale)
		var guide_length: float = lerpf(150.0, 565.0, power_ratio)
		var guide_start := Vector2(0.0, -lift)
		var current_point := guide_start
		var current_direction := aim_direction
		var path_points := PackedVector2Array([current_point])
		var markers := PackedVector2Array()
		for path_index in range(1, 25):
			var progress: float = float(path_index) / 24.0
			current_direction = current_direction.rotated(bias_ratio * 0.07 * (1.0 - progress))
			current_point += current_direction * (guide_length / 24.0)
			path_points.append(current_point)
			if path_index % 4 == 0:
				markers.append(current_point)
		draw_polyline(path_points, Color(0.86, 1.0, 0.95, 0.24), 9.0)
		draw_polyline(path_points, Color(0.90, 0.98, 0.96, 0.88), 3.0)
		for marker_position in markers:
			draw_circle(marker_position, 4.0, Color(0.92, 1.0, 0.96, 0.64))
		draw_circle(current_point, 9.0, Color(0.92, 1.0, 0.96, 0.30))
		draw_arc(current_point, 15.0, 0.0, TAU, 24, Color(0.92, 1.0, 0.96, 0.70), 2.0)