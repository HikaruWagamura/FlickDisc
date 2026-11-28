extends VBoxContainer

## Chameleon-style bowl studio. Four slots, draw or upload on either face.

signal kit_changed

const Kit := preload("res://scripts/kit.gd")
const FONT_ANTON := preload("res://assets/fonts/Anton-Regular.ttf")
const FONT_INTER := preload("res://assets/fonts/Inter-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/Inter-Bold.ttf")

const GOLD := Color("#F5C84B")
const BLUE_LIT := Color("#2A7BFF")
const PLUM := Color(0.08, 0.16, 0.34, 0.96)
const MUTED := Color("#A9C6EA")
const CREAM := Color("#F4F7FF")
const FACE := 256

const INKS := [
	Color("#121214"),
	Color("#fff6f0"),
	Color("#ff3d9a"),
	Color("#c41018"),
	Color("#d4a017"),
	Color("#5ad4ea"),
	Color("#2f4ad8"),
	Color("#7a3dff"),
	Color("#1f6b3a"),
	Color("#e85a12"),
]

const BRUSHES := [6, 14, 28]
const PLACES := [
	{"id": "left", "name": "LEFT", "skin": "photo_left"},
	{"id": "right", "name": "RIGHT", "skin": "photo_right"},
	{"id": "both", "name": "BOTH", "skin": "photo_both"},
	{"id": "split", "name": "EACH", "skin": "photo_split"},
	{"id": "wrap", "name": "WRAP", "skin": "photo_wrap"},
]

var profile
var slot_index := 0
var face := "a"
var tool := "draw"
var ink := Color("#121214")
var brush := 14
var place := "left"
var coverage := "whole"
var picked_theme := "both"
var canvas_a: Image
var canvas_b: Image
var drawing := false
var last_pt := Vector2(-1, -1)
var face_view: TextureRect
var face_tex: ImageTexture
var face_view_b: TextureRect
var face_tex_b: ImageTexture
var preview_bowl: TextureRect
var preview_bowl_b: TextureRect
var caption: Label
var look_box: VBoxContainer
var hero_row: HBoxContainer
var pads_row: HBoxContainer
var draw_block: VBoxContainer
var draw_toggle: Button
var draw_open := false
var face_row: Control
var slot_buttons: Array = []
var tool_buttons: Array = []
var size_buttons: Array = []
var ink_buttons: Array = []
var place_buttons: Array = []
var face_buttons: Array = []
var cover_buttons: Array = []
var photo_picker: FileDialog
var upload_button: Button
var copy_button: Button
var stamp_buttons: Array = []


func setup(player_profile) -> void:
	profile = player_profile
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	slot_index = int(profile.bowl_slot)
	Kit.active_slot = slot_index
	_load_canvases()
	_build()
	coverage = _coverage_from_skin(str(profile.bowl_skin))
	refresh()


func refresh() -> void:
	if profile == null:
		return
	slot_index = clampi(int(profile.bowl_slot), 0, Kit.SLOT_COUNT - 1)
	Kit.active_slot = slot_index
	_load_canvases()
	_paint()


func pick_slot(index: int) -> void:
	_save_current_slot()
	slot_index = clampi(index, 0, Kit.SLOT_COUNT - 1)
	profile.bowl_slot = slot_index
	profile.bowl_skin = profile.slot_skin(slot_index)
	profile.bowl_color = profile.slot_color(slot_index)
	Kit.active_slot = slot_index
	profile.save_profile()
	coverage = _coverage_from_skin(str(profile.bowl_skin))
	_load_canvases()
	_commit()


func pick_place(id: String) -> void:
	place = id
	if id == "right" or id == "split" or id == "both":
		coverage = "half"
		if id == "right":
			face = "b"
		else:
			face = "a"
	elif id == "wrap":
		coverage = "whole"
		face = "a"
	elif id == "left":
		face = "a"
	_apply_place_skin()
	_paint()
	_commit()


