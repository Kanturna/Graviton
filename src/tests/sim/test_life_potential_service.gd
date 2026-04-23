extends RefCounted


const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")
const HK_LIFE_POTENTIAL_SERVICE: StringName = SimTestHarnessScript.HARNESS_KEY_LIFE_POTENTIAL_SERVICE


class PlanetaryStateProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


class EnvironmentProbe:
	extends Node

	var describe_calls: int = 0

	func describe_body(_id: StringName) -> Dictionary:
		describe_calls += 1
		return {}


static func run(ctx) -> void:
	ctx.current_suite = "test_life_potential_service"
	_test_service_ignores_environment_as_weighted_axis(ctx)
	_test_gamma_iv_anchor_matches_expected_scores(ctx)
	_test_anchor_worlds_map_to_expected_tracks(ctx)
	_test_contextual_tie_break_prefers_track_from_thermal_band(ctx)


static func _test_service_ignores_environment_as_weighted_axis(ctx) -> void:
	var registry: Node = _single_planet_registry(&"planet_a")
	var planetary_state_probe := PlanetaryStateProbe.new()
	planetary_state_probe.desc_by_id[&"planet_a"] = _sampled_state_desc(
		PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE,
		PlanetaryStateServiceScript.VolatileInventoryClass.RICH,
		PlanetaryStateServiceScript.ClimateBufferClass.BUFFERED,
		PlanetaryStateServiceScript.StabilityClass.STABLE,
		PlanetaryStateServiceScript.SeasonalityClass.LOW
	)
	var environment_probe := EnvironmentProbe.new()
	var service = LifePotentialServiceScript.new()
	service.configure(registry, planetary_state_probe, environment_probe)
	var desc: Dictionary = service.describe_body(&"planet_a")
	ctx.assert_true(bool(desc.get(LifePotentialServiceScript.KEY_HAS_LIFE_POTENTIAL_BASIS, false)),
		"LifePotentialService baut fuer unterstuetzte Bodies eine Potenzialbasis auf")
	ctx.assert_true(environment_probe.describe_calls == 0,
		"LifePotentialService nutzt Environment nicht als gewichtete Lookup-Achse")

	service.free()
	environment_probe.free()
	planetary_state_probe.free()
	registry.free()


static func _test_gamma_iv_anchor_matches_expected_scores(ctx) -> void:
	var registry: Node = _single_planet_registry(&"gamma_iv")
	var planetary_state_probe := PlanetaryStateProbe.new()
	planetary_state_probe.desc_by_id[&"gamma_iv"] = _sampled_state_desc(
		PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE,
		PlanetaryStateServiceScript.VolatileInventoryClass.LIMITED,
		PlanetaryStateServiceScript.ClimateBufferClass.MODERATE,
		PlanetaryStateServiceScript.StabilityClass.WINDOWED,
		PlanetaryStateServiceScript.SeasonalityClass.SEASONAL
	)
	var service = LifePotentialServiceScript.new()
	service.configure(registry, planetary_state_probe)
	var desc: Dictionary = service.describe_body(&"gamma_iv")
	var scores_by_track: Dictionary = desc.get(LifePotentialServiceScript.KEY_TRACK_SCORES_BY_ID, {})
	var classes_by_track: Dictionary = desc.get(LifePotentialServiceScript.KEY_TRACK_POTENTIAL_CLASS_BY_ID, {})

	ctx.assert_true(is_equal_approx(float(scores_by_track.get(LifePotentialServiceScript.Track.WATER_CARBON, -1.0)), 0.72),
		"gamma_iv ergibt fuer WATER_CARBON den kalibrierten 0.72-Score")
	ctx.assert_true(is_equal_approx(float(scores_by_track.get(LifePotentialServiceScript.Track.SULFUR_REACTIVE, -1.0)), 0.70),
		"gamma_iv ergibt fuer SULFUR_REACTIVE den kalibrierten 0.70-Score")
	ctx.assert_true(is_equal_approx(float(scores_by_track.get(LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT, -1.0)), 0.42),
		"gamma_iv ergibt fuer CRYOGENIC_SOLVENT den kalibrierten Low-Score")
	ctx.assert_true(
		int(classes_by_track.get(LifePotentialServiceScript.Track.WATER_CARBON, -1)) == LifePotentialServiceScript.PotentialClass.MEDIUM,
		"gamma_iv bleibt unter der 0.75-Grenze bewusst MEDIUM statt HIGH"
	)

	service.free()
	planetary_state_probe.free()
	registry.free()


