class_name DiscController
extends Node3D

## Aiming for the button currently in hand. Drag back and release to flick.
## The button itself is a CrokinolePuck; this node only draws the guide.

signal aim_changed(direction: Vector3, power_ratio: float)
signal bias_changed(bias_ratio: float)
signal shot_started
signal shot_stopped

const Metrics = preload("res://scripts/table_metrics.gd")

var active_puck
var is_aiming := false
var shot_in_progress := false
var aim_direction := Vector3(0.0, 0.0, -1.0)
var power_ratio := 0.0
var bias_ratio := 0.0

var _guide_mesh := ImmediateMesh.new()
var _guide_instance: MeshInstance3D
var _end_marker: MeshInstance3D
var _idle_ring: MeshInstance3D
var _guide_has_surface := false

func _ready() -> void:
	_build_guide()

func bind_puck(puck: Node3D) -> void:
	active_puck = puck
	shot_in_progress = false
	is_aiming = false
	power_ratio = 0.0
	if puck != null:
		global_position = puck.global_position
	_clear_guide()

func _process(_delta: float) -> void:
	var show_ring := active_puck != null and not shot_in_progress and not is_aiming
	if _idle_ring != null:
		_idle_ring.visible = show_ring
		if show_ring:
			global_position = active_puck.global_position
			var pulse := 1.0 + sin(float(Time.get_ticks_msec()) * 0.004) * 0.08
			_idle_ring.scale = Vector3(pulse, 1.0, pulse)
	if is_aiming:
		_rebuild_guide()
	elif _guide_has_surface and not is_aiming:
		_clear_guide()

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
	if shot_in_progress or active_puck == null:
		return false
	is_aiming = true
	global_position = active_puck.global_position
	update_aim(world_point)
	return true

func update_aim(world_point: Vector3) -> void:
	if not is_aiming:
		return
	var pull := world_point - global_position
	pull.y = 0.0
	var pull_length := pull.length()
	power_ratio = minf(pull_length, Metrics.MAX_DRAG_DISTANCE) / Metrics.MAX_DRAG_DISTANCE
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
	if power_ratio < 0.05 or active_puck == null:
		power_ratio = 0.0
		aim_changed.emit(aim_direction, 0.0)
		return
	_launch()

func _launch() -> void:
	var speed := lerpf(Metrics.MIN_SPEED, Metrics.MAX_SPEED, power_ratio)
	active_puck.velocity = aim_direction * speed
	active_puck.velocity.y = 0.0
	active_puck.moving = true
	active_puck.played = true
	active_puck.shot_bias = bias_ratio
	active_puck.stop_timer = 0.0
	shot_in_progress = true
	shot_started.emit()

func mark_shot_finished() -> void:
	shot_in_progress = false
	shot_stopped.emit()

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
	marker.inner_radius = 0.03
	marker.outer_radius = 0.048
	marker.rings = 24
	marker.ring_segments = 8
	var marker_material := StandardMaterial3D.new()
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(0.98, 0.9, 0.62, 0.9)
	_end_marker = Metrics.add_mesh(self, marker, marker_material, Vector3(0.0, 0.03, 0.0))
	_end_marker.visible = false
	_end_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var ring := TorusMesh.new()
	ring.inner_radius = Metrics.DISC_RADIUS * 1.35
	ring.outer_radius = Metrics.DISC_RADIUS * 1.85
	ring.rings = 28
	ring.ring_segments = 8
	var ring_material := StandardMaterial3D.new()
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(0.55, 0.95, 1.0, 0.55)
	_idle_ring = Metrics.add_mesh(self, ring, ring_material, Vector3(0.0, 0.012, 0.0))
	_idle_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_idle_ring.visible = false

func _clear_guide() -> void:
	if _guide_has_surface:
		_guide_mesh.clear_surfaces()
		_guide_has_surface = false
	if _end_marker != null:
		_end_marker.visible = false

func _blocked(flat: Vector2) -> bool:
	for peg in Metrics.peg_positions():
		if flat.distance_to(Vector2(peg.x, peg.z)) <= Metrics.PEG_RADIUS + Metrics.DISC_RADIUS * 0.92:
			return true
	for node in get_tree().get_nodes_in_group("crokinole_puck"):
		if node == active_puck:
			continue
		var puck := node as Node3D
		if puck == null or bool(puck.get("sunk")):
			continue
		if flat.distance_to(Vector2(puck.position.x, puck.position.z)) <= Metrics.DISC_RADIUS * 1.9:
			return true
	return false

func _rebuild_guide() -> void:
	if _guide_has_surface:
		_guide_mesh.clear_surfaces()
		_guide_has_surface = false
	if not is_aiming or power_ratio <= 0.0:
		_end_marker.visible = false
		return
	var length := lerpf(0.35, 1.85, power_ratio)
	var steps := 32
	var points: Array[Vector3] = [Vector3.ZERO]
	var point := Vector3.ZERO
	var direction := aim_direction
	direction.y = 0.0
	if direction.length() < 0.001:
		direction = Vector3(0.0, 0.0, -1.0)
	direction = direction.normalized()
	var limit := Metrics.DITCH_OUTER - Metrics.DISC_RADIUS
	for step_index in range(1, steps + 1):
		var progress := float(step_index) / float(steps)
		direction = direction.rotated(Vector3.UP, -bias_ratio * 0.07 * (1.0 - progress))
		direction.y = 0.0
		if direction.length() < 0.001:
			break
		direction = direction.normalized()
		var next_point := point + direction * (length / float(steps))
		var flat := Vector2(global_position.x + next_point.x, global_position.z + next_point.z)
		if flat.length() > limit or _blocked(flat):
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
		var center: Vector3 = points[point_index]
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
		var width := lerpf(0.01, 0.03, 1.0 - float(point_index) / float(points.size()))
		var alpha := lerpf(0.95, 0.12, float(point_index) / float(points.size()))
		var lifted := Vector3(center.x, 0.03, center.z)
		_guide_mesh.surface_set_color(Color(1.0, 0.94, 0.72, alpha))
		_guide_mesh.surface_add_vertex(lifted + side * width)
		_guide_mesh.surface_add_vertex(lifted - side * width)
	_guide_mesh.surface_end()
	_guide_has_surface = true
	var last: Vector3 = points[points.size() - 1]
	_end_marker.position = Vector3(last.x, 0.03, last.z)
	_end_marker.visible = true
