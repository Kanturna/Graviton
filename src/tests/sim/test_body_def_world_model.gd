extends RefCounted


static func run(ctx) -> void:
	ctx.current_suite = "test_body_def_world_model"
	_test_valid_root_defaults_remain_valid(ctx)
	_test_negative_rotation_is_invalid(ctx)
	_test_negative_luminosity_is_invalid(ctx)
	_test_non_finite_axial_tilt_is_invalid(ctx)
	_test_north_pole_orbit_frame_azimuth_defaults_to_valid_zero(ctx)
	_test_non_finite_north_pole_azimuth_is_invalid(ctx)
	_test_non_finite_rotation_is_invalid(ctx)
	_test_non_finite_luminosity_is_invalid(ctx)
	_test_albedo_boundary_values(ctx)
	_test_albedo_out_of_range_is_invalid(ctx)
	_test_non_finite_albedo_is_invalid(ctx)
	_test_greenhouse_boundary_value_is_valid(ctx)
	_test_negative_greenhouse_is_invalid(ctx)
	_test_greenhouse_above_sanity_limit_is_invalid(ctx)
	_test_non_finite_greenhouse_is_invalid(ctx)


static func _make_valid_root() -> BodyDef:
	var def := BodyDef.new()
	def.id = &"root"
	def.display_name = "Root"
	def.kind = BodyType.Kind.STAR
	def.mass_kg = UnitSystem.SOLAR_MASS_KG
	def.radius_m = 6.957e8
	def.parent_id = &""
	def.orbit_profile = null
	return def


static func _test_valid_root_defaults_remain_valid(ctx) -> void:
	var def := _make_valid_root()
	ctx.assert_true(def.is_valid(), "bestehende Pflichtfelder + neue Defaults bleiben valide")


static func _test_negative_rotation_is_invalid(ctx) -> void:
	var def := _make_valid_root()
	def.rotation_period_s = -0.1
	ctx.assert_true(not def.is_valid(), "rotation_period_s < 0.0 ist invalid")


static func _test_negative_luminosity_is_invalid(ctx) -> void:
	var def := _make_valid_root()
	def.luminosity_w = -1.0
	ctx.assert_true(not def.is_valid(), "luminosity_w < 0.0 ist invalid")


static func _test_non_finite_axial_tilt_is_invalid(ctx) -> void:
	var inf_def := _make_valid_root()
	inf_def.axial_tilt_rad = INF
	ctx.assert_true(not inf_def.is_valid(), "axial_tilt_rad = INF ist invalid")

	var nan_def := _make_valid_root()
	nan_def.axial_tilt_rad = NAN
	ctx.assert_true(not nan_def.is_valid(), "axial_tilt_rad = NaN ist invalid")


static func _test_north_pole_orbit_frame_azimuth_defaults_to_valid_zero(ctx) -> void:
	var def := _make_valid_root()
	def.north_pole_orbit_frame_azimuth_rad = 0.0
	ctx.assert_true(def.is_valid(), "north_pole_orbit_frame_azimuth_rad = 0.0 ist valid")


static func _test_non_finite_north_pole_azimuth_is_invalid(ctx) -> void:
	var inf_def := _make_valid_root()
	inf_def.north_pole_orbit_frame_azimuth_rad = INF
	ctx.assert_true(not inf_def.is_valid(), "north_pole_orbit_frame_azimuth_rad = INF ist invalid")

	var nan_def := _make_valid_root()
	nan_def.north_pole_orbit_frame_azimuth_rad = NAN
	ctx.assert_true(not nan_def.is_valid(), "north_pole_orbit_frame_azimuth_rad = NaN ist invalid")


static func _test_non_finite_rotation_is_invalid(ctx) -> void:
	var inf_def := _make_valid_root()
	inf_def.rotation_period_s = INF
	ctx.assert_true(not inf_def.is_valid(), "rotation_period_s = INF ist invalid")

	var nan_def := _make_valid_root()
	nan_def.rotation_period_s = NAN
	ctx.assert_true(not nan_def.is_valid(), "rotation_period_s = NaN ist invalid")


static func _test_non_finite_luminosity_is_invalid(ctx) -> void:
	var inf_def := _make_valid_root()
	inf_def.luminosity_w = INF
	ctx.assert_true(not inf_def.is_valid(), "luminosity_w = INF ist invalid")

	var nan_def := _make_valid_root()
	nan_def.luminosity_w = NAN
	ctx.assert_true(not nan_def.is_valid(), "luminosity_w = NaN ist invalid")


static func _test_albedo_boundary_values(ctx) -> void:
	var zero_def := _make_valid_root()
	zero_def.albedo = 0.0
	ctx.assert_true(zero_def.is_valid(), "albedo = 0.0 ist valid")

	var one_def := _make_valid_root()
	one_def.albedo = 1.0
	ctx.assert_true(one_def.is_valid(), "albedo = 1.0 ist valid")


static func _test_albedo_out_of_range_is_invalid(ctx) -> void:
	var below_def := _make_valid_root()
	below_def.albedo = -0.0001
	ctx.assert_true(not below_def.is_valid(), "albedo < 0.0 ist invalid")

	var above_def := _make_valid_root()
	above_def.albedo = 1.0001
	ctx.assert_true(not above_def.is_valid(), "albedo > 1.0 ist invalid")


static func _test_non_finite_albedo_is_invalid(ctx) -> void:
	var inf_def := _make_valid_root()
	inf_def.albedo = INF
	ctx.assert_true(not inf_def.is_valid(), "albedo = INF ist invalid")

	var nan_def := _make_valid_root()
	nan_def.albedo = NAN
	ctx.assert_true(not nan_def.is_valid(), "albedo = NaN ist invalid")


static func _test_greenhouse_boundary_value_is_valid(ctx) -> void:
	var def := _make_valid_root()
	def.greenhouse_delta_k = 0.0
	ctx.assert_true(def.is_valid(), "greenhouse_delta_k = 0.0 ist valid")


static func _test_negative_greenhouse_is_invalid(ctx) -> void:
	var def := _make_valid_root()
	def.greenhouse_delta_k = -0.1
	ctx.assert_true(not def.is_valid(), "greenhouse_delta_k < 0.0 ist invalid")


static func _test_greenhouse_above_sanity_limit_is_invalid(ctx) -> void:
	var def := _make_valid_root()
	def.greenhouse_delta_k = 2000.1
	ctx.assert_true(not def.is_valid(), "greenhouse_delta_k > 2000.0 ist invalid")


static func _test_non_finite_greenhouse_is_invalid(ctx) -> void:
	var inf_def := _make_valid_root()
	inf_def.greenhouse_delta_k = INF
	ctx.assert_true(not inf_def.is_valid(), "greenhouse_delta_k = INF ist invalid")

	var nan_def := _make_valid_root()
	nan_def.greenhouse_delta_k = NAN
	ctx.assert_true(not nan_def.is_valid(), "greenhouse_delta_k = NaN ist invalid")
