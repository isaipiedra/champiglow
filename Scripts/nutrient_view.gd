extends Node3D

@export var terrain: MeshInstance3D
@export var spacing: float = 1.0
@export var ignored_bodies: Array[Node3D] = [] 

# Colores de los nutrientes
@export var color_carbon: Color = Color(0.2, 0.4, 1.0)
@export var color_nitrogen: Color = Color(1.0, 0.4, 0.8)
@export var color_metals: Color = Color(1.0, 0.9, 0.2)

@export var max_items_per_cell: int = 15 

var grid_data: Dictionary = {}
var _grid_positions: Dictionary = {}
var _scatter_transforms: Dictionary = {}

var _multi_carbon: MultiMeshInstance3D
var _multi_nitrogen: MultiMeshInstance3D
var _multi_metals: MultiMeshInstance3D

func _ready() -> void:
	await get_tree().process_frame
	_build_grid()
	_build_multimeshes()
	visible = false

func _build_grid() -> void:
	_scatter_transforms.clear()
	if not terrain: return
	
	var aabb := terrain.global_transform * terrain.get_aabb()
	var size_x := aabb.size.x - (spacing * 0.5)
	var size_z := aabb.size.z - (spacing * 0.5)
	
	var count_x := int(maxf(size_x, 1.0) / spacing)
	var count_z := int(maxf(size_z, 1.0) / spacing)
	
	var center := aabb.get_center()
	var start_x := center.x - (count_x * spacing) * 0.5
	var start_z := center.z - (count_z * spacing) * 0.5

	var space_state = get_world_3d().direct_space_state

	# Lista de objetos a ignorar (RIDs)
	var exclude_rids: Array[RID] = []
	for body in ignored_bodies:
		if body is CollisionObject3D:
			exclude_rids.append(body.get_rid())

	for i in range(count_x + 1):
		for j in range(count_z + 1):
			var pos_x := start_x + i * spacing
			var pos_z := start_z + j * spacing
			
			var ray_origin := Vector3(pos_x, 100.0, pos_z)
			var ray_end := Vector3(pos_x, -100.0, pos_z)
			
			var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
			query.exclude = exclude_rids #Ignora los obstáculos del terreno
			
			var result := space_state.intersect_ray(query)
			
			if result:
				var hit_pos = result.position + (Vector3.UP * 0.15)
				
				var cell_key = Vector2i(i, j)
				_grid_positions[cell_key] = to_local(hit_pos)
				grid_data[cell_key] = {"carbon": 0.0, "nitrogen": 0.0, "metals": 0.0}
				
				var scatter_c = []
				var scatter_n = []
				var scatter_m = []
				for k in max_items_per_cell:
					scatter_c.append(_get_random_transform())
					scatter_n.append(_get_random_transform())
					scatter_m.append(_get_random_transform())
					
				_scatter_transforms[cell_key] = {
					"carbon": scatter_c, 
					"nitrogen": scatter_n, 
					"metals": scatter_m
				}

func _get_random_transform() -> Transform3D:
	var offset = Vector3(
		randf_range(-spacing * 0.4, spacing * 0.4),
		0.0, 
		randf_range(-spacing * 0.4, spacing * 0.4)
	)
	var spin_basis = Basis(Vector3.UP, randf() * TAU)
	var s = randf_range(0.8, 1.2)
	var final_basis = spin_basis.scaled(Vector3(s, s, s))
	return Transform3D(final_basis, offset)
	
func _build_multimeshes() -> void:
	var total_instances = _grid_positions.size() * max_items_per_cell
	_multi_carbon = _create_multimesh(_make_triangle_mesh(color_carbon), total_instances)
	_multi_nitrogen = _create_multimesh(_make_circle_mesh(color_nitrogen), total_instances)
	_multi_metals = _create_multimesh(_make_square_mesh(color_metals), total_instances)

