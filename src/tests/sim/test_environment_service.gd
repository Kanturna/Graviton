extends RefCounted

const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")

class ThermalStub:
	extends Node

	var _desc_by_id: Dictionary = {}

	func set_description(
		id: StringName,
		teq_k: float,
		source_id: StringName = &"sol",
		has_luminous_ancestor: bool = true
	) -> void:
		_desc_by_id[id] = {
			"body_id": id,
			"source_id": source_id,
			"equilibrium_temperature_k": teq_k,
			"has_luminous_ancestor": has_luminous_ancestor,
		}

	func describe_body(id: StringName) -> Dictionary:
		if _desc_by_id.has(id):
			return _desc_by_id[id]
		return {
			"body_id": id,
			"source_id": StringName(""),
			"equilibrium_temperature_k": 0.0,
			"has_luminous_ancestor": false,
		}


static func run(ctx) -> void:
	ctx.current_suite = "test_environment_service"
	_test_sample_system_planet_a_is_marginal(ctx)
	_test_sample_system_moon_a_is_supported_and_habitable(ctx)
	_test_sample_system_sol_is_unsupported(ctx)
	_test_supported_body_without_luminous_ancestor_is_hostile(ctx)
	_test_describe_and_classify_stay_consistent(ctx)
	_test_boundary_temperatures_are_pinned(ctx)
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


static func _make_environment_service(registry: Node, thermal_service: Node):
	var service = EnvironmentServiceScript.new()
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
	var environment_service = _make_environment_service(registry, thermal_service)
	return {
		"loader": loader,
		"registry": registry,
		"time_service": time_service,
		"orbit_service": orbit_service,
		"thermal_service": thermal_service,
		"environment_service": environment_service,
	}


static func _cleanup_setup(setup: Dictionary) -> void:
	var environment_service = setup.get("environment_service", null)
	if environment_service != null:
		environment_service.free()
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


static func _planet_def(id: StringName, parent: StringName, semi_major_axis_m: float) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.PLANET
	def.mass_kg = UnitSystem.EARTH_MASS_KG
	def.radius_m = 6.371e6
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


