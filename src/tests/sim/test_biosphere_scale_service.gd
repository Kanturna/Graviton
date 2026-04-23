extends RefCounted


const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const ProtoBiosphereSimulationServiceScript = preload("res://src/sim/life/proto_biosphere_simulation_service.gd")
const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")


class PlanetaryStateProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


class LifePotentialProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


class ProtoBiosphereProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


static func run(ctx) -> void:
	ctx.current_suite = "test_biosphere_scale_service"
	_test_pure_helper_matches_live_describe_path(ctx)
	_test_band_carrying_capacity_uses_thermal_gate_and_progress_squared(ctx)
	_test_dominant_track_defaults_to_life_potential_and_only_switches_on_zero_capacity_edge_case(ctx)
	_test_sample_system_planet_a_calibrates_to_microbial_after_four_ticks_and_later_complex_multicellular(ctx)
	_test_anchor_worlds_keep_expected_tracks_and_gamma_iv_stays_below_ecosystem(ctx)


static func _test_pure_helper_matches_live_describe_path(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var planetary_state_service = setup[SimTestHarnessScript.HARNESS_KEY_PLANETARY_STATE_SERVICE]
	var life_potential_service = setup[SimTestHarnessScript.HARNESS_KEY_LIFE_POTENTIAL_SERVICE]
	var proto_biosphere_service = setup[SimTestHarnessScript.HARNESS_KEY_PROTO_BIOSPHERE_SERVICE]
	var biosphere_scale_service = setup[SimTestHarnessScript.HARNESS_KEY_BIOSPHERE_SCALE_SERVICE]
	var live_desc: Dictionary = biosphere_scale_service.describe_body(&"planet_a")
	var pure_desc: Dictionary = BiosphereScaleServiceScript.evaluate_from_descriptions(
		planetary_state_service.describe_body(&"planet_a"),
		life_potential_service.describe_body(&"planet_a"),
		proto_biosphere_service.describe_body(&"planet_a"),
		&"planet_a"
	)
	ctx.assert_true(
		live_desc == pure_desc,
		"BiosphereScaleService.evaluate_from_descriptions liefert fuer dieselbe Welt exakt denselben Desc wie describe_body"
	)
	SimTestHarnessScript.teardown_context(setup)


static func _test_band_carrying_capacity_uses_thermal_gate_and_progress_squared(ctx) -> void:
	var registry: Node = _single_planet_registry(&"planet_a")
	var planetary_state_probe := PlanetaryStateProbe.new()
	planetary_state_probe.desc_by_id[&"planet_a"] = _sampled_state_desc(
		295.0,
		295.0,
		210.0,
		PlanetaryStateServiceScript.VolatileInventoryClass.RICH,
		PlanetaryStateServiceScript.ClimateBufferClass.BUFFERED,
		PlanetaryStateServiceScript.StabilityClass.STABLE,
		PlanetaryStateServiceScript.SeasonalityClass.LOW,
		PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
	)
	var life_potential_probe := LifePotentialProbe.new()
	life_potential_probe.desc_by_id[&"planet_a"] = _life_potential_desc(
		&"planet_a",
		LifePotentialServiceScript.Track.WATER_CARBON,
		LifePotentialServiceScript.PotentialClass.HIGH
	)
	var proto_biosphere_probe := ProtoBiosphereProbe.new()
	proto_biosphere_probe.desc_by_id[&"planet_a"] = _proto_biosphere_desc(
		&"planet_a",
		{
			LifePotentialServiceScript.Track.WATER_CARBON: 0.50,
			LifePotentialServiceScript.Track.SULFUR_REACTIVE: 0.10,
			LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT: 0.10,
		},
		LifePotentialServiceScript.Track.WATER_CARBON,
		LifePotentialServiceScript.PotentialClass.HIGH
	)
	var service = BiosphereScaleServiceScript.new()
	service.configure(registry, planetary_state_probe, life_potential_probe, proto_biosphere_probe)
	var desc: Dictionary = service.describe_body(&"planet_a")
	var water_carrying_capacity_by_band: Dictionary = desc.get(
		BiosphereScaleServiceScript.KEY_CARRYING_CAPACITY_BY_TRACK_BY_BAND,
		{}
	).get(LifePotentialServiceScript.Track.WATER_CARBON, {})
	var water_biomass_by_band: Dictionary = desc.get(
		BiosphereScaleServiceScript.KEY_BIOMASS_BY_TRACK_BY_BAND,
		{}
	).get(LifePotentialServiceScript.Track.WATER_CARBON, {})
	var water_carrying_capacity_index: float = float(desc.get(
		BiosphereScaleServiceScript.KEY_CARRYING_CAPACITY_INDEX_BY_TRACK,
		{}
	).get(LifePotentialServiceScript.Track.WATER_CARBON, -1.0))
	var water_biomass_index: float = float(desc.get(
		BiosphereScaleServiceScript.KEY_BIOMASS_INDEX_BY_TRACK,
		{}
	).get(LifePotentialServiceScript.Track.WATER_CARBON, -1.0))

	ctx.assert_true(
		is_equal_approx(float(water_carrying_capacity_by_band.get(BiosphereScaleServiceScript.BAND_NORTH, -1.0)), 0.0),
		"Band-Thermik gate't thermisch inkompatible WATER-CARBON-Baender hart auf Carrying Capacity 0.0"
	)
	ctx.assert_true(
		is_equal_approx(float(water_carrying_capacity_by_band.get(BiosphereScaleServiceScript.BAND_SOUTH, -1.0)), 1.0)
			and is_equal_approx(float(water_carrying_capacity_by_band.get(BiosphereScaleServiceScript.BAND_EQUATOR, -1.0)), 1.0),
		"Temperierte WATER-CARBON-Baender koennen bei Preferred-Achsen volle Carrying Capacity erreichen"
	)
	ctx.assert_true(
		is_equal_approx(float(water_biomass_by_band.get(BiosphereScaleServiceScript.BAND_SOUTH, -1.0)), 0.25)
			and is_equal_approx(float(water_biomass_by_band.get(BiosphereScaleServiceScript.BAND_EQUATOR, -1.0)), 0.25),
		"Biomass nutzt progress^2, also wird aus Proto-Progress 0.50 genau Biomass-Fraction 0.25"
	)
	ctx.assert_true(
		is_equal_approx(water_carrying_capacity_index, 0.75),
		"Band-Indizes nutzen exakt die 0.25/0.50/0.25-Flaechengewichte"
	)
	ctx.assert_true(
		is_equal_approx(water_biomass_index, 0.1875),
		"Biomass-Index ist die flaechengwichtete Summe aus Carrying Capacity und progress^2"
	)

	service.free()
	proto_biosphere_probe.free()
	life_potential_probe.free()
	planetary_state_probe.free()
	registry.free()


static func _test_dominant_track_defaults_to_life_potential_and_only_switches_on_zero_capacity_edge_case(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var biosphere_scale_service = setup[SimTestHarnessScript.HARNESS_KEY_BIOSPHERE_SCALE_SERVICE]
	var life_potential_service = setup[SimTestHarnessScript.HARNESS_KEY_LIFE_POTENTIAL_SERVICE]
	var live_desc: Dictionary = biosphere_scale_service.describe_body(&"planet_a")
	var live_life_potential_desc: Dictionary = life_potential_service.describe_body(&"planet_a")
	ctx.assert_true(
		int(live_desc.get(BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID, -1))
			== int(live_life_potential_desc.get(LifePotentialServiceScript.KEY_DOMINANT_TRACK_ID, -2)),
		"Life v2 bleibt auf normalen Welten standardmaessig an den Life-Potential-Track verankert"
	)
	SimTestHarnessScript.teardown_context(setup)

	var edge_case_desc: Dictionary = BiosphereScaleServiceScript.evaluate_from_descriptions(
		_sampled_state_desc(
			210.0,
			210.0,
			210.0,
			PlanetaryStateServiceScript.VolatileInventoryClass.RICH,
			PlanetaryStateServiceScript.ClimateBufferClass.BUFFERED,
			PlanetaryStateServiceScript.StabilityClass.STABLE,
			PlanetaryStateServiceScript.SeasonalityClass.LOW,
			PlanetaryStateServiceScript.ThermalExtremityClass.COLD
		),
		_life_potential_desc(
			&"edge_world",
			LifePotentialServiceScript.Track.WATER_CARBON,
			LifePotentialServiceScript.PotentialClass.MEDIUM,
			{
				LifePotentialServiceScript.Track.WATER_CARBON: LifePotentialServiceScript.PotentialClass.MEDIUM,
				LifePotentialServiceScript.Track.SULFUR_REACTIVE: LifePotentialServiceScript.PotentialClass.LOW,
				LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT: LifePotentialServiceScript.PotentialClass.HIGH,
			}
		),
		_proto_biosphere_desc(
			&"edge_world",
			{
				LifePotentialServiceScript.Track.WATER_CARBON: 0.30,
				LifePotentialServiceScript.Track.SULFUR_REACTIVE: 0.10,
				LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT: 0.50,
			},
			LifePotentialServiceScript.Track.WATER_CARBON,
			LifePotentialServiceScript.PotentialClass.MEDIUM
		),
		&"edge_world"
	)
	ctx.assert_true(
		int(edge_case_desc.get(BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID, -1))
			== LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
		"Life v2 darf nur dann vom Potential-Track abweichen, wenn dessen Carrying Capacity 0.0 ist und ein anderer Track positive Biomass traegt"
	)


static func _test_sample_system_planet_a_calibrates_to_microbial_after_four_ticks_and_later_complex_multicellular(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var time_service: Node = setup[SimTestHarnessScript.HARNESS_KEY_TIME_SERVICE]
	var biosphere_scale_service = setup[SimTestHarnessScript.HARNESS_KEY_BIOSPHERE_SCALE_SERVICE]
	for _tick in range(4):
		time_service._emit_tick(ProtoBiosphereSimulationServiceScript.BIO_TICK_STEP_S)
	var after_four_ticks_desc: Dictionary = biosphere_scale_service.describe_body(&"planet_a")
	ctx.assert_true(
		int(after_four_ticks_desc.get(BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID, -1))
			== LifePotentialServiceScript.Track.WATER_CARBON,
		"sample_system.planet_a bleibt auch in Life v2 WATER_CARBON-dominiert"
	)
	ctx.assert_true(
		int(after_four_ticks_desc.get(BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE, -1))
			== BiosphereScaleServiceScript.Stage.MICROBIAL,
		"sample_system.planet_a bleibt nach vier Bio-Ticks player-facing noch MICROBIAL, weil die Band-Gates nur aequatoriale Biomass tragen"
	)
	for _tick in range(96):
		time_service._emit_tick(ProtoBiosphereSimulationServiceScript.BIO_TICK_STEP_S)
	var late_desc: Dictionary = biosphere_scale_service.describe_body(&"planet_a")
	ctx.assert_true(
		int(late_desc.get(BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE, -1))
			== BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
		"sample_system.planet_a kalibriert im Endzustand auf COMPLEX_MULTICELLULAR statt bis COMPLEX_ECOSYSTEM durchzulaufen"
	)
	SimTestHarnessScript.teardown_context(setup)


static func _test_anchor_worlds_keep_expected_tracks_and_gamma_iv_stays_below_ecosystem(ctx) -> void:
	var starter_setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"starter_world")
	var starter_time_service: Node = starter_setup[SimTestHarnessScript.HARNESS_KEY_TIME_SERVICE]
	var starter_biosphere_scale_service = starter_setup[SimTestHarnessScript.HARNESS_KEY_BIOSPHERE_SCALE_SERVICE]
	for _tick in range(100):
		starter_time_service._emit_tick(ProtoBiosphereSimulationServiceScript.BIO_TICK_STEP_S)

	var gamma_iv_desc: Dictionary = starter_biosphere_scale_service.describe_body(&"gamma_iv")
	var alpha_iii_desc: Dictionary = starter_biosphere_scale_service.describe_body(&"alpha_iii")
	var gamma_iii_desc: Dictionary = starter_biosphere_scale_service.describe_body(&"gamma_iii")
	var gamma_iii_cryogenic_biomass_by_band: Dictionary = gamma_iii_desc.get(
		BiosphereScaleServiceScript.KEY_BIOMASS_BY_TRACK_BY_BAND,
		{}
	).get(LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT, {})

	ctx.assert_true(
		int(gamma_iv_desc.get(BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID, -1))
			== LifePotentialServiceScript.Track.WATER_CARBON,
		"starter_world.gamma_iv bleibt in Life v2 WATER_CARBON-dominiert"
	)
	ctx.assert_true(
		int(gamma_iv_desc.get(BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE, -1))
			== BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
		"starter_world.gamma_iv kalibriert auf COMPLEX_MULTICELLULAR statt automatisch bis COMPLEX_ECOSYSTEM durchzulaufen"
	)
	ctx.assert_true(
		int(alpha_iii_desc.get(BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID, -1))
			== LifePotentialServiceScript.Track.SULFUR_REACTIVE,
		"starter_world.alpha_iii bleibt auch in Life v2 sulfur-dominiert"
	)
	ctx.assert_true(
		int(gamma_iii_desc.get(BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID, -1))
			== LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
		"starter_world.gamma_iii bleibt auch in Life v2 cryogenic-dominiert"
	)
	ctx.assert_true(
		float(gamma_iii_cryogenic_biomass_by_band.get(BiosphereScaleServiceScript.BAND_SOUTH, 0.0)) > 0.0
			or float(gamma_iii_cryogenic_biomass_by_band.get(BiosphereScaleServiceScript.BAND_EQUATOR, 0.0)) > 0.0
			or float(gamma_iii_cryogenic_biomass_by_band.get(BiosphereScaleServiceScript.BAND_NORTH, 0.0)) > 0.0,
		"starter_world.gamma_iii traegt tatsaechlich cryogene Biomass auf thermisch kompatiblen Baendern"
	)
	SimTestHarnessScript.teardown_context(starter_setup)


static func _sampled_state_desc(
		south_band_mean_surface_temperature_k: float,
		equator_band_mean_surface_temperature_k: float,
		north_band_mean_surface_temperature_k: float,
		volatile_class: int,
		buffer_class: int,
		stability_class: int,
		seasonality_class: int,
		thermal_class: int
	) -> Dictionary:
	return {
		PlanetaryStateServiceScript.KEY_BODY_ID: &"planet_a",
		PlanetaryStateServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		PlanetaryStateServiceScript.KEY_HAS_SAMPLED_YEAR_BASIS: true,
		PlanetaryStateServiceScript.KEY_SOUTH_BAND_MEAN_SURFACE_TEMPERATURE_K: south_band_mean_surface_temperature_k,
		PlanetaryStateServiceScript.KEY_EQUATOR_BAND_MEAN_SURFACE_TEMPERATURE_K: equator_band_mean_surface_temperature_k,
		PlanetaryStateServiceScript.KEY_NORTH_BAND_MEAN_SURFACE_TEMPERATURE_K: north_band_mean_surface_temperature_k,
		PlanetaryStateServiceScript.KEY_VOLATILE_INVENTORY_CLASS: volatile_class,
		PlanetaryStateServiceScript.KEY_CLIMATE_BUFFER_CLASS: buffer_class,
		PlanetaryStateServiceScript.KEY_STABILITY_CLASS: stability_class,
		PlanetaryStateServiceScript.KEY_SEASONALITY_CLASS: seasonality_class,
		PlanetaryStateServiceScript.KEY_THERMAL_EXTREMITY_CLASS: thermal_class,
	}


static func _life_potential_desc(
		body_id: StringName,
		dominant_track_id: int,
		dominant_potential_class: int,
		classes_by_track: Dictionary = {}
	) -> Dictionary:
	var resolved_classes_by_track: Dictionary = classes_by_track.duplicate()
	if resolved_classes_by_track.is_empty():
		for track_id in LifePotentialServiceScript.TRACK_IDS:
			resolved_classes_by_track[track_id] = LifePotentialServiceScript.PotentialClass.NONE
		resolved_classes_by_track[dominant_track_id] = dominant_potential_class
	return {
		LifePotentialServiceScript.KEY_BODY_ID: body_id,
		LifePotentialServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		LifePotentialServiceScript.KEY_HAS_LIFE_POTENTIAL_BASIS: true,
		LifePotentialServiceScript.KEY_DOMINANT_TRACK_ID: dominant_track_id,
		LifePotentialServiceScript.KEY_DOMINANT_POTENTIAL_CLASS: dominant_potential_class,
		LifePotentialServiceScript.KEY_TRACK_POTENTIAL_CLASS_BY_ID: resolved_classes_by_track,
	}


static func _proto_biosphere_desc(
		body_id: StringName,
		progress_by_track: Dictionary,
		dominant_track_id: int,
		dominant_potential_class: int
	) -> Dictionary:
	return {
		ProtoBiosphereSimulationServiceScript.KEY_BODY_ID: body_id,
		ProtoBiosphereSimulationServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		ProtoBiosphereSimulationServiceScript.KEY_HAS_BIOSPHERE_BASIS: true,
		ProtoBiosphereSimulationServiceScript.KEY_TRACK_PROGRESS_BY_ID: progress_by_track,
		ProtoBiosphereSimulationServiceScript.KEY_DOMINANT_TRACK_ID: dominant_track_id,
		ProtoBiosphereSimulationServiceScript.KEY_BIOSPHERE_STAGE: ProtoBiosphereSimulationServiceScript.Stage.PREBIOTIC,
		ProtoBiosphereSimulationServiceScript.KEY_DOMINANT_POTENTIAL_CLASS: dominant_potential_class,
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
