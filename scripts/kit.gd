class_name FlickKit
extends RefCounted

## Player kit. Palettes and skins are unlocked so we can try them on
## bowls and discs. Paid locks come later.

const SHADER := preload("res://shaders/bowl_kit.gdshader")
const DISC_SHADER := preload("res://shaders/disc_kit.gdshader")

const LOOK_SPLIT := 0
const LOOK_BOTH := 1
const LOOK_GRAPHIC := 2
const LOOK_PHOTO_LEFT := 3
const LOOK_PHOTO_RIGHT := 4
const LOOK_PHOTO_SPLIT := 5
const PHOTO_A_PATH := "user://kit/photo_a.png"
const PHOTO_B_PATH := "user://kit/photo_b.png"
const SLOT_COUNT := 4
static var active_slot := 0

const PALETTES := [
	{"id": "club", "name": "Club red", "a": Color("#e12a32"), "b": Color("#fff6f0")},
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
	{"id": "club", "name": "CLUB", "look": LOOK_SPLIT},
	{"id": "split", "name": "HALF / HALF", "look": LOOK_SPLIT},
	{"id": "both", "name": "SOLID", "look": LOOK_BOTH},
	{"id": "camo", "name": "WOODLAND", "look": LOOK_GRAPHIC},
	{"id": "arctic", "name": "ARCTIC", "look": LOOK_GRAPHIC},
	{"id": "desert", "name": "DESERT", "look": LOOK_GRAPHIC},
	{"id": "digital", "name": "DIGITAL", "look": LOOK_GRAPHIC},
	{"id": "urban", "name": "URBAN", "look": LOOK_GRAPHIC},
	{"id": "carbon", "name": "CARBON", "look": LOOK_GRAPHIC},
	{"id": "marble", "name": "MARBLE", "look": LOOK_GRAPHIC},
	{"id": "metal", "name": "METAL", "look": LOOK_GRAPHIC},
	{"id": "flame", "name": "FLAME", "look": LOOK_GRAPHIC},
	{"id": "galaxy", "name": "GALAXY", "look": LOOK_GRAPHIC},
	{"id": "photo_left", "name": "LEFT FACE", "look": LOOK_PHOTO_LEFT},
	{"id": "photo_right", "name": "RIGHT FACE", "look": LOOK_PHOTO_RIGHT},
	{"id": "photo_both", "name": "BOTH FACES", "look": LOOK_PHOTO_SPLIT},
	{"id": "photo_split", "name": "ONE EACH", "look": LOOK_PHOTO_SPLIT},
	{"id": "photo_wrap", "name": "FULL WRAP", "look": LOOK_GRAPHIC},
]

const PHOTO_SKINS := ["photo_left", "photo_right", "photo_both", "photo_split", "photo_wrap"]
const THEME_SKINS := ["club", "split", "both", "camo", "arctic", "desert", "digital", "urban", "carbon", "marble", "metal", "flame", "galaxy"]

const WRAPS := {
	"camo": "res://assets/wraps/woodland.png",
	"arctic": "res://assets/wraps/arctic.png",
	"desert": "res://assets/wraps/desert.png",
	"digital": "res://assets/wraps/digital.png",
	"urban": "res://assets/wraps/urban.png",
	"carbon": "res://assets/wraps/carbon.png",
	"marble": "res://assets/wraps/marble.png",
	"metal": "res://assets/wraps/metal.png",
}

static var _graphic_cache := {}
static var _preview_cache := {}


static func default_kit() -> Dictionary:
	return {
		"bowl_skin": "club",
		"bowl_color": 1,
		"disc_skin": "club",
		"disc_color": 0,
		"photo_a": "",
		"photo_b": "",
		"bowl_slot": 0,
	}


static func is_photo_skin(skin_id: String) -> bool:
	return skin_id in PHOTO_SKINS


static func is_theme_skin(skin_id: String) -> bool:
	return skin_id in THEME_SKINS


static func uses_custom_bowl(kit: Dictionary) -> bool:
	var skin_id := str(kit.get("bowl_skin", "club"))
	return skin_id != "club" and skin_id != "standard"


static func uses_custom_disc(kit: Dictionary) -> bool:
	var skin_id := str(kit.get("disc_skin", "club"))
	return skin_id != "club" and skin_id != "standard"


