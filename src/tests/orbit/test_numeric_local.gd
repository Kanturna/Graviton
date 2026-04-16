extends RefCounted

# Unit-Tests fuer LocalOrbitIntegrator und OrbitService-NUMERIC_LOCAL-Pfad.
# Kein Szenen-Laden, keine Autoloads — synthetisch.


# Minimaler Mock, der die Registry-API fuer OrbitService-Tests emuliert.
class MockRegistry:
	var _defs: Dictionary = {}
	var _states: Dictionary = {}
	var _order: Array[StringName] = []

	func add(def: BodyDef, state: BodyState) -> void:
		_defs[def.id] = def
		_states[def.id] = state
		_order.append(def.id)

	func get_def(id: StringName):
		return _defs.get(id, null)

	func get_state(id: StringName):
		return _states.get(id, null)

	func get_update_order() -> Array[StringName]:
		return _order.duplicate()

	func body_count() -> int:
		return _order.size()


class MockTime:
	signal sim_tick(dt: float)
	var sim_time_s: float = 0.0
	var time_scale: float = 1.0
	var paused: bool = false
	var tick_count: int = 0


# Hilfsmethode: Kreisbahn-Geschwindigkeit (v = sqrt(mu/r)) in der xy-Ebene.
static func _circular_velocity_mps(radius_m: float, mu: float) -> Vector3:
	return Vector3(0.0, sqrt(mu / radius_m), 0.0)


static func run(ctx) -> void:
	_test_gravity_known_value(ctx)
	_test_gravity_singularity(ctx)
	_test_circular_orbit_radius_stability(ctx)
	_test_circular_orbit_energy_conservation(ctx)
	_test_entry_position_continuity(ctx)
	_test_authored_orbit_not_eligible(ctx)
	_test_root_not_eligible(ctx)
	_test_exit_clears_numeric_set(ctx)
	_test_no_mutation_from_candidates_alone(ctx)
	_test_current_mode_remains_numeric_after_ticks(ctx)


# 1. Bekannter Gravitations-Wert: 1 AU von 1 Sonnenmasse
static func _test_gravity_known_value(ctx) -> void:
	var AU: float = UnitSystem.AU_M
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var pos: Vector3 = Vector3(AU, 0.0, 0.0)
	var acc: Vector3 = LocalOrbitIntegrator.gravity_acceleration_mps2(pos, mu)
	# Erwartete Beschleunigung: mu / r^2 ≈ 5.93e-3 m/s², Richtung -x
	var expected_mag: float = mu / (AU * AU)
	ctx.assert_almost(acc.length(), expected_mag, expected_mag * 0.001,
		"gravity_known_value: Betrag bei 1 AU stimmt (< 0.1%)")
	ctx.assert_true(acc.x < 0.0 and absf(acc.y) < 1e-10 and absf(acc.z) < 1e-10,
		"gravity_known_value: Richtung zeigt zum Ursprung (-x)")


# 2. Singularitaetsschutz: pos nahezu Null → ZERO
static func _test_gravity_singularity(ctx) -> void:
	var acc: Vector3 = LocalOrbitIntegrator.gravity_acceleration_mps2(
		Vector3(0.0, 0.0, 0.0), 1.32712440018e20)
	ctx.assert_vec_almost(acc, Vector3.ZERO, 1e-30,
		"gravity_singularity: pos=ZERO gibt ZERO zurueck")


# 3. Kreisbahn-Radius-Stabilitaet: nach 1 000 Schritten < 0.5% Drift
static func _test_circular_orbit_radius_stability(ctx) -> void:
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var r0: float = 1.0e10  # kleiner Orbit fuer kurze Integration
	var pos: Vector3 = Vector3(r0, 0.0, 0.0)
	var vel: Vector3 = _circular_velocity_mps(r0, mu)
	var dt: float = 1.0
	for _i in range(1000):
		var result: Dictionary = LocalOrbitIntegrator.step_velocity_verlet(pos, vel, mu, dt)
		pos = result["pos"]
		vel = result["vel"]
	var r_final: float = pos.length()
	var drift: float = absf(r_final - r0) / r0
	ctx.assert_true(drift < 0.005,
		"circular_orbit_radius_stability: < 0.5%% Drift nach 1000 Schritten (drift=%.4f%%)" % [drift * 100.0])


