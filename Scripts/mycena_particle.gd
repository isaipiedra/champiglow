
extends Node3D

signal landed(spore: Node3D, body: Node3D)

@onready var rigid_body: RigidBody3D = $RigidBody3D
@export var lifetime_after_landing: float = 15.0
@export var day_air_drag: float = 1
@export var night_air_drag: float = 0.0

var actual_wind: Vector3 = Vector3.ZERO
var humidity: float = 0.0
var has_landed: bool = false


func _ready() -> void:
	rigid_body.gravity_scale = 0.1

	rigid_body.contact_monitor = true
	rigid_body.max_contacts_reported = 4
	
	rigid_body.add_to_group("mycena_spore_body")

	rigid_body.body_entered.connect(_on_body_entered)


func fetch_environmental_factors(wind: Vector3) -> void:
	actual_wind = wind


func change_actual_wind(wind: Vector3) -> void:
	actual_wind = wind


func its_night() -> void:
	rigid_body.gravity_scale = 0.1
	rigid_body.linear_damp = night_air_drag
	print("NOCHE | Gravedad: ", rigid_body.gravity_scale,
		  " | Amortiguación: ", rigid_body.linear_damp)


func its_day() -> void:
	rigid_body.gravity_scale = 0.001
	rigid_body.linear_damp = day_air_drag
	print("DÍA | Gravedad: ", rigid_body.gravity_scale,
		  " | Amortiguación: ", rigid_body.linear_damp)


func _physics_process(_delta: float) -> void:
	if not has_landed and actual_wind != Vector3.ZERO:
		rigid_body.apply_central_force(actual_wind)



func _on_body_entered(body: Node3D) -> void:
	if has_landed:
		return

	if body == rigid_body:
		return

	if body.is_in_group("mycena_spore_body"):
		return
		
	has_landed = true
	rigid_body.linear_velocity = Vector3.ZERO
	rigid_body.angular_velocity = Vector3.ZERO
	rigid_body.freeze = true
	
	landed.emit(self, body)
	
	print("Cuerpo de colisión: ", body.get_path())
	print("Grupos del cuerpo: ", body.get_groups())
	print("¿Es huésped?: ", body.is_in_group("mycena_host"))

	if body.is_in_group("mycena_host"):
		print("¡Espora aterrizó en el tronco! Puede intentar germinar.")
	else:
		print("Espora aterrizó en otra superficie: ", body.name)




func _remove_after_landing() -> void:
	await get_tree().create_timer(lifetime_after_landing).timeout

	if is_inside_tree():
		queue_free()
