extends Node3D

@export var mycena_scene: PackedScene
@export var wind_force: Vector3 = Vector3(0,0.0,0) #Fuerza del viento

@onready var label_time = $CanvasLayer/Control/Label_Time
@onready var label_wind_direction = $CanvasLayer/Control/Label_Wind_Direction

var wind_value = 0.5
var time_speed_mul = 1
var original_day_length = 0
var array_mycena_particles: Array = [] #Arreglo para almacenar todas las esferas
var wind_direction_text = "Ninguna"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Prueba de particulas")
	if label_time:
		label_time.text = "Velocidad de día: x%d" % [time_speed_mul]
		original_day_length = $sky.day_length
		label_wind_direction.text = "Dirección del viento: " + wind_direction_text
#Detecta entradas como clics del mouse
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		generate_particle()
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
					
		if event.keycode == KEY_R:
			if time_speed_mul < 4:
				time_speed_mul *= 2
			else: 
				time_speed_mul = 1
				
			$sky.day_length = original_day_length / time_speed_mul
			
			label_time.text = "Velocidad de día: x%d" % [time_speed_mul]
			print($sky.day_length)
			
				
			


func generate_particle(): 
	if not mycena_scene:
		print("No se ha añadido la escena en el Inspector")
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = $Camera3D.project_ray_origin(mouse_pos)
	var ray_direction = $Camera3D.project_ray_normal(mouse_pos)
	
	var new_particle = mycena_scene.instantiate()
	new_particle.global_position = ray_origin + ray_direction * 5.0
	
	add_child(new_particle)
	
	if new_particle.has_method("fetch_environmental_factors"):
		new_particle.fetch_environmental_factors(wind_force)
	
	array_mycena_particles.append(new_particle)
	
	print("Se añadio la particula")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
