extends RefCounted

const OrbitHudFormatterScript = preload("res://src/tools/rendering/orbit_hud_formatter.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_hud_formatter"
	_test_primary_source_formatter_uses_visible_label(ctx)
	_test_primary_source_formatter_handles_missing_source(ctx)
	_test_inspector_environment_badge_reuses_environment_and_climate_labels(ctx)
	_test_planet_summary_formatter_uses_environment_and_climate(ctx)
	_test_planet_life_summary_formatter_collapses_life_density_and_species(ctx)
	_test_planet_life_summary_formatter_handles_sparse_basis(ctx)
	_test_world_formatter_uses_fixed_axis_order(ctx)
	_test_life_formatter_handles_track_and_none_cases(ctx)
	_test_biomass_formatter_shows_quantitative_index(ctx)
	_test_species_formatter_reuses_caps_style(ctx)
	_test_summary_formatters_use_compact_survey_language(ctx)
	_test_density_formatter_maps_life_stages_without_extra_thresholds(ctx)
	_test_compact_badge_helpers_reuse_short_stage_density_and_species_text(ctx)
	_test_cycle_formatter_uses_explicit_rotation_and_orbit_labels(ctx)
	_test_life_potential_formatter_uses_track_and_class(ctx)
	_test_inspector_world_line_hides_low_seasonality(ctx)
	_test_inspector_life_line_reuses_hud_language(ctx)
	_test_time_formatter_uses_adaptive_elapsed_units(ctx)
	_test_day_and_year_formatter_use_single_unit_periods(ctx)
	_test_scale_formatter_uses_human_rate_language(ctx)
	_test_cadence_formatter_humanizes_bio_tick_durations(ctx)


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


static func _test_planet_summary_formatter_uses_environment_and_climate(ctx) -> void:
	var environment_desc: Dictionary = {
		"is_supported_body_kind": true,
		"environment_class": 0,
		"ecosystem_type": 1,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_planet_summary(environment_desc) == "Summary: HABITABLE / TEMPERATE",
		"Planet Summary verdichtet Environment und Climate in eine Hauptaussage"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_planet_summary({}) == "Summary: n/a",
		"Planet Summary bleibt bei fehlender Environment-Basis sichtbar, aber explizit n/a"
	)


static func _test_planet_life_summary_formatter_collapses_life_density_and_species(ctx) -> void:
	var biosphere_desc: Dictionary = {
		"has_biosphere_scale_basis": true,
		"biosphere_stage": 3,
		"dominant_track_id": 2,
		"dominant_potential_class": 3,
		"dominant_biomass_index": 0.57,
	}
	var native_species_desc: Dictionary = {
		"has_native_species_basis": true,
		"metabolism_class": 0,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_planet_life_summary(biosphere_desc, native_species_desc)
			== "Life: COMPLEX   Density: THRIVING   Species: PHOTO",
		"Planet Life Summary buendelt Life/Density/Species und laesst den Track bewusst fuer Details weg"
	)


static func _test_planet_life_summary_formatter_handles_sparse_basis(ctx) -> void:
	ctx.assert_true(
		OrbitHudFormatterScript.format_planet_life_summary({
			"has_biosphere_scale_basis": true,
			"biosphere_stage": 1,
			"dominant_track_id": 0,
			"dominant_potential_class": 3,
			"dominant_biomass_index": 0.0,
		}, {}) == "Life: PREBIOTIC",
		"PREBIOTIC bekommt in der neuen Hauptaussage keine pseudo-Density und keine Species"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_planet_life_summary({},
			{"has_native_species_basis": true, "metabolism_class": 0}
		) == "Life: n/a",
		"Ohne Life-Basis bleibt die Life-Hauptaussage explizit n/a"
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
		"has_biosphere_scale_basis": true,
		"biosphere_stage": 3,
		"dominant_track_id": 0,
		"dominant_potential_class": 3,
		"dominant_biomass_index": 0.57,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_life(biosphere_desc) == "Life: COMPLEX_MULTICELLULAR / WATER_CARBON",
		"HUD formatter rendert die player-facing Life-v2-Zeile mit Stage und Track"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_life({
			"has_biosphere_scale_basis": true,
			"biosphere_stage": 0,
			"dominant_track_id": 0,
			"dominant_potential_class": 0,
			"dominant_biomass_index": 0.0,
		}) == "Life: STERILE",
		"HUD formatter blendet bei NONE bewusst jeden Default-Track aus"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_life({}) == "Life: n/a",
		"HUD formatter zeigt ohne Biosphaeren-Basis explizit Life: n/a"
	)


static func _test_biomass_formatter_shows_quantitative_index(ctx) -> void:
	ctx.assert_true(
		OrbitHudFormatterScript.format_biomass({
			"has_biosphere_scale_basis": true,
			"dominant_biomass_index": 0.57,
		}) == "Biomass: 0.57",
		"HUD formatter rendert die neue quantitative Biomass-Zeile mit zwei Nachkommastellen"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_biomass({}) == "Biomass: n/a",
		"HUD formatter zeigt ohne Biosphere-Scale-Basis explizit Biomass: n/a"
	)


static func _test_species_formatter_reuses_caps_style(ctx) -> void:
	ctx.assert_true(
		OrbitHudFormatterScript.format_species({
			"has_native_species_basis": true,
			"species_complexity_class": 0,
			"metabolism_class": 0,
			"habitat_class": 0,
			"mobility_class": 0,
		}) == "Species: EARLY_MACRO / PHOTOTROPHIC / TEMPERATE_SURFACE / SESSILE",
		"HUD formatter rendert die Species-Zeile im bestehenden CAPS/CAPS/CAPS-Stil"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_species({}) == "Species: n/a",
		"HUD formatter zeigt ohne Species-Basis explizit Species: n/a"
	)


static func _test_summary_formatters_use_compact_survey_language(ctx) -> void:
	var biosphere_desc: Dictionary = {
		"has_biosphere_scale_basis": true,
		"biosphere_stage": 3,
		"dominant_track_id": 2,
		"dominant_potential_class": 3,
		"dominant_biomass_index": 0.57,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_life_summary(biosphere_desc) == "Life: COMPLEX / CRYOGENIC_SOLVENT",
		"Summary-Lesart kuerzt nur die Stage, behaelt aber den Track sichtbar"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_species_summary({
			"has_native_species_basis": true,
			"metabolism_class": 3,
			"mobility_class": 2,
		}) == "Species: CRYO / MOTILE",
		"Summary-Lesart kuerzt die Species-Zeile auf die spielrelevante Kurzform"
	)


static func _test_density_formatter_maps_life_stages_without_extra_thresholds(ctx) -> void:
	ctx.assert_true(
		OrbitHudFormatterScript.format_density({
			"has_biosphere_scale_basis": true,
			"biosphere_stage": 2,
		}) == "Density: SPARSE",
		"MICROBIAL mappt direkt auf SPARSE"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_density({
			"has_biosphere_scale_basis": true,
			"biosphere_stage": 3,
		}) == "Density: THRIVING",
		"COMPLEX_MULTICELLULAR mappt direkt auf THRIVING"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_density({
			"has_biosphere_scale_basis": true,
			"biosphere_stage": 4,
		}) == "Density: ABUNDANT",
		"COMPLEX_ECOSYSTEM mappt direkt auf ABUNDANT"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_density({
			"has_biosphere_scale_basis": true,
			"biosphere_stage": 1,
		}) == "Density: n/a",
		"PREBIOTIC bekommt bewusst keine pseudo-dichte Anzeige"
	)


static func _test_compact_badge_helpers_reuse_short_stage_density_and_species_text(ctx) -> void:
	ctx.assert_true(
		OrbitHudFormatterScript.compact_life_stage_text({
			"has_biosphere_scale_basis": true,
			"biosphere_stage": 4,
		}) == "ECOSYSTEM",
		"Badge-Stage-Texte kuerzen nur auf die freigegebene Survey-Sprache"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.compact_density_text({
			"has_biosphere_scale_basis": true,
			"biosphere_stage": 3,
		}) == "THRIVING",
		"Badge-Density-Texte kommen direkt aus der Life-Stage"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.compact_species_text({
			"has_native_species_basis": true,
			"metabolism_class": 2,
		}) == "SULFUR",
		"Badge-Species-Texte kuerzen Metabolismus auf die freigegebene Kurzform"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.compact_species_text({}) == "",
		"Ohne Species-Basis bleibt die Badge-Species-Zeile leer"
	)


static func _test_cycle_formatter_uses_explicit_rotation_and_orbit_labels(ctx) -> void:
	ctx.assert_true(
		OrbitHudFormatterScript.format_cycle({
			"has_rotation_basis": true,
			"rotation_period_s": 25.0 * UnitSystem.DAY_S,
			"has_orbital_period_basis": true,
			"orbital_period_s": UnitSystem.YEAR_S,
		}) == "Cycle: rot 25.0 d / orb 1.0 y",
		"Cycle-Readout benennt Rotation und Orbit explizit statt zweier ambiger Zahlen"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_cycle({}) == "Cycle: n/a",
		"Cycle-Readout bleibt ohne jede Periodenbasis explizit n/a"
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
		"has_biosphere_scale_basis": true,
		"biosphere_stage": 2,
		"dominant_track_id": 2,
		"dominant_potential_class": 3,
		"dominant_biomass_index": 0.40,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_inspector_life_line(biosphere_desc) == "Life: MICROBIAL / CRYOGENIC_SOLVENT / HIGH",
		"Inspector rendert die kompakte Life-Zeile im festgelegten Stage/Track/Class-Format"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_inspector_life_line({
			"has_biosphere_scale_basis": true,
			"biosphere_stage": 0,
			"dominant_track_id": 0,
			"dominant_potential_class": 0,
			"dominant_biomass_index": 0.0,
		}) == "Life: STERILE",
		"Inspector blendet bei NONE auch in der kompakten Life-Zeile den Track aus"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_inspector_life_line({}) == "Life: n/a",
		"Inspector zeigt ohne Biosphaeren-Basis explizit Life: n/a"
	)


static func _test_time_formatter_uses_adaptive_elapsed_units(ctx) -> void:
	ctx.assert_true(
		OrbitHudFormatterScript.format_time(45.0, 12, 81) == "T+ 45 s   steps 12   FPS 81",
		"T+-Zeile bleibt strukturell erhalten und zeigt kurze Laufzeit in Sekunden"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_time(750.0, 12, 81) == "T+ 12.5 min   steps 12   FPS 81",
		"T+-Zeile rendert mittlere Laufzeit adaptiv in Minuten"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_time(8.3 * 3600.0, 12, 81) == "T+ 8.3 h   steps 12   FPS 81",
		"T+-Zeile rendert Stunden mit einer Nachkommastelle"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_time(12.4 * UnitSystem.DAY_S, 12, 81) == "T+ 12.4 d   steps 12   FPS 81",
		"T+-Zeile rendert Tageswerte adaptiv in Tagen"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_time(1.2 * UnitSystem.YEAR_S, 12, 81) == "T+ 1.2 y   steps 12   FPS 81",
		"T+-Zeile rendert lange Laufzeiten adaptiv in Jahren"
	)


static func _test_day_and_year_formatter_use_single_unit_periods(ctx) -> void:
	var orbit_readout_desc: Dictionary = {
		"has_rotation_basis": true,
		"rotation_period_s": 4.6 * 3600.0,
		"has_orbital_period_basis": true,
		"orbital_period_s": 12.1 * UnitSystem.DAY_S,
	}
	ctx.assert_true(
		OrbitHudFormatterScript.format_rotation(orbit_readout_desc) == "Rotation: 4.6 h",
		"Rotation-Readout bleibt bei einer Zahl plus einer Einheit"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_orbit(orbit_readout_desc) == "Orbit: 12.1 d",
		"Orbit-Readout bleibt bei einer Zahl plus einer Einheit"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_orbit({
			"has_orbital_period_basis": true,
			"orbital_period_s": UnitSystem.YEAR_S,
		}) == "Orbit: 1.0 y",
		"Orbit-Readout schaltet ab YEAR_S auf plain y um"
	)


static func _test_scale_formatter_uses_human_rate_language(ctx) -> void:
	ctx.assert_true(
		OrbitHudFormatterScript.format_scale(3600.0, "5/8", 0.5, "wide", "root-overview")
			== "Rate: 1 h/s   Preset 5/8   Zoom 50% wide (root-overview)",
		"HUD formatter beschreibt Zeit jetzt als lesbare Rate statt als rohen x-Multiplikator"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_scale(1380.0, "Custom", 1.0, "focus-lock")
			== "Rate: 23 min/s   Preset Custom   Zoom 100% focus-lock",
		"Zwischenwerte behalten die Custom-Semantik und rendern trotzdem eine lesbare Rate"
	)


static func _test_cadence_formatter_humanizes_bio_tick_durations(ctx) -> void:
	ctx.assert_true(
		OrbitHudFormatterScript.format_cadence(86400.0) == "Cadence: Bio tick ~ 10 s",
		"Hohe Raten verkuerzen die Life-Cadence bis in Sekunden"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_cadence(3600.0) == "Cadence: Bio tick ~ 4 min",
		"Default-Rate rendert die Life-Cadence kompakt in Minuten"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_cadence(180.0) == "Cadence: Bio tick ~ 1 h 20 min",
		"Mittlere Raten rendern die Life-Cadence mit Stunden- und Minutenanteil"
	)
	ctx.assert_true(
		OrbitHudFormatterScript.format_cadence(1.0) == "Cadence: Bio tick ~ 10 d",
		"Der Slider-Feinmodus bleibt bis in Tagesdauern sauber lesbar"
	)
