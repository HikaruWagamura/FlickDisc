extends Node3D

## Builds the round crokinole table: wood surface, scoring rings, bumper, and pink rim.
## Geometry is generated once so the 2D rink and this 3D view share the same rules.

const Metrics = preload("res://scripts/table_metrics.gd")

const _GLYPHS := {
	"F": ["11111", "10000", "11110", "10000", "10000", "10000", "10000"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"I": ["111", "010", "010", "010", "010", "010", "111"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
	"0": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
}

func _ready() -> void:
	_build_room()
	_build_table_body()
	_build_surface()
	_build_rail()
	_build_throw_line()

func _build_room() -> void:
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#100c12")
	floor_material.roughness = 0.92
	Metrics.add_mesh(self, _box(Vector3(8.0, 0.04, 8.0)), floor_material, Vector3(0.0, -0.62, 0.0))

	var rug_material := StandardMaterial3D.new()
	rug_material.albedo_color = Color("#1a0c14")
	rug_material.roughness = 0.88
	Metrics.add_mesh(self, Metrics.cylinder(1.72, 0.02, 48), rug_material, Vector3(0.0, -0.595, 0.0))

func _build_table_body() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("#140e12")
	body_material.roughness = 0.55
	body_material.metallic = 0.18
	Metrics.add_mesh(self, Metrics.cylinder(1.08, 0.18, 64), body_material, Vector3(0.0, -0.12, 0.0))

	var leg_material := Metrics.plastic(Color("#1c1418"), 0.4, 0.0)
	leg_material.metallic = 0.35
	for index in 4:
		var angle := PI * 0.25 + float(index) * PI * 0.5
		var leg := Metrics.cylinder(0.045, 0.46, 16)
		leg.bottom_radius = 0.055
		Metrics.add_mesh(
			self,
			leg,
			leg_material,
			Vector3(cos(angle) * 0.74, -0.39, sin(angle) * 0.74)
		)

	var skirt := CylinderMesh.new()
	skirt.top_radius = 1.135
	skirt.bottom_radius = 1.135
	skirt.height = 0.2
	skirt.radial_segments = 80
	skirt.cap_top = false
	skirt.cap_bottom = false
	var skirt_material := StandardMaterial3D.new()
	skirt_material.albedo_texture = _make_rim_texture()
	skirt_material.roughness = 0.38
	skirt_material.metallic = 0.22
	skirt_material.emission_enabled = true
	skirt_material.emission_texture = skirt_material.albedo_texture
	skirt_material.emission = Color("#ff4f9a")
	skirt_material.emission_energy_multiplier = 0.22
	Metrics.add_mesh(self, skirt, skirt_material, Vector3(0.0, -0.06, 0.0))

func _build_surface() -> void:
	var texture := _make_surface_texture()
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.78
	material.metallic = 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var surface := MeshInstance3D.new()
	surface.mesh = _playing_surface_mesh(Metrics.PLAY_RADIUS, 0.03)
	surface.set_surface_override_material(0, material)
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("#3b2418")
	edge.roughness = 0.64
	edge.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_surface_override_material(1, edge)
	add_child(surface)

	var hole := TorusMesh.new()
	hole.inner_radius = 0.09
	hole.outer_radius = 0.125
	hole.rings = 40
	hole.ring_segments = 12
	Metrics.add_mesh(self, hole, Metrics.plastic(Color("#ff4f9a"), 0.28, 0.45), Vector3(0.0, 0.008, 0.0))

func _build_rail() -> void:
	var rail := TorusMesh.new()
	rail.inner_radius = Metrics.PLAY_RADIUS
	rail.outer_radius = Metrics.PLAY_RADIUS + 0.09
	rail.rings = 72
	rail.ring_segments = 16
	var rail_material := Metrics.plastic(Color("#1a1218"), 0.32, 0.0)
	rail_material.metallic = 0.45
	Metrics.add_mesh(self, rail, rail_material, Vector3(0.0, 0.028, 0.0))

	var halo := TorusMesh.new()
	halo.inner_radius = 1.145
	halo.outer_radius = 1.2
	halo.rings = 64
	halo.ring_segments = 12
	Metrics.add_mesh(self, halo, Metrics.plastic(Color("#ff3d92"), 0.24, 1.6), Vector3(0.0, 0.012, 0.0))

	for index in 16:
		var angle := float(index) * TAU / 16.0
		var stud := SphereMesh.new()
		stud.radius = 0.026
		stud.height = 0.052
		stud.radial_segments = 16
		stud.rings = 8
		var pink := index % 2 == 0
		var stud_color := Color("#ff4f9a") if pink else Color("#f6f1ea")
		Metrics.add_mesh(
			self,
			stud,
			Metrics.plastic(stud_color, 0.22, 0.7 if pink else 0.12),
			Vector3(cos(angle) * 1.055, 0.075, sin(angle) * 1.055)
		)

	for index in 4:
		_add_crown(PI * 0.25 + float(index) * PI * 0.5)
		_add_bolt(float(index) * PI * 0.5)

func _add_crown(angle: float) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(cos(angle) * 1.09, 0.1, sin(angle) * 1.09)
	add_child(holder)
	holder.look_at(Vector3(0.0, holder.position.y, 0.0), Vector3.UP)
	var material := Metrics.plastic(Color("#ff3d92"), 0.3, 1.15)
	var base := BoxMesh.new()
	base.size = Vector3(0.12, 0.028, 0.028)
	Metrics.add_mesh(holder, base, material)
	for peak_index in 3:
		var peak := BoxMesh.new()
		var peak_height := 0.07 if peak_index == 1 else 0.048
		peak.size = Vector3(0.022, peak_height, 0.02)
		Metrics.add_mesh(
			holder,
			peak,
			material,
			Vector3(lerpf(-0.04, 0.04, float(peak_index) / 2.0), 0.04, 0.0)
		)

func _add_bolt(angle: float) -> void:
	var bolt := BoxMesh.new()
	bolt.size = Vector3(0.03, 0.09, 0.012)
	var instance := Metrics.add_mesh(
		self,
		bolt,
		Metrics.plastic(Color("#ffd4ea"), 0.2, 1.3),
		Vector3(cos(angle) * 1.09, 0.12, sin(angle) * 1.09)
	)
	instance.rotation = Vector3(0.0, -angle, deg_to_rad(16.0))

func _build_throw_line() -> void:
	var line := BoxMesh.new()
	line.size = Vector3(0.78, 0.008, 0.016)
	var material := Metrics.plastic(Color("#f0c15a"), 0.35, 0.35)
	Metrics.add_mesh(self, line, material, Vector3(0.0, 0.008, 0.52))

func _playing_surface_mesh(radius: float, thickness: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 96
	for index in segments:
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		_add_surface_vertex(top, Vector3(0.0, 0.0, 0.0), Vector2(0.5, 0.5))
		_add_surface_vertex(top, Vector3(cos(a0) * radius, 0.0, sin(a0) * radius), Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5))
		_add_surface_vertex(top, Vector3(cos(a1) * radius, 0.0, sin(a1) * radius), Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5))
	mesh = top.commit(mesh)

	var side := SurfaceTool.new()
	side.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom_y := -thickness
	for index in segments:
		var a0 := TAU * float(index) / float(segments)
		var a1 := TAU * float(index + 1) / float(segments)
		var n0 := Vector3(cos(a0), 0.0, sin(a0))
		var n1 := Vector3(cos(a1), 0.0, sin(a1))
		var p0_top := n0 * radius
		var p1_top := n1 * radius
		var p0_bottom := p0_top + Vector3(0.0, bottom_y, 0.0)
		var p1_bottom := p1_top + Vector3(0.0, bottom_y, 0.0)
		_add_side_vertex(side, p0_top, n0)
		_add_side_vertex(side, p0_bottom, n0)
		_add_side_vertex(side, p1_bottom, n1)
		_add_side_vertex(side, p0_top, n0)
		_add_side_vertex(side, p1_bottom, n1)
		_add_side_vertex(side, p1_top, n1)
	return side.commit(mesh)

func _add_surface_vertex(tool: SurfaceTool, point: Vector3, uv: Vector2) -> void:
	tool.set_normal(Vector3.UP)
	tool.set_uv(uv)
	tool.add_vertex(point)

func _add_side_vertex(tool: SurfaceTool, point: Vector3, normal: Vector3) -> void:
	tool.set_normal(normal)
	tool.set_uv(Vector2(0.5 + normal.x * 0.5, 0.98))
	tool.add_vertex(point)

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _make_surface_texture() -> Texture2D:
	var size := 512
	var bytes := PackedByteArray()
	bytes.resize(size * size * 4)
	var center := (float(size) - 1.0) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var splats: Array[Vector2] = []
	var splat_radii: Array[float] = []
	for _index in 22:
		var angle := rng.randf() * TAU
		var radius := rng.randf_range(0.18, 0.92) * center
		splats.append(Vector2(center + cos(angle) * radius, center + sin(angle) * radius))
		splat_radii.append(rng.randf_range(4.0, 11.0))

	for y in size:
		var row := y * size * 4
		var dy := (float(y) - center) / center
		for x in size:
			var dx := (float(x) - center) / center
			var radius := sqrt(dx * dx + dy * dy)
			var color := _wood_color(dx, dy, radius)
			color = _apply_markings(color, dx, dy, radius)
			var index := row + x * 4
			bytes[index] = _byte(color.r)
			bytes[index + 1] = _byte(color.g)
			bytes[index + 2] = _byte(color.b)
			bytes[index + 3] = 255

	_stamp_splats(bytes, size, splats, splat_radii)
	_stamp_logo(bytes, size)
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, bytes)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _wood_color(dx: float, dy: float, radius: float) -> Color:
	var grain := 0.5 + 0.5 * sin(dx * 16.0 + sin(dy * 5.5) * 2.4)
	var fine := 0.5 + 0.5 * sin((dx * 1.6 + dy) * 70.0)
	var color := Color("#c9894c").lerp(Color("#8a532b"), grain * 0.9)
	color = color.lerp(Color("#5c341c"), fine * 0.1 + radius * 0.2)
	if radius > 0.9:
		color = color.lerp(Color("#5a321c"), (radius - 0.9) / 0.1)
	if radius < 0.42:
		color = color.lerp(Color("#6b3d24"), (0.42 - radius) * 0.45)
	return color

