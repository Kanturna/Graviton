extends RefCounted


static func run(ctx) -> void:
	ctx.current_suite = "test_local_orbit_integrator"
	_test_gravity_points_towards_parent(ctx)
	_test_gravity_magnitude_matches_reference(ctx)
	_test_gravity_zero_radius_returns_zero(ctx)
	_test_gravity_non_finite_returns_zero(ctx)
	_test_velocity_verlet_zero_mu_is_linear(ctx)
	_test_velocity_verlet_orbital_sanity(ctx)


static func _integrator_script() -> GDScript:
	return load("res://src/sim/orbit/local_orbit_integrator.gd")


static func _test_gravity_points_towards_parent(ctx) -> void:
	var integrator := _integrator_script()
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var accel: Vector3 = integrator.gravity_acceleration_mps2(Vector3(2.0e9, 0.0, 0.0), mu)
	ctx.assert_true(accel.x < 0.0, "gravity_acceleration zeigt entlang -x zum Parent")
	ctx.assert_almost(accel.y, 0.0, 1.0e-12, "gravity_acceleration hat kein y fuer x-Achsenfall")
	ctx.assert_almost(accel.z, 0.0, 1.0e-12, "gravity_acceleration hat kein z fuer x-Achsenfall")


static func _test_gravity_magnitude_matches_reference(ctx) -> void:
	var integrator := _integrator_script()
	var radius: float = 3.0e9
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var accel: Vector3 = integrator.gravity_acceleration_mps2(Vector3(radius, 0.0, 0.0), mu)
	var expected_mag: float = mu / (radius * radius)
	ctx.assert_almost(accel.length(), expected_mag, expected_mag * 1.0e-6,
		"gravity_acceleration Betrag stimmt mit mu/r^2 ueberein")


static func _test_gravity_zero_radius_returns_zero(ctx) -> void:
	var integrator := _integrator_script()
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	ctx.assert_vec_almost(
		integrator.gravity_acceleration_mps2(Vector3.ZERO, mu),
		Vector3.ZERO,
		1.0e-12,
		"gravity_acceleration bei r=0 liefert Vector3.ZERO"
	)


static func _test_gravity_non_finite_returns_zero(ctx) -> void:
	var integrator := _integrator_script()
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	ctx.assert_vec_almost(
		integrator.gravity_acceleration_mps2(Vector3(INF, 0.0, 0.0), mu),
		Vector3.ZERO,
		1.0e-12,
		"gravity_acceleration bei nicht-finiten Inputs liefert Vector3.ZERO"
	)


static func _test_velocity_verlet_zero_mu_is_linear(ctx) -> void:
	var integrator := _integrator_script()
	var initial_pos: Vector3 = Vector3(1.0, 2.0, 3.0)
	var initial_vel: Vector3 = Vector3(4.0, -2.0, 1.0)
	var dt: float = 5.0
	var stepped: Dictionary = integrator.step_velocity_verlet(initial_pos, initial_vel, dt, 0.0)
	ctx.assert_vec_almost(
		stepped.get("position_parent_frame_m", Vector3.ZERO),
		initial_pos + initial_vel * dt,
		1.0e-9,
		"velocity_verlet bleibt bei mu=0 geradlinig"
	)
	ctx.assert_vec_almost(
		stepped.get("velocity_parent_frame_mps", Vector3.ZERO),
		initial_vel,
		1.0e-9,
		"velocity_verlet haelt bei mu=0 die Velocity konstant"
	)


static func _test_velocity_verlet_orbital_sanity(ctx) -> void:
	var integrator := _integrator_script()
	var a: float = 1.0e9
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var position: Vector3 = Vector3(a, 0.0, 0.0)
	var velocity: Vector3 = Vector3(0.0, sqrt(mu / a), 0.0)
	var period_s: float = TAU * sqrt(pow(a, 3.0) / mu)
	var dt: float = period_s / 1000.0
	var energy_start: float = _specific_energy(position, velocity, mu)

	for _step in range(1000):
		var stepped: Dictionary = integrator.step_velocity_verlet(position, velocity, dt, mu)
		position = stepped.get("position_parent_frame_m", position)
		velocity = stepped.get("velocity_parent_frame_mps", velocity)

	var radius_end: float = position.length()
	var energy_end: float = _specific_energy(position, velocity, mu)
	ctx.assert_true(absf(radius_end - a) / a <= 0.02,
		"orbital sanity: Radius driftet nach 1000 Schritten hoechstens um 2%%")
	ctx.assert_true(absf(energy_end - energy_start) / absf(energy_start) <= 0.01,
		"orbital sanity: spezifische Energie driftet hoechstens um 1%%")


static func _specific_energy(position_parent_frame_m: Vector3, velocity_parent_frame_mps: Vector3, mu: float) -> float:
	var radius: float = position_parent_frame_m.length()
	return 0.5 * velocity_parent_frame_mps.length_squared() - mu / radius
