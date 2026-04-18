extends RefCounted

const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")

const OVERVIEW_RATIO: float = 0.4
const MAX_CLOSEUP_BIAS: float = 10.0


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_zoom_model"
	_test_hybrid_zoom_scale_mapping(ctx)
	_test_world_overview_scale_ratio(ctx)
	_test_focus_relative_closeup_semantics(ctx)
	_test_zoom_mode_labels(ctx)
	_test_focus_closeup_ratio_semantics(ctx)


static func _test_hybrid_zoom_scale_mapping(ctx) -> void:
	var root_fit_scale: float = 20.0
	var focus_fit_scale: float = 50.0
	var world_overview_scale: float = OrbitZoomModelScript.world_overview_scale(
		root_fit_scale,
		OVERVIEW_RATIO
	)

	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(
			root_fit_scale,
			focus_fit_scale,
			0.005,
			OVERVIEW_RATIO,
			MAX_CLOSEUP_BIAS
		),
		world_overview_scale,
		0.000001,
		"0.5% mappt exakt auf world_overview_scale"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(
			root_fit_scale,
			focus_fit_scale,
			1.0,
			OVERVIEW_RATIO,
			MAX_CLOSEUP_BIAS
		),
		focus_fit_scale,
		0.000001,
		"100% mappt exakt auf focus_fit_scale"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(
			root_fit_scale,
			focus_fit_scale,
			100.0,
			OVERVIEW_RATIO,
			MAX_CLOSEUP_BIAS
		),
		focus_fit_scale * MAX_CLOSEUP_BIAS,
		0.000001,
		"10000% mappt exakt auf focus_fit_scale * MAX_FOCUS_CLOSEUP_BIAS"
	)
	ctx.assert_true(
		OrbitZoomModelScript.target_view_scale(
			root_fit_scale,
			focus_fit_scale,
			0.20,
			OVERVIEW_RATIO,
			MAX_CLOSEUP_BIAS
		) > world_overview_scale
		and OrbitZoomModelScript.target_view_scale(
			root_fit_scale,
			focus_fit_scale,
			0.20,
			OVERVIEW_RATIO,
			MAX_CLOSEUP_BIAS
		) < focus_fit_scale,
		"Zwischen 0.5% und 100% bleibt der Scale im Overview->Fit-Bereich"
	)


static func _test_world_overview_scale_ratio(ctx) -> void:
	var root_fit_scale: float = 20.0
	var world_overview_scale: float = OrbitZoomModelScript.world_overview_scale(
		root_fit_scale,
		OVERVIEW_RATIO
	)
	ctx.assert_almost(
		world_overview_scale,
		root_fit_scale * OVERVIEW_RATIO,
		0.000001,
		"world_overview_scale == root_fit_scale * 0.4"
	)
	ctx.assert_true(
		world_overview_scale < root_fit_scale,
		"Unter Root-Fokus ist 0.5% kleiner als 100% und damit ein echter sichtbarer Bereich"
	)


static func _test_focus_relative_closeup_semantics(ctx) -> void:
	var root_fit_scale: float = 20.0
	var first_focus_fit_scale: float = 30.0
	var second_focus_fit_scale: float = 45.0
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(
			root_fit_scale,
			first_focus_fit_scale,
			1.0,
			OVERVIEW_RATIO,
			MAX_CLOSEUP_BIAS
		),
		30.0,
		0.000001,
		"100% ergibt fuer den ersten Fokus dessen Fit-Skala"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(
			root_fit_scale,
			second_focus_fit_scale,
			1.0,
			OVERVIEW_RATIO,
			MAX_CLOSEUP_BIAS
		),
		45.0,
		0.000001,
		"100% ergibt fuer den zweiten Fokus dessen Fit-Skala"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(
			root_fit_scale,
			first_focus_fit_scale,
			100.0,
			OVERVIEW_RATIO,
			MAX_CLOSEUP_BIAS
		),
		300.0,
		0.000001,
		"10000% ergibt fuer den ersten Fokus lokalen Closeup"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.target_view_scale(
			root_fit_scale,
			second_focus_fit_scale,
			100.0,
			OVERVIEW_RATIO,
			MAX_CLOSEUP_BIAS
		),
		450.0,
		0.000001,
		"10000% ergibt fuer den zweiten Fokus einen anderen lokalen Closeup"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.focus_closeup_bias(1.0, MAX_CLOSEUP_BIAS),
		1.0,
		0.000001,
		"Der lokale Closeup-Bias startet auf Fokus-Fit bei 1.0"
	)
	ctx.assert_almost(
		OrbitZoomModelScript.focus_closeup_bias(100.0, MAX_CLOSEUP_BIAS),
		10.0,
		0.000001,
		"Der lokale Closeup-Bias endet bei 10000% exakt auf 10.0"
	)


static func _test_zoom_mode_labels(ctx) -> void:
	ctx.assert_true(
		OrbitZoomModelScript.zoom_mode_label(0.4) == "world",
		"Zoomwerte unter 100% tragen das HUD-Label world"
	)
	ctx.assert_true(
		OrbitZoomModelScript.zoom_mode_label(1.0) == "fit",
		"100% traegt das HUD-Label fit"
	)
	ctx.assert_true(
		OrbitZoomModelScript.zoom_mode_label(32.0) == "focus",
		"Zoomwerte ueber 100% tragen das HUD-Label focus"
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
