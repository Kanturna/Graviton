extends RefCounted

const PlanetBadgeOverlayScript = preload("res://src/tools/rendering/planet_badge_overlay.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const NativeSpeciesServiceScript = preload("res://src/sim/life/native_species_service.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_planet_badge_overlay"
	_test_badge_lines_hide_second_row_for_prebiotic_worlds(ctx)
	_test_badge_lines_show_density_without_species_for_microbial_worlds(ctx)
	_test_badge_lines_show_density_and_species_for_complex_worlds(ctx)


static func _test_badge_lines_hide_second_row_for_prebiotic_worlds(ctx) -> void:
	var lines: PackedStringArray = PlanetBadgeOverlayScript.build_badge_text_lines({
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: BiosphereScaleServiceScript.Stage.PREBIOTIC,
	}, {})
	ctx.assert_true(lines.size() == 1, "PREBIOTIC-Badges bleiben einzeilig")
	ctx.assert_true(lines[0] == "LIFE PREBIOTIC", "PREBIOTIC-Badges tragen nur die Life-Stage")


static func _test_badge_lines_show_density_without_species_for_microbial_worlds(ctx) -> void:
	var lines: PackedStringArray = PlanetBadgeOverlayScript.build_badge_text_lines({
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: BiosphereScaleServiceScript.Stage.MICROBIAL,
		BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.SULFUR_REACTIVE,
	}, {})
	ctx.assert_true(lines.size() == 2, "MICROBIAL-Badges bekommen eine zweite Zeile fuer Density")
	ctx.assert_true(lines[0] == "LIFE MICROBIAL", "Erste Badge-Zeile zeigt die kompakte Life-Stage")
	ctx.assert_true(lines[1] == "SPARSE", "MICROBIAL-Badges zeigen ohne Species-Basis nur die Density")


static func _test_badge_lines_show_density_and_species_for_complex_worlds(ctx) -> void:
	var lines: PackedStringArray = PlanetBadgeOverlayScript.build_badge_text_lines({
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
		BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.SULFUR_REACTIVE,
	}, {
		NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS: true,
		NativeSpeciesServiceScript.KEY_METABOLISM_CLASS: NativeSpeciesServiceScript.MetabolismClass.SULFUR_CHEMOSYNTHETIC,
	})
	ctx.assert_true(lines.size() == 2, "Species-Badges behalten die zweizeilige Survey-Darstellung")
	ctx.assert_true(lines[0] == "LIFE COMPLEX", "Erste Badge-Zeile kuerzt COMPLEX_MULTICELLULAR auf COMPLEX")
	ctx.assert_true(lines[1] == "THRIVING SULFUR", "Zweite Badge-Zeile kombiniert Density und Species-Kurzform")
