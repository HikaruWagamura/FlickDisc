class_name DiscController
extends Node3D

## Player puck. Motion stays on the table plane: drag backward to aim, release to flick.
## Bias bends the shot as the puck slows, matching the 2D rules.

signal aim_changed(direction: Vector3, power_ratio: float)
signal bias_changed(bias_ratio: float)
signal shot_started
signal shot_stopped

const Metrics = preload("res://scripts/table_metrics.gd")

const MAX_DRAG_DISTANCE := 0.58
const MIN_SPEED := 0.55
const MAX_SPEED := 2.6
const FRICTION_PER_SECOND := 0.25
const STOP_SPEED := 0.06
const STOP_GRACE_SECONDS := 0.12
const RAIL_RESTITUTION := 0.5

var start_position := Metrics.PLAYER_START
var is_aiming := false
var shot_in_progress := false
var aim_direction := Vector3(0.0, 0.0, -1.0)
var power_ratio := 0.0
var bias_ratio := 0.0
var shot_bias := 0.0
var stop_timer := 0.0
var slide_velocity := Vector3.ZERO

var _visual: Node3D
var _guide_mesh := ImmediateMesh.new()
var _guide_instance: MeshInstance3D
var _end_marker: MeshInstance3D
var _idle_ring: MeshInstance3D
var _guide_has_surface := false

func _ready() -> void:
	start_position = Metrics.PLAYER_START
	_build_visual()
	_build_guide()
	reset_to_start()

func _process(_delta: float) -> void:
	if _idle_ring == null:
		return
	var show_ring := not shot_in_progress and not is_aiming
	_idle_ring.visible = show_ring
	if show_ring:
		var pulse := 1.0 + sin(float(Time.get_ticks_msec()) * 0.004) * 0.08
		_idle_ring.scale = Vector3(pulse, 1.0, pulse)
	if is_aiming:
		_rebuild_guide()
	elif _guide_has_surface and not shot_in_progress:
		_clear_guide()

func _physics_process(delta: float) -> void:
	if not shot_in_progress:
		return
	var speed := Vector2(slide_velocity.x, slide_velocity.z).length()
	if speed > STOP_SPEED:
		var slowdown := clampf(1.0 - speed / MAX_SPEED, 0.0, 1.0)
		var turn_rate := lerpf(0.12, 0.85, slowdown)
		# Positive bias is a right-hand curve when looking down the table.
		var turned := slide_velocity.rotated(Vector3.UP, -shot_bias * turn_rate * delta)
		slide_velocity = Vector3(turned.x, 0.0, turned.z)
		var spin_sign := -1.0 if shot_bias < 0.0 else 1.0
		_visual.rotation.y += spin_sign * lerpf(2.0, 14.0, speed / MAX_SPEED) * delta
	slide_velocity *= pow(FRICTION_PER_SECOND, delta)
	position += slide_velocity * delta
	position.y = Metrics.DISC_CENTER_Y
	_keep_inside_board()
	if Vector2(slide_velocity.x, slide_velocity.z).length() <= STOP_SPEED:
		slide_velocity = Vector3.ZERO
		stop_timer += delta
		if stop_timer >= STOP_GRACE_SECONDS:
			shot_in_progress = false
			shot_stopped.emit()
	else:
		stop_timer = 0.0

func set_bias(value: float) -> void:
	bias_ratio = clampf(value, -1.0, 1.0)
	bias_changed.emit(bias_ratio)
	if is_aiming:
		_rebuild_guide()

func cycle_bias() -> void:
	if bias_ratio < -0.5:
		set_bias(0.0)
	elif bias_ratio > 0.5:
		set_bias(-1.0)
	else:
		set_bias(1.0)

func begin_aim(world_point: Vector3) -> bool:
	if shot_in_progress:
		return false
	is_aiming = true
	update_aim(world_point)
	return true