func apply_theme(skin_id: String) -> void:
	picked_theme = skin_id
	if coverage == "half" and not Kit.is_photo_skin(skin_id) and skin_id != "split" and skin_id != "club" and skin_id != "both":
		var pal: Dictionary = Kit.palette(profile.bowl_color)
		var baked := Kit.theme_face(skin_id, pal)
		if baked != null:
			if face == "b":
				canvas_b = baked
			else:
				canvas_a = baked
			place = "split"
			_save_canvases()
			_apply_place_skin()
			_commit()
			return
	profile.bowl_skin = skin_id
	profile.set_slot(slot_index, skin_id, profile.bowl_color)
	if skin_id == "split" or Kit.is_photo_skin(skin_id):
		coverage = "half"
	elif skin_id == "both" or int(Kit.skin(skin_id).get("look", 0)) == Kit.LOOK_GRAPHIC:
		coverage = "whole"
	_commit()


func set_coverage(mode: String) -> void:
	coverage = "half" if mode == "half" else "whole"
	if coverage == "whole":
		place = "wrap"
		face = "a"
		var keep := picked_theme
		if keep == "" or keep == "split" or keep == "club" or Kit.is_photo_skin(keep):
			keep = "both"
		profile.bowl_skin = keep
		profile.set_slot(slot_index, keep, profile.bowl_color)
	else:
		place = "split"
		face = "a"
		_prepare_half()
	_paint()
	_commit()


func _coverage_from_skin(skin_id: String) -> String:
	if Kit.is_photo_skin(skin_id) or skin_id == "split":
		return "half"
	return "whole"


func _prepare_half() -> void:
	var skin_id := str(profile.bowl_skin)
	var look := int(Kit.skin(skin_id).get("look", Kit.LOOK_SPLIT))
	if look == Kit.LOOK_GRAPHIC:
		var pal: Dictionary = Kit.palette(profile.bowl_color)
		var baked := Kit.theme_face(skin_id, pal)
		if baked != null:
			canvas_a = baked
			canvas_b = _blank()
			_fill_disc(canvas_b, pal["b"])
			_save_canvases()
			profile.bowl_skin = "photo_split"
			profile.set_slot(slot_index, "photo_split", profile.bowl_color)
			return
	if skin_id == "both":
		profile.bowl_skin = "split"
		profile.set_slot(slot_index, "split", profile.bowl_color)


func apply_photo(image: Image) -> void:
	if image == null:
		return
	var cropped := _square(image)
	if place == "both":
		canvas_a = cropped.duplicate() as Image
		canvas_b = cropped.duplicate() as Image
		_save_canvases()
	elif place == "wrap":
		canvas_a = cropped.duplicate() as Image
		Kit.save_user_photo("a", canvas_a, slot_index)
	elif face == "b":
		canvas_b = cropped
		Kit.save_user_photo("b", canvas_b, slot_index)
	else:
		canvas_a = cropped
		Kit.save_user_photo("a", canvas_a, slot_index)
	_apply_place_skin()
	_commit()


func demo_paint() -> void:
	pick_slot(1)
	place = "split"
	face = "a"
	tool = "draw"
	ink = Color("#121214")
	brush = 14
	draw_open = true
	coverage = "half"
	canvas_a = _blank()
	_stamp_smile(canvas_a, Color("#fff4e8"), Color("#121214"), Color("#c41018"))
	canvas_b = Kit._demo_dog()
	_apply_place_skin()
	_save_canvases()
	_commit()


