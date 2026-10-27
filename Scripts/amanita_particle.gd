extends Node3D

#Referencia a hijo para las físicas
@onready var rigid_body: RigidBody3D = $RigidBody3D

var actual_wind: Vector3 = Vector3.ZERO
var humidity: float = 0.0

func _ready() -> void:
		rigid_body.gravity_scale = 0.1

	
#Funcion que recibe el viento del main
func fetch_environmental_factors(wind: Vector3) -> void:
	actual_wind = wind
		
func change_actual_wind(wind: Vector3) -> void:
	actual_wind = wind
	
func its_night() -> void:
	rigid_body.gravity_scale = 0.1


func its_day() -> void:
	rigid_body.gravity_scale = 0.0001

	

func _physics_process(delta: float) -> void:
	if rigid_body and actual_wind != Vector3.ZERO:
		rigid_body.apply_central_force(actual_wind)
