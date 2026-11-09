extends Node3D

@export var mycena_scene: PackedScene
@export var amanita_scene: PackedScene
@export var wind_pivot: Node3D

@export var wind_force: Vector3 = Vector3.ZERO   # (se calcula desde el pivote)

@onready var label_time = $CanvasLayer/Interface/Label_Time
@onready var label_temperature = $CanvasLayer/Interface/Label_Temperature
@onready var label_humidity = $CanvasLayer/Interface/Label_Humidity
@onready var label_selected_fungus = $CanvasLayer/Interface/Label_Selected_Fungus

# --- nodos de la interfaz ---
@onready var ui: Node = $CanvasLayer/Interface
@onready var temp_slider: Range = _find(ui.get_node("sliders/slider"), "Range")
@onready var humidity_slider: Range = _find(ui.get_node("sliders/humidity-slider"), "Range")
@onready var play_button: BaseButton = _find(ui.get_node("time/PlayButton"), "BaseButton")
@onready var forward_button: BaseButton = _find(ui.get_node("time/forward_button"), "BaseButton")
@onready var red_button: BaseButton = _find(ui.get_node("mushrooms/Control/red"), "BaseButton")
@onready var glow_button: BaseButton = _find(ui.get_node("mushrooms/Control2/glow"), "BaseButton")

var wind_value := 0.5
var time_speed_mul := 1
var original_day_length := 0.0
var is_night := false
var is_day := false
var temperature_celsius := 0.0
var humidity_percentage := 0.0
var chosen_fungus := 0   # 0 = Amanita, 1 = Mycena

var array_mycena_particles: Array = []
var array_amanita_particles: Array = []

var _last_wind_angle := INF


# Busca el slider o botón dentro de la escena instanciada
func _find(node: Node, type: String) -> Node:
	if node.is_class(type):
		return node
	return node.find_children("*", type, true, false)[0]


func _ready() -> void:
	original_day_length = $sky.day_length

	# Evita que la barra espaciadora presione el último botón tocado
	for c in ui.find_children("*", "Control", true, false):
		c.focus_mode = Control.FOCUS_NONE

	temp_slider.value_changed.connect(_set_temperature)
	humidity_slider.value_changed.connect(_set_humidity)
	forward_button.pressed.connect(_cycle_speed)
	play_button.pressed.connect(_toggle_time)
	red_button.pressed.connect(_set_fungus.bind(0))    # Amanita
	glow_button.pressed.connect(_set_fungus.bind(1))   # Mycena

	_set_temperature(temperature_celsius)
	_set_humidity(humidity_percentage)
	_update_time_label()
	_update_fungus_label()


# ---------- teclas e interfaz ----------
func _set_temperature(v: float) -> void:
	temperature_celsius = clampf(v, 0.0, 100.0)
	label_temperature.text = "Temperatura %.1f °C" % temperature_celsius
	temp_slider.value = temperature_celsius


func _set_humidity(v: float) -> void:
	humidity_percentage = clampf(v, 0.0, 100.0)
	label_humidity.text = "Porcentaje de Humedad: %.1f" % humidity_percentage
	humidity_slider.value = humidity_percentage


func _cycle_speed() -> void:
	if $sky.auto_advance:
		time_speed_mul = time_speed_mul * 2 if time_speed_mul < 4 else 1
		$sky.day_length = original_day_length / time_speed_mul
		_update_time_label()


func _toggle_time() -> void:
	$sky.auto_advance = not $sky.auto_advance
	_update_time_label()


func _set_fungus(id: int) -> void:
	chosen_fungus = id
	_update_fungus_label()


# ---------- labels  ----------
func _update_time_label() -> void:
	if $sky.auto_advance:
		label_time.text = "Velocidad de día: x%d" % time_speed_mul
	else:
		label_time.text = "Velocidad de día: x0 - Tiempo detenido"
	play_button.button_pressed = not $sky.auto_advance  # pressed = tiempo corriendo


func _update_fungus_label() -> void:
	label_selected_fungus.text = "Amanita Muscaria" if chosen_fungus == 0 else "Mycena Chlorophos"
	red_button.button_pressed = (chosen_fungus == 0)
	glow_button.button_pressed = (chosen_fungus == 1)

# ---------- viento ----------
func update_wind_from_pivot() -> void:
	if not wind_pivot:
		return
	var angle := fposmod(wind_pivot.rotation.y, TAU)
	if absf(angle - _last_wind_angle) < 0.005:
		return
	_last_wind_angle = angle

	wind_force = Vector3(0.0, 0.0, wind_value).rotated(Vector3.UP, angle)

	for particle in array_mycena_particles + array_amanita_particles:
		if is_instance_valid(particle):
			particle.change_actual_wind(wind_force)


# ---------- entrada ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		generate_particle()

	if not (event is InputEventKey and event.pressed):
		return

	match event.keycode:
		KEY_O: _set_temperature(temperature_celsius + 1)
		KEY_I: _set_temperature(temperature_celsius - 1)
		KEY_K: _set_humidity(humidity_percentage + 1)
		KEY_J: _set_humidity(humidity_percentage - 1)

	if event.echo:
		return

	match event.keycode:
		KEY_R: forward_button.pressed.emit()
		KEY_SPACE: _toggle_time()
		KEY_H: _set_fungus(1 - chosen_fungus)


# ---------- partículas ----------
func generate_particle() -> void:
	var scene := amanita_scene if chosen_fungus == 0 else mycena_scene
	if not scene:
		print("No se ha añadido la escena en el Inspector")
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin: Vector3 = $Camera3D.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = $Camera3D.project_ray_normal(mouse_pos)

	var new_particle = scene.instantiate()
	new_particle.global_position = ray_origin + ray_direction * 5.0
	add_child(new_particle)

	if new_particle.has_method("fetch_environmental_factors"):
		new_particle.fetch_environmental_factors(wind_force)

	if chosen_fungus == 0:
		array_amanita_particles.append(new_particle)
	else:
		array_mycena_particles.append(new_particle)


func _process(_delta: float) -> void:
	update_wind_from_pivot()

	if $sky.time_of_day >= 18.0:
		if not is_night:
			is_night = true
			is_day = false
			for particle in array_mycena_particles:
				if is_instance_valid(particle):
					particle.its_night()
	else:
		if not is_day:
			is_day = true
			is_night = false
			for particle in array_mycena_particles:
				if is_instance_valid(particle):
					particle.its_day()
