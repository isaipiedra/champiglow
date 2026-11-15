
extends Node3D

@export var natural_color: Color = Color("#e8e3ce") #Color del hongo sin estar brillando
@export var glow_color: Color = Color("#55ff33") #Color del honguito al brillar
@export var rotten_color: Color = Color("#6b4f3b") # Marrón tierra desaturado

@export_range(0.0, 5.0, 0.1) #valor mínimo de brillo, máximo, incremento
var glow_strength: float = 1.0 #Valor incial de brillo

@export_group("Variación natural")
@export_range(0.0, 0.4, 0.01) #Variacion entre los tamaños de los honguitos
var size_variation: float = 0.18

@onready var stem: Node3D = $Stem #Nodo del tallo
@onready var stem_mesh: MeshInstance3D = $Stem/MeshInstance3D #Nodo de la malla del tayo
@onready var cap: Node3D = $Cap #Nodo del sombrerillo del hongo para hacerlo crecer
@onready var glow_light: OmniLight3D = $GlowLight #Nodo del brillo del hongo

var glowing: bool = false #Honguito iluminando si o no
var growth_day: int = 1 #Dia de crecimiento

var _adult_stem_scale: Vector3 #Escala original del hongo adulto
var _adult_cap_position: Vector3 #Posicion original del sombrero adulto
var _stem_base_y: float #Altura de la base del tallo para que se mantenga igual mientras crece el hongo
var _stem_center_offset: float #Desplazamiento original segun el tallo
var _stem_half_height: float #Mitad de la altura del tallo

var _height_variation: float = 1.0 #Variación en la altura del tallo
var _width_variation: float = 1.0 #Variación en la anchura del tallo
var _cap_variation: float = 1.0 #Varación de las dimensiones dle sombrero

var _adult_cap_scale: Vector3 #Escala original del sombrero adulto
 
var has_glowed: bool = false #Bandera que indica si el honguito ha brillado una vez
var glow_days_elapsed: int = 0
var glow_progress: float = 0.0 #Transición luminosa, la intensidad entre 0.0 y 1.0
var _stem_material: StandardMaterial3D #Material para controlar el aspecto del tallo

#Var rotten
var rotten_days_elapsed: int = 0
var rotten_progress: float = 0.0
var rotten_has_started: bool = false
var fruit_has_died: bool = false
signal fruit_died(mushroom: Node3D)

func _ready() -> void:
	#Se guardan las medidas del tallo y sombrerillo originales
	_adult_stem_scale = stem.scale
	_adult_cap_position = cap.position
	_adult_cap_scale = cap.scale
	
	#Variacion de tamaño, devuelve un decimal entre este intervalo. Son variaciones para
	#la anchura, la altura y el tamaño del sombrerito
	_height_variation = randf_range(1.0 - size_variation, 1.0 + size_variation)

	_width_variation = randf_range(1.0 - size_variation, 1.0 + size_variation)

	_cap_variation = randf_range(1.0 - size_variation, 1.0 + size_variation)
	
	
	#Caja delimitadora del tallo
	var bounds: AABB = stem_mesh.get_aabb()
	
	#Desplazamiento vertical del tallo
	_stem_center_offset = (stem_mesh.position.y + (bounds.position.y + bounds.size.y * 0.5) * stem_mesh.scale.y)

	_stem_half_height = (bounds.size.y * 0.5 * absf(stem_mesh.scale.y))

	#Estimación de la parte inferior del tallo
	_stem_base_y = (stem.position.y + stem.scale.y * (_stem_center_offset - _stem_half_height))
	
	#Material del tallo
	_stem_material = StandardMaterial3D.new()
	stem_mesh.material_override = _stem_material
	
	glow_light.light_color = glow_color
	glow_light.light_energy = 0.0
	glow_light.visible = false
	update_appearance()
	_apply_growth_stage()


# Control de apariencia.

