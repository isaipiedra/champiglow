extends Node3D

signal fruit_died(mushroom: Node3D)
signal spores_started(mushroom: Node3D)
signal spores_stopped(mushroom: Node3D)

@export_group("Apariencia")
@export var cap_color := Color("#d92323")
@export var stem_color := Color("#eee9d9")
@export var spots_color := Color("#ffffff")
@export var rotten_color := Color("#665044")

@export_group("Variación natural")
@export_range(0.0, 0.4, 0.01) var size_variation := 0.18

@export_group("Condiciones ambientales")
@export var amanita_min_temp: float = 18.0
@export var amanita_max_temp: float = 24.0
@export var amanita_min_humidity: float = 80.0

# Días desde que nace
@export_group("Crecimiento")
@export var stem_growth_days := 28.0
@export var cap_start_day := 10.0
@export var cap_full_day := 28.0

@export_group("Nutrientes")
# Cuánto consume del suelo cada día
@export var carbon_per_day := 0.1
@export var nitrogen_per_day := 0.1
@export var metals_per_day := 0.2
# Días seguidos sin poder comer antes de empezar a morir
@export var starvation_days := 2

@export_group("Esporas")
# Día en que empieza a soltar esporas 
@export var spores_start_day := 31.0
# Día en que deja de soltarlas
@export var spores_end_day := 32.0
# Esporas máximas que suelta cada hongo
@export var max_spores := 10

@export_group("Pudrición")
# Edad en días a la que empieza a pudrirse
@export var lifespan_days := 33.0
# Días que dura pudriendose hasta morir
@export var rot_days := 4.0
# Días que dura pudirnedose por estrés ambiental.
@export var stress_rot_days := 1.0

@export_group("Estrés ambiental")
# Días acumulados con condiciones malas antes de empezar a pudrirse
@export var stress_tolerance_days := 0.7
# lo rápido se recupera del estrés
@export var recovery_rate := 0.5

# Altura del tallo adulto
const STEM_HEIGHT := 0.25

var is_rotting := false
var is_dead := false
var rot_progress := 0.0

var environment_ok := true
var environmental_stress := 0.0

var is_releasing_spores := false
var spores_generated := 0

var nutrient_view: Node3D
var hungry_days := 0
var is_fed := true

var _sky: Node
var _birth_day := 0.0
var _last_day := 0.0
var _rot_start_day := 0.0
var _rot_duration := 1.0
var _stem_variation := 1.0
var _cap_variation := 1.0
var _adult_cap_scale := Vector3.ONE
var _stem_material: StandardMaterial3D
var _cap_material: StandardMaterial3D
var growth_day: int = 1 #Dia de crecimiento

@onready var stem: MeshInstance3D = $Stem
@onready var cap: MeshInstance3D = $Cap
@onready var ring: MeshInstance3D = $Ring
@onready var spots: Node3D = $Spots


func _ready() -> void:
	_adult_cap_scale = cap.scale
	_stem_variation = randf_range(1.0 - size_variation, 1.0 + size_variation)
	_cap_variation = randf_range(1.0 - size_variation, 1.0 + size_variation)

	_stem_material = StandardMaterial3D.new()
	_stem_material.albedo_color = stem_color
	_stem_material.roughness = 0.9
	stem.material_override = _stem_material

	_cap_material = StandardMaterial3D.new()
	_cap_material.albedo_color = cap_color
	_cap_material.roughness = 0.8
	cap.material_override = _cap_material

	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = stem_color
	ring.material_override = ring_material

	var spots_material := StandardMaterial3D.new()
	spots_material.albedo_color = spots_color
	for spot in spots.get_children():
		if spot is MeshInstance3D:
			spot.material_override = spots_material

	_apply_growth(0.0)

# Main la llama a medianoche
func advance_growth_day() -> void:
	if is_rotting or is_dead:
		return
	_eat()
	if is_rotting:
		return
	growth_day += 1
	_apply_growth(float(growth_day - 1))

# La llama Main justo después de añadir el hongo a la escena.
func setup(sky: Node, size: float, nutrients: Node3D = null) -> void:
	_sky = sky
	nutrient_view = nutrients
	_birth_day = _sky.elapsed_days
	_last_day = _birth_day
	scale = Vector3.ONE * size
	_apply_growth(0.0)


