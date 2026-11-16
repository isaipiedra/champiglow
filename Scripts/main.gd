extends Node3D

@export var mycena_scene: PackedScene
@export var amanita_scene: PackedScene
@export var mycena_model_scene: PackedScene #Modelo del cuerpod el hongo mycena
@export var wind_pivot: Node3D

@export var wind_force: Vector3 = Vector3.ZERO   # (se calcula desde el pivote)

@export var amanita_mushroom_scenes: Array[PackedScene] = []
@export var mushroom_scale := 1.0
@export var mushroom_grow_time := 1.5
@export var growth_days := 28.0

#Generación de esporas
@export var spore_interval: float = 2
var spore_timer: float = 0.0


@export var living_tree_models: PackedStringArray = ["MapleTree"]
@export var tree_radius := 1.5
var _living_tree_positions: Array[Vector2] = []

@export_flags_3d_physics var mushroom_layer: int = 8

@onready var label_time = $CanvasLayer/Interface/Label_Time
@onready var label_temperature = $CanvasLayer/Interface/Label_Temperature
@onready var label_humidity = $CanvasLayer/Interface/Label_Humidity
@onready var label_selected_fungus = $CanvasLayer/Interface/Label_Selected_Fungus

# --- nodos de la interfaz ---
@onready var ui: Node = $CanvasLayer/Interface
@onready var temp_slider: Range = _find(ui.get_node("sliders/slider"), "Range")
@onready var humidity_slider: Range = _find(ui.get_node("sliders/humidity-slider"), "Range")
@onready var play_button: BaseButton = _find(ui.get_node("time/PlayButton"), "BaseButton")
@onready var forward_button: BaseButton = _find(ui.get_node("time/forward_button"), "BaseButton")
@onready var red_button: BaseButton = _find(ui.get_node("mushrooms/Control/red"), "BaseButton")
@onready var glow_button: BaseButton = _find(ui.get_node("mushrooms/Control2/glow"), "BaseButton")

# --- nodos de las vistas ---
@onready var wind_view: Node3D = $WindView
@onready var wind_toggle: BaseButton = ui.get_node("views/WindToggle")
@onready var nutrient_view: Node3D = $NutrientView
@onready var nutrients_toggle: BaseButton = ui.get_node("views/nutrients_toggle")
@onready var carbon_button: BaseButton = ui.get_node("nutrients/carbon_button")
@onready var nitrogen_button: BaseButton = ui.get_node("nutrients/nitrogen_button")
@onready var metals_button: BaseButton = ui.get_node("nutrients/metals_button")


var wind_value := 1
var time_speed_mul := 1
var original_day_length := 0.0
var is_night := false
var is_day := false
var temperature_celsius := 0.0
var humidity_percentage := 0.0
var chosen_fungus := 0   # 0 = Amanita, 1 = Mycena
var _last_time_of_day: float = 0.0

var array_mycena_particles: Array = []
var array_amanita_particles: Array = []
var grown_mycenas: Array[Node3D] = [] #Lista de hongos mycena
var array_mushrooms_generating_mycenas: Array = []
var array_mushrooms_generating_amanita: Array = []

var _last_wind_angle := INF

var _pending_mushrooms: Array[Dictionary] = []

# Busca el slider o botón dentro de la escena instanciada
func _find(node: Node, type: String) -> Node:
	if node.is_class(type):
		return node
	return node.find_children("*", type, true, false)[0]


