shader_type canvas_item;

uniform vec3 base_color = vec3(0.42, 0.69, 1.0);
uniform vec3 secondary_color = vec3(0.32, 0.55, 0.82);
uniform vec3 accent_color = vec3(0.78, 0.88, 0.98);
uniform vec3 atmo_color = vec3(0.54, 0.78, 1.0);
uniform float terminator_softness = 0.28;
uniform float rim_strength = 0.32;
uniform float df_t = 0.0;
uniform float rotation_speed = 0.06;
uniform float surface_freq = 8.0;
uniform float surface_var_strength = 0.06;
uniform float polar_tint_strength = 0.18;
uniform float band_strength = 0.36;   // generic large-scale breakup
uniform float patch_strength = 0.0;   // generic albedo patches / moon breakup
uniform float land_ocean_strength = 0.0;
uniform float cloud_strength = 0.0;
uniform float ice_strength = 0.0;
uniform float lava_strength = 0.0;
uniform float dryness_strength = 0.0;
uniform float crater_strength = 0.0;
// Rotation domain: 0.0 = screen-plane (features orbit disk center; moon legacy)
//                  1.0 = spherical Y-axis (features traverse limb to limb; planet)
uniform float spherical_mix = 0.0;


float _hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}


float _noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = _hash21(i);
	float b = _hash21(i + vec2(1.0, 0.0));
	float c = _hash21(i + vec2(0.0, 1.0));
	float d = _hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


float _fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += _noise(p) * amplitude;
		p = p * 2.03 + vec2(17.3, 11.7);
		amplitude *= 0.5;
	}
	return value;
}


