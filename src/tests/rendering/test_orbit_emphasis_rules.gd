extends RefCounted

const OrbitEmphasisRulesScript = preload("res://src/tools/rendering/orbit_emphasis_rules.gd")
const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")
const BodyDefScript = preload("res://src/sim/bodies/body_def.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_emphasis_rules"
	_test_star_closeup_phase_only_activates_for_focus_star(ctx)
	_test_star_closeup_phase_maps_focus_ratio_to_unit_interval(ctx)
	_test_star_focus_scale_uses_conservative_p14_6_range(ctx)
	_test_body_detail_factor_preserves_low_closeup_progression(ctx)
	_test_body_detail_factor_keeps_growing_up_to_max_zoom(ctx)


static func _make_def(id: StringName, kind: int) -> BodyDef:
	var def := BodyDefScript.new()
	def.id = id
	def.kind = kind
	return def


static func _test_star_closeup_phase_only_activates_for_focus_star(ctx) -> void:
	var star_focus: BodyDef = _make_def(&"star_a", BodyType.Kind.STAR)
	var star_other: BodyDef = _make_def(&"star_b", BodyType.Kind.STAR)
	var planet_focus: BodyDef = _make_def(&"planet_a", BodyType.Kind.PLANET)

	ctx.assert_almost(
		OrbitEmphasisRulesScript.star_closeup_phase(&"star_b", star_other, &"star_a", 6.0),
		0.0,
		0.000001,
		"Nicht-fokussierte Sterne bekommen keine P14.6-Closeup-Phase"
	)
	ctx.assert_almost(
		OrbitEmphasisRulesScript.star_closeup_phase(&"planet_a", planet_focus, &"planet_a", 6.0),
		0.0,
		0.000001,
		"Nicht-Sterne nutzen den P14.6-Star-Closeup-Pfad nicht"
	)
	ctx.assert_almost(
		OrbitEmphasisRulesScript.star_closeup_phase(&"star_a", star_focus, &"star_a", 1.0),
		0.0,
		0.000001,
		"Der Fokusstern startet auf Scope-Fit ohne zusaetzliche Closeup-Phase"
	)


static func _test_star_closeup_phase_maps_focus_ratio_to_unit_interval(ctx) -> void:
	var star_focus: BodyDef = _make_def(&"star_a", BodyType.Kind.STAR)
	ctx.assert_almost(
		OrbitEmphasisRulesScript.star_closeup_phase(&"star_a", star_focus, &"star_a", 2.0),
		log(2.0) / log(6.0),
		0.000001,
		"Die P14.6-Star-Closeup-Phase nutzt die festgezogene Log-Abbildung"
	)
	ctx.assert_almost(
		OrbitEmphasisRulesScript.star_closeup_phase(&"star_a", star_focus, &"star_a", 6.0),
		1.0,
		0.000001,
		"focus_closeup_ratio == 6.0 mappt auf die volle P14.6-Closeup-Phase"
	)
	ctx.assert_almost(
		OrbitEmphasisRulesScript.star_closeup_phase(&"star_a", star_focus, &"star_a", 60.0),
		1.0,
		0.000001,
		"Hohe focus_closeup_ratio-Werte clampen die P14.6-Closeup-Phase auf 1.0"
	)


static func _test_star_focus_scale_uses_conservative_p14_6_range(ctx) -> void:
	ctx.assert_almost(
		OrbitEmphasisRulesScript.star_focus_scale(0.0),
		1.0,
		0.000001,
		"Ohne Closeup-Phase bleibt der Stern-Footprint unveraendert"
	)
	ctx.assert_almost(
		OrbitEmphasisRulesScript.star_focus_scale(0.5),
		1.25,
		0.000001,
		"Die konservative P14.6-Skalierung interpoliert linear zwischen 1.0 und 1.5"
	)
	ctx.assert_almost(
		OrbitEmphasisRulesScript.star_focus_scale(1.0),
		1.5,
		0.000001,
		"Die volle P14.6-Closeup-Phase capped den Fokusstern auf 1.5x Footprint"
	)


static func _test_body_detail_factor_preserves_low_closeup_progression(ctx) -> void:
	var planet_focus: BodyDef = _make_def(&"planet_a", BodyType.Kind.PLANET)
	var factor: float = OrbitEmphasisRulesScript.body_detail_factor(
		&"planet_a",
		planet_focus,
		&"planet_a",
		null,
		10.0
	)
	var expected: float = 1.0 + (pow(10.0, 0.90) - 1.0) * 0.96
	ctx.assert_almost(
		factor,
		expected,
		0.000001,
		"Unterhalb des neuen Tail-Starts bleibt die bestehende Closeup-Kurve unveraendert"
	)


static func _test_body_detail_factor_keeps_growing_up_to_max_zoom(ctx) -> void:
	var planet_focus: BodyDef = _make_def(&"planet_a", BodyType.Kind.PLANET)
	var plateau_edge: float = OrbitEmphasisRulesScript.body_detail_factor(
		&"planet_a",
		planet_focus,
		&"planet_a",
		null,
		15.0
	)
	var max_zoom: float = OrbitEmphasisRulesScript.body_detail_factor(
		&"planet_a",
		planet_focus,
		&"planet_a",
		null,
		OrbitZoomModelScript.MAX_ZOOM_FACTOR
	)
	ctx.assert_true(
		max_zoom > plateau_edge + 6.0,
		"Hoher Detail-Zoom waechst jetzt sichtbar weiter ueber das fruehere ~1500%-Plateau hinaus"
	)
	ctx.assert_true(
		max_zoom > 18.0,
		"10000% liefern jetzt wieder spuerbar mehr planetaren Closeup als mittlere Detailwerte"
	)
