shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(1920.0, 1080.0);
uniform float seed = 424242.0;
uniform float star_density : hint_range(0.25, 2.5) = 1.0;
uniform float band_strength : hint_range(0.0, 2.0) = 1.0;
uniform float nebula_strength : hint_range(0.0, 2.0) = 1.0;


float _hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}


vec2 _hash22(vec2 p) {
	return vec2(
		fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123),
		fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453123)
	);
}


float _noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = _hash21(i);
	float b = _hash21(i + vec2(1.0, 0.0));
	float c = _hash21(i + vec2(0.0, 1.0));
	float d = _hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}


float _fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	mat2 basis = mat2(vec2(1.7, 1.2), vec2(-1.2, 1.7));
	for (int i = 0; i < 5; i++) {
		value += _noise(p) * amplitude;
		p = basis * p * 1.65 + vec2(3.1, 5.7);
		amplitude *= 0.5;
	}
	return value;
}


mat2 _rot(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat2(vec2(c, -s), vec2(s, c));
}


vec3 _star_tint(float tone) {
	vec3 cool = vec3(0.74, 0.84, 1.0);
	vec3 neutral = vec3(0.93, 0.95, 1.0);
	vec3 warm = vec3(1.0, 0.90, 0.78);
	vec3 base = mix(cool, neutral, smoothstep(0.10, 0.45, tone));
	return mix(base, warm, smoothstep(0.45, 1.0, tone));
}


vec3 _sample_star_layer(
	vec2 p,
	float cell_scale,
	float threshold,
	float min_radius,
	float max_radius,
	float halo_scale,
	float seed_offset,
	float brightness_boost
) {
	vec2 grid = p * cell_scale;
	vec2 base = floor(grid);
	vec2 frac_pos = fract(grid) - 0.5;
	vec3 accum = vec3(0.0);

	for (int yi = -1; yi <= 1; yi++) {
		for (int xi = -1; xi <= 1; xi++) {
			vec2 cell_offset = vec2(float(xi), float(yi));
			vec2 cell = base + cell_offset;
			float chance = _hash21(cell + vec2(seed * 0.00013 + seed_offset, seed * 0.00019 - seed_offset));
			float enabled = step(threshold, chance);
			vec2 rnd = _hash22(cell + vec2(seed * 0.00031 + seed_offset * 2.0, seed * 0.00047 - seed_offset * 3.0));
			vec2 star_pos = cell_offset + rnd - 0.5;
			float radius = mix(min_radius, max_radius, rnd.x * rnd.x);
			float dist = length(frac_pos - star_pos);
			float core = 1.0 - smoothstep(radius * 0.35, radius, dist);
			float halo = 1.0 - smoothstep(radius, radius * halo_scale, dist);
			float brightness = mix(0.35, 1.25, _hash21(cell + vec2(41.0 + seed_offset, -17.0 - seed_offset)));
			float tone = _hash21(cell + vec2(-67.0 - seed_offset, 29.0 + seed_offset));
			accum += _star_tint(tone) * enabled * brightness * brightness_boost * (core + halo * 0.24);
		}
	}

	return accum;
}


