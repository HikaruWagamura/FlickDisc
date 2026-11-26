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

## One drag is the whole shot. The finger pulls the bowl back, and the
## bowl leaves along that same line. No separate lock, no timing needle.
var direct := false
var direct_aim := Vector3(0.0, 0.0, -1.0)
var direct_power := 0.0
var direct_hold := Vector3.ZERO
var finger := Vector2.ZERO
var _raw_aim := Vector3(0.0, 0.0, -1.0)
var _raw_power := 0.0
var _raw_hold := Vector3.ZERO
const DIRECT_METRES := 0.78
const DIRECT_PULL_PX := 235.0
const DIRECT_SIDE_PX := 155.0
const DIRECT_AIM_X := 0.34
const AIM_SMOOTH := 16.0
const POWER_SMOOTH := 16.0
const HOLD_SMOOTH := 14.0

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
	if not direct or phase != "pull":
		return
	var dt := maxf(delta, 0.0001)
	var aim_blend := 1.0 - exp(-AIM_SMOOTH * dt)
	var pow_blend := 1.0 - exp(-POWER_SMOOTH * dt)
	var hold_blend := 1.0 - exp(-HOLD_SMOOTH * dt)
	direct_aim = direct_aim.lerp(_raw_aim, aim_blend)
	if direct_aim.length() > 0.001:
		direct_aim = direct_aim.normalized()
	else:
		direct_aim = Vector3(0.0, 0.0, -1.0)
	direct_power = lerpf(direct_power, _raw_power, pow_blend)
	direct_hold = direct_hold.lerp(_raw_hold, hold_blend)


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
	if direct:
		_direct_input(event)
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


func _direct_input(event: InputEvent) -> void:
	if _is_mouse_press(event):
		var frame := Engine.get_process_frames()
		if frame == _press_frame:
			return
		var screen: Vector2 = event.position
		if not _direct_can_start(screen):
			return
		_press_frame = frame
		phase = "pull"
		_from = screen
		_travel = 0.0
		direct_aim = Vector3(0.0, 0.0, -1.0)
		direct_power = 0.0
		direct_hold = anchor
		_raw_aim = direct_aim
		_raw_power = 0.0
		_raw_hold = anchor
		_apply_direct(screen)
		get_viewport().set_input_as_handled()
		return
	if phase != "pull":
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_apply_direct(event.position)
		get_viewport().set_input_as_handled()
	elif _is_mouse_release(event):
		var frame := Engine.get_process_frames()
		if frame == _release_frame:
			return
		_release_frame = frame
		_apply_direct(event.position)
		if direct_power >= 0.07:
			phase = "busy"
			fired.emit(direct_power, 0.0)
		else:
			phase = "idle"
			direct_power = 0.0
			direct_hold = anchor
			_raw_power = 0.0
			_raw_hold = anchor
			_raw_aim = Vector3(0.0, 0.0, -1.0)
			cancelled_pull.emit()
		get_viewport().set_input_as_handled()


func _direct_can_start(screen: Vector2) -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and hovered.mouse_filter == Control.MOUSE_FILTER_STOP:
		return false
	if hit_test.is_valid() and bool(hit_test.call(screen)):
		return true
	var view := get_viewport().get_visible_rect().size
	# The mat sits in the lower half. A press there still takes the bowl.
	return screen.y > view.y * 0.58 and screen.x > 36.0 and screen.x < view.x - 36.0


func _apply_direct(screen: Vector2) -> void:
	finger = screen
	_travel = maxf(_travel, _from.distance_to(screen))
	# The green in front of the camera never reaches behind the mat, so the
	# pull is the finger's own travel. Use the space below the bowl; do not
	# fill the bar on the first few centimetres of drag.
	var pull_px := maxf(_pull_pixels(_from, screen), 0.0)
	var side_px := _side_pixels(_from, screen)
	if pull_px < 10.0 and absf(side_px) < 6.0:
		_raw_power = 0.0
		_raw_aim = Vector3(0.0, 0.0, -1.0)
		_raw_hold = anchor
		return
	var travel := clampf(pull_px / DIRECT_PULL_PX, 0.0, 1.0)
	var back := travel * DIRECT_METRES
	# Slingshot: pull bottom-left, send top-right. Finger left is +side_px.
	var nudge := 0.0
	if absf(side_px) > 4.0:
		nudge = clampf(side_px / DIRECT_SIDE_PX, -1.0, 1.0)
	_raw_aim = Vector3(nudge * DIRECT_AIM_X, 0.0, -1.0).normalized()
	_raw_power = pow(travel, 0.84)
	_raw_hold = anchor + Vector3(-nudge * travel * 0.10, 0.0, back)


func _is_mouse_press(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed


func _is_mouse_release(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
