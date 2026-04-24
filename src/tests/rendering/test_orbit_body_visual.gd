extends RefCounted

const OrbitBodyVisualScript = preload("res://src/tools/rendering/orbit_body_visual.gd")
const PlanetVisualProfileScript = preload("res://src/tools/rendering/planet_visual_profile.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_body_visual"
	_test_star_material_keeps_detailmap_active(ctx)
	_test_moon_material_enables_hybrid_reference(ctx)
	_test_planet_material_keeps_reference_disabled(ctx)
	_test_singleton_fallback_textures_are_reused(ctx)
	_test_temperate_theme_enables_hybrid_reference(ctx)
	_test_frozen_theme_enables_hybrid_reference(ctx)
	_test_hot_theme_enables_hybrid_reference(ctx)
	_test_identical_theme_apply_is_idempotent(ctx)
	_test_detail_redraw_ignores_tiny_focus_jitter(ctx)


static func _test_star_material_keeps_detailmap_active(ctx) -> void:
	var mat: ShaderMaterial = OrbitBodyVisualScript._make_sphere_material(BodyType.Kind.STAR)
	ctx.assert_true(mat != null, "star material kann erzeugt werden")
	ctx.assert_true(
		mat.get_shader_parameter("star_reference_tex") != null,
		"star material bindet jetzt zusaetzlich eine solar reference texture"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("star_reference_strength")) > 0.0,
		"star material aktiviert jetzt einen bildgefuehrten solar hybrid blend"
	)
	ctx.assert_true(
		mat.get_shader_parameter("star_detail_tex") != null,
		"star material bindet weiter eine solar detailmap"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("detailmap_strength")) >= 0.42,
		"star material behaelt die solar detailmap weiter als sekundere Strukturquelle aktiv"
	)


static func _test_moon_material_enables_hybrid_reference(ctx) -> void:
	var mat: ShaderMaterial = OrbitBodyVisualScript._make_sphere_material(BodyType.Kind.MOON)
	ctx.assert_true(mat != null, "moon material kann erzeugt werden")
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_strength")) > 0.0,
		"moon material aktiviert den hybriden reference blend"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_center_preserve")) > 0.0,
		"moon material schuetzt das Referenzzentrum vor zu starker Vollflaechen-Schattierung"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_procedural_damp")) > 0.0,
		"moon material daempft den alten prozeduralen Mond-Look unter der Referenz"
	)
	ctx.assert_true(
		mat.get_shader_parameter("surface_reference_tex") != null,
		"moon material bindet eine reference texture"
	)


static func _test_planet_material_keeps_reference_disabled(ctx) -> void:
	var mat: ShaderMaterial = OrbitBodyVisualScript._make_sphere_material(BodyType.Kind.PLANET)
	ctx.assert_true(mat != null, "planet material kann erzeugt werden")
	ctx.assert_true(
		is_zero_approx(float(mat.get_shader_parameter("surface_reference_strength"))),
		"planet material bleibt im ersten Pilot ohne reference blend"
	)


static func _test_singleton_fallback_textures_are_reused(ctx) -> void:
	var white_a: Texture2D = OrbitBodyVisualScript._make_white_1px()
	var white_b: Texture2D = OrbitBodyVisualScript._make_white_1px()
	var transparent_a: Texture2D = OrbitBodyVisualScript._make_transparent_1px()
	var transparent_b: Texture2D = OrbitBodyVisualScript._make_transparent_1px()
	ctx.assert_true(white_a == white_b, "white fallback texture wird als Singleton wiederverwendet")
	ctx.assert_true(transparent_a == transparent_b, "transparent fallback texture wird als Singleton wiederverwendet")


static func _test_temperate_theme_enables_hybrid_reference(ctx) -> void:
	var visual = _make_visual(BodyType.Kind.PLANET)
	visual.apply_planet_theme(PlanetVisualProfileScript._make_temperate_ocean_theme())
	var mat: ShaderMaterial = visual._sphere.material as ShaderMaterial
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_strength")) > 0.0,
		"TEMPERATE_OCEAN aktiviert jetzt einen planetaren hybrid reference blend"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_radius")) < 0.46,
		"TEMPERATE_OCEAN cropped die Referenz enger als den Moon-Pilot"
	)
	ctx.assert_true(
		mat.get_shader_parameter("surface_reference_tex") != null,
		"TEMPERATE_OCEAN bindet eine Referenz-Texture"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_native_color_strength")) >= 0.90,
		"TEMPERATE_OCEAN bevorzugt jetzt die nativen Farben der Referenz deutlich staerker"
	)
	ctx.assert_true(
		is_equal_approx(float(mat.get_shader_parameter("surface_reference_rotation_domain")), 0.0),
		"TEMPERATE_OCEAN nutzt jetzt den verzerrungsfreien disc-preserving Rotationspfad"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_min_gate")) >= 1.0,
		"TEMPERATE_OCEAN haelt die Referenz jetzt auch in der Fernansicht voll aktiv"
	)
	ctx.assert_true(
		is_zero_approx(float(mat.get_shader_parameter("surface_reference_portrait_strength"))),
		"TEMPERATE_OCEAN nutzt keinen separaten portrait-stabilen Closeup-Sprite mehr"
	)
	ctx.assert_true(
		is_zero_approx(float(mat.get_shader_parameter("cloud_strength"))),
		"TEMPERATE_OCEAN legt keine zusaetzlichen Shader-Wolken mehr ueber die Referenz"
	)
	_free_visual(visual)


