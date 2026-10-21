extends RefCounted

## Shared layout for the 3D crokinole table.
## One world unit is 0.33 m, so the playing surface is about 66 cm across.

const PLAY_RADIUS := 1.0
const SURFACE_Y := 0.0
const DISC_RADIUS := 0.058
const DISC_HEIGHT := 0.034
const DISC_CENTER_Y := 0.018
const JACK_RADIUS := 0.046
const JACK_HEIGHT := 0.028
const JACK_CENTER_Y := 0.016
const METERS_PER_UNIT := 0.33
const PLAYER_START := Vector3(0.0, 0.018, 0.62)

static func plastic(color: Color, roughness: float, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.06
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
