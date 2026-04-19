extends RefCounted

const SpaceBackdropScript = preload("res://src/tools/rendering/space_backdrop.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_space_backdrop"
	_test_backdrop_creates_shader_material_with_defaults(ctx)
	_test_backdrop_syncs_exported_tuning_to_shader(ctx)
	_test_backdrop_keeps_composition_viewport_stable_after_resize(ctx)


static func _test_backdrop_creates_shader_material_with_defaults(ctx) -> void:
	var backdrop = SpaceBackdropScript.new()
	backdrop.size = Vector2(1280.0, 720.0)
	backdrop._ready()

	var mat: ShaderMaterial = backdrop.material as ShaderMaterial
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
	backdrop.free()


static func _test_backdrop_syncs_exported_tuning_to_shader(ctx) -> void:
	var backdrop = SpaceBackdropScript.new()
	backdrop.size = Vector2(1920.0, 1080.0)
	backdrop._ready()
	backdrop.seed = 777
	backdrop.star_density = 1.45
	backdrop.band_strength = 0.82
	backdrop.nebula_strength = 1.28

	var mat: ShaderMaterial = backdrop.material as ShaderMaterial
	ctx.assert_almost(float(mat.get_shader_parameter("seed")), 777.0, 1.0e-9, "seed wird in den Shader gespiegelt")
	ctx.assert_almost(float(mat.get_shader_parameter("star_density")), 1.45, 1.0e-9, "star_density wird in den Shader gespiegelt")
	ctx.assert_almost(float(mat.get_shader_parameter("band_strength")), 0.82, 1.0e-9, "band_strength wird in den Shader gespiegelt")
	ctx.assert_almost(float(mat.get_shader_parameter("nebula_strength")), 1.28, 1.0e-9, "nebula_strength wird in den Shader gespiegelt")
	backdrop.free()


static func _test_backdrop_keeps_composition_viewport_stable_after_resize(ctx) -> void:
	var backdrop = SpaceBackdropScript.new()
	backdrop.size = Vector2(1280.0, 720.0)
	backdrop._ready()
	backdrop.size = Vector2(1920.0, 1080.0)
	backdrop._on_resized()

	var mat: ShaderMaterial = backdrop.material as ShaderMaterial
	ctx.assert_true(
		mat.get_shader_parameter("viewport_size") == Vector2(1280.0, 720.0),
		"spaetere Resize-Ereignisse remappen die Hintergrund-Komposition nicht mehr"
	)
	backdrop.free()
