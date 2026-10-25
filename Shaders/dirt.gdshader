shader_type spatial;

uniform vec3 color_dark : source_color = vec3(0.2, 0.15, 0.1);
uniform vec3 color_light : source_color = vec3(0.36, 0.27, 0.20);
uniform float scale = 1.0;
uniform float bump_strength : hint_range(0.0, 5.0) = 0.1;
uniform float crack_depth : hint_range(0.0, 1.0) = 0.01;
uniform float crack_mask_scale : hint_range(0.1, 5.0) = 3.0;
uniform float crack_mask_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float crack_mask_softness : hint_range(0.01, 0.5) = 0.8;
uniform float displacement_scale : hint_range(0.1, 20.0) = 20; // lower = bigger bumps
uniform int displacement_octaves : hint_range(1, 5) = 5;        // lower = rounder
uniform float displacement : hint_range(0.0, 1.0) = 0.04; // needs a subdivided mesh
uniform bool smooth_edges = true; 
uniform vec3 box_half_size = vec3(0.5, 0.5, 0.5); // half of BoxMesh size
uniform float edge_blend : hint_range(1.0, 16.0) = 1.0;
uniform float roughness_min : hint_range(0.0, 1.0) = 0.7; //glossy look

varying vec3 obj_pos;
varying vec3 obj_normal;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1,0,0)), u.x),
			mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), u.x), u.y),
		mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), u.x),
			mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), u.x), u.y),
		u.z);
}

float fbm(vec3 p, int octaves, float rough) {
	float sum = 0.0, amp = 0.5, norm = 0.0;
	for (int i = 0; i < octaves; i++) {
		sum += noise3(p) * amp;
		norm += amp;
		p *= 2.0;
		amp *= rough;
	}
	return sum / norm;
}

// x = distance to nearest point, y = distance to second nearest
vec2 voronoi(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float f1 = 10.0, f2 = 10.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		float d = length(g + hash33(i + g) - f);
		if (d < f1) { f2 = f1; f1 = d; }
		else if (d < f2) { f2 = d; }
	}
	return vec2(f1, f2);
}

// Returns height in x, crack mask (0 = crack edge) in y
vec2 height_at(vec3 p) {
	vec3 q = p * scale;
	float large = fbm(q * 0.6, 3, 0.5);
	float fine = fbm(q * 4.0, 5, 0.55);
	vec2 v = voronoi(q * 1.4);
	float edge = smoothstep(0.0, 0.18, v.y - v.x);
	// Noise mask (like the noise -> color ramp in Blender): cracks only where mask is high
	float mask = fbm(q * crack_mask_scale + 31.7, 4, 0.5);
	mask = smoothstep(crack_mask_threshold - crack_mask_softness, crack_mask_threshold + crack_mask_softness, mask);
	edge = 1.0 - (1.0 - edge) * mask;
	float h = large * 0.55 + fine * 0.35 - (1.0 - edge) * crack_depth;
	return vec2(h, edge);
}

vec3 smooth_dir(vec3 v) {
	vec3 a = pow(abs(v / box_half_size), vec3(edge_blend));
	return normalize(sign(v) * a);
}

float displacement_height(vec3 p) {
	float h = fbm(p * displacement_scale, displacement_octaves, 0.4);
	return h * h * (3.0 - 2.0 * h); // rounds the peaks
}

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	if (displacement > 0.0) {
		vec3 dir = smooth_edges ? smooth_dir(VERTEX) : NORMAL;
		VERTEX += dir * (displacement_height(VERTEX) - 0.5) * displacement;
	}
}

void fragment() {
	vec3 p = obj_pos;
	vec3 n = normalize(obj_normal);

	// Height + bump via finite differences
	float e = 0.004;
	vec2 h0 = height_at(p);
	float hx = height_at(p + vec3(e, 0, 0)).x;
	float hy = height_at(p + vec3(0, e, 0)).x;
	float hz = height_at(p + vec3(0, 0, e)).x;
	vec3 grad = vec3(hx - h0.x, hy - h0.x, hz - h0.x) / e;
	grad -= n * dot(grad, n); // keep only the tangent part
	vec3 bumped = normalize(n - grad * bump_strength * 0.15);
	NORMAL = normalize(mat3(VIEW_MATRIX) * (mat3(MODEL_MATRIX) * bumped));

	// Color: two-tone brown driven by noise + height, darker in cracks
	float tone = fbm(p * scale * 1.5 + 7.0, 4, 0.5);
	float t = smoothstep(0.25, 0.75, tone * 0.6 + h0.x * 0.8);
	vec3 col = mix(color_dark, color_light, t);
	col *= mix(0.45, 1.0, h0.y);                    // crack darkening
	col *= 0.85 + 0.3 * fbm(p * scale * 12.0, 2, 0.5); // fine grain

	ALBEDO = col;
	ROUGHNESS = clamp(roughness_min + 0.25 * fbm(p * scale * 3.0, 3, 0.5), 0.0, 1.0);
	SPECULAR = 0.2;
	METALLIC = 0.0;
}
