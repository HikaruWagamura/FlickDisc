class_name DiscController
extends Node3D

signal aim_changed(direction: Vector2, power_ratio: float)
signal bias_changed(bias_ratio: float)
signal shot_started
signal shot_stopped

const DISC_RADIUS := 0.42
const MAX_DRAG_PIXELS := 160.0
const MAX_SPEED := 21.5
const MIN_SPEED := 3.2
const FRICTION_PER_SECOND := 0.52
const STOP_SPEED := 0.15
const STOP_GRACE_SECONDS := 0.15
const TURN_FAST := 0.015
const TURN_SLOW := 0.10
const PICK_RADIUS_PX := 88.0
const GUIDE_DOTS := 16

var start_position := Vector3.ZERO
var min_x := -2.4
var max_x := 2.4
var min_z := -37.5
var max_z := -0.5
var is_aiming := false
var shot_in_progress := false
var aim_direction := Vector3(0.0, 0.0, -1.0)
var power_ratio := 0.0
var bias_ratio := 0.0
var shot_bias := 0.0
var velocity := Vector3.ZERO
var stop_timer := 0.0
var spin_angle := 0.0

var _visual: Node3D
var _spin: Node3D
var _shadow: MeshInstance3D
var _guide: Node3D
var _dots: Array[MeshInstance3D] = []
var _end_ring: MeshInstance3D


func _ready() -> void:
	start_position = position
	_build_visual()
	_build_guide()


func _physics_process(delta: float) -> void:
	if not shot_in_progress:
		return
	var step := _integrate(global_position, velocity, shot_bias, delta)
	global_position = step[0]
	velocity = step[1]
	var speed := velocity.length()
	if speed > STOP_SPEED:
		var spin_sign := -1.0 if shot_bias < 0.0 else 1.0
		spin_angle += spin_sign * lerpf(2.2, 13.0, speed / MAX_SPEED) * delta
		stop_timer = 0.0
	else:
		velocity = Vector3.ZERO
		stop_timer += delta
		if stop_timer >= STOP_GRACE_SECONDS:
			shot_in_progress = false
			_apply_visual(0.0)
			shot_stopped.emit()
			return
	_apply_visual(speed)


func set_bias(value: float) -> void:
	bias_ratio = clampf(value, -1.0, 1.0)
	bias_changed.emit(bias_ratio)


func cycle_bias() -> void:
	if bias_ratio < -0.5:
		set_bias(0.0)
	elif bias_ratio > 0.5:
		set_bias(-1.0)
	else:
		set_bias(1.0)


func begin_aim(pointer_position: Vector2) -> bool:
	if shot_in_progress:
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var disc_screen := camera.unproject_position(global_position + Vector3(0.0, 0.12, 0.0))
	if pointer_position.distance_to(disc_screen) > PICK_RADIUS_PX:
		return false
	is_aiming = true
	update_aim(pointer_position)
	return true


func update_aim(pointer_position: Vector2) -> void:
	if not is_aiming:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var disc_screen := camera.unproject_position(global_position + Vector3(0.0, 0.12, 0.0))
	var pull_px := pointer_position - disc_screen
	var pull_len := pull_px.length()
	power_ratio = clampf(pull_len / MAX_DRAG_PIXELS, 0.0, 1.0)
	if pull_len > 6.0:
		var from := _ground_point(disc_screen)
		var to := _ground_point(disc_screen + pull_px)
		var world_pull := to - from
		world_pull.y = 0.0
		if world_pull.length() > 0.04:
			aim_direction = (-world_pull).normalized()
	aim_changed.emit(Vector2(aim_direction.x, aim_direction.z), power_ratio)
	_update_guide()


func release_aim(pointer_position: Vector2) -> void:
	if not is_aiming:
		return
	update_aim(pointer_position)
	is_aiming = false
	_hide_guide()
	if power_ratio < 0.08:
		power_ratio = 0.0
		aim_changed.emit(Vector2(aim_direction.x, aim_direction.z), power_ratio)
		return
	launch()


func launch() -> void:
	shot_bias = bias_ratio
	velocity = aim_direction * lerpf(MIN_SPEED, MAX_SPEED, power_ratio)
	velocity.y = 0.0
	shot_in_progress = true
	stop_timer = 0.0
	shot_started.emit()


func reset_to_start() -> void:
	velocity = Vector3.ZERO
	global_position = start_position
	is_aiming = false
	shot_in_progress = false
	power_ratio = 0.0
	stop_timer = 0.0
	shot_bias = 0.0
	spin_angle = 0.0
	_hide_guide()
	_apply_visual(0.0)


func set_rink_bounds(bounds_min: Vector2, bounds_max: Vector2) -> void:
	min_x = bounds_min.x + DISC_RADIUS
	max_x = bounds_max.x - DISC_RADIUS
	min_z = bounds_min.y + DISC_RADIUS
	max_z = bounds_max.y - DISC_RADIUS


