extends RefCounted


const WorldLoaderScript = preload("res://src/sim/world/world_loader.gd")
const ProtoBiosphereSimulationServiceScript = preload("res://src/sim/life/proto_biosphere_simulation_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_proto_biosphere_simulation_service"
	_test_sample_system_high_track_becomes_microbial_after_four_ticks(ctx)
	_test_starter_world_anchors_start_with_expected_tracks(ctx)
	_test_scaleup_galaxy_100_initializes_background_state_for_all_planets_and_moons(ctx)
	_test_resident_and_offscreen_read_same_state_for_same_body(ctx)


static func _test_sample_system_high_track_becomes_microbial_after_four_ticks(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var time_service: Node = setup[SimTestHarnessScript.HARNESS_KEY_TIME_SERVICE]
	var service = setup[SimTestHarnessScript.HARNESS_KEY_PROTO_BIOSPHERE_SERVICE]

	var initial_desc: Dictionary = service.describe_body(&"planet_a")
	ctx.assert_true(
		ProtoBiosphereSimulationServiceScript.to_string_stage(int(
			initial_desc.get("biosphere_stage", -1)
		)) == "PREBIOTIC",
		"sample_system.planet_a startet bewusst nur prebiotisch"
	)
	ctx.assert_true(
		LifePotentialServiceScript.to_string_track(int(initial_desc.get("dominant_track_id", -1))) == "WATER_CARBON",
		"sample_system.planet_a startet auf dem erwarteten WATER_CARBON-Pfad"
	)
	for _tick in range(4):
		time_service._emit_tick(ProtoBiosphereSimulationServiceScript.BIO_TICK_STEP_S)
	var advanced_desc: Dictionary = service.describe_body(&"planet_a")
	ctx.assert_true(
		ProtoBiosphereSimulationServiceScript.to_string_stage(int(
			advanced_desc.get("biosphere_stage", -1)
		)) == "MICROBIAL",
		"ein HIGH-Track erreicht nach vier Bio-Ticks den MICROBIAL-Cap"
	)
	SimTestHarnessScript.teardown_context(setup)


static func _test_starter_world_anchors_start_with_expected_tracks(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"starter_world")
	var service = setup[SimTestHarnessScript.HARNESS_KEY_PROTO_BIOSPHERE_SERVICE]

	var gamma_iv_desc: Dictionary = service.describe_body(&"gamma_iv")
	ctx.assert_true(
		ProtoBiosphereSimulationServiceScript.to_string_stage(int(
			gamma_iv_desc.get("biosphere_stage", -1)
		)) == "PREBIOTIC",
		"starter_world.gamma_iv startet als PREBIOTIC"
	)
	ctx.assert_true(
		LifePotentialServiceScript.to_string_track(int(gamma_iv_desc.get("dominant_track_id", -1))) == "WATER_CARBON",
		"starter_world.gamma_iv bleibt WATER_CARBON-dominiert"
	)
	ctx.assert_true(
		LifePotentialServiceScript.to_string_track(int(
			service.describe_body(&"alpha_iii").get("dominant_track_id", -1)
		)) == "SULFUR_REACTIVE",
		"starter_world.alpha_iii bleibt sulfur-dominiert"
	)
	ctx.assert_true(
		LifePotentialServiceScript.to_string_track(int(
			service.describe_body(&"gamma_iii").get("dominant_track_id", -1)
		)) == "CRYOGENIC_SOLVENT",
		"starter_world.gamma_iii bleibt cryogenic-dominiert"
	)
	SimTestHarnessScript.teardown_context(setup)


static func _test_scaleup_galaxy_100_initializes_background_state_for_all_planets_and_moons(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var time_service: Node = load("res://src/core/time/time_service.gd").new()
	var galaxy = loader.load_named_galaxy(WorldLoaderScript.SCALEUP_GALAXY_100_ID)
	ctx.assert_true(galaxy != null, "scaleup_galaxy_100 laesst sich fuer den Background-State laden")
	var loaded: bool = loader.load_named_world(WorldLoaderScript.SCALEUP_GALAXY_100_ID, registry)
	ctx.assert_true(loaded, "scaleup_galaxy_100 materialisiert den Default-Resident-Slice sauber")

	var service = ProtoBiosphereSimulationServiceScript.new()
	service.configure(registry, time_service, loader)
	service.initialize_for_galaxy(galaxy)

	var defs: Array[BodyDef] = loader.build_defs_for_root_ids(galaxy, galaxy.root_ids(), galaxy.galaxy_id)
	var expected_planetary_body_count: int = 0
	for def in defs:
		if def != null and (def.kind == BodyType.Kind.PLANET or def.kind == BodyType.Kind.MOON):
			expected_planetary_body_count += 1
	ctx.assert_true(
		int(service.get_debug_snapshot().get("tracked_life_body_count", -1)) == expected_planetary_body_count,
		"scaleup_galaxy_100 initialisiert Background-State fuer alle PLANET-/MOON-Bodies der Galaxy"
	)

	service.free()
	time_service.free()
	registry.free()
	loader.free()


static func _test_resident_and_offscreen_read_same_state_for_same_body(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var time_service: Node = load("res://src/core/time/time_service.gd").new()
	var galaxy = loader.load_named_galaxy(WorldLoaderScript.SCALEUP_GALAXY_100_ID)
	var loaded: bool = loader.load_named_world(WorldLoaderScript.SCALEUP_GALAXY_100_ID, registry)
	ctx.assert_true(loaded, "scaleup_galaxy_100 materialisiert den Default-Resident-Slice fuer den Resident/Offscreen-Test")

	var service = ProtoBiosphereSimulationServiceScript.new()
	service.configure(registry, time_service, loader)
	service.initialize_for_galaxy(galaxy)

	var offscreen_root_id: StringName = StringName("")
	for root_id in galaxy.root_ids():
		if not galaxy.default_resident_root_ids.has(root_id):
			offscreen_root_id = root_id
			break
	ctx.assert_true(offscreen_root_id != StringName(""), "scaleup_galaxy_100 enthaelt mindestens einen initial nichtresidenten Root")
	var offscreen_defs: Array[BodyDef] = loader.build_defs_for_root_ids(galaxy, [offscreen_root_id], galaxy.galaxy_id)
	var offscreen_body_id: StringName = _first_planetary_body_id(offscreen_defs)
	ctx.assert_true(offscreen_body_id != StringName(""), "der initial nichtresidente Root liefert mindestens einen planetaren Body")

	var before_materialize_desc: Dictionary = service.describe_body(offscreen_body_id)
	var next_resident_root_ids: Array[StringName] = []
	next_resident_root_ids.append_array(galaxy.default_resident_root_ids)
	next_resident_root_ids.append(offscreen_root_id)
	loader.materialize_galaxy_roots(galaxy, next_resident_root_ids, registry, galaxy.galaxy_id)
	var after_materialize_desc: Dictionary = service.describe_body(offscreen_body_id)
	ctx.assert_true(
		before_materialize_desc == after_materialize_desc,
		"resident und offscreen liefern fuer denselben Body bei gleichem sim_time_s denselben Life-Zustand"
	)

	service.free()
	time_service.free()
	registry.free()
	loader.free()


static func _first_planetary_body_id(defs: Array[BodyDef]) -> StringName:
	for def in defs:
		if def != null and (def.kind == BodyType.Kind.PLANET or def.kind == BodyType.Kind.MOON):
			return def.id
	return StringName("")
