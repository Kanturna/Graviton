shader_type canvas_item;

uniform vec3 base_color = vec3(0.42, 0.69, 1.0);
uniform vec3 atmo_color = vec3(0.54, 0.78, 1.0);
uniform float terminator_softness = 0.28;
uniform float rim_strength = 0.32;
uniform float df_t = 0.0;
uniform float rotation_speed = 0.06;
uniform float surface_freq = 8.0;
uniform float surface_var_strength = 0.09;
uniform float polar_tint_strength = 0.20;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);

	float sphere_r = 0.42;
	float alpha = smoothstep(sphere_r + 0.04, sphere_r - 0.02, dist);
	if (alpha <= 0.001) { discard; }

	vec2 n_xy = uv / sphere_r;
	float nz = sqrt(max(0.0, 1.0 - dot(n_xy, n_xy)));
	vec3 n = normalize(vec3(n_xy, nz));

	// Lighting always uses the unrotated normal — terminator stays fixed
	vec3 light = normalize(vec3(-0.6, -0.6, 0.8));
	float ndotl = dot(n, light);
	float lit = smoothstep(-terminator_softness, terminator_softness, ndotl);
	float limb = pow(max(0.0, n.z), 0.38);

	float ambient = 0.07;
	float diffuse = (ambient + (1.0 - ambient) * lit) * limb;

	float rim = pow(1.0 - max(0.0, n.z), 3.5) * rim_strength;
	rim *= smoothstep(0.0, 0.4, lit + 0.3);

	// Rotate the surface domain over TIME — simulates body rotation
	// The normal n used for lighting is unrotated, so terminator does not move
	float rot = TIME * rotation_speed;
	float cr = cos(rot);
	float sr = sin(rot);
	vec2 n_rot = vec2(cr * n.x - sr * n.y, sr * n.x + cr * n.y);

	// Surface variation: three sin frequencies on the rotated domain
	float f = surface_freq;
	float sv = sin(n_rot.x * f        + n_rot.y * (f * 0.81))
	         + sin(n_rot.x * (f * 0.58) - n_rot.y * (f * 1.45)) * 0.60
	         + sin((n_rot.x + n_rot.y) * (f * 0.93))              * 0.40;
	float surface_var = sv * surface_var_strength * 0.50;

	// Polar brightening: lighter/cooler at poles, rotates with surface
	vec3 polar_tint = vec3(0.92, 0.95, 1.0);

	vec3 col = base_color * diffuse;
	col += col * surface_var;
	col = mix(col, col * polar_tint, pow(abs(n_rot.y), 3.0) * polar_tint_strength);
	col += atmo_color * rim;

	COLOR = vec4(col, alpha);
}