static func _test_anchor_worlds_map_to_expected_tracks(ctx) -> void:
	var sample_setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var sample_service = sample_setup[HK_LIFE_POTENTIAL_SERVICE]
	var planet_a_desc: Dictionary = sample_service.describe_body(&"planet_a")
	_assert_track_and_class(
		ctx,
		planet_a_desc,
		LifePotentialServiceScript.Track.WATER_CARBON,
		LifePotentialServiceScript.PotentialClass.HIGH,
		"sample_system.planet_a"
	)
	_assert_track_class_max(
		ctx,
		planet_a_desc,
		LifePotentialServiceScript.Track.SULFUR_REACTIVE,
		LifePotentialServiceScript.PotentialClass.LOW,
		"sample_system.planet_a sulfur"
	)
	_assert_track_class_max(
		ctx,
		planet_a_desc,
		LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
		LifePotentialServiceScript.PotentialClass.LOW,
		"sample_system.planet_a cryogenic"
	)
	SimTestHarnessScript.teardown_context(sample_setup)

	var starter_setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"starter_world")
	var starter_service = starter_setup[HK_LIFE_POTENTIAL_SERVICE]
	var gamma_iv_desc: Dictionary = starter_service.describe_body(&"gamma_iv")
	_assert_track_and_class(
		ctx,
		gamma_iv_desc,
		LifePotentialServiceScript.Track.WATER_CARBON,
		LifePotentialServiceScript.PotentialClass.MEDIUM,
		"starter_world.gamma_iv"
	)
	_assert_track_and_class(
		ctx,
		starter_service.describe_body(&"alpha_iii"),
		LifePotentialServiceScript.Track.SULFUR_REACTIVE,
		LifePotentialServiceScript.PotentialClass.MEDIUM,
		"starter_world.alpha_iii"
	)
	_assert_track_and_class(
		ctx,
		starter_service.describe_body(&"gamma_iii"),
		LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
		LifePotentialServiceScript.PotentialClass.HIGH,
		"starter_world.gamma_iii"
	)
	_assert_track_class_max(
		ctx,
		gamma_iv_desc,
		LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
		LifePotentialServiceScript.PotentialClass.LOW,
		"starter_world.gamma_iv cryogenic"
	)
	SimTestHarnessScript.teardown_context(starter_setup)


