class_name CrokinolePuck
extends Node3D

## One crokinole button. The match steps every puck together so pegs and
## other buttons can carom them.

const Metrics = preload("res://scripts/table_metrics.gd")

var velocity := Vector3.ZERO
var moving := false
var sunk := false
var in_ditch := false
var is_player := true
var shot_bias := 0.0
var stop_timer := 0.0
var played := false

var _visual: Node3D

func setup(player_disc: bool) -> void:
	is_player = player_disc
	_build_visual()

func flat() -> Vector2:
	return Vector2(position.x, position.z)

func set_flat(spot: Vector2) -> void:
	var height := Metrics.DITCH_Y if in_ditch else Metrics.DISC_CENTER_Y
	position = Vector3(spot.x, height, spot.y)

func points() -> int:
	if not is_player or not played:
		return 0
	if moving and not sunk:
		return 0
	return Metrics.points_for(flat().length(), sunk)

func spin(delta: float) -> void:
	if _visual == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed <= 0.01:
		return
	var spin_sign := -1.0 if shot_bias < 0.0 else 1.0
	_visual.rotation.y += spin_sign * lerpf(2.0, 18.0, clampf(speed / Metrics.MAX_SPEED, 0.0, 1.0)) * delta

func sink_into_hole() -> void:
	if sunk:
		return
	sunk = true
	moving = false
	velocity = Vector3.ZERO
	shot_bias = 0.0
	var drop := create_tween()
	drop.set_parallel(true)
	drop.tween_property(self, "position:y", -0.045, 0.22)
	drop.tween_property(self, "scale", Vector3(0.62, 0.62, 0.62), 0.22)

func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var body_color := Color("#141414") if is_player else Color("#f3e6cf")
	var rim_color := Color("#2a2a2e") if is_player else Color("#c4a574")
	var center_color := Color("#ff3d9a") if is_player else Color("#6b3e28")
	var ring_color := Color("#ff2f9a") if is_player else Color("#f0d48a")

	var body := CylinderMesh.new()
	body.top_radius = Metrics.DISC_RADIUS
	body.bottom_radius = Metrics.DISC_RADIUS * 0.94
	body.height = Metrics.DISC_HEIGHT
	body.radial_segments = 40
	Metrics.add_mesh(_visual, body, Metrics.plastic(rim_color, 0.32, 0.0))

	var top := Metrics.cylinder(Metrics.DISC_RADIUS * 0.86, 0.006, 36)
	Metrics.add_mesh(_visual, top, Metrics.plastic(body_color, 0.22, 0.04), Vector3(0.0, Metrics.DISC_HEIGHT * 0.42, 0.0))

	var ring := TorusMesh.new()
	ring.inner_radius = Metrics.DISC_RADIUS * 0.48
	ring.outer_radius = Metrics.DISC_RADIUS * 0.6
	ring.rings = 28
	ring.ring_segments = 8
	Metrics.add_mesh(_visual, ring, Metrics.plastic(ring_color, 0.22, 0.85 if is_player else 0.12), Vector3(0.0, Metrics.DISC_HEIGHT * 0.5, 0.0))

	var cap := Metrics.cylinder(Metrics.DISC_RADIUS * 0.32, 0.007, 24)
	Metrics.add_mesh(_visual, cap, Metrics.plastic(center_color, 0.2, 0.08), Vector3(0.0, Metrics.DISC_HEIGHT * 0.55, 0.0))

	var shadow := Metrics.cylinder(Metrics.DISC_RADIUS * 1.15, 0.003, 28)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.32)
	var shadow_mesh := Metrics.add_mesh(self, shadow, shadow_material, Vector3(0.02, -Metrics.DISC_CENTER_Y + 0.003, 0.02))
	shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
