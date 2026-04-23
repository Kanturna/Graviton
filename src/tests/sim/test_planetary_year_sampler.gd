extends RefCounted


const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")
const HK_REGISTRY: StringName = SimTestHarnessScript.HARNESS_KEY_REGISTRY
const HK_TIME_SERVICE: StringName = SimTestHarnessScript.HARNESS_KEY_TIME_SERVICE
const HK_PLANETARY_YEAR_SAMPLER: StringName = SimTestHarnessScript.HARNESS_KEY_PLANETARY_YEAR_SAMPLER


static func run(ctx) -> void:
	ctx.current_suite = "test_planetary_year_sampler"
	_test_sampler_is_non_mutating_for_kepler_planet(ctx)
	_test_sampler_supports_authored_moon_profiles(ctx)
	_test_numeric_local_bodies_report_no_sampled_year_basis(ctx)


static func _test_sampler_is_non_mutating_for_kepler_planet(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var registry: Node = setup[HK_REGISTRY]
	var time_service: Node = setup[HK_TIME_SERVICE]
	var sampler = setup[HK_PLANETARY_YEAR_SAMPLER]
	var before_time_s: float = time_service.sim_time_s
	var state_before: BodyState = registry.get_state(&"planet_a")
	var before_position: Vector3 = state_before.position_parent_frame_m
	var before_velocity: Vector3 = state_before.velocity_parent_frame_mps

	var annual_desc: Dictionary = sampler.sample_body(&"planet_a")
	ctx.assert_true(bool(annual_desc.get("has_sampled_year_basis", false)), "planet_a liefert als KEPLER-Planet eine sampled-year-Basis")
	ctx.assert_true(
		registry.get_state(&"planet_a").position_parent_frame_m.is_equal_approx(before_position),
		"planetary_year_sampler mutiert den Live-BodyState nicht"
	)
	ctx.assert_true(
		registry.get_state(&"planet_a").velocity_parent_frame_mps.is_equal_approx(before_velocity),
		"planetary_year_sampler mutiert auch die Live-Velocity nicht"
	)
	ctx.assert_almost(time_service.sim_time_s, before_time_s, 1.0e-9, "planetary_year_sampler veraendert TimeService.sim_time_s nicht")
	SimTestHarnessScript.teardown_context(setup)


static func _test_sampler_supports_authored_moon_profiles(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var sampler = setup[HK_PLANETARY_YEAR_SAMPLER]
	var annual_desc: Dictionary = sampler.sample_body(&"moon_a")
	ctx.assert_true(bool(annual_desc.get("has_sampled_year_basis", false)), "AUTHORED-Orbit-Monde bekommen in v1 eine sampled-year-Basis")
	ctx.assert_true(bool(annual_desc.get("has_primary_source_only_basis", false)), "AUTHORED-Orbit-Monde markieren den bekannten primary-source-only-V1-Pfad explizit")
	SimTestHarnessScript.teardown_context(setup)


static func _test_numeric_local_bodies_report_no_sampled_year_basis(ctx) -> void:
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var sampler = load("res://src/sim/planetary/planetary_year_sampler.gd").new()
	sampler.configure(registry)

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
	planet.id = &"numeric_planet"
	planet.display_name = "Numeric Planet"
	planet.kind = BodyType.Kind.PLANET
	planet.mass_kg = UnitSystem.EARTH_MASS_KG
	planet.radius_m = UnitSystem.EARTH_RADIUS_M
	planet.parent_id = &"sol"
	planet.orbit_profile = OrbitProfile.new()
	planet.orbit_profile.mode = OrbitMode.Kind.NUMERIC_LOCAL
	registry.register_body(planet)

	var annual_desc: Dictionary = sampler.sample_body(&"numeric_planet")
	ctx.assert_true(not bool(annual_desc.get("has_sampled_year_basis", true)), "NUMERIC_LOCAL-Profile werden im Jahres-Sampler frueh abgelehnt")

	sampler.free()
	registry.free()