# 4. Energieerhalt: kinetisch + potentiell nach 1 Umlauf < 1% Aenderung
static func _test_circular_orbit_energy_conservation(ctx) -> void:
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var r0: float = 1.0e10
	var pos: Vector3 = Vector3(r0, 0.0, 0.0)
	var vel: Vector3 = _circular_velocity_mps(r0, mu)
	# Umlaufzeit fuer kleinen Orbit
	var period_s: float = TAU * sqrt(r0 * r0 * r0 / mu)
	var dt: float = 1.0
	var steps: int = int(period_s / dt)
	var e0: float = 0.5 * vel.length_squared() - mu / pos.length()
	for _i in range(steps):
		var result: Dictionary = LocalOrbitIntegrator.step_velocity_verlet(pos, vel, mu, dt)
		pos = result["pos"]
		vel = result["vel"]
	var e1: float = 0.5 * vel.length_squared() - mu / pos.length()
	var rel_change: float = absf(e1 - e0) / absf(e0)
	ctx.assert_true(rel_change < 0.01,
		"energy_conservation: < 1%% Energieaenderung nach 1 Umlauf (rel=%.4f%%)" % [rel_change * 100.0])


# 5. Positionskontinuitaet beim Eintritt: < 100 m Sprung
static func _test_entry_position_continuity(ctx) -> void:
	var reg := MockRegistry.new()
	var time := MockTime.new()

	var sol_def := BodyDef.new()
	sol_def.id = &"sol"
	sol_def.parent_id = &""
	sol_def.mass_kg = UnitSystem.SOLAR_MASS_KG
	var sol_state := BodyState.new(&"sol", &"")
	reg.add(sol_def, sol_state)

	var planet_def := BodyDef.new()
	planet_def.id = &"planet_a"
	planet_def.parent_id = &"sol"
	planet_def.mass_kg = 5.972e24
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 1.0e10
	prof.eccentricity = 0.0
	planet_def.orbit_profile = prof
	var planet_state := BodyState.new(&"planet_a", &"sol")
	reg.add(planet_def, planet_state)

	var service := OrbitService.new()
	service._registry = reg
	service._time = time
	service._configured = true

	# Kepler-Position zum Zeitpunkt 0 berechnen
	service.update_body(planet_state, planet_def, 0.0)
	var pos_before: Vector3 = planet_state.position_parent_frame_m

	# Eintreten in NUMERIC_LOCAL
	service.request_numeric_local_candidates([&"planet_a"])
	var pos_after: Vector3 = planet_state.position_parent_frame_m

	var jump_m: float = (pos_after - pos_before).length()
	ctx.assert_true(jump_m < 100.0,
		"entry_continuity: Sprung < 100 m beim Eintritt (%.2f m)" % jump_m)
	ctx.assert_true(planet_state.current_mode == OrbitMode.Kind.NUMERIC_LOCAL,
		"entry_continuity: current_mode ist NUMERIC_LOCAL nach Eintritt")
	service.free()


# 6. AUTHORED_ORBIT-Body wird nie in _numeric_local_ids eingetragen
static func _test_authored_orbit_not_eligible(ctx) -> void:
	var reg := MockRegistry.new()
	var time := MockTime.new()

	var root_def := BodyDef.new()
	root_def.id = &"root"
	root_def.parent_id = &""
	root_def.mass_kg = 1.0e30
	reg.add(root_def, BodyState.new(&"root", &""))

	var moon_def := BodyDef.new()
	moon_def.id = &"moon"
	moon_def.parent_id = &"root"
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 1.0e8
	prof.authored_period_s = 1.0e6
	moon_def.orbit_profile = prof
	reg.add(moon_def, BodyState.new(&"moon", &"root"))

	var service := OrbitService.new()
	service._registry = reg
	service._time = time
	service._configured = true

	service.request_numeric_local_candidates([&"moon"])
	ctx.assert_true(not (&"moon" in service._numeric_local_ids),
		"authored_not_eligible: AUTHORED_ORBIT-Body nicht in _numeric_local_ids")
	service.free()


# 7. Root-Body wird nie in _numeric_local_ids eingetragen
static func _test_root_not_eligible(ctx) -> void:
	var reg := MockRegistry.new()
	var time := MockTime.new()

	var root_def := BodyDef.new()
	root_def.id = &"sol"
	root_def.parent_id = &""
	root_def.mass_kg = UnitSystem.SOLAR_MASS_KG
	reg.add(root_def, BodyState.new(&"sol", &""))

	var service := OrbitService.new()
	service._registry = reg
	service._time = time
	service._configured = true

	service.request_numeric_local_candidates([&"sol"])
	ctx.assert_true(not (&"sol" in service._numeric_local_ids),
		"root_not_eligible: Root-Body nicht in _numeric_local_ids")
	service.free()