func update_appearance() -> void:
	#Interpolación lineal, mezcla el color natural con el luminoso
	var current_color: Color
	if fruit_has_died:
		current_color = rotten_color
	elif not rotten_has_started:
		current_color = natural_color.lerp( glow_color,glow_progress)
	elif rotten_has_started:
		current_color = natural_color.lerp(rotten_color, rotten_progress)
		

	# Material del tallo.
	_stem_material.albedo_color = current_color
	_stem_material.roughness = 0.8
	_stem_material.emission_enabled = glow_progress > 0.001
	_stem_material.emission = glow_color
	_stem_material.emission_energy_multiplier = (glow_strength * glow_progress)

	# Material del sombrero.
	if cap.has_method("set_mushroom_appearance"): cap.set_mushroom_appearance(current_color, glow_strength * glow_progress)
	
	#Brillo del omniLight
	glow_light.visible = glow_progress > 0.001
	glow_light.light_energy = glow_strength * glow_progress


# Avanzar un día de crecimiento.
func advance_growth_day() -> void:
	growth_day += 1

	if growth_day == 14 and not has_glowed:
		has_glowed = true
		glowing = true
		glow_progress = 0.0

		update_appearance()

	elif growth_day >= 17 and growth_day < 18 and has_glowed and glowing:
		glowing = false
		glow_progress = 0.0

		update_appearance()
		
	elif growth_day == 18 and not rotten_has_started:
		rotten_has_started = true
		rotten_progress = 0.0
		update_appearance() 

	_apply_growth_stage()


func _apply_growth_stage() -> void:
	# El tallo crece durante los días 1 al 9.
	#Progreso del tallo entre los 9 días representado por un valor entre 0 y 1
	var stem_progress: float = clampf(float(growth_day - 1) / 8.0, 0.0, 1.0)
	
	
	var stem_factor: float = lerpf(0.08, 1.0, stem_progress)

	#Tamaño del tallo según su progreso
	stem.scale = Vector3(_adult_stem_scale.x * _width_variation,_adult_stem_scale.y * stem_factor * _height_variation,_adult_stem_scale.z * _width_variation)

	# Mantener la base del tallo en su posición.
	stem.position.y = (_stem_base_y - stem.scale.y * (_stem_center_offset - _stem_half_height))

	# Ajustar la altura del sombrero según el tallo.
	var target_cap_y := (_stem_base_y + (_adult_cap_position.y - _stem_base_y) * _height_variation)

	cap.position.y = lerpf(_stem_base_y,target_cap_y, stem_factor)

	# El sombrero aparece el día 10 y se expande hasta el 14.
	cap.visible = growth_day >= 10

	var cap_progress: float = clampf(float(growth_day - 10) / 4.0, 0.0, 1.0)

	var cap_factor: float = lerpf( 0.18, 1.0, cap_progress)

	cap.scale = _adult_cap_scale * _cap_variation * cap_factor
	
	
func _process(delta: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var sky := current_scene.get_node_or_null("sky")
	if sky == null:
		return

	# No avanzar mientras el reloj esté detenido.
	if not bool(sky.get("auto_advance")):
		return

	var day_duration := float(sky.get("day_length"))
	if day_duration <= 0.0:
		return

	var previous_progress := glow_progress
	var previous_rotten_progress := rotten_progress

	match growth_day:
		14:
			glow_progress = minf(glow_progress + delta / day_duration,1.0)

		15:
			glow_progress = 1.0

		16:
			glow_progress = maxf(glow_progress - delta / day_duration, 0.0)
		18:
			rotten_progress = minf(rotten_progress + delta / day_duration, 1.0)
		19:
			rotten_progress = 1.0
		20:
			fruit_has_died = true
			rotten_progress = maxf(rotten_progress - delta / day_duration, 0.0)
		22:
			fruit_died.emit(self)
			
	
	if not is_equal_approx(previous_progress, glow_progress) || not is_equal_approx(previous_rotten_progress, rotten_progress) :
		update_appearance()
		
	if fruit_has_died:
		update_appearance()
		
