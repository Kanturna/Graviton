extends RefCounted


static func run(ctx) -> void:
	ctx.current_suite = "test_local_orbit_integrator"
	_test_gravity_points_towards_parent(ctx)
	_test_gravity_magnitude_matches_reference(ctx)
	_test_gravity_zero_radius_returns_zero(ctx)
	_test_gravity_non_finite_returns_zero(ctx)
	_test_velocity_verlet_zero_mu_is_linear(ctx)
	_test_velocity_verlet_substepped_small_dt_matches_single_step(ctx)
	_test_velocity_verlet_substepped_matches_manual_multi_step(ctx)
	_test_velocity_verlet_substepped_cap_reports_and_covers_full_dt(ctx)
	_test_velocity_verlet_substepped_invalid_params_return_unchanged(ctx)
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


static func _test_velocity_verlet_substepped_small_dt_matches_single_step(ctx) -> void:
	var integrator := _integrator_script()
	var position: Vector3 = Vector3(1.0e9, 0.0, 0.0)
	var velocity: Vector3 = Vector3(0.0, 1.2e5, 0.0)
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var single_step: Dictionary = integrator.step_velocity_verlet(position, velocity, 5.0, mu)
	var substepped: Dictionary = integrator.step_velocity_verlet_substepped(
		position,
		velocity,
		5.0,
		mu,
		10.0,
		64
	)

	ctx.assert_true(int(substepped.get("substep_count", -1)) == 1,
		"substepped helper nutzt bei kleinem dt genau einen Substep")
	ctx.assert_vec_almost(
		substepped.get("position_parent_frame_m", Vector3.ZERO),
		single_step.get("position_parent_frame_m", Vector3.ZERO),
		1.0e-6,
		"substepped helper stimmt bei einem Substep mit single-step Position ueberein"
	)
	ctx.assert_vec_almost(
		substepped.get("velocity_parent_frame_mps", Vector3.ZERO),
		single_step.get("velocity_parent_frame_mps", Vector3.ZERO),
		1.0e-6,
		"substepped helper stimmt bei einem Substep mit single-step Velocity ueberein"
	)


static func _test_velocity_verlet_substepped_matches_manual_multi_step(ctx) -> void:
	var integrator := _integrator_script()
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var position: Vector3 = Vector3(1.0e9, 0.0, 0.0)
	var velocity: Vector3 = Vector3(0.0, sqrt(mu / 1.0e9), 0.0)
	var substepped: Dictionary = integrator.step_velocity_verlet_substepped(
		position,
		velocity,
		40.0,
		mu,
		10.0,
		64
	)
	var expected_position: Vector3 = position
	var expected_velocity: Vector3 = velocity

	for _step in range(4):
		var stepped: Dictionary = integrator.step_velocity_verlet(
			expected_position,
			expected_velocity,
			10.0,
			mu
		)
		expected_position = stepped.get("position_parent_frame_m", expected_position)
		expected_velocity = stepped.get("velocity_parent_frame_mps", expected_velocity)

	ctx.assert_true(int(substepped.get("substep_count", -1)) == 4,
		"substepped helper nutzt ceil(dt/target) fuer die Substep-Anzahl")
	ctx.assert_vec_almost(
		substepped.get("position_parent_frame_m", Vector3.ZERO),
		expected_position,
		1.0e-3,
		"substepped helper stimmt mit manueller Multi-Step-Position ueberein"
	)
	ctx.assert_vec_almost(
		substepped.get("velocity_parent_frame_mps", Vector3.ZERO),
		expected_velocity,
		1.0e-3,
		"substepped helper stimmt mit manueller Multi-Step-Velocity ueberein"
	)


