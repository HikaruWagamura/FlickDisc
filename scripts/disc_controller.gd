class_name DiscController
extends RigidBody2D

signal aim_changed(direction: Vector2, power_ratio: float)
signal shot_started
signal shot_stopped

const DISC_RADIUS := 27.0
const MAX_DRAG_DISTANCE := 170.0
const MAX_SPEED := 680.0
const FRICTION_PER_SECOND := 0.72
const STOP_SPEED := 7.0
const STOP_GRACE_SECONDS := 0.18

const DISC_BLUE := Color("#5db7ef")
const DISC_BLUE_DARK := Color("#1769ad")
const DISC_HIGHLIGHT := Color(0.88, 0.98, 1.0, 0.82)

var start_position := Vector2.ZERO
var rink_bounds := Rect2()
var is_aiming := false
var shot_in_progress := false
var aim_direction := Vector2.UP
var power_ratio := 0.0
var stop_timer := 0.0

func _ready() -> void:
	start_position = position
	freeze = true
	queue_redraw()

func _physics_process(delta: float) -> void:
	if shot_in_progress:
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
	linear_velocity = aim_direction * lerpf(120.0, MAX_SPEED, power_ratio)
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
			-0.42 if position.x == min_x or position.x == max_x else 1.0,
			-0.42 if position.y == min_y or position.y == max_y else 1.0
		)

func _draw() -> void:
	draw_circle(Vector2(0.0, 11.0), DISC_RADIUS + 3.0, Color(0.0, 0.10, 0.17, 0.30))
	draw_circle(Vector2.ZERO, DISC_RADIUS + 3.0, DISC_BLUE_DARK)
	draw_circle(Vector2(0.0, -3.0), DISC_RADIUS, DISC_BLUE)
	draw_circle(Vector2(-9.0, -11.0), 7.0, DISC_HIGHLIGHT)
	draw_arc(Vector2(0.0, -3.0), DISC_RADIUS - 5.0, 0.0, TAU, 40, Color(0.88, 0.98, 1.0, 0.45), 2.0)

	if is_aiming and power_ratio > 0.0:
		var guide_length := lerpf(70.0, 180.0, power_ratio)
		var guide_end := aim_direction * guide_length
		draw_dashed_line(Vector2.ZERO, guide_end, Color(0.92, 0.98, 1.0, 0.85), 4.0, 10.0)
		draw_circle(guide_end, 7.0, Color(0.92, 0.98, 1.0, 0.42))