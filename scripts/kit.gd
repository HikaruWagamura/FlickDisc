class_name FlickKit
extends RefCounted

## Player kit. Palettes and skins are unlocked so we can try them on
## bowls and discs. Paid locks come later.

const SHADER := preload("res://shaders/bowl_kit.gdshader")
const DISC_SHADER := preload("res://shaders/disc_kit.gdshader")

const LOOK_SPLIT := 0
const LOOK_BOTH := 1
const LOOK_GRAPHIC := 2
const LOOK_GRAPHIC_ONE := 3

const PALETTES := [
	{"id": "pink", "name": "Club pink", "a": Color("#ff3d9a"), "b": Color("#fff6f0")},
	{"id": "red", "name": "Match red", "a": Color("#c41018"), "b": Color("#f4ece6")},
	{"id": "crimson", "name": "Crimson", "a": Color("#7a1020"), "b": Color("#f0e4d8")},
	{"id": "tangerine", "name": "Tangerine", "a": Color("#e85a12"), "b": Color("#fff3e6")},
	{"id": "gold", "name": "Gold", "a": Color("#d4a017"), "b": Color("#fff8e8")},
	{"id": "lime", "name": "Lime", "a": Color("#7ccf3a"), "b": Color("#f4ffe8")},
	{"id": "forest", "name": "Forest", "a": Color("#1f6b3a"), "b": Color("#e8f4ea")},
	{"id": "mint", "name": "Mint", "a": Color("#3ecf9a"), "b": Color("#edfff8")},
	{"id": "ice", "name": "Ice", "a": Color("#5ad4ea"), "b": Color("#f2fbff")},
	{"id": "teal", "name": "Teal", "a": Color("#147a86"), "b": Color("#e6f7f6")},
	{"id": "royal", "name": "Royal", "a": Color("#2f4ad8"), "b": Color("#eef2ff")},
	{"id": "navy", "name": "Navy", "a": Color("#14285a"), "b": Color("#e8eef8")},
	{"id": "violet", "name": "Violet", "a": Color("#7a3dff"), "b": Color("#f4eeff")},
	{"id": "magenta", "name": "Magenta", "a": Color("#c41278"), "b": Color("#ffe8f4")},
	{"id": "rose", "name": "Rose", "a": Color("#e56b8a"), "b": Color("#fff0f4")},
	{"id": "coral", "name": "Coral", "a": Color("#ff6b4a"), "b": Color("#fff0ea")},
	{"id": "copper", "name": "Copper", "a": Color("#b85a28"), "b": Color("#f8ece0")},
	{"id": "chalk", "name": "Chalk", "a": Color("#f4f4f6"), "b": Color("#d0d0d6")},
	{"id": "cream", "name": "Cream", "a": Color("#f3e6cf"), "b": Color("#fffaf2")},
	{"id": "slate", "name": "Slate", "a": Color("#5a6578"), "b": Color("#e8edf2")},
	{"id": "charcoal", "name": "Charcoal", "a": Color("#2a2a30"), "b": Color("#ece8e2")},
	{"id": "black", "name": "Black", "a": Color("#121214"), "b": Color("#f0ece6")},
]

const SKINS := [
	{"id": "split", "name": "HALF / HALF", "look": LOOK_SPLIT},
	{"id": "both", "name": "BOTH SIDES", "look": LOOK_BOTH},
	{"id": "camo", "name": "WOODLAND", "look": LOOK_GRAPHIC},
	{"id": "arctic", "name": "ARCTIC", "look": LOOK_GRAPHIC},
	{"id": "desert", "name": "DESERT", "look": LOOK_GRAPHIC},
	{"id": "digital", "name": "DIGITAL", "look": LOOK_GRAPHIC},
	{"id": "urban", "name": "URBAN", "look": LOOK_GRAPHIC},
	{"id": "carbon", "name": "CARBON", "look": LOOK_GRAPHIC},
	{"id": "marble", "name": "MARBLE", "look": LOOK_GRAPHIC},
	{"id": "flame", "name": "FLAME", "look": LOOK_GRAPHIC},
	{"id": "galaxy", "name": "GALAXY", "look": LOOK_GRAPHIC},
	{"id": "sunset", "name": "SUNSET", "look": LOOK_GRAPHIC},
	{"id": "royal", "name": "ROYAL", "look": LOOK_GRAPHIC},
	{"id": "tiger", "name": "TIGER", "look": LOOK_GRAPHIC},
	{"id": "honeycomb", "name": "HONEYCOMB", "look": LOOK_GRAPHIC},
	{"id": "checker", "name": "CHECKER", "look": LOOK_GRAPHIC},
	{"id": "gold", "name": "GOLD LEAF", "look": LOOK_GRAPHIC},
	{"id": "photo", "name": "PHOTO FACE", "look": LOOK_GRAPHIC_ONE},
	{"id": "photo_both", "name": "PHOTO WRAP", "look": LOOK_GRAPHIC},
]

static var _graphic_cache := {}
static var _preview_cache := {}


static func default_kit() -> Dictionary:
	return {
		"bowl_skin": "split",
		"bowl_color": 1,
		"disc_skin": "both",
		"disc_color": 0,
	}


static func palette(index: int) -> Dictionary:
	return PALETTES[clampi(index, 0, PALETTES.size() - 1)]


static func skin(skin_id: String) -> Dictionary:
	for item in SKINS:
		if str(item["id"]) == skin_id:
			return item
	return SKINS[0]


static func from_meta(tree: SceneTree) -> Dictionary:
	if tree == null or tree.root == null or not tree.root.has_meta("flickdisc_kit"):
		return default_kit()
	var kit: Variant = tree.root.get_meta("flickdisc_kit")
	if typeof(kit) != TYPE_DICTIONARY:
		return default_kit()
	var out := default_kit()
	out.merge(kit, true)
	return out


static func pack(skin_id: String, color: int) -> Dictionary:
	return {
		"bowl_skin": skin_id,
		"bowl_color": color,
		"disc_skin": skin_id,
		"disc_color": color,
	}


static func paint_holder(holder: Node3D, kit: Dictionary, opponent: bool = false) -> void:
	if holder == null:
		return
	var mi := _find_mesh(holder)
	if mi == null:
		return
	if opponent:
		mi.material_override = null
		return
	_paint_mesh(mi, kit, false)


static func paint_disc(mi: MeshInstance3D, kit: Dictionary) -> void:
	if mi == null:
		return
	_paint_mesh(mi, kit, true)


static func _paint_mesh(mi: MeshInstance3D, kit: Dictionary, for_disc: bool) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = DISC_SHADER if for_disc else SHADER
	var pal := palette(int(kit.get("disc_color" if for_disc else "bowl_color", 0)))
	var look_info := skin(str(kit.get("disc_skin" if for_disc else "bowl_skin", "split")))
	mat.set_shader_parameter("color_a", pal["a"])
	mat.set_shader_parameter("color_b", pal["b"])
	mat.set_shader_parameter("look", int(look_info["look"]))
	mat.set_shader_parameter("seam", 0.08)
	var graphic := graphic_texture(str(look_info["id"]), pal["a"], pal["b"])
	mat.set_shader_parameter("graphic_tex", graphic)
	mat.set_shader_parameter("graphic_mix", 1.0)
	if for_disc:
		var span := 0.22
		var face := 0
		if mi.mesh != null:
			var box: AABB = mi.mesh.get_aabb()
			var ax := box.size.x
			var ay := box.size.y
			var az := box.size.z
			if ay <= ax and ay <= az:
				face = 0
				span = maxf(ax, az) * 0.5
			elif az <= ax and az <= ay:
				face = 1
				span = maxf(ax, ay) * 0.5
			else:
				face = 2
				span = maxf(ay, az) * 0.5
			span = maxf(span, 0.001)
		mat.set_shader_parameter("span", span)
		mat.set_shader_parameter("face", face)
	else:
		var grain: Texture2D = load("res://assets/bowls/textures/bowl_color_3.jpg")
		var normal: Texture2D = load("res://assets/bowls/textures/bowl_normal.jpg")
		mat.set_shader_parameter("grain_tex", grain)
		mat.set_shader_parameter("normal_tex", normal)
	mi.material_override = mat


static func disc_colors(kit: Dictionary) -> Dictionary:
	var pal := palette(int(kit.get("disc_color", 0)))
	var skin_id := str(kit.get("disc_skin", "both"))
	return {
		"body": pal["b"] if skin_id == "split" else pal["a"],
		"rim": Color("#2a2a2e"),
		"center": pal["a"],
		"ring": pal["a"],
		"skin": skin_id,
		"graphic": graphic_texture(skin_id, pal["a"], pal["b"]),
	}


static func graphic_texture(skin_id: String, color_a: Color, color_b: Color) -> Texture2D:
	var key := "%s_%s_%s" % [skin_id, color_a.to_html(false), color_b.to_html(false)]
	if _graphic_cache.has(key):
		return _graphic_cache[key]
	var image: Image
	match skin_id:
		"camo":
			image = _camo(color_a, Color("#2a3a1c"), Color("#6a5a32"), Color("#c4b48a"))
		"arctic":
			image = _camo(Color("#f7fbff"), Color("#c8e6f4"), Color("#8fd0ea"), Color("#dcecff"))
		"desert":
			image = _camo(Color("#c4a06a"), Color("#8a6a38"), Color("#e8d2a4"), Color("#5a4020"))
		"urban":
			image = _camo(Color("#4a4e56"), Color("#2a2c32"), Color("#8a8e96"), Color("#1a1c20"))
		"digital":
			image = _digital(color_a, color_b)
		"carbon":
			image = _carbon()
		"marble":
			image = _marble(color_b, color_a)
		"flame":
			image = _flame(color_a)
		"galaxy":
			image = _galaxy()
		"sunset":
			image = _sunset(color_a)
		"royal":
			image = _royal()
		"tiger":
			image = _tiger(color_a)
		"honeycomb":
			image = _honeycomb(color_a)
		"checker":
			image = _checker(color_a, color_b)
		"gold":
			image = _gold()
		"photo", "photo_both":
			image = _photo_face()
		_:
			image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
			image.fill(Color(1, 1, 1, 0))
	var tex := ImageTexture.create_from_image(image)
	_graphic_cache[key] = tex
	return tex


static func preview(kit: Dictionary, for_disc: bool) -> Texture2D:
	var pal := palette(int(kit.get("disc_color" if for_disc else "bowl_color", 0)))
	var skin_id := str(kit.get("disc_skin" if for_disc else "bowl_skin", "split"))
	var color_a: Color = pal["a"]
	var color_b: Color = pal["b"]
	var key := "%s_%s_%s_%s" % [skin_id, color_a.to_html(false), color_b.to_html(false), for_disc]
	if _preview_cache.has(key):
		return _preview_cache[key]
	var look_info := skin(skin_id)
	var graphic := graphic_texture(skin_id, pal["a"], pal["b"])
	var gimg: Image = graphic.get_image() if graphic != null else null
	if gimg != null and gimg.is_compressed():
		gimg.decompress()
	var size := 160
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in size:
		for x in size:
			var nx := (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(size) * 2.0 - 1.0
			var r2 := nx * nx + ny * ny
			if r2 > 1.0:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - r2))
			var side := clampf((nx + 0.08) / 0.16, 0.0, 1.0)
			var col: Color = color_a
			var look := int(look_info["look"])
			if look == LOOK_SPLIT:
				col = color_a.lerp(color_b, side)
			elif look == LOOK_BOTH:
				col = color_a
			else:
				if gimg != null:
					var u := 0.5 + atan2(nx, nz) / TAU
					var v := 0.5 - ny * 0.5
					if for_disc:
						u = clampf(0.5 + nx * 0.5, 0.0, 1.0)
						v = clampf(0.5 + ny * 0.5, 0.0, 1.0)
					var sx := clampi(int(u * float(gimg.get_width())), 0, gimg.get_width() - 1)
					var sy := clampi(int(v * float(gimg.get_height())), 0, gimg.get_height() - 1)
					var sample: Color = gimg.get_pixel(sx, sy)
					if look == LOOK_GRAPHIC_ONE:
						col = color_b.lerp(sample, (1.0 - side) * sample.a)
					else:
						col = sample if sample.a > 0.12 else color_a
			if for_disc and r2 < 0.18:
				col = color_a
			var light := clampf(0.42 + nz * 0.7 + nx * 0.12 - ny * 0.08, 0.22, 1.2)
			var alpha := 1.0 if r2 < 0.9 else clampf((1.0 - r2) / 0.1, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r * light, col.g * light, col.b * light, alpha))
	var tex := ImageTexture.create_from_image(img)
	_preview_cache[key] = tex
	return tex


static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null


static func _camo(c0: Color, c1: Color, c2: Color, c3: Color) -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var blobs := [
		{"c": c0, "x": 0.22, "y": 0.28, "r": 0.42},
		{"c": c1, "x": 0.68, "y": 0.24, "r": 0.38},
		{"c": c2, "x": 0.48, "y": 0.62, "r": 0.46},
		{"c": c3, "x": 0.18, "y": 0.72, "r": 0.32},
		{"c": c1, "x": 0.82, "y": 0.70, "r": 0.36},
		{"c": c0, "x": 0.58, "y": 0.88, "r": 0.28},
		{"c": c3, "x": 0.38, "y": 0.12, "r": 0.24},
		{"c": c2, "x": 0.90, "y": 0.42, "r": 0.26},
	]
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / float(size)
			var v := (float(y) + 0.5) / float(size)
			var col := c1
			var best := 99.0
			for blob in blobs:
				var dx: float = u - float(blob["x"])
				var dy: float = v - float(blob["y"])
				var wobble := 0.05 * sin(u * 18.0 + v * 11.0) + 0.03 * sin(u * 31.0 - v * 17.0)
				var d := sqrt(dx * dx + dy * dy) / (float(blob["r"]) + wobble)
				if d < best:
					best = d
					col = blob["c"]
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	return img


static func _digital(c0: Color, c1: Color) -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cell := 16
	var tones: Array[Color] = [c0, c0.darkened(0.35), c1, c0.lightened(0.18), Color("#1a1c14")]
	for y in size:
		for x in size:
			var cx := x / cell
			var cy := y / cell
			var n := _hash(cx, cy, 17)
			var col: Color = tones[int(n * float(tones.size())) % tones.size()]
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	return img


static func _carbon() -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := float(x)
			var v := float(y)
			var weave := absf(sin((u + v) * 0.22) * sin((u - v) * 0.22))
			var dark := Color(0.08, 0.08, 0.09).lerp(Color(0.22, 0.22, 0.24), weave)
			img.set_pixel(x, y, Color(dark.r, dark.g, dark.b, 1.0))
	return img


static func _marble(base: Color, vein: Color) -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := float(x) / float(size)
			var v := float(y) / float(size)
			var n := sin(u * 12.0 + v * 7.0) + 0.55 * sin(u * 27.0 - v * 19.0 + 1.7)
			n += 0.25 * sin(u * 53.0 + v * 41.0)
			var t := clampf(absf(n) * 0.62, 0.0, 1.0)
			var col := base.lerp(vein, pow(t, 1.8))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	return img


static func _flame(accent: Color) -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var t := float(y) / float(size)
		for x in size:
			var u := float(x) / float(size)
			var wobble := 0.08 * sin(u * 18.0 + t * 9.0)
			var k := clampf(t + wobble, 0.0, 1.0)
			var col := Color("#fff3c0").lerp(Color("#ff7a18"), k)
			col = col.lerp(accent, 0.28)
			col = col.lerp(Color("#4a0610"), clampf((k - 0.55) / 0.45, 0.0, 1.0))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	return img


static func _galaxy() -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := float(x) / float(size)
			var v := float(y) / float(size)
			var neb := 0.5 + 0.5 * sin(u * 7.0 + v * 5.0) * sin(u * 3.0 - v * 8.0)
			var col := Color("#0b0720").lerp(Color("#5a2cff"), neb * 0.7)
			col = col.lerp(Color("#ff3d9a"), clampf(neb - 0.62, 0.0, 1.0) * 0.8)
			var star := _hash(x, y, 91)
			if star > 0.992:
				col = Color(1, 1, 1)
			elif star > 0.984:
				col = col.lerp(Color("#dce8ff"), 0.8)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	return img


static func _sunset(accent: Color) -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var t := float(y) / float(size)
		var band: Color = Color("#ffb070").lerp(Color("#ff3d9a"), t)
		band = band.lerp(accent, 0.28)
		band = band.lerp(Color("#3a1028"), clampf((t - 0.62) / 0.38, 0.0, 1.0))
		for x in size:
			var n := 0.04 * sin(float(x) * 0.11 + float(y) * 0.07)
			img.set_pixel(x, y, Color(clampf(band.r + n, 0, 1), clampf(band.g + n * 0.5, 0, 1), band.b, 1.0))
	return img


static func _royal() -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var t := float(y) / float(size)
			var col := Color("#1a1048").lerp(Color("#5a2cff"), t)
			if int(x + y * 3) % 37 == 0:
				col = Color("#e8c56a")
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	return img


static func _tiger(accent: Color) -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var gold := Color("#e0a030").lerp(accent, 0.35)
	for y in size:
		for x in size:
			var u := float(x) / float(size)
			var v := float(y) / float(size)
			var stripe := sin((u * 9.0 + v * 1.6 + 0.18 * sin(v * 12.0)) * TAU)
			var col := gold if stripe > 0.18 else Color("#1a120c")
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	return img


static func _honeycomb(accent: Color) -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := float(x) / 28.0
			var v := float(y) / 24.0
			var row := floorf(v)
			var colx := floorf(u + (0.5 if int(row) % 2 == 0 else 0.0))
			var dx := u - colx
			var dy := v - row
			var d := maxf(absf(dx - 0.5), absf(dy - 0.5) * 0.92)
			var col := accent.lerp(Color("#1a1208"), 0.45)
			if d > 0.42:
				col = Color("#3a2a12")
			elif d < 0.18:
				col = accent.lightened(0.18)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	return img


static func _checker(c0: Color, c1: Color) -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cell := 32
	for y in size:
		for x in size:
			var on := ((x / cell) + (y / cell)) % 2 == 0
			var col := c0 if on else c1
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	return img


static func _gold() -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := float(x) / float(size)
			var v := float(y) / float(size)
			var n := 0.5 + 0.5 * sin(u * 21.0 + v * 17.0) * sin(u * 9.0 - v * 13.0)
			var col := Color("#6a4a12").lerp(Color("#f0d070"), n)
			if _hash(x, y, 4) > 0.94:
				col = Color("#fff4c8")
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	return img


static func _photo_face() -> Image:
	var tex: Texture2D = load("res://assets/flickdisc_mark.png")
	if tex == null:
		tex = load("res://assets/flick_disc_logo.png")
	if tex == null:
		var blank := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		blank.fill(Color(1, 1, 1, 0))
		return blank
	var image := tex.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() > 512:
		image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
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
	return image


static func _hash(x: int, y: int, salt: int) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 1274126177) & 0x7fffffff
	return float(h % 10000) / 10000.0
