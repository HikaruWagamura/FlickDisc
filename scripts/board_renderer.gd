extends Node3D

## FlickDisc table. The paid crokinole mesh is the board you play on.
## Peg collision still uses NCA measures so scoring stays honest.

const Metrics = preload("res://scripts/table_metrics.gd")
const CLUB_BOARD := preload("res://assets/board/crokinole.fbx")

const LOGO_PATH := "res://assets/flick_disc_logo.png"
const MARK_PATH := "res://assets/flickdisc_mark.png"
const COURSE_PATH := "res://assets/course_background.png"

func _ready() -> void:
	_build_room()
	var club := _mount_club()
	if not club:
		_build_body()
		_build_surface()
		_build_rail()
		_build_pegs()
		_place_board_logos()
		_build_twenty_racks()


func _mount_club() -> bool:
	if CLUB_BOARD == null:
		return false
	var raw: Node = CLUB_BOARD.instantiate()
	if raw == null:
		return false
	var playfield := _named_mesh(raw, "playfield")
	if playfield == null or playfield.mesh == null:
		raw.free()
		return false
	var holder := Node3D.new()
	holder.name = "ClubBoard"
	add_child(holder)
	holder.add_child(raw)
	# Fit the painted playfield to the NCA surface so the ditch and the
	# 20-hole stay where the discs already play. Pins and buttons keep
	# the pack's own size on that same scale.
	var face := _world_aabb(playfield)
	var radius := maxf(face.size.x, face.size.z) * 0.5
	if radius < 0.001:
		radius = 0.2748
	var pack_scale := Metrics.SURFACE_RADIUS / radius
	holder.scale = Vector3.ONE * pack_scale
	# Sit the playing face on y=0. Ignore packed discs so they do not
	# lift the whole table.
	var box := _world_aabb(playfield)
	holder.position.y -= box.position.y + box.size.y
	_dress_club(raw)
	_hide_named(raw, "AnimationPlayer")
	_stash_pack_discs(raw)
	_stash_pack_pins(raw)
	var disc := _named_mesh(raw, "disc_01")
	if disc != null:
		var xf := disc.global_transform
		xf.origin = Vector3.ZERO
		Metrics.club_disc_xform = xf
		var disc_box := _world_aabb(disc)
		Metrics.club_center_y = disc_box.size.y * 0.5
		Metrics.club_ditch_y = -0.012
	_place_board_logos()
	_build_twenty_racks()
	return true


func _dress_club(node: Node) -> void:
	var playfield := _pbr(
		"res://assets/board/textures/crokinole_playfield_Mat_BaseColor.jpg",
		"res://assets/board/textures/crokinole_playfield_Mat_Normal.jpg",
		"res://assets/board/textures/crokinole_playfield_Mat_Roughness.jpg",
		"res://assets/board/textures/crokinole_playfield_Mat_Metallic.jpg"
	)
	var figures := _pbr(
		"res://assets/board/textures/crokinole_figures_Mat_BaseColor.jpg",
		"res://assets/board/textures/crokinole_figures_Mat_Normal.jpg",
		"res://assets/board/textures/crokinole_figures_Mat_Roughness.jpg",
		"res://assets/board/textures/crokinole_figures_Mat_Metallic.jpg"
	)
	Metrics.club_figures_mat = figures
	_apply_mats(node, playfield, figures)


