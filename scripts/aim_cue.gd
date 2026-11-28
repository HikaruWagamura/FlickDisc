extends Node3D

## Two real aim cues on the same grass path:
##   BLOCKS — a fixed 5+3 graph. Count and size stay put; only colour changes.
##   RIGGED — the 10-bone skinned arrow, posed along that same curve
##   BOTH   — both meshes sitting on the live aim line at once

const PACK := preload("res://assets/arrows/arrow.fbx")
const RIGGED := preload("res://assets/arrows/rigged_arrow.glb")
const SHADER_PATH := "res://shaders/aim_guide_3d.gdshader"
const MESH_NAME := "arrow_15"
const MAIN_ARROWS := 5
const TAIL_ARROWS := 3
const MAX_ARROWS := 8
const PERIOD := 0.67
## Sit above the dashed centre line (line top is ~0.024) so the small
## tip arrows never clip the stripe or the grass. Hop only goes up.
const SEAT_BLOCK := 0.052
const SEAT_RIG := 0.052
const SCALE_L := 0.58
const SCALE_W := 0.36
const SCALE_H := 0.84
const SHAKE_FROM := 0.94
const STYLE_BLOCKS := 0
const STYLE_RIGGED := 1
const STYLE_BOTH := 2
## First two stay full size so they still read on the grass. The third
## sits 5% smaller, then 90, 90, 85, 80, and 70 at the tip.
const TAPER := [1.00, 1.00, 0.95, 0.90, 0.90, 0.85, 0.80, 0.70]
## Bowls start where the old second head sat, so the first block clears
## the stone. Crokinole pulls path_start in because the disc is smaller.
const T_START := 0.223
const T_END := 0.96

var style := STYLE_BLOCKS
var size_scale := 1.0
var head_count := MAX_ARROWS
var path_start := T_START
var _material: ShaderMaterial
var _chevron: ArrayMesh
var _local_centre := Vector3.ZERO
var _local_size := Vector3.ONE
var _mesh_min_y := -0.08
var _faces: Array[Vector3] = []
var _nodes: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _rig: Node3D
var _rig_mesh: MeshInstance3D
var _skel: Skeleton3D
var _bone_order: PackedInt32Array = PackedInt32Array()
var _showing := false
var _count := 0
var _path := PackedVector3Array()
var _power := 0.0


func _ready() -> void:
	_chevron = _load_chevron()
	var shader := load(SHADER_PATH) as Shader
	if shader != null:
		_material = ShaderMaterial.new()
		_material.shader = shader
	for i in MAX_ARROWS:
		var mi := MeshInstance3D.new()
		mi.name = "MiniArrow%d" % i
		mi.mesh = _chevron
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 8.0
		mi.visible = false
		if _material != null:
			var mat := _material.duplicate() as ShaderMaterial
			mat.render_priority = 3
			mi.material_override = mat
			_mats.append(mat)
		mi.sorting_offset = 4.0
		add_child(mi)
		_nodes.append(mi)
		_faces.append(Vector3(0.0, 0.0, -1.0))
	_load_rigged()


func _load_rigged() -> void:
	var packed: PackedScene = RIGGED
	if packed == null:
		push_error("Rigged aim arrow missing")
		return
	_rig = packed.instantiate()
	_rig.name = "RiggedArrow"
	_rig.visible = false
	add_child(_rig)
	_skel = _find_skel(_rig)
	_rig_mesh = _find_mesh_node(_rig)
	if _rig_mesh != null:
		_rig_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_rig_mesh.extra_cull_margin = 8.0
	if _skel == null:
		push_error("Rigged aim arrow has no skeleton")
		return
	_bone_order = _chain_bones(_skel)
	_skel.motion_scale = 1.0


func set_style(which: int) -> void:
	style = clampi(which, STYLE_BLOCKS, STYLE_BOTH)
	if _showing:
		_place()
	else:
		_hide_parts()


func set_size_scale(value: float) -> void:
	size_scale = clampf(value, 0.08, 2.5)
	if _showing:
		_place()


func set_heads(count: int) -> void:
	head_count = clampi(count, 1, MAX_ARROWS)
	if _showing:
		_place()


func set_path_start(t: float) -> void:
	path_start = clampf(t, 0.0, 0.6)
	if _showing:
		_place()


func _load_chevron() -> ArrayMesh:
	var packed: PackedScene = PACK
	if packed == null:
		push_error("Aim cue pack missing")
		return ArrayMesh.new()
	var root := packed.instantiate()
	var source := _find_pack_mesh(root, MESH_NAME)
	var mesh := _extract_one(source)
	root.queue_free()
	return mesh


