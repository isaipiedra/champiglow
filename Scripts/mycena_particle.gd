extends Node3D

#Referencia a hijo para las físicas
@onready var rigid_body: RigidBody3D = $RigidBody3D

var actual_wind: Vector3 = Vector3.ZERO
var humidity: float = 0.0

#Funcion que recibe el viento del main
func fetch_environmental_factors(wind: Vector3) -> void:
	actual_wind = wind
	print("Se inició la particula con viento");

func _physics_process(delta: float) -> void:
	if rigid_body and actual_wind != Vector3.ZERO:
		rigid_body.apply_central_force(actual_wind)
