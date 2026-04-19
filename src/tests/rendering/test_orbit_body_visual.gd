extends RefCounted

const OrbitBodyVisualScript = preload("res://src/tools/rendering/orbit_body_visual.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_body_visual"
	_test_moon_material_enables_hybrid_reference(ctx)
	_test_planet_material_keeps_reference_disabled(ctx)


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