func _find_pack_mesh(node: Node, mesh_name: String) -> ArrayMesh:
	if node is MeshInstance3D and node.name == mesh_name:
		var mi := node as MeshInstance3D
		if mi.mesh is ArrayMesh:
			return mi.mesh as ArrayMesh
	for child in node.get_children():
		var found := _find_pack_mesh(child, mesh_name)
		if found != null:
			return found
	return null


func _extract_one(source: ArrayMesh) -> ArrayMesh:
	if source == null or source.get_surface_count() < 1:
		return ArrayMesh.new()
	var arrays := source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return source
	var lo := verts[0].x
	var hi := verts[0].x
	for v in verts:
		lo = minf(lo, v.x)
		hi = maxf(hi, v.x)
	var span := maxf(hi - lo, 0.001)
	# Keep the centre mini of the five-arrow row.
	var pick := 2
	var keep := PackedInt32Array()
	for i in verts.size():
		var bin := clampi(int(((verts[i].x - lo) / span) * 5.0), 0, 4)
		if bin == pick:
			keep.append(i)
	if keep.size() < 3:
		_local_centre = source.get_aabb().position + source.get_aabb().size * 0.5
		_local_size = source.get_aabb().size
		return source
	var remap := {}
	var new_verts := PackedVector3Array()
	var new_normals := PackedVector3Array()
	var new_uvs := PackedVector2Array()
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for old_i in keep:
		remap[old_i] = new_verts.size()
		new_verts.append(verts[old_i])
		if old_i < src_n.size():
			new_normals.append(src_n[old_i])
		if old_i < src_uv.size():
			new_uvs.append(src_uv[old_i])
	var new_indices := PackedInt32Array()
	var src_idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if src_idx.is_empty():
		for i in range(0, verts.size() - 2, 3):
			if remap.has(i) and remap.has(i + 1) and remap.has(i + 2):
				new_indices.append(remap[i])
				new_indices.append(remap[i + 1])
				new_indices.append(remap[i + 2])
	else:
		for i in range(0, src_idx.size() - 2, 3):
			var a: int = src_idx[i]
			var b: int = src_idx[i + 1]
			var c: int = src_idx[i + 2]
			if remap.has(a) and remap.has(b) and remap.has(c):
				new_indices.append(remap[a])
				new_indices.append(remap[b])
				new_indices.append(remap[c])
	if new_verts.is_empty():
		_local_centre = source.get_aabb().position + source.get_aabb().size * 0.5
		_local_size = source.get_aabb().size
		return source
	var min_p := new_verts[0]
	var max_p := new_verts[0]
	for v in new_verts:
		min_p.x = minf(min_p.x, v.x)
		min_p.y = minf(min_p.y, v.y)
		min_p.z = minf(min_p.z, v.z)
		max_p.x = maxf(max_p.x, v.x)
		max_p.y = maxf(max_p.y, v.y)
		max_p.z = maxf(max_p.z, v.z)
	_local_centre = (min_p + max_p) * 0.5
	# Pack chevrons point along +X and open across Z. Rotate so Godot -Z is
	# the tip, +Y is up, +X is the V width. looking_at can then face them
	# down the path.
	var out_verts := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var rot_min := Vector3(INF, INF, INF)
	var rot_max := Vector3(-INF, -INF, -INF)
	for i in new_verts.size():
		var local := new_verts[i] - _local_centre
		var baked := Vector3(local.z, local.y, -local.x)
		out_verts.append(baked)
		rot_min.x = minf(rot_min.x, baked.x)
		rot_min.y = minf(rot_min.y, baked.y)
		rot_min.z = minf(rot_min.z, baked.z)
		rot_max.x = maxf(rot_max.x, baked.x)
		rot_max.y = maxf(rot_max.y, baked.y)
		rot_max.z = maxf(rot_max.z, baked.z)
	_local_size = rot_max - rot_min
	_mesh_min_y = rot_min.y
	var span_z := maxf(_local_size.z, 0.001)
	for baked in out_verts:
		var along := clampf((baked.z - rot_min.z) / span_z, 0.0, 1.0)
		out_uvs.append(Vector2(0.5, along))
	_local_centre = Vector3.ZERO
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if new_indices.is_empty():
		for i in out_verts.size():
			if i < new_normals.size():
				var n: Vector3 = new_normals[i]
				st.set_normal(Vector3(n.z, n.y, -n.x))
			st.set_uv(out_uvs[i])
			st.add_vertex(out_verts[i])
	else:
		for idx in new_indices:
			if idx < new_normals.size():
				var n: Vector3 = new_normals[idx]
				st.set_normal(Vector3(n.z, n.y, -n.x))
			st.set_uv(out_uvs[idx])
			st.add_vertex(out_verts[idx])
	st.generate_normals()
	return st.commit()


