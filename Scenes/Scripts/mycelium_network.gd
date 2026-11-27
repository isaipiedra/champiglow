class_name MyceliumNetwork
extends Node3D

@export_group("L-system")
#Cuántas veces se aplican las reglas
@export var iterations := 4

@export var random_seed := 0
@export var angle_deg := 22.5
# Maximo de segmentos
@export var max_segments := 1500

@export_group("Forma (metros)")
@export var segment_length := 0.1
#Cuánto baja cada segmento
@export var sink_per_segment := 0.05
@export var base_radius := 0.008
@export var min_radius := 0.003
@export var width_factor := 0.93

@export_group("Apariencia")
@export var color := Color("ac8e4dff")

#8 hifas radiales 
const AXIOM := "[HA][<<HA][<<<<HA][<<<<<<HA][<<<<<<<<HA][<<<<<<<<<<HA][<<<<<<<<<<<<HA][<<<<<<<<<<<<<<HA]"

const RULES := {
	"A": [
		[0.35, "!F[++A][--A]FA"], # horquilla con continuación
		[0.20, "!FF[++A]A"], # rama lateral derecha
		[0.20, "!FF[--A]A"], # rama lateral izquierda
		[0.15, "!F[++F][--F]A"], # espolones cortos que terminan
		[0.10, "!FFA"], # crece sin ramificar
	]
}


const MAX_SENTENCE := 60000

var rng := RandomNumberGenerator.new()
var _multi: MultiMesh
var _segment_count := 0


# Llamar después de añadir el nodo a la escena y de posicionarlo
func build() -> void:
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed

	var sentence := _expand(iterations)
	var segments := _interpret(sentence)
	# Se ordenan por distancia desde el centro
	segments.sort_custom(func(p, q): return p["d"] < q["d"])
	_segment_count = segments.size()

	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 5
	mesh.rings = 1

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material = material

	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.mesh = mesh
	_multi.instance_count = _segment_count
	for i in _segment_count:
		var s: Dictionary = segments[i]
		_multi.set_instance_transform(i, _segment_transform(s["a"], s["b"], s["r"]))
	_multi.visible_instance_count = 0

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func set_growth(t: float) -> void:
	if _multi == null:
		return
	_multi.visible_instance_count = int(round(clampf(t, 0.0, 1.0) * _segment_count))


# El sistema L

func _pick(options: Array) -> String:
	var r := rng.randf()
	var acc := 0.0
	for option in options:
		acc += option[0]
		if r <= acc:
			return option[1]
	return options[options.size() - 1][1]


func _expand(n: int) -> String:
	var s := AXIOM
	for i in n:
		var next := ""
		for c in s:
			if RULES.has(c):
				next += _pick(RULES[c])
			else:
				next += c
		s = next
		if s.length() > MAX_SENTENCE:
			break
	return s


# Recorre la cadena y devuelve los segmentos.

func _interpret(sentence: String) -> Array:
	var angle := deg_to_rad(angle_deg)
	var segments: Array = []
	var pos := Vector3.ZERO
	var rot := Basis.IDENTITY
	var radius := base_radius
	var dist := 0.0
	var stack: Array = []

	for c in sentence:
		if segments.size() >= max_segments:
			break
		match c:
			"F":
				
				rot = rot * Basis(Vector3.UP, rng.randf_range(-0.15, 0.15))
				rot = rot * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08))
				var length := segment_length * rng.randf_range(0.6, 1.4)
				var sink := sink_per_segment * rng.randf_range(0.5, 1.5)
				var to := pos + (-rot.z * length) + Vector3.DOWN * sink
				dist += pos.distance_to(to)
				segments.append({"a": pos, "b": to, "r": maxf(radius, min_radius), "d": dist})
				pos = to
			"!":
				radius *= width_factor
			"+":
				rot = rot * Basis(Vector3.UP, angle * rng.randf_range(0.8, 1.25))
			"-":
				rot = rot * Basis(Vector3.UP, -angle * rng.randf_range(0.8, 1.25))
			"&":
				rot = rot * Basis(Vector3.RIGHT, angle)
			"^":
				rot = rot * Basis(Vector3.RIGHT, -angle)
			"<":
				
				rot = Basis(Vector3.UP, angle) * rot
			"[":
				stack.push_back([pos, rot, radius, dist])
			"]":
				if not stack.is_empty():
					var saved = stack.pop_back()
					pos = saved[0]
					rot = saved[1]
					radius = saved[2]
					dist = saved[3]
	return segments


# Cilindro de altura 1 y radio 1
func _segment_transform(a: Vector3, b: Vector3, r: float) -> Transform3D:
	var dir := b - a
	var length := maxf(dir.length(), 0.0001)
	var up := dir / length
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := up.cross(ref).normalized()
	var z := x.cross(up).normalized()
	return Transform3D(Basis(x * r, up * length, z * r), (a + b) * 0.5)
