shader_type canvas_item;

uniform float df_t = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);

	float sphere_r = 0.42;
	float alpha = smoothstep(sphere_r + 0.04, sphere_r - 0.02, dist);
	if (alpha <= 0.001) { discard; }

	vec2 n_xy = uv / sphere_r;
	float t = dist / sphere_r;

	// Animated corona edge warp — gives the limb a living, irregular shape
	float angle = atan(uv.y, uv.x);
	float warp = sin(angle * 5.0 + TIME * 0.65) * 0.020
	           + sin(angle * 9.0 - TIME * 1.20) * 0.012
	           + sin(angle * 3.0 + TIME * 0.38) * 0.024;
	float t_w = clamp(t + warp * t, 0.0, 1.2);

	// Proper limb darkening: center bright, edge ~26% dimmer (matches real solar disc)
	float limb = 1.0 - 0.26 * pow(t_w, 1.7);

	// Radial color temperature: center near-white, edge warmer/more saturated
	vec3 center_col = vec3(1.0, 0.97, 0.86);
	vec3 edge_col = vec3(1.0, 0.76, 0.28);
	vec3 col = mix(center_col, edge_col, pow(t_w, 1.8)) * limb;

	// Granulation / convection cell animation — three overlapping sin products
	float gran = sin(n_xy.x * 10.0 + TIME * 1.90) * sin(n_xy.y * 8.5 - TIME * 1.40) * 0.50
	           + sin(n_xy.x * 16.0 - TIME * 2.80) * sin(n_xy.y * 13.0 + TIME * 2.10) * 0.30
	           + sin((n_xy.x * 1.2 + n_xy.y * 0.8) * 7.0 + TIME * 1.10) * 0.20;
	gran = gran * (1.0 - t * 0.65) * 0.065;
	col *= 1.0 + gran;

	// Corona rim glow
	float rim = pow(max(0.0, 1.0 - abs(t_w - 1.0) * 5.5), 2.0) * 0.48;
	col += vec3(1.0, 0.82, 0.48) * rim;

	COLOR = vec4(clamp(col, 0.0, 1.0), alpha);
}
