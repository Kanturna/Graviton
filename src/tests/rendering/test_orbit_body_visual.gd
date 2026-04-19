extends RefCounted

const OrbitBodyVisualScript = preload("res://src/tools/rendering/orbit_body_visual.gd")
const PlanetVisualProfileScript = preload("res://src/tools/rendering/planet_visual_profile.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_body_visual"
	_test_star_material_keeps_detailmap_active(ctx)
	_test_moon_material_enables_hybrid_reference(ctx)
	_test_planet_material_keeps_reference_disabled(ctx)
	_test_temperate_theme_enables_hybrid_reference(ctx)
	_test_frozen_theme_enables_hybrid_reference(ctx)
	_test_hot_theme_enables_hybrid_reference(ctx)


static func _test_star_material_keeps_detailmap_active(ctx) -> void:
	var mat: ShaderMaterial = OrbitBodyVisualScript._make_sphere_material(BodyType.Kind.STAR)
	ctx.assert_true(mat != null, "star material kann erzeugt werden")
	ctx.assert_true(
		mat.get_shader_parameter("star_detail_tex") != null,
		"star material bindet weiter eine solar detailmap"
	)
	ctx.assert_true(
		float(mat.get_shader_parameter("detailmap_strength")) >= 0.60,
		"star material liest die solar detailmap im aktuellen Follow-up etwas staerker"
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


static func _make_visual(kind: int):
	var visual = OrbitBodyVisualScript.new()
	visual.configure(kind)
	visual._ready()
	return visual