static func _test_sample_system_planet_a_is_marginal(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var environment_service = setup["environment_service"]
	var desc: Dictionary = environment_service.describe_body(&"planet_a")
	ctx.assert_true(bool(desc.get("is_supported_body_kind", false)), "planet_a ist ein unterstuetzter Umweltkoerper")
	_assert_class_eq(
		ctx,
		environment_service.classify(&"planet_a"),
		EnvironmentServiceScript.Class.MARGINAL,
		"planet_a wird bei ~257 K als MARGINAL klassifiziert"
	)
	_cleanup_setup(setup)


static func _test_sample_system_moon_a_is_supported_and_habitable(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var environment_service = setup["environment_service"]
	var desc: Dictionary = environment_service.describe_body(&"moon_a")
	ctx.assert_true(bool(desc.get("is_supported_body_kind", false)), "moon_a ist ein unterstuetzter Umweltkoerper")
	ctx.assert_true(desc.get("source_id", StringName("")) == &"sol", "moon_a sieht weiter sol als Quelle")
	ctx.assert_true(bool(desc.get("has_luminous_ancestor", false)), "moon_a behaelt einen luminous ancestor")
	_assert_class_eq(
		ctx,
		environment_service.classify(&"moon_a"),
		EnvironmentServiceScript.Class.HABITABLE,
		"moon_a wird bei seiner aktuellen Thermalbasis als HABITABLE klassifiziert"
	)
	_cleanup_setup(setup)


static func _test_sample_system_sol_is_unsupported(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var environment_service = setup["environment_service"]
	var desc: Dictionary = environment_service.describe_body(&"sol")
	ctx.assert_true(not bool(desc.get("is_supported_body_kind", true)), "sol ist kein unterstuetzter Umweltkoerper")
	_cleanup_setup(setup)


static func _test_supported_body_without_luminous_ancestor_is_hostile(ctx) -> void:
	var registry := _make_registry()
	var time_service := _make_time_service()
	var orbit_service = _make_orbit_service(registry, time_service)
	for def in [
		_root_def(&"dark_root", 0.0),
		_planet_def(&"dark_planet", &"dark_root", 1.0e9),
	]:
		registry.register_body(def)
	orbit_service.recompute_all_at_time(0.0)
	var thermal_service = _make_thermal_service(registry)
	var environment_service = _make_environment_service(registry, thermal_service)
	var desc: Dictionary = environment_service.describe_body(&"dark_planet")
	ctx.assert_true(bool(desc.get("is_supported_body_kind", false)), "dark_planet bleibt ein unterstuetzter Umweltkoerper")
	ctx.assert_true(not bool(desc.get("has_luminous_ancestor", true)), "dark_planet hat keinen luminous ancestor")
	_assert_class_eq(
		ctx,
		int(desc.get("environment_class", -1)),
		EnvironmentServiceScript.Class.HOSTILE,
		"dark_planet wird ohne leuchtenden Ancestor als HOSTILE klassifiziert"
	)
	environment_service.free()
	thermal_service.free()
	orbit_service.free()
	time_service.free()
	registry.free()


static func _test_describe_and_classify_stay_consistent(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var environment_service = setup["environment_service"]
	var desc: Dictionary = environment_service.describe_body(&"planet_a")
	_assert_class_eq(
		ctx,
		int(desc.get("environment_class", -1)),
		environment_service.classify(&"planet_a"),
		"describe_body und classify bleiben fuer planet_a konsistent"
	)
	_cleanup_setup(setup)


static func _test_boundary_temperatures_are_pinned(ctx) -> void:
	var registry := _make_registry()
	registry.register_body(_root_def(&"sol", UnitSystem.SOLAR_LUMINOSITY_W))
	registry.register_body(_planet_def(&"planet_a", &"sol", 1.0e9))
	registry.register_body(_planet_def(&"moon_a", &"sol", 1.5e9))

	var thermal_stub := ThermalStub.new()
	var environment_service = _make_environment_service(registry, thermal_stub)

	thermal_stub.set_description(&"planet_a", 273.15)
	_assert_class_eq(ctx, environment_service.classify(&"planet_a"), EnvironmentServiceScript.Class.HABITABLE, "273.15 K ist HABITABLE")
	thermal_stub.set_description(&"planet_a", 273.14)
	_assert_class_eq(ctx, environment_service.classify(&"planet_a"), EnvironmentServiceScript.Class.MARGINAL, "273.14 K ist MARGINAL")
	thermal_stub.set_description(&"planet_a", 323.15)
	_assert_class_eq(ctx, environment_service.classify(&"planet_a"), EnvironmentServiceScript.Class.HABITABLE, "323.15 K ist HABITABLE")
	thermal_stub.set_description(&"planet_a", 323.16)
	_assert_class_eq(ctx, environment_service.classify(&"planet_a"), EnvironmentServiceScript.Class.MARGINAL, "323.16 K ist MARGINAL")
	thermal_stub.set_description(&"planet_a", 223.15)
	_assert_class_eq(ctx, environment_service.classify(&"planet_a"), EnvironmentServiceScript.Class.MARGINAL, "223.15 K ist MARGINAL")
	thermal_stub.set_description(&"planet_a", 223.14)
	_assert_class_eq(ctx, environment_service.classify(&"planet_a"), EnvironmentServiceScript.Class.HOSTILE, "223.14 K ist HOSTILE")
	thermal_stub.set_description(&"planet_a", 373.15)
	_assert_class_eq(ctx, environment_service.classify(&"planet_a"), EnvironmentServiceScript.Class.MARGINAL, "373.15 K ist MARGINAL")
	thermal_stub.set_description(&"planet_a", 373.16)
	_assert_class_eq(ctx, environment_service.classify(&"planet_a"), EnvironmentServiceScript.Class.HOSTILE, "373.16 K ist HOSTILE")

	environment_service.free()
	thermal_stub.free()
	registry.free()


static func _test_unknown_id_returns_full_default_shape(ctx) -> void:
	var registry := _make_registry()
	var thermal_stub := ThermalStub.new()
	var environment_service = _make_environment_service(registry, thermal_stub)
	var desc: Dictionary = environment_service.describe_body(&"missing_body")
	ctx.assert_true(desc.has("body_id"), "Default-Shape enthaelt body_id")
	ctx.assert_true(desc.has("source_id"), "Default-Shape enthaelt source_id")
	ctx.assert_true(desc.has("equilibrium_temperature_k"), "Default-Shape enthaelt equilibrium_temperature_k")
	ctx.assert_true(desc.has("environment_class"), "Default-Shape enthaelt environment_class")
	ctx.assert_true(desc.has("is_supported_body_kind"), "Default-Shape enthaelt is_supported_body_kind")
	ctx.assert_true(desc.has("has_luminous_ancestor"), "Default-Shape enthaelt has_luminous_ancestor")
	ctx.assert_true(desc.get("body_id", StringName("")) == &"missing_body", "Default-Shape behaelt die angefragte body_id")
	ctx.assert_true(desc.get("source_id", StringName("")) == StringName(""), "Default-Shape setzt leere source_id")
	ctx.assert_almost(float(desc.get("equilibrium_temperature_k", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt Gleichgewichtstemperatur auf 0.0")
	_assert_class_eq(ctx, int(desc.get("environment_class", -1)), EnvironmentServiceScript.Class.HOSTILE, "Default-Shape setzt HOSTILE als Fallback")
	ctx.assert_true(not bool(desc.get("is_supported_body_kind", true)), "Default-Shape setzt is_supported_body_kind auf false")
	ctx.assert_true(not bool(desc.get("has_luminous_ancestor", true)), "Default-Shape setzt has_luminous_ancestor auf false")
	environment_service.free()
	thermal_stub.free()
	registry.free()


static func _assert_class_eq(ctx, actual: int, expected: int, label: String) -> void:
	ctx.assert_true(actual == expected, "%s (actual=%s expected=%s)" % [
		label,
		EnvironmentServiceScript.to_string_class(actual),
		EnvironmentServiceScript.to_string_class(expected),
	])