func _build() -> void:
	add_child(_kicker("YOUR PRESETS"))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	add_child(slots)
	for i in Kit.SLOT_COUNT:
		var button := _button("SLOT %d" % (i + 1), 12)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(func() -> void: pick_slot(i))
		slots.add_child(button)
		slot_buttons.append(button)
	caption = _wrapped("SLOT 1  ·  WHOLE BOWL")
	add_child(caption)
	add_child(_kicker("COVER THE BOWL"))
	var cover := HBoxContainer.new()
	cover.add_theme_constant_override("separation", 8)
	add_child(cover)
	for item in [{"id": "whole", "name": "WHOLE BOWL"}, {"id": "half", "name": "HALF AND HALF"}]:
		var chip := _button(str(item["name"]), 14)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 42)
		chip.set_meta("cover_id", str(item["id"]))
		chip.pressed.connect(func() -> void: set_coverage(str(item["id"])))
		cover.add_child(chip)
		cover_buttons.append(chip)
	hero_row = HBoxContainer.new()
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_theme_constant_override("separation", 18)
	add_child(hero_row)
	preview_bowl = _bowl_view(112)
	hero_row.add_child(preview_bowl)
	preview_bowl_b = _bowl_view(168)
	preview_bowl_b.visible = false
	hero_row.add_child(preview_bowl_b)
	look_box = VBoxContainer.new()
	look_box.add_theme_constant_override("separation", 8)
	add_child(look_box)
	draw_toggle = _button("PAINT THIS FACE", 14)
	draw_toggle.custom_minimum_size = Vector2(0, 48)
	draw_toggle.pressed.connect(func() -> void:
		draw_open = not draw_open
		_paint()
	)
	add_child(draw_toggle)
	draw_block = VBoxContainer.new()
	draw_block.add_theme_constant_override("separation", 8)
	draw_block.visible = false
	add_child(draw_block)
	face_row = HBoxContainer.new()
	face_row.add_theme_constant_override("separation", 6)
	draw_block.add_child(face_row)
	for item in [{"id": "a", "name": "LEFT FACE"}, {"id": "b", "name": "RIGHT FACE"}]:
		var chip := _button(str(item["name"]), 11)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 34)
		chip.pressed.connect(func() -> void:
			face = str(item["id"])
			if face == "b" and place == "left":
				place = "right"
			elif face == "a" and place == "right":
				place = "left"
			_paint()
		)
		face_row.add_child(chip)
		face_buttons.append(chip)
	pads_row = HBoxContainer.new()
	pads_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pads_row.add_theme_constant_override("separation", 14)
	draw_block.add_child(pads_row)
	face_view = _pad_view(168)
	face_view.gui_input.connect(func(event: InputEvent) -> void: _on_pad_side(event, "a"))
	pads_row.add_child(face_view)
	face_tex = ImageTexture.new()
	face_view_b = _pad_view(168)
	face_view_b.gui_input.connect(func(event: InputEvent) -> void: _on_pad_side(event, "b"))
	pads_row.add_child(face_view_b)
	face_tex_b = ImageTexture.new()
	draw_block.add_child(_kicker("DRAW"))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	draw_block.add_child(tools)
	for item in [{"id": "draw", "name": "DRAW"}, {"id": "erase", "name": "ERASE"}, {"id": "fill", "name": "FILL"}, {"id": "clear", "name": "CLEAR"}]:
		var chip := _button(str(item["name"]), 12)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 42)
		chip.pressed.connect(func() -> void: _pick_tool(str(item["id"])))
		tools.add_child(chip)
		tool_buttons.append(chip)
	var place_block := VBoxContainer.new()
	place_block.visible = false
	add_child(place_block)
	place_block.add_child(_kicker("PLACE ON"))
	var place_row := GridContainer.new()
	place_row.columns = 5
	place_row.add_theme_constant_override("h_separation", 6)
	place_row.add_theme_constant_override("v_separation", 6)
	place_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_block.add_child(place_row)
	for item in PLACES:
		var chip := _button(str(item["name"]), 10)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 40)
		chip.set_meta("place_id", str(item["id"]))
		chip.pressed.connect(func() -> void: pick_place(str(item["id"])))
		place_row.add_child(chip)
		place_buttons.append(chip)
	var stamps := HBoxContainer.new()
	stamps.add_theme_constant_override("separation", 6)
	draw_block.add_child(stamps)
	for item in [{"id": "smile", "name": "SMILE"}, {"id": "star", "name": "STAR"}, {"id": "heart", "name": "HEART"}, {"id": "ring", "name": "RING"}]:
		var chip := _button(str(item["name"]), 11)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 40)
		chip.pressed.connect(func() -> void: _stamp_preset(str(item["id"])))
		stamps.add_child(chip)
		stamp_buttons.append(chip)
	draw_block.add_child(_kicker("INK"))
	var inks := HBoxContainer.new()
	inks.add_theme_constant_override("separation", 6)
	inks.alignment = BoxContainer.ALIGNMENT_CENTER
	draw_block.add_child(inks)
	for color in INKS:
		var swatch := Button.new()
		swatch.text = ""
		swatch.custom_minimum_size = Vector2(40, 40)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		swatch.pressed.connect(func() -> void:
			ink = color
			if tool == "erase":
				tool = "draw"
			_paint()
		)
		inks.add_child(swatch)
		ink_buttons.append(swatch)
	draw_block.add_child(_kicker("BRUSH"))
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 6)
	draw_block.add_child(sizes)
	for i in BRUSHES.size():
		var names := ["S", "M", "L"]
		var chip := _button(names[i], 13)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 40)
		chip.pressed.connect(func() -> void:
			brush = BRUSHES[i]
			_paint()
		)
		sizes.add_child(chip)
		size_buttons.append(chip)
	draw_block.add_child(_kicker("PHOTO"))
	var photos := HBoxContainer.new()
	photos.add_theme_constant_override("separation", 8)
	draw_block.add_child(photos)
	upload_button = _button("UPLOAD TO THIS FACE", 12)
	upload_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upload_button.custom_minimum_size = Vector2(0, 48)
	upload_button.pressed.connect(_pick_photo)
	photos.add_child(upload_button)
	copy_button = _button("COPY TO OTHER FACE", 12)
	copy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_button.custom_minimum_size = Vector2(0, 48)
	copy_button.pressed.connect(_copy_face)
	photos.add_child(copy_button)
	_build_photo_picker()


