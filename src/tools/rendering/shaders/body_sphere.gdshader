shader_type canvas_item;

uniform vec3 base_color = vec3(0.42, 0.69, 1.0);
uniform vec3 atmo_color = vec3(0.54, 0.78, 1.0);
uniform float terminator_softness = 0.28;
uniform float rim_strength = 0.32;
uniform float df_t = 0.0;
uniform float rotation_speed = 0.06;
uniform float surface_freq = 8.0;
uniform float surface_var_strength = 0.06;
uniform float polar_tint_strength = 0.18;
uniform float band_strength = 0.36;   // planet: atmospheric bands; 0 for moon
uniform float patch_strength = 0.0;   // moon: albedo patches; 0 for planet

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);

	float sphere_r = 0.42;
	float alpha = smoothstep(sphere_r + 0.04, sphere_r - 0.02, dist);
	if (alpha <= 0.001) { discard; }

	vec2 n_xy = uv / sphere_r;
	float nz = sqrt(max(0.0, 1.0 - dot(n_xy, n_xy)));
	vec3 n = normalize(vec3(n_xy, nz));

	// Lighting always uses unrotated n — terminator stays fixed
	vec3 light = normalize(vec3(-0.6, -0.6, 0.8));
	float ndotl = dot(n, light);
	float lit = smoothstep(-terminator_softness, terminator_softness, ndotl);
	float limb = pow(max(0.0, n.z), 0.38);
	float ambient = 0.07;
	float diffuse = (ambient + (1.0 - ambient) * lit) * limb;
	float rim = pow(1.0 - max(0.0, n.z), 3.5) * rim_strength;
	rim *= smoothstep(0.0, 0.4, lit + 0.3);

	// Rotate surface domain — only the texture rotates, not the lighting
	float rot = TIME * rotation_speed;
	float cr = cos(rot);
	float sr = sin(rot);
	vec2 n_rot = vec2(cr * n.x - sr * n.y, sr * n.x + cr * n.y);

	// Slow domain warp — band edges deform on a much longer timescale than the rotation
	// df_t scales warp amplitude: almost none in overview, turbulent at close-up
	float warp_amp = mix(0.03, 0.14, df_t);
	float wx = (sin(n_rot.y * 3.5 + TIME * 0.07) + sin(n_rot.y * 6.1 - TIME * 0.11) * 0.50) * warp_amp;
	float wy = sin(n_rot.x * 2.9 - TIME * 0.05) * warp_amp * 0.65;
	vec2 n_w = n_rot + vec2(wx, wy);

	// Surface base color
	vec3 surface_col = base_color;

	// Atmospheric bands (planet): three overlapping sin layers on warped domain
	// band_strength=0 → no effect (moon path)
	float band_raw = sin(n_w.y * 2.8 + n_w.x * 0.75) * 0.50
	               + sin(n_w.y * 4.7 - n_w.x * 0.55 + 1.8) * 0.32
	               + sin(n_w.y * 1.5 + n_w.x * 0.35 + 3.2) * 0.18;
	float band = band_raw * 0.50 + 0.50;  // remap [-1,1] to [0,1]
	vec3 band_dark  = base_color * vec3(0.80, 0.83, 0.76);
	vec3 band_light = base_color * vec3(1.10, 1.08, 1.14);
	vec3 band_col = mix(band_dark, band_light, band);
	surface_col = mix(surface_col, band_col, band_strength);

	// Albedo patches (moon): bilinear value noise on rotated domain
	// patch_strength=0 → no effect (planet path)
	vec2 p = n_rot * 1.8;
	vec2 pi2 = floor(p);
	vec2 pf = fract(p);
	pf = pf * pf * (3.0 - 2.0 * pf);
	float albedo = mix(
		mix(fract(sin(dot(pi2,             vec2(127.1, 311.7))) * 43758.5),
		    fract(sin(dot(pi2 + vec2(1,0), vec2(127.1, 311.7))) * 43758.5), pf.x),
		mix(fract(sin(dot(pi2 + vec2(0,1), vec2(127.1, 311.7))) * 43758.5),
		    fract(sin(dot(pi2 + vec2(1,1), vec2(127.1, 311.7))) * 43758.5), pf.x), pf.y);
	surface_col *= 1.0 + (albedo - 0.5) * patch_strength;

	// Secondary fine breakup over primary surface feature
	float f = surface_freq;
	float sv = sin(n_rot.x * f        + n_rot.y * (f * 0.81))
	         + sin(n_rot.x * (f * 0.58) - n_rot.y * (f * 1.45)) * 0.60
	         + sin((n_rot.x + n_rot.y) * (f * 0.93))              * 0.40;
	float surface_var = sv * surface_var_strength * 0.50;

	// Polar brightening (rotates with surface)
	vec3 polar_tint = vec3(0.92, 0.95, 1.0);

	vec3 col = surface_col * diffuse;
	col += col * surface_var;
	col = mix(col, col * polar_tint, pow(abs(n_rot.y), 3.0) * polar_tint_strength);
	col += atmo_color * rim;

	COLOR = vec4(col, alpha);
}
