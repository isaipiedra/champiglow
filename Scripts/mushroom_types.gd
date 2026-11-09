extends TextureButton

const SCALE_UNPRESSED := Vector2(0.60, 0.60)
const SCALE_PRESSED := Vector2.ONE

func _ready() -> void:
	toggle_mode = true 
	resized.connect(func(): pivot_offset = size / 2.0)
	pivot_offset = size / 2.0
	scale = SCALE_PRESSED if button_pressed else SCALE_UNPRESSED
	toggled.connect(_on_toggled)

func _on_toggled(on: bool) -> void:
	print("toggled: ", on)
	var tween := create_tween()
	tween.tween_property(self, "scale", SCALE_PRESSED if on else SCALE_UNPRESSED, 0.08)