func clear() -> void:
	_showing = false
	_count = 0
	_path = PackedVector3Array()
	visible = false
	_hide_parts()


func present(path: PackedVector3Array, power: float, _facing: Vector3 = Vector3.ZERO) -> void:
	if path.size() < 2:
		clear()
		return
	visible = true
	_showing = true
	_path = path
	_power = clampf(power, 0.0, 1.0)
	# Count is the 5+3 graph, never the pull. Power only tints the bars.
	_count = head_count
	_place()


func _process(_delta: float) -> void:
	# Only keep ticking when the graph is shaking at full weight.
	if _showing and _path.size() >= 2 and _power >= SHAKE_FROM:
		_place()


func _place() -> void:
	if _path.size() < 2:
		return
	var show_blocks := style == STYLE_BLOCKS or style == STYLE_BOTH
	var show_rig := style == STYLE_RIGGED or style == STYLE_BOTH
	# When both sit on the same line, keep the blocks a little smaller so
	# the rigged shaft is still readable underneath.
	if show_blocks:
		_place_blocks()
	else:
		_hide_blocks()
	if show_rig:
		_place_rigged()
	else:
		_hide_rigged()


func _hide_parts() -> void:
	_hide_blocks()
	_hide_rigged()


func _hide_blocks() -> void:
	for mi in _nodes:
		mi.visible = false


func _hide_rigged() -> void:
	if _rig != null:
		_rig.visible = false


func _place_blocks() -> void:
	var amount := _power
	var total := head_count
	var start_t := path_start
	# 5+3 taper stays. Pull never adds, hides, or resizes bars — only colour.
	var scale_l := SCALE_L * size_scale
	var scale_w := SCALE_W * size_scale
	var scale_h := SCALE_H * size_scale
	if style == STYLE_BOTH:
		scale_l *= 0.90
		scale_w *= 0.90
	var hop := 0.0
	if amount >= SHAKE_FROM:
		var shake := clampf((amount - SHAKE_FROM) / (1.0 - SHAKE_FROM), 0.0, 1.0)
		var wave := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.052)
		hop = wave * (0.012 * shake * size_scale)
	for i in MAX_ARROWS:
		var mi := _nodes[i]
		if i >= total:
			mi.visible = false
			continue
		mi.visible = true
		var t := start_t
		if total > 1:
			t = lerpf(start_t, T_END, float(i) / float(total - 1))
		var taper := 0.70
		if i < TAPER.size():
			taper = float(TAPER[i])
		var centre := _sample(_path, t)
		var tangent := _facing(_path, t)
		if tangent.length() < 0.04:
			tangent = _faces[i]
		else:
			_faces[i] = tangent
		var sl := scale_l * taper
		var sw := scale_w * taper
		# Keep height up so the small tip still sits on the grass, not in it.
		var sh := scale_h * lerpf(1.0, taper, 0.12)
		var lift := SEAT_BLOCK * size_scale - _mesh_min_y * sh
		var origin := Vector3(centre.x, lift + hop, centre.z)
		var xf := Transform3D()
		xf.origin = origin
		xf = xf.looking_at(origin + tangent, Vector3.UP)
		xf.basis = xf.basis.scaled(Vector3(sw, sh, sl))
		mi.global_transform = xf
		if i < _mats.size() and _mats[i] != null:
			_mats[i].set_shader_parameter("power", amount)
			_mats[i].set_shader_parameter("glow_enabled", true)
			_mats[i].set_shader_parameter("along", t)


func _place_rigged() -> void:
	if _rig == null or _skel == null or _bone_order.is_empty():
		return
	_skel.clear_bones_global_pose_override()
	_skel.reset_bone_poses()
	var length := _path_length()
	var start := _sample(_path, 0.22)
	var tip := _sample(_path, 0.98)
	var chord := Vector3(tip.x - start.x, 0.0, tip.z - start.z)
	if chord.length() < 0.05:
		chord = _tangent(_path, 0.10)
	var tan := chord.normalized()
	var wave := float(Time.get_ticks_msec()) * 0.001
	var hop := 0.0
	if _power >= SHAKE_FROM:
		hop = (0.5 + 0.5 * sin((wave / PERIOD) * TAU)) * 0.01
	var origin := Vector3(start.x, SEAT_RIG + hop, start.z)
	_rig.visible = true
	# Mesh rest length is 0.75 along local -Z. look_at points -Z down the path.
	var rest_len := 0.75
	var sx := 1.05
	var sy := 2.8
	var sz := clampf(length / rest_len, 2.0, 3.6)
	var xf := Transform3D()
	xf.origin = origin
	xf = xf.looking_at(origin + tan * maxf(length, 1.0), Vector3.UP)
	xf.basis = xf.basis.scaled(Vector3(sx, sy, sz))
	_rig.global_transform = xf


