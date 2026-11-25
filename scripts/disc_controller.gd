class_name DiscController
extends Node3D

const BowlScript := preload("res://scripts/bowl.gd")

signal aim_changed(direction: Vector2, power_ratio: float)
signal bias_changed(bias_ratio: float)
signal shot_started
signal shot_stopped
signal impacted(speed: float, hit_jack: bool, hit_bank: bool)

const DISC_RADIUS := 0.20
const MAX_DRAG_PIXELS := 210.0
const MAX_SPEED := 15.2
const MIN_SPEED := 6.0
const AIM_RESPONSE := 16.0
const DIAL_POWER_PIXELS := 148.0
const DIAL_SIDE_PIXELS := 132.0
const LINE_LOCK_PIXELS := 36.0
const MAX_LINE := 0.16
## Constant slowdown, so a draw takes about five seconds and can be watched.
const DECEL := 1.65
const STOP_SPEED := 0.15
const STOP_GRACE_SECONDS := 0.15
const BANK_KEEP := 0.40
## Radians of turn per metre at bias 1. The hand tightens as the bowl slows,
## and a straight delivery still finishes wide of the line.
const CURL_PER_METRE := 0.0052
const CURL_DRAW := 1.55
const DITCH_FLOOR_Y := -0.23
const RUNUP_MAX := 1.8
const PICK_RADIUS_PX := 88.0
const GUIDE_DOTS := 9
const GUIDE_PORTION := 0.26

var start_position := Vector3.ZERO
var green_min := Vector2(-2.9, -38.0)
var green_max := Vector2(2.9, -0.2)
var radius := DISC_RADIUS
var mass := 1.0
var is_jack := false
var is_aiming := false
var shot_in_progress := false
var aim_direction := Vector3(0.0, 0.0, -1.0)
var power_ratio := 0.0
var _aim_target := Vector3(0.0, 0.0, -1.0)
var _power_target := 0.0
var bias_ratio := 0.0
var shot_bias := 0.0
var shot_power := 0.0
var delivering_jack := false
var ditch_mode := false
var in_ditch := false
var bowl_bias := 0.95
var hand_sign := -1.0
var line_side := 0.0
var _line_locked := false
var velocity := Vector3.ZERO
var stop_timer := 0.0
var spin_angle := 0.0
var roll_basis := Basis.IDENTITY
var punch := 0.0
var palette_index := 0
var obstacles: Array = []

var _rim_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D
var _cap_mat: StandardMaterial3D
var _mark_mat: StandardMaterial3D
var _impact_speed := 0.0
var _impact_jack := false
var _impact_bank := false

var _visual: Node3D
var _spin: Node3D
var _shadow: MeshInstance3D
var _guide: Node3D
var _dots: Array[MeshInstance3D] = []
var _jack_visual: Node3D
var _bias_pip: Node3D
var _stone: Node3D
var _club_holder: Node3D


func _ready() -> void:
	start_position = position
	_build_visual()
	_build_guide()


func _process(delta: float) -> void:
	if not is_aiming:
		return
	var blend := 1.0 - exp(-AIM_RESPONSE * delta)
	var blended := aim_direction.lerp(_aim_target, blend)
	if blended.length() > 0.001:
		aim_direction = blended.normalized()
	power_ratio = lerpf(power_ratio, _power_target, blend)
	aim_changed.emit(Vector2(aim_direction.x, aim_direction.z), power_ratio)
	_update_guide()


func _physics_process(delta: float) -> void:
	if not shot_in_progress:
		return
	_impact_speed = 0.0
	_impact_jack = false
	_impact_bank = false
	var substeps := 6
	var step := delta / float(substeps)
	for _sub in substeps:
		if in_ditch:
			_sink(self, step)
		else:
			_advance(self, step, true)
		for body in obstacles:
			if body.in_ditch:
				if body.moving:
					_sink(body, step)
			elif body.moving:
				_advance(body, step, false)
		_resolve_pairs()
	_settle_frame(delta)
	_apply_visual(velocity.length())
	for body in obstacles:
		if body.has_method("present"):
			body.travel = body.velocity
			if "lean" in body:
				body.lean = _lean_angle(body.velocity.length())
			body.present(body.velocity.length())
	if _impact_speed > 0.45:
		impacted.emit(_impact_speed, _impact_jack, _impact_bank)


