extends Camera3D

@export var main_camera: Camera3D
@export var target: Node3D
@export var distance := 4.0
@export var yaw_only := false

func _process(_delta: float) -> void:
	if not main_camera or not target:
		return
	var b := main_camera.global_transform.basis
	if yaw_only:
		b = Basis.from_euler(Vector3(0.0, main_camera.global_rotation.y, 0.0))
	global_transform = Transform3D(b, target.global_position + b.z * distance)
