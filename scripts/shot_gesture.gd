extends Node

## Touch the disc and slide it on the line. Releasing opens the fan.
## The next pull, back along the shot, is the strike.

signal place_at(spot: Vector3)
signal opened_take
signal cancelled_pull
signal fired(power: float, needle: float)

const TakeScript := preload("res://scripts/shot_take.gd")

var phase := "idle"
var anchor := Vector3.ZERO
var camera: Camera3D
var hit_test: Callable
var board_point: Callable
var take

var _from := Vector2.ZERO
var _press_frame := -1
var _release_frame := -1


func _ready() -> void:
	take = TakeScript.new()
	take.name = "ShotTake"
	add_child(take)
	take.fired.connect(_on_fired)


func arm() -> void:
	phase = "idle"
	if take != null:
		take.close()


func busy() -> void:
	phase = "busy"
	if take != null:
		take.close()


func advance(delta: float) -> void:
	if take != null:
		take.advance(delta)


func read_power() -> float:
	if take == null:
		return 0.0
	return float(take.power)


func read_needle() -> float:
	if take == null:
		return 0.0
	return float(take.needle)


func _input(event: InputEvent) -> void:
	if phase == "busy":
		return
	if _is_mouse_press(event):
		var frame := Engine.get_process_frames()
		if frame == _press_frame:
			return
		_press_frame = frame
		var screen: Vector2 = event.position
		var hit := false
		if hit_test.is_valid():
			hit = bool(hit_test.call(screen))
		if not hit:
			return
		_from = screen
		if phase == "idle" or phase == "place":
			phase = "place"
		elif phase == "take":
			phase = "hold"
		get_viewport().set_input_as_handled()
		return
	if phase != "place" and phase != "hold" and phase != "pull":
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_move(event.position)
		get_viewport().set_input_as_handled()
	elif _is_mouse_release(event):
		var frame := Engine.get_process_frames()
		if frame == _release_frame:
			return
		_release_frame = frame
		_up(event.position)
		get_viewport().set_input_as_handled()


func _move(screen: Vector2) -> void:
	if phase == "place":
		_emit_place(screen)
		return
	var pull := _pull_pixels(_from, screen)
	var side := absf(_side_pixels(_from, screen))
	if phase == "hold":
		if pull > 16.0:
			phase = "pull"
			take.begin_pull()
			take.drag(pull)
		elif side > 26.0 and pull < 14.0:
			phase = "place"
			_emit_place(screen)
		return
	if phase == "pull":
		take.drag(pull)


func _up(screen: Vector2) -> void:
	if phase == "place" or phase == "hold":
		if phase == "place":
			_emit_place(screen)
		phase = "take"
		take.open()
		opened_take.emit()
		return
	if phase != "pull":
		return
	take.drag(_pull_pixels(_from, screen))
	var before := phase
	take.release()
	if phase == before:
		phase = "take"
		cancelled_pull.emit()


func _on_fired(power: float, needle: float) -> void:
	phase = "busy"
	fired.emit(power, needle)


func _emit_place(screen: Vector2) -> void:
	if not board_point.is_valid():
		return
	var spot: Vector3 = board_point.call(screen)
	place_at.emit(spot)


func _pull_axis() -> Vector2:
	if camera == null:
		return Vector2(0, 1)
	var origin := camera.unproject_position(anchor)
	var back := camera.unproject_position(anchor + Vector3(0.0, 0.0, 0.45))
	var axis := back - origin
	if axis.length() < 2.0:
		return Vector2(0, 1)
	return axis.normalized()


func _pull_pixels(from: Vector2, to: Vector2) -> float:
	return (to - from).dot(_pull_axis())


func _side_pixels(from: Vector2, to: Vector2) -> float:
	var axis := _pull_axis()
	return (to - from).dot(Vector2(-axis.y, axis.x))


func _is_mouse_press(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed


func _is_mouse_release(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
