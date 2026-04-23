extends RefCounted

const OrbitHudFormatterScript = preload("res://src/tools/rendering/orbit_hud_formatter.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_hud_formatter"
	_test_primary_source_formatter_uses_visible_label(ctx)
	_test_primary_source_formatter_handles_missing_source(ctx)
	_test_inspector_environment_badge_reuses_environment_and_climate_labels(ctx)
	_test_world_formatter_uses_fixed_axis_order(ctx)
	_test_life_formatter_handles_track_and_none_cases(ctx)
	_test_life_potential_formatter_uses_track_and_class(ctx)
	_test_inspector_world_line_hides_low_seasonality(ctx)
	_test_inspector_life_line_reuses_hud_language(ctx)


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


static func _test_world_formatter_uses_fixed_axis_order(ctx) -> void:
	var planetary_state_desc: Dictionary = {
		"has_sampled_year_basis": true,
		"volatile_inventory_class": 2,
		"climate_buffer_class": 2,
		"seasonality_class": 0,
		"stability_class": 2,
		"thermal_extremity_class": 2,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_world(planetary_state_desc) == "World: RICH / BUFFERED / LOW / STABLE / TEMPERATE",
		"HUD formatter rendert die neue World-Zeile in der festgelegten Achsenreihenfolge"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_world({}) == "World: n/a",
		"HUD formatter zeigt ohne sampled-year-Basis explizit World: n/a"
	)


static func _test_life_potential_formatter_uses_track_and_class(ctx) -> void:
	var life_potential_desc: Dictionary = {
		"has_life_potential_basis": true,
		"dominant_track_id": 0,
		"dominant_potential_class": 3,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_life_potential(life_potential_desc) == "Life Potential: WATER_CARBON / HIGH",
		"HUD formatter rendert die Life-Potential-Zeile im festgelegten Track/Class-Format"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_life_potential({}) == "Life Potential: n/a",
		"HUD formatter zeigt ohne Life-Potential-Basis explizit Life Potential: n/a"
	)


static func _test_life_formatter_handles_track_and_none_cases(ctx) -> void:
	var biosphere_desc: Dictionary = {
		"has_biosphere_basis": true,
		"biosphere_stage": 1,
		"dominant_track_id": 0,
		"dominant_potential_class": 3,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_life(biosphere_desc) == "Life: PREBIOTIC / WATER_CARBON",
		"HUD formatter rendert die neue Life-Zeile mit Stage und Track"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_life({
			"has_biosphere_basis": true,
			"biosphere_stage": 0,
			"dominant_track_id": 0,
			"dominant_potential_class": 0,
		}) == "Life: STERILE",
		"HUD formatter blendet bei NONE bewusst jeden Default-Track aus"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_life({}) == "Life: n/a",
		"HUD formatter zeigt ohne Biosphaeren-Basis explizit Life: n/a"
	)


static func _test_inspector_world_line_hides_low_seasonality(ctx) -> void:
	var low_seasonality_desc: Dictionary = {
		"has_sampled_year_basis": true,
		"volatile_inventory_class": 2,
		"climate_buffer_class": 2,
		"seasonality_class": 0,
		"stability_class": 2,
		"thermal_extremity_class": 2,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_inspector_world_line(low_seasonality_desc) == "World: RICH / BUFFERED / STABLE / TEMPERATE",
		"Inspector blendet LOW-Seasonality in der kompakten World-Zeile aus"
	)

	var seasonal_desc: Dictionary = {
		"has_sampled_year_basis": true,
		"volatile_inventory_class": 1,
		"climate_buffer_class": 1,
		"seasonality_class": 1,
		"stability_class": 1,
		"thermal_extremity_class": 2,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_inspector_world_line(seasonal_desc) == "World: LIMITED / MODERATE / WINDOWED / TEMPERATE / SEASONAL",
		"Inspector haengt nicht-LOW-Seasonality explizit an die kompakte World-Zeile an"
	)


static func _test_inspector_life_line_reuses_hud_language(ctx) -> void:
	var biosphere_desc: Dictionary = {
		"has_biosphere_basis": true,
		"biosphere_stage": 2,
		"dominant_track_id": 2,
		"dominant_potential_class": 3,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_inspector_life_line(biosphere_desc) == "Life: MICROBIAL / CRYOGENIC_SOLVENT / HIGH",
		"Inspector rendert die kompakte Life-Zeile im festgelegten Stage/Track/Class-Format"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_inspector_life_line({
			"has_biosphere_basis": true,
			"biosphere_stage": 0,
			"dominant_track_id": 0,
			"dominant_potential_class": 0,
		}) == "Life: STERILE",
		"Inspector blendet bei NONE auch in der kompakten Life-Zeile den Track aus"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_inspector_life_line({}) == "Life: n/a",
		"Inspector zeigt ohne Biosphaeren-Basis explizit Life: n/a"
	)