func _bend_rigged() -> void:
	if _skel == null:
		return
	var n := _bone_order.size()
	if n < 2:
		return
	for i in n:
		var bone_i: int = _bone_order[i]
		var t := lerpf(0.10, 0.96, float(i) / float(n - 1))
		var pos := _sample(_path, t)
		var tan := _tangent(_path, t)
		var pos_s := _skel.to_local(Vector3(pos.x, SEAT_RIG, pos.z))
		var ahead := pos + tan
		var ahead_s := _skel.to_local(Vector3(ahead.x, SEAT_RIG, ahead.z))
		var y_axis := ahead_s - pos_s
		if y_axis.length() < 0.0001:
			y_axis = Vector3(0.0, 0.0, -1.0)
		else:
			y_axis = y_axis.normalized()
		var z_axis := Vector3(0.0, 1.0, 0.0)
		var x_axis := z_axis.cross(y_axis)
		if x_axis.length_squared() < 0.0001:
			x_axis = Vector3(1.0, 0.0, 0.0)
		else:
			x_axis = x_axis.normalized()
		z_axis = y_axis.cross(x_axis).normalized()
		var pose := Transform3D(Basis(x_axis, y_axis, z_axis), pos_s)
		_skel.set_bone_global_pose_override(bone_i, pose, 1.0, true)


func _find_skel(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skel(child)
		if found != null:
			return found
	return null


func _find_mesh_node(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_node(child)
		if found != null:
			return found
	return null


func _chain_bones(skel: Skeleton3D) -> PackedInt32Array:
	var ordered := PackedInt32Array()
	var named := PackedInt32Array()
	for i in 10:
		var idx := skel.find_bone("Bone_%02d" % i)
		if idx >= 0:
			named.append(idx)
	if named.size() >= 2:
		return named
	var root := -1
	for i in skel.get_bone_count():
		if skel.get_bone_parent(i) < 0:
			root = i
			break
	if root < 0:
		for i in skel.get_bone_count():
			ordered.append(i)
		return ordered
	_walk_bones(skel, root, ordered)
	return ordered


func _walk_bones(skel: Skeleton3D, bone: int, into: PackedInt32Array) -> void:
	into.append(bone)
	for i in skel.get_bone_count():
		if skel.get_bone_parent(i) == bone:
			_walk_bones(skel, i, into)


func _path_length() -> float:
	var total := 0.0
	for i in range(1, _path.size()):
		total += _path[i - 1].distance_to(_path[i])
	return maxf(total, 0.18)


func _sample(path: PackedVector3Array, t: float) -> Vector3:
	var total := _path_length()
	var want := clampf(t, 0.0, 1.0) * total
	var walked := 0.0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var span := a.distance_to(b)
		if walked + span >= want or i == path.size() - 1:
			var u := 0.0 if span < 0.0001 else clampf((want - walked) / span, 0.0, 1.0)
			var point := a.lerp(b, u)
			return Vector3(point.x, 0.0, point.z)
		walked += span
	var last := path[path.size() - 1]
	return Vector3(last.x, 0.0, last.z)


func _tangent(path: PackedVector3Array, t: float) -> Vector3:
	var last := path.size() - 1
	var index := clampi(int(t * float(last)), 0, last - 1)
	var dir := path[index + 1] - path[index]
	dir.y = 0.0
	if dir.length() < 0.001:
		return Vector3(0.0, 0.0, -1.0)
	return dir.normalized()


func _facing(path: PackedVector3Array, t: float) -> Vector3:
	# Point this chevron at a spot a little further along the path so a
	# hook still reads as arrows facing the run, not the side.
	var here := _sample(path, t)
	var ahead := _sample(path, minf(t + 0.10, 1.0))
	var dir := Vector3(ahead.x - here.x, 0.0, ahead.z - here.z)
	if dir.length() < 0.04:
		return _tangent(path, t)
	return dir.normalized()
