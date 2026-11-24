class_name NutrientDrop
extends MeshInstance3D

var target_y: float = 0.0
var nutrient_type: String = ""
var amount: float = 0.0
var view_ref: Node = null
var fall_speed: float = 6.0

func setup(pos: Vector3, n_type: String, n_amount: float, view: Node, color: Color):
	target_y = pos.y
	nutrient_type = n_type
	amount = n_amount
	view_ref = view
	
	global_position = pos + Vector3(0, 1.2, 0)
	
	mesh = _create_drop_mesh(nutrient_type, color)

func _create_drop_mesh(type: String, color: Color) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var r_out = 0.08
	var r_in = 0.04
	var v = []
	var i = []
	
	if type == "carbon":
		# Triángulo
		v = [Vector3(0, 0, r_out), Vector3(-r_out * 0.866, 0, -r_out * 0.5), Vector3(r_out * 0.866, 0, -r_out * 0.5)]
		i = [Vector3(0, 0, r_in), Vector3(-r_in * 0.866, 0, -r_in * 0.5), Vector3(r_in * 0.866, 0, -r_in * 0.5)]
	elif type == "nitrogen":
		# Círculo
		var segments = 10
		for k in segments:
			var a = (float(k) / segments) * TAU
			v.append(Vector3(cos(a) * r_out/2, 0, sin(a) * r_out/2))
			i.append(Vector3(cos(a) * r_in/2, 0, sin(a) * r_in/2))
	else:
		# Cuadrado
		v = [Vector3(-r_out/2, 0, -r_out/2), Vector3(r_out/2, 0, -r_out/2), Vector3(r_out/2, 0, r_out/2), Vector3(-r_out/2, 0, r_out/2)]
		i = [Vector3(-r_in/2, 0, -r_in/2), Vector3(r_in/2, 0, -r_in/2), Vector3(r_in/2, 0, r_in/2), Vector3(-r_in/2, 0, r_in/2)]
	
	var count = v.size()
	
	# 1. Borde (Stroke)
	for k in count:
		var next = (k + 1) % count
		st.add_vertex(v[k]); st.add_vertex(v[next]); st.add_vertex(i[next])
		st.add_vertex(v[k]); st.add_vertex(i[next]); st.add_vertex(i[k])
	st.generate_normals()
	st.set_material(_create_mat(color, false))
	var result_mesh = st.commit()
	
	# 2. Relleno (Fill)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if type == "carbon":
		st.add_vertex(i[0]); st.add_vertex(i[1]); st.add_vertex(i[2])
	elif type == "nitrogen":
		for k in count:
			var next = (k + 1) % count
			st.add_vertex(Vector3.ZERO); st.add_vertex(i[k]); st.add_vertex(i[next])
	else:
		st.add_vertex(i[0]); st.add_vertex(i[1]); st.add_vertex(i[2])
		st.add_vertex(i[0]); st.add_vertex(i[2]); st.add_vertex(i[3])
	st.generate_normals()
	st.set_material(_create_mat(color, true))
	
	return st.commit(result_mesh)

func _create_mat(color: Color, is_fill: bool) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	
	if is_fill:
		mat.albedo_color = Color(color.r, color.g, color.b, 0.2)
	else:
		mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	return mat

func _process(delta: float) -> void:
	global_position.y -= fall_speed * delta
	rotate_y(delta * 8.0)
	
	if global_position.y <= target_y:
		if is_instance_valid(view_ref):
			view_ref.add_nutrient_at(global_position, nutrient_type, amount)
		queue_free()
