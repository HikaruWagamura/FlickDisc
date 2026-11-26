class_name HandSwitch
extends Control

## Forehand / backhand. A small curved pack arrow in the corner shows
## which way the bowl will run toward the jack. Tap to flip the hand.

signal chosen(forehand: bool)

const PACK := preload("res://assets/arrows/arrow.fbx")
const FONT := preload("res://assets/fonts/Inter-Bold.ttf")
const MESH_NAME := "arrow_13"

var forehand := true
var _mesh: MeshInstance3D
var _holder: Node3D
var _pivot: Node3D
var _caption: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_draw_plate()
	_mount_arrow()
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -16.0
	_caption.offset_bottom = -1.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font", FONT)
	_caption.add_theme_font_size_override("font_size", 9)
	_caption.add_theme_color_override("font_color", Color("#fff6ff"))
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	var hit := Button.new()
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hit.pressed.connect(_toggle)
	add_child(hit)
	_apply_hand()


func set_forehand(on: bool) -> void:
	forehand = on
	_apply_hand()


func _toggle() -> void:
	chosen.emit(not forehand)


func _draw_plate() -> void:
	var plate := Panel.new()
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.05, 0.18, 0.90)
	box.border_color = Color("#ff2e8a")
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	plate.add_theme_stylebox_override("panel", box)
	add_child(plate)


func _mount_arrow() -> void:
	var wrap := SubViewportContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.offset_left = 4.0
	wrap.offset_top = 2.0
	wrap.offset_right = -4.0
	wrap.offset_bottom = -16.0
	wrap.stretch = true
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	var view := SubViewport.new()
	view.transparent_bg = true
	view.own_world_3d = true
	view.size = Vector2i(128, 128)
	view.msaa_3d = Viewport.MSAA_2X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	wrap.add_child(view)

	var world := Node3D.new()
	view.add_child(world)
	var env := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(0, 0, 0, 0)
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.86, 0.80, 0.92)
	sky.ambient_light_energy = 1.0
	env.environment = sky
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	light.light_energy = 1.2
	world.add_child(light)

	var packed: Node = PACK.instantiate()
	var source := _named_mesh(packed, MESH_NAME)
	_holder = Node3D.new()
	world.add_child(_holder)
	_pivot = Node3D.new()
	_holder.add_child(_pivot)
	_mesh = MeshInstance3D.new()
	if source != null and source.mesh != null:
		_mesh.mesh = source.mesh
		var aabb := source.mesh.get_aabb()
		_mesh.position = -aabb.get_center()
	_mesh.material_override = _arrow_mat()
	_mesh.extra_cull_margin = 4.0
	_pivot.add_child(_mesh)
	# Pack shaft is +Z. Turn it to world -Z so the jack sits at the top.
	_pivot.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	packed.free()

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.35
	cam.position = Vector3(0.0, 2.2, 0.0)
	cam.current = true
	world.add_child(cam)
	# Screen up is world -Z, the same way the rink looks toward the head.
	cam.look_at(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))


func _named_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and str(node.name) == mesh_name:
		return node
	for child in node.get_children():
		var found := _named_mesh(child, mesh_name)
		if found != null:
			return found
	return null


func _arrow_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.32, 0.58)
	mat.metallic = 0.42
	mat.roughness = 0.28
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.22, 0.48)
	mat.emission_energy_multiplier = 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _apply_hand() -> void:
	if _holder != null:
		# Rest pose runs right to left toward the jack (forehand).
		# Backhand is the left-to-right mirror, flipped in screen space.
		_holder.scale = Vector3(1.0 if forehand else -1.0, 1.0, 1.0)
	if _caption != null:
		_caption.text = "FORE" if forehand else "BACK"
