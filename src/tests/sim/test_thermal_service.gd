extends RefCounted


static func run(ctx) -> void:
	ctx.current_suite = "test_thermal_service"
	_test_sample_system_planet_a_matches_inverse_square_law(ctx)
	_test_sample_system_planet_a_absorbed_flux_and_temperature_match_formula(ctx)
	_test_sample_system_planet_a_temperature_matches_earth_like_sanity(ctx)
	_test_self_is_not_treated_as_source(ctx)
	_test_dark_parent_is_skipped_for_moon_and_keeps_non_zero_thermal_values(ctx)
	_test_starter_world_dark_root_yields_zero_for_root_and_stars(ctx)
	_test_starter_world_relative_planet_insolation_order(ctx)
	_test_starter_world_relative_planet_temperature_order(ctx)
	_test_cross_root_light_does_not_leak(ctx)
	_test_albedo_boundaries_control_absorption_and_temperature(ctx)
	_test_unknown_and_non_finite_paths_return_zero(ctx)
	_test_describe_body_matches_compute_and_reports_source(ctx)
	_test_describe_body_unknown_returns_full_default_shape(ctx)


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


static func _setup_named_world(world_id: StringName) -> Dictionary:
	var loader := _make_loader()
	var registry := _make_registry()
	var time_service := _make_time_service()
	var orbit_service = _make_orbit_service(registry, time_service)
	var loaded: bool = loader.load_named_world(world_id, registry)
	assert(loaded, "test setup failed to load named world '%s'" % world_id)
	orbit_service.recompute_all_at_time(0.0)
	var thermal_service = _make_thermal_service(registry)
	return {
		"loader": loader,
		"registry": registry,
		"time_service": time_service,
		"orbit_service": orbit_service,
		"thermal_service": thermal_service,
	}


static func _cleanup_setup(setup: Dictionary) -> void:
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


