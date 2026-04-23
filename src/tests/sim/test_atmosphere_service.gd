extends RefCounted

const AtmosphereServiceScript = preload("res://src/sim/atmosphere/atmosphere_service.gd")
const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")
const HK_ATMOSPHERE_SERVICE: StringName = SimTestHarnessScript.HARNESS_KEY_ATMOSPHERE_SERVICE


static func run(ctx) -> void:
	ctx.current_suite = "test_atmosphere_service"
	_test_sample_system_planet_a_reports_greenhouse_and_surface_temperature(ctx)
	_test_sample_system_planet_a_reports_latitudinal_surface_temperatures(ctx)
	_test_latitudinal_compute_matches_describe_for_fixed_bands(ctx)
	_test_exact_poles_and_latitude_clamping_work(ctx)
	_test_invalid_latitude_returns_zero(ctx)
	_test_sample_system_moon_a_keeps_zero_greenhouse_and_sol_source(ctx)
	_test_missing_luminous_source_keeps_greenhouse_but_zero_surface_temperature(ctx)
	_test_describe_matches_compute(ctx)
	_test_unknown_id_returns_full_default_shape(ctx)
	_test_pure_surface_helpers_match_live_path(ctx)


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
	return SimTestHarnessScript.build_named_world_context(world_id)


static func _cleanup_setup(setup: Dictionary) -> void:
	SimTestHarnessScript.teardown_context(setup)


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
	var atmosphere_service = setup[HK_ATMOSPHERE_SERVICE]
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


