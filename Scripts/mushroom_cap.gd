@tool
extends Node3D

@export var cap_radius: float = 0.30
@export var cap_height: float = 0.22
@export var radial_segments: int = 48
@export var cap_color: Color = Color("#e8e3ce")

@onready var cap_mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	generate_cap()


func generate_cap() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Cada Vector2 representa (radio, altura),
	# con valores relativos al tamaño del sombrero.
	var profile: Array[Vector2] = [
		Vector2(0.02, 1.00),
		Vector2(0.12, 0.99),
		Vector2(0.28, 0.94),
		Vector2(0.48, 0.82),
		Vector2(0.68, 0.63),
		Vector2(0.85, 0.40),
		Vector2(0.97, 0.17),
		Vector2(1.00, 0.02),
		Vector2(0.99, -0.12),
		Vector2(0.93, -0.24),
		Vector2(0.84, -0.28)
	]

	for i in range(profile.size() - 1):
		var ring_a: Vector2 = profile[i]
		var ring_b: Vector2 = profile[i + 1]

		for j in range(radial_segments):
			var a0 := TAU * float(j) / radial_segments
			var a1 := TAU * float(j + 1) / radial_segments

			var p0 := Vector3(
				cos(a0) * ring_a.x * cap_radius,
				ring_a.y * cap_height,
				sin(a0) * ring_a.x * cap_radius
			)

			var p1 := Vector3(
				cos(a0) * ring_b.x * cap_radius,
				ring_b.y * cap_height,
				sin(a0) * ring_b.x * cap_radius
			)

			var p2 := Vector3(
				cos(a1) * ring_b.x * cap_radius,
				ring_b.y * cap_height,
				sin(a1) * ring_b.x * cap_radius
			)

			var p3 := Vector3(
				cos(a1) * ring_a.x * cap_radius,
				ring_a.y * cap_height,
				sin(a1) * ring_a.x * cap_radius
			)

			surface.add_vertex(p0)
			surface.add_vertex(p1)
			surface.add_vertex(p2)

			surface.add_vertex(p0)
			surface.add_vertex(p2)
			surface.add_vertex(p3)

	surface.generate_normals()

	var generated_mesh := surface.commit()
	cap_mesh.mesh = generated_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = cap_color
	material.roughness = 0.8

	material.emission_enabled = true
	material.emission = cap_color
	material.emission_energy_multiplier = 0.0

	cap_mesh.material_override = material
	
func set_mushroom_appearance(new_color: Color, glow_strength: float = 0.0) -> void:
	cap_color = new_color
	
	var material := cap_mesh.material_override as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = new_color
	material.emission_enabled = glow_strength > 0.0
	material.emission = Color("#55ff33")
	material.emission_energy_multiplier = glow_strength
