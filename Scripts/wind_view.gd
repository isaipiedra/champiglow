extends Node3D

@export var terrain: MeshInstance3D
@export var spacing: float = 4.0
@export var arrow_color: Color = Color(0.4, 0.75, 1.0)

# Alturas para los tres niveles de las flechas 
@export var layer_heights: Array[float] = [0.5, 3.0, 5.5]

var _multi: MultiMeshInstance3D
var _positions: Array[Vector3] = []

func _ready() -> void:
	await get_tree().process_frame
	_build_grid()
	_build_multimesh()
	visible = false

func _build_grid() -> void:
	_positions.clear()
	if not terrain:
		push_error("Falta asignar el terreno en el inspector de WindView")
		return

	var aabb := terrain.global_transform * terrain.get_aabb()
	var size_x := aabb.size.x
	var size_z := aabb.size.z
	
	# Margen para evitar que las flechas cambien mucho de altura por el terreno
	var margin := spacing * 0.75
	size_x = maxf(size_x - margin, 1.0)
	size_z = maxf(size_z - margin, 1.0)
	
	var count_x := int(size_x / spacing)
	var count_z := int(size_z / spacing)
	
	var center := aabb.get_center()
	var start_x := center.x - (count_x * spacing) * 0.5
	var start_z := center.z - (count_z * spacing) * 0.5

	var space_state = get_world_3d().direct_space_state

	for i in range(count_x + 1):
		for j in range(count_z + 1):
			var pos_x := start_x + i * spacing
			var pos_z := start_z + j * spacing
			
			# Cálculo de la altura del terreno
			var ray_origin := Vector3(pos_x, 100.0, pos_z)
			var ray_end := Vector3(pos_x, -100.0, pos_z)
			var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
			var result := space_state.intersect_ray(query)
			
			if result:
				var ground_y = result.position.y
				
				# Tres capas de flechas con las alturas
				for height_offset in layer_heights:
					var final_pos := Vector3(pos_x, ground_y + height_offset, pos_z)
					_positions.append(to_local(final_pos))
			else:
				pass
				
func _build_multimesh() -> void:
	_multi = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _build_arrow_mesh() # Función para construir la flecha
	mm.instance_count = _positions.size()
	_multi.multimesh = mm
	add_child(_multi)
	
	for i in _positions.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _positions[i]))

func update_arrows(wind_force: Vector3) -> void:
	if not visible or not _multi:
		return
		
	var strength := wind_force.length()
	if strength < 0.01:
		return
		
	var rot := Basis(Vector3.UP, atan2(wind_force.x, wind_force.z))
	var length := clampf(strength * 1.0, 0.6, 1.8)
	var basis := rot.scaled(Vector3(1.0, 1.0, length))
	
	for i in _positions.size():
		_multi.multimesh.set_instance_transform(i, Transform3D(basis, _positions[i]))

# --- Diseño de la flecha en 3D ---
func _build_arrow_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Palo de la flecha
	var stick_mesh := CylinderMesh.new()
	stick_mesh.bottom_radius = 0.03
	stick_mesh.top_radius = 0.03
	stick_mesh.height = 0.6
	stick_mesh.radial_segments = 12

	var stick_tf := Transform3D(Basis(Vector3.RIGHT, PI/2), Vector3(0, 0, 0.3))
	st.append_from(stick_mesh, 0, stick_tf)

	# 2. Punta de la flecha
	var head_mesh := CylinderMesh.new()
	head_mesh.bottom_radius = 0.09
	head_mesh.top_radius = 0.0 
	head_mesh.height = 0.25
	head_mesh.radial_segments = 12

	# Posición del palo y la punta de la flecha
	var head_tf := Transform3D(Basis(Vector3.RIGHT, PI/2), Vector3(0, 0, 0.725))
	st.append_from(head_mesh, 0, head_tf)

	# 3. Material de la flecha
	var mat := StandardMaterial3D.new()
	mat.albedo_color = arrow_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX 
	mat.roughness = 0.3 
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.5 
	st.set_material(mat)

	return st.commit()