# Revisa si están buenas la temperatura y humedad
func set_environment_conditions(temperature: float, humidity: float) -> void:
	environment_ok = (temperature >= amanita_min_temp and temperature <= amanita_max_temp
		and humidity >= amanita_min_humidity)


#  Esporas 
func can_generate_spores() -> bool:
	return spores_generated < max_spores


func register_spore_generation() -> void:
	spores_generated += 1


# Punto desde donde salen las esporas
func get_spore_origin() -> Vector3:
	return cap.global_position + Vector3.UP * 0.05 * scale.y

# Come del suelo bajo el hongo. Se llama una vez por día.
func _eat() -> void:
	if nutrient_view == null:
		return
	var needs := {"carbon": carbon_per_day, "nitrogen": nitrogen_per_day, "metals": metals_per_day}
	var fed := true
	for type in needs:
		var need: float = needs[type]
		if need <= 0.0:
			continue
		var got: float = nutrient_view.consume_nutrient_at(global_position, type, need)
		if got < need - 0.001:
			fed = false
	is_fed = fed
	if fed:
		hungry_days = 0
	else:
		hungry_days += 1
		if hungry_days >= starvation_days:
			start_rot(true)

# --- Pudrición ---
func start_rot(from_stress := false) -> void:
	if is_rotting or is_dead or _sky == null:
		return
	is_rotting = true
	_rot_start_day = _sky.elapsed_days
	_rot_duration = stress_rot_days if from_stress else rot_days
	if is_releasing_spores:
		is_releasing_spores = false
		spores_stopped.emit(self)


func _process(_delta: float) -> void:
	if _sky == null or is_dead:
		return

	var now: float = _sky.elapsed_days
	var dt := now - _last_day 
	_last_day = now

	if is_rotting:
		_update_rot(now)
		return

	var age := now - _birth_day
	_update_spore_phase(age)
	_update_spore_phase(age)
	_update_stress(dt)

	if not is_rotting and lifespan_days > 0.0 and age >= lifespan_days:
		start_rot()


func _update_spore_phase(age: float) -> void:
	var should_release := (age >= spores_start_day and age < spores_end_day
		and can_generate_spores())
	if should_release and not is_releasing_spores:
		is_releasing_spores = true
		spores_started.emit(self)
	elif not should_release and is_releasing_spores:
		is_releasing_spores = false
		spores_stopped.emit(self)


func _update_stress(dt: float) -> void:
	if environment_ok:
		environmental_stress = maxf(0.0, environmental_stress - dt * recovery_rate)
	else:
		environmental_stress += dt
		if environmental_stress >= stress_tolerance_days:
			start_rot(true)


func _update_rot(now: float) -> void:
	rot_progress = clampf((now - _rot_start_day) / maxf(_rot_duration, 0.001), 0.0, 1.0)
	_stem_material.albedo_color = stem_color.lerp(rotten_color, rot_progress)
	_cap_material.albedo_color = cap_color.lerp(rotten_color, rot_progress)
	if rot_progress >= 1.0:
		is_dead = true
		fruit_died.emit(self)


func _apply_growth(age: float) -> void:
	# Tallo, crece desde la base
	var stem_progress := clampf(age / maxf(stem_growth_days, 0.001), 0.0, 1.0)
	var stem_factor := lerpf(0.1, 1.0, stem_progress)
	var stem_h := STEM_HEIGHT * stem_factor * _stem_variation
	stem.scale = Vector3(_stem_variation, stem_factor * _stem_variation, _stem_variation)
	stem.position.y = stem_h / 2.0

	# Sombrero, anillo y manchas
	var cap_visible := age >= cap_start_day
	cap.visible = cap_visible
	ring.visible = cap_visible
	spots.visible = cap_visible

	var cap_progress := clampf(
		(age - cap_start_day) / maxf(cap_full_day - cap_start_day, 0.001), 0.0, 1.0)
	var cap_factor := lerpf(0.15, 1.0, cap_progress) * _cap_variation
	cap.scale = _adult_cap_scale * cap_factor
	spots.scale = Vector3.ONE * cap_factor

	
	cap.position.y = stem_h
	spots.position.y = stem_h
	ring.position.y = stem_h * 0.7
