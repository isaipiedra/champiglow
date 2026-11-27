shader_type sky;

// dirección hacia el sol
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);

uniform vec3 day_top : source_color = vec3(0.22, 0.52, 0.95);
uniform vec3 day_horizon : source_color = vec3(0.95, 0.85, 0.75);
uniform vec3 night_top : source_color = vec3(0.01, 0.02, 0.09);
uniform vec3 night_horizon : source_color = vec3(0.06, 0.08, 0.2);
uniform vec3 warm_horizon : source_color = vec3(1.0, 0.5, 0.2);
uniform float base_warmth : hint_range(0.0, 1.0) = 0.25;

uniform float sun_size = 3.0;
uniform float moon_size = 2.5;
uniform float star_amount : hint_range(0.0, 1.0) = 0.6;

uniform float cloud_density : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_scale = 2.0;
uniform float cloud_speed = 0.01;
uniform float cloud_softness : hint_range(0.005, 0.6) = 0.25;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 wind = vec2(1.0, 0.3);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	float sun_h = sun_dir.y;

	float day = smoothstep(-0.1, 0.25, sun_h);
	float twilight = 1.0 - smoothstep(0.0, 0.3, abs(sun_h));
	float warm = clamp(twilight + base_warmth * day, 0.0, 1.0);

	// --- Degradado del cielo ---
	vec3 top = mix(night_top, day_top, day);
	vec3 hor = mix(night_horizon, day_horizon, day);
	hor = mix(hor, warm_horizon, warm * 0.85);

	float k = pow(1.0 - clamp(h, 0.0, 1.0), 3.0);
	vec3 col = mix(top, hor, k);

	// resplandor cerca del sol
	float sd = max(dot(dir, sun_dir), 0.0);
	col += warm_horizon * pow(sd, 6.0) * twilight * 0.6;
	col += vec3(1.0, 0.9, 0.7) * pow(sd, 16.0) * 0.2 * day;

	// suelo
	vec3 ground = mix(night_horizon * 0.5, hor * 0.6, day);
	col = mix(col, ground, 1.0 - smoothstep(-0.12, 0.0, h));

	// estrellas
	float night = 1.0 - smoothstep(-0.2, 0.05, sun_h);
	vec3 sp = dir * 90.0;
	vec3 cell = floor(sp);
	vec3 f = fract(sp) - 0.5;
	float sh = hash31(cell);
	float star = step(1.0 - star_amount * 0.06, sh) * smoothstep(0.45, 0.0, length(f));
	star *= 0.7 + 0.3 * sin(TIME * 3.0 + sh * 100.0);
	col += vec3(1.0) * star * night * smoothstep(0.0, 0.15, h);

	// sol y luna
	float sun_cos = cos(radians(sun_size));
	float sun_disc = smoothstep(sun_cos - 0.0004, sun_cos, dot(dir, sun_dir));
	vec3 sun_col = mix(vec3(1.0, 0.95, 0.8), warm_horizon * 1.4, twilight);
	col = mix(col, sun_col, sun_disc * smoothstep(-0.05, 0.02, h));

	float moon_cos = cos(radians(moon_size));
	float moon_disc = smoothstep(moon_cos - 0.0004, moon_cos, dot(dir, -sun_dir));
	col = mix(col, vec3(0.9, 0.93, 1.0), moon_disc * night * smoothstep(-0.05, 0.02, h));

	// nubes
	vec2 uv = dir.xz / max(h + 0.1, 0.05) * cloud_scale + TIME * cloud_speed * wind;
	float n = fbm(uv);
	float th = mix(0.75, 0.3, cloud_density);
	float c = smoothstep(th, th + cloud_softness, n);
	float core = smoothstep(th + 0.05, th + 0.05 + cloud_softness * 2.0, n);

	vec3 lit = mix(vec3(0.12, 0.14, 0.28), vec3(1.0), day);
	lit = mix(lit, warm_horizon * 0.9 + vec3(0.25), twilight * 0.6);
	vec3 shade = lit * vec3(0.65, 0.7, 0.88);
	vec3 cloud_col = mix(shade, lit, core);

	float cloud_fade = smoothstep(0.0, 0.25, h);
	col = mix(col, cloud_col, c * cloud_fade * cloud_opacity);

	COLOR = col;
}