func update_aim(world_point: Vector3) -> void:
	if not is_aiming:
		return
	var pull := world_point - global_position
	pull.y = 0.0
	var pull_length := pull.length()
	var drag_distance := minf(pull_length, MAX_DRAG_DISTANCE)
	power_ratio = drag_distance / MAX_DRAG_DISTANCE
	if pull_length > 0.01:
		aim_direction = -pull / pull_length
	aim_changed.emit(aim_direction, power_ratio)
	_rebuild_guide()

func release_aim(world_point: Vector3) -> void:
	if not is_aiming:
		return
	update_aim(world_point)
	is_aiming = false
	_clear_guide()
	if power_ratio < 0.05:
		power_ratio = 0.0
		aim_changed.emit(aim_direction, 0.0)
		return
	launch()

func launch() -> void:
	shot_bias = bias_ratio
	slide_velocity = aim_direction * lerpf(MIN_SPEED, MAX_SPEED, power_ratio)
	slide_velocity.y = 0.0
	shot_in_progress = true
	stop_timer = 0.0
	shot_started.emit()

func reset_to_start() -> void:
	slide_velocity = Vector3.ZERO
	position = start_position
	is_aiming = false
	shot_in_progress = false
	power_ratio = 0.0
	stop_timer = 0.0
	shot_bias = 0.0
	if _visual != null:
		_visual.rotation = Vector3.ZERO
	_clear_guide()

func _keep_inside_board() -> void:
	var flat := Vector2(position.x, position.z)
	var limit := Metrics.PLAY_RADIUS - Metrics.DISC_RADIUS
	if flat.length() <= limit or flat.length() <= 0.0001:
		return
	var normal := flat.normalized()
	var clamped := normal * limit
	position.x = clamped.x
	position.z = clamped.y
	var velocity := Vector2(slide_velocity.x, slide_velocity.z)
	var outward := velocity.dot(normal)
	if outward > 0.0:
		velocity = (velocity - normal * outward * 2.0) * RAIL_RESTITUTION
		slide_velocity = Vector3(velocity.x, 0.0, velocity.y)

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var base := CylinderMesh.new()
	base.top_radius = Metrics.DISC_RADIUS
	base.bottom_radius = Metrics.DISC_RADIUS * 0.94
	base.height = Metrics.DISC_HEIGHT
	base.radial_segments = 40
	Metrics.add_mesh(_visual, base, Metrics.plastic(Color("#9d1d5c"), 0.34, 0.08))

	var cap := Metrics.cylinder(Metrics.DISC_RADIUS * 0.76, 0.008, 32)
	Metrics.add_mesh(
		_visual,
		cap,
		Metrics.plastic(Color("#ff4f9a"), 0.22, 0.2),
		Vector3(0.0, Metrics.DISC_HEIGHT * 0.42, 0.0)
	)

	var center := Metrics.cylinder(Metrics.DISC_RADIUS * 0.3, 0.01, 24)
	Metrics.add_mesh(
		_visual,
		center,
		Metrics.plastic(Color("#ffe6f2"), 0.18, 0.25),
		Vector3(0.0, Metrics.DISC_HEIGHT * 0.5, 0.0)
	)

	var stripe := BoxMesh.new()
	stripe.size = Vector3(Metrics.DISC_RADIUS * 1.15, 0.012, 0.012)
	Metrics.add_mesh(
		_visual,
		stripe,
		Metrics.plastic(Color("#fff3b0"), 0.28, 0.45),
		Vector3(0.0, Metrics.DISC_HEIGHT * 0.52, 0.0)
	)

	var shadow := Metrics.cylinder(Metrics.DISC_RADIUS * 1.2, 0.004, 32)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.38)
	var shadow_mesh := Metrics.add_mesh(self, shadow, shadow_material, Vector3(0.03, -Metrics.DISC_CENTER_Y + 0.004, 0.03))
	shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var ring := TorusMesh.new()
	ring.inner_radius = Metrics.DISC_RADIUS * 1.25
	ring.outer_radius = Metrics.DISC_RADIUS * 1.7
	ring.rings = 28
	ring.ring_segments = 8
	var ring_material := StandardMaterial3D.new()
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(0.55, 0.95, 1.0, 0.45)
	_idle_ring = Metrics.add_mesh(self, ring, ring_material, Vector3(0.0, -Metrics.DISC_CENTER_Y + 0.008, 0.0))
	_idle_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_guide() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_guide_instance = MeshInstance3D.new()
	_guide_instance.mesh = _guide_mesh
	_guide_instance.material_override = material
	_guide_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_guide_instance)

	var marker := TorusMesh.new()
	marker.inner_radius = 0.028
	marker.outer_radius = 0.046
	marker.rings = 24
	marker.ring_segments = 8
	var marker_material := Metrics.plastic(Color("#f3e2a2"), 0.3, 0.4)
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.albedo_color = Color(0.98, 0.9, 0.62, 0.85)
	_end_marker = Metrics.add_mesh(self, marker, marker_material, Vector3(0.0, 0.02, 0.0))
	_end_marker.visible = false
	_end_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _clear_guide() -> void:
	if _guide_has_surface:
		_guide_mesh.clear_surfaces()
		_guide_has_surface = false
	if _end_marker != null:
		_end_marker.visible = false

