extends Control

signal back_requested

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Atras.pressed.connect(on_atras_pressed)

func on_atras_pressed() -> void:
	back_requested.emit()
