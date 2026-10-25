extends Node

@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var sky_shader: Shader

@export_range(0.0, 24.0) var time_of_day := 8.0:
	set(v):
		time_of_day = v
		_apply()
@export var auto_advance := true
@export var day_length := 120.0 ## segundos reales
@export_range(-180.0, 180.0) var sun_yaw := 30.0 ## rotación del recorrido del sol

@export var day_light_color := Color(1.0, 0.96, 0.88)
@export var warm_light_color := Color(1.0, 0.55, 0.25)
@export var night_light_color := Color(0.45, 0.55, 0.9)
@export var enable_shadows := true
@export var shadow_distance := 300.0 ## distancia máxima de sombras
@export_range(0.0, 1.0) var ambient_day := 0.2 ## luz de relleno del cielo de día
@export_range(0.0, 1.0) var ambient_night := 0.08
@export_range(0.5, 2.0) var contrast := 1.1
@export_range(0.5, 2.0) var saturation := 1.2
@export var day_energy := 1.2
@export var night_energy := 0.15

var _mat: ShaderMaterial
var _env: Environment

func _ready() -> void:
	if world_environment == null:
		world_environment = WorldEnvironment.new()
		add_child(world_environment)
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.shadow_enabled = true
		add_child(sun)
	sun.shadow_enabled = enable_shadows
	sun.directional_shadow_max_distance = shadow_distance
	if sky_shader == null:
		sky_shader = load("res://Shaders/sky.gdshader")

	_mat = ShaderMaterial.new()
	_mat.shader = sky_shader

	var sky := Sky.new()
	sky.sky_material = _mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME

	_env = world_environment.environment if world_environment.environment else Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	world_environment.environment = _env
	_env.adjustment_enabled = true
	_env.adjustment_contrast = contrast
	_env.adjustment_saturation = saturation

	_apply()

func _process(delta: float) -> void:
	if auto_advance:
		time_of_day = fposmod(time_of_day + delta * 24.0 / day_length, 24.0)

func _apply() -> void:
	if _mat == null or sun == null:
		return

	var a := (time_of_day - 6.0) / 24.0 * TAU
	var yaw := deg_to_rad(sun_yaw)
	var to_sun := Vector3(cos(a), sin(a), 0.0).rotated(Vector3.UP, yaw)
	var side := Vector3.BACK.rotated(Vector3.UP, yaw) # perpendicular al recorrido
	var elev := to_sun.y

	var day := smoothstep(-0.05, 0.3, elev)
	var twilight := 1.0 - smoothstep(0.0, 0.3, absf(elev))

	# luz de noche
	var light_to := to_sun if elev > -0.05 else -to_sun
	sun.global_transform = Transform3D(Basis.looking_at(-light_to, side), sun.global_position)

	var col := night_light_color.lerp(day_light_color, day)
	col = col.lerp(warm_light_color, twilight * 0.85 * smoothstep(-0.05, 0.1, elev))
	sun.light_color = col
	sun.light_energy = lerpf(night_energy, day_energy, day)

	_env.ambient_light_energy = lerpf(ambient_night, ambient_day, day)
	_mat.set_shader_parameter("sun_dir", to_sun)
