extends Control

signal back_requested

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Atras.pressed.connect(on_atras_pressed)

func on_atras_pressed() -> void:
	back_requested.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