static func palette(index: int) -> Dictionary:
	return PALETTES[clampi(index, 0, PALETTES.size() - 1)]


static func skin(skin_id: String) -> Dictionary:
	var wanted := skin_id
	if wanted == "photo":
		wanted = "photo_left"
	for item in SKINS:
		if str(item["id"]) == wanted:
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
	active_slot = int(out.get("bowl_slot", 0))
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
	if opponent or not uses_custom_bowl(kit):
		_paint_tree(holder, kit, true)
		return
	_paint_tree(holder, kit, false)


static func _paint_tree(node: Node, kit: Dictionary, opponent: bool) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if opponent:
			mi.material_override = null
		else:
			_paint_mesh(mi, kit, false)
	for child in node.get_children():
		_paint_tree(child, kit, opponent)


static func paint_disc(mi: MeshInstance3D, kit: Dictionary) -> void:
	if mi == null:
		return
	if not uses_custom_disc(kit):
		mi.material_override = null
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
	mat.set_shader_parameter("seam", 0.02)
	var skin_id := str(look_info["id"])
	var graphic := graphic_texture(skin_id, pal["a"], pal["b"], kit)
	mat.set_shader_parameter("graphic_tex", graphic)
	var graphic_b := graphic_texture_b(skin_id, pal["a"], pal["b"], kit)
	mat.set_shader_parameter("graphic_tex_b", graphic_b if graphic_b != null else graphic)
	mat.set_shader_parameter("graphic_mix", 1.0)
	mat.set_shader_parameter("graphic_scale", _wrap_scale(skin_id))
	if not for_disc:
		mat.set_shader_parameter("roughness_val", _wrap_roughness(skin_id))
		mat.set_shader_parameter("metallic_val", _wrap_metal(skin_id))
		if mi.has_meta("pole_axis"):
			mat.set_shader_parameter("pole_axis", mi.get_meta("pole_axis"))
		if mi.has_meta("mesh_center"):
			mat.set_shader_parameter("mesh_center", mi.get_meta("mesh_center"))
		if mi.has_meta("pole_half"):
			mat.set_shader_parameter("pole_half", mi.get_meta("pole_half"))
		if mi.has_meta("groove_inner"):
			mat.set_shader_parameter("groove_inner", mi.get_meta("groove_inner"))
		var up := Vector3.UP
		var xf: Transform3D = mi.global_transform
		var inv := xf.basis.inverse()
		up = (inv * Vector3.UP).normalized()
		mat.set_shader_parameter("face_up", up)
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


static func graphic_texture(skin_id: String, color_a: Color, color_b: Color, kit: Dictionary = {}) -> Texture2D:
	if is_photo_skin(skin_id):
		var slot := "a"
		if skin_id == "photo_right":
			slot = "a"
		var tex := load_user_photo(slot)
		if tex == null and skin_id == "photo_wrap":
			tex = load_user_photo("a")
		if tex != null:
			return tex
		return ImageTexture.create_from_image(_demo_face())
	if WRAPS.has(skin_id):
		var wrap_key := "wrap_%s" % skin_id
		if _graphic_cache.has(wrap_key):
			return _graphic_cache[wrap_key]
		var wrap: Texture2D = load(str(WRAPS[skin_id]))
		if wrap != null:
			_graphic_cache[wrap_key] = wrap
			return wrap
	var key := "%s_%s_%s" % [skin_id, color_a.to_html(false), color_b.to_html(false)]
	if _graphic_cache.has(key):
		return _graphic_cache[key]
	var image: Image
	match skin_id:
		"flame":
			image = _flame(color_a)
		"galaxy":
			image = _galaxy()
		_:
			image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
			image.fill(Color(1, 1, 1, 0))
	var baked := ImageTexture.create_from_image(image)
	_graphic_cache[key] = baked
	return baked


static func graphic_texture_b(skin_id: String, color_a: Color, color_b: Color, kit: Dictionary = {}) -> Texture2D:
	if skin_id == "photo_split":
		var tex := load_user_photo("b")
		if tex != null:
			return tex
		return ImageTexture.create_from_image(_demo_dog())
	if skin_id == "photo_both" or skin_id == "photo_left" or skin_id == "photo_right" or skin_id == "photo_wrap":
		return graphic_texture(skin_id, color_a, color_b, kit)
	return graphic_texture(skin_id, color_a, color_b, kit)


