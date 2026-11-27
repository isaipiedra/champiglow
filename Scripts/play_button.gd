extends TextureButton

@export var icon_normal: Texture2D
@export var icon_pressed: Texture2D
@onready var texture_rect: TextureRect = $icon

func _ready() -> void:
	toggled.connect(func(on: bool): texture_rect.texture = icon_pressed if on else icon_normal)
