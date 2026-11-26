extends MeshInstance3D

## Purchased 3D arrows. Straight aim only — discs do not curve, so the
## mesh stays rigid. Five pack styles cover the club modes.

const PACK := preload("res://assets/arrows/arrows.fbx")

const STYLES := {
	"classic": "arrow_0",
	"practice": "arrow_1",
	"friends": "arrow_9",
	"challenge": "arrow_13",
	"bowls": "arrow_5",
}

static var _meshes: Dictionary = {}
static var _loaded := false

var _style := "arrow_0"
var _table := "crokinole"


static func style_for(setup: Dictionary) -> String:
	var rink := str(setup.get("rink", "crokinole"))
	var channel := str(setup.get("channel", "classic"))
	if rink == "lawn":
		return str(STYLES["bowls"])
	if STYLES.has(channel):
		return str(STYLES[channel])
	return str(STYLES["classic"])


static func _ensure_pack() -> void:
	if _loaded:
		return
	_loaded = true
	if PACK == null:
		return
	var raw: Node = PACK.instantiate()
	if raw == null:
		return
	_stash(raw)
	raw.free()


static func _stash(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			_meshes[str(mi.name)] = mi.mesh
	for child in node.get_children():
		_stash(child)


func wear(style_name: String, table_name: String = "crokinole") -> void:
	_style = style_name
	_table = table_name
	_ensure_pack()
	var mesh_res: Mesh = _meshes.get(_style)
	if mesh_res == null:
		mesh_res = _meshes.get("arrow_0")
	if mesh_res == null:
		return
	mesh = mesh_res
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	extra_cull_margin = 8.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#7A3BFF") if _table == "crokinole" else Color("#E8C56A")
	mat.metallic = 0.42
	mat.roughness = 0.28
	mat.emission_enabled = true
	mat.emission = Color("#C4AEFF") if _table == "crokinole" else Color("#FFE27A")
	mat.emission_energy_multiplier = 0.55
	material_override = mat
	visible = false


func clear() -> void:
	visible = false


func present(origin: Vector3, aim: Vector3, power: float) -> void:
	if mesh == null:
		clear()
		return
	var direction := aim
	direction.y = 0.0
	if direction.length() < 0.001:
		direction = Vector3(0.0, 0.0, -1.0)
	direction = direction.normalized()
	var amount := clampf(power, 0.0, 1.0)
	var length := lerpf(0.24, 0.64, amount)
	var sit := 0.022
	if _table == "lawn":
		length = lerpf(1.15, 3.4, amount)
		sit = 0.04
	var box := mesh.get_aabb()
	var native := maxf(box.size.x, 0.001)
	var s := length / native
	# looking_at aims -Z. Swap so the pack's +X is the aim, then lay the
	# chevron on the table (thickness up).
	var look := Basis.looking_at(direction, Vector3.UP)
	var basis := Basis(-look.z, look.y, look.x).rotated(direction, PI * 0.5)
	basis = basis.scaled(Vector3(s, s, s))
	var tail := Vector3(-box.position.x, -box.get_center().y, -box.get_center().z)
	var gap := 0.22 if _table == "crokinole" else 0.42
	var tip := origin + Vector3(0.0, sit, 0.0) + direction * gap
	global_transform = Transform3D(basis, tip) * Transform3D(Basis.IDENTITY, tail)
	visible = true