func _rebuild_guide() -> void:
	if _guide_has_surface:
		_guide_mesh.clear_surfaces()
		_guide_has_surface = false
	if not is_aiming or power_ratio <= 0.0:
		_end_marker.visible = false
		return
	var length := lerpf(0.28, 1.7, power_ratio)
	var steps := 28
	var points: Array[Vector3] = [Vector3.ZERO]
	var point := Vector3.ZERO
	var direction := aim_direction
	direction.y = 0.0
	if direction.length() < 0.001:
		direction = Vector3(0.0, 0.0, -1.0)
	direction = direction.normalized()
	var limit := Metrics.PLAY_RADIUS - Metrics.DISC_RADIUS * 0.35
	for step_index in range(1, steps + 1):
		var progress := float(step_index) / float(steps)
		direction = direction.rotated(Vector3.UP, -bias_ratio * 0.085 * (1.0 - progress))
		direction.y = 0.0
		if direction.length() < 0.001:
			break
		direction = direction.normalized()
		var next_point := point + direction * (length / float(steps))
		var flat := Vector2(global_position.x + next_point.x, global_position.z + next_point.z)
		if flat.length() > limit:
			var clipped := flat.normalized() * limit
			next_point = Vector3(clipped.x - global_position.x, 0.0, clipped.y - global_position.z)
			points.append(next_point)
			break
		point = next_point
		points.append(point)
	if points.size() < 2:
		_end_marker.visible = false
		return

	var material: Material = _guide_instance.material_override
	_guide_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
	for point_index in points.size():
		var center := points[point_index]
		var forward := Vector3(0.0, 0.0, -1.0)
		if point_index + 1 < points.size():
			forward = points[point_index + 1] - center
		elif point_index > 0:
			forward = center - points[point_index - 1]
		forward.y = 0.0
		if forward.length() < 0.0001:
			forward = Vector3(0.0, 0.0, -1.0)
		forward = forward.normalized()
		var side := Vector3(-forward.z, 0.0, forward.x)
		var width := lerpf(0.012, 0.034, 1.0 - float(point_index) / float(points.size()))
		var alpha := lerpf(0.95, 0.15, float(point_index) / float(points.size()))
		var lifted := Vector3(center.x, 0.02, center.z)
		_guide_mesh.surface_set_color(Color(0.95, 0.9, 0.7, alpha))
		_guide_mesh.surface_add_vertex(lifted + side * width)
		_guide_mesh.surface_add_vertex(lifted - side * width)
	_guide_mesh.surface_end()
	_guide_has_surface = true

	var last := points[points.size() - 1]
	_end_marker.position = Vector3(last.x, 0.02, last.z)
	_end_marker.visible = true