func configure_jack() -> void:
	delivering_jack = true
	bowl_bias = 0.0
	bias_ratio = 0.0
	radius = BowlScript.JACK_RADIUS
	mass = BowlScript.JACK_MASS
	is_jack = true
	if _visual != null:
		_visual.visible = false
	if _jack_visual != null:
		_jack_visual.visible = true
	line_side = 0.0
	bias_changed.emit(bias_ratio)


func configure_bowl(index: int, hand: float) -> void:
	delivering_jack = false
	hand_sign = hand
	var info: Dictionary = BowlScript.bowl_type(index)
	bowl_bias = float(info["bias"])
	bias_ratio = hand_sign * bowl_bias
	radius = DISC_RADIUS
	mass = BowlScript.DISC_MASS
	is_jack = false
	set_palette(palette_index)
	if _visual != null:
		_visual.visible = true
	if _jack_visual != null:
		_jack_visual.visible = false
	_place_pip()
	bias_changed.emit(bias_ratio)


func set_hand(hand: float) -> void:
	hand_sign = hand
	if delivering_jack:
		return
	bias_ratio = hand_sign * bowl_bias
	_place_pip()
	bias_changed.emit(bias_ratio)


func toggle_hand() -> void:
	set_hand(1.0 if hand_sign < 0.0 else -1.0)


func begin_dial() -> bool:
	if shot_in_progress or not visible:
		return false
	is_aiming = true
	_line_locked = false
	_aim_target = Vector3(line_side, 0.0, -1.0).normalized()
	aim_direction = _aim_target
	_power_target = 0.0
	power_ratio = 0.0
	return true


func update_dial(pull: Vector2) -> void:
	if not is_aiming:
		return
	var down := maxf(pull.y, 0.0)
	# Sideways sets the line. Pulling down afterwards sets the weight
	# and leaves that line alone, so the two choices stay separate.
	if down < LINE_LOCK_PIXELS:
		_line_locked = false
		if absf(pull.x) > 10.0:
			line_side = clampf(pull.x / DIAL_SIDE_PIXELS, -1.0, 1.0) * MAX_LINE
		_power_target = 0.0
	else:
		if not _line_locked:
			_line_locked = true
			if absf(pull.x) > 10.0:
				line_side = clampf(pull.x / DIAL_SIDE_PIXELS, -1.0, 1.0) * MAX_LINE
		_power_target = clampf((down - LINE_LOCK_PIXELS) / DIAL_POWER_PIXELS, 0.0, 1.0)
	_aim_target = Vector3(line_side, 0.0, -1.0).normalized()


func release_dial() -> void:
	if not is_aiming:
		return
	is_aiming = false
	aim_direction = _aim_target
	power_ratio = _power_target
	_hide_guide()
	aim_changed.emit(Vector2(aim_direction.x, aim_direction.z), power_ratio)
	if power_ratio < 0.08:
		power_ratio = 0.0
		aim_changed.emit(Vector2(aim_direction.x, aim_direction.z), power_ratio)
		return
	launch()


func pose_aim(aim: Vector3) -> void:
	if shot_in_progress:
		return
	if aim.length() < 0.001:
		aim_direction = Vector3(0.0, 0.0, -1.0)
	else:
		aim_direction = aim.normalized()
	_aim_target = aim_direction
	_apply_visual(0.0)


func preview_take(aim: Vector3, power: float) -> void:
	if shot_in_progress:
		return
	var direction := aim
	if direction.length() < 0.001:
		direction = Vector3(0.0, 0.0, -1.0)
	else:
		direction = direction.normalized()
	_aim_target = direction
	aim_direction = direction
	var shown := clampf(power, 0.0, 1.0)
	_power_target = shown
	power_ratio = shown
	is_aiming = shown >= 0.08
	if not is_aiming:
		_hide_guide()
	_apply_visual(0.0)
	aim_changed.emit(Vector2(aim_direction.x, aim_direction.z), shown)