func _pbr(albedo_path: String, normal_path: String, rough_path: String, metal_path: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var albedo: Texture2D = load(albedo_path)
	var normal: Texture2D = load(normal_path)
	var rough: Texture2D = load(rough_path)
	var metal: Texture2D = load(metal_path)
	if albedo != null:
		mat.albedo_texture = albedo
		mat.albedo_color = Color(1, 1, 1)
	else:
		mat.albedo_color = Color(0.62, 0.42, 0.24)
	if normal != null:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = 0.7
	if rough != null:
		mat.roughness_texture = rough
		mat.roughness = 0.72
	else:
		mat.roughness = 0.55
	if metal != null:
		mat.metallic_texture = metal
		mat.metallic = 0.04
	else:
		mat.metallic = 0.04
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


func _apply_mats(node: Node, playfield: StandardMaterial3D, figures: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var n := str(node.name).to_lower()
		var mat := figures if ("pin" in n or "disc" in n) else playfield
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_mats(child, playfield, figures)


func _named_mesh(node: Node, key: String) -> MeshInstance3D:
	if node is MeshInstance3D:
		var n := str(node.name).to_lower()
		if key in n:
			return node
	for child in node.get_children():
		var found := _named_mesh(child, key)
		if found != null:
			return found
	return null


func _image(path: String) -> Image:
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	var image: Image = tex.get_image()
	if image != null and image.is_compressed():
		image.decompress()
	return image


func _stash_pack_discs(node: Node) -> void:
	Metrics.club_dark.clear()
	Metrics.club_light.clear()
	var albedo: Image = _image("res://assets/board/textures/crokinole_figures_Mat_BaseColor.jpg")
	_collect_discs(node, albedo)
	_hide_packed_discs(node)


func _collect_discs(node: Node, albedo: Image) -> void:
	if node is MeshInstance3D and "disc" in str(node.name).to_lower() and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		var luma := _disc_luma(mi, albedo)
		if luma < 0.28:
			Metrics.club_dark.append(mi.mesh)
		else:
			Metrics.club_light.append(mi.mesh)
	for child in node.get_children():
		_collect_discs(child, albedo)


func _disc_luma(mi: MeshInstance3D, albedo: Image) -> float:
	if albedo == null or albedo.is_empty():
		return 0.5
	var arrays := mi.mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if uvs.is_empty():
		return 0.5
	var c := Vector2.ZERO
	for uv in uvs:
		c += uv
	c /= float(uvs.size())
	var px := Vector2i(
		clampi(int(c.x * albedo.get_width()), 0, albedo.get_width() - 1),
		clampi(int(c.y * albedo.get_height()), 0, albedo.get_height() - 1)
	)
	var col: Color = albedo.get_pixelv(px)
	return col.r * 0.3 + col.g * 0.59 + col.b * 0.11


func _stash_pack_pins(node: Node) -> void:
	var pins := _named_mesh(node, "pins")
	if pins == null or pins.mesh == null:
		return
	var verts: PackedVector3Array = pins.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bins: Array[Vector2] = []
	for v in verts:
		var p := Vector2(v.x, v.y)
		var placed := false
		for i in bins.size():
			if p.distance_to(bins[i]) < 0.012:
				bins[i] = (bins[i] + p) * 0.5
				placed = true
				break
		if not placed:
			bins.append(p)
	Metrics.club_pegs.clear()
	for c in bins:
		var world: Vector3 = pins.to_global(Vector3(c.x, c.y, 0.0))
		Metrics.club_pegs.append(Vector3(world.x, 0.0, world.z))


func _hide_packed_discs(node: Node) -> void:
	if "disc" in str(node.name).to_lower() and node is Node3D:
		(node as Node3D).visible = false
	for child in node.get_children():
		_hide_packed_discs(child)


func _hide_named(node: Node, key: String) -> void:
	if key.to_lower() in str(node.name).to_lower():
		if node is Node3D:
			(node as Node3D).visible = false
		elif node is AnimationPlayer:
			(node as AnimationPlayer).stop()
			node.queue_free()
		return
	for child in node.get_children():
		_hide_named(child, key)


func _world_aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		var local := mi.mesh.get_aabb()
		for i in 8:
			var p: Vector3 = mi.global_transform * local.get_endpoint(i)
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	for child in node.get_children():
		var child_box := _world_aabb(child)
		if child_box.size.length() > 0.00001:
			if first:
				box = child_box
				first = false
			else:
				box = box.merge(child_box)
	return box

func _build_room() -> void:
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#080719")
	floor_material.roughness = 0.92
	Metrics.add_mesh(self, _box(Vector3(18.0, 0.04, 22.0)), floor_material, Vector3(0.0, -0.64, -4.0))
	var rug := StandardMaterial3D.new()
	rug.albedo_color = Color("#1A1028")
	rug.roughness = 0.86
	Metrics.add_mesh(self, Metrics.cylinder(Metrics.DITCH_OUTER + 0.55, 0.02, 64), rug, Vector3(0.0, -0.595, 0.0))
	var wash := OmniLight3D.new()
	wash.position = Vector3(0.0, 2.4, 0.6)
	wash.light_color = Color("#C4AEFF")
	wash.light_energy = 0.55
	wash.omni_range = 8.0
	add_child(wash)
	var gold := OmniLight3D.new()
	gold.position = Vector3(0.0, 1.6, 1.4)
	gold.light_color = Color("#E8C56A")
	gold.light_energy = 0.28
	gold.omni_range = 5.0
	add_child(gold)

func _build_body() -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color("#2a1612")
	body.roughness = 0.48
	body.metallic = 0.22
	Metrics.add_mesh(self, Metrics.cylinder(Metrics.DITCH_OUTER + 0.06, 0.16, 80), body, Vector3(0.0, -0.1, 0.0))

	var leg_material := Metrics.plastic(Color("#1a1012"), 0.38, 0.0)
	leg_material.metallic = 0.4
	for index in 4:
		var angle := PI * 0.25 + float(index) * PI * 0.5
		var leg := Metrics.cylinder(0.05, 0.42, 16)
		leg.bottom_radius = 0.06
		Metrics.add_mesh(self, leg, leg_material, Vector3(cos(angle) * Metrics.DITCH_OUTER * 0.72, -0.38, sin(angle) * Metrics.DITCH_OUTER * 0.72))

	var skirt := CylinderMesh.new()
	skirt.top_radius = Metrics.DITCH_OUTER + 0.1
	skirt.bottom_radius = Metrics.DITCH_OUTER + 0.1
	skirt.height = 0.18
	skirt.radial_segments = 96
	skirt.cap_top = false
	skirt.cap_bottom = false
	var skirt_material := StandardMaterial3D.new()
	skirt_material.albedo_color = Color("#1a1014")
	skirt_material.roughness = 0.35
	skirt_material.metallic = 0.45
	Metrics.add_mesh(self, skirt, skirt_material, Vector3(0.0, -0.05, 0.0))

func _build_surface() -> void:
	var images := _make_board_images()
	var albedo: Image = images[0]
	var emission: Image = images[1]
	albedo.generate_mipmaps()
	emission.generate_mipmaps()
	var texture := ImageTexture.create_from_image(albedo)
	var emission_texture := ImageTexture.create_from_image(emission)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = texture
	wood.emission_enabled = true
	wood.emission_texture = emission_texture
	wood.emission_energy_multiplier = 0.22
	wood.roughness = 0.38
	wood.metallic = 0.12
	wood.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var surface := MeshInstance3D.new()
	surface.mesh = _disc_mesh(Metrics.SURFACE_RADIUS, 0.028)
	surface.set_surface_override_material(0, wood)
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("#4a2c1a")
	edge.roughness = 0.5
	surface.set_surface_override_material(1, edge)
	add_child(surface)

	var ditch_material := StandardMaterial3D.new()
	ditch_material.albedo_color = Color("#3a2218")
	ditch_material.roughness = 0.72
	var ditch := MeshInstance3D.new()
	ditch.mesh = _annulus(Metrics.SURFACE_RADIUS, Metrics.DITCH_OUTER, -0.018, 96)
	ditch.material_override = ditch_material
	add_child(ditch)

	var lip := MeshInstance3D.new()
	lip.mesh = _wall(Metrics.SURFACE_RADIUS, 0.0, -0.018, 96)
	lip.material_override = edge
	add_child(lip)

	var hole_well := Metrics.cylinder(Metrics.HOLE_RADIUS * 0.9, 0.05, 32)
	Metrics.add_mesh(self, hole_well, Metrics.plastic(Color("#12080c"), 0.8, 0.0), Vector3(0.0, -0.03, 0.0))
	var hole_ring := TorusMesh.new()
	hole_ring.inner_radius = Metrics.HOLE_RADIUS * 0.92
	hole_ring.outer_radius = Metrics.HOLE_RADIUS * 1.18
	hole_ring.rings = 40
	hole_ring.ring_segments = 12
	Metrics.add_mesh(self, hole_ring, Metrics.plastic(Color("#e8c56a"), 0.28, 0.25), Vector3(0.0, 0.006, 0.0))

func _build_rail() -> void:
	var rail := TorusMesh.new()
	rail.inner_radius = Metrics.DITCH_OUTER - 0.01
	rail.outer_radius = Metrics.DITCH_OUTER + 0.07
	rail.rings = 80
	rail.ring_segments = 16
	var rail_material := Metrics.plastic(Color("#221418"), 0.28, 0.0)
	rail_material.metallic = 0.55
	Metrics.add_mesh(self, rail, rail_material, Vector3(0.0, 0.02, 0.0))

	var inlay := TorusMesh.new()
	inlay.inner_radius = Metrics.DITCH_OUTER + 0.045
	inlay.outer_radius = Metrics.DITCH_OUTER + 0.065
	inlay.rings = 72
	inlay.ring_segments = 10
	Metrics.add_mesh(self, inlay, Metrics.plastic(Color("#7A3BFF"), 0.18, 1.15), Vector3(0.0, 0.028, 0.0))

func _build_pegs() -> void:
	for peg_position in Metrics.peg_positions():
		var peg := Node3D.new()
		peg.position = peg_position + Vector3(0.0, 0.03, 0.0)
		add_child(peg)
		var post := CylinderMesh.new()
		post.top_radius = Metrics.PEG_RADIUS * 0.82
		post.bottom_radius = Metrics.PEG_RADIUS
		post.height = 0.06
		post.radial_segments = 20
		Metrics.add_mesh(peg, post, Metrics.plastic(Color("#6a3a22"), 0.4, 0.0))
		var cap := SphereMesh.new()
		cap.radius = Metrics.PEG_RADIUS * 0.95
		cap.height = Metrics.PEG_RADIUS * 1.9
		cap.radial_segments = 20
		cap.rings = 12
		Metrics.add_mesh(peg, cap, Metrics.plastic(Color("#8d5a32"), 0.32, 0.04), Vector3(0.0, 0.038, 0.0))
		var foot := Metrics.cylinder(Metrics.PEG_RADIUS * 1.25, 0.008, 20)
		Metrics.add_mesh(peg, foot, Metrics.plastic(Color("#3a2218"), 0.45, 0.0), Vector3(0.0, -0.028, 0.0))

func _place_board_logos() -> void:
	var tex := _logo_decal()
	if tex == null:
		return
	# Sit in the 10-ring on both shooting sides so the 20, pegs, and lines stay clear.
	var along := (Metrics.RING_10 + Metrics.RING_5) * 0.5
	_logo_plate(Vector3(0.0, 0.0028, along), 0.0, tex)
	_logo_plate(Vector3(0.0, 0.0028, -along), 180.0, tex)


func _logo_plate(at: Vector3, yaw: float, tex: Texture2D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.24, 0.24)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.position = at
	mi.rotation_degrees = Vector3(-90.0, yaw, 0.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 0.92)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _logo_decal() -> Texture2D:
	var image: Image = _image(MARK_PATH)
	if image == null or image.is_empty():
		image = _image(LOGO_PATH)
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	if image.get_width() > 512 or image.get_height() > 512:
		image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var cx := float(width) * 0.5
	var cy := float(height) * 0.5
	var radius := minf(cx, cy) * 0.98
	for y in height:
		for x in width:
			var pixel: Color = image.get_pixel(x, y)
			var dx := (float(x) + 0.5 - cx) / radius
			var dy := (float(y) + 0.5 - cy) / radius
			var radial := sqrt(dx * dx + dy * dy)
			var luma := pixel.r * 0.3 + pixel.g * 0.59 + pixel.b * 0.11
			var chroma := maxf(pixel.r, maxf(pixel.g, pixel.b)) - minf(pixel.r, minf(pixel.g, pixel.b))
			if radial > 1.0 or (luma < 0.08 and chroma < 0.07):
				pixel.a = 0.0
			else:
				pixel.a = 1.0 if radial < 0.92 else clampf((1.0 - radial) / 0.08, 0.0, 1.0)
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


func _build_twenty_racks() -> void:
	var tray := Metrics.plastic(Color("#1A1028"), 0.32, 0.0)
	tray.metallic = 0.35
	var lip := Metrics.plastic(Color("#E8C56A"), 0.28, 0.35)
	for player_side in [true, false]:
		var root := Node3D.new()
		root.name = "TwentyRackYou" if player_side else "TwentyRackFar"
		add_child(root)
		var first: Vector3 = Metrics.twenty_rack_slot(player_side, 0)
		var last: Vector3 = Metrics.twenty_rack_slot(player_side, 7)
		root.position = Vector3((first.x + last.x) * 0.5, 0.0, (first.z + last.z) * 0.5)
		var plank := BoxMesh.new()
		plank.size = Vector3(0.20, 0.01, 0.56)
		Metrics.add_mesh(root, plank, tray, Vector3(0.0, 0.018, 0.0))
		var edge := BoxMesh.new()
		edge.size = Vector3(0.206, 0.004, 0.566)
		Metrics.add_mesh(root, edge, lip, Vector3(0.0, 0.025, 0.0))


func _disc_mesh(radius: float, thickness: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 128
	for index in segments:
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		_add_top(top, Vector3.ZERO, Vector2(0.5, 0.5))
		_add_top(top, Vector3(cos(a0) * radius, 0.0, sin(a0) * radius), Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5))
		_add_top(top, Vector3(cos(a1) * radius, 0.0, sin(a1) * radius), Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5))
	mesh = top.commit(mesh)
	var side := SurfaceTool.new()
	side.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in segments:
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var n0 := Vector3(cos(a0), 0.0, sin(a0))
		var n1 := Vector3(cos(a1), 0.0, sin(a1))
		var top0 := n0 * radius
		var top1 := n1 * radius
		var bot0 := top0 + Vector3(0.0, -thickness, 0.0)
		var bot1 := top1 + Vector3(0.0, -thickness, 0.0)
		_add_side(side, top0, n0)
		_add_side(side, bot0, n0)
		_add_side(side, bot1, n1)
		_add_side(side, top0, n0)
		_add_side(side, bot1, n1)
		_add_side(side, top1, n1)
	return side.commit(mesh)

func _annulus(inner: float, outer: float, height: float, segments: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in segments:
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var inner0 := Vector3(cos(a0) * inner, height, sin(a0) * inner)
		var inner1 := Vector3(cos(a1) * inner, height, sin(a1) * inner)
		var outer0 := Vector3(cos(a0) * outer, height, sin(a0) * outer)
		var outer1 := Vector3(cos(a1) * outer, height, sin(a1) * outer)
		_add_top(tool, inner0, Vector2.ZERO)
		_add_top(tool, outer0, Vector2.ZERO)
		_add_top(tool, outer1, Vector2.ZERO)
		_add_top(tool, inner0, Vector2.ZERO)
		_add_top(tool, outer1, Vector2.ZERO)
		_add_top(tool, inner1, Vector2.ZERO)
	return tool.commit()

func _wall(radius: float, top_y: float, bottom_y: float, segments: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in segments:
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var n0 := Vector3(cos(a0), 0.0, sin(a0))
		var n1 := Vector3(cos(a1), 0.0, sin(a1))
		_add_side(tool, n0 * radius + Vector3(0.0, top_y, 0.0), n0)
		_add_side(tool, n0 * radius + Vector3(0.0, bottom_y, 0.0), n0)
		_add_side(tool, n1 * radius + Vector3(0.0, bottom_y, 0.0), n1)
		_add_side(tool, n0 * radius + Vector3(0.0, top_y, 0.0), n0)
		_add_side(tool, n1 * radius + Vector3(0.0, bottom_y, 0.0), n1)
		_add_side(tool, n1 * radius + Vector3(0.0, top_y, 0.0), n1)
	return tool.commit()

func _add_top(tool: SurfaceTool, point: Vector3, uv: Vector2) -> void:
	tool.set_normal(Vector3.UP)
	tool.set_uv(uv)
	tool.add_vertex(point)

func _add_side(tool: SurfaceTool, point: Vector3, normal: Vector3) -> void:
	tool.set_normal(normal)
	tool.set_uv(Vector2(0.5, 0.98))
	tool.add_vertex(point)

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _build_club_rink() -> void:
	var lane_material := StandardMaterial3D.new()
	lane_material.albedo_color = Color("#1f8f4c")
	lane_material.roughness = 0.78
	var lane := BoxMesh.new()
	lane.size = Vector3(2.35, 0.045, 1.7)
	Metrics.add_mesh(self, lane, lane_material, Vector3(0.0, -0.55, -2.28))

	var lane_top := PlaneMesh.new()
	lane_top.size = Vector2(2.35, 1.7)
	var lane_print := StandardMaterial3D.new()
	lane_print.albedo_texture = ImageTexture.create_from_image(_paint_lane())
	lane_print.roughness = 0.78
	lane_print.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	Metrics.add_mesh(self, lane_top, lane_print, Vector3(0.0, -0.522, -2.28))

	# Faded marks on the grass to either side of the rink's near end.
	_add_lawn_mark(Vector3(-1.62, -0.608, -1.58), 1.05, 0.72)
	_add_lawn_mark(Vector3(1.62, -0.608, -1.58), 1.05, 0.72)

	var rail_material := StandardMaterial3D.new()
	rail_material.albedo_color = Color("#d7e7df")
	rail_material.roughness = 0.45
	for side in [-1.0, 1.0]:
		var boundary := BoxMesh.new()
		boundary.size = Vector3(0.035, 0.028, 1.55)
		Metrics.add_mesh(self, boundary, rail_material, Vector3(side * 1.08, -0.515, -2.28))
	var center_line := BoxMesh.new()
	center_line.size = Vector3(0.016, 0.012, 1.35)
	var center_material := StandardMaterial3D.new()
	center_material.albedo_color = Color(1.0, 1.0, 1.0, 0.7)
	center_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	center_material.roughness = 0.4
	Metrics.add_mesh(self, center_line, center_material, Vector3(0.0, -0.52, -2.35))

	var jack_ring := TorusMesh.new()
	jack_ring.inner_radius = 0.14
	jack_ring.outer_radius = 0.2
	jack_ring.rings = 28
	jack_ring.ring_segments = 8
	Metrics.add_mesh(self, jack_ring, Metrics.plastic(Color("#f4f7f2"), 0.35, 0.08), Vector3(0.0, -0.51, -2.85))
	var jack := SphereMesh.new()
	jack.radius = 0.05
	jack.height = 0.065
	jack.radial_segments = 16
	jack.rings = 8
	Metrics.add_mesh(self, jack, Metrics.plastic(Color("#f3bd56"), 0.28, 0.25), Vector3(0.0, -0.48, -2.85))

	var backdrop := PlaneMesh.new()
	backdrop.size = Vector2(6.8, 3.4)
	var backdrop_material := StandardMaterial3D.new()
	backdrop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backdrop_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var course := _image(COURSE_PATH)
	if course != null and not course.is_empty():
		var crop_y := int(course.get_height() * 0.30)
		var crop_h := int(course.get_height() * 0.16)
		var crop := course.get_region(Rect2i(0, crop_y, course.get_width(), crop_h))
		crop.flip_y()
		backdrop_material.albedo_texture = ImageTexture.create_from_image(crop)
	backdrop_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var backdrop_mesh := MeshInstance3D.new()
	backdrop_mesh.mesh = backdrop
	backdrop_mesh.material_override = backdrop_material
	backdrop_mesh.position = Vector3(0.0, 0.35, -3.45)
	backdrop_mesh.rotation_degrees = Vector3(-58.0, 0.0, 0.0)
	add_child(backdrop_mesh)

	var lamp_material := Metrics.plastic(Color("#1c2430"), 0.4, 0.0)
	var glow_material := Metrics.plastic(Color("#ffe6b0"), 0.2, 2.4)
	for side in [-1.0, 1.0]:
		for lamp_z in [-1.9, -2.7]:
			var post := Metrics.cylinder(0.03, 0.95, 10)
			Metrics.add_mesh(self, post, lamp_material, Vector3(side * 1.62, -0.08, lamp_z))
			Metrics.add_mesh(self, Metrics.cylinder(0.07, 0.07, 12), glow_material, Vector3(side * 1.62, 0.42, lamp_z))

func _paint_lane() -> Image:
	var width := 512
	var height := 384
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color("#1f8f4c"))
	for band in range(0, height, 28):
		image.fill_rect(Rect2i(0, band, width, 14), Color("#239a54"))
	# High V is the near end of the plane, the start of the rink.
	_stamp_logo(image, Vector2(256.0, 268.0), 250.0, 0.62, false)
	return image

func _add_lawn_mark(at: Vector3, width: float, strength: float) -> void:
	var side := 256
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	_stamp_logo(image, Vector2(side * 0.5, side * 0.5), float(side) * 0.94, strength, true)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, width * 0.72)
	var mesh := Metrics.add_mesh(self, plane, material, at)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _stamp_logo(image: Image, center: Vector2, diameter: float, strength: float, cutout: bool) -> void:
	var logo: Image = _image(LOGO_PATH)
	if logo == null or logo.is_empty():
		return
	var copy: Image = logo.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	var side := maxi(int(diameter), 8)
	copy.resize(side, side, Image.INTERPOLATE_LANCZOS)
	var origin := Vector2i(int(center.x) - side / 2, int(center.y) - side / 2)
	for y in side:
		for x in side:
			var dest := Vector2i(origin.x + x, origin.y + y)
			if dest.x < 0 or dest.y < 0 or dest.x >= image.get_width() or dest.y >= image.get_height():
				continue
			var pixel: Color = copy.get_pixel(x, y)
			var luma: float = pixel.r * 0.3 + pixel.g * 0.59 + pixel.b * 0.11
			var ink := clampf((luma - 0.07) / 0.28, 0.0, 1.0)
			var nx := (float(x) + 0.5) / float(side) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(side) * 2.0 - 1.0
			var edge := clampf((0.96 - sqrt(nx * nx + ny * ny)) / 0.34, 0.0, 1.0)
			var alpha := ink * edge * strength
			if alpha <= 0.02:
				continue
			if cutout:
				image.set_pixel(dest.x, dest.y, Color(pixel.r, pixel.g, pixel.b, alpha))
			else:
				var base: Color = image.get_pixel(dest.x, dest.y)
				var mixed: Color = base.lerp(Color(pixel.r, pixel.g, pixel.b, 1.0), alpha)
				mixed.a = 1.0
				image.set_pixel(dest.x, dest.y, mixed)

func _make_board_images() -> Array:
	var size := 1024
	var bytes := PackedByteArray()
	bytes.resize(size * size * 4)
	var center := (float(size) - 1.0) * 0.5
	for y in size:
		var row := y * size * 4
		var dy := (float(y) - center) / center
		for x in size:
			var dx := (float(x) - center) / center
			var radius := sqrt(dx * dx + dy * dy)
			var color := _wood_color(dx, dy, radius)
			var index := row + x * 4
			bytes[index] = _byte(color.r)
			bytes[index + 1] = _byte(color.g)
			bytes[index + 2] = _byte(color.b)
			bytes[index + 3] = 255
	var albedo := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)
	var emission := Image.create(size, size, false, Image.FORMAT_RGBA8)
	emission.fill(Color(0.0, 0.0, 0.0, 1.0))
	_apply_logo(albedo, emission)
	_paint_play_lines(albedo)
	return [albedo, emission]