static func face_path(side: String, slot: int = -1) -> String:
	var n := active_slot if slot < 0 else slot
	var letter := "b" if side == "b" else "a"
	return "user://kit/s%d_%s.png" % [n, letter]


static func load_user_photo(slot: String) -> Texture2D:
	_migrate_legacy_photos()
	var path := face_path(slot)
	if not FileAccess.file_exists(path):
		path = PHOTO_A_PATH if slot != "b" else PHOTO_B_PATH
	var cache_key := "user_%s_%s_%s" % [str(active_slot), slot, str(FileAccess.get_modified_time(path))]
	if _graphic_cache.has(cache_key):
		return _graphic_cache[cache_key]
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(image)
	_graphic_cache[cache_key] = tex
	return tex


static func save_user_photo(slot: String, image: Image, kit_slot: int = -1) -> String:
	if image == null:
		return ""
	var copy := image.duplicate() as Image
	if copy.is_compressed():
		copy.decompress()
	copy.convert(Image.FORMAT_RGBA8)
	var wide := copy.get_width()
	var high := copy.get_height()
	var side := mini(wide, high)
	if side > 512:
		var scale := 512.0 / float(side)
		copy.resize(maxi(1, int(round(float(wide) * scale))), maxi(1, int(round(float(high) * scale))), Image.INTERPOLATE_LANCZOS)
		wide = copy.get_width()
		high = copy.get_height()
		side = mini(wide, high)
	if wide != high:
		var x := (wide - side) / 2
		var y := (high - side) / 2
		copy = copy.get_region(Rect2i(x, y, side, side))
	DirAccess.make_dir_recursive_absolute("user://kit")
	var path := face_path(slot, kit_slot)
	copy.save_png(path)
	_graphic_cache.clear()
	_preview_cache.clear()
	return path


static func has_user_photo(slot: String) -> bool:
	_migrate_legacy_photos()
	return FileAccess.file_exists(face_path(slot)) or FileAccess.file_exists(PHOTO_A_PATH if slot != "b" else PHOTO_B_PATH)


static func _migrate_legacy_photos() -> void:
	DirAccess.make_dir_recursive_absolute("user://kit")
	if FileAccess.file_exists(PHOTO_A_PATH) and not FileAccess.file_exists(face_path("a", 0)):
		DirAccess.copy_absolute(PHOTO_A_PATH, face_path("a", 0))
	if FileAccess.file_exists(PHOTO_B_PATH) and not FileAccess.file_exists(face_path("b", 0)):
		DirAccess.copy_absolute(PHOTO_B_PATH, face_path("b", 0))


static func seed_demo_photos() -> void:
	save_user_photo("a", _demo_face())
	save_user_photo("b", _demo_dog())


static func _wrap_scale(skin_id: String) -> float:
	match skin_id:
		"camo", "arctic", "desert", "urban", "digital":
			return 2.2
		"carbon":
			return 3.4
		"marble", "metal":
			return 1.6
		_:
			return 1.0


static func _wrap_roughness(skin_id: String) -> float:
	match skin_id:
		"carbon", "metal":
			return 0.26
		"marble":
			return 0.20
		_:
			return 0.42


static func _wrap_metal(skin_id: String) -> float:
	match skin_id:
		"carbon":
			return 0.62
		"metal":
			return 0.78
		_:
			return 0.04