func fire_taken(aim: Vector3, power: float) -> void:
	var direction := aim
	if direction.length() < 0.001:
		direction = Vector3(0.0, 0.0, -1.0)
	else:
		direction = direction.normalized()
	is_aiming = false
	aim_direction = direction
	_aim_target = direction
	power_ratio = clampf(power, 0.0, 1.0)
	_power_target = power_ratio
	_hide_guide()
	# Leave from the hand. Snapping back to the mat was a hitch on release.
	var held := global_position
	var runup := held.z - start_position.z
	if runup < -0.05 or runup > RUNUP_MAX or absf(held.x - start_position.x) > 0.4:
		global_position = start_position
	else:
		global_position = Vector3(start_position.x, 0.0, held.z)
	if power_ratio < 0.08:
		power_ratio = 0.0
		aim_changed.emit(Vector2(aim_direction.x, aim_direction.z), 0.0)
		return
	launch()


func launch() -> void:
	shot_power = power_ratio
	shot_bias = 0.0 if delivering_jack else bias_ratio
	velocity = _delivery_velocity(aim_direction, shot_power)
	shot_in_progress = true
	stop_timer = 0.0
	shot_started.emit()


func _delivery_velocity(aim: Vector3, power: float) -> Vector3:
	var speed := lerpf(MIN_SPEED, MAX_SPEED, power)
	var planar := Vector2(aim.x, aim.z)
	if planar.length() < 0.001:
		planar = Vector2(0.0, -1.0)
	# Leave on the line the player chose. The bias bends it afterwards.
	planar = planar.normalized() * speed
	return Vector3(planar.x, 0.0, planar.y)


func reset_to_start() -> void:
	velocity = Vector3.ZERO
	global_position = start_position
	in_ditch = false
	is_aiming = false
	shot_in_progress = false
	power_ratio = 0.0
	stop_timer = 0.0
	shot_bias = 0.0
	spin_angle = 0.0
	roll_basis = Basis.IDENTITY
	punch = 0.0
	visible = true
	_hide_guide()
	_apply_visual(0.0)


func set_palette(index: int) -> void:
	palette_index = index % 2
	BowlScript.apply_team(_body_mat, palette_index, false)


func set_green(bounds_min: Vector2, bounds_max: Vector2) -> void:
	green_min = bounds_min
	green_max = bounds_max


func _advance(body, delta: float, use_shot_bias: bool) -> void:
	if body.in_ditch:
		return
	var bias := shot_bias if use_shot_bias else 0.0
	var length_power := shot_power if use_shot_bias else 0.0
	var before_pos: Vector3 = body.global_position
	var moved := _move_planar(body.global_position, body.velocity, body.radius, bias, use_shot_bias, delta, length_power)
	var fell: bool = moved[3]
	if fell:
		body.in_ditch = true
		var lip: Vector3 = moved[0]
		var slide: Vector3 = moved[1]
		body.global_position = Vector3(lip.x, 0.0, lip.z)
		body.velocity = Vector3(slide.x, -0.85, slide.z)
		if body == self:
			spin_angle += before_pos.distance_to(body.global_position) / maxf(body.radius, 0.05)
		var fall_speed: float = moved[2]
		if fall_speed > _impact_speed:
			_impact_speed = fall_speed
			_impact_jack = body.is_jack
			_impact_bank = true
		return
	body.global_position = moved[0]
	body.velocity = moved[1]
	var rolled: Vector3 = body.global_position - before_pos
	body.roll_basis = BowlScript.roll_basis_by(body.roll_basis, rolled, body.radius)
	if body == self:
		spin_angle += rolled.length() / maxf(body.radius, 0.05)
	var wall_hit: float = moved[2]
	if wall_hit > 1.2 and wall_hit > _impact_speed:
		_impact_speed = wall_hit
		_impact_jack = false
		_impact_bank = true
	if body.velocity.length() <= STOP_SPEED:
		body.velocity = Vector3.ZERO


