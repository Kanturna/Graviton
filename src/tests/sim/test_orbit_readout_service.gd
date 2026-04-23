extends RefCounted


const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_readout_service"
	_test_sample_system_planet_a_reads_as_one_day_one_year(ctx)
	_test_service_reports_short_toy_orbits_and_root_without_basis(ctx)
	_test_authored_moon_uses_authored_orbit_period(ctx)


static func _test_sample_system_planet_a_reads_as_one_day_one_year(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var orbit_readout_service = setup[SimTestHarnessScript.HARNESS_KEY_ORBIT_READOUT_SERVICE]
	var desc: Dictionary = orbit_readout_service.describe_body(&"planet_a")
	ctx.assert_true(bool(desc.get("has_rotation_basis", false)), "planet_a hat eine Rotationsbasis")
	ctx.assert_true(bool(desc.get("has_orbital_period_basis", false)), "planet_a hat eine Orbitbasis")
	ctx.assert_almost(
		float(desc.get("rotation_period_s", 0.0)),
		UnitSystem.DAY_S,
		1.0e-6,
		"planet_a liest Day direkt aus rotation_period_s"
	)
	ctx.assert_almost(
		float(desc.get("orbital_period_s", 0.0)),
		UnitSystem.YEAR_S,
		4.0e3,
		"planet_a liest ueber die bestehende Kepler-Periodenlogik als ungefaehr ein Jahr"
	)
	SimTestHarnessScript.teardown_context(setup)


static func _test_service_reports_short_toy_orbits_and_root_without_basis(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"starter_world")
	var orbit_readout_service = setup[SimTestHarnessScript.HARNESS_KEY_ORBIT_READOUT_SERVICE]
	var alpha_desc: Dictionary = orbit_readout_service.describe_body(&"alpha")
	ctx.assert_true(bool(alpha_desc.get("has_rotation_basis", false)), "alpha-Stern hat eine Day-Basis")
	ctx.assert_true(bool(alpha_desc.get("has_orbital_period_basis", false)), "alpha-Stern hat eine Year-Basis um obsidian")
	ctx.assert_almost(
		float(alpha_desc.get("orbital_period_s", 0.0)),
		40000.0,
		1.0e-6,
		"AUTHORED-Orbit-Sterne lesen exakt authored_period_s als Year"
	)
	var obsidian_desc: Dictionary = orbit_readout_service.describe_body(&"obsidian")
	ctx.assert_true(not bool(obsidian_desc.get("has_rotation_basis", true)), "obsidian ohne Rotationswert bleibt ohne Day-Basis")
	ctx.assert_true(not bool(obsidian_desc.get("has_orbital_period_basis", true)), "obsidian als Root bleibt ohne Year-Basis")
	SimTestHarnessScript.teardown_context(setup)


static func _test_authored_moon_uses_authored_orbit_period(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var orbit_readout_service = setup[SimTestHarnessScript.HARNESS_KEY_ORBIT_READOUT_SERVICE]
	var desc: Dictionary = orbit_readout_service.describe_body(&"moon_a")
	ctx.assert_true(bool(desc.get("has_orbital_period_basis", false)), "AUTHORED-Orbit-Monde haben eine Year-Basis")
	ctx.assert_almost(
		float(desc.get("orbital_period_s", 0.0)),
		2360592.0,
		1.0e-6,
		"AUTHORED-Orbit-Monde lesen exakt authored_period_s"
	)
	SimTestHarnessScript.teardown_context(setup)
