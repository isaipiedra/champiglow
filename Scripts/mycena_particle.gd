extends Node3D

signal landed(spore: Node3D, body: Node3D)

@onready var rigid_body: RigidBody3D = $RigidBody3D
@export var lifetime_after_landing: float = 15.0

@export_group("Día y noche")
@export var day_air_drag: float = 3.0
@export var night_air_drag: float = 1.8
@export var day_gravity_scale: float = 0.02
@export var night_gravity_scale: float = 0.09 
@export_group("")

@export var initial_impulse: float = 0.05
@export var wind_influence: float = 0.9 

var actual_wind: Vector3 = Vector3.ZERO
var humidity: float = 0.0
var has_landed: bool = false
var isDay: bool = true

func _ready() -> void:
	rigid_body.mass = 0.05
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
	rigid_body.gravity_scale = night_gravity_scale
	rigid_body.linear_damp = night_air_drag
	isDay = false

func its_day() -> void:
	rigid_body.gravity_scale = day_gravity_scale
	rigid_body.linear_damp = day_air_drag
	isDay = true

func _physics_process(_delta: float) -> void:
	if not has_landed and actual_wind != Vector3.ZERO:
		rigid_body.apply_central_force(actual_wind * wind_influence * rigid_body.mass)
		
func init_shot(direction: Vector3) -> void:
	var impulse_to_apply = initial_impulse
	if not isDay:
		impulse_to_apply = initial_impulse * 2.0
	
	rigid_body.apply_central_impulse(direction.normalized() * impulse_to_apply)

func _on_body_entered(body: Node3D) -> void:
	if has_landed or body == rigid_body or body.is_in_group("mycena_spore_body"):
		return
		
	has_landed = true
	rigid_body.linear_velocity = Vector3.ZERO
	rigid_body.angular_velocity = Vector3.ZERO
	rigid_body.freeze = true
	
	landed.emit(self, body)

func _remove_after_landing() -> void:
	await get_tree().create_timer(lifetime_after_landing).timeout
	if is_inside_tree():
		queue_free()