func _settle_frame(delta: float) -> void:
	if velocity.length() <= STOP_SPEED:
		velocity = Vector3.ZERO
		stop_timer += delta
	else:
		stop_timer = 0.0
	for body in obstacles:
		if not body.moving:
			continue
		if body.velocity.length() <= STOP_SPEED:
			body.stop_timer += delta
			if body.stop_timer >= STOP_GRACE_SECONDS:
				body.moving = false
				body.velocity = Vector3.ZERO
		else:
			body.stop_timer = 0.0
	if stop_timer >= STOP_GRACE_SECONDS and _obstacles_resting():
		shot_in_progress = false
		shot_stopped.emit()


func _obstacles_resting() -> bool:
	for body in obstacles:
		if body.moving:
			return false
	return true


func _resolve_pairs() -> void:
	for body in obstacles:
		_bounce(self, body)
	for i in obstacles.size():
		for j in range(i + 1, obstacles.size()):
			_bounce(obstacles[i], obstacles[j])


func _bounce(a, b) -> void:
	if a.in_ditch or b.in_ditch:
		return
	var jack_hit: bool = a.is_jack or b.is_jack
	var resolved: Dictionary = BowlScript.resolve(
		a.global_position, a.velocity, a.radius, a.mass,
		b.global_position, b.velocity, b.radius, b.mass,
		BowlScript.restitution_for(jack_hit)
	)
	a.global_position = resolved["a_pos"]
	a.velocity = resolved["a_vel"]
	b.global_position = resolved["b_pos"]
	b.velocity = resolved["b_vel"]
	var impact: float = resolved["impact"]
	if impact <= 0.2:
		return
	if a != self:
		a.moving = true
		a.stop_timer = 0.0
	if b != self:
		b.moving = true
		b.stop_timer = 0.0
	if impact > _impact_speed:
		_impact_speed = impact
		_impact_jack = jack_hit
		_impact_bank = false
	var hit_punch := clampf(impact / 6.0, 0.35, 1.0)
	_punch(a, hit_punch)
	_punch(b, hit_punch)


func _punch(body, amount: float) -> void:
	if body == self:
		punch = maxf(punch, amount)
	elif body.has_method("add_punch"):
		body.add_punch(amount)


func _move_planar(pos: Vector3, vel: Vector3, body_radius: float, bias: float, use_bias: bool, delta: float, _length_power: float = 0.0) -> Array:
	vel = _damp(vel, bias if use_bias else 0.0, delta)
	var before := vel
	pos += vel * delta
	pos.y = 0.0
	# In ditch mode the side strings and the far end are open. Crossing the
	# line starts the fall. The near end still rebounds.
	if ditch_mode and _crossed_ditch(pos, body_radius):
		var lip := _lip(pos, body_radius)
		var outward := Vector3(pos.x - lip.x, 0.0, pos.z - lip.z)
		if outward.length() < 0.001:
			outward = Vector3(before.x, 0.0, before.z)
		if outward.length() < 0.001:
			outward = Vector3(0.0, 0.0, -1.0)
		var carry := clampf(before.length() * 0.42, 0.9, 2.5)
		return [lip, outward.normalized() * carry, before.length(), true]
	var min_x := green_min.x + body_radius
	var max_x := green_max.x - body_radius
	var min_z := green_min.y + body_radius
	var max_z := green_max.y - body_radius
	var wall := 0.0
	if pos.x < min_x:
		pos.x = min_x
		wall = maxf(wall, absf(before.x))
		vel.x = absf(vel.x) * BANK_KEEP
		vel.z *= 0.92
	elif pos.x > max_x:
		pos.x = max_x
		wall = maxf(wall, absf(before.x))
		vel.x = -absf(vel.x) * BANK_KEEP
		vel.z *= 0.92
	if pos.z < min_z:
		pos.z = min_z
		wall = maxf(wall, absf(before.z))
		vel.z = absf(vel.z) * BANK_KEEP
		vel.x *= 0.92
	elif pos.z > max_z:
		pos.z = max_z
		wall = maxf(wall, absf(before.z))
		vel.z = -absf(vel.z) * BANK_KEEP
		vel.x *= 0.92
	return [pos, vel, wall, false]