func _pick_tool(id: String) -> void:
	if id == "clear":
		_clear_face()
		return
	if id == "fill":
		_fill_face()
		return
	tool = id
	_paint()


func _on_pad_side(event: InputEvent, side: String) -> void:
	face = side
	if side == "b" and coverage == "half" and place == "left":
		place = "right"
	elif side == "a" and coverage == "half" and place == "right":
		place = "left"
	_on_pad(event)


func _on_pad(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			drawing = true
			last_pt = Vector2(-1, -1)
			_stroke(_pad_point(touch.position))
		else:
			drawing = false
			_save_canvases()
			_commit()
		return
	if event is InputEventScreenDrag:
		_stroke(_pad_point((event as InputEventScreenDrag).position))
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		drawing = mouse.pressed
		if drawing:
			last_pt = Vector2(-1, -1)
			_stroke(_pad_point(mouse.position))
		else:
			_save_canvases()
			_commit()
		return
	if event is InputEventMouseMotion and drawing:
		_stroke(_pad_point((event as InputEventMouseMotion).position))


func _pad_point(local: Vector2) -> Vector2:
	var view := face_view_b if face == "b" and face_view_b != null else face_view
	var box := view.size
	if box.x < 8.0 or box.y < 8.0:
		box = view.custom_minimum_size
	return Vector2(local.x / box.x * float(FACE), local.y / box.y * float(FACE))


func _stroke(pt: Vector2) -> void:
	var img := _active_canvas()
	if tool == "erase":
		_brush_stamp(img, pt, Color(0, 0, 0, 0), true)
	else:
		_brush_stamp(img, pt, ink, false)
	if last_pt.x >= 0.0:
		var steps := int(ceil(pt.distance_to(last_pt) / maxf(2.0, float(brush) * 0.35)))
		for i in range(1, steps):
			var mid := last_pt.lerp(pt, float(i) / float(steps))
			if tool == "erase":
				_brush_stamp(img, mid, Color(0, 0, 0, 0), true)
			else:
				_brush_stamp(img, mid, ink, false)
	last_pt = pt
	_mirror_if_needed()
	_refresh_pad()


func _brush_stamp(img: Image, pt: Vector2, col: Color, erase: bool) -> void:
	var radius := brush
	var r2 := radius * radius
	var x0 := maxi(0, int(pt.x) - radius)
	var y0 := maxi(0, int(pt.y) - radius)
	var x1 := mini(FACE - 1, int(pt.x) + radius)
	var y1 := mini(FACE - 1, int(pt.y) + radius)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x - pt.x
			var dy := y - pt.y
			if dx * dx + dy * dy > float(r2):
				continue
			var nx := (float(x) + 0.5) / float(FACE) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(FACE) * 2.0 - 1.0
			if nx * nx + ny * ny > 1.02:
				continue
			if erase:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, col)


