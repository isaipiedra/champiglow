extends Control

@onready var v_slider: VSlider = $VSlider
@onready var label: Label = $NinePatchRect/Label

func _ready() -> void:
	v_slider.value_changed.connect(_on_value_changed)
	_on_value_changed(v_slider.value)

func _on_value_changed(value: float) -> void:
	label.text = str(int(value))