func _integrate(pos: Vector3, vel: Vector3, bias: float, delta: float) -> Array:
	vel = _curve_and_damp(vel, bias, delta)
	pos += vel * delta
	pos.y = 0.0
	if pos.x < min_x:
		pos.x = min_x
		vel.x = absf(vel.x) * 0.18
	elif pos.x > max_x:
		pos.x = max_x
		vel.x = -absf(vel.x) * 0.18
	if pos.z < min_z:
		pos.z = min_z
		vel.z = absf(vel.z) * 0.18
	elif pos.z > max_z:
		pos.z = max_z
		vel.z = -absf(vel.z) * 0.18
	return [pos, vel]


func _curve_and_damp(vel: Vector3, bias: float, delta: float) -> Vector3:
	var planar := Vector2(vel.x, vel.z)
	var speed := planar.length()
	if speed > 0.001 and absf(bias) > 0.001:
		var slow := clampf(1.0 - speed / MAX_SPEED, 0.0, 1.0)
		var turn := lerpf(TURN_FAST, TURN_SLOW, slow * slow)
		planar = planar.rotated(bias * turn * delta)
		vel.x = planar.x
		vel.z = planar.y
	vel *= pow(FRICTION_PER_SECOND, delta)
	vel.y = 0.0
	return vel


func _ground_point(screen_pos: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.00001:
		return global_position
	var t := -origin.y / direction.y
	if t < 0.0:
		return global_position
	return origin + direction * t


func _apply_visual(speed: float) -> void:
	if _visual == null:
		return
	var lift := clampf(speed / MAX_SPEED, 0.0, 1.0)
	_visual.position.y = lift * 0.05
	_visual.rotation.z = shot_bias * 0.2 * lift
	_spin.rotation.y = spin_angle
	_shadow.position = Vector3(0.1 + lift * 0.08, 0.012, 0.06)


func _update_guide() -> void:
	if _guide == null:
		return
	var path := _predict_path()
	_guide.visible = power_ratio > 0.02 and path.size() > 1
	if not _guide.visible:
		return
	var last := path.size() - 1
	for i in _dots.size():
		var sample := int(round(float(i + 1) / float(_dots.size()) * float(last)))
		sample = clampi(sample, 0, last)
		_dots[i].global_position = path[sample] + Vector3(0.0, 0.045, 0.0)
		_dots[i].visible = true
	_end_ring.global_position = path[last] + Vector3(0.0, 0.04, 0.0)
	_end_ring.visible = true


func _hide_guide() -> void:
	if _guide != null:
		_guide.visible = false


func _predict_path() -> PackedVector3Array:
	var points := PackedVector3Array()
	var pos := global_position
	var vel := aim_direction * lerpf(MIN_SPEED, MAX_SPEED, power_ratio)
	vel.y = 0.0
	points.append(pos)
	var step := 0.08
	for i in 90:
		var integrated: Array = _integrate(pos, vel, bias_ratio, step)
		pos = integrated[0]
		vel = integrated[1]
		if i % 2 == 1:
			points.append(pos)
		if vel.length() <= STOP_SPEED:
			points.append(pos)
			break
	return points


func _build_visual() -> void:
	_shadow = MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.4
	shadow_mesh.bottom_radius = 0.4
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

	var rim_mat := _disc_mat(Color(0.40, 0.06, 0.10), 0.4, 0.15)
	var body_mat := _disc_mat(Color(0.82, 0.12, 0.18), 0.32, 0.18)
	var cap_mat := _disc_mat(Color(0.93, 0.22, 0.26), 0.28, 0.08)
	var mark_mat := StandardMaterial3D.new()
	mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark_mat.albedo_color = Color(0.97, 0.96, 0.93)

	_add_cylinder(_spin, Vector3(0.0, 0.03, 0.0), 0.43, 0.40, 0.05, rim_mat)
	_add_cylinder(_spin, Vector3(0.0, 0.068, 0.0), 0.39, 0.34, 0.058, body_mat)
	_add_cylinder(_spin, Vector3(0.0, 0.1, 0.0), 0.26, 0.26, 0.014, cap_mat)
	var ring := MeshInstance3D.new()
	ring.mesh = _annulus(0.16, 0.21, 28)
	ring.position = Vector3(0.0, 0.11, 0.0)
	ring.material_override = mark_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(ring)
	for spoke in 4:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.11, 0.008, 0.03)
		bar.mesh = box
		var angle := float(spoke) * TAU / 4.0
		bar.position = Vector3(cos(angle) * 0.1, 0.112, sin(angle) * 0.1)
		bar.rotation.y = angle
		bar.material_override = mark_mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_spin.add_child(bar)


func _build_guide() -> void:
	_guide = Node3D.new()
	_guide.visible = false
	add_child(_guide)
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = Color(0.96, 0.98, 0.95)
	for i in GUIDE_DOTS:
		var dot := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.075
		mesh.height = 0.15
		mesh.radial_segments = 10
		mesh.rings = 6
		dot.mesh = mesh
		dot.material_override = dot_mat
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_guide.add_child(dot)
		_dots.append(dot)
	_end_ring = MeshInstance3D.new()
	_end_ring.mesh = _annulus(0.18, 0.3, 32)
	var ring_mat := dot_mat.duplicate()
	_end_ring.material_override = ring_mat
	_end_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_guide.add_child(_end_ring)


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