func _ready() -> void:
	original_day_length = $sky.day_length
	_last_time_of_day = $sky.time_of_day

	# Evita que la barra espaciadora presione el último botón tocado
	for c in ui.find_children("*", "Control", true, false):
		c.focus_mode = Control.FOCUS_NONE

	temp_slider.value_changed.connect(_set_temperature)
	humidity_slider.value_changed.connect(_set_humidity)
	forward_button.pressed.connect(_cycle_speed)
	play_button.pressed.connect(_toggle_time)
	red_button.pressed.connect(_set_fungus.bind(0))    # Amanita
	glow_button.pressed.connect(_set_fungus.bind(1))   # Mycena
	wind_toggle.toggled.connect(_on_wind_toggle)
	nutrients_toggle.toggled.connect(_on_nutrients_toggle)
	
	carbon_button.pressed.connect(_on_add_nutrient.bind("carbon", 10.0))
	nitrogen_button.pressed.connect(_on_add_nutrient.bind("nitrogen", 10.0))
	metals_button.pressed.connect(_on_add_nutrient.bind("metals", 10.0))

	_set_temperature(temperature_celsius)
	_set_humidity(humidity_percentage)
	_update_time_label()
	_update_fungus_label()
	_collect_living_trees()
	

# ---------- teclas e interfaz ----------
func _set_temperature(v: float) -> void:
	temperature_celsius = clampf(v, 0.0, 100.0)
	label_temperature.text = "Temperatura %.1f °C" % temperature_celsius
	temp_slider.value = temperature_celsius
	_notify_mycenas_environment()


func _set_humidity(v: float) -> void:
	humidity_percentage = clampf(v, 0.0, 100.0)
	label_humidity.text = "Porcentaje de Humedad: %.1f" % humidity_percentage
	humidity_slider.value = humidity_percentage
	_notify_mycenas_environment()



func _cycle_speed() -> void:
	time_speed_mul = time_speed_mul * 2 if time_speed_mul < 16 else 1
	$sky.day_length = original_day_length / time_speed_mul
	_update_time_label()


func _toggle_time() -> void:
	$sky.auto_advance = not $sky.auto_advance
	_update_time_label()


func _set_fungus(id: int) -> void:
	chosen_fungus = id
	_update_fungus_label()


# ---------- labels  ----------
func _update_time_label() -> void:
	if $sky.auto_advance:
		label_time.text = "Velocidad de día: x%d" % time_speed_mul
	else:
		label_time.text = "Velocidad de día: x0 - Tiempo detenido"
	play_button.button_pressed = not $sky.auto_advance  # pressed = tiempo corriendo


func _update_fungus_label() -> void:
	label_selected_fungus.text = "Amanita Muscaria" if chosen_fungus == 0 else "Mycena Chlorophos"
	red_button.button_pressed = (chosen_fungus == 0)
	glow_button.button_pressed = (chosen_fungus == 1)

# ---------- viento ----------
func update_wind_from_pivot() -> void:
	if not wind_pivot:
		return
	var angle := fposmod(wind_pivot.rotation.y, TAU)
	if absf(angle - _last_wind_angle) < 0.005:
		return
	_last_wind_angle = angle

	wind_force = Vector3(0.0, 0.0, wind_value).rotated(Vector3.UP, angle)

	for particle in array_mycena_particles + array_amanita_particles:
		if is_instance_valid(particle):
			particle.change_actual_wind(wind_force)

func _on_wind_toggle(toggled_on: bool) -> void:
	wind_view.visible = toggled_on

# ---------- entrada ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		generate_particle()

	if not (event is InputEventKey and event.pressed):
		return

	match event.keycode:
		KEY_O: _set_temperature(temperature_celsius + 1)
		KEY_I: _set_temperature(temperature_celsius - 1)
		KEY_K: _set_humidity(humidity_percentage + 1)
		KEY_J: _set_humidity(humidity_percentage - 1)

	if event.echo:
		return

	match event.keycode:
		KEY_R: forward_button.pressed.emit()
		KEY_SPACE: _toggle_time()
		KEY_H: _set_fungus(1 - chosen_fungus)

func are_mycena_conditions_optimal() -> bool:
	return (temperature_celsius >= 8.0 and temperature_celsius <= 27.0 and humidity_percentage >= 70.0)
	
# ---------- Hongos -------------

func _update_pending_mushrooms() -> void:
	var now: float = $sky.elapsed_days
	for i in range(_pending_mushrooms.size() - 1, -1, -1):
		if now >= _pending_mushrooms[i]["ready_at"]:
			_grow_amanita(_pending_mushrooms[i]["pos"])
			_pending_mushrooms.remove_at(i)