# 8. Nach request_numeric_local_candidates([]) ist Set leer; naechster Tick nutzt Kepler
static func _test_exit_clears_numeric_set(ctx) -> void:
	var reg := MockRegistry.new()
	var time := MockTime.new()

	var sol_def := BodyDef.new()
	sol_def.id = &"sol"
	sol_def.parent_id = &""
	sol_def.mass_kg = UnitSystem.SOLAR_MASS_KG
	reg.add(sol_def, BodyState.new(&"sol", &""))

	var planet_def := BodyDef.new()
	planet_def.id = &"planet_a"
	planet_def.parent_id = &"sol"
	planet_def.mass_kg = 5.972e24
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 1.0e10
	planet_def.orbit_profile = prof
	var planet_state := BodyState.new(&"planet_a", &"sol")
	reg.add(planet_def, planet_state)

	var service := OrbitService.new()
	service._registry = reg
	service._time = time
	service._configured = true
	service.update_body(planet_state, planet_def, 0.0)

	service.request_numeric_local_candidates([&"planet_a"])
	ctx.assert_true(&"planet_a" in service._numeric_local_ids,
		"exit_clears: planet_a ist im Set nach Eintritt")

	service.request_numeric_local_candidates([])
	ctx.assert_true(not (&"planet_a" in service._numeric_local_ids),
		"exit_clears: _numeric_local_ids leer nach request([])")

	# Naechster update_body-Aufruf → Kepler-Pfad
	time.sim_time_s = 1.0
	service.update_body(planet_state, planet_def, 1.0)
	ctx.assert_true(planet_state.current_mode == OrbitMode.Kind.KEPLER_APPROX,
		"exit_clears: current_mode = KEPLER_APPROX nach Austritt + Tick")
	service.free()


# 9. Keine BodyState-Mutation durch request_numeric_local_candidates allein (kein dt)
static func _test_no_mutation_from_candidates_alone(ctx) -> void:
	var reg := MockRegistry.new()
	var time := MockTime.new()

	var sol_def := BodyDef.new()
	sol_def.id = &"sol"
	sol_def.parent_id = &""
	sol_def.mass_kg = UnitSystem.SOLAR_MASS_KG
	reg.add(sol_def, BodyState.new(&"sol", &""))

	var planet_def := BodyDef.new()
	planet_def.id = &"planet_a"
	planet_def.parent_id = &"sol"
	planet_def.mass_kg = 5.972e24
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 1.0e10
	planet_def.orbit_profile = prof
	var planet_state := BodyState.new(&"planet_a", &"sol")
	reg.add(planet_def, planet_state)

	var service := OrbitService.new()
	service._registry = reg
	service._time = time
	service._configured = true
	# Eintritt setzt Pos/Vel aus Kepler (das ist erlaubt in _enter_numeric_local)
	service.update_body(planet_state, planet_def, 0.0)
	var pos_before: Vector3 = planet_state.position_parent_frame_m

	# Zweiter Aufruf mit gleichen Kandidaten: Planet ist bereits im Set → kein neuer Sprung
	service.request_numeric_local_candidates([&"planet_a"])
	service.request_numeric_local_candidates([&"planet_a"])
	var pos_after: Vector3 = planet_state.position_parent_frame_m
	ctx.assert_vec_almost(pos_after, pos_before, 1e-3,
		"no_mutation_candidates: Wiederholter Kandidaten-Aufruf aendert Pos nicht")
	service.free()


# 10. Nach mehreren _update_numeric_local-Ticks bleibt current_mode NUMERIC_LOCAL
static func _test_current_mode_remains_numeric_after_ticks(ctx) -> void:
	var reg := MockRegistry.new()
	var time := MockTime.new()

	var sol_def := BodyDef.new()
	sol_def.id = &"sol"
	sol_def.parent_id = &""
	sol_def.mass_kg = UnitSystem.SOLAR_MASS_KG
	reg.add(sol_def, BodyState.new(&"sol", &""))

	var planet_def := BodyDef.new()
	planet_def.id = &"planet_a"
	planet_def.parent_id = &"sol"
	planet_def.mass_kg = 5.972e24
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = 1.0e10
	planet_def.orbit_profile = prof
	var planet_state := BodyState.new(&"planet_a", &"sol")
	reg.add(planet_def, planet_state)

	var service := OrbitService.new()
	service._registry = reg
	service._time = time
	service._configured = true
	service.update_body(planet_state, planet_def, 0.0)
	service.request_numeric_local_candidates([&"planet_a"])

	# Mehrere Ticks
	var dt: float = 1.0 / 60.0
	for i in range(10):
		time.sim_time_s += dt
		service.update_body(planet_state, planet_def, time.sim_time_s)
	ctx.assert_true(planet_state.current_mode == OrbitMode.Kind.NUMERIC_LOCAL,
		"mode_remains_numeric: current_mode = NUMERIC_LOCAL nach 10 Ticks")
	service.free()
