extends RefCounted

const OrbitHudFormatterScript = preload("res://src/tools/rendering/orbit_hud_formatter.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_hud_formatter"
	_test_primary_source_formatter_uses_visible_label(ctx)
	_test_primary_source_formatter_handles_missing_source(ctx)
	_test_inspector_environment_badge_reuses_environment_and_climate_labels(ctx)


static func _test_primary_source_formatter_uses_visible_label(ctx) -> void:
	var thermal_desc: Dictionary = {
		"has_luminous_ancestor": true,
		"source_id": &"gamma",
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_primary_source(thermal_desc) == "Primary source: gamma",
		"HUD formatter macht die Primaerquelle explizit sichtbar"
	)


static func _test_primary_source_formatter_handles_missing_source(ctx) -> void:
	var thermal_desc: Dictionary = {
		"has_luminous_ancestor": false,
		"source_id": StringName(""),
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_primary_source(thermal_desc) == "Primary source: none",
		"HUD formatter zeigt fehlende Primaerquelle explizit als none"
	)


static func _test_inspector_environment_badge_reuses_environment_and_climate_labels(ctx) -> void:
	var environment_desc: Dictionary = {
		"is_supported_body_kind": true,
		"environment_class": 0,
		"ecosystem_type": 1,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_inspector_environment_badge(environment_desc) == "HABITABLE / TEMPERATE",
		"Inspector-Badges nutzen dieselbe Environment-/Climate-Sprache wie der HUD-Formatter"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_inspector_environment_badge({}) == "n/a",
		"Inspector-Badges zeigen ohne unterstuetzten Environment-Snapshot explizit n/a"
	)
