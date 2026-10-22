extends Control

## Pull-down aim pad. Press the dial and draw down to set pace,
## and sideways to set the line. The finger can leave the ring.

signal pull_changed(pull: Vector2)
signal pull_released(pull: Vector2)

const MAX_PULL := 156.0

var dragging := false
var pull := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if _device() and event is InputEventScreenTouch:
		if event.pressed:
			_begin(event.position)
		elif dragging:
			_finish()
		accept_event()
	elif _device() and event is InputEventScreenDrag and dragging:
		_set_pull(event.position - size * 0.5)
		accept_event()
	elif not _device() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(event.position)
		elif dragging:
			_finish()
		accept_event()
	elif not _device() and event is InputEventMouseMotion and dragging:
		_set_pull(event.position - size * 0.5)
		accept_event()


func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if _device() and event is InputEventScreenDrag:
		_set_pull(_local_point(event.position) - size * 0.5)
		get_viewport().set_input_as_handled()
	elif _device() and event is InputEventScreenTouch and not event.pressed:
		_finish()
		get_viewport().set_input_as_handled()
	elif not _device() and event is InputEventMouseMotion:
		_set_pull(_local_point(event.position) - size * 0.5)
		get_viewport().set_input_as_handled()
	elif not _device() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish()
		get_viewport().set_input_as_handled()


func _begin(local_pos: Vector2) -> void:
	dragging = true
	_set_pull(local_pos - size * 0.5)


func _finish() -> void:
	if not dragging:
		return
	dragging = false
	var released := pull
	pull = Vector2.ZERO
	queue_redraw()
	pull_released.emit(released)


func _set_pull(offset: Vector2) -> void:
	offset.y = maxf(offset.y, -8.0)
	if offset.length() > MAX_PULL:
		offset = offset.normalized() * MAX_PULL
	pull = offset
	pull_changed.emit(pull)
	queue_redraw()


func _local_point(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


func _device() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	draw_circle(center + Vector2(0.0, 3.0), radius, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(center, radius, Color(0.04, 0.1, 0.14, 0.92))
	draw_arc(center, radius - 1.5, 0.0, TAU, 72, Color(0.9, 0.76, 0.38), 2.5, true)
	draw_arc(center, radius * 0.42, 0.0, TAU, 40, Color(0.45, 0.86, 0.9, 0.35), 1.5, true)
	var chevron := center + Vector2(0.0, 8.0)
	draw_line(chevron + Vector2(-9.0, -4.0), chevron + Vector2(0.0, 8.0), Color(0.98, 0.9, 0.55, 0.9), 2.4, true)
	draw_line(chevron + Vector2(9.0, -4.0), chevron + Vector2(0.0, 8.0), Color(0.98, 0.9, 0.55, 0.9), 2.4, true)
	var knob := center + pull
	if pull.length() > 3.0:
		draw_line(center, knob, Color(0.95, 0.84, 0.42, 0.95), 3.0, true)
	draw_circle(knob, 12.0, Color(0.98, 0.82, 0.34))
	draw_circle(knob, 6.0, Color(0.22, 0.12, 0.04))
