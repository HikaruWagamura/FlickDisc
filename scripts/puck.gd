class_name CrokinolePuck
extends Node3D

## One crokinole button. The match steps every puck together so pegs and
## other buttons can carom them.

const Metrics = preload("res://scripts/table_metrics.gd")
const Kit := preload("res://scripts/kit.gd")

var velocity := Vector3.ZERO
var moving := false
var sunk := false
var in_ditch := false
var removed := false
var is_player := true
var shot_bias := 0.0
var stop_timer := 0.0
var played := false
var start_flat := Vector2.ZERO

var tint := Color("#d4222a")
var _kit_index := 0
var _visual: Node3D

func setup(player_disc: bool, disc_tint: Color = Color("#d4222a"), kit_index: int = 0) -> void:
	is_player = player_disc
	tint = disc_tint
	_kit_index = kit_index
	_build_visual()

func flat() -> Vector2:
	return Vector2(position.x, position.z)

func set_flat(spot: Vector2) -> void:
	position = Vector3(spot.x, Metrics.sit_y(in_ditch), spot.y)

func ring_points() -> int:
	if removed:
		return 0
	if is_player and not played:
		return 0
	if moving and not sunk:
		return 0
	if in_ditch:
		return 0
	if sunk:
		return 20
	return Metrics.points_for(flat().length(), false)

func on_playing_surface() -> bool:
	return not removed and not sunk and not in_ditch

func in_15_or_20() -> bool:
	if removed or in_ditch:
		return false
	if sunk:
		return true
	return Metrics.touches_15(flat().length())


func park_twenty(index: int) -> void:
	sunk = true
	moving = false
	in_ditch = false
	removed = false
	velocity = Vector3.ZERO
	scale = Vector3.ONE
	var side := 1.0 if is_player else -1.0
	var col := index % 4
	var row := int(index / 4)
	position = Vector3(
		side * (Metrics.DITCH_OUTER * 0.62 + float(col) * Metrics.DISC_RADIUS * 2.2),
		Metrics.DISC_CENTER_Y,
		Metrics.DITCH_OUTER * 0.22 + float(row) * Metrics.DISC_RADIUS * 2.2
	)

func displaced_from_start() -> float:
	return flat().distance_to(start_flat)

func mark_start() -> void:
	start_flat = flat()

func take_off() -> void:
	if removed:
		return
	removed = true
	moving = false
	played = true
	sunk = false
	in_ditch = false
	velocity = Vector3.ZERO
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(0.08, 0.08, 0.08), 0.22)
	tween.tween_property(self, "position:y", position.y + 0.08, 0.22)
	tween.finished.connect(func() -> void:
		visible = false
		scale = Vector3.ONE
	)

func points() -> int:
	if not is_player:
		return 0
	return ring_points()

func spin(delta: float) -> void:
	if _visual == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed <= 0.01:
		return
	var spin_sign := -1.0 if shot_bias < 0.0 else 1.0
	_visual.rotation.y += spin_sign * lerpf(1.2, 7.0, clampf(speed / Metrics.MAX_SPEED, 0.0, 1.0)) * delta

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
	if _wear_club():
		return
	var body_color := tint
	var rim_color := Color("#c4a574") if is_player else Color("#3a1c0c")
	var center_color := Color("#fff8f0") if is_player else Color("#4a2410")
	var ring_color := Color("#e8d2a8") if is_player else Color("#8a5228")

	var body := CylinderMesh.new()
	body.top_radius = Metrics.DISC_RADIUS
	body.bottom_radius = Metrics.DISC_RADIUS * 0.96
	body.height = Metrics.DISC_HEIGHT
	body.radial_segments = 64
	Metrics.add_mesh(_visual, body, Metrics.plastic(rim_color, 0.34, 0.0))

	var top := Metrics.cylinder(Metrics.DISC_RADIUS * 0.9, 0.004, 64)
	Metrics.add_mesh(_visual, top, Metrics.plastic(body_color, 0.28, 0.0), Vector3(0.0, Metrics.DISC_HEIGHT * 0.46, 0.0))

	var band := Metrics.cylinder(Metrics.DISC_RADIUS * 0.72, 0.005, 64)
	var band_glow := 0.12 if is_player else 0.0
	Metrics.add_mesh(_visual, band, Metrics.plastic(ring_color, 0.24, band_glow), Vector3(0.0, Metrics.DISC_HEIGHT * 0.52, 0.0))

	var groove := Metrics.cylinder(Metrics.DISC_RADIUS * 0.5, 0.004, 48)
	Metrics.add_mesh(_visual, groove, Metrics.plastic(body_color, 0.3, 0.0), Vector3(0.0, Metrics.DISC_HEIGHT * 0.56, 0.0))

	var cap := Metrics.cylinder(Metrics.DISC_RADIUS * 0.3, 0.005, 40)
	Metrics.add_mesh(_visual, cap, Metrics.plastic(center_color, 0.22, 0.0), Vector3(0.0, Metrics.DISC_HEIGHT * 0.6, 0.0))

	var shadow := Metrics.cylinder(Metrics.DISC_RADIUS * 1.15, 0.003, 28)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.32)
	var shadow_mesh := Metrics.add_mesh(self, shadow, shadow_material, Vector3(0.02, -Metrics.sit_y(false) + 0.003, 0.02))
	shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_kit_disc(kit: Dictionary) -> void:
	var body := CylinderMesh.new()
	body.top_radius = Metrics.DISC_RADIUS
	body.bottom_radius = Metrics.DISC_RADIUS * 0.96
	body.height = Metrics.DISC_HEIGHT
	body.radial_segments = 72
	var mi := MeshInstance3D.new()
	mi.mesh = body
	Kit.paint_disc(mi, kit)
	_visual.add_child(mi)
	_add_disc_shadow()


func _add_disc_shadow() -> void:
	var shadow := Metrics.cylinder(Metrics.DISC_RADIUS * 1.12, 0.003, 28)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.28)
	var shadow_mesh := Metrics.add_mesh(self, shadow, shadow_material, Vector3(0.018, -Metrics.sit_y(false) + 0.002, 0.018))
	shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _wear_club() -> bool:
	var mesh: Mesh = Metrics.club_disc_mesh(is_player, _kit_index)
	if mesh == null:
		return false
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Metrics.club_disc_xform
	if Metrics.club_figures_mat != null:
		mi.material_override = Metrics.club_figures_mat
	_visual.add_child(mi)
	_add_disc_shadow()
	return true
