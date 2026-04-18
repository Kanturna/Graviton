extends RefCounted

const AtmosphereServiceScript = preload("res://src/sim/atmosphere/atmosphere_service.gd")
const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")


class AtmosphereStub:
	extends Node

	var _desc_by_id: Dictionary = {}

	func set_description(
		id: StringName,
		south_midlatitude_surface_temperature_k: float,
		equator_surface_temperature_k: float,
		north_midlatitude_surface_temperature_k: float,
		source_id: StringName = &"sol",
		has_luminous_ancestor: bool = true,
		has_latitudinal_surface_basis: bool = true,
		equilibrium_temperature_k: float = -1.0,
		greenhouse_delta_k: float = 0.0,
		surface_temperature_k: float = -1.0
	) -> void:
		var resolved_surface_temperature_k: float = surface_temperature_k
		if resolved_surface_temperature_k < 0.0:
			resolved_surface_temperature_k = equator_surface_temperature_k
		var resolved_equilibrium_temperature_k: float = equilibrium_temperature_k
		if resolved_equilibrium_temperature_k < 0.0:
			resolved_equilibrium_temperature_k = resolved_surface_temperature_k
		_desc_by_id[id] = {
			"body_id": id,
			"source_id": source_id,
			"equilibrium_temperature_k": resolved_equilibrium_temperature_k,
			"greenhouse_delta_k": greenhouse_delta_k,
			"surface_temperature_k": resolved_surface_temperature_k,
			"has_latitudinal_surface_basis": has_latitudinal_surface_basis,
			"south_midlatitude_surface_temperature_k": south_midlatitude_surface_temperature_k,
			"equator_surface_temperature_k": equator_surface_temperature_k,
			"north_midlatitude_surface_temperature_k": north_midlatitude_surface_temperature_k,
			"has_luminous_ancestor": has_luminous_ancestor,
		}

	func describe_body(id: StringName) -> Dictionary:
		if _desc_by_id.has(id):
			return _desc_by_id[id]
		return {
			"body_id": id,
			"source_id": StringName(""),
			"equilibrium_temperature_k": 0.0,
			"greenhouse_delta_k": 0.0,
			"surface_temperature_k": 0.0,
			"has_latitudinal_surface_basis": false,
			"south_midlatitude_surface_temperature_k": 0.0,
			"equator_surface_temperature_k": 0.0,
			"north_midlatitude_surface_temperature_k": 0.0,
			"has_luminous_ancestor": false,
		}


static func run(ctx) -> void:
	ctx.current_suite = "test_environment_service"
	_test_sample_system_planet_a_is_habitable_and_seasonal(ctx)
	_test_sample_system_moon_a_is_supported_and_band_aware(ctx)
	_test_starter_world_gamma_iv_is_compact_habitable_candidate_at_t0(ctx)
	_test_sample_system_sol_is_unsupported(ctx)
	_test_supported_body_without_luminous_ancestor_is_hostile(ctx)
	_test_describe_and_classify_stay_consistent(ctx)
	_test_class_and_ecosystem_matrix(ctx)
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


static func _make_environment_service(registry: Node, atmosphere_service: Node):
	var service = EnvironmentServiceScript.new()
	service.configure(registry, atmosphere_service)
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
	var environment_service = _make_environment_service(registry, atmosphere_service)
	return {
		"loader": loader,
		"registry": registry,
		"time_service": time_service,
		"orbit_service": orbit_service,
		"thermal_service": thermal_service,
		"atmosphere_service": atmosphere_service,
		"environment_service": environment_service,
	}


static func _cleanup_setup(setup: Dictionary) -> void:
	var environment_service = setup.get("environment_service", null)
	if environment_service != null:
		environment_service.free()
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


