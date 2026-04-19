shader_type canvas_item;

uniform float df_t = 0.0;
uniform sampler2D star_detail_tex;
uniform float star_closeup_phase = 0.0;
uniform vec3 star_core_color = vec3(1.0, 0.95, 0.80);
uniform vec3 star_mid_color = vec3(1.0, 0.62, 0.18);
uniform vec3 star_channel_color = vec3(0.62, 0.18, 0.08);
uniform float activity_strength = 0.34;
uniform float activity_scale = 4.2;
uniform float filament_strength = 0.30;
uniform float filament_scale = 3.1;
uniform float rim_hotness = 0.78;
uniform float edge_activity_strength = 0.22;
uniform float edge_activity_scale = 5.0;
uniform float macro_surface_strength = 0.26;
uniform float macro_surface_scale = 1.35;
uniform float meso_breakup_strength = 0.22;
uniform float meso_breakup_scale = 2.40;
uniform float granulation_contrast = 1.12;
uniform float channel_contrast = 1.18;
uniform float hotspot_contrast = 1.10;
uniform float detailmap_strength = 0.42;
uniform float detailmap_scale = 1.15;
uniform float prominence_strength = 0.28;
uniform float sunspot_strength = 0.24;


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
	vec2 n_xy = uv / sphere_r;
	float t = dist / sphere_r;

	// Animated corona edge warp — drives both silhouette and internal limb/color/rim
	float angle = atan(uv.y, uv.x);
	float warp = sin(angle * 5.0 + TIME * 0.65) * 0.020
	           + sin(angle * 9.0 - TIME * 1.20) * 0.012
	           + sin(angle * 3.0 + TIME * 0.38) * 0.024;
	// df_t-gated warp gain: silhouette near-circular in overview, breathing at close-up
	float t_w = clamp(t * (1.0 + warp * mix(0.25, 1.0, df_t)), 0.0, 1.2);

	// Silhouette uses the unwarped t: the star always reads as a clean round disc,
	// while limb/color/rim below still breathe with t_w for internal animation.
	// Thresholds: 0.46/0.42 ≈ 1.095, 0.40/0.42 ≈ 0.952 (distance edges in t-space)
	float alpha = smoothstep(1.095, 0.952, t);
	if (alpha <= 0.001) { discard; }

	// Proper limb darkening: center bright, edge ~26% dimmer
	float limb = 1.0 - 0.26 * pow(t_w, 1.7);

	// Radial color temperature: center near-white, edge warmer/more saturated
	vec3 col = mix(star_core_color, star_mid_color, pow(t_w, 1.8)) * limb;

	// Macro surface field stays static: it organizes the star into broad
	// basins / convection regions without making the whole surface drift.
	vec2 macro_uv = n_xy * macro_surface_scale + vec2(2.7, -1.9);
	vec2 macro_warp = vec2(
		_fbm(macro_uv * 0.85 + vec2(4.1, -2.3)),
		_fbm(macro_uv * 0.79 + vec2(-3.6, 5.2))
	) - 0.5;
	macro_uv += macro_warp * 0.85;
	float macro_raw = _fbm(macro_uv);
	float macro_centered = (macro_raw - 0.5) * 2.0;
	float macro_df = mix(0.05, 1.0, smoothstep(0.08, 0.60, df_t));
	float macro_mod = macro_centered * macro_surface_strength * macro_df
		* max(0.0, 1.0 - t * 0.38);
	col *= 1.0 + macro_mod;

	// Three-direction hexagonal granulation — avoids cross/grid artifact of sin(x)*sin(y)
	// Angles ~0°/60°/115° (slightly off perfect hexagonal to break mathematical regularity)
	// df_t scales amplitude: subtle in overview, distinct at close-up
	vec2 p = n_xy * 11.0;
	// Slow low-freq domain warp — breaks the regular hexagonal lattice without adding flicker
	// Warp TIME (0.09/0.11) is ~6× slower than cell TIME → warp is background drift, cells are foreground
	// Amplitude 1.4 on 11-scale ≈ ~13% cell-width offset → visible irregularity, not chaos
	vec2 wp = vec2(sin(p.y * 0.35 + TIME * 0.11),
	               sin(p.x * 0.31 - TIME * 0.09)) * 1.4;
	p += wp;
	float g0 = sin(p.x * 1.00                  + TIME * 0.54);
	float g1 = sin(p.x * 0.48 + p.y * 0.88     - TIME * 0.71);
	float g2 = sin(p.x * 0.52 - p.y * 0.85     + TIME * 0.43);
	float cell_raw = (g0 * 1.00 + g1 * 0.90 + g2 * 0.85) / 2.75;
	// Asymmetric granulation morphology — broad bright upwelling centers,
	// thin dark downwelling lanes. Mirrors solar convection: hot plasma pools
	// separated by a narrower cool network. Lane contrast dominates (0.60 vs 1.35).
	float cell_pos = max(0.0, cell_raw);
	float cell_neg = max(0.0, -cell_raw);
	float bright = pow(cell_pos, 0.65);   // broad, soft hot centers
	float dark   = pow(cell_neg, 2.40);   // narrow, hard cool lanes
	float asym = bright * 0.60 - dark * 1.35;
	float gran = asym * (1.0 - t * 0.65) * mix(0.11, 0.28, df_t);
	col *= 1.0 + gran * granulation_contrast;
	// Temperature tint: lanes pick up a warmer/redder hue, bright centers stay near white.
	// Activity remains color-only; alpha never changes.
	float lane_tint = max(0.0, -asym) * mix(0.18, 0.70, df_t);

	// Add a new meso breakup layer between macro organization and the
	// existing activity fields. It drifts only very slowly.
	float meso_df = smoothstep(0.10, 0.68, df_t);
	vec2 meso_uv = n_xy * meso_breakup_scale + vec2(TIME * 0.018, -TIME * 0.014);
	meso_uv += vec2(macro_centered * 0.70, -macro_centered * 0.45);
	float meso_raw = _fbm(meso_uv + vec2(1.2, -3.4)) * 0.72
		+ _noise(meso_uv * 2.15 + vec2(-2.8, 4.6)) * 0.28;
	float meso_faculae = smoothstep(0.60, 0.82, meso_raw);
	float meso_faculae_add = meso_faculae * meso_breakup_strength * meso_df
		* max(0.0, 1.0 - t * 0.46);
	col += mix(star_mid_color, star_core_color, 0.64) * meso_faculae_add;

	// Add a coarser solar-activity layer above the fine granulation:
	// bright faculae / active regions plus darker channel structures.
	float activity_df = mix(0.14, 1.0, df_t);
	vec2 ap = n_xy * activity_scale;
	ap += vec2(
		sin(ap.y * 0.63 + TIME * 0.08),
		sin(ap.x * 0.57 - TIME * 0.07)
	) * 0.95 + wp * 0.18;
	float a0 = sin(ap.x * 0.92 + TIME * 0.19);
	float a1 = sin(ap.x * 0.41 + ap.y * 0.87 - TIME * 0.14);
	float a2 = sin(ap.x * 0.76 - ap.y * 0.36 + TIME * 0.11);
	float activity_raw = (a0 * 1.00 + a1 * 0.82 + a2 * 0.74) / 2.56;
	float faculae = pow(max(0.0, activity_raw), 1.35);
	float activity_mask = max(0.0, 1.0 - t * 0.52);
	float activity_faculae_add = faculae * activity_strength * activity_df
		* activity_mask * 0.58 * hotspot_contrast;
	col += mix(star_mid_color, star_core_color, 0.72) * activity_faculae_add;

	vec2 fp = n_xy * filament_scale;
	fp += vec2(
		sin(fp.y * 0.79 - TIME * 0.06),
		sin(fp.x * 0.68 + TIME * 0.05)
	) * 1.05 + vec2(activity_raw * 0.80, -activity_raw * 0.60);
	float f0 = sin(fp.x * 0.88 - TIME * 0.12);
	float f1 = sin(fp.x * 0.30 + fp.y * 1.04 + TIME * 0.10);
	float f2 = sin(fp.x * 0.96 - fp.y * 0.52 - TIME * 0.08);
	float filament_raw = (f0 * 0.90 + f1 * 1.00 + f2 * 0.70) / 2.60;
	float filaments = pow(max(0.0, -filament_raw), 1.85);
	float filament_mix = filaments * filament_strength * activity_df
		* max(0.0, 1.0 - t * 0.42) * 0.42;
	float channel_mix = clamp(lane_tint + filament_mix * channel_contrast, 0.0, 0.88);
	col = mix(col, mix(col, star_channel_color, 0.78), channel_mix);

	// P14.6 hybrid closeup layer: a derived detailmap adds structured
	// faculae and darker sunspot/channel complexes only for the focused
	// star closeup path. Alpha stays untouched.
	float detail_phase = smoothstep(0.10, 1.0, star_closeup_phase);
	vec2 detail_drift = vec2(TIME * 0.007, -TIME * 0.005) * detail_phase;
	vec2 detail_uv = n_xy * (0.5 / max(detailmap_scale, 0.001)) + vec2(0.5) + detail_drift;
	float detail_sample = texture(star_detail_tex, detail_uv).r;
	float detail_signal = (detail_sample - 0.5) * 2.0;
	float detail_mask = detail_phase * smoothstep(1.02, 0.82, t);
	float detail_faculae_add = max(0.0, detail_signal) * detailmap_strength * detail_mask;
	float detail_sunspots = max(0.0, -detail_signal) * sunspot_strength * detail_mask;
	col += mix(star_mid_color, star_core_color, 0.82) * detail_faculae_add;
	col = mix(col, mix(col, star_channel_color * 0.82, 0.86), clamp(detail_sunspots, 0.0, 0.68));
	float prominence_hint = max(0.0, detail_signal) * prominence_strength * detail_phase
		* smoothstep(0.62, 0.96, t_w) * (1.0 - smoothstep(0.98, 1.05, t_w));
	col += vec3(1.0, 0.84, 0.38) * prominence_hint * 0.34;

	// Build the hotter inner rim in-shader first; the CPU halo only stays
	// as a subtle atmosphere around it.
	float rim = pow(max(0.0, 1.0 - abs(t_w - 1.0) * 5.5), 2.0) * mix(0.44, 0.78, rim_hotness);
	float edge_zone = smoothstep(0.58, 0.92, t_w) * (1.0 - smoothstep(0.96, 1.05, t_w));
	float edge_signal = sin(angle * edge_activity_scale + TIME * 0.22) * 0.55
		+ sin(angle * (edge_activity_scale * 0.57) - TIME * 0.17) * 0.35
		+ sin(angle * (edge_activity_scale * 1.71) + TIME * 0.11) * 0.20;
	float edge_active = pow(max(0.0, edge_signal), 1.8) * edge_zone
		* edge_activity_strength * mix(0.15, 1.0, df_t);
	col += mix(star_mid_color, star_core_color, 0.58) * rim;
	col += star_core_color * edge_active * 0.68;
	col += vec3(1.0, 0.86, 0.48) * edge_active * 0.34;

	COLOR = vec4(clamp(col, 0.0, 1.0), alpha);
}
