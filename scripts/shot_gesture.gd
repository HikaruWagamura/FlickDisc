extends Node

## Touch the disc and drag toward where the shot should start. That
## draws the dotted line. A tap locks it. The pull after that is the
## weight, and the needle is only the timing.

signal place_at(spot: Vector3)
signal aim_set(amount: float)
signal kept_aim
signal opened_take
signal cancelled_pull
signal fired(power: float, needle: float)

const TakeScript := preload("res://scripts/shot_take.gd")

var phase := "idle"
var anchor := Vector3.ZERO
var aim := 0.0
var camera: Camera3D
var hit_test: Callable
var board_point: Callable
var take

var _from := Vector2.ZERO
var _press_frame := -1
var _release_frame := -1
var _travel := 0.0


func _ready() -> void:
	take = TakeScript.new()
	take.name = "ShotTake"
	add_child(take)
	take.fired.connect(_on_fired)


func arm() -> void:
	phase = "idle"
	aim = 0.0
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


func read_aim() -> float:
	return aim


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
		_travel = 0.0
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
	_travel = maxf(_travel, _from.distance_to(screen))
	if phase == "place":
		# Along the line places the disc. A drag up the board points the shot.
		if _ahead(screen) > 18.0:
			_set_aim(screen)
		else:
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
	if phase == "place":
		if _ahead(screen) > 18.0:
			_set_aim(screen)
		elif _travel >= 10.0:
			_emit_place(screen)
		# A drag only sets the line. A tap on the disc enters the shot.
		if _travel < 18.0:
			phase = "take"
			take.open()
			opened_take.emit()
		else:
			phase = "place"
			kept_aim.emit()
		return
	if phase == "hold":
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


func _set_aim(screen: Vector2) -> void:
	# The line follows the finger. Drag toward the side you want.
	var side := _side_pixels(_disc_screen(), screen)
	aim = clampf(-side / 110.0, -1.0, 1.0)
	aim_set.emit(aim)


func _disc_screen() -> Vector2:
	if camera == null:
		return _from
	return camera.unproject_position(anchor)


func _ahead(screen: Vector2) -> float:
	return (screen - _disc_screen()).dot(-_pull_axis())


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