func _fill_face() -> void:
	var img := _active_canvas()
	for y in FACE:
		for x in FACE:
			var nx := (float(x) + 0.5) / float(FACE) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(FACE) * 2.0 - 1.0
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, ink)
	_mirror_if_needed()
	_save_canvases()
	_apply_place_skin()
	_commit()


func _clear_face() -> void:
	if place == "both":
		canvas_a = _blank()
		canvas_b = _blank()
	elif face == "b":
		canvas_b = _blank()
	else:
		canvas_a = _blank()
	_save_canvases()
	_apply_place_skin()
	_commit()


func _stamp_preset(kind: String) -> void:
	var img := _active_canvas()
	match kind:
		"smile":
			_stamp_smile(img, ink.lightened(0.55), ink, Color("#c41018"))
		"star":
			_stamp_star(img, ink)
		"heart":
			_stamp_heart(img, Color("#ff3d9a") if ink.is_equal_approx(Color("#121214")) else ink)
		"ring":
			_stamp_ring(img, ink)
	_mirror_if_needed()
	_save_canvases()
	_apply_place_skin()
	_commit()


func _copy_face() -> void:
	if face == "b":
		canvas_a = canvas_b.duplicate() as Image
	else:
		canvas_b = canvas_a.duplicate() as Image
	place = "both"
	_save_canvases()
	_apply_place_skin()
	_commit()


func _pick_photo() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show(
			"Choose a photo",
			OS.get_system_dir(OS.SYSTEM_DIR_PICTURES),
			"",
			false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Photos"]),
			func(status: bool, selected_paths: PackedStringArray, _filter_index: int) -> void:
				if status and not selected_paths.is_empty():
					_on_photo_picked(selected_paths[0])
		)
		return
	_build_photo_picker()
	if photo_picker != null:
		photo_picker.popup_centered()


func _build_photo_picker() -> void:
	if photo_picker != null:
		return
	photo_picker = FileDialog.new()
	photo_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	photo_picker.access = FileDialog.ACCESS_FILESYSTEM
	photo_picker.title = "Choose a photo"
	photo_picker.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Photos"])
	photo_picker.use_native_dialog = true
	photo_picker.size = Vector2i(720, 520)
	photo_picker.visible = false
	photo_picker.file_selected.connect(_on_photo_picked)
	add_child(photo_picker)


func _on_photo_picked(path: String) -> void:
	var image := Image.new()
	if image.load(path) != OK:
		return
	apply_photo(image)


func _active_canvas() -> Image:
	if face == "b":
		if canvas_b == null:
			canvas_b = _blank()
		return canvas_b
	if canvas_a == null:
		canvas_a = _blank()
	return canvas_a


func _mirror_if_needed() -> void:
	if place != "both":
		return
	if face == "b":
		canvas_a = canvas_b.duplicate() as Image
	else:
		canvas_b = canvas_a.duplicate() as Image


func _load_canvases() -> void:
	canvas_a = _load_face("a")
	canvas_b = _load_face("b")


func _load_face(side: String) -> Image:
	var path := Kit.face_path(side, slot_index)
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			if image.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			if image.get_width() != FACE or image.get_height() != FACE:
				image.resize(FACE, FACE, Image.INTERPOLATE_LANCZOS)
			return image
	return _blank()


func _save_canvases() -> void:
	if canvas_a != null:
		Kit.save_user_photo("a", canvas_a, slot_index)
	if canvas_b != null:
		Kit.save_user_photo("b", canvas_b, slot_index)


func _save_current_slot() -> void:
	if profile == null:
		return
	profile.set_slot(slot_index, profile.bowl_skin, profile.bowl_color)