static func _test_contextual_tie_break_prefers_track_from_thermal_band(ctx) -> void:
	var registry: Node = _single_planet_registry(&"planet_a")
	var service = LifePotentialServiceScript.new()
	var warm_tied_scores := {
		LifePotentialServiceScript.Track.WATER_CARBON: 0.50,
		LifePotentialServiceScript.Track.SULFUR_REACTIVE: 0.50,
		LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT: 0.10,
	}
	var cold_tied_scores := {
		LifePotentialServiceScript.Track.WATER_CARBON: 0.50,
		LifePotentialServiceScript.Track.SULFUR_REACTIVE: 0.10,
		LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT: 0.50,
	}

	var temperate_desc: Dictionary = _sampled_state_desc(
		PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE,
		PlanetaryStateServiceScript.VolatileInventoryClass.RICH,
		PlanetaryStateServiceScript.ClimateBufferClass.BUFFERED,
		PlanetaryStateServiceScript.StabilityClass.STABLE,
		PlanetaryStateServiceScript.SeasonalityClass.LOW
	)
	var hot_desc: Dictionary = _sampled_state_desc(
		PlanetaryStateServiceScript.ThermalExtremityClass.HOT,
		PlanetaryStateServiceScript.VolatileInventoryClass.LIMITED,
		PlanetaryStateServiceScript.ClimateBufferClass.MODERATE,
		PlanetaryStateServiceScript.StabilityClass.WINDOWED,
		PlanetaryStateServiceScript.SeasonalityClass.SEASONAL
	)
	var cold_desc: Dictionary = _sampled_state_desc(
		PlanetaryStateServiceScript.ThermalExtremityClass.COLD,
		PlanetaryStateServiceScript.VolatileInventoryClass.RICH,
		PlanetaryStateServiceScript.ClimateBufferClass.BUFFERED,
		PlanetaryStateServiceScript.StabilityClass.STABLE,
		PlanetaryStateServiceScript.SeasonalityClass.LOW
	)
	ctx.assert_true(
		service._dominant_track_id(warm_tied_scores, temperate_desc) == LifePotentialServiceScript.Track.WATER_CARBON,
		"Gleichstand auf temperierter Welt faellt auf WATER_CARBON"
	)
	ctx.assert_true(
		service._dominant_track_id(warm_tied_scores, hot_desc) == LifePotentialServiceScript.Track.SULFUR_REACTIVE,
		"Gleichstand auf heisser Welt faellt auf SULFUR_REACTIVE"
	)
	ctx.assert_true(
		service._dominant_track_id(cold_tied_scores, cold_desc) == LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
		"Gleichstand auf kalter Welt faellt auf CRYOGENIC_SOLVENT"
	)

	service.free()
	registry.free()


static func _assert_track_and_class(ctx, desc: Dictionary, expected_track: int, expected_class: int, label: String) -> void:
	ctx.assert_true(
		int(desc.get(LifePotentialServiceScript.KEY_DOMINANT_TRACK_ID, -1)) == expected_track,
		"%s nutzt den erwarteten dominanten Chemiepfad" % label
	)
	ctx.assert_true(
		int(desc.get(LifePotentialServiceScript.KEY_DOMINANT_POTENTIAL_CLASS, -1)) == expected_class,
		"%s nutzt die erwartete Potenzialklasse" % label
	)


static func _assert_track_class_max(ctx, desc: Dictionary, track_id: int, max_class: int, label: String) -> void:
	var classes_by_track: Dictionary = desc.get(LifePotentialServiceScript.KEY_TRACK_POTENTIAL_CLASS_BY_ID, {})
	ctx.assert_true(
		int(classes_by_track.get(track_id, LifePotentialServiceScript.PotentialClass.NONE)) <= max_class,
		"%s bleibt unter der erwarteten Obergrenze" % label
	)


static func _sampled_state_desc(
		thermal_class: int,
		volatile_class: int,
		buffer_class: int,
		stability_class: int,
		seasonality_class: int
	) -> Dictionary:
	return {
		"is_supported_body_kind": true,
		"has_sampled_year_basis": true,
		"thermal_extremity_class": thermal_class,
		"volatile_inventory_class": volatile_class,
		"climate_buffer_class": buffer_class,
		"stability_class": stability_class,
		"seasonality_class": seasonality_class,
	}


static func _single_planet_registry(planet_id: StringName) -> Node:
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var star := BodyDef.new()
	star.id = &"sol"
	star.display_name = "Sol"
	star.kind = BodyType.Kind.STAR
	star.mass_kg = UnitSystem.SOLAR_MASS_KG
	star.radius_m = 6.957e8
	star.parent_id = &""
	registry.register_body(star)

	var planet := BodyDef.new()
	planet.id = planet_id
	planet.display_name = String(planet_id)
	planet.kind = BodyType.Kind.PLANET
	planet.mass_kg = UnitSystem.EARTH_MASS_KG
	planet.radius_m = UnitSystem.EARTH_RADIUS_M
	planet.parent_id = &"sol"
	planet.orbit_profile = OrbitProfile.new()
	planet.orbit_profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	planet.orbit_profile.authored_radius_m = 1.0e9
	planet.orbit_profile.authored_period_s = 10.0
	registry.register_body(planet)
	return registry
