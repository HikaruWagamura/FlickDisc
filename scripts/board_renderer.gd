extends Node3D

## High-resolution crokinole table: recessed ditch, scoring rings, and eight pegs.

const Metrics = preload("res://scripts/table_metrics.gd")

func _ready() -> void:
	_build_room()
	_build_body()
	_build_surface()
	_build_rail()
	_build_pegs()

func _build_room() -> void:
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#120e12")
	floor_material.roughness = 0.94
	Metrics.add_mesh(self, _box(Vector3(8.0, 0.04, 8.0)), floor_material, Vector3(0.0, -0.62, 0.0))
	var rug := StandardMaterial3D.new()
	rug.albedo_color = Color("#241018")
	rug.roughness = 0.9
	Metrics.add_mesh(self, Metrics.cylinder(1.85, 0.02, 64), rug, Vector3(0.0, -0.595, 0.0))

func _build_body() -> void:
	var body := StandardMaterial3D.new()
	body.albedo_color = Color("#2a1612")
	body.roughness = 0.48
	body.metallic = 0.22
	Metrics.add_mesh(self, Metrics.cylinder(1.16, 0.16, 80), body, Vector3(0.0, -0.1, 0.0))

	var leg_material := Metrics.plastic(Color("#1a1012"), 0.38, 0.0)
	leg_material.metallic = 0.4
	for index in 4:
		var angle := PI * 0.25 + float(index) * PI * 0.5
		var leg := Metrics.cylinder(0.05, 0.42, 16)
		leg.bottom_radius = 0.06
		Metrics.add_mesh(self, leg, leg_material, Vector3(cos(angle) * 0.78, -0.38, sin(angle) * 0.78))

	var skirt := CylinderMesh.new()
	skirt.top_radius = 1.2
	skirt.bottom_radius = 1.2
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
	var texture := _make_surface_texture()
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = texture
	wood.roughness = 0.42
	wood.metallic = 0.04
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
	Metrics.add_mesh(self, inlay, Metrics.plastic(Color("#ff4f86"), 0.22, 0.85), Vector3(0.0, 0.028, 0.0))

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

func _make_surface_texture() -> Texture2D:
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
			color = _apply_rings(color, dx, dy, radius)
			var index := row + x * 4
			bytes[index] = _byte(color.r)
			bytes[index + 1] = _byte(color.g)
			bytes[index + 2] = _byte(color.b)
			bytes[index + 3] = 255
	_stamp_marks(bytes, size)
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

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
