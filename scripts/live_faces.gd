class_name LiveFaces
extends RefCounted

## Club portraits for Live Game. You pick a face. AI rivals are named.

const FACE_COLORS: Array[Color] = [
	Color("#F5C84B"),
	Color("#E12A32"),
	Color("#1C6CFF"),
	Color("#7A3DFF"),
	Color("#5AD4EA"),
	Color("#2DBE6C"),
	Color("#E07A2A"),
	Color("#F4F7FF"),
]

const RIVALS := [
	{"name": "Marlow", "mark": "MA", "skill": 0, "color": 1},
	{"name": "Vesper", "mark": "VE", "skill": 1, "color": 2},
	{"name": "Nash", "mark": "NA", "skill": 1, "color": 0},
	{"name": "Sable", "mark": "SA", "skill": 2, "color": 3},
	{"name": "Quinn", "mark": "QU", "skill": 0, "color": 4},
	{"name": "Rook", "mark": "RO", "skill": 2, "color": 7},
	{"name": "Ivy", "mark": "IV", "skill": 1, "color": 5},
	{"name": "Holt", "mark": "HO", "skill": 2, "color": 6},
]


static func color_at(index: int) -> Color:
	return FACE_COLORS[clampi(index, 0, FACE_COLORS.size() - 1)]


static func ink_for(fill: Color) -> Color:
	var luma := fill.r * 0.3 + fill.g * 0.6 + fill.b * 0.1
	if luma > 0.55:
		return Color("#07101C")
	return Color("#F4F7FF")


static func rival_at(index: int) -> Dictionary:
	return RIVALS[clampi(index, 0, RIVALS.size() - 1)]


static func random_rival() -> Dictionary:
	return RIVALS[randi() % RIVALS.size()]


static func photo_path() -> String:
	return "user://live_face.png"


static func load_photo() -> Texture2D:
	if not FileAccess.file_exists(photo_path()):
		return null
	var img := Image.new()
	if img.load(photo_path()) != OK:
		return null
	return ImageTexture.create_from_image(img)


static func save_photo(image: Image) -> void:
	if image == null:
		return
	var copy := image.duplicate()
	if copy.get_width() > 512 or copy.get_height() > 512:
		copy.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	copy.save_png(photo_path())