void fragment() {
	vec2 safe_viewport = max(viewport_size, vec2(1.0));
	float aspect = safe_viewport.x / safe_viewport.y;
	float density_t = clamp((star_density - 0.25) / 2.25, 0.0, 1.0);

	vec2 uv = SCREEN_UV;
	vec2 p = (uv - vec2(0.5)) * vec2(aspect, 1.0);
	float radius = length(p * vec2(1.0, 1.25));

	vec3 color = mix(
		vec3(0.006, 0.009, 0.022),
		vec3(0.017, 0.029, 0.061),
		smoothstep(-0.60, 0.85, p.y)
	);

	float inner_glow = 1.0 - smoothstep(0.10, 1.20, radius);
	color += vec3(0.010, 0.018, 0.034) * inner_glow * 0.55;
	color += vec3(0.028, 0.014, 0.010) * exp(-pow(length(p - vec2(0.70, 0.34)) / 0.72, 2.0)) * 0.35;
	color += vec3(0.006, 0.020, 0.040) * exp(-pow(length(p - vec2(-0.64, -0.24)) / 0.68, 2.0)) * 0.45;

	vec2 band_p = _rot(-0.42) * p;
	band_p.y += 0.10;
	float band_wide = exp(-pow(band_p.y / 0.44, 2.0));
	float band_core = exp(-pow(band_p.y / 0.20, 2.0));
	float band_shape = _fbm(vec2(band_p.x * 1.6 + seed * 0.00012, band_p.y * 3.8 - seed * 0.00018));
	float band_breakup = _fbm(vec2(band_p.x * 5.5 - 12.0, band_p.y * 9.0 + seed * 0.00027));
	float band_ridge = 1.0 - abs(_fbm(vec2(band_p.x * 3.4 + 18.0, band_p.y * 10.0 - 5.0 - seed * 0.00033)) * 2.0 - 1.0);
	float band_mix = smoothstep(0.28, 0.82, _fbm(vec2(band_p.x * 1.1 + 21.0, band_p.y * 2.4 - 7.0)));
	float band_amount = band_strength * (
		band_wide * 0.12
		+ band_core * (0.12 + 0.18 * band_shape + 0.11 * band_breakup)
	);
	vec3 band_color = mix(vec3(0.09, 0.11, 0.17), vec3(0.30, 0.23, 0.18), band_mix);
	band_color += vec3(0.04, 0.03, 0.03) * band_breakup;
	color += band_color * band_amount;
	color += vec3(0.022, 0.020, 0.030) * band_wide * band_strength * 0.16;

	float dust_lane_noise = _fbm(vec2(band_p.x * 4.2 - 16.0, band_p.y * 14.0 + 3.0 + seed * 0.00021));
	float dust_lanes = band_core * smoothstep(0.48, 0.78, dust_lane_noise) * (0.35 + 0.45 * band_ridge);
	color *= 1.0 - dust_lanes * band_strength * 0.40;

	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float side = _hash21(vec2(seed * 0.013 + fi * 17.0, 4.0 + fi)) < 0.5 ? -1.0 : 1.0;
		float vertical = _hash21(vec2(seed * 0.009 + fi * 29.0, 8.0 + fi)) < 0.5 ? -1.0 : 1.0;
		vec2 center = vec2(
			side * mix(0.22, 0.74, _hash21(vec2(seed * 0.017 + fi * 13.0, 12.0 + fi))),
			vertical * mix(0.08, 0.34, _hash21(vec2(seed * 0.019 + fi * 7.0, 16.0 + fi)))
		);
		vec2 local = _rot(_hash21(vec2(seed * 0.021 + fi * 11.0, 33.0 + fi)) * 1.8 - 0.9) * (p - center);
		float pocket_radius = mix(0.20, 0.34, _hash21(vec2(seed * 0.015 + fi * 19.0, 27.0 + fi)));
		float field = exp(-pow(length(vec2(local.x * 1.18, local.y * 0.80)) / pocket_radius, 2.0));
		float breakup = _fbm(local * 4.0 + vec2(fi * 3.2, fi * 5.7) + seed * 0.00071);
		float wisps = 1.0 - abs(_fbm(local * 7.8 - vec2(fi * 4.1, -fi * 2.7) - seed * 0.00093) * 2.0 - 1.0);
		float mask = field * smoothstep(0.22, 0.88, breakup) * (0.65 + wisps * 0.35);
		float tint_index = mod(fi, 4.0);
		vec3 tint = vec3(0.0);
		if (tint_index < 0.5) {
			tint = vec3(0.58, 0.26, 0.80);
		} else if (tint_index < 1.5) {
			tint = vec3(0.25, 0.66, 0.86);
		} else if (tint_index < 2.5) {
			tint = vec3(0.72, 0.48, 0.24);
		} else {
			tint = vec3(0.68, 0.32, 0.64);
		}
		float opacity = (0.040 + 0.050 * _hash21(vec2(fi * 12.3, seed * 0.00057 + fi))) * nebula_strength;
		color += tint * mask * opacity;
	}

	float star_boost = 0.78 + band_wide * 0.34;
	vec3 stars = vec3(0.0);
	stars += _sample_star_layer(
		p,
		170.0,
		mix(0.9930, 0.9860, density_t),
		0.010,
		0.020,
		2.7,
		1.0,
		0.85
	);
	stars += _sample_star_layer(
		p,
		108.0,
		mix(0.9972, 0.9930, density_t),
		0.013,
		0.030,
		3.3,
		13.0,
		1.05
	);
	stars += _sample_star_layer(
		p,
		54.0,
		mix(0.9990, 0.9968, density_t),
		0.020,
		0.048,
		5.0,
		31.0,
		1.35
	);
	color += stars * star_boost;

	float fine_specks = pow(max(_noise(uv * safe_viewport * 0.36 + vec2(seed * 0.00041, seed * 0.00023)) - 0.84, 0.0) / 0.16, 4.0);
	color += vec3(0.26, 0.30, 0.38) * fine_specks * (0.02 + band_wide * 0.02);

	color *= 1.0 - smoothstep(0.82, 1.28, radius) * 0.38;
	color = clamp(color, vec3(0.0), vec3(1.0));
	COLOR = vec4(color, 1.0);
}