func _on_amanita_landed(spore: Node3D, pos: Vector3) -> void:
	array_amanita_particles.erase(spore)
	var flat := Vector2(pos.x, pos.z)
	var nearest := INF
	for t in _living_tree_positions:
		nearest = minf(nearest, flat.distance_to(t))
	if _is_near_living_tree(pos):
		_pending_mushrooms.append({"pos": pos, "ready_at": $sky.elapsed_days + growth_days})


func _grow_amanita(pos: Vector3) -> void:
	if amanita_mushroom_scenes.is_empty() || amanita_mushroom_scenes[0] == null:
		push_warning("No hay estos hongos")
		return

	var mushroom := amanita_mushroom_scenes[0].instantiate() as Node3D
	add_child(mushroom)
	mushroom.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), pos)

	var body := mushroom as CollisionObject3D
	if body:
		body.collision_layer = mushroom_layer

	var target := mushroom_scale * randf_range(0.9, 1.1)
	mushroom.scale = Vector3.ONE * target * 0.01
	create_tween().tween_property(mushroom, "scale", Vector3.ONE * target, mushroom_grow_time)

func _collect_living_trees() -> void:
	_living_tree_positions.clear()
	for node in find_children("*", "Node3D", true, false):
		var tree := node as Node3D
		var file_name := tree.scene_file_path.get_file()
		if file_name.is_empty():
			continue
		for model in living_tree_models:
			if file_name.begins_with(model):
				var origin := tree.global_position
				var meshes := tree.find_children("*", "MeshInstance3D", true, false)
				if not meshes.is_empty():
					origin = (meshes[0] as Node3D).global_position
				_living_tree_positions.append(Vector2(origin.x, origin.z))
				#print("Árbol vivo: ", tree.name, " en ", origin)
				break
	

func _is_near_living_tree(pos: Vector3) -> bool:
	var flat := Vector2(pos.x, pos.z)
	var max_dist_sq := tree_radius * tree_radius
	for tree_pos in _living_tree_positions:
		if flat.distance_squared_to(tree_pos) <= max_dist_sq:
			return true
	return false

# ---------- partículas ----------
func generate_particle() -> void:
	var scene := amanita_scene if chosen_fungus == 0 else mycena_scene
	if not scene:
		print("No tiene nada la amanita_scene")
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin: Vector3 = $Camera3D.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = $Camera3D.project_ray_normal(mouse_pos)

	var new_particle = scene.instantiate()
	new_particle.global_position = ray_origin + ray_direction * 5.0
	if chosen_fungus == 1 and new_particle.has_signal("landed"):
		new_particle.connect("landed", Callable(self, "_on_mycena_spore_landed"))
	add_child(new_particle)
	new_particle.global_position = ray_origin + ray_direction * 5.0
	

	if new_particle.has_method("fetch_environmental_factors"):
		new_particle.fetch_environmental_factors(wind_force)
		
	if chosen_fungus == 1:
		if $sky.time_of_day >= 18.0:
			new_particle.its_night()
		else:
			new_particle.its_day()

	if chosen_fungus == 0:
		array_amanita_particles.append(new_particle)
		new_particle.landed.connect(_on_amanita_landed)
	else:
		array_mycena_particles.append(new_particle)

func _on_mycena_spore_landed(spore: Node3D, body: Node3D) -> void:
	if not is_instance_valid(spore) or not is_instance_valid(body):
		return

	if not body.is_in_group("mycena_host"):
		spore.queue_free()
		return
	
	if not  are_mycena_conditions_optimal():
		spore.queue_free()
		return

	
	if mycena_model_scene == null:
		print("Falta mycena_model en el main")
	
	var spore_body := spore.get_node_or_null("RigidBody3D") as RigidBody3D
	
	if spore_body == null:
		print("La espora no tiene hijo RigidBody3D")
		return
	
	var mushroom := mycena_model_scene.instantiate() as Node3D
	mushroom.fruit_died.connect(_on_mycena_died)
	mushroom.spores_started.connect(_on_spores_started)
	mushroom.spores_stopped.connect(_on_spores_stopped)
	
	add_child(mushroom)
	
	mushroom.global_position = (spore_body.global_position - Vector3.UP * 0.004)
	
	grown_mycenas.append(mushroom)
	
	mushroom.set_environment_conditions(temperature_celsius, humidity_percentage,
		time_speed_mul)
	
	spore.queue_free()
	