static func preview(kit: Dictionary, for_disc: bool) -> Texture2D:
	var pal := palette(int(kit.get("disc_color" if for_disc else "bowl_color", 0)))
	var skin_id := str(kit.get("disc_skin" if for_disc else "bowl_skin", "split"))
	var color_a: Color = pal["a"]
	var color_b: Color = pal["b"]
	var key := "%s_%s_%s_%s_%s_%s_%s" % [
		skin_id,
		color_a.to_html(false),
		color_b.to_html(false),
		for_disc,
		str(active_slot),
		str(FileAccess.get_modified_time(face_path("a"))),
		str(FileAccess.get_modified_time(face_path("b"))),
	]
	if _preview_cache.has(key):
		return _preview_cache[key]
	var look_info := skin(skin_id)
	var graphic := graphic_texture(skin_id, pal["a"], pal["b"], kit)
	var graphic_b := graphic_texture_b(skin_id, pal["a"], pal["b"], kit)
	var gimg: Image = graphic.get_image() if graphic != null else null
	var gimg_b: Image = graphic_b.get_image() if graphic_b != null else gimg
	if gimg != null and gimg.is_compressed():
		gimg.decompress()
	if gimg_b != null and gimg_b.is_compressed():
		gimg_b.decompress()
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
			if skin_id == "club":
				col = color_a
			elif look == LOOK_SPLIT:
				col = color_a.lerp(color_b, side)
			elif look == LOOK_BOTH:
				col = color_a
			else:
				if gimg != null:
					var u := clampf(0.5 + nx * 0.52, 0.0, 1.0)
					var v := clampf(0.5 + ny * 0.52, 0.0, 1.0)
					if look == LOOK_GRAPHIC:
						u = 0.5 + atan2(nx, nz) / TAU
						v = 0.5 - ny * 0.5
					if for_disc:
						u = clampf(0.5 + nx * 0.5, 0.0, 1.0)
						v = clampf(0.5 + ny * 0.5, 0.0, 1.0)
					var sample := _sample_image(gimg, u, v)
					var sample_b := _sample_image(gimg_b if gimg_b != null else gimg, u, v)
					if look == LOOK_PHOTO_LEFT:
						col = color_a.lerp(sample, (1.0 - side) * sample.a)
					elif look == LOOK_PHOTO_RIGHT:
						col = color_a.lerp(sample, side * sample.a)
					elif look == LOOK_PHOTO_SPLIT:
						var left := color_a.lerp(sample, sample.a)
						var right := color_a.lerp(sample_b, sample_b.a)
						col = left.lerp(right, side)
					else:
						col = sample if sample.a > 0.12 else color_a
			if for_disc and r2 < 0.08:
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


static func _sample_image(image: Image, u: float, v: float) -> Color:
	if image == null:
		return Color(1, 1, 1, 0)
	var sx := clampi(int(clampf(u, 0.0, 1.0) * float(image.get_width() - 1)), 0, image.get_width() - 1)
	var sy := clampi(int(clampf(v, 0.0, 1.0) * float(image.get_height() - 1)), 0, image.get_height() - 1)
	return image.get_pixel(sx, sy)


static func _demo_face() -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx := float(size) * 0.5
	var cy := float(size) * 0.48
	for y in size:
		for x in size:
			var dx := (float(x) + 0.5 - cx) / (float(size) * 0.42)
			var dy := (float(y) + 0.5 - cy) / (float(size) * 0.48)
			var r := sqrt(dx * dx + dy * dy)
			if r > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var skin := Color(0.93, 0.74, 0.58)
			var shade := clampf(0.88 + dx * 0.12 - dy * 0.08, 0.7, 1.1)
			var col := Color(skin.r * shade, skin.g * shade, skin.b * shade, 1.0)
			var eye_l := Vector2(dx + 0.28, dy + 0.12)
			var eye_r := Vector2(dx - 0.28, dy + 0.12)
			if eye_l.length() < 0.12 or eye_r.length() < 0.12:
				col = Color(0.12, 0.14, 0.18, 1.0)
			var mouth := absf(dy - 0.28) + absf(dx) * 0.45
			if dy > 0.18 and mouth < 0.12:
				col = Color(0.72, 0.28, 0.32, 1.0)
			img.set_pixel(x, y, col)
	return img


static func _demo_dog() -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx := float(size) * 0.5
	var cy := float(size) * 0.52
	for y in size:
		for x in size:
			var dx := (float(x) + 0.5 - cx) / (float(size) * 0.42)
			var dy := (float(y) + 0.5 - cy) / (float(size) * 0.42)
			var r := sqrt(dx * dx + dy * dy)
			var ear := minf(Vector2(dx + 0.62, dy + 0.55).length() / 0.38, Vector2(dx - 0.62, dy + 0.55).length() / 0.38)
			if r > 1.0 and ear > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var fur := Color(0.72, 0.48, 0.22)
			if ear <= 1.0 and r > 0.92:
				fur = Color(0.42, 0.24, 0.10)
			var col := fur
			if Vector2(dx + 0.22, dy + 0.08).length() < 0.11 or Vector2(dx - 0.22, dy + 0.08).length() < 0.11:
				col = Color(0.08, 0.08, 0.08, 1.0)
			if Vector2(dx, dy - 0.08).length() < 0.14:
				col = Color(0.18, 0.12, 0.08, 1.0)
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
