extends RefCounted

## Crokinole table in meters-ish world units.
## The wooden surface has a radius of 0.92. Eight pegs stand on the 15-point circle.

const SURFACE_RADIUS := 0.92
const DITCH_OUTER := 1.08
const HOLE_RADIUS := 0.108
const RING_15 := 0.40
const RING_10 := 0.64
const RING_5 := 0.92
const PEG_RADIUS := 0.036
const PEG_RING := 0.28
const DISC_RADIUS := 0.058
const DISC_HEIGHT := 0.030
const DISC_CENTER_Y := 0.016
const DITCH_Y := -0.006
const PLAYER_START_Z := 0.68
const LANE_HALF := 0.30
const DISCS_PER_ROUND := 8

const MIN_SPEED := 1.15
const MAX_SPEED := 3.6
const MAX_DRAG_DISTANCE := 0.7
const SURFACE_FRICTION := 0.2
const DITCH_FRICTION := 0.08
const PEG_RESTITUTION := 0.74
const DISC_RESTITUTION := 0.9
const RAIL_RESTITUTION := 0.4
const STOP_SPEED := 0.055

static func peg_positions() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for index in 8:
		var angle := PI / 8.0 + float(index) * TAU / 8.0
		points.append(Vector3(cos(angle) * PEG_RING, 0.0, sin(angle) * PEG_RING))
	return points

static func points_for(distance_from_center: float, sunk: bool) -> int:
	# A disc scores a ring only when it is clear of that ring's line.
	# Touching the line scores the lower ring. The hole scores only when the disc has dropped.
	if sunk:
		return 20
	var clear := DISC_RADIUS
	if distance_from_center <= RING_15 - clear:
		return 15
	if distance_from_center <= RING_10 - clear:
		return 10
	if distance_from_center <= RING_5 - clear:
		return 5
	return 0

static func plastic(color: Color, roughness: float, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.08
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

static func add_mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

static func cylinder(radius: float, height: float, segments: int = 48) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return mesh
