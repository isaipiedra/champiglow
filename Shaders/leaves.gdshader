shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

//luz que atraviesa las hojas
uniform vec4 backlight_color : source_color = vec4(0.65, 0.85, 0.25, 1.0);
uniform float translucency : hint_range(0.0, 2.0) = 0.6;

//suavizado
uniform vec3 crown_center = vec3(0.0, 2.0, 0.0); // en espacio local del árbol
uniform float crown_radius = 2.0;
uniform float normal_smoothing : hint_range(0.0, 1.0) = 0.7;

// interior más oscuro
uniform float inner_darkness : hint_range(0.0, 1.0) = 0.55;

// movimiento
uniform float wind_strength = 0.03;
uniform float wind_speed = 1.5;

varying float v_ao;

void vertex() {
	vec3 d = VERTEX - crown_center;
	v_ao = clamp(length(d) / crown_radius, 0.0, 1.0);
	NORMAL = normalize(mix(NORMAL, normalize(d), normal_smoothing));

	float t = TIME * wind_speed;
	VERTEX += vec3(
		sin(t + VERTEX.x * 1.5 + VERTEX.z),
		0.0,
		cos(t * 0.8 + VERTEX.z * 1.5)) * wind_strength * v_ao;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = tex.rgb * tint.rgb * mix(inner_darkness, 1.0, v_ao);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = roughness;
	SPECULAR = 0.15;
	BACKLIGHT = backlight_color.rgb * translucency;

	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
}