func _crossed_ditch(pos: Vector3, body_radius: float) -> bool:
	return pos.x < green_min.x + body_radius or pos.x > green_max.x - body_radius or pos.z < green_min.y + body_radius


func _lip(pos: Vector3, body_radius: float) -> Vector3:
	var min_x := green_min.x + body_radius
	var max_x := green_max.x - body_radius
	var min_z := green_min.y + body_radius
	return Vector3(clampf(pos.x, min_x, max_x), 0.0, maxf(pos.z, min_z))


func _sink(body, delta: float) -> void:
	var before: Vector3 = body.global_position
	body.velocity.y -= 12.0 * delta
	var horizontal := Vector2(body.velocity.x, body.velocity.z)
	var speed := horizontal.length()
	if speed > 0.001:
		var drag := 7.5 if body.global_position.y <= DITCH_FLOOR_Y + 0.02 else 4.2
		var next := speed - drag * delta
		if next <= STOP_SPEED:
			horizontal = Vector2.ZERO
		else:
			horizontal = horizontal / speed * next
		body.velocity.x = horizontal.x
		body.velocity.z = horizontal.y
	body.global_position += body.velocity * delta
	if body.global_position.y < DITCH_FLOOR_Y:
		body.global_position.y = DITCH_FLOOR_Y
		body.velocity.y = 0.0
	var moved: Vector3 = body.global_position - before
	body.roll_basis = BowlScript.roll_basis_by(body.roll_basis, moved, body.radius)
	if body == self:
		spin_angle += moved.length() / maxf(body.radius, 0.05)
	var height: float = body.global_position.y
	var slide := Vector2(body.velocity.x, body.velocity.z)
	var drop: float = body.velocity.y
	if height <= DITCH_FLOOR_Y + 0.001 and slide.length() <= STOP_SPEED and absf(drop) < 0.05:
		body.velocity = Vector3.ZERO
		if body != self:
			body.moving = false


func weight_for_length(metres: float, bias: float) -> float:
	var goal := maxf(metres, 2.0)
	var low := 0.12
	var high := 1.0
	for _step in 12:
		var mid := (low + high) * 0.5
		if _forward_travel(mid, bias) < goal:
			low = mid
		else:
			high = mid
	return clampf((low + high) * 0.5, 0.12, 0.98)


func predict_rest(from: Vector3, aim: Vector3, power: float, bias: float) -> Vector3:
	var pos := from
	var vel := _delivery_velocity(aim, power)
	var step := 0.05
	for _i in 480:
		var moved := _move_planar(pos, vel, radius, bias, true, step, power)
		pos = moved[0]
		vel = moved[1]
		if bool(moved[3]) or vel.length() < STOP_SPEED:
			break
	return pos


func _forward_travel(power: float, bias: float) -> float:
	return -predict_rest(Vector3.ZERO, Vector3(0.0, 0.0, -1.0), power, bias).z


func will_ditch(from: Vector3, aim: Vector3, power: float, bias: float) -> bool:
	var pos := from
	var vel := _delivery_velocity(aim, power)
	var step := 0.05
	for _i in 480:
		var moved := _move_planar(pos, vel, radius, bias, true, step, power)
		pos = moved[0]
		vel = moved[1]
		if bool(moved[3]):
			return true
		if vel.length() < STOP_SPEED:
			return false
	return false


