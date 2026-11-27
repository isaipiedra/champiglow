extends TextureButton

@onready var decoration: TextureRect = $decoration

func _ready() -> void:
	decoration.visible = button_pressed  # match the initial state
	toggled.connect(func(on: bool): decoration.visible = on)