func _apply_markings(color: Color, dx: float, dy: float, radius: float) -> Color:
	if radius < 0.09:
		return Color("#140a0e")
	if radius < 0.118:
		return Color("#ff4f9a").lerp(Color("#ffd0e6"), (0.118 - radius) / 0.028)
	var ring_radii: Array[float] = [0.22, 0.36, 0.50, 0.64, 0.78, 0.91]
	for ring_radius in ring_radii:
		var distance := absf(radius - ring_radius)
		if distance < 0.016:
			return color.lerp(Color("#1a0d09"), 1.0 - distance / 0.016)
	if radius > 0.16 and radius < 0.93 and (absf(dx) < 0.012 or absf(dy) < 0.012):
		return color.lerp(Color("#24140e"), 0.9)
	return _apply_dots(color, dx, dy, radius)

func _apply_dots(color: Color, dx: float, dy: float, radius: float) -> Color:
	var dot_rings: Array[float] = [0.36, 0.64]
	for ring_radius in dot_rings:
		if absf(radius - ring_radius) > 0.03:
			continue
		var angle := atan2(dy, dx)
		var spoke := fposmod(angle, TAU / 8.0)
		var spoke_distance := minf(spoke, TAU / 8.0 - spoke) * ring_radius
		if spoke_distance < 0.018 and absf(radius - ring_radius) < 0.018:
			return Color("#f7f3ea")
	return color