static func _test_velocity_verlet_substepped_cap_reports_and_covers_full_dt(ctx) -> void:
	var integrator := _integrator_script()
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var position: Vector3 = Vector3(1.0e9, 0.0, 0.0)
	var velocity: Vector3 = Vector3(0.0, sqrt(mu / 1.0e9), 0.0)
	var capped: Dictionary = integrator.step_velocity_verlet_substepped(
		position,
		velocity,
		100.0,
		mu,
		10.0,
		6
	)
	var expected_position: Vector3 = position
	var expected_velocity: Vector3 = velocity
	var expected_substep_dt: float = 100.0 / 6.0

	for _step in range(6):
		var stepped: Dictionary = integrator.step_velocity_verlet(
			expected_position,
			expected_velocity,
			expected_substep_dt,
			mu
		)
		expected_position = stepped.get("position_parent_frame_m", expected_position)
		expected_velocity = stepped.get("velocity_parent_frame_mps", expected_velocity)

	ctx.assert_true(bool(capped.get("hit_substep_cap", false)),
		"substepped helper meldet capped regime, wenn ideal_substeps > max_substeps")
	ctx.assert_true(int(capped.get("substep_count", -1)) == 6,
		"substepped helper capped die Substep-Anzahl auf max_substeps")
	ctx.assert_almost(float(capped.get("substep_dt_s", -1.0)), expected_substep_dt, 1.0e-9,
		"substepped helper verteilt das volle dt auf capped Substeps")
	ctx.assert_vec_almost(
		capped.get("position_parent_frame_m", Vector3.ZERO),
		expected_position,
		1.0e-3,
		"capped helper deckt das volle dt ueber alle capped Substeps ab"
	)
	ctx.assert_vec_almost(
		capped.get("velocity_parent_frame_mps", Vector3.ZERO),
		expected_velocity,
		1.0e-3,
		"capped helper deckt die volle Velocity-Integration ueber capped Substeps ab"
	)


static func _test_velocity_verlet_substepped_invalid_params_return_unchanged(ctx) -> void:
	var integrator := _integrator_script()
	var position: Vector3 = Vector3(1.0, 2.0, 3.0)
	var velocity: Vector3 = Vector3(4.0, 5.0, 6.0)
	var invalid_target: Dictionary = integrator.step_velocity_verlet_substepped(
		position,
		velocity,
		10.0,
		0.0,
		0.0,
		64
	)
	var invalid_max: Dictionary = integrator.step_velocity_verlet_substepped(
		position,
		velocity,
		10.0,
		0.0,
		10.0,
		0
	)
	var invalid_dt: Dictionary = integrator.step_velocity_verlet_substepped(
		position,
		velocity,
		INF,
		0.0,
		10.0,
		64
	)
	var invalid_vec: Dictionary = integrator.step_velocity_verlet_substepped(
		Vector3(INF, 0.0, 0.0),
		velocity,
		10.0,
		0.0,
		10.0,
		64
	)

	for result in [invalid_target, invalid_max, invalid_dt, invalid_vec]:
		ctx.assert_true(int(result.get("substep_count", -1)) == 0,
			"ungueltige Substep-Parameter liefern substep_count = 0")
		ctx.assert_true(not bool(result.get("hit_substep_cap", true)),
			"ungueltige Substep-Parameter liefern hit_substep_cap = false")

	ctx.assert_vec_almost(
		invalid_target.get("position_parent_frame_m", Vector3.ZERO),
		position,
		1.0e-12,
		"ungueltiger target_substep liefert unveraenderte Position"
	)
	ctx.assert_vec_almost(
		invalid_target.get("velocity_parent_frame_mps", Vector3.ZERO),
		velocity,
		1.0e-12,
		"ungueltiger target_substep liefert unveraenderte Velocity"
	)
	ctx.assert_vec_almost(
		invalid_max.get("position_parent_frame_m", Vector3.ZERO),
		position,
		1.0e-12,
		"ungueltiges max_substeps liefert unveraenderte Position"
	)
	ctx.assert_vec_almost(
		invalid_dt.get("velocity_parent_frame_mps", Vector3.ZERO),
		velocity,
		1.0e-12,
		"ungueltiges dt liefert unveraenderte Velocity"
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
