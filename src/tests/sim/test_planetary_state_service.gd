extends RefCounted


const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")
const HK_REGISTRY: StringName = SimTestHarnessScript.HARNESS_KEY_REGISTRY
const HK_THERMAL_SERVICE: StringName = SimTestHarnessScript.HARNESS_KEY_THERMAL_SERVICE
const HK_ATMOSPHERE_SERVICE: StringName = SimTestHarnessScript.HARNESS_KEY_ATMOSPHERE_SERVICE
const HK_PLANETARY_STATE_SERVICE: StringName = SimTestHarnessScript.HARNESS_KEY_PLANETARY_STATE_SERVICE


class YearSamplerProbe:
	extends Node

	var sample_calls_by_id: Dictionary = {}
	var sample_result: Dictionary = {}

	func sample_body(id: StringName) -> Dictionary:
		sample_calls_by_id[id] = int(sample_calls_by_id.get(id, 0)) + 1
		var out: Dictionary = sample_result.duplicate()
		out["body_id"] = id
		return out


static func run(ctx) -> void:
	ctx.current_suite = "test_planetary_state_service"
	_test_service_uses_lazy_annual_cache(ctx)
	_test_pure_helper_matches_live_describe_path(ctx)
	_test_sample_system_planet_a_matches_anchor_profile(ctx)
	_test_starter_world_gamma_iv_matches_anchor_profile(ctx)
	_test_extreme_and_cold_references_keep_clear_world_readings(ctx)


static func _test_service_uses_lazy_annual_cache(ctx) -> void:
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var star := BodyDef.new()
	star.id = &"sol"
	star.display_name = "Sol"
	star.kind = BodyType.Kind.STAR
	star.mass_kg = UnitSystem.SOLAR_MASS_KG
	star.radius_m = 6.957e8
	star.luminosity_w = UnitSystem.SOLAR_LUMINOSITY_W
	star.parent_id = &""
	star.orbit_profile = null
	registry.register_body(star)

	var planet := BodyDef.new()
	planet.id = &"planet_a"
	planet.display_name = "Planet A"
	planet.kind = BodyType.Kind.PLANET
	planet.mass_kg = UnitSystem.EARTH_MASS_KG
	planet.radius_m = UnitSystem.EARTH_RADIUS_M
	planet.parent_id = &"sol"
	planet.volatile_inventory_ratio = 0.80
	planet.climate_buffer_factor = 0.80
	planet.orbit_profile = OrbitProfile.new()
	planet.orbit_profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	planet.orbit_profile.authored_radius_m = 1.0e9
	planet.orbit_profile.authored_period_s = 10.0
	registry.register_body(planet)

	var sampler := YearSamplerProbe.new()
	sampler.sample_result = {
		"has_sampled_year_basis": true,
		"has_primary_source_only_basis": true,
		"south_band_min_surface_temperature_k": 290.0,
		"south_band_max_surface_temperature_k": 300.0,
		"south_band_mean_surface_temperature_k": 295.0,
		"equator_band_min_surface_temperature_k": 292.0,
		"equator_band_max_surface_temperature_k": 302.0,
		"equator_band_mean_surface_temperature_k": 297.0,
		"north_band_min_surface_temperature_k": 289.0,
		"north_band_max_surface_temperature_k": 301.0,
		"north_band_mean_surface_temperature_k": 295.0,
		"annual_global_min_surface_temperature_k": 289.0,
		"annual_global_max_surface_temperature_k": 302.0,
		"annual_global_mean_surface_temperature_k": 296.0,
		"annual_max_band_span_k": 13.0,
		"annual_moderate_sample_fraction": 1.0,
	}

	var thermal_service = load("res://src/sim/thermal/thermal_service.gd").new()
	var atmosphere_service = load("res://src/sim/atmosphere/atmosphere_service.gd").new()
	var service = PlanetaryStateServiceScript.new()
	service.configure(
		registry,
		thermal_service,
		atmosphere_service,
		sampler
	)
	service.describe_body(&"planet_a")
	service.describe_body(&"planet_a")
	ctx.assert_true(int(sampler.sample_calls_by_id.get(&"planet_a", 0)) == 1, "PlanetaryStateService berechnet annualisierte Stats pro Body lazy genau einmal")

	service.free()
	thermal_service.free()
	atmosphere_service.free()
	sampler.free()
	registry.free()