func _apply_place_skin() -> void:
	var skin_id := "photo_left"
	match place:
		"right":
			skin_id = "photo_right"
		"both":
			skin_id = "photo_both"
		"split":
			skin_id = "photo_split"
		"wrap":
			skin_id = "photo_wrap"
		_:
			skin_id = "photo_left"
	var has_a := _has_ink(canvas_a)
	var has_b := _has_ink(canvas_b)
	if place == "left" or place == "right":
		if has_a and has_b:
			skin_id = "photo_split"
		elif has_b and not has_a:
			skin_id = "photo_right"
		elif has_a and not has_b:
			skin_id = "photo_left"
	profile.bowl_skin = skin_id
	profile.set_slot(slot_index, skin_id, profile.bowl_color)
	profile.bowl_slot = slot_index


func _commit() -> void:
	if profile != null:
		profile.save_profile()
	Kit.active_slot = slot_index
	var tree := get_tree()
	if tree != null:
		tree.root.set_meta("flickdisc_kit", profile.kit())
	_paint()
	kit_changed.emit()


func _paint() -> void:
	_sync_coverage_layout()
	_refresh_pad()
	if preview_bowl != null and profile != null:
		preview_bowl.texture = Kit.preview(_face_kit("a"), false)
	if preview_bowl_b != null and profile != null:
		preview_bowl_b.texture = Kit.preview(_face_kit("b"), false)
	if caption != null:
		var cover_name := "HALF AND HALF" if coverage == "half" else "WHOLE BOWL"
		if coverage == "half":
			var face_name := "RIGHT FACE" if face == "b" else "LEFT FACE"
			caption.text = "SLOT %d  ·  %s  ·  %s" % [slot_index + 1, cover_name, face_name]
		else:
			caption.text = "SLOT %d  ·  WHOLE BOWL  ·  this is your match bowl" % (slot_index + 1)
	for i in slot_buttons.size():
		var on: bool = i == slot_index
		_paint_button(slot_buttons[i], GOLD if on else PLUM, Color("#FFE9A0") if on else Color(1, 1, 1, 0.18), CREAM, 12, 8, 2 if on else 1)
		slot_buttons[i].text = "SLOT %d" % (i + 1)
	for chip in cover_buttons:
		var id := str(chip.get_meta("cover_id"))
		var on: bool = coverage == id
		_paint_button(chip, GOLD if on else PLUM, Color("#FFE9A0") if on else Color(1, 1, 1, 0.18), Color("#1A1208") if on else CREAM, 14, 8, 2 if on else 1)
	for i in face_buttons.size():
		var id := "a" if i == 0 else "b"
		var on: bool = face == id
		_paint_button(face_buttons[i], GOLD if on else PLUM, Color("#FFE9A0") if on else Color(1, 1, 1, 0.18), CREAM, 11, 8, 2 if on else 1)
	for chip in place_buttons:
		var id := str(chip.get_meta("place_id"))
		var on: bool = place == id
		_paint_button(chip, GOLD if on else PLUM, Color("#FFE9A0") if on else Color(1, 1, 1, 0.18), CREAM if on else MUTED, 11, 8, 2 if on else 1)
	var tool_ids := ["draw", "erase", "fill", "clear"]
	for i in tool_buttons.size():
		var on: bool = tool == str(tool_ids[i])
		_paint_button(tool_buttons[i], GOLD if on else PLUM, Color("#FFE9A0") if on else Color(1, 1, 1, 0.18), CREAM, 12, 8, 2 if on else 1)
	for i in size_buttons.size():
		var on: bool = brush == int(BRUSHES[i])
		_paint_button(size_buttons[i], GOLD if on else PLUM, Color("#FFE9A0") if on else Color(1, 1, 1, 0.18), CREAM, 13, 8, 2 if on else 1)
	for i in ink_buttons.size():
		var color: Color = INKS[i]
		var on: bool = ink.is_equal_approx(color)
		_paint_button(ink_buttons[i], color, Color("#FFE9A0") if on else Color(1, 1, 1, 0.22), CREAM, 20, 0, 3 if on else 1)
	if upload_button != null:
		_paint_button(upload_button, BLUE_LIT, Color("#8EC4FF"), CREAM, 12, 8, 2)
	if copy_button != null:
		_paint_button(copy_button, PLUM, Color("#FFE9A0"), CREAM, 12, 8, 2)
	for chip in stamp_buttons:
		_paint_button(chip, PLUM, Color(1, 1, 1, 0.18), CREAM, 11, 8, 1)
	if draw_toggle != null:
		var draw_label := "HIDE PAINT" if draw_open else "PAINT THIS FACE"
		draw_toggle.text = draw_label
		_paint_button(draw_toggle, GOLD if draw_open else PLUM, Color("#FFE9A0") if draw_open else Color(1, 1, 1, 0.18), Color("#1A1208") if draw_open else CREAM, 14, 8, 2 if draw_open else 1)
	if draw_block != null:
		draw_block.visible = draw_open