func _damp(vel: Vector3, bias: float, delta: float) -> Vector3:
	var planar := Vector2(vel.x, vel.z)
	var speed := planar.length()
	if speed < 0.001:
		return Vector3.ZERO
	if absf(bias) > 0.001:
		var slow := clampf(1.0 - speed / MAX_SPEED, 0.0, 1.0)
		var curve := CURL_PER_METRE * (1.0 + CURL_DRAW * slow * slow)
		# Turn with the distance run. Negative bias is the forehand
		# and bends to the player's left. The same bowl takes the same
		# hand from a centre line or a wide one.
		planar = planar.rotated(bias * curve * speed * delta)
		speed = planar.length()
	var next := speed - DECEL * delta
	if next <= STOP_SPEED:
		return Vector3.ZERO
	planar = planar / speed * next
	return Vector3(planar.x, 0.0, planar.y)


func _lean_angle(speed: float) -> float:
	if not shot_in_progress or absf(shot_bias) < 0.01 or speed < 0.2:
		return 0.0
	var slow := clampf(1.0 - speed / MAX_SPEED, 0.0, 1.0)
	var into := clampf(absf(shot_bias) / 1.45, 0.0, 1.0)
	var wobble := sin(spin_angle * 2.0) * 0.03 * clampf(speed / 8.0, 0.0, 1.0)
	# Negative bias draws left, so the bowl tips onto that side.
	return -signf(shot_bias) * into * lerpf(0.05, 0.2, slow * slow) + wobble


func _apply_visual(speed: float) -> void:
	if _visual == null:
		return
	punch = move_toward(punch, 0.0, 0.08)
	var lift := clampf(speed / MAX_SPEED, 0.0, 1.0)
	var hop := lift * 0.016 + punch * 0.05
	var sit := radius - BowlScript.SIT_NEST
	if delivering_jack and _jack_visual != null:
		_visual.position = Vector3.ZERO
		_visual.basis = Basis.IDENTITY
		_jack_visual.position = Vector3(0.0, sit + hop, 0.0)
		_jack_visual.transform.basis = roll_basis
	else:
		var facing := velocity if velocity.length() > 0.2 else aim_direction
		_visual.position = Vector3(0.0, sit + hop, 0.0)
		_visual.basis = BowlScript._posed_basis(facing, _lean_angle(speed), Basis.IDENTITY)
		if _spin != null:
			_spin.position = Vector3.ZERO
			if shot_in_progress or speed > 0.2:
				_spin.transform.basis = roll_basis
			else:
				var yaw := atan2(aim_direction.x, -aim_direction.z)
				_spin.rotation = Vector3(0.0, lerp_angle(_spin.rotation.y, yaw, 0.4), 0.0)
		_place_pip()
	if _shadow != null:
		_shadow.visible = global_position.y > -0.06
		_shadow.position = Vector3(0.0, 0.003, 0.0)


func guide_points() -> PackedVector3Array:
	if not is_aiming or power_ratio <= 0.02:
		return PackedVector3Array()
	return _predict_path()


func _update_guide() -> void:
	# The aim is drawn as screen dots, so the world meshes stay hidden.
	# They sat on the white dashes and read as stray specks.
	_hide_guide()


func _hide_guide() -> void:
	if _guide != null:
		_guide.visible = false


func _predict_path() -> PackedVector3Array:
	# Only the opening quarter of the run. The rest of the hand is for
	# the player to judge.
	var aiming_line := power_ratio < 0.08
	var pace := 0.42 if aiming_line else power_ratio
	# The guide is the line the finger chose. Bias bends the bowl after release.
	var bias := 0.0
	var use_bias := false
	var samples: Array[Vector3] = []
	var dists: Array[float] = []
	var pos := global_position
	var vel := _delivery_velocity(aim_direction, pace)
	var travelled := 0.0
	samples.append(pos)
	dists.append(0.0)
	var step := 0.05
	for i in 220:
		var prev := pos
		var moved := _move_planar(pos, vel, radius, bias, use_bias, step, pace)
		pos = moved[0]
		vel = moved[1]
		travelled += prev.distance_to(pos)
		if i % 2 == 1:
			samples.append(pos)
			dists.append(travelled)
		if moved[3] or vel.length() < STOP_SPEED:
			break
	var limit := maxf(travelled * GUIDE_PORTION, 1.2)
	var points := PackedVector3Array()
	for i in samples.size():
		if dists[i] <= limit:
			points.append(samples[i])
	if points.size() < 2 and samples.size() > 1:
		points.append(samples[1])
	return points


