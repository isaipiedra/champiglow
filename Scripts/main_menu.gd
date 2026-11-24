extends Control

signal start_requested
signal toggle_requested

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$VBoxContainer/start.pressed.connect(func(): start_requested.emit())
	$VBoxContainer/about.pressed.connect(_on_about_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):   # Escape
		toggle_requested.emit()
		get_viewport().set_input_as_handled()

func _on_about_pressed() -> void:
	pass