func _stamp_splats(bytes: PackedByteArray, size: int, splats: Array[Vector2], radii: Array[float]) -> void:
	for index in splats.size():
		var splat := splats[index]
		var radius := radii[index]
		var min_x := maxi(int(splat.x - radius) - 1, 0)
		var max_x := mini(int(splat.x + radius) + 2, size)
		var min_y := maxi(int(splat.y - radius) - 1, 0)
		var max_y := mini(int(splat.y + radius) + 2, size)
		for y in range(min_y, max_y):
			for x in range(min_x, max_x):
				var distance := Vector2(float(x), float(y)).distance_to(splat)
				if distance >= radius:
					continue
				var blend := (1.0 - distance / radius) * 0.62
				_blend_pixel(bytes, size, x, y, Color("#ff4d9a"), blend)

func _stamp_logo(bytes: PackedByteArray, size: int) -> void:
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	_stamp_text(bytes, size, "20", center + Vector2(0.0, -1.0), 4, Color("#f3bd56"))
	var title_origin := center + Vector2(0.0, -74.0)
	var subtitle_origin := center + Vector2(0.0, 54.0)
	for offset in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2)]:
		_stamp_text(bytes, size, "FLICK", title_origin + offset, 9, Color("#ff4f9a"))
		_stamp_text(bytes, size, "DISC", subtitle_origin + offset, 9, Color("#ff4f9a"))
	_stamp_text(bytes, size, "FLICK", title_origin, 9, Color("#1a0c0e"))
	_stamp_text(bytes, size, "DISC", subtitle_origin, 9, Color("#1a0c0e"))

