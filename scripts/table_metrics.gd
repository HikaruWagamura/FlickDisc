extends RefCounted

## NCA crokinole, scaled so a disc is 1 1/4 inch.
## Playing surface 26". Rings at 4", 8" and 12". Hole is 1 3/8",
## only a little wider than the disc. Pegs stand on the 4" ring.

const DISC_RADIUS := 0.058
const INCH := DISC_RADIUS / 0.625
const SURFACE_RADIUS := 13.0 * INCH
const DITCH_OUTER := 15.0 * INCH
const HOLE_RADIUS := 0.6875 * INCH
const RING_15 := 4.0 * INCH
const RING_10 := 8.0 * INCH
const RING_5 := 12.0 * INCH
const PEG_RADIUS := 0.1875 * INCH
const PEG_RING := RING_15
const DISC_HEIGHT := 0.030
const DISC_CENTER_Y := 0.016
const DITCH_Y := -0.006
const PLAYER_START_Z := 12.35 * INCH
const LANE_HALF := 3.2 * INCH
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

## Filled when the paid crokinole pack is on the table. Pegs and buttons
## then use the pack's own size and placement instead of the procedural set.
static var club_pegs: Array[Vector3] = []
static var club_dark: Array = []
static var club_light: Array = []
static var club_disc_xform := Transform3D.IDENTITY
static var club_figures_mat: Material
static var club_center_y := DISC_CENTER_Y
static var club_ditch_y := DITCH_Y

static func peg_positions() -> Array[Vector3]:
	if club_pegs.size() >= 8:
		return club_pegs
	var points: Array[Vector3] = []
	for index in 8:
		var angle := PI / 8.0 + float(index) * TAU / 8.0
		points.append(Vector3(cos(angle) * PEG_RING, 0.0, sin(angle) * PEG_RING))
	return points


static func sit_y(in_ditch: bool) -> float:
	return club_ditch_y if in_ditch else club_center_y


static func club_disc_mesh(player_disc: bool, kit_index: int) -> Mesh:
	var bank: Array = club_dark if player_disc else club_light
	if bank.is_empty():
		bank = club_light if player_disc else club_dark
	if bank.is_empty():
		return null
	return bank[kit_index % bank.size()]

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