func _build_visual() -> void:
	_shadow = MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.16
	shadow_mesh.bottom_radius = 0.16
	shadow_mesh.height = 0.008
	shadow_mesh.radial_segments = 24
	_shadow.mesh = shadow_mesh
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.albedo_color = Color(0.0, 0.05, 0.02, 0.34)
	_shadow.material_override = shadow_mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.position = Vector3(0.1, 0.012, 0.06)
	add_child(_shadow)

	_visual = Node3D.new()
	add_child(_visual)
	_spin = Node3D.new()
	_visual.add_child(_spin)

	var dressed: Dictionary = BowlScript.dress_stone(_spin, palette_index, hand_sign, false)
	_rim_mat = dressed["rim"]
	_body_mat = dressed["body"]
	_cap_mat = dressed["cap"]
	_mark_mat = dressed["mark"]
	_bias_pip = dressed["weight"]
	_club_holder = dressed["weight"]
	_stone = dressed.get("stone", dressed["weight"])
	_place_pip()

	_jack_visual = Node3D.new()
	_jack_visual.visible = false
	add_child(_jack_visual)
	var jack_mesh: Mesh = BowlScript.jack_mesh()
	var jack_mat := _disc_mat(Color(0.96, 0.94, 0.88), 0.28, 0.08)
	BowlScript.apply_jack(jack_mat)
	if jack_mesh != null:
		var jack_mi := MeshInstance3D.new()
		jack_mi.mesh = jack_mesh
		BowlScript._fit_mesh(jack_mi, BowlScript.JACK_RADIUS * 2.0)
		jack_mi.material_override = jack_mat
		_jack_visual.add_child(jack_mi)
	else:
		_add_sphere(_jack_visual, Vector3.ZERO, BowlScript.JACK_RADIUS, Vector3.ONE, jack_mat)


func _place_pip() -> void:
	if _bias_pip == null:
		return
	_bias_pip.rotation = Vector3(0.0, BowlScript.hand_yaw(hand_sign), 0.0)


func _build_guide() -> void:
	_guide = Node3D.new()
	_guide.visible = false
	add_child(_guide)
	for i in GUIDE_DOTS:
		var dot := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.055
		mesh.height = 0.11
		mesh.radial_segments = 12
		mesh.rings = 8
		dot.mesh = mesh
		var dot_mat := StandardMaterial3D.new()
		dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dot_mat.albedo_color = Color(0.97, 0.98, 1.0, 0.96)
		dot_mat.emission_enabled = true
		dot_mat.emission = Color(0.92, 0.96, 1.0)
		dot_mat.emission_energy_multiplier = 0.55
		dot.material_override = dot_mat
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_guide.add_child(dot)
		_dots.append(dot)


func _add_sphere(parent: Node3D, pos: Vector3, radius_m: float, scale: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius_m
	mesh.height = radius_m * 2.0
	mesh.radial_segments = 28
	mesh.rings = 14
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale
	mi.material_override = mat
	parent.add_child(mi)


func _add_cylinder(parent: Node3D, pos: Vector3, bottom_r: float, top_r: float, height: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_r
	mesh.top_radius = top_r
	mesh.height = height
	mesh.radial_segments = 28
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)


func _disc_mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return mat


func _annulus(inner_r: float, outer_r: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var i0 := Vector3(cos(a0) * inner_r, 0.0, sin(a0) * inner_r)
		var i1 := Vector3(cos(a1) * inner_r, 0.0, sin(a1) * inner_r)
		var o0 := Vector3(cos(a0) * outer_r, 0.0, sin(a0) * outer_r)
		var o1 := Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r)
		for vertex in [i0, o0, o1, i0, o1, i1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	return st.commit()