func _create_multimesh(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mmi = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mmi.multimesh = mm
	add_child(mmi)
	return mmi

func add_nutrient(nutrient_type: String, amount: float) -> void:
	for key in grid_data.keys():
		var current = grid_data[key][nutrient_type]
		grid_data[key][nutrient_type] = clampf(current + amount, 0.0, 100.0)
	_update_visuals()

func consume_nutrient_at(world_pos: Vector3, nutrient_type: String, amount: float) -> float:
	var local_pos = to_local(world_pos)
	var closest_key = Vector2i.ZERO
	var min_dist = INF
	for key in _grid_positions.keys():
		var dist = _grid_positions[key].distance_squared_to(local_pos)
		if dist < min_dist:
			min_dist = dist
			closest_key = key
	
	if min_dist < (spacing * spacing):
		var available = grid_data[closest_key][nutrient_type]
		var consumed = minf(available, amount)
		grid_data[closest_key][nutrient_type] -= consumed
		_update_visuals()
		return consumed
	return 0.0

# Devuelve cuánto nutriente hay cerca de una posición
func get_nutrient_at(world_pos: Vector3, nutrient_type: String) -> float:
	var local_pos = to_local(world_pos)
	var closest_key = Vector2i.ZERO
	var min_dist = INF
	for key in _grid_positions.keys():
		var dist = _grid_positions[key].distance_squared_to(local_pos)
		if dist < min_dist:
			min_dist = dist
			closest_key = key

	if min_dist < (spacing * spacing):
		return grid_data[closest_key][nutrient_type]
	return 0.0

func _update_visuals() -> void:
	if not visible: return
	
	var cell_idx = 0
	for key in _grid_positions.keys():
		var data = grid_data[key]
		var base_pos = _grid_positions[key]
		var scatters = _scatter_transforms[key]
		
		_update_single_nutrient(_multi_carbon, data["carbon"], base_pos, cell_idx, scatters["carbon"])
		_update_single_nutrient(_multi_nitrogen, data["nitrogen"], base_pos, cell_idx, scatters["nitrogen"])
		_update_single_nutrient(_multi_metals, data["metals"], base_pos, cell_idx, scatters["metals"])
		
		cell_idx += 1

func _update_single_nutrient(mmi: MultiMeshInstance3D, density: float, base_pos: Vector3, cell_idx: int, scatters: Array) -> void:
	var count = int((density / 100.0) * max_items_per_cell)
	var start_idx = cell_idx * max_items_per_cell
	
	for i in max_items_per_cell:
		var inst_idx = start_idx + i
		if i < count:
			var t = Transform3D(Basis.IDENTITY, base_pos) * scatters[i]
			mmi.multimesh.set_instance_transform(inst_idx, t)
		else:
			mmi.multimesh.set_instance_transform(inst_idx, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), base_pos))

# Mesh de triángulos (carbono)
func _make_triangle_mesh(color: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var r_out = 0.07
	var r_in = 0.04
	var v = [Vector3(0, 0, r_out), Vector3(-r_out * 0.866, 0, -r_out * 0.5), Vector3(r_out * 0.866, 0, -r_out * 0.5)]
	var i = [Vector3(0, 0, r_in), Vector3(-r_in * 0.866, 0, -r_in * 0.5), Vector3(r_in * 0.866, 0, -r_in * 0.5)]
	
	for k in 3:
		var next = (k + 1) % 3
		st.add_vertex(v[k]); st.add_vertex(v[next]); st.add_vertex(i[next])
		st.add_vertex(v[k]); st.add_vertex(i[next]); st.add_vertex(i[k])
	st.generate_normals()
	st.set_material(_create_mat(color, false))
	var mesh = st.commit()
	
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(i[0]); st.add_vertex(i[1]); st.add_vertex(i[2])
	st.generate_normals()
	st.set_material(_create_mat(color, true))
	return st.commit(mesh)

# Mesh de cuadrados (nitrógeno)
func _make_square_mesh(color: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var r_out = 0.04
	var r_in = 0.03
	var v = [Vector3(-r_out, 0, -r_out), Vector3(r_out, 0, -r_out), Vector3(r_out, 0, r_out), Vector3(-r_out, 0, r_out)]
	var i = [Vector3(-r_in, 0, -r_in), Vector3(r_in, 0, -r_in), Vector3(r_in, 0, r_in), Vector3(-r_in, 0, r_in)]
	
	for k in 4:
		var next = (k + 1) % 4
		st.add_vertex(v[k]); st.add_vertex(v[next]); st.add_vertex(i[next])
		st.add_vertex(v[k]); st.add_vertex(i[next]); st.add_vertex(i[k])
	st.generate_normals()
	st.set_material(_create_mat(color, false))
	var mesh = st.commit()
	
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(i[0]); st.add_vertex(i[1]); st.add_vertex(i[2])
	st.add_vertex(i[0]); st.add_vertex(i[2]); st.add_vertex(i[3])
	st.generate_normals()
	st.set_material(_create_mat(color, true))
	return st.commit(mesh)

# Mesh de circulos (metales)
func _make_circle_mesh(color: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var r_out = 0.05
	var r_in = 0.04
	var segments = 16
	var v_out = []
	var v_in = []
	for k in segments:
		var a = (float(k) / segments) * TAU
		v_out.append(Vector3(cos(a) * r_out, 0, sin(a) * r_out))
		v_in.append(Vector3(cos(a) * r_in, 0, sin(a) * r_in))
	
	for k in segments:
		var next = (k + 1) % segments
		st.add_vertex(v_out[k]); st.add_vertex(v_out[next]); st.add_vertex(v_in[next])
		st.add_vertex(v_out[k]); st.add_vertex(v_in[next]); st.add_vertex(v_in[k])
	st.generate_normals()
	st.set_material(_create_mat(color, false))
	var mesh = st.commit()
	
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in segments:
		var next = (k + 1) % segments
		st.add_vertex(Vector3.ZERO); st.add_vertex(v_in[k]); st.add_vertex(v_in[next])
	st.generate_normals()
	st.set_material(_create_mat(color, true))
	return st.commit(mesh)

func _create_mat(color: Color, is_fill: bool) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	
	if is_fill:
		mat.albedo_color = Color(color.r, color.g, color.b, 0.2) # 80% transparencia
	else:
		mat.albedo_color = Color(color.r, color.g, color.b, 0.7) # 30% transparencia
	return mat
