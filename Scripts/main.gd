extends Node3D

@export var mycena_scene: PackedScene
@export var amanita_scene: PackedScene

@export var wind_force: Vector3 = Vector3(0,0.0,0) #Fuerza del viento

@onready var label_time = $CanvasLayer/Control/Label_Time
@onready var label_wind_direction = $CanvasLayer/Control/Label_Wind_Direction
@onready var label_temperature = $CanvasLayer/Control/Label_Temperature
@onready var label_humidity = $CanvasLayer/Control/Label_Humidity
@onready var label_selected_fungus = $CanvasLayer/Control/Label_Selected_Fungus

var wind_value = 0.5
var time_speed_mul = 1
var original_day_length = 0
var is_night = false
var is_day = false
var temperature_celsius = 0;
var humidity_percentage = 0;
var chosen_fungus = 0; #0 Para Amanita y 1 para y mycena

var array_mycena_particles: Array = [] #Arreglo para almacenar todas las particulas de Mycena
var array_amanita_particles: Array = [] #Arreglo para particulas de amanita

var wind_direction_text = "Ninguna"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var advancing = $sky.auto_advance 
	if label_time:
		if advancing:
			label_time.text = "Velocidad de día: x%d" % [time_speed_mul]
		else:
			label_time.text = "Velocidad de día: x%d - Tiempo detenido" % [0]
			
		original_day_length = $sky.day_length
		label_wind_direction.text = "Dirección del viento: " + wind_direction_text
		label_temperature.text = "Temperatura %.1f °C" % [temperature_celsius]
		label_humidity.text = "Porcetaje de Humedad: %.1f" % [humidity_percentage]
		label_selected_fungus.text = "Amanita Muscaria" if chosen_fungus == 0 else "Mycena Chlorophos"
		
#Detecta entradas como clics del mouse
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		generate_particle()
	#control de dirección del viento
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT || event.keycode == KEY_LEFT || event.keycode == KEY_UP || event.keycode == KEY_DOWN: 
			#todo esto desde la perspectiva de incio del juego, sin mover la cámara
			match event.keycode:
				KEY_RIGHT: #Viento hacia la derecha
					wind_force = Vector3(wind_value,0.0,0.0)
					wind_direction_text = "Este a Oeste"
				KEY_LEFT: #viento hacia la izquierda
					wind_force = Vector3(-wind_value,0.0,0.0)
					wind_direction_text = "Oeste a Este"
				KEY_UP: #Viento hacia el frente
					wind_force = Vector3(0.0,0.0,wind_value)
					wind_direction_text = "Sur a Norte"
				KEY_DOWN: #Viento acia atras
					wind_force = Vector3(0.0,0.0,-wind_value)
					wind_direction_text = "Norte a sur"
					
			label_wind_direction.text = "Dirección del viento: " + wind_direction_text
			for particle in array_mycena_particles:
				if is_instance_valid(particle):
					particle.change_actual_wind(wind_force)
		
		#Acelerar el tiempo			
		if event.keycode == KEY_R && $sky.auto_advance:
			if time_speed_mul < 4:
				time_speed_mul *= 2
			else: 
				time_speed_mul = 1
				
			$sky.day_length = original_day_length / time_speed_mul
			
			label_time.text = "Velocidad de día: x%d" % [time_speed_mul]
			print($sky.day_length)
		
		#Detención del tiempo actual
		if event.keycode == KEY_SPACE:
			var advancing = !$sky.auto_advance 
			$sky.auto_advance = advancing
			if not advancing:
				label_time.text = "Velocidad de día: x%d - Tiempo detenido" % [0]
			else:
				label_time.text = "Velocidad de día: x%d" % [time_speed_mul]
		
		#Seleccion de hongo
		if event.keycode == KEY_H:
			chosen_fungus = 0 if chosen_fungus == 1 else 1
			label_selected_fungus.text = "Amanita Muscaria" if chosen_fungus == 0 else "Mycena Chlorophos"
		
		if event.keycode == KEY_O:
			temperature_celsius += 0.5
			label_temperature.text = "Temperatura %.1f °C" % [temperature_celsius]

		#Disminuir temperatura
		if event.keycode == KEY_I:
			temperature_celsius -= 0.5
			label_temperature.text = "Temperatura %.1f °C" % [temperature_celsius]
		
		#Aumentar la humedad del ambiente
		if event.keycode == KEY_K:
			humidity_percentage += 0.5
			label_humidity.text = "Porcetaje de Humedad: %.1f" % [humidity_percentage]
			
		if event.keycode == KEY_J:
			humidity_percentage -= 0.5
			label_humidity.text = "Porcetaje de Humedad: %.1f" % [humidity_percentage]
			
	elif event is InputEventKey and event.pressed:
		#Aumentar temperatura
		if event.keycode == KEY_O:
			temperature_celsius += 0.5
			label_temperature.text = "Temperatura %.1f °C" % [temperature_celsius]

		#Disminuir temperatura
		if event.keycode == KEY_I:
			temperature_celsius -= 0.5
			label_temperature.text = "Temperatura %.1f °C" % [temperature_celsius]
		
		#Aumentar la humedad del ambiente
		if event.keycode == KEY_K:
			humidity_percentage += 0.5
			label_humidity.text = "Porcetaje de Humedad: %.1f" % [humidity_percentage]
			
		if event.keycode == KEY_J:
			humidity_percentage -= 0.5
			label_humidity.text = "Porcetaje de Humedad: %.1f" % [humidity_percentage]
		
			
func generate_particle(): 
	if not mycena_scene:
		print("No se ha añadido la escena en el Inspector")
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = $Camera3D.project_ray_origin(mouse_pos)
	var ray_direction = $Camera3D.project_ray_normal(mouse_pos)
	
	var new_particle = amanita_scene.instantiate() if chosen_fungus == 0 else mycena_scene.instantiate()
	new_particle.global_position = ray_origin + ray_direction * 5.0
	
	add_child(new_particle)
	
	if new_particle.has_method("fetch_environmental_factors"):
		new_particle.fetch_environmental_factors(wind_force)
	
	if chosen_fungus == 0:
		array_amanita_particles.append(new_particle)
	else:
		array_mycena_particles.append(new_particle)

	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if $sky.time_of_day >= 18.0 and not is_night:
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
			
	pass
