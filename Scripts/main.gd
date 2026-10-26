extends Node3D

@export var mycena_scene: PackedScene
@export var wind_force: Vector3 = Vector3(1.5,0.0,0.8) #Fuerza del viento

var array_mycena_particles: Array = [] #Arreglo para almacenar todas las esferas

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Prueba de particulas")

#Detecta entradas como clics del mouse
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		generate_particle()


func generate_particle(): 
	if not mycena_scene:
		print("No se ha añadido la escena en el Inspector")
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = $Camera3D.project_ray_origin(mouse_pos)
	var ray_direction = $Camera3D.project_ray_normal(mouse_pos)
	
	var new_particle = mycena_scene.instantiate()
	new_particle.global_position = ray_origin + ray_direction * 10.0
	
	add_child(new_particle)
	
	if new_particle.has_method("fetch_environmental_factors"):
		new_particle.fetch_environmental_factors(wind_force)
	
	array_mycena_particles.append(new_particle)
	
	print("Se añadio la particula")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
