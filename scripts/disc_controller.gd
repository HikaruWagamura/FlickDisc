class_name DiscController
extends Node3D

const BowlScript := preload("res://scripts/bowl.gd")

signal aim_changed(direction: Vector2, power_ratio: float)
signal bias_changed(bias_ratio: float)
signal shot_started
signal shot_stopped
signal impacted(speed: float, hit_jack: bool, hit_bank: bool)

const DISC_RADIUS := 0.18
const MAX_DRAG_PIXELS := 210.0
const MAX_SPEED := 66.0
const MIN_SPEED := 5.0
const AIM_RESPONSE := 11.0
const DIAL_POWER_PIXELS := 148.0
const DIAL_SIDE_PIXELS := 132.0
const LINE_LOCK_PIXELS := 36.0
const MAX_LINE := 0.16
const FRICTION_PER_SECOND := 0.52
const STOP_SPEED := 0.15
const STOP_GRACE_SECONDS := 0.15
## Radians of turn per metre at bias 1. The same bowl takes the same
## curve whatever the aim, so a straight line still finishes wide.
const CURL_PER_METRE := 0.0025
const CURL_DRAW := 0.45
const PICK_RADIUS_PX := 88.0
const GUIDE_DOTS := 6
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
var _bias_pip: MeshInstance3D


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
	var substeps := 4
	var step := delta / float(substeps)
	for _sub in substeps:
		_advance(self, step, true)
		for body in obstacles:
			if body.moving and not body.in_ditch:
				_advance(body, step, false)
		_resolve_pairs()
	_settle_frame(delta)
	_apply_visual(velocity.length())
	for body in obstacles:
		if body.has_method("present"):
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
	set_palette(0)
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
	global_position = start_position
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
	punch = 0.0
	visible = true
	_hide_guide()
	_apply_visual(0.0)


func set_palette(index: int) -> void:
	palette_index = index % 4
	if _rim_mat == null:
		return
	var colors: Array = BowlScript.palette(palette_index)
	_rim_mat.albedo_color = colors[0]
	_body_mat.albedo_color = colors[1]
	_cap_mat.albedo_color = colors[2]
	_mark_mat.albedo_color = colors[3]


func set_green(bounds_min: Vector2, bounds_max: Vector2) -> void:
	green_min = bounds_min
	green_max = bounds_max


func _advance(body, delta: float, use_shot_bias: bool) -> void:
	if body.in_ditch:
		return
	var bias := shot_bias if use_shot_bias else 0.0
	var length_power := shot_power if use_shot_bias else 0.0
	var moved := _move_planar(body.global_position, body.velocity, body.radius, bias, use_shot_bias, delta, length_power)
	var fell: bool = moved[3]
	if fell:
		body.in_ditch = true
		body.velocity = Vector3.ZERO
		body.global_position = moved[0]
		if body != self:
			body.moving = false
		var fall_speed: float = moved[2]
		if fall_speed > _impact_speed:
			_impact_speed = fall_speed
			_impact_jack = body.is_jack
			_impact_bank = true
		return
	body.global_position = moved[0]
	body.velocity = moved[1]
	var wall_hit: float = moved[2]
	if wall_hit > 1.2 and wall_hit > _impact_speed:
		_impact_speed = wall_hit
		_impact_jack = false
		_impact_bank = true
	var speed: float = body.velocity.length()
	if speed > STOP_SPEED:
		var spin_sign := -1.0 if bias < 0.0 else 1.0
		body.spin_angle += spin_sign * lerpf(2.2, 13.0, speed / MAX_SPEED) * delta
	else:
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
	var hit_punch := clampf(impact / 10.0, 0.2, 1.0)
	_punch(a, hit_punch)
	_punch(b, hit_punch)


func _punch(body, amount: float) -> void:
	if body == self:
		punch = maxf(punch, amount)
	elif body.has_method("add_punch"):
		body.add_punch(amount)


func _move_planar(pos: Vector3, vel: Vector3, body_radius: float, bias: float, use_bias: bool, delta: float, length_power: float = 0.0) -> Array:
	if use_bias:
		vel = _curve_and_damp(vel, bias, delta, length_power)
	else:
		vel *= pow(FRICTION_PER_SECOND, delta)
		vel.y = 0.0
	var before := vel
	pos += vel * delta
	pos.y = 0.0
	# In ditch mode the side strings and the far end are open. Crossing the
	# line drops the bowl in. The near end still rebounds.
	if ditch_mode and (pos.x < green_min.x + body_radius or pos.x > green_max.x - body_radius or pos.z < green_min.y + body_radius):
		return [_ditch_park(pos), Vector3.ZERO, before.length(), true]
	var min_x := green_min.x + body_radius
	var max_x := green_max.x - body_radius
	var min_z := green_min.y + body_radius
	var max_z := green_max.y - body_radius
	var wall := 0.0
	if pos.x < min_x:
		pos.x = min_x
		wall = maxf(wall, absf(before.x))
		vel.x = absf(vel.x) * 0.18
	elif pos.x > max_x:
		pos.x = max_x
		wall = maxf(wall, absf(before.x))
		vel.x = -absf(vel.x) * 0.18
	if pos.z < min_z:
		pos.z = min_z
		wall = maxf(wall, absf(before.z))
		vel.z = absf(vel.z) * 0.18
	elif pos.z > max_z:
		pos.z = max_z
		wall = maxf(wall, absf(before.z))
		vel.z = -absf(vel.z) * 0.18
	return [pos, vel, wall, false]


