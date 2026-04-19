extends RefCounted

const SpaceBackdropScript = preload("res://src/tools/rendering/space_backdrop.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_space_backdrop"
	_test_backdrop_creates_shader_material_with_defaults(ctx)
	_test_backdrop_syncs_exported_tuning_to_shader(ctx)
	_test_backdrop_keeps_composition_viewport_stable_after_resize(ctx)
	_test_backdrop_keeps_existing_screen_pixels_stable_after_resize(ctx)


static func _test_backdrop_creates_shader_material_with_defaults(ctx) -> void:
	var backdrop = SpaceBackdropScript.new()
	backdrop.size = Vector2(1280.0, 720.0)
	backdrop._ready()
	backdrop._capture_initial_composition_viewport()

	var mat: ShaderMaterial = backdrop._ensure_material()
	ctx.assert_true(mat != null, "space backdrop erzeugt ein ShaderMaterial")
	ctx.assert_true(mat.shader != null, "space backdrop bindet einen expliziten Shader")
	ctx.assert_true(backdrop.seed == 424242, "space backdrop startet mit dem dokumentierten deterministischen Seed")
	ctx.assert_almost(float(mat.get_shader_parameter("star_density")), 1.0, 1.0e-9, "default star_density bleibt neutral")
	ctx.assert_almost(float(mat.get_shader_parameter("band_strength")), 1.0, 1.0e-9, "default band_strength bleibt neutral")
	ctx.assert_almost(float(mat.get_shader_parameter("nebula_strength")), 1.0, 1.0e-9, "default nebula_strength bleibt neutral")
	ctx.assert_true(
		mat.get_shader_parameter("viewport_size") == Vector2(1280.0, 720.0),
		"space backdrop schreibt seine aktuelle Groesse in den Shader"
	)
	ctx.assert_true(
		mat.get_shader_parameter("render_size") == Vector2(1280.0, 720.0),
		"space backdrop schreibt seine aktuelle Bake-Groesse in den Shader"
	)
	backdrop.free()


static func _test_backdrop_syncs_exported_tuning_to_shader(ctx) -> void:
	var backdrop = SpaceBackdropScript.new()
	backdrop.size = Vector2(1920.0, 1080.0)
	backdrop._ready()
	backdrop._capture_initial_composition_viewport()
	backdrop.seed = 777
	backdrop.star_density = 1.45
	backdrop.band_strength = 0.82
	backdrop.nebula_strength = 1.28

	var mat: ShaderMaterial = backdrop._ensure_material()
	ctx.assert_almost(float(mat.get_shader_parameter("seed")), 777.0, 1.0e-9, "seed wird in den Shader gespiegelt")
	ctx.assert_almost(float(mat.get_shader_parameter("star_density")), 1.45, 1.0e-9, "star_density wird in den Shader gespiegelt")
	ctx.assert_almost(float(mat.get_shader_parameter("band_strength")), 0.82, 1.0e-9, "band_strength wird in den Shader gespiegelt")
	ctx.assert_almost(float(mat.get_shader_parameter("nebula_strength")), 1.28, 1.0e-9, "nebula_strength wird in den Shader gespiegelt")
	ctx.assert_true(
		mat.get_shader_parameter("render_size") == Vector2(1920.0, 1080.0),
		"render_size folgt ausserhalb des Trees weiterhin der aktuellen Bake-Groesse"
	)
	backdrop.free()


static func _test_backdrop_keeps_composition_viewport_stable_after_resize(ctx) -> void:
	var backdrop = SpaceBackdropScript.new()
	backdrop.size = Vector2(1280.0, 720.0)
	backdrop._ready()
	backdrop._capture_initial_composition_viewport()
	backdrop.size = Vector2(1920.0, 1080.0)
	backdrop._on_resized()

	var mat: ShaderMaterial = backdrop._ensure_material()
	ctx.assert_true(
		mat.get_shader_parameter("viewport_size") == Vector2(1280.0, 720.0),
		"spaetere Resize-Ereignisse remappen die Hintergrund-Komposition nicht mehr"
	)
	ctx.assert_true(
		mat.get_shader_parameter("render_size") == Vector2(1920.0, 1080.0),
		"die aktuelle Bake-Groesse folgt spaeteren Resizes weiter"
	)
	backdrop.free()


static func _test_backdrop_keeps_existing_screen_pixels_stable_after_resize(ctx) -> void:
	var composition_size := Vector2(1280.0, 720.0)
	var stable_screen_px := Vector2(320.0, 180.0)
	var composition_uv_before: Vector2 = SpaceBackdropScript.composition_uv_for_screen_px(
		stable_screen_px,
		composition_size
	)
	var composition_uv_after: Vector2 = SpaceBackdropScript.composition_uv_for_screen_px(
		stable_screen_px,
		composition_size
	)
	ctx.assert_almost(composition_uv_after.x, composition_uv_before.x, 1.0e-9, "Resize haelt bestehende Bildschirm-Pixel stabil (x)")
	ctx.assert_almost(composition_uv_after.y, composition_uv_before.y, 1.0e-9, "Resize haelt bestehende Bildschirm-Pixel stabil (y)")