func _sync_coverage_layout() -> void:
	var half := coverage == "half"
	if preview_bowl_b != null:
		preview_bowl_b.visible = half
	if face_view_b != null:
		face_view_b.visible = half
	if face_row != null:
		face_row.visible = half
	if preview_bowl != null:
		preview_bowl.custom_minimum_size = Vector2(104, 104) if half else Vector2(112, 112)
	if preview_bowl_b != null:
		preview_bowl_b.custom_minimum_size = Vector2(104, 104)
	if face_view != null:
		face_view.custom_minimum_size = Vector2(156, 156)
	if face_view_b != null:
		face_view_b.custom_minimum_size = Vector2(156, 156)


func _face_kit(side: String) -> Dictionary:
	var kit: Dictionary = profile.kit()
	if coverage != "half":
		return kit
	var copy: Dictionary = kit.duplicate(true)
	var pal: Dictionary = Kit.palette(int(copy.get("bowl_color", 1)))
	if Kit.is_photo_skin(str(copy.get("bowl_skin", "club"))) or _has_ink(canvas_a if side == "a" else canvas_b):
		copy["bowl_skin"] = "photo_wrap"
		copy["preview_photo_slot"] = "b" if side == "b" else "a"
		return copy
	copy["bowl_skin"] = "both"
	if side == "b":
		copy["preview_color"] = pal["b"]
		copy["preview_color_b"] = pal["a"]
	return copy


func _refresh_pad() -> void:
	_paint_pad(face_view, face_tex, "a")
	if coverage == "half":
		_paint_pad(face_view_b, face_tex_b, "b")