func _stamp_text(bytes: PackedByteArray, size: int, text: String, origin: Vector2, pixel: int, color: Color) -> void:
	var total_width := 0
	for character_index in text.length():
		var glyph: Array = _GLYPHS[text[character_index]]
		total_width += (glyph[0] as String).length() * pixel + pixel
	total_width -= pixel
	var cursor_x := origin.x - float(total_width) * 0.5
	var start_y := origin.y - 3.5 * float(pixel)
	for character_index in text.length():
		var glyph: Array = _GLYPHS[text[character_index]]
		var glyph_width := (glyph[0] as String).length()
		for row in glyph.size():
			var row_text := glyph[row] as String
			for column in glyph_width:
				if row_text[column] != "1":
					continue
				_fill_rect(
					bytes,
					size,
					int(cursor_x) + column * pixel,
					int(start_y) + row * pixel,
					pixel,
					pixel,
					color
				)
		cursor_x += float(glyph_width * pixel + pixel)

func _make_rim_texture() -> Texture2D:
	var width := 1024
	var height := 128
	var bytes := PackedByteArray()
	bytes.resize(width * height * 4)
	var panel_width := width / 8
	for y in height:
		for x in width:
			var panel := int(x / panel_width)
			var local_u := float(x % panel_width) / float(panel_width)
			var local_v := float(y) / float(height)
			var color := _rim_color(local_u, local_v, panel)
			var index := (y * width + x) * 4
			bytes[index] = _byte(color.r)
			bytes[index + 1] = _byte(color.g)
			bytes[index + 2] = _byte(color.b)
			bytes[index + 3] = 255
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _rim_color(u: float, v: float, panel: int) -> Color:
	var background := Color("#12080e")
	if v < 0.1 or v > 0.9:
		return Color("#ff4f9a")
	if v > 0.74 and fmod(u * 10.0 + v * 8.0, 1.0) < 0.38:
		background = Color("#7a2454")
	if panel % 2 == 0:
		return _crown_panel(background, u, v)
	return _bolt_panel(background, u, v)

func _crown_panel(background: Color, u: float, v: float) -> Color:
	if u > 0.16 and u < 0.84 and v > 0.56 and v < 0.74:
		if u > 0.24 and u < 0.76 and v > 0.62 and v < 0.7:
			return Color("#2a1020")
		return Color("#ff4f9a")
	var peaks: Array[float] = [0.28, 0.5, 0.72]
	for peak in peaks:
		if v < 0.2 or v > 0.58:
			continue
		var t := (v - 0.2) / 0.38
		var half_width := lerpf(0.0, 0.11, t)
		if absf(u - peak) <= half_width:
			return Color("#ff4f9a") if absf(u - peak) > half_width * 0.45 else Color("#ffd0e8")
	if Vector2(u - 0.5, v - 0.8).length() < 0.045:
		return Color("#fff4ea")
	return background

func _bolt_panel(background: Color, u: float, v: float) -> Color:
	var points: Array[Vector2] = [
		Vector2(0.68, 0.16),
		Vector2(0.4, 0.4),
		Vector2(0.58, 0.48),
		Vector2(0.3, 0.84),
	]
	var point := Vector2(u, v)
	for segment in points.size() - 1:
		if _distance_to_segment(point, points[segment], points[segment + 1]) < 0.055:
			return Color("#ffd4ea") if _distance_to_segment(point, points[segment], points[segment + 1]) < 0.028 else Color("#ff4f9a")
	if absf(u - 0.5) < 0.08 and absf(v - 0.5) < 0.08:
		return Color("#3a1830")
	return background

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var length_squared := start.distance_squared_to(end)
	if length_squared <= 0.00001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(end - start) / length_squared, 0.0, 1.0)
	return point.distance_to(start + (end - start) * t)

func _fill_rect(bytes: PackedByteArray, size: int, origin_x: int, origin_y: int, width: int, height: int, color: Color) -> void:
	for y in range(origin_y, origin_y + height):
		if y < 0 or y >= size:
			continue
		for x in range(origin_x, origin_x + width):
			if x < 0 or x >= size:
				continue
			_blend_pixel(bytes, size, x, y, color, 1.0)

func _blend_pixel(bytes: PackedByteArray, size: int, x: int, y: int, color: Color, amount: float) -> void:
	var index := (y * size + x) * 4
	var keep := 1.0 - amount
	bytes[index] = _byte(float(bytes[index]) / 255.0 * keep + color.r * amount)
	bytes[index + 1] = _byte(float(bytes[index + 1]) / 255.0 * keep + color.g * amount)
	bytes[index + 2] = _byte(float(bytes[index + 2]) / 255.0 * keep + color.b * amount)

func _byte(value: float) -> int:
	return clampi(int(round(value * 255.0)), 0, 255)