static func _test_pure_helper_matches_live_describe_path(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var registry: Node = setup[HK_REGISTRY]
	var year_sampler = setup[SimTestHarnessScript.HARNESS_KEY_PLANETARY_YEAR_SAMPLER]
	var service = setup[HK_PLANETARY_STATE_SERVICE]
	var body_def: BodyDef = registry.get_def(&"planet_a")
	var annual_profile: Dictionary = year_sampler.sample_body(&"planet_a")
	var live_desc: Dictionary = service.describe_body(&"planet_a")
	var pure_desc: Dictionary = PlanetaryStateServiceScript.describe_from_def_and_annual_profile(
		&"planet_a",
		body_def,
		annual_profile
	)
	ctx.assert_true(
		live_desc == pure_desc,
		"describe_from_def_and_annual_profile liefert fuer dieselbe Welt exakt denselben State-Desc wie describe_body"
	)
	SimTestHarnessScript.teardown_context(setup)


static func _test_sample_system_planet_a_matches_anchor_profile(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var planetary_state_service = setup[HK_PLANETARY_STATE_SERVICE]
	var desc: Dictionary = planetary_state_service.describe_body(&"planet_a")
	ctx.assert_true(bool(desc.get("has_sampled_year_basis", false)), "sample_system.planet_a hat eine sampled-year-Basis")
	ctx.assert_true(
		PlanetaryStateServiceScript.to_string_volatile_inventory_class(int(desc.get("volatile_inventory_class", -1))) == "RICH",
		"sample_system.planet_a liest als reservoirreiche Welt"
	)
	ctx.assert_true(
		PlanetaryStateServiceScript.to_string_climate_buffer_class(int(desc.get("climate_buffer_class", -1))) == "BUFFERED",
		"sample_system.planet_a liest als gepufferte Welt"
	)
	ctx.assert_true(
		PlanetaryStateServiceScript.to_string_thermal_extremity_class(int(desc.get("thermal_extremity_class", -1))) == "TEMPERATE",
		"sample_system.planet_a bleibt im Mittel temperiert"
	)
	SimTestHarnessScript.teardown_context(setup)


static func _test_starter_world_gamma_iv_matches_anchor_profile(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"starter_world")
	var planetary_state_service = setup[HK_PLANETARY_STATE_SERVICE]
	var desc: Dictionary = planetary_state_service.describe_body(&"gamma_iv")
	ctx.assert_true(bool(desc.get("has_sampled_year_basis", false)), "starter_world.gamma_iv hat eine sampled-year-Basis")
	ctx.assert_true(
		PlanetaryStateServiceScript.to_string_volatile_inventory_class(int(desc.get("volatile_inventory_class", -1))) == "LIMITED",
		"starter_world.gamma_iv liest als LIMITED-Reservoirwelt"
	)
	ctx.assert_true(
		PlanetaryStateServiceScript.to_string_climate_buffer_class(int(desc.get("climate_buffer_class", -1))) == "MODERATE",
		"starter_world.gamma_iv liest als moderat gepufferte Welt"
	)
	ctx.assert_true(
		PlanetaryStateServiceScript.to_string_thermal_extremity_class(int(desc.get("thermal_extremity_class", -1))) == "TEMPERATE",
		"starter_world.gamma_iv bleibt im Mittel temperiert"
	)
	SimTestHarnessScript.teardown_context(setup)


static func _test_extreme_and_cold_references_keep_clear_world_readings(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"starter_world")
	var planetary_state_service = setup[HK_PLANETARY_STATE_SERVICE]
	var hot_desc: Dictionary = planetary_state_service.describe_body(&"alpha_iii")
	var cold_desc: Dictionary = planetary_state_service.describe_body(&"gamma_iii")

	ctx.assert_true(
		PlanetaryStateServiceScript.to_string_volatile_inventory_class(int(hot_desc.get("volatile_inventory_class", -1))) == "TRACE",
		"alpha_iii bleibt im World-Profil eine Trace-Volatiles-Welt"
	)
	ctx.assert_true(
		PlanetaryStateServiceScript.to_string_climate_buffer_class(int(hot_desc.get("climate_buffer_class", -1))) == "UNBUFFERED",
		"alpha_iii bleibt im World-Profil weitgehend ungepuffert"
	)
	ctx.assert_true(
		PlanetaryStateServiceScript.to_string_thermal_extremity_class(int(cold_desc.get("thermal_extremity_class", -1))) == "FROZEN"
			or PlanetaryStateServiceScript.to_string_thermal_extremity_class(int(cold_desc.get("thermal_extremity_class", -1))) == "COLD",
		"ein klar aeusserer Gamma-Referenzplanet bleibt kalt bis gefroren lesbar"
	)
	SimTestHarnessScript.teardown_context(setup)