func _paint_pad(view: TextureRect, tex: ImageTexture, side: String) -> void:
	if view == null:
		return
	var art := canvas_b if side == "b" else canvas_a
	if coverage == "whole" and profile != null and not Kit.is_photo_skin(str(profile.bowl_skin)):
		art = null
	var pal: Dictionary = Kit.palette(profile.bowl_color if profile != null else 1)
	var base: Color = pal["b"] if side == "b" else pal["a"]
	var img := Image.create(FACE, FACE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in FACE:
		for x in FACE:
			var nx := (float(x) + 0.5) / float(FACE) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(FACE) * 2.0 - 1.0
			var r2 := nx * nx + ny * ny
			if r2 > 1.0:
				continue
			var col := base.darkened(0.08 * r2)
			if art != null:
				var px := art.get_pixel(x, y)
				if px.a > 0.04:
					col = col.lerp(px, px.a)
			img.set_pixel(x, y, col)
	if tex == null:
		tex = ImageTexture.create_from_image(img)
		if side == "b":
			face_tex_b = tex
		else:
			face_tex = tex
	else:
		tex.set_image(img)
	view.texture = tex


func _blank() -> Image:
	var img := Image.create(FACE, FACE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _square(image: Image) -> Image:
	var copy := image.duplicate() as Image
	if copy.is_compressed():
		copy.decompress()
	copy.convert(Image.FORMAT_RGBA8)
	var wide := copy.get_width()
	var high := copy.get_height()
	var side := mini(wide, high)
	if wide != high:
		copy = copy.get_region(Rect2i((wide - side) / 2, (high - side) / 2, side, side))
	copy.resize(FACE, FACE, Image.INTERPOLATE_LANCZOS)
	return copy


func _has_ink(img: Image) -> bool:
	if img == null:
		return false
	var step := 8
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			if img.get_pixel(x, y).a > 0.12:
				return true
	return false


func _stamp_smile(img: Image, fill: Color, line: Color, blush: Color) -> void:
	_fill_circle(img, Vector2(128, 128), 108, fill)
	_fill_circle(img, Vector2(96, 108), 14, line)
	_fill_circle(img, Vector2(160, 108), 14, line)
	_fill_circle(img, Vector2(72, 150), 16, blush)
	_fill_circle(img, Vector2(184, 150), 16, blush)
	for i in 28:
		var t := PI * 0.18 + float(i) / 27.0 * PI * 0.64
		var p := Vector2(128.0 + cos(t) * 52.0, 128.0 + sin(t) * 46.0)
		_fill_circle(img, p, 6, line)


func _stamp_star(img: Image, col: Color) -> void:
	for y in FACE:
		for x in FACE:
			var p := Vector2(float(x) - 128.0, float(y) - 128.0)
			var ang := atan2(p.y, p.x)
			var r := p.length()
			var spike := 0.5 + 0.5 * cos(ang * 5.0)
			if r < 28.0 + spike * 78.0:
				img.set_pixel(x, y, col)


func _stamp_heart(img: Image, col: Color) -> void:
	for y in FACE:
		for x in FACE:
			var nx := (float(x) - 128.0) / 90.0
			var ny := (128.0 - float(y)) / 90.0 - 0.15
			var a := nx * nx + ny * ny - 1.0
			if a * a * a - nx * nx * ny * ny * ny < 0.0:
				img.set_pixel(x, y, col)


func _stamp_ring(img: Image, col: Color) -> void:
	for y in FACE:
		for x in FACE:
			var d := Vector2(float(x) - 128.0, float(y) - 128.0).length()
			if d > 78.0 and d < 104.0:
				img.set_pixel(x, y, col)


func _fill_circle(img: Image, at: Vector2, radius: int, col: Color) -> void:
	var r2 := radius * radius
	var x0 := maxi(0, int(at.x) - radius)
	var y0 := maxi(0, int(at.y) - radius)
	var x1 := mini(FACE - 1, int(at.x) + radius)
	var y1 := mini(FACE - 1, int(at.y) + radius)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x - at.x
			var dy := y - at.y
			if dx * dx + dy * dy <= float(r2):
				img.set_pixel(x, y, col)


func _bowl_view(side: int) -> TextureRect:
	var view := TextureRect.new()
	view.custom_minimum_size = Vector2(side, side)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view


func _pad_view(side: int) -> TextureRect:
	var view := TextureRect.new()
	view.custom_minimum_size = Vector2(side, side)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	return view


func _fill_disc(img: Image, col: Color) -> void:
	if img == null:
		return
	for y in FACE:
		for x in FACE:
			var nx := (float(x) + 0.5) / float(FACE) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(FACE) * 2.0 - 1.0
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, col)


func _kicker(text: String) -> Label:
	return _label(text, 12, CREAM, FONT_BOLD)


func _wrapped(text: String) -> Label:
	var label := _label(text, 14, MUTED, FONT_INTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", FONT_BOLD)
	button.add_theme_font_size_override("font_size", font_size)
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	return button


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _paint_button(button: Button, fill: Color, border: Color, font_color: Color, radius: int, side: int, width: int = 1) -> void:
	button.add_theme_stylebox_override("normal", _flat(fill, border, width, radius, side))
	button.add_theme_stylebox_override("hover", _flat(fill.lightened(0.12), border, width, radius, side))
	button.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.08), GOLD, width, radius, side))
	button.add_theme_stylebox_override("disabled", _flat(fill, border, width, radius, side))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)


func _flat(fill: Color, border: Color, width: int, radius: int, side: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = side
	style.content_margin_right = side
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