func _advance_mycena_growth_days() -> void:
	for mushroom in grown_mycenas:
		if (is_instance_valid(mushroom) and mushroom.has_method("advance_growth_day")):
			mushroom.advance_growth_day()

#Funciones relacionadas a pudrirse y esparcir esporas
func _on_spores_started(mushroom: Node3D) -> void:
	if not array_mushrooms_generating_mycenas.has(mushroom):
		array_mushrooms_generating_mycenas.append(mushroom)


func _on_spores_stopped(mushroom: Node3D) -> void:
	array_mushrooms_generating_mycenas.erase(mushroom)
	
	
func _on_mycena_died(mushroom: Node3D) -> void:
	grown_mycenas.erase(mushroom)
	mushroom.queue_free()

func _generate_mycena_spore(mushroom: Node3D) -> void:
	
	if not mushroom.can_generate_spores():
		array_mushrooms_generating_mycenas.erase(mushroom)
		return
	
	if mycena_scene == null:
		return
	var cap := mushroom.get_node_or_null("Cap") as Node3D
	var spore := mycena_scene.instantiate() as Node3D
	
	add_child(spore)
	spore.global_position.x = cap.global_position.x
	spore.global_position.y = cap.global_position.y + 0.2
	spore.global_position.z = cap.global_position.z
	
	var direction := Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3)).normalized()

	
	if spore.has_signal("landed"):
		spore.landed.connect(_on_mycena_spore_landed)
	
	if spore.has_method("fetch_environmental_factors"):
		spore.fetch_environmental_factors(wind_force)
	
	if $sky.time_of_day >= 18.0:
		spore.its_night()
	else:
		spore.its_day()
		
	spore.init_shot(direction) 


	array_mycena_particles.append(spore)
	mushroom.register_spore_generation()

#Podrirse
func _notify_mycenas_environment() -> void:
	for mushroom in grown_mycenas:
		if is_instance_valid(mushroom):
			mushroom.set_environment_conditions(temperature_celsius, humidity_percentage, time_speed_mul)
	
func _process(delta: float) -> void:
	update_wind_from_pivot()
	
	var current_time: float = $sky.time_of_day

	_update_pending_mushrooms()
	if wind_view.visible:
		wind_view.update_arrows(wind_force)
		
	if $sky.time_of_day >= 18.0:
		if not is_night:
			is_night = true
			is_day = false
			for particle in array_mycena_particles:
				if is_instance_valid(particle):
					particle.its_night()
	else:
		if not is_day:
			is_day = true
			is_day = true
			is_night = false
			for particle in array_mycena_particles:
				if is_instance_valid(particle):
					particle.its_day()
	
	if not array_mushrooms_generating_mycenas.is_empty():
		spore_timer += delta * time_speed_mul

		if spore_timer >= spore_interval:
			spore_timer -= spore_interval

			for mushroom in array_mushrooms_generating_mycenas.duplicate():
				if is_instance_valid(mushroom):
					_generate_mycena_spore(mushroom)
				else:
					array_mushrooms_generating_mycenas.erase(mushroom)
				
	if current_time < _last_time_of_day:
		_advance_mycena_growth_days()
	_last_time_of_day = current_time

# ---------- nutrientes ----------
func _on_nutrients_toggle(toggled_on: bool) -> void:
	nutrient_view.visible = toggled_on
	if toggled_on:
		# Obligamos a que actualice los tamaños al encenderse
		nutrient_view.call_deferred("_update_visuals")

func _on_add_nutrient(nutrient_type: String, amount: float) -> void:
	nutrient_view.add_nutrient(nutrient_type, amount)
