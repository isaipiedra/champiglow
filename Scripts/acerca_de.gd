extends Control

signal back_requested
signal controles_requested
signal hongos_requested

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$AtrasButton.pressed.connect(on_atras_pressed)
	$Controles.pressed.connect(on_controles_pressed)
	$infoHongo.pressed.connect(on_infoHongos_pressed)

func on_atras_pressed() -> void:
	back_requested.emit()
	
func on_controles_pressed() -> void:
	controles_requested.emit()
	
func on_infoHongos_pressed() -> void:
	hongos_requested.emit()
