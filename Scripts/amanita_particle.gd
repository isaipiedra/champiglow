extends Node3D

## Cuando la espora toca el suelo.
signal landed(spore: Node3D, position: Vector3)

## La capa del suelo
@export_flags_3d_physics var ground_mask: int = 1

@onready var rigid_body: RigidBody3D = $RigidBody3D

var actual_wind: Vector3 = Vector3.ZERO
var humidity: float = 0.0

var _touched_ground := false
var _has_landed := false


func _ready() -> void:
	rigid_body.gravity_scale = 0.1
	# La espora solo choca con el suelo
	rigid_body.collision_layer = 1 << 1 
	rigid_body.collision_mask = ground_mask
	rigid_body.contact_monitor = true
	rigid_body.max_contacts_reported = 1
	rigid_body.body_entered.connect(_on_body_entered)


func fetch_environmental_factors(wind: Vector3) -> void:
	actual_wind = wind


func change_actual_wind(wind: Vector3) -> void:
	actual_wind = wind


func its_night() -> void:
	rigid_body.gravity_scale = 0.1


func its_day() -> void:
	rigid_body.gravity_scale = 0.0001


func _on_body_entered(_body: Node) -> void:
	_touched_ground = true


func _physics_process(_delta: float) -> void:
	if _touched_ground and not _has_landed:
		_has_landed = true
		_emit_landing()
		return
	if rigid_body and actual_wind != Vector3.ZERO:
		rigid_body.apply_central_force(actual_wind)


func _emit_landing() -> void:
	var origin := rigid_body.global_position
	var query := PhysicsRayQueryParameters3D.create(
		origin + Vector3.UP * 0.1, origin + Vector3.DOWN * 0.3, ground_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	landed.emit(self, hit.get("position", origin))
	queue_free()
