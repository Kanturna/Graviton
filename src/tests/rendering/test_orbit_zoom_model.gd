extends RefCounted

const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_zoom_model"
	_test_absolute_zoom_scale_mapping(ctx)
	_test_fit_zoom_factor_clamps_to_range(ctx)
	_test_focus_fallback_thresholds(ctx)
	_test_focus_closeup_ratio_semantics(ctx)


static func _test_absolute_zoom_scale_mapping(ctx) -> void:
	var world_base_scale: float = 12.0
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(world_base_scale, 0.05),
		0.60,
		0.000001,
		"5% mappt exakt auf 0.05 * world_base_scale"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(world_base_scale, 1.0),
		12.0,
		0.000001,
		"100% mappt exakt auf 1.0 * world_base_scale"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(world_base_scale, 100.0),
		1200.0,
		0.000001,
		"10000% mappt exakt auf 100.0 * world_base_scale"
	)


static func _test_fit_zoom_factor_clamps_to_range(ctx) -> void:
	ctx.assert_almost(
		OrbitZoomModelScript.fit_zoom_factor(18.0, 12.0, 0.05, 100.0),
		1.5,
		0.000001,
		"fit current focus berechnet focus_fit_scale / world_base_scale"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.fit_zoom_factor(0.01, 12.0, 0.05, 100.0),
		0.05,
		0.000001,
		"fit current focus clampt nach unten in den neuen Zoombereich"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.fit_zoom_factor(900.0, 12.0, 0.05, 100.0),
		75.0,
		0.000001,
		"fit current focus bleibt innerhalb des erweiterten Zoombereichs, wenn kein oberer Clamp noetig ist"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.fit_zoom_factor(1800.0, 12.0, 0.05, 100.0),
		100.0,
		0.000001,
		"fit current focus clampt nach oben in den neuen Zoombereich"
	)


static func _test_focus_fallback_thresholds(ctx) -> void:
	var viewport_size := Vector2(2000.0, 1200.0)
	ctx.assert_true(
		OrbitZoomModelScript.should_auto_fit_for_focus(95.0, viewport_size, 0.08, 0.60),
		"projected focus radius unter 8% der kurzen Viewport-Seite erzwingt auto-fit"
	)
	ctx.assert_true(
		not OrbitZoomModelScript.should_auto_fit_for_focus(96.0, viewport_size, 0.08, 0.60),
		"projected focus radius exakt auf 8% bleibt im Zoom-erhalten-Fenster"
	)
	ctx.assert_true(
		not OrbitZoomModelScript.should_auto_fit_for_focus(720.0, viewport_size, 0.08, 0.60),
		"projected focus radius exakt auf 60% bleibt im Zoom-erhalten-Fenster"
	)
	ctx.assert_true(
		OrbitZoomModelScript.should_auto_fit_for_focus(721.0, viewport_size, 0.08, 0.60),
		"projected focus radius ueber 60% der kurzen Viewport-Seite erzwingt auto-fit"
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