void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);

	float sphere_r = 0.42;
	float alpha = smoothstep(sphere_r + 0.04, sphere_r - 0.02, dist);
	if (alpha <= 0.001) {
		discard;
	}

	vec2 n_xy = uv / sphere_r;
	float nz = sqrt(max(0.0, 1.0 - dot(n_xy, n_xy)));
	vec3 n = normalize(vec3(n_xy, nz));

	vec3 light = normalize(vec3(-0.6, -0.6, 0.8));
	float ndotl = dot(n, light);
	float lit = smoothstep(-terminator_softness, terminator_softness, ndotl);
	float limb = pow(max(0.0, n.z), 0.38);
	float ambient = 0.07;
	float diffuse = (ambient + (1.0 - ambient) * lit) * limb;
	float rim = pow(1.0 - max(0.0, n.z), 3.5) * rim_strength;
	rim *= smoothstep(0.0, 0.4, lit + 0.3);

	float rot = TIME * rotation_speed;
	float cr = cos(rot);
	float sr = sin(rot);
	vec2 n_flat = vec2(cr * n.x - sr * n.y, sr * n.x + cr * n.y);
	float lon = atan(n.x, n.z) - rot;
	float lat = n.y;
	vec2 n_sph = vec2(lon, lat);
	vec2 n_rot = mix(n_flat, n_sph, spherical_mix);

	float warp_amp = mix(0.03, 0.14, df_t);
	float wx = (sin(n_rot.y * 3.5 + TIME * 0.07) + sin(n_rot.y * 6.1 - TIME * 0.11) * 0.50) * warp_amp;
	float wy = sin(n_rot.x * 2.9 - TIME * 0.05) * warp_amp * 0.65;
	vec2 n_w = n_rot + vec2(wx, wy);

	vec3 surface_col = base_color;

	float band_raw = sin(n_w.y * 2.8 + n_w.x * 0.75) * 0.50
		+ sin(n_w.y * 4.7 - n_w.x * 0.55 + 1.8) * 0.32
		+ sin(n_w.y * 1.5 + n_w.x * 0.35 + 3.2) * 0.18;
	float band = band_raw * 0.50 + 0.50;
	vec3 band_dark = base_color * vec3(0.80, 0.83, 0.76);
	vec3 band_light = mix(base_color, secondary_color, 0.35) * vec3(1.08, 1.06, 1.12);
	vec3 band_col = mix(band_dark, band_light, band);
	surface_col = mix(surface_col, band_col, band_strength);

	vec2 p = n_rot * 1.8;
	float albedo_noise = _noise(p);
	surface_col *= 1.0 + (albedo_noise - 0.5) * patch_strength;

	float mid_detail = smoothstep(0.10, 0.22, df_t);
	float high_detail = smoothstep(0.60, 0.78, df_t);
	vec2 theme_uv = vec2(n_sph.x * 0.32, n_sph.y * 2.2);
	float macro_noise = _fbm(theme_uv * 1.20 + vec2(1.7, -0.9));
	float micro_noise = _fbm(theme_uv * 3.40 + vec2(-2.3, 4.1));
	float breakup_noise = _fbm((n_w + vec2(0.7, -1.3)) * 2.0);
	float polar_mask = pow(clamp(abs(n.y), 0.0, 1.0), 2.8);
	float land_mask = smoothstep(0.44, 0.66, macro_noise + breakup_noise * 0.18);
	float coast_mask = land_mask * (1.0 - land_mask) * 4.0;
	float cloud_mask = smoothstep(
		0.56,
		0.74,
		_fbm(theme_uv * 4.0 + vec2(TIME * 0.015, -TIME * 0.008))
	);
	float ice_noise = _fbm(theme_uv * 5.5 + vec2(3.2, -4.0));
	float ice_mask = smoothstep(0.48, 0.86, polar_mask + ice_noise * 0.22);
	float crater_field = _noise(theme_uv * 12.0 + vec2(5.8, -1.7));
	float crater_mask = smoothstep(0.78, 0.96, crater_field)
		* (1.0 - smoothstep(0.25, 0.82, cloud_strength + land_ocean_strength));
	float scorch_noise = _fbm(theme_uv * 2.8 + vec2(-TIME * 0.008, TIME * 0.004));
	float crack_wave = abs(sin(n_sph.x * 18.0 + scorch_noise * 6.0 + n_sph.y * 5.0));
	float lava_mask = pow(1.0 - crack_wave, 18.0) * smoothstep(0.28, 0.72, scorch_noise);
	float dust_mask = smoothstep(0.42, 0.78, micro_noise * 0.65 + macro_noise * 0.35);

	surface_col = mix(
		surface_col,
		mix(base_color, secondary_color, 0.72),
		land_mask * land_ocean_strength * mid_detail
	);
	surface_col += accent_color * coast_mask * land_ocean_strength * high_detail * 0.08;
	surface_col = mix(
		surface_col,
		mix(secondary_color, accent_color, 0.28),
		dust_mask * dryness_strength * mid_detail * 0.60
	);
	surface_col = mix(
		surface_col,
		mix(secondary_color, vec3(1.0), 0.45),
		ice_mask * ice_strength * (0.35 + 0.65 * mid_detail)
	);
	surface_col = mix(
		surface_col,
		accent_color,
		lava_mask * lava_strength * high_detail * 0.65
	);
	surface_col = mix(
		surface_col,
		surface_col * 0.72 + accent_color * 0.10,
		crater_mask * crater_strength * high_detail
	);

	float f = surface_freq;
	float sv = sin(n_rot.x * f + n_rot.y * (f * 0.81))
		+ sin(n_rot.x * (f * 0.58) - n_rot.y * (f * 1.45)) * 0.60
		+ sin((n_rot.x + n_rot.y) * (f * 0.93)) * 0.40;
	float surface_var = sv * surface_var_strength * 0.50;

	vec3 polar_tint = vec3(0.92, 0.95, 1.0);
	vec3 col = surface_col * diffuse;
	col += col * surface_var;
	col = mix(col, col * polar_tint, pow(abs(n_rot.y), 3.0) * polar_tint_strength);

	float cloud_mix = cloud_mask * cloud_strength * high_detail;
	col = mix(col, vec3(1.0), cloud_mix * 0.65);
	col += accent_color * lava_mask * lava_strength * high_detail * 0.28 * (0.35 + 0.65 * lit);
	col += atmo_color * rim;

	COLOR = vec4(col, alpha);
}
