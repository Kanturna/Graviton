extends RefCounted

const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")

static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_zoom_model"
	_test_scope_relative_zoom_scale_mapping(ctx)
	_test_zoom_clamps_to_supported_range(ctx)
	_test_focus_closeup_ratio_semantics(ctx)


static func _test_scope_relative_zoom_scale_mapping(ctx) -> void:
	var scope_fit_scale: float = 50.0
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(scope_fit_scale, 0.005),
		scope_fit_scale * 0.005,
		0.000001,
		"0.5% mappt exakt auf scope_fit_scale * 0.005"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(scope_fit_scale, 1.0),
		scope_fit_scale,
		0.000001,
		"100% mappt exakt auf scope_fit_scale"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(scope_fit_scale, 100.0),
		scope_fit_scale * 100.0,
		0.000001,
		"10000% mappt exakt auf scope_fit_scale * 100"
	)


static func _test_zoom_clamps_to_supported_range(ctx) -> void:
	var scope_fit_scale: float = 50.0
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(scope_fit_scale, 0.000001),
		scope_fit_scale * OrbitZoomModelScript.MIN_ZOOM_FACTOR,
		0.000001,
		"target_view_scale clamp't nach unten auf MIN_ZOOM_FACTOR"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(scope_fit_scale, 1000000.0),
		scope_fit_scale * OrbitZoomModelScript.MAX_ZOOM_FACTOR,
		0.000001,
		"target_view_scale clamp't nach oben auf MAX_ZOOM_FACTOR"
	)


static func _test_focus_closeup_ratio_semantics(ctx) -> void:
	ctx.assert_almost(
		OrbitZoomModelScript.focus_closeup_ratio(120.0, 120.0),
		1.0,
		0.000001,
		"focus_closeup_ratio bleibt 1.0 auf Fokus-Fit"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.focus_closeup_ratio(300.0, 120.0),
		2.5,
		0.000001,
		"focus_closeup_ratio waechst ueber Fokus-Fit hinaus"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.focus_closeup_ratio(60.0, 120.0),
		1.0,
		0.000001,
		"focus_closeup_ratio faellt nie unter 1.0"
	)