static func _test_frozen_theme_enables_hybrid_reference(ctx) -> void:
	var visual = _make_visual(BodyType.Kind.PLANET)
	visual.apply_planet_theme(PlanetVisualProfileScript._make_frozen_theme())
	var mat: ShaderMaterial = visual._sphere.material as ShaderMaterial
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_strength")) > 0.0,
		"FROZEN aktiviert jetzt einen planetaren hybrid reference blend"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_center_preserve")) > 0.0,
		"FROZEN schuetzt die icy reference im Zentrum vor zu starker Vollflaechen-Schattierung"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_native_color_strength")) >= 0.90,
		"FROZEN bevorzugt jetzt die nativen Farben der Referenz deutlich staerker"
	)
	ctx.assert_true(
		is_equal_approx(float(mat.get_shader_parameter("surface_reference_rotation_domain")), 0.0),
		"FROZEN nutzt jetzt den verzerrungsfreien disc-preserving Rotationspfad"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_min_gate")) >= 1.0,
		"FROZEN haelt die Referenz jetzt auch in der Fernansicht voll aktiv"
	)
	ctx.assert_true(
		is_zero_approx(float(mat.get_shader_parameter("surface_reference_portrait_strength"))),
		"FROZEN nutzt keinen separaten portrait-stabilen Closeup-Sprite mehr"
	)
	ctx.assert_true(
		is_zero_approx(float(mat.get_shader_parameter("cloud_strength"))),
		"FROZEN legt keine zusaetzlichen Shader-Wolken mehr ueber die Referenz"
	)
	_free_visual(visual)


static func _test_hot_theme_enables_hybrid_reference(ctx) -> void:
	var visual = _make_visual(BodyType.Kind.PLANET)
	visual.apply_planet_theme(PlanetVisualProfileScript._make_hot_scorched_theme())
	var mat: ShaderMaterial = visual._sphere.material as ShaderMaterial
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_strength")) > 0.0,
		"HOT_SCORCHED aktiviert jetzt einen planetaren hybrid reference blend"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("surface_reference_rim_boost")) > 0.0,
		"HOT_SCORCHED behaelt zusaetzlich einen shaderseitig verstaerkten heissen Rand"
	)
	ctx.assert_true(
		is_equal_approx(float(mat.get_shader_parameter("surface_reference_rotation_domain")), 1.0),
		"HOT_SCORCHED bleibt beim bestehenden rotationsgekoppelten Hybridpfad"
	)
	ctx.assert_true(
		is_zero_approx(float(mat.get_shader_parameter("surface_reference_portrait_strength"))),
		"HOT_SCORCHED bleibt ohne separaten portrait-stabilen Closeup-Sprite"
	)
	_free_visual(visual)


static func _test_identical_theme_apply_is_idempotent(ctx) -> void:
	var visual = _make_visual(BodyType.Kind.PLANET)
	visual.apply_planet_theme(PlanetVisualProfileScript._make_temperate_ocean_theme())
	var apply_count_after_first_theme: int = visual.get_theme_apply_count()
	visual.apply_planet_theme(PlanetVisualProfileScript._make_temperate_ocean_theme())
	ctx.assert_true(apply_count_after_first_theme == 1, "erstes Theme-Apply wird einmal gezaehlt")
	ctx.assert_true(
		visual.get_theme_apply_count() == apply_count_after_first_theme,
		"identische Theme-Werte loesen kein zweites Material-Apply aus"
	)
	_free_visual(visual)


static func _test_detail_redraw_ignores_tiny_focus_jitter(ctx) -> void:
	var planet_visual = _make_visual(BodyType.Kind.PLANET)
	planet_visual.set_detail_factor(1.0 + OrbitBodyVisualScript.DETAIL_FACTOR_REDRAW_EPSILON * 0.5)
	ctx.assert_almost(
		planet_visual._detail_factor,
		1.0,
		0.000001,
		"Sub-Epsilon Detail-Jitter schreibt keinen neuen Redraw-/Shader-State"
	)
	planet_visual.set_detail_factor(1.0 + OrbitBodyVisualScript.DETAIL_FACTOR_REDRAW_EPSILON * 2.0)
	ctx.assert_true(
		planet_visual._detail_factor > 1.0,
		"Groessere Detail-Aenderungen aktualisieren den Visual-State weiterhin"
	)
	_free_visual(planet_visual)

	var star_visual = _make_visual(BodyType.Kind.STAR)
	star_visual.set_star_closeup_phase(OrbitBodyVisualScript.STAR_CLOSEUP_PHASE_REDRAW_EPSILON * 0.5)
	ctx.assert_almost(
		star_visual._star_closeup_phase,
		0.0,
		0.000001,
		"Sub-Epsilon Star-Closeup-Jitter schreibt keinen neuen Redraw-/Shader-State"
	)
	star_visual.set_star_closeup_phase(OrbitBodyVisualScript.STAR_CLOSEUP_PHASE_REDRAW_EPSILON * 2.0)
	ctx.assert_true(
		star_visual._star_closeup_phase > 0.0,
		"Groessere Star-Closeup-Aenderungen aktualisieren den Visual-State weiterhin"
	)
	_free_visual(star_visual)


static func _make_visual(kind: int):
	var visual = OrbitBodyVisualScript.new()
	visual.configure(kind)
	visual._ready()
	return visual


static func _free_visual(visual) -> void:
	if visual != null:
		visual.free()
