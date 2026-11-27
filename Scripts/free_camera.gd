extends Camera3D

@export var focus_target: Node3D
@export var orbit_distance := 15.0
@export var freelook_speed := 10.0
@export var orbit_sensitivity := 0.004
@export var pan_sensitivity := 0.0015
@export var zoom_factor := 1.1

var focus := Vector3.ZERO
var distance := 15.0
var yaw := 0.0
var pitch := 0.0
var _freelook := false

func _ready() -> void:
	current = true
	distance = orbit_distance
	if focus_target:
		focus = focus_target.global_position
		distance = maxf(global_position.distance_to(focus), 0.5)
		look_at(focus)
	var e := global_transform.basis.get_euler()
	pitch = e.x
	yaw = e.y
	if not focus_target:
		_sync_focus()

func _sync_focus() -> void:
	focus = global_position - global_transform.basis.z * distance

func _apply_orbit() -> void:
	var b := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	global_transform = Transform3D(b, focus + b.z * distance)

func _zoom(f: float) -> void:
	if _freelook:
		freelook_speed = clampf(freelook_speed / f, 0.5, 500.0)
	else:
		distance = maxf(distance * f, 0.05)
		_apply_orbit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_freelook = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _freelook else Input.MOUSE_MODE_VISIBLE
			if not _freelook:
				_sync_focus()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.0 / zoom_factor)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_factor)

	elif event is InputEventMouseMotion:
		var m: int = event.button_mask
		if _freelook:
			yaw -= event.relative.x * orbit_sensitivity
			pitch = clampf(pitch - event.relative.y * orbit_sensitivity, -1.55, 1.55)
			global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), global_position)
		elif (m & MOUSE_BUTTON_MASK_MIDDLE) or ((m & MOUSE_BUTTON_MASK_LEFT) and event.alt_pressed):
			if event.shift_pressed:
				var s := distance * pan_sensitivity
				focus += (-global_transform.basis.x * event.relative.x + global_transform.basis.y * event.relative.y) * s
			else:
				yaw -= event.relative.x * orbit_sensitivity
				pitch = clampf(pitch - event.relative.y * orbit_sensitivity, -1.55, 1.55)
			_apply_orbit()

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F and focus_target:
			focus = focus_target.global_position
			_apply_orbit()

func _process(delta: float) -> void:
	if not _freelook:
		return
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= global_transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += global_transform.basis.z
	if Input.is_key_pressed(KEY_A): dir -= global_transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += global_transform.basis.x
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q): dir -= Vector3.UP
	if dir != Vector3.ZERO:
		var s := freelook_speed
		if Input.is_key_pressed(KEY_SHIFT): s *= 3.0
		if Input.is_key_pressed(KEY_ALT): s /= 3.0
		global_position += dir.normalized() * s * delta