static func _test_sample_system_planet_a_is_habitable_and_seasonal(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var environment_service = setup["environment_service"]
	var desc: Dictionary = environment_service.describe_body(&"planet_a")
	ctx.assert_true(bool(desc.get("is_supported_body_kind", false)), "planet_a ist ein unterstuetzter Umweltkoerper")
	ctx.assert_true(bool(desc.get("has_latitudinal_surface_basis", false)), "planet_a hat latitudinale Umweltbasis")
	ctx.assert_true(bool(desc.get("has_habitable_band", false)), "planet_a hat mindestens ein habitales Band")
	ctx.assert_true(bool(desc.get("has_liquid_water_band", false)), "planet_a hat mindestens ein Band im Fluessigwasserfenster")
	_assert_class_eq(
		ctx,
		environment_service.classify(&"planet_a"),
		EnvironmentServiceScript.Class.HABITABLE,
		"planet_a bleibt ueber seine Bandtemperaturen HABITABLE"
	)
	_assert_ecosystem_eq(
		ctx,
		int(desc.get("ecosystem_type", -1)),
		EnvironmentServiceScript.EcosystemType.SEASONAL_WORLD,
		"planet_a wird ohne Waermetransport bewusst als SEASONAL_WORLD eingeordnet"
	)
	ctx.assert_true(
		float(desc.get("south_midlatitude_surface_temperature_k", 0.0))
			!= float(desc.get("north_midlatitude_surface_temperature_k", 0.0)),
		"planet_a zeigt unterschiedliche midlatitude-Baender"
	)
	_cleanup_setup(setup)


static func _test_sample_system_moon_a_is_supported_and_band_aware(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var environment_service = setup["environment_service"]
	var desc: Dictionary = environment_service.describe_body(&"moon_a")
	ctx.assert_true(bool(desc.get("is_supported_body_kind", false)), "moon_a bleibt ein unterstuetzter Umweltkoerper")
	ctx.assert_true(bool(desc.get("has_latitudinal_surface_basis", false)), "moon_a hat eine latitudinale Umweltbasis")
	ctx.assert_true(desc.get("source_id", StringName("")) == &"sol", "moon_a sieht weiter sol als Quelle")
	ctx.assert_true(
		int(desc.get("environment_class", -1)) == environment_service.classify(&"moon_a"),
		"moon_a describe_body und classify bleiben konsistent"
	)
	ctx.assert_true(
		float(desc.get("equator_surface_temperature_k", 0.0)) > 0.0,
		"moon_a meldet eine endliche aequatoriale Bandtemperatur"
	)
	_cleanup_setup(setup)


static func _test_starter_world_gamma_iv_is_compact_habitable_candidate_at_t0(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"starter_world")
	var environment_service = setup["environment_service"]
	var desc: Dictionary = environment_service.describe_body(&"gamma_iv")
	ctx.assert_true(bool(desc.get("is_supported_body_kind", false)), "gamma_iv bleibt ein unterstuetzter Umweltkoerper")
	ctx.assert_true(bool(desc.get("has_latitudinal_surface_basis", false)), "gamma_iv hat eine latitudinale Umweltbasis")
	ctx.assert_true(bool(desc.get("has_habitable_band", false)), "gamma_iv hat mindestens ein habitales Band")
	ctx.assert_true(bool(desc.get("has_liquid_water_band", false)), "gamma_iv hat mindestens ein Fluessigwasser-Band")
	_assert_class_eq(
		ctx,
		environment_service.classify(&"gamma_iv"),
		EnvironmentServiceScript.Class.HABITABLE,
		"gamma_iv ist bei t = 0.0 der kompakte habitabele Kandidat der StarterWorld"
	)
	_assert_ecosystem_eq(
		ctx,
		int(desc.get("ecosystem_type", -1)),
		EnvironmentServiceScript.EcosystemType.SEASONAL_WORLD,
		"gamma_iv bleibt bei t = 0.0 bewusst ein SEASONAL_WORLD"
	)
	_cleanup_setup(setup)


static func _test_sample_system_sol_is_unsupported(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var environment_service = setup["environment_service"]
	var desc: Dictionary = environment_service.describe_body(&"sol")
	ctx.assert_true(not bool(desc.get("is_supported_body_kind", true)), "sol ist kein unterstuetzter Umweltkoerper")
	ctx.assert_true(not bool(desc.get("has_habitable_band", true)), "unsupported bodies melden kein habitales Band")
	ctx.assert_true(not bool(desc.get("has_liquid_water_band", true)), "unsupported bodies melden kein Fluessigwasser-Band")
	_cleanup_setup(setup)


static func _test_supported_body_without_luminous_ancestor_is_hostile(ctx) -> void:
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
	var environment_service = _make_environment_service(registry, atmosphere_service)
	var desc: Dictionary = environment_service.describe_body(&"dark_planet")
	ctx.assert_true(bool(desc.get("is_supported_body_kind", false)), "dark_planet bleibt ein unterstuetzter Umweltkoerper")
	ctx.assert_true(not bool(desc.get("has_luminous_ancestor", true)), "dark_planet hat keinen luminous ancestor")
	ctx.assert_true(not bool(desc.get("has_latitudinal_surface_basis", true)), "dark_planet hat keine latitudinale Umweltbasis")
	ctx.assert_true(not bool(desc.get("has_habitable_band", true)), "dark_planet hat ohne Quelle kein habitales Band")
	ctx.assert_true(not bool(desc.get("has_liquid_water_band", true)), "dark_planet hat ohne Quelle kein Fluessigwasser-Band")
	_assert_class_eq(
		ctx,
		int(desc.get("environment_class", -1)),
		EnvironmentServiceScript.Class.HOSTILE,
		"dark_planet wird ohne leuchtenden Ancestor als HOSTILE klassifiziert"
	)
	_assert_ecosystem_eq(
		ctx,
		int(desc.get("ecosystem_type", -1)),
		EnvironmentServiceScript.EcosystemType.FROZEN_WORLD,
		"dark_planet faellt im Default-Pfad auf FROZEN_WORLD zurueck"
	)
	environment_service.free()
	atmosphere_service.free()
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


static func _test_class_and_ecosystem_matrix(ctx) -> void:
	var registry := _make_registry()
	registry.register_body(_root_def(&"sol", UnitSystem.SOLAR_LUMINOSITY_W))
	registry.register_body(_planet_def(&"planet_a", &"sol", 1.0e9))

	var atmosphere_stub := AtmosphereStub.new()
	var environment_service = _make_environment_service(registry, atmosphere_stub)
	var cases: Array[Dictionary] = [
		{
			"label": "FROZEN_WORLD + HOSTILE",
			"bands": [180.0, 190.0, 200.0],
			"class": EnvironmentServiceScript.Class.HOSTILE,
			"ecosystem": EnvironmentServiceScript.EcosystemType.FROZEN_WORLD,
			"has_habitable_band": false,
			"has_liquid_water_band": false,
		},
		{
			"label": "FROZEN_WORLD + MARGINAL",
			"bands": [250.0, 260.0, 270.0],
			"class": EnvironmentServiceScript.Class.MARGINAL,
			"ecosystem": EnvironmentServiceScript.EcosystemType.FROZEN_WORLD,
			"has_habitable_band": false,
			"has_liquid_water_band": false,
		},
		{
			"label": "TEMPERATE_WORLD + HABITABLE",
			"bands": [280.0, 290.0, 300.0],
			"class": EnvironmentServiceScript.Class.HABITABLE,
			"ecosystem": EnvironmentServiceScript.EcosystemType.TEMPERATE_WORLD,
			"has_habitable_band": true,
			"has_liquid_water_band": true,
		},
		{
			"label": "HOT_WORLD + MARGINAL",
			"bands": [330.0, 340.0, 350.0],
			"class": EnvironmentServiceScript.Class.MARGINAL,
			"ecosystem": EnvironmentServiceScript.EcosystemType.HOT_WORLD,
			"has_habitable_band": false,
			"has_liquid_water_band": true,
		},
		{
			"label": "HOT_WORLD + HOSTILE",
			"bands": [380.0, 390.0, 400.0],
			"class": EnvironmentServiceScript.Class.HOSTILE,
			"ecosystem": EnvironmentServiceScript.EcosystemType.HOT_WORLD,
			"has_habitable_band": false,
			"has_liquid_water_band": false,
		},
		{
			"label": "SEASONAL_WORLD + HABITABLE",
			"bands": [250.0, 300.0, 340.0],
			"class": EnvironmentServiceScript.Class.HABITABLE,
			"ecosystem": EnvironmentServiceScript.EcosystemType.SEASONAL_WORLD,
			"has_habitable_band": true,
			"has_liquid_water_band": true,
		},
		{
			"label": "SEASONAL_WORLD + MARGINAL",
			"bands": [240.0, 260.0, 340.0],
			"class": EnvironmentServiceScript.Class.MARGINAL,
			"ecosystem": EnvironmentServiceScript.EcosystemType.SEASONAL_WORLD,
			"has_habitable_band": false,
			"has_liquid_water_band": true,
		},
		{
			"label": "SEASONAL_WORLD + HOSTILE",
			"bands": [180.0, 390.0, 410.0],
			"class": EnvironmentServiceScript.Class.HOSTILE,
			"ecosystem": EnvironmentServiceScript.EcosystemType.SEASONAL_WORLD,
			"has_habitable_band": false,
			"has_liquid_water_band": false,
		},
	]

	for case_data in cases:
		var bands: Array = case_data.get("bands", [])
		atmosphere_stub.set_description(
			&"planet_a",
			float(bands[0]),
			float(bands[1]),
			float(bands[2])
		)
		var desc: Dictionary = environment_service.describe_body(&"planet_a")
		_assert_class_eq(
			ctx,
			environment_service.classify(&"planet_a"),
			int(case_data.get("class", -1)),
			"%s klassifiziert die Banderwartung korrekt" % case_data.get("label", "")
		)
		_assert_ecosystem_eq(
			ctx,
			int(desc.get("ecosystem_type", -1)),
			int(case_data.get("ecosystem", -1)),
			"%s mappt den Oekosystemtyp korrekt" % case_data.get("label", "")
		)
		ctx.assert_true(
			bool(desc.get("has_habitable_band", false)) == bool(case_data.get("has_habitable_band", false)),
			"%s setzt has_habitable_band korrekt" % case_data.get("label", "")
		)
		ctx.assert_true(
			bool(desc.get("has_liquid_water_band", false)) == bool(case_data.get("has_liquid_water_band", false)),
			"%s setzt has_liquid_water_band korrekt" % case_data.get("label", "")
		)

	environment_service.free()
	atmosphere_stub.free()
	registry.free()


static func _test_unknown_id_returns_full_default_shape(ctx) -> void:
	var registry := _make_registry()
	var atmosphere_stub := AtmosphereStub.new()
	var environment_service = _make_environment_service(registry, atmosphere_stub)
	var desc: Dictionary = environment_service.describe_body(&"missing_body")
	ctx.assert_true(desc.has("body_id"), "Default-Shape enthaelt body_id")
	ctx.assert_true(desc.has("source_id"), "Default-Shape enthaelt source_id")
	ctx.assert_true(desc.has("equilibrium_temperature_k"), "Default-Shape enthaelt equilibrium_temperature_k")
	ctx.assert_true(desc.has("greenhouse_delta_k"), "Default-Shape enthaelt greenhouse_delta_k")
	ctx.assert_true(desc.has("surface_temperature_k"), "Default-Shape enthaelt surface_temperature_k")
	ctx.assert_true(desc.has("has_latitudinal_surface_basis"), "Default-Shape enthaelt has_latitudinal_surface_basis")
	ctx.assert_true(desc.has("south_midlatitude_surface_temperature_k"), "Default-Shape enthaelt S60 surface temperature")
	ctx.assert_true(desc.has("equator_surface_temperature_k"), "Default-Shape enthaelt aequatoriale surface temperature")
	ctx.assert_true(desc.has("north_midlatitude_surface_temperature_k"), "Default-Shape enthaelt N60 surface temperature")
	ctx.assert_true(desc.has("environment_class"), "Default-Shape enthaelt environment_class")
	ctx.assert_true(desc.has("ecosystem_type"), "Default-Shape enthaelt ecosystem_type")
	ctx.assert_true(desc.has("is_supported_body_kind"), "Default-Shape enthaelt is_supported_body_kind")
	ctx.assert_true(desc.has("has_habitable_band"), "Default-Shape enthaelt has_habitable_band")
	ctx.assert_true(desc.has("has_liquid_water_band"), "Default-Shape enthaelt has_liquid_water_band")
	ctx.assert_true(desc.has("has_luminous_ancestor"), "Default-Shape enthaelt has_luminous_ancestor")
	ctx.assert_true(desc.get("body_id", StringName("")) == &"missing_body", "Default-Shape behaelt die angefragte body_id")
	ctx.assert_true(desc.get("source_id", StringName("")) == StringName(""), "Default-Shape setzt leere source_id")
	ctx.assert_almost(float(desc.get("equilibrium_temperature_k", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt Gleichgewichtstemperatur auf 0.0")
	ctx.assert_almost(float(desc.get("greenhouse_delta_k", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt greenhouse_delta_k auf 0.0")
	ctx.assert_almost(float(desc.get("surface_temperature_k", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt surface_temperature_k auf 0.0")
	ctx.assert_true(not bool(desc.get("has_latitudinal_surface_basis", true)), "Default-Shape setzt has_latitudinal_surface_basis auf false")
	ctx.assert_almost(float(desc.get("south_midlatitude_surface_temperature_k", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt S60 surface temperature auf 0.0")
	ctx.assert_almost(float(desc.get("equator_surface_temperature_k", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt aequatoriale surface temperature auf 0.0")
	ctx.assert_almost(float(desc.get("north_midlatitude_surface_temperature_k", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt N60 surface temperature auf 0.0")
	_assert_class_eq(ctx, int(desc.get("environment_class", -1)), EnvironmentServiceScript.Class.HOSTILE, "Default-Shape setzt HOSTILE als Fallback")
	_assert_ecosystem_eq(ctx, int(desc.get("ecosystem_type", -1)), EnvironmentServiceScript.EcosystemType.FROZEN_WORLD, "Default-Shape setzt FROZEN_WORLD als Fallback")
	ctx.assert_true(not bool(desc.get("is_supported_body_kind", true)), "Default-Shape setzt is_supported_body_kind auf false")
	ctx.assert_true(not bool(desc.get("has_habitable_band", true)), "Default-Shape setzt has_habitable_band auf false")
	ctx.assert_true(not bool(desc.get("has_liquid_water_band", true)), "Default-Shape setzt has_liquid_water_band auf false")
	ctx.assert_true(not bool(desc.get("has_luminous_ancestor", true)), "Default-Shape setzt has_luminous_ancestor auf false")
	environment_service.free()
	atmosphere_stub.free()
	registry.free()


static func _assert_class_eq(ctx, actual: int, expected: int, label: String) -> void:
	ctx.assert_true(actual == expected, "%s (actual=%s expected=%s)" % [
		label,
		EnvironmentServiceScript.to_string_class(actual),
		EnvironmentServiceScript.to_string_class(expected),
	])


static func _assert_ecosystem_eq(ctx, actual: int, expected: int, label: String) -> void:
	ctx.assert_true(actual == expected, "%s (actual=%s expected=%s)" % [
		label,
		EnvironmentServiceScript.to_string_ecosystem(actual),
		EnvironmentServiceScript.to_string_ecosystem(expected),
	])
