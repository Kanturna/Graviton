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

	// Proper limb darkening: center bright, edge ~26% dimmer
	float limb = 1.0 - 0.26 * pow(t_w, 1.7);

	// Radial color temperature: center near-white, edge warmer/more saturated
	vec3 center_col = vec3(1.0, 0.97, 0.86);
	vec3 edge_col = vec3(1.0, 0.76, 0.28);
	vec3 col = mix(center_col, edge_col, pow(t_w, 1.8)) * limb;

	// Sharpened granulation cells with higher contrast
	// Two sin-product layers create a cell-like pattern
	float cell1 = sin(n_xy.x * 9.0 + TIME * 3.2) * sin(n_xy.y * 8.0 - TIME * 2.6);
	float cell2 = sin(n_xy.x * 14.0 - TIME * 4.1) * sin(n_xy.y * 11.0 + TIME * 3.0);
	float cell_raw = cell1 * 0.55 + cell2 * 0.45;
	// Push toward ±1 for sharper, more distinct cell boundaries
	float abs_raw = abs(cell_raw);
	float cell_sharp = sign(cell_raw) * (1.0 - pow(1.0 - abs_raw, 1.5));
	float gran = cell_sharp * (1.0 - t * 0.65) * 0.18;
	col *= 1.0 + gran;

	// Corona rim glow
	float rim = pow(max(0.0, 1.0 - abs(t_w - 1.0) * 5.5), 2.0) * 0.48;
	col += vec3(1.0, 0.82, 0.48) * rim;

	COLOR = vec4(clamp(col, 0.0, 1.0), alpha);
}
