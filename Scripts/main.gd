extends Node3D

@export var mycena_scene: PackedScene
@export var amanita_scene: PackedScene
@export var wind_pivot: Node3D   # asigna windControl en el Inspector

@export var wind_force: Vector3 = Vector3.ZERO   # Fuerza del viento (se calcula desde el pivote)

@onready var label_time = $CanvasLayer/Control/Label_Time
@onready var label_temperature = $CanvasLayer/Control/Label_Temperature
@onready var label_humidity = $CanvasLayer/Control/Label_Humidity
@onready var label_selected_fungus = $CanvasLayer/Control/Label_Selected_Fungus

var wind_value := 0.5
var time_speed_mul := 1
var original_day_length := 0.0
var is_night := false
var is_day := false
var temperature_celsius := 0.0
var humidity_percentage := 0.0
var chosen_fungus := 0   # 0 = Amanita, 1 = Mycena

var array_mycena_particles: Array = []
var array_amanita_particles: Array = []

var _last_wind_angle := INF


func _ready() -> void:
	original_day_length = $sky.day_length
	_update_time_label()
	label_temperature.text = "Temperatura %.1f °C" % temperature_celsius
	label_humidity.text = "Porcentaje de Humedad: %.1f" % humidity_percentage
	_update_fungus_label()


func _update_time_label() -> void:
	if $sky.auto_advance:
		label_time.text = "Velocidad de día: x%d" % time_speed_mul
	else:
		label_time.text = "Velocidad de día: x0 - Tiempo detenido"


func _update_fungus_label() -> void:
	label_selected_fungus.text = "Amanita Muscaria" if chosen_fungus == 0 else "Mycena Chlorophos"


# Viento: rotación 0 del pivote = viento hacia el sur (+Z). Gira 360° con el pivote.
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		generate_particle()

	if not (event is InputEventKey and event.pressed):
		return

	# Temperatura y humedad (permiten mantener la tecla)
	match event.keycode:
		KEY_O:
			temperature_celsius += 0.5
			label_temperature.text = "Temperatura %.1f °C" % temperature_celsius
		KEY_I:
			temperature_celsius -= 0.5
			label_temperature.text = "Temperatura %.1f °C" % temperature_celsius
		KEY_K:
			humidity_percentage += 0.5
			label_humidity.text = "Porcentaje de Humedad: %.1f" % humidity_percentage
		KEY_J:
			humidity_percentage -= 0.5
			label_humidity.text = "Porcentaje de Humedad: %.1f" % humidity_percentage

	if event.echo:
		return

	match event.keycode:
		KEY_R:  # Acelerar el tiempo
			if $sky.auto_advance:
				time_speed_mul = time_speed_mul * 2 if time_speed_mul < 4 else 1
				$sky.day_length = original_day_length / time_speed_mul
				_update_time_label()
		KEY_SPACE:  # Detener / reanudar el tiempo
			$sky.auto_advance = not $sky.auto_advance
			_update_time_label()
		KEY_H:  # Cambiar hongo
			chosen_fungus = 1 - chosen_fungus
			_update_fungus_label()


func generate_particle() -> void:
	var scene := amanita_scene if chosen_fungus == 0 else mycena_scene
	if not scene:
		print("No se ha añadido la escena en el Inspector")
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin: Vector3 = $Camera3D.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = $Camera3D.project_ray_normal(mouse_pos)

	var new_particle = scene.instantiate()
	new_particle.global_position = ray_origin + ray_direction * 5.0
	add_child(new_particle)

	if new_particle.has_method("fetch_environmental_factors"):
		new_particle.fetch_environmental_factors(wind_force)

	if chosen_fungus == 0:
		array_amanita_particles.append(new_particle)
	else:
		array_mycena_particles.append(new_particle)


func _process(_delta: float) -> void:
	update_wind_from_pivot()

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
			is_night = false
			for particle in array_mycena_particles:
				if is_instance_valid(particle):
					particle.its_day()