static func _test_sample_system_planet_a_reports_latitudinal_surface_temperatures(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup[HK_ATMOSPHERE_SERVICE]
	var desc: Dictionary = atmosphere_service.describe_body(&"planet_a")
	ctx.assert_true(bool(desc.get("has_latitudinal_surface_basis", false)), "planet_a hat latitudinale surface basis")
	var south_midlatitude_surface_temperature_k: float = float(
		desc.get("south_midlatitude_surface_temperature_k", 0.0)
	)
	var equator_surface_temperature_k: float = float(desc.get("equator_surface_temperature_k", 0.0))
	var north_midlatitude_surface_temperature_k: float = float(
		desc.get("north_midlatitude_surface_temperature_k", 0.0)
	)
	ctx.assert_true(south_midlatitude_surface_temperature_k > 0.0, "planet_a meldet S60 surface temperature")
	ctx.assert_true(equator_surface_temperature_k > 0.0, "planet_a meldet aequatoriale surface temperature")
	ctx.assert_true(north_midlatitude_surface_temperature_k > 0.0, "planet_a meldet N60 surface temperature")
	ctx.assert_true(
		south_midlatitude_surface_temperature_k != equator_surface_temperature_k
			or equator_surface_temperature_k != north_midlatitude_surface_temperature_k,
		"planet_a zeigt bandabhaengige Temperaturunterschiede"
	)
	_cleanup_setup(setup)


static func _test_latitudinal_compute_matches_describe_for_fixed_bands(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup[HK_ATMOSPHERE_SERVICE]
	var desc: Dictionary = atmosphere_service.describe_body(&"planet_a")
	ctx.assert_almost(
		float(desc.get("south_midlatitude_surface_temperature_k", 0.0)),
		atmosphere_service.compute_surface_temperature_at_latitude_k(&"planet_a", -PI / 3.0),
		1.0e-6,
		"S60 compute und describe stimmen ueberein"
	)
	ctx.assert_almost(
		float(desc.get("equator_surface_temperature_k", 0.0)),
		atmosphere_service.compute_surface_temperature_at_latitude_k(&"planet_a", 0.0),
		1.0e-6,
		"Eq compute und describe stimmen ueberein"
	)
	ctx.assert_almost(
		float(desc.get("north_midlatitude_surface_temperature_k", 0.0)),
		atmosphere_service.compute_surface_temperature_at_latitude_k(&"planet_a", PI / 3.0),
		1.0e-6,
		"N60 compute und describe stimmen ueberein"
	)
	_cleanup_setup(setup)


static func _test_exact_poles_and_latitude_clamping_work(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup[HK_ATMOSPHERE_SERVICE]
	var south_pole_surface_temperature_k: float = atmosphere_service.compute_surface_temperature_at_latitude_k(
		&"planet_a",
		-PI * 0.5
	)
	var north_pole_surface_temperature_k: float = atmosphere_service.compute_surface_temperature_at_latitude_k(
		&"planet_a",
		PI * 0.5
	)
	ctx.assert_true(south_pole_surface_temperature_k >= 0.0, "exakter Suedpol liefert finiten Wert")
	ctx.assert_true(north_pole_surface_temperature_k >= 0.0, "exakter Nordpol liefert finiten Wert")
	ctx.assert_almost(
		atmosphere_service.compute_surface_temperature_at_latitude_k(&"planet_a", PI),
		north_pole_surface_temperature_k,
		1.0e-6,
		"Latituden > +PI/2 clampen auf den Nordpol"
	)
	ctx.assert_almost(
		atmosphere_service.compute_surface_temperature_at_latitude_k(&"planet_a", -PI),
		south_pole_surface_temperature_k,
		1.0e-6,
		"Latituden < -PI/2 clampen auf den Suedpol"
	)
	_cleanup_setup(setup)


static func _test_invalid_latitude_returns_zero(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup[HK_ATMOSPHERE_SERVICE]
	ctx.assert_almost(
		atmosphere_service.compute_surface_temperature_at_latitude_k(&"planet_a", NAN),
		0.0,
		1.0e-9,
		"NaN-Latitude liefert 0.0"
	)
	ctx.assert_almost(
		atmosphere_service.compute_surface_temperature_at_latitude_k(&"planet_a", INF),
		0.0,
		1.0e-9,
		"INF-Latitude liefert 0.0"
	)
	_cleanup_setup(setup)


static func _test_sample_system_moon_a_keeps_zero_greenhouse_and_sol_source(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup[HK_ATMOSPHERE_SERVICE]
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
	ctx.assert_true(bool(desc.get("has_latitudinal_surface_basis", false)), "moon_a hat latitudinale surface basis")
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
	ctx.assert_almost(
		atmosphere_service.compute_surface_temperature_at_latitude_k(&"dark_planet", 0.0),
		0.0,
		1.0e-9,
		"ohne thermische Basis bleibt auch die latitudinale Oberflaechentemperatur bei 0.0"
	)
	ctx.assert_true(not bool(desc.get("has_luminous_ancestor", true)), "dark_planet hat keinen luminous ancestor")
	atmosphere_service.free()
	thermal_service.free()
	orbit_service.free()
	time_service.free()
	registry.free()


static func _test_describe_matches_compute(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup[HK_ATMOSPHERE_SERVICE]
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
	ctx.assert_almost(
		float(desc.get("equator_surface_temperature_k", 0.0)),
		atmosphere_service.compute_surface_temperature_at_latitude_k(&"planet_a", 0.0),
		1.0e-6,
		"describe_body und compute_surface_temperature_at_latitude_k liefern denselben aequatorialen Wert"
	)
	_cleanup_setup(setup)


static func _test_unknown_id_returns_full_default_shape(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var atmosphere_service = setup[HK_ATMOSPHERE_SERVICE]
	var desc: Dictionary = atmosphere_service.describe_body(&"missing_body")
	ctx.assert_true(desc.has("body_id"), "Default-Shape enthaelt body_id")
	ctx.assert_true(desc.has("source_id"), "Default-Shape enthaelt source_id")
	ctx.assert_true(desc.has("equilibrium_temperature_k"), "Default-Shape enthaelt equilibrium_temperature_k")
	ctx.assert_true(desc.has("greenhouse_delta_k"), "Default-Shape enthaelt greenhouse_delta_k")
	ctx.assert_true(desc.has("surface_temperature_k"), "Default-Shape enthaelt surface_temperature_k")
	ctx.assert_true(desc.has("has_latitudinal_surface_basis"), "Default-Shape enthaelt has_latitudinal_surface_basis")
	ctx.assert_true(desc.has("south_midlatitude_surface_temperature_k"), "Default-Shape enthaelt S60 surface temperature")
	ctx.assert_true(desc.has("equator_surface_temperature_k"), "Default-Shape enthaelt aequatoriale surface temperature")
	ctx.assert_true(desc.has("north_midlatitude_surface_temperature_k"), "Default-Shape enthaelt N60 surface temperature")
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
	ctx.assert_true(not bool(desc.get("has_luminous_ancestor", true)), "Default-Shape setzt has_luminous_ancestor auf false")
	_cleanup_setup(setup)


static func _test_pure_surface_helpers_match_live_path(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var registry: Node = setup[SimTestHarnessScript.HARNESS_KEY_REGISTRY]
	var thermal_service = setup[SimTestHarnessScript.HARNESS_KEY_THERMAL_SERVICE]
	var atmosphere_service = setup[HK_ATMOSPHERE_SERVICE]
	var planet_def: BodyDef = registry.get_def(&"planet_a")
	var thermal_desc: Dictionary = thermal_service.describe_body(&"planet_a")

	ctx.assert_almost(
		AtmosphereServiceScript.compute_surface_temperature_k_from_equilibrium(
			float(thermal_desc.get("equilibrium_temperature_k", 0.0)),
			planet_def.greenhouse_delta_k
		),
		atmosphere_service.compute_surface_temperature_k(&"planet_a"),
		1.0e-6,
		"pure equilibrium->surface helper bleibt numerisch kompatibel zum Live-Pfad"
	)
	ctx.assert_almost(
		AtmosphereServiceScript.compute_surface_temperature_at_latitude_from_contexts(
			float(thermal_desc.get("insolation_wpm2", 0.0)),
			float(thermal_desc.get("subsolar_latitude_rad", 0.0)),
			0.0,
			planet_def.albedo,
			planet_def.greenhouse_delta_k
		),
		atmosphere_service.compute_surface_temperature_at_latitude_k(&"planet_a", 0.0),
		1.0e-6,
		"pure latitudinale surface helper bleibt numerisch kompatibel zum Live-Pfad"
	)
	_cleanup_setup(setup)