static func _test_sample_system_planet_a_matches_inverse_square_law(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var registry: Node = setup["registry"]
	var thermal_service = setup["thermal_service"]
	var sol: BodyDef = registry.get_def(&"sol")
	var planet_state: BodyState = registry.get_state(&"planet_a")
	var radius_m: float = planet_state.position_parent_frame_m.length()
	var expected_wpm2: float = sol.luminosity_w / (4.0 * PI * radius_m * radius_m)
	var actual_wpm2: float = thermal_service.compute_insolation_wpm2(&"planet_a")
	ctx.assert_almost(
		actual_wpm2,
		expected_wpm2,
		maxf(expected_wpm2 * 1.0e-6, 1.0e-9),
		"planet_a folgt im sample_system dem Inverse-Square-Law"
	)
	_cleanup_setup(setup)


static func _test_sample_system_planet_a_absorbed_flux_and_temperature_match_formula(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var registry: Node = setup["registry"]
	var thermal_service = setup["thermal_service"]
	var planet_def: BodyDef = registry.get_def(&"planet_a")
	var insolation_wpm2: float = thermal_service.compute_insolation_wpm2(&"planet_a")
	var expected_absorbed_wpm2: float = _expected_absorbed_flux_wpm2(insolation_wpm2, planet_def.albedo)
	var actual_absorbed_wpm2: float = thermal_service.compute_absorbed_flux_wpm2(&"planet_a")
	ctx.assert_almost(
		actual_absorbed_wpm2,
		expected_absorbed_wpm2,
		maxf(expected_absorbed_wpm2 * 1.0e-6, 1.0e-9),
		"planet_a absorbierter Fluss folgt (1 - albedo) * F / 4"
	)
	var expected_teq_k: float = _expected_equilibrium_temperature_k(expected_absorbed_wpm2)
	var actual_teq_k: float = thermal_service.compute_equilibrium_temperature_k(&"planet_a")
	ctx.assert_almost(
		actual_teq_k,
		expected_teq_k,
		maxf(expected_teq_k * 1.0e-6, 1.0e-9),
		"planet_a Gleichgewichtstemperatur folgt pow(absorbed / sigma, 0.25)"
	)
	_cleanup_setup(setup)


static func _test_sample_system_planet_a_temperature_matches_earth_like_sanity(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var thermal_service = setup["thermal_service"]
	var teq_k: float = thermal_service.compute_equilibrium_temperature_k(&"planet_a")
	ctx.assert_true(
		absf(teq_k - 257.0) <= 10.0,
		"planet_a bleibt am Periapsis innerhalb der Earth-like-Sanity von 257 +/- 10 K"
	)
	_cleanup_setup(setup)


static func _test_self_is_not_treated_as_source(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var thermal_service = setup["thermal_service"]
	ctx.assert_almost(
		thermal_service.compute_insolation_wpm2(&"sol"),
		0.0,
		1.0e-9,
		"sol bestrahlt sich in P6 nicht selbst"
	)
	ctx.assert_almost(
		thermal_service.compute_absorbed_flux_wpm2(&"sol"),
		0.0,
		1.0e-9,
		"sol hat ohne Self-Illumination auch 0.0 absorbierten Fluss"
	)
	ctx.assert_almost(
		thermal_service.compute_equilibrium_temperature_k(&"sol"),
		0.0,
		1.0e-9,
		"sol hat ohne Self-Illumination auch 0.0 Gleichgewichtstemperatur"
	)
	_cleanup_setup(setup)


static func _test_dark_parent_is_skipped_for_moon_and_keeps_non_zero_thermal_values(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var thermal_service = setup["thermal_service"]
	var moon_wpm2: float = thermal_service.compute_insolation_wpm2(&"moon_a")
	var moon_absorbed_wpm2: float = thermal_service.compute_absorbed_flux_wpm2(&"moon_a")
	var moon_teq_k: float = thermal_service.compute_equilibrium_temperature_k(&"moon_a")
	var moon_desc: Dictionary = thermal_service.describe_body(&"moon_a")
	ctx.assert_true(moon_wpm2 > 0.0, "moon_a erhaelt ueber den Stern als Ancestor non-zero Insolation")
	ctx.assert_true(moon_absorbed_wpm2 > 0.0, "moon_a erhaelt ueber den Stern als Ancestor non-zero absorbierten Fluss")
	ctx.assert_true(moon_teq_k > 0.0, "moon_a erhaelt ueber den Stern als Ancestor non-zero Gleichgewichtstemperatur")
	ctx.assert_true(moon_desc.get("source_id", StringName("")) == &"sol", "moon_a nutzt sol statt planet_a als Quelle")
	_cleanup_setup(setup)


static func _test_starter_world_dark_root_yields_zero_for_root_and_stars(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"starter_world")
	var thermal_service = setup["thermal_service"]
	ctx.assert_almost(thermal_service.compute_insolation_wpm2(&"obsidian"), 0.0, 1.0e-9, "obsidian hat keine Insolation")
	ctx.assert_almost(thermal_service.compute_insolation_wpm2(&"alpha"), 0.0, 1.0e-9, "alpha hat unter dunklem Root keine Insolation")
	ctx.assert_almost(thermal_service.compute_insolation_wpm2(&"beta"), 0.0, 1.0e-9, "beta hat unter dunklem Root keine Insolation")
	ctx.assert_almost(thermal_service.compute_absorbed_flux_wpm2(&"obsidian"), 0.0, 1.0e-9, "obsidian hat keinen absorbierten Fluss")
	ctx.assert_almost(thermal_service.compute_absorbed_flux_wpm2(&"alpha"), 0.0, 1.0e-9, "alpha hat unter dunklem Root keinen absorbierten Fluss")
	ctx.assert_almost(thermal_service.compute_absorbed_flux_wpm2(&"beta"), 0.0, 1.0e-9, "beta hat unter dunklem Root keinen absorbierten Fluss")
	ctx.assert_almost(thermal_service.compute_equilibrium_temperature_k(&"obsidian"), 0.0, 1.0e-9, "obsidian hat 0.0 Gleichgewichtstemperatur")
	ctx.assert_almost(thermal_service.compute_equilibrium_temperature_k(&"alpha"), 0.0, 1.0e-9, "alpha hat unter dunklem Root 0.0 Gleichgewichtstemperatur")
	ctx.assert_almost(thermal_service.compute_equilibrium_temperature_k(&"beta"), 0.0, 1.0e-9, "beta hat unter dunklem Root 0.0 Gleichgewichtstemperatur")
	_cleanup_setup(setup)


static func _test_starter_world_relative_planet_insolation_order(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"starter_world")
	var thermal_service = setup["thermal_service"]
	# Die Radienbereiche der jeweiligen Paare ueberlappen in der StarterWorld nicht:
	# alpha_i bleibt stets naeher an alpha als alpha_ii, beta_i stets naeher an beta als beta_ii.
	ctx.assert_true(
		thermal_service.compute_insolation_wpm2(&"alpha_i") > thermal_service.compute_insolation_wpm2(&"alpha_ii"),
		"alpha_i bleibt aufgrund des nicht ueberlappenden Radiusbereichs stets insolationsstaerker als alpha_ii"
	)
	ctx.assert_true(
		thermal_service.compute_insolation_wpm2(&"beta_i") > thermal_service.compute_insolation_wpm2(&"beta_ii"),
		"beta_i bleibt aufgrund des nicht ueberlappenden Radiusbereichs stets insolationsstaerker als beta_ii"
	)
	_cleanup_setup(setup)


static func _test_starter_world_relative_planet_temperature_order(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"starter_world")
	var thermal_service = setup["thermal_service"]
	# Dieselben nicht ueberlappenden Radiusbereiche wie im Insolation-Test
	# halten auch die Gleichgewichtstemperatur-Ordnung robust.
	ctx.assert_true(
		thermal_service.compute_equilibrium_temperature_k(&"alpha_i") > thermal_service.compute_equilibrium_temperature_k(&"alpha_ii"),
		"alpha_i bleibt aufgrund des nicht ueberlappenden Radiusbereichs stets waermer als alpha_ii"
	)
	ctx.assert_true(
		thermal_service.compute_equilibrium_temperature_k(&"beta_i") > thermal_service.compute_equilibrium_temperature_k(&"beta_ii"),
		"beta_i bleibt aufgrund des nicht ueberlappenden Radiusbereichs stets waermer als beta_ii"
	)
	_cleanup_setup(setup)


static func _test_cross_root_light_does_not_leak(ctx) -> void:
	var registry := _make_registry()
	var time_service := _make_time_service()
	var orbit_service = _make_orbit_service(registry, time_service)
	for def in [
		_root_def(&"dark_root", 0.0),
		_planet_def(&"dark_planet", &"dark_root", 1.0e9),
		_root_def(&"bright_root", UnitSystem.SOLAR_LUMINOSITY_W),
		_planet_def(&"bright_planet", &"bright_root", 1.0e9),
	]:
		registry.register_body(def)
	orbit_service.recompute_all_at_time(0.0)
	var thermal_service = _make_thermal_service(registry)
	ctx.assert_almost(
		thermal_service.compute_insolation_wpm2(&"dark_planet"),
		0.0,
		1.0e-9,
		"dark_planet sieht keine Cross-Root-Quelle"
	)
	ctx.assert_almost(
		thermal_service.compute_absorbed_flux_wpm2(&"dark_planet"),
		0.0,
		1.0e-9,
		"dark_planet hat ohne Cross-Root-Quelle 0.0 absorbierten Fluss"
	)
	ctx.assert_almost(
		thermal_service.compute_equilibrium_temperature_k(&"dark_planet"),
		0.0,
		1.0e-9,
		"dark_planet hat ohne Cross-Root-Quelle 0.0 Gleichgewichtstemperatur"
	)
	ctx.assert_true(
		thermal_service.compute_insolation_wpm2(&"bright_planet") > 0.0,
		"bright_planet erhaelt unter luminous root normale Insolation"
	)
	thermal_service.free()
	orbit_service.free()
	time_service.free()
	registry.free()


static func _test_albedo_boundaries_control_absorption_and_temperature(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var registry: Node = setup["registry"]
	var thermal_service = setup["thermal_service"]
	var planet_def: BodyDef = registry.get_def(&"planet_a")
	var insolation_wpm2: float = thermal_service.compute_insolation_wpm2(&"planet_a")
	planet_def.albedo = 0.0
	ctx.assert_almost(
		thermal_service.compute_absorbed_flux_wpm2(&"planet_a"),
		insolation_wpm2 / 4.0,
		maxf(insolation_wpm2 * 1.0e-6, 1.0e-9),
		"albedo 0.0 liefert maximale Absorption von F / 4"
	)
	ctx.assert_true(
		thermal_service.compute_equilibrium_temperature_k(&"planet_a") > 0.0,
		"albedo 0.0 behaelt non-zero Gleichgewichtstemperatur"
	)
	planet_def.albedo = 1.0
	ctx.assert_almost(
		thermal_service.compute_absorbed_flux_wpm2(&"planet_a"),
		0.0,
		1.0e-9,
		"albedo 1.0 reflektiert den kompletten Fluss"
	)
	ctx.assert_almost(
		thermal_service.compute_equilibrium_temperature_k(&"planet_a"),
		0.0,
		1.0e-9,
		"albedo 1.0 fuehrt zu 0.0 Gleichgewichtstemperatur"
	)
	_cleanup_setup(setup)


static func _test_unknown_and_non_finite_paths_return_zero(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var registry: Node = setup["registry"]
	var thermal_service = setup["thermal_service"]
	ctx.assert_almost(
		thermal_service.compute_insolation_wpm2(&"missing_body"),
		0.0,
		1.0e-9,
		"unbekannte ID liefert 0.0 Insolation"
	)
	ctx.assert_almost(
		thermal_service.compute_absorbed_flux_wpm2(&"missing_body"),
		0.0,
		1.0e-9,
		"unbekannte ID liefert 0.0 absorbierten Fluss"
	)
	ctx.assert_almost(
		thermal_service.compute_equilibrium_temperature_k(&"missing_body"),
		0.0,
		1.0e-9,
		"unbekannte ID liefert 0.0 Gleichgewichtstemperatur"
	)
	var planet_state: BodyState = registry.get_state(&"planet_a")
	planet_state.position_parent_frame_m = Vector3(INF, 0.0, 0.0)
	ctx.assert_almost(
		thermal_service.compute_insolation_wpm2(&"planet_a"),
		0.0,
		1.0e-9,
		"nicht-finite Parent-Frame-Kette liefert 0.0 Insolation"
	)
	ctx.assert_almost(
		thermal_service.compute_absorbed_flux_wpm2(&"planet_a"),
		0.0,
		1.0e-9,
		"nicht-finite Parent-Frame-Kette liefert 0.0 absorbierten Fluss"
	)
	ctx.assert_almost(
		thermal_service.compute_equilibrium_temperature_k(&"planet_a"),
		0.0,
		1.0e-9,
		"nicht-finite Parent-Frame-Kette liefert 0.0 Gleichgewichtstemperatur"
	)
	_cleanup_setup(setup)


static func _test_describe_body_matches_compute_and_reports_source(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var registry: Node = setup["registry"]
	var thermal_service = setup["thermal_service"]
	var desc: Dictionary = thermal_service.describe_body(&"planet_a")
	var planet_def: BodyDef = registry.get_def(&"planet_a")
	var computed_wpm2: float = thermal_service.compute_insolation_wpm2(&"planet_a")
	var computed_absorbed_wpm2: float = thermal_service.compute_absorbed_flux_wpm2(&"planet_a")
	var computed_teq_k: float = thermal_service.compute_equilibrium_temperature_k(&"planet_a")
	ctx.assert_true(desc.get("body_id", StringName("")) == &"planet_a", "describe_body setzt body_id")
	ctx.assert_true(desc.get("source_id", StringName("")) == &"sol", "describe_body meldet sol als Quelle fuer planet_a")
	ctx.assert_true(bool(desc.get("has_luminous_ancestor", false)), "describe_body meldet luminous ancestor fuer planet_a")
	ctx.assert_true(float(desc.get("distance_to_source_m", 0.0)) > 0.0, "describe_body meldet positive Distanz")
	ctx.assert_almost(
		float(desc.get("albedo", -1.0)),
		planet_def.albedo,
		1.0e-9,
		"describe_body meldet die Body-Albedo"
	)
	ctx.assert_almost(
		float(desc.get("insolation_wpm2", 0.0)),
		computed_wpm2,
		maxf(computed_wpm2 * 1.0e-9, 1.0e-9),
		"describe_body und compute_insolation_wpm2 liefern denselben Insolation-Wert"
	)
	ctx.assert_almost(
		float(desc.get("absorbed_flux_wpm2", 0.0)),
		computed_absorbed_wpm2,
		maxf(computed_absorbed_wpm2 * 1.0e-9, 1.0e-9),
		"describe_body und compute_absorbed_flux_wpm2 liefern denselben Wert"
	)
	ctx.assert_almost(
		float(desc.get("equilibrium_temperature_k", 0.0)),
		computed_teq_k,
		maxf(computed_teq_k * 1.0e-9, 1.0e-9),
		"describe_body und compute_equilibrium_temperature_k liefern denselben Wert"
	)
	_cleanup_setup(setup)


static func _test_describe_body_unknown_returns_full_default_shape(ctx) -> void:
	var setup: Dictionary = _setup_named_world(&"sample_system")
	var thermal_service = setup["thermal_service"]
	var desc: Dictionary = thermal_service.describe_body(&"missing_body")
	ctx.assert_true(desc.has("body_id"), "Default-Shape enthaelt body_id")
	ctx.assert_true(desc.has("source_id"), "Default-Shape enthaelt source_id")
	ctx.assert_true(desc.has("distance_to_source_m"), "Default-Shape enthaelt distance_to_source_m")
	ctx.assert_true(desc.has("insolation_wpm2"), "Default-Shape enthaelt insolation_wpm2")
	ctx.assert_true(desc.has("albedo"), "Default-Shape enthaelt albedo")
	ctx.assert_true(desc.has("absorbed_flux_wpm2"), "Default-Shape enthaelt absorbed_flux_wpm2")
	ctx.assert_true(desc.has("equilibrium_temperature_k"), "Default-Shape enthaelt equilibrium_temperature_k")
	ctx.assert_true(desc.has("has_luminous_ancestor"), "Default-Shape enthaelt has_luminous_ancestor")
	ctx.assert_true(desc.get("body_id", StringName("")) == &"missing_body", "Default-Shape behaelt die angefragte body_id")
	ctx.assert_true(desc.get("source_id", StringName("")) == StringName(""), "Default-Shape setzt leere source_id")
	ctx.assert_almost(float(desc.get("distance_to_source_m", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt Distanz auf 0.0")
	ctx.assert_almost(float(desc.get("insolation_wpm2", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt Insolation auf 0.0")
	ctx.assert_almost(float(desc.get("albedo", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt Albedo auf 0.0")
	ctx.assert_almost(float(desc.get("absorbed_flux_wpm2", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt absorbierten Fluss auf 0.0")
	ctx.assert_almost(float(desc.get("equilibrium_temperature_k", -1.0)), 0.0, 1.0e-9, "Default-Shape setzt Gleichgewichtstemperatur auf 0.0")
	ctx.assert_true(not bool(desc.get("has_luminous_ancestor", true)), "Default-Shape setzt has_luminous_ancestor auf false")
	_cleanup_setup(setup)


static func _expected_absorbed_flux_wpm2(insolation_wpm2: float, albedo: float) -> float:
	return (1.0 - albedo) * insolation_wpm2 / 4.0


static func _expected_equilibrium_temperature_k(absorbed_flux_wpm2: float) -> float:
	return pow(absorbed_flux_wpm2 / UnitSystem.STEFAN_BOLTZMANN_WPM2K4, 0.25)
