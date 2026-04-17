shader_type canvas_item;

uniform vec3 base_color = vec3(0.42, 0.69, 1.0);
uniform vec3 atmo_color = vec3(0.54, 0.78, 1.0);
uniform float terminator_softness = 0.28;
uniform float rim_strength = 0.32;
uniform float df_t = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);

	float sphere_r = 0.42;
	float alpha = smoothstep(sphere_r + 0.04, sphere_r - 0.02, dist);
	if (alpha <= 0.001) { discard; }

	vec2 n_xy = uv / sphere_r;
	float nz = sqrt(max(0.0, 1.0 - dot(n_xy, n_xy)));
	vec3 n = normalize(vec3(n_xy, nz));

	vec3 light = normalize(vec3(-0.6, -0.6, 0.8));
	float ndotl = dot(n, light);

	float lit = smoothstep(-terminator_softness, terminator_softness, ndotl);
	float limb = pow(max(0.0, n.z), 0.55);

	float ambient = 0.07;
	float diffuse = (ambient + (1.0 - ambient) * lit) * limb;

	float rim = pow(1.0 - max(0.0, n.z), 3.5) * rim_strength;
	rim *= smoothstep(0.0, 0.4, lit + 0.3);

	vec3 col = base_color * diffuse + atmo_color * rim;
	COLOR = vec4(col, alpha);
}
