extends RefCounted

const SurveyVisualThemeScript = preload("res://src/tools/ui/survey_visual_theme.gd")
const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_survey_visual_theme"
	_test_body_kind_colors(ctx)
	_test_environment_class_colors(ctx)
	_test_ecosystem_type_colors(ctx)
	_test_life_stage_colors(ctx)


static func _test_body_kind_colors(ctx) -> void:
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_body_kind(BodyType.Kind.STAR) == SurveyVisualThemeScript.BODY_TEXT_STAR,
		"SurveyVisualTheme faerbt Sterne warm/golden"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_body_kind(BodyType.Kind.BLACK_HOLE) == SurveyVisualThemeScript.BODY_TEXT_BLACK_HOLE,
		"SurveyVisualTheme faerbt Schwarze Loecher kuehl/violett"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_body_kind(BodyType.Kind.PLANET) == SurveyVisualThemeScript.BODY_TEXT_PLANET,
		"SurveyVisualTheme hat einen eigenen PLANET-Farbton"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_body_kind(9999) == SurveyVisualThemeScript.BODY_TEXT_DEFAULT,
		"Unbekannte Body-Kinds fallen auf neutralen Text zurueck"
	)


static func _test_environment_class_colors(ctx) -> void:
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_environment_class(EnvironmentServiceScript.Class.HABITABLE) == SurveyVisualThemeScript.ENV_HABITABLE,
		"HABITABLE nutzt den gruenen Environment-Farbton"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_environment_class(EnvironmentServiceScript.Class.MARGINAL) == SurveyVisualThemeScript.ENV_HARSH,
		"Internes MARGINAL mappt farblich auf den player-facing HARSH-Zustand"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_environment_class(EnvironmentServiceScript.Class.HOSTILE) == SurveyVisualThemeScript.ENV_HOSTILE,
		"HOSTILE nutzt den roten Environment-Farbton"
	)


static func _test_ecosystem_type_colors(ctx) -> void:
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_ecosystem_type(EnvironmentServiceScript.EcosystemType.FROZEN_WORLD) == SurveyVisualThemeScript.CLIMATE_FROZEN,
		"FROZEN nutzt einen kalten Blauton"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_ecosystem_type(EnvironmentServiceScript.EcosystemType.TEMPERATE_WORLD) == SurveyVisualThemeScript.CLIMATE_TEMPERATE,
		"TEMPERATE nutzt einen gruenen Klimaton"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_ecosystem_type(EnvironmentServiceScript.EcosystemType.SEASONAL_WORLD) == SurveyVisualThemeScript.CLIMATE_SEASONAL,
		"SEASONAL nutzt einen warmen Gelbton"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_ecosystem_type(EnvironmentServiceScript.EcosystemType.HOT_WORLD) == SurveyVisualThemeScript.CLIMATE_HOT,
		"HOT nutzt einen roten Klimaton"
	)


static func _test_life_stage_colors(ctx) -> void:
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_life_stage(BiosphereScaleServiceScript.Stage.STERILE) == SurveyVisualThemeScript.LIFE_STERILE,
		"STERILE bleibt hellgrau/blaugrau lesbar"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_life_stage(BiosphereScaleServiceScript.Stage.PREBIOTIC) == SurveyVisualThemeScript.LIFE_PREBIOTIC,
		"PREBIOTIC nutzt einen hellen Life-Farbton"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_life_stage(BiosphereScaleServiceScript.Stage.MICROBIAL) == SurveyVisualThemeScript.LIFE_MICROBIAL,
		"MICROBIAL nutzt einen aktiveren Life-Farbton"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_life_stage(BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR) == SurveyVisualThemeScript.LIFE_COMPLEX,
		"COMPLEX_MULTICELLULAR nutzt einen komplexeren Life-Farbton"
	)
	ctx.assert_true(
		SurveyVisualThemeScript.color_for_life_stage(BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM) == SurveyVisualThemeScript.LIFE_ECOSYSTEM,
		"COMPLEX_ECOSYSTEM nutzt den staerksten Life-Farbton"
	)
