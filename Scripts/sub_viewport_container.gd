extends SubViewportContainer

@export var pivot: Node3D
@export var sensibilidad := 0.01

var dragging := false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		accept_event()   # stops _unhandled_input from spawning a particle
	elif event is InputEventMouseMotion and dragging:
		pivot.rotate_y(event.relative.x * sensibilidad)
		accept_event()
