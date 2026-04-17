shader_type canvas_item;

uniform float df_t = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);

	float sphere_r = 0.42;
	float alpha = smoothstep(sphere_r + 0.04, sphere_r - 0.02, dist);
	if (alpha <= 0.001) { discard; }

	float t = dist / sphere_r;

	float limb_bright = 1.0 + 0.35 * pow(t, 1.8);

	vec3 center_col = vec3(1.0, 0.97, 0.86);
	vec3 edge_col = vec3(1.0, 0.82, 0.36);
	vec3 col = mix(center_col, edge_col, pow(t, 1.4)) * limb_bright;

	float rim = pow(max(0.0, 1.0 - abs(t - 1.0) * 6.0), 2.0) * 0.55;
	col += vec3(1.0, 0.88, 0.60) * rim;

	if (df_t > 0.4) {
		vec2 cell = floor(uv * 28.0 + 0.5);
		float h = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5);
		float noise_strength = (df_t - 0.4) * 0.06;
		col *= 1.0 - noise_strength * (0.5 - h);
	}

	COLOR = vec4(clamp(col, 0.0, 1.0), alpha);
}
