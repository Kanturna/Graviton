extends RefCounted

const AtmosphereServiceScript = preload("res://src/sim/atmosphere/atmosphere_service.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_atmosphere_service"
	_test_sample_system_planet_a_reports_greenhouse_and_surface_temperature(ctx)
	_test_sample_system_planet_a_matches_earth_like_surface_sanity(ctx)
	_test_sample_system_moon_a_keeps_zero_greenhouse_and_sol_source(ctx)
	_test_missing_luminous_source_keeps_greenhouse_but_zero_surface_temperature(ctx)
	_test_describe_matches_compute(ctx)
	_test_unknown_id_returns_full_default_shape(ctx)


static func _make_loader() -> Node:
	return load("res://src/sim/world/world_loader.gd").new()


static func _make_registry() -> Node:
	return load("res://src/sim/universe/universe_registry.gd").new()


static func _make_time_service() -> Node:
	return load("res://src/core/time/time_service.gd").new()


static func _make_orbit_service(registry: Node, time_service: Node):
	var service = load("res://src/sim/orbit/orbit_service.gd").new()
	service.configure(registry, time_service)
	return service


static func _make_thermal_service(registry: Node):
	var service = load("res://src/sim/thermal/thermal_service.gd").new()
	service.configure(registry)
	return service


static func _make_atmosphere_service(registry: Node, thermal_service: Node):
	var service = AtmosphereServiceScript.new()
	service.configure(registry, thermal_service)
	return service


static func _setup_named_world(world_id: StringName) -> Dictionary:
	var loader := _make_loader()
	var registry := _make_registry()
	var time_service := _make_time_service()
	var orbit_service = _make_orbit_service(registry, time_service)
	var loaded: bool = loader.load_named_world(world_id, registry)
	assert(loaded, "test setup failed to load named world '%s'" % world_id)
	orbit_service.recompute_all_at_time(0.0)
	var thermal_service = _make_thermal_service(registry)
	var atmosphere_service = _make_atmosphere_service(registry, thermal_service)
	return {
		"loader": loader,
		"registry": registry,
		"time_service": time_service,
		"orbit_service": orbit_service,
		"thermal_service": thermal_service,
		"atmosphere_service": atmosphere_service,
	}


static func _cleanup_setup(setup: Dictionary) -> void:
	var atmosphere_service = setup.get("atmosphere_service", null)
	if atmosphere_service != null:
		atmosphere_service.free()
	var thermal_service = setup.get("thermal_service", null)
	if thermal_service != null:
		thermal_service.free()
	var orbit_service = setup.get("orbit_service", null)
	if orbit_service != null:
		orbit_service.free()
	var time_service = setup.get("time_service", null)
	if time_service != null:
		time_service.free()
	var registry = setup.get("registry", null)
	if registry != null:
		registry.free()
	var loader = setup.get("loader", null)
	if loader != null:
		loader.free()


static func _root_def(id: StringName, luminosity_w: float) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.STAR
	def.mass_kg = UnitSystem.SOLAR_MASS_KG
	def.radius_m = 6.957e8
	def.luminosity_w = luminosity_w
	def.parent_id = &""
	def.orbit_profile = null
	return def


static func _planet_def(
	id: StringName,
	parent: StringName,
	semi_major_axis_m: float,
	greenhouse_delta_k: float = 0.0
) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.PLANET
	def.mass_kg = UnitSystem.EARTH_MASS_KG
	def.radius_m = 6.371e6
	def.greenhouse_delta_k = greenhouse_delta_k
	def.parent_id = parent
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.KEPLER_APPROX
	profile.semi_major_axis_m = semi_major_axis_m
	profile.eccentricity = 0.0
	profile.inclination_rad = 0.0
	profile.longitude_ascending_node_rad = 0.0
	profile.argument_periapsis_rad = 0.0
	profile.mean_anomaly_epoch_rad = 0.0
	profile.epoch_s = 0.0
	def.orbit_profile = profile
	return def


static func _test_sample_system_planet_a_reports_greenhouse_and_surface_temperature(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup["atmosphere_service"]
	var desc: Dictionary = atmosphere_service.describe_body(&"planet_a")
	var equilibrium_temperature_k: float = float(desc.get("equilibrium_temperature_k", 0.0))
	var greenhouse_delta_k: float = float(desc.get("greenhouse_delta_k", -1.0))
	var surface_temperature_k: float = float(desc.get("surface_temperature_k", 0.0))
	ctx.assert_almost(greenhouse_delta_k, 31.0, 1.0e-9, "planet_a meldet greenhouse_delta_k = 31.0")
	ctx.assert_almost(
		surface_temperature_k,
		equilibrium_temperature_k + 31.0,
		maxf(surface_temperature_k * 1.0e-6, 1.0e-9),
		"planet_a surface_temperature_k folgt T_eq + greenhouse_delta_k"
	)
	_cleanup_setup(setup)


static func _test_sample_system_planet_a_matches_earth_like_surface_sanity(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup["atmosphere_service"]
	var surface_temperature_k: float = atmosphere_service.compute_surface_temperature_k(&"planet_a")
	ctx.assert_true(
		absf(surface_temperature_k - 288.0) <= 10.0,
		"planet_a bleibt mit Greenhouse innerhalb der Earth-like-Sanity von 288 +/- 10 K"
	)
	_cleanup_setup(setup)


static func _test_sample_system_moon_a_keeps_zero_greenhouse_and_sol_source(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup["atmosphere_service"]
	var desc: Dictionary = atmosphere_service.describe_body(&"moon_a")
	ctx.assert_true(desc.get("source_id", StringName("")) == &"sol", "moon_a behaelt sol als Quelle")
	ctx.assert_true(bool(desc.get("has_luminous_ancestor", false)), "moon_a behaelt luminous ancestor")
	ctx.assert_almost(float(desc.get("greenhouse_delta_k", -1.0)), 0.0, 1.0e-9, "moon_a behaelt greenhouse_delta_k = 0.0")
	ctx.assert_almost(
		float(desc.get("surface_temperature_k", -1.0)),
		float(desc.get("equilibrium_temperature_k", 0.0)),
		maxf(float(desc.get("surface_temperature_k", 0.0)) * 1.0e-6, 1.0e-9),
		"moon_a behaelt bei 0.0 Greenhouse dieselbe Oberflaechentemperatur wie T_eq"
	)
	_cleanup_setup(setup)


static func _test_missing_luminous_source_keeps_greenhouse_but_zero_surface_temperature(ctx) -> void:
	var registry := _make_registry()
	var time_service := _make_time_service()
	var orbit_service = _make_orbit_service(registry, time_service)
	for def in [
		_root_def(&"dark_root", 0.0),
		_planet_def(&"dark_planet", &"dark_root", 1.0e9, 50.0),
	]:
		registry.register_body(def)
	orbit_service.recompute_all_at_time(0.0)
	var thermal_service = _make_thermal_service(registry)
	var atmosphere_service = _make_atmosphere_service(registry, thermal_service)
	var desc: Dictionary = atmosphere_service.describe_body(&"dark_planet")
	ctx.assert_almost(float(desc.get("greenhouse_delta_k", -1.0)), 50.0, 1.0e-9, "dark_planet behaelt den modellierten Greenhouse-Wert")
	ctx.assert_almost(float(desc.get("surface_temperature_k", -1.0)), 0.0, 1.0e-9, "ohne thermische Basis bleibt surface_temperature_k bei 0.0")
	ctx.assert_true(not bool(desc.get("has_luminous_ancestor", true)), "dark_planet hat keinen luminous ancestor")
	atmosphere_service.free()
	thermal_service.free()
	orbit_service.free()
	time_service.free()
	registry.free()


static func _test_describe_matches_compute(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup["atmosphere_service"]
	var desc: Dictionary = atmosphere_service.describe_body(&"planet_a")
	ctx.assert_almost(
		float(desc.get("greenhouse_delta_k", 0.0)),
		atmosphere_service.compute_greenhouse_delta_k(&"planet_a"),
		1.0e-9,
		"describe_body und compute_greenhouse_delta_k liefern denselben Wert"
	)
	ctx.assert_almost(
		float(desc.get("surface_temperature_k", 0.0)),
		atmosphere_service.compute_surface_temperature_k(&"planet_a"),
		maxf(float(desc.get("surface_temperature_k", 0.0)) * 1.0e-9, 1.0e-9),
		"describe_body und compute_surface_temperature_k liefern denselben Wert"
	)
	_cleanup_setup(setup)


static func _test_unknown_id_returns_full_default_shape(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup["atmosphere_service"]
	var desc: Dictionary = atmosphere_service.describe_body(&"missing_body")
	ctx.assert_true(desc.has("body_id"), "Default-Shape enthaelt body_id")
	ctx.assert_true(desc.has("source_id"), "Default-Shape enthaelt source_id")
	ctx.assert_true(desc.has("equilibrium_temperature_k"), "Default-Shape enthaelt equilibrium_temperature_k")
	ctx.assert_true(desc.has("greenhouse_delta_k"), "Default-Shape enthaelt greenhouse_delta_k")
	ctx.assert_true(desc.has("surface_temperature_k"), "Default-Shape enthaelt surface_temperature_k")
	ctx.assert_true(desc.has("has_luminous_ancestor"), "Default-Shape enthaelt has_luminous_ancestor")
	ctx.assert_true(desc.get("body_id", StringName("")) == &"missing_body", "Default-Shape behaelt die angefragte body_id")
	ctx.assert_true(desc.get("source_id", StringName("")) == StringName(""), "Default-Shape setzt leere source_id")
	ctx.assert_almost(float(desc.get("equilibrium_temperature_k", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt Gleichgewichtstemperatur auf 0.0")
	ctx.assert_almost(float(desc.get("greenhouse_delta_k", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt greenhouse_delta_k auf 0.0")
	ctx.assert_almost(float(desc.get("surface_temperature_k", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt surface_temperature_k auf 0.0")
	ctx.assert_true(not bool(desc.get("has_luminous_ancestor", true)), "Default-Shape setzt has_luminous_ancestor auf false")
	_cleanup_setup(setup)