func _apply_logo(albedo: Image, emission: Image) -> void:
	var logo := _image(LOGO_PATH)
	if logo == null or logo.is_empty():
		push_warning("FlickDisc logo could not be loaded")
		return
	logo.convert(Image.FORMAT_RGBA8)
	var diameter := 940
	logo.resize(diameter, diameter, Image.INTERPOLATE_LANCZOS)
	var origin := (albedo.get_width() - diameter) / 2
	var half := float(diameter) * 0.5
	for y in diameter:
		for x in diameter:
			var dx := float(x) + 0.5 - half
			var dy := float(y) + 0.5 - half
			var radius := sqrt(dx * dx + dy * dy) / half
			# Keep the hole and the scoring rings on clear wood. The mark sits in the outer band.
			if radius < 0.55 or radius > 0.96:
				continue
			var fade := 0.16 if radius < 0.9 else (0.96 - radius) / 0.06 * 0.16
			var src := logo.get_pixel(x, y)
			var kept := albedo.get_pixel(origin + x, origin + y)
			albedo.set_pixel(origin + x, origin + y, kept.lerp(Color(src.r, src.g, src.b), fade))
			var neon := src.r > 0.45 and src.r > src.b and src.g < src.r * 1.05
			var chrome := src.r > 0.78 and src.g > 0.78 and src.b > 0.78
			if fade > 0.2 and (neon or chrome):
				emission.set_pixel(origin + x, origin + y, Color(src.r, src.g, src.b, fade * 0.35))

