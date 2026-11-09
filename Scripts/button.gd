extends TextureButton

@export var icon_normal: Texture2D

const SCALE_NORMAL := Vector2.ONE
const SCALE_PRESSED := Vector2(0.9, 0.9)

func _ready() -> void:
	pivot_offset = size / 2.0  # escala desde el centro
	button_down.connect(func(): _animate_scale(SCALE_PRESSED))
	button_up.connect(func(): _animate_scale(SCALE_NORMAL))

func _animate_scale(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 0.08)
