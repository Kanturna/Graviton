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

	// Three-direction hexagonal granulation — avoids cross/grid artifact of sin(x)*sin(y)
	// Angles ~0°/60°/115° (slightly off perfect hexagonal to break mathematical regularity)
	// df_t scales amplitude: subtle in overview, distinct at close-up
	vec2 p = n_xy * 11.0;
	float g0 = sin(p.x * 1.00                  + TIME * 0.54);
	float g1 = sin(p.x * 0.48 + p.y * 0.88     - TIME * 0.71);
	float g2 = sin(p.x * 0.52 - p.y * 0.85     + TIME * 0.43);
	float cell_raw = (g0 * 1.00 + g1 * 0.90 + g2 * 0.85) / 2.75;
	float abs_raw = abs(cell_raw);
	float cell_sharp = sign(cell_raw) * (1.0 - pow(1.0 - abs_raw, 2.0));
	float gran = cell_sharp * (1.0 - t * 0.65) * mix(0.06, 0.18, df_t);
	col *= 1.0 + gran;

	// Corona rim glow
	float rim = pow(max(0.0, 1.0 - abs(t_w - 1.0) * 5.5), 2.0) * 0.48;
	col += vec3(1.0, 0.82, 0.48) * rim;

	COLOR = vec4(clamp(col, 0.0, 1.0), alpha);
}