func _paint_play_lines(albedo: Image) -> void:
	var center := (float(albedo.get_width()) - 1.0) * 0.5
	var surface := Metrics.SURFACE_RADIUS
	var hole := Metrics.HOLE_RADIUS / surface * center
	var lip := hole * 1.45
	_fill_disc(albedo, center, lip, Color("#f0c56a"))
	_fill_disc(albedo, center, hole, Color("#12080c"))
	for ring in [Metrics.RING_15, Metrics.RING_10, Metrics.RING_5]:
		_stroke_circle(albedo, center, ring / surface * center, center * 0.007, Color("#fff6fc"))
	_stroke_cross(albedo, center, Color(1.0, 0.92, 0.96))

func _fill_disc(albedo: Image, center: float, radius: float, color: Color) -> void:
	var min_pixel := int(floor(center - radius))
	var max_pixel := int(ceil(center + radius))
	var limit := albedo.get_width() - 1
	for y in range(maxi(min_pixel, 0), mini(max_pixel, limit) + 1):
		for x in range(maxi(min_pixel, 0), mini(max_pixel, limit) + 1):
			var dx := float(x) - center
			var dy := float(y) - center
			if dx * dx + dy * dy <= radius * radius:
				albedo.set_pixel(x, y, color)

func _stroke_circle(albedo: Image, center: float, radius: float, width: float, color: Color) -> void:
	var pad := width + 1.0
	var min_pixel := int(floor(center - radius - pad))
	var max_pixel := int(ceil(center + radius + pad))
	var limit := albedo.get_width() - 1
	for y in range(maxi(min_pixel, 0), mini(max_pixel, limit) + 1):
		for x in range(maxi(min_pixel, 0), mini(max_pixel, limit) + 1):
			var dx := float(x) - center
			var dy := float(y) - center
			if absf(sqrt(dx * dx + dy * dy) - radius) <= width:
				albedo.set_pixel(x, y, albedo.get_pixel(x, y).lerp(color, 0.88))

