extends RefCounted


const HARNESS_KEY_LOADER: StringName = &"loader"
const HARNESS_KEY_REGISTRY: StringName = &"registry"
const HARNESS_KEY_TIME_SERVICE: StringName = &"time_service"
const HARNESS_KEY_ORBIT_SERVICE: StringName = &"orbit_service"
const HARNESS_KEY_THERMAL_SERVICE: StringName = &"thermal_service"
const HARNESS_KEY_ATMOSPHERE_SERVICE: StringName = &"atmosphere_service"
const HARNESS_KEY_ENVIRONMENT_SERVICE: StringName = &"environment_service"
const HARNESS_KEY_PLANETARY_YEAR_SAMPLER: StringName = &"planetary_year_sampler"
const HARNESS_KEY_PLANETARY_STATE_SERVICE: StringName = &"planetary_state_service"
const HARNESS_KEY_LIFE_POTENTIAL_SERVICE: StringName = &"life_potential_service"
const HARNESS_KEY_PROTO_BIOSPHERE_SERVICE: StringName = &"proto_biosphere_service"
const HARNESS_KEY_BIOSPHERE_SCALE_SERVICE: StringName = &"biosphere_scale_service"
const HARNESS_KEY_NATIVE_SPECIES_SERVICE: StringName = &"native_species_service"
const HARNESS_KEY_GENETIC_SPECIES_SERVICE: StringName = &"genetic_species_service"
const HARNESS_KEY_LIFE_ECOLOGY_SERVICE: StringName = &"life_ecology_service"
const HARNESS_KEY_LIFE_POPULATION_ESTIMATE_SERVICE: StringName = &"life_population_estimate_service"
const HARNESS_KEY_ORBIT_READOUT_SERVICE: StringName = &"orbit_readout_service"


static func build_named_world_context(world_id: StringName) -> Dictionary:
	var loader = load("res://src/sim/world/world_loader.gd").new()
	var registry = load("res://src/sim/universe/universe_registry.gd").new()
	var time_service = load("res://src/core/time/time_service.gd").new()
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	orbit_service.configure(registry, time_service)

	var loaded: bool = loader.load_named_world(world_id, registry)
	assert(loaded, "SimTestHarness: failed to load named world '%s'" % world_id)

	orbit_service.recompute_all_at_time(0.0)

	var thermal_service = load("res://src/sim/thermal/thermal_service.gd").new()
	thermal_service.configure(registry)
	var atmosphere_service = load("res://src/sim/atmosphere/atmosphere_service.gd").new()
	atmosphere_service.configure(registry, thermal_service)
	var environment_service = load("res://src/sim/environment/environment_service.gd").new()
	environment_service.configure(registry, atmosphere_service)
	var planetary_year_sampler = load("res://src/sim/planetary/planetary_year_sampler.gd").new()
	planetary_year_sampler.configure(registry)
	var planetary_state_service = load("res://src/sim/planetary/planetary_state_service.gd").new()
	planetary_state_service.configure(
		registry,
		thermal_service,
		atmosphere_service,
		planetary_year_sampler
	)
	var life_potential_service = load("res://src/sim/life/life_potential_service.gd").new()
	life_potential_service.configure(
		registry,
		planetary_state_service,
		environment_service
	)
	var proto_biosphere_service = load("res://src/sim/life/proto_biosphere_simulation_service.gd").new()
	proto_biosphere_service.configure(
		registry,
		time_service,
		loader
	)
	proto_biosphere_service.initialize_for_named_world(world_id)
	var biosphere_scale_service = load("res://src/sim/life/biosphere_scale_service.gd").new()
	biosphere_scale_service.configure(
		registry,
		planetary_state_service,
		life_potential_service,
		proto_biosphere_service
	)
	var native_species_service = load("res://src/sim/life/native_species_service.gd").new()
	native_species_service.configure(
		registry,
		planetary_state_service,
		life_potential_service,
		biosphere_scale_service
	)
	var genetic_species_service = load("res://src/sim/life/genetic_species_service.gd").new()
	genetic_species_service.configure(
		registry,
		planetary_state_service,
		life_potential_service,
		biosphere_scale_service,
		native_species_service
	)
	var life_ecology_service = load("res://src/sim/life/life_ecology_service.gd").new()
	life_ecology_service.configure(
		registry,
		biosphere_scale_service,
		genetic_species_service
	)
	var life_population_estimate_service = load("res://src/sim/life/life_population_estimate_service.gd").new()
	life_population_estimate_service.configure(
		registry,
		biosphere_scale_service,
		life_ecology_service
	)
	var orbit_readout_service = load("res://src/sim/orbit/orbit_readout_service.gd").new()
	orbit_readout_service.configure(registry)

	return {
		HARNESS_KEY_LOADER: loader,
		HARNESS_KEY_REGISTRY: registry,
		HARNESS_KEY_TIME_SERVICE: time_service,
		HARNESS_KEY_ORBIT_SERVICE: orbit_service,
		HARNESS_KEY_THERMAL_SERVICE: thermal_service,
		HARNESS_KEY_ATMOSPHERE_SERVICE: atmosphere_service,
		HARNESS_KEY_ENVIRONMENT_SERVICE: environment_service,
		HARNESS_KEY_PLANETARY_YEAR_SAMPLER: planetary_year_sampler,
		HARNESS_KEY_PLANETARY_STATE_SERVICE: planetary_state_service,
		HARNESS_KEY_LIFE_POTENTIAL_SERVICE: life_potential_service,
		HARNESS_KEY_PROTO_BIOSPHERE_SERVICE: proto_biosphere_service,
		HARNESS_KEY_BIOSPHERE_SCALE_SERVICE: biosphere_scale_service,
		HARNESS_KEY_NATIVE_SPECIES_SERVICE: native_species_service,
		HARNESS_KEY_GENETIC_SPECIES_SERVICE: genetic_species_service,
		HARNESS_KEY_LIFE_ECOLOGY_SERVICE: life_ecology_service,
		HARNESS_KEY_LIFE_POPULATION_ESTIMATE_SERVICE: life_population_estimate_service,
		HARNESS_KEY_ORBIT_READOUT_SERVICE: orbit_readout_service,
	}


static func teardown_context(ctx: Dictionary) -> void:
	_free_if_present(ctx.get(HARNESS_KEY_PROTO_BIOSPHERE_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_LIFE_POPULATION_ESTIMATE_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_LIFE_ECOLOGY_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_BIOSPHERE_SCALE_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_GENETIC_SPECIES_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_NATIVE_SPECIES_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_ORBIT_READOUT_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_LIFE_POTENTIAL_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_PLANETARY_STATE_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_PLANETARY_YEAR_SAMPLER, null))
	_free_if_present(ctx.get(HARNESS_KEY_ENVIRONMENT_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_ATMOSPHERE_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_THERMAL_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_ORBIT_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_TIME_SERVICE, null))
	_free_if_present(ctx.get(HARNESS_KEY_REGISTRY, null))
	_free_if_present(ctx.get(HARNESS_KEY_LOADER, null))
	ctx.clear()


static func _free_if_present(value) -> void:
	if value != null:
		value.free()
