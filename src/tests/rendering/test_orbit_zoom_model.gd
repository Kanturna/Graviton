extends RefCounted

const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")

static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_zoom_model"
	_test_scope_relative_zoom_scale_mapping(ctx)
	_test_zoom_clamps_to_supported_range(ctx)
	_test_wide_anchor_blend_semantics(ctx)
	_test_zoom_mode_labels(ctx)
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


static func _test_wide_anchor_blend_semantics(ctx) -> void:
	ctx.assert_almost(
		OrbitZoomModelScript.wide_anchor_blend(1.0),
		0.0,
		0.000001,
		"wide_anchor_blend ist auf FIT exakt 0.0"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.wide_anchor_blend(OrbitZoomModelScript.MIN_ZOOM_FACTOR),
		1.0,
		0.000001,
		"wide_anchor_blend ist auf MIN_ZOOM_FACTOR exakt 1.0"
	)
	var slight_wide: float = OrbitZoomModelScript.wide_anchor_blend(0.95)
	var mid_wide: float = OrbitZoomModelScript.wide_anchor_blend(0.1)
	var far_wide: float = OrbitZoomModelScript.wide_anchor_blend(0.01)
	ctx.assert_true(
		slight_wide > 0.0 and slight_wide < 0.2,
		"Leichtes wide erzeugt nur einen kleinen Root-Einfluss"
	)
	ctx.assert_true(
		slight_wide < mid_wide and mid_wide < far_wide,
		"wide_anchor_blend steigt monoton, je weiter man rauszoomt"
	)


static func _test_zoom_mode_labels(ctx) -> void:
	ctx.assert_true(
		OrbitZoomModelScript.zoom_mode_label(0.4) == "wide",
		"Zoomwerte unter 100% tragen das HUD-Label wide"
	)
	ctx.assert_true(
		OrbitZoomModelScript.zoom_mode_label(1.0) == "fit",
		"100% traegt das HUD-Label fit"
	)
	ctx.assert_true(
		OrbitZoomModelScript.zoom_mode_label(32.0) == "detail",
		"Zoomwerte ueber 100% tragen das HUD-Label detail"
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