func _stroke_cross(albedo: Image, center: float, color: Color) -> void:
	var size := albedo.get_width()
	var inner := center * 0.16
	var outer := center * 0.95
	for axis in size:
		var distance := absf(float(axis) - center)
		if distance < inner or distance > outer:
			continue
		for offset in range(-2, 3):
			var across := int(center) + offset
			if across < 0 or across >= size:
				continue
			albedo.set_pixel(across, axis, albedo.get_pixel(across, axis).lerp(color, 0.75))
			albedo.set_pixel(axis, across, albedo.get_pixel(axis, across).lerp(color, 0.75))

func _wood_color(dx: float, dy: float, radius: float) -> Color:
	var grain := 0.5 + 0.5 * sin(dx * 28.0 + sin(dy * 4.0) * 2.2)
	var fine := 0.5 + 0.5 * sin((dx * 2.0 + dy * 0.35) * 90.0)
	var color := Color("#c4894a").lerp(Color("#8a5528"), grain * 0.78)
	color = color.lerp(Color("#5a3218"), fine * 0.1 + radius * 0.22)
	var knot := Vector2(dx - 0.22, dy + 0.31).length()
	if knot < 0.045:
		color = color.lerp(Color("#4a2814"), 1.0 - knot / 0.045)
	return color

func _apply_rings(color: Color, dx: float, dy: float, radius: float) -> Color:
	if radius < 0.117:
		return Color("#140c0e")
	if radius < 0.145:
		return Color("#e8c56a").lerp(Color("#fff1c4"), (0.145 - radius) / 0.028)
	var rings: Array[float] = [0.435, 0.696, 0.955]
	for ring_radius in rings:
		var distance := absf(radius - ring_radius)
		if distance < 0.014:
			var strength := 1.0 - distance / 0.014
			return color.lerp(Color("#1a0e0a"), strength)
	if radius > 0.16 and radius < 0.96 and (absf(dx) < 0.008 or absf(dy) < 0.008):
		return color.lerp(Color("#24140e"), 0.92)
	return color

