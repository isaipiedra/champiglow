extends TextureButton

@export var icon_normal: Texture2D

@onready var label: Label = $detail/Label

var multipliers := [1, 2, 4]
var index := 0

func _ready() -> void:
	_update_label()
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	index = (index + 1) % multipliers.size()
	_update_label()

func _update_label() -> void:
	label.text = "x%d" % multipliers[index]