func _ditch_park(pos: Vector3) -> Vector3:
	var parked := pos
	var near_side := absf(parked.x) > green_max.x - 0.7
	if near_side and parked.x < 0.0:
		parked.x = green_min.x - 0.44
	elif near_side and parked.x > 0.0:
		parked.x = green_max.x + 0.44
	if parked.z < green_min.y + 0.7:
		parked.z = green_min.y - 0.44
	parked.y = -0.12
	return parked


func _curve_and_damp(vel: Vector3, bias: float, delta: float, _length_power: float) -> Vector3:
	var planar := Vector2(vel.x, vel.z)
	var speed := planar.length()
	if speed > 0.001 and absf(bias) > 0.001:
		var slow := clampf(1.0 - speed / MAX_SPEED, 0.0, 1.0)
		var curve := CURL_PER_METRE * (1.0 + CURL_DRAW * slow * slow)
		# Turn with the distance run, not with an aim that pulls back
		# to the jack. A centre line and a wide line take the same hand.
		# Negative bias is the forehand and turns to the player's left.
		planar = planar.rotated(bias * curve * speed * delta)
		vel.x = planar.x
		vel.z = planar.y
	vel *= pow(FRICTION_PER_SECOND, delta)
	vel.y = 0.0
	return vel


func _apply_visual(speed: float) -> void:
	if _visual == null:
		return
	punch = move_toward(punch, 0.0, 0.08)
	var lift := clampf(speed / MAX_SPEED, 0.0, 1.0)
	_visual.position.y = lift * 0.05 + punch * 0.07
	_visual.rotation.z = shot_bias * 0.2 * lift
	_spin.rotation.y = spin_angle
	_shadow.position = Vector3(0.1 + lift * 0.08, 0.012, 0.06)


func _update_guide() -> void:
	if _guide == null:
		return
	var path := _predict_path()
	var show_line := path.size() > 1 and power_ratio > 0.02
	_guide.visible = show_line
	if not _guide.visible:
		return
	var last := path.size() - 1
	for i in _dots.size():
		var along := float(i + 1) / float(_dots.size())
		var sample := int(round(along * float(last)))
		sample = clampi(sample, 0, last)
		_dots[i].global_position = path[sample] + Vector3(0.0, 0.06, 0.0)
		var scale := lerpf(1.0, 0.22, along)
		_dots[i].scale = Vector3(scale, scale, scale)
		var mat := _dots[i].material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = lerpf(0.9, 0.0, along)
		_dots[i].visible = true


func _hide_guide() -> void:
	if _guide != null:
		_guide.visible = false


func _predict_path() -> PackedVector3Array:
	# Only the opening quarter of the run. The rest of the hand is for
	# the player to judge.
	var aiming_line := power_ratio < 0.08
	var pace := 0.42 if aiming_line else power_ratio
	var bias := 0.0 if delivering_jack else bias_ratio
	var use_bias := not delivering_jack
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

	_rim_mat = _disc_mat(Color(0.09, 0.08, 0.07), 0.4, 0.15)
	_body_mat = _disc_mat(Color(0.93, 0.90, 0.84), 0.32, 0.08)
	_cap_mat = _disc_mat(Color(0.98, 0.95, 0.88), 0.28, 0.08)
	_mark_mat = StandardMaterial3D.new()
	_mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_mat.albedo_color = Color(0.12, 0.10, 0.08)

	_add_cylinder(_spin, Vector3(0.0, 0.014, 0.0), 0.18, 0.172, 0.02, _rim_mat)
	var gold := _disc_mat(Color(0.86, 0.68, 0.28), 0.28, 0.78)
	_add_cylinder(_spin, Vector3(0.0, 0.022, 0.0), 0.15, 0.15, 0.004, gold)
	_add_cylinder(_spin, Vector3(0.0, 0.026, 0.0), 0.132, 0.132, 0.006, _body_mat)
	_bias_pip = MeshInstance3D.new()
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 0.02
	pip_mesh.height = 0.04
	pip_mesh.radial_segments = 12
	pip_mesh.rings = 8
	_bias_pip.mesh = pip_mesh
	_bias_pip.material_override = _mark_mat
	_bias_pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(_bias_pip)
	_place_pip()

	_jack_visual = Node3D.new()
	_jack_visual.visible = false
	add_child(_jack_visual)
	var jack_mat := _disc_mat(Color(0.98, 0.82, 0.28), 0.22, 0.72)
	jack_mat.emission_enabled = true
	jack_mat.emission = Color(0.62, 0.42, 0.08)
	jack_mat.emission_energy_multiplier = 0.35
	_add_sphere(_jack_visual, Vector3(0.0, BowlScript.JACK_RADIUS, 0.0), BowlScript.JACK_RADIUS, Vector3.ONE, jack_mat)


func _place_pip() -> void:
	if _bias_pip == null:
		return
	_bias_pip.position = Vector3(hand_sign * 0.13, 0.02, 0.0)


func _build_guide() -> void:
	_guide = Node3D.new()
	_guide.visible = false
	add_child(_guide)
	for i in GUIDE_DOTS:
		var dot := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.045
		mesh.height = 0.09
		mesh.radial_segments = 12
		mesh.rings = 8
		dot.mesh = mesh
		var dot_mat := StandardMaterial3D.new()
		dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dot_mat.albedo_color = Color(0.98, 0.84, 0.32, 0.95)
		dot_mat.emission_enabled = true
		dot_mat.emission = Color(1.0, 0.78, 0.28)
		dot_mat.emission_energy_multiplier = 0.35
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