func _stamp_marks(bytes: PackedByteArray, size: int) -> void:
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var hole := float(size) * 0.034
	_paint_stroke(bytes, size, _digit_two(center + Vector2(-hole * 0.78, 0.0), hole * 0.95), hole * 0.15, Color("#f3d48a"))
	_paint_stroke(bytes, size, _oval(center + Vector2(hole * 0.72, 0.0), hole * 0.38, hole * 0.58, 28), hole * 0.16, Color("#f3d48a"))
	_paint_number(bytes, size, "15", center + Vector2(float(size) * 0.145, 0.0), float(size) * 0.018, Color("#2a140e"))
	_paint_number(bytes, size, "10", center + Vector2(float(size) * 0.25, 0.0), float(size) * 0.018, Color("#2a140e"))
	_paint_number(bytes, size, "5", center + Vector2(float(size) * 0.36, 0.0), float(size) * 0.02, Color("#2a140e"))

func _oval(origin: Vector2, radius_x: float, radius_y: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in steps + 1:
		var angle := TAU * float(index) / float(steps)
		points.append(origin + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points

func _digit_two(origin: Vector2, height: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var width := height * 0.56
	for index in 14:
		var t := float(index) / 13.0
		var angle := PI + t * PI
		points.append(origin + Vector2(cos(angle) * width * 0.5, -height * 0.06 + sin(angle) * height * 0.36))
	points.append(origin + Vector2(-width * 0.5, height * 0.42))
	points.append(origin + Vector2(width * 0.52, height * 0.42))
	return points

func _paint_number(bytes: PackedByteArray, size: int, text: String, origin: Vector2, height: float, color: Color) -> void:
	var cursor := origin.x - height * 0.7 * float(text.length() - 1)
	for character_index in text.length():
		var glyph := text[character_index]
		var at := Vector2(cursor, origin.y)
		if glyph == "0":
			_paint_stroke(bytes, size, _oval(at, height * 0.34, height * 0.48, 20), height * 0.16, color)
		elif glyph == "1":
			var stem := PackedVector2Array([at + Vector2(0.0, -height * 0.48), at + Vector2(0.0, height * 0.48)])
			_paint_stroke(bytes, size, stem, height * 0.16, color)
		elif glyph == "5":
			_paint_stroke(bytes, size, _digit_five(at, height), height * 0.15, color)
		cursor += height * 1.35

func _digit_five(origin: Vector2, height: float) -> PackedVector2Array:
	var width := height * 0.55
	return PackedVector2Array([
		origin + Vector2(width * 0.45, -height * 0.46),
		origin + Vector2(-width * 0.45, -height * 0.46),
		origin + Vector2(-width * 0.45, -height * 0.05),
		origin + Vector2(width * 0.2, -height * 0.12),
		origin + Vector2(width * 0.48, height * 0.16),
		origin + Vector2(0.0, height * 0.48),
		origin + Vector2(-width * 0.5, height * 0.32),
	])

func _paint_stroke(bytes: PackedByteArray, size: int, points: PackedVector2Array, width: float, color: Color) -> void:
	if points.size() < 2:
		return
	var radius := width * 0.5
	var padding := radius + 2.0
	var min_x := 100000
	var min_y := 100000
	var max_x := 0
	var max_y := 0
	for point in points:
		min_x = mini(min_x, int(floor(point.x - padding)))
		min_y = mini(min_y, int(floor(point.y - padding)))
		max_x = maxi(max_x, int(ceil(point.x + padding)))
		max_y = maxi(max_y, int(ceil(point.y + padding)))
	min_x = clampi(min_x, 0, size - 1)
	min_y = clampi(min_y, 0, size - 1)
	max_x = clampi(max_x, 0, size - 1)
	max_y = clampi(max_y, 0, size - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var sample := Vector2(float(x) + 0.5, float(y) + 0.5)
			var nearest := _distance_to_path(sample, points)
			var edge := radius + 1.25
			if nearest > edge:
				continue
			var alpha := clampf((edge - nearest) / 2.5, 0.0, 1.0)
			_blend_pixel(bytes, size, x, y, color, alpha)

func _distance_to_path(point: Vector2, points: PackedVector2Array) -> float:
	var best := 100000.0
	for index in points.size() - 1:
		best = minf(best, _distance_to_segment(point, points[index], points[index + 1]))
	return best

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)

func _blend_pixel(bytes: PackedByteArray, size: int, x: int, y: int, color: Color, alpha: float) -> void:
	var index := (y * size + x) * 4
	var keep := 1.0 - alpha
	bytes[index] = _byte(float(bytes[index]) / 255.0 * keep + color.r * alpha)
	bytes[index + 1] = _byte(float(bytes[index + 1]) / 255.0 * keep + color.g * alpha)
	bytes[index + 2] = _byte(float(bytes[index + 2]) / 255.0 * keep + color.b * alpha)

func _byte(value: float) -> int:
	return clampi(int(round(value * 255.0)), 0, 255)
