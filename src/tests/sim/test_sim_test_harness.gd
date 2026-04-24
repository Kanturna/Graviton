extends RefCounted


const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_sim_test_harness"
	_test_sample_system_context_is_fully_built_and_tears_down(ctx)
	_test_starter_world_context_is_fully_built_and_tears_down(ctx)


static func _test_sample_system_context_is_fully_built_and_tears_down(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var registry: Node = setup[SimTestHarnessScript.HARNESS_KEY_REGISTRY]
	var thermal_service = setup[SimTestHarnessScript.HARNESS_KEY_THERMAL_SERVICE]
	var atmosphere_service = setup[SimTestHarnessScript.HARNESS_KEY_ATMOSPHERE_SERVICE]
	var environment_service = setup[SimTestHarnessScript.HARNESS_KEY_ENVIRONMENT_SERVICE]
	var life_potential_service = setup[SimTestHarnessScript.HARNESS_KEY_LIFE_POTENTIAL_SERVICE]
	var proto_biosphere_service = setup[SimTestHarnessScript.HARNESS_KEY_PROTO_BIOSPHERE_SERVICE]
	var native_species_service = setup[SimTestHarnessScript.HARNESS_KEY_NATIVE_SPECIES_SERVICE]
	var genetic_species_service = setup[SimTestHarnessScript.HARNESS_KEY_GENETIC_SPECIES_SERVICE]
	var life_ecology_service = setup[SimTestHarnessScript.HARNESS_KEY_LIFE_ECOLOGY_SERVICE]
	var orbit_readout_service = setup[SimTestHarnessScript.HARNESS_KEY_ORBIT_READOUT_SERVICE]
	ctx.assert_true(registry.has_body(&"sol"), "sample_system context enthaelt sol")
	ctx.assert_true(registry.has_body(&"planet_a"), "sample_system context enthaelt planet_a")
	ctx.assert_true(thermal_service.compute_insolation_wpm2(&"planet_a") > 0.0, "thermal_service ist fuer sample_system fertig konfiguriert")
	ctx.assert_true(atmosphere_service.compute_surface_temperature_k(&"planet_a") > 0.0, "atmosphere_service ist fuer sample_system fertig konfiguriert")
	ctx.assert_true(bool(environment_service.describe_body(&"planet_a").get("is_supported_body_kind", false)),
		"environment_service ist fuer sample_system fertig konfiguriert")
	ctx.assert_true(bool(life_potential_service.describe_body(&"planet_a").get("has_life_potential_basis", false)),
		"life_potential_service ist fuer sample_system fertig konfiguriert")
	ctx.assert_true(bool(proto_biosphere_service.describe_body(&"planet_a").get("has_biosphere_basis", false)),
		"proto_biosphere_service ist fuer sample_system fertig konfiguriert")
	ctx.assert_true(bool(native_species_service.describe_body(&"planet_a").get("is_supported_body_kind", false)),
		"native_species_service ist fuer sample_system fertig konfiguriert")
	ctx.assert_true(bool(genetic_species_service.describe_body(&"planet_a").get("is_supported_body_kind", false)),
		"genetic_species_service ist fuer sample_system fertig konfiguriert")
	ctx.assert_true(bool(life_ecology_service.describe_body(&"planet_a").get("is_supported_body_kind", false)),
		"life_ecology_service ist fuer sample_system fertig konfiguriert")
	ctx.assert_true(bool(orbit_readout_service.describe_body(&"planet_a").get("has_orbital_period_basis", false)),
		"orbit_readout_service ist fuer sample_system fertig konfiguriert")
	SimTestHarnessScript.teardown_context(setup)
	ctx.assert_true(not is_instance_valid(registry), "teardown_context free't die sample_system registry")
	ctx.assert_true(not is_instance_valid(environment_service), "teardown_context free't den sample_system environment_service")


static func _test_starter_world_context_is_fully_built_and_tears_down(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"starter_world")
	var registry: Node = setup[SimTestHarnessScript.HARNESS_KEY_REGISTRY]
	var environment_service = setup[SimTestHarnessScript.HARNESS_KEY_ENVIRONMENT_SERVICE]
	var life_potential_service = setup[SimTestHarnessScript.HARNESS_KEY_LIFE_POTENTIAL_SERVICE]
	var proto_biosphere_service = setup[SimTestHarnessScript.HARNESS_KEY_PROTO_BIOSPHERE_SERVICE]
	var native_species_service = setup[SimTestHarnessScript.HARNESS_KEY_NATIVE_SPECIES_SERVICE]
	var genetic_species_service = setup[SimTestHarnessScript.HARNESS_KEY_GENETIC_SPECIES_SERVICE]
	var life_ecology_service = setup[SimTestHarnessScript.HARNESS_KEY_LIFE_ECOLOGY_SERVICE]
	var orbit_readout_service = setup[SimTestHarnessScript.HARNESS_KEY_ORBIT_READOUT_SERVICE]
	ctx.assert_true(registry.body_count() == 18, "starter_world context enthaelt alle 18 Bodies")
	ctx.assert_true(registry.has_body(&"obsidian"), "starter_world context enthaelt obsidian")
	ctx.assert_true(bool(environment_service.describe_body(&"gamma_iv").get("is_supported_body_kind", false)),
		"starter_world environment_service beschreibt gamma_iv")
	ctx.assert_true(bool(life_potential_service.describe_body(&"gamma_iv").get("has_life_potential_basis", false)),
		"starter_world life_potential_service beschreibt gamma_iv")
	ctx.assert_true(bool(proto_biosphere_service.describe_body(&"gamma_iv").get("has_biosphere_basis", false)),
		"starter_world proto_biosphere_service beschreibt gamma_iv")
	ctx.assert_true(bool(native_species_service.describe_body(&"gamma_iv").get("is_supported_body_kind", false)),
		"starter_world native_species_service beschreibt planetare Bodies")
	ctx.assert_true(bool(genetic_species_service.describe_body(&"gamma_iv").get("is_supported_body_kind", false)),
		"starter_world genetic_species_service beschreibt planetare Bodies")
	ctx.assert_true(bool(life_ecology_service.describe_body(&"gamma_iv").get("is_supported_body_kind", false)),
		"starter_world life_ecology_service beschreibt planetare Bodies")
	ctx.assert_true(bool(orbit_readout_service.describe_body(&"alpha").get("has_orbital_period_basis", false)),
		"starter_world orbit_readout_service beschreibt auch Sternorbits")
	SimTestHarnessScript.teardown_context(setup)
	ctx.assert_true(not is_instance_valid(registry), "teardown_context free't die starter_world registry")
	ctx.assert_true(not is_instance_valid(environment_service), "teardown_context free't den starter_world environment_service")
