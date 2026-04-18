extends RefCounted

const TEST_SEED_EPSILON_S: float = 1.0


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_service_numeric_local"
	_test_numeric_request_enters_numeric_local(ctx)
	_test_numeric_entry_seeds_from_analytic_state(ctx)
	_test_numeric_local_integrates_on_next_step(ctx)
	_test_numeric_local_substeps_large_dt(ctx)
	_test_capped_numeric_local_keeps_mode_and_sets_warning_flag(ctx)
	_test_empty_request_exits_back_to_kepler_after_grace(ctx)
	_test_request_return_during_grace_avoids_reseed(ctx)
	_test_ineligible_requested_bodies_are_ignored(ctx)
	_test_request_replace_semantics_drop_old_wish_after_grace(ctx)
	_test_identical_request_is_idempotent(ctx)
	_test_update_order_stays_topological(ctx)


static func _make_registry() -> Node:
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	for def in [_root_def(), _planet_def(), _moon_def()]:
		reg.register_body(def)
	return reg


static func _make_time_service() -> Node:
	return load("res://src/core/time/time_service.gd").new()


static func _make_orbit_service(registry: Node, time_service: Node):
	var service = load("res://src/sim/orbit/orbit_service.gd").new()
	service.configure(registry, time_service)
	return service


static func _root_def() -> BodyDef:
	var def := BodyDef.new()
	def.id = &"sol"
	def.display_name = "sol"
	def.kind = BodyType.Kind.STAR
	def.mass_kg = UnitSystem.SOLAR_MASS_KG
	def.radius_m = 6.957e8
	def.parent_id = &""
	def.orbit_profile = null
	return def


static func _planet_def() -> BodyDef:
	var def := BodyDef.new()
	def.id = &"planet_a"
	def.display_name = "planet_a"
	def.kind = BodyType.Kind.PLANET
	def.mass_kg = UnitSystem.EARTH_MASS_KG
	def.radius_m = 6.371e6
	def.parent_id = &"sol"
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.KEPLER_APPROX
	profile.semi_major_axis_m = 1.0e9
	profile.eccentricity = 0.02
	profile.inclination_rad = 0.0
	profile.longitude_ascending_node_rad = 0.0
	profile.argument_periapsis_rad = 0.3
	profile.mean_anomaly_epoch_rad = 0.4
	profile.epoch_s = 0.0
	def.orbit_profile = profile
	return def


static func _moon_def() -> BodyDef:
	var def := BodyDef.new()
	def.id = &"moon_a"
	def.display_name = "moon_a"
	def.kind = BodyType.Kind.MOON
	def.mass_kg = UnitSystem.LUNAR_MASS_KG
	def.radius_m = 1.737e6
	def.parent_id = &"planet_a"
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = 2.0e8
	profile.authored_period_s = 4.0e5
	profile.authored_phase_rad = 0.0
	def.orbit_profile = profile
	return def


static func _ids(values: Array[StringName]) -> Array[StringName]:
	return values


static func _integrator_script() -> GDScript:
	return load("res://src/sim/orbit/local_orbit_integrator.gd")


static func _emit_sim_tick(time_service: Node, dt_s: float) -> void:
	time_service._emit_tick(dt_s)


static func _test_numeric_request_enters_numeric_local(ctx) -> void:
	var reg := _make_registry()
	var time_service := _make_time_service()
	var service = _make_orbit_service(reg, time_service)

	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.recompute_all_at_time(123.0)

	var state: BodyState = reg.get_state(&"planet_a")
	ctx.assert_true(state.current_mode == OrbitMode.Kind.NUMERIC_LOCAL,
		"KEPLER_APPROX-Planet wechselt nach Request zu NUMERIC_LOCAL")

	service.free()
	time_service.free()
	reg.free()


static func _test_numeric_entry_seeds_from_analytic_state(ctx) -> void:
	var reg := _make_registry()
	var time_service := _make_time_service()
	var service = _make_orbit_service(reg, time_service)
	var state: BodyState = reg.get_state(&"planet_a")
	var def: BodyDef = reg.get_def(&"planet_a")
	var profile: OrbitProfile = def.orbit_profile
	var t_entry: float = 456.0

	state.position_parent_frame_m = Vector3(9.9e8, -9.9e8, 0.0)
	state.velocity_parent_frame_mps = Vector3(12345.0, -54321.0, 0.0)

	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.recompute_all_at_time(t_entry)

	var expected: Dictionary = _evaluate_kepler_state(def, profile, t_entry)
	ctx.assert_vec_almost(
		state.position_parent_frame_m,
		expected.get("position_parent_frame_m", Vector3.ZERO),
		1.0e-3,
		"Eintritt seeded Position aus analytischer Kepler-Loesung"
	)
	ctx.assert_vec_almost(
		state.velocity_parent_frame_mps,
		expected.get("velocity_parent_frame_mps", Vector3.ZERO),
		1.0e-3,
		"Eintritt seeded Velocity aus analytischer Kepler-Loesung"
	)

	service.free()
	time_service.free()
	reg.free()


static func _test_numeric_local_integrates_on_next_step(ctx) -> void:
	var reg := _make_registry()
	var time_service := _make_time_service()
	var service = _make_orbit_service(reg, time_service)
	var state: BodyState = reg.get_state(&"planet_a")
	var def: BodyDef = reg.get_def(&"planet_a")

	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.recompute_all_at_time(100.0)
	var pos_before: Vector3 = state.position_parent_frame_m
	var vel_before: Vector3 = state.velocity_parent_frame_mps
	var dt: float = 10.0

	service.recompute_all_at_time(100.0 + dt)

	var expected: Dictionary = _integrator_script().step_velocity_verlet(
		pos_before,
		vel_before,
		dt,
		_compute_parent_mu(reg, def)
	)
	ctx.assert_vec_almost(
		state.position_parent_frame_m,
		expected.get("position_parent_frame_m", Vector3.ZERO),
		1.0e-3,
		"NUMERIC_LOCAL integriert Position mit Velocity-Verlet weiter"
	)
	ctx.assert_vec_almost(
		state.velocity_parent_frame_mps,
		expected.get("velocity_parent_frame_mps", Vector3.ZERO),
		1.0e-3,
		"NUMERIC_LOCAL integriert Velocity mit Velocity-Verlet weiter"
	)

	service.free()
	time_service.free()
	reg.free()


static func _test_numeric_local_substeps_large_dt(ctx) -> void:
	var reg := _make_registry()
	var time_service := _make_time_service()
	var service = _make_orbit_service(reg, time_service)
	var state: BodyState = reg.get_state(&"planet_a")
	var def: BodyDef = reg.get_def(&"planet_a")

	service.numeric_local_target_substep_s = 10.0
	service.numeric_local_max_substeps_per_tick = 64
	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.recompute_all_at_time(0.0)
	var pos_before: Vector3 = state.position_parent_frame_m
	var vel_before: Vector3 = state.velocity_parent_frame_mps
	var dt: float = 40.0

	_emit_sim_tick(time_service, dt)

	var expected: Dictionary = _integrator_script().step_velocity_verlet_substepped(
		pos_before,
		vel_before,
		dt,
		_compute_parent_mu(reg, def),
		service.numeric_local_target_substep_s,
		service.numeric_local_max_substeps_per_tick
	)
	ctx.assert_vec_almost(
		state.position_parent_frame_m,
		expected.get("position_parent_frame_m", Vector3.ZERO),
		1.0e-3,
		"grosser dt wird im NUMERIC_LOCAL-Pfad per Substepping integriert"
	)
	ctx.assert_vec_almost(
		state.velocity_parent_frame_mps,
		expected.get("velocity_parent_frame_mps", Vector3.ZERO),
		1.0e-3,
		"grosser dt nutzt dieselbe Substep-Mathematik wie der Integrator-Helper"
	)
	ctx.assert_true(not service._substep_cap_warning_active_by_id.has(&"planet_a"),
		"nicht-gecappte Substep-Ticks setzen kein Cap-Warning-Flag")

	service.free()
	time_service.free()
	reg.free()


static func _test_capped_numeric_local_keeps_mode_and_sets_warning_flag(ctx) -> void:
	var reg := _make_registry()
	var time_service := _make_time_service()
	var service = _make_orbit_service(reg, time_service)
	var state: BodyState = reg.get_state(&"planet_a")
	var def: BodyDef = reg.get_def(&"planet_a")

	service.numeric_local_target_substep_s = 1.0
	service.numeric_local_max_substeps_per_tick = 2
	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.recompute_all_at_time(0.0)
	var pos_before: Vector3 = state.position_parent_frame_m
	var vel_before: Vector3 = state.velocity_parent_frame_mps

	_emit_sim_tick(time_service, 10.0)

	var expected: Dictionary = _integrator_script().step_velocity_verlet_substepped(
		pos_before,
		vel_before,
		10.0,
		_compute_parent_mu(reg, def),
		service.numeric_local_target_substep_s,
		service.numeric_local_max_substeps_per_tick
	)
	ctx.assert_true(state.current_mode == OrbitMode.Kind.NUMERIC_LOCAL,
		"auch im capped Fall bleibt der Body in NUMERIC_LOCAL")
	ctx.assert_true(bool(expected.get("hit_substep_cap", false)),
		"Testfall erzwingt bewusst einen gecappten Substep-Tick")
	ctx.assert_vec_almost(
		state.position_parent_frame_m,
		expected.get("position_parent_frame_m", Vector3.ZERO),
		1.0e-3,
		"capped Tick integriert trotzdem das volle dt numerisch"
	)
	ctx.assert_true(service._substep_cap_warning_active_by_id.has(&"planet_a"),
		"erster Cap-Tick setzt das Warning-Dedup-Flag")

	_emit_sim_tick(time_service, 10.0)
	ctx.assert_true(service._substep_cap_warning_active_by_id.has(&"planet_a"),
		"Folge-Cap-Ticks behalten das Dedup-Flag statt neue State-Pfade zu oeffnen")

	service.numeric_local_max_substeps_per_tick = 64
	_emit_sim_tick(time_service, 1.0)
	ctx.assert_true(not service._substep_cap_warning_active_by_id.has(&"planet_a"),
		"ein uncapped Tick setzt das Cap-Warning-Flag wieder zurueck")

	service.free()
	time_service.free()
	reg.free()


static func _test_empty_request_exits_back_to_kepler_after_grace(ctx) -> void:
	var reg := _make_registry()
	var time_service := _make_time_service()
	var service = _make_orbit_service(reg, time_service)
	var state: BodyState = reg.get_state(&"planet_a")
	var def: BodyDef = reg.get_def(&"planet_a")
	var profile: OrbitProfile = def.orbit_profile

	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.recompute_all_at_time(0.0)
	_emit_sim_tick(time_service, 1.0)
	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.request_numeric_local_candidates(_ids([]))

	_emit_sim_tick(time_service, 1.0)
	ctx.assert_true(state.current_mode == OrbitMode.Kind.NUMERIC_LOCAL,
		"ein fehlender Request-Tick bleibt wegen Grace noch numerisch")

	_emit_sim_tick(time_service, 1.0)

	var expected: Dictionary = _evaluate_kepler_state(def, profile, 3.0)
	ctx.assert_true(state.current_mode == OrbitMode.Kind.KEPLER_APPROX,
		"leerer Request fuehrt nach Ablauf der Grace zum Rueckwechsel auf KEPLER_APPROX")
	ctx.assert_vec_almost(
		state.position_parent_frame_m,
		expected.get("position_parent_frame_m", Vector3.ZERO),
		1.0e-3,
		"Rueckwechsel nach Grace setzt analytische Kepler-Position"
	)
	ctx.assert_vec_almost(
		state.velocity_parent_frame_mps,
		expected.get("velocity_parent_frame_mps", Vector3.ZERO),
		1.0e-3,
		"Rueckwechsel nach Grace setzt analytische Kepler-Velocity"
	)

	service.free()
	time_service.free()
	reg.free()


static func _test_ineligible_requested_bodies_are_ignored(ctx) -> void:
	var reg := _make_registry()
	var time_service := _make_time_service()
	var service = _make_orbit_service(reg, time_service)

	service.request_numeric_local_candidates(_ids([&"sol", &"moon_a", &"planet_a"]))
	service.recompute_all_at_time(50.0)

	ctx.assert_true(reg.get_state(&"sol").current_mode != OrbitMode.Kind.NUMERIC_LOCAL,
		"Roots bleiben trotz Request nicht-numerisch")
	ctx.assert_true(reg.get_state(&"moon_a").current_mode == OrbitMode.Kind.AUTHORED_ORBIT,
		"AUTHORED_ORBIT-Body bleibt trotz Request authored")
	ctx.assert_true(reg.get_state(&"planet_a").current_mode == OrbitMode.Kind.NUMERIC_LOCAL,
		"eligible Planet wird trotz ineligible Nachbarn numerisch")

	service.free()
	time_service.free()
	reg.free()


static func _test_request_return_during_grace_avoids_reseed(ctx) -> void:
	var reg := _make_registry()
	var time_service := _make_time_service()
	var service = _make_orbit_service(reg, time_service)
	var state: BodyState = reg.get_state(&"planet_a")
	var def: BodyDef = reg.get_def(&"planet_a")

	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.recompute_all_at_time(0.0)
	_emit_sim_tick(time_service, 10.0)
	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.request_numeric_local_candidates(_ids([]))
	_emit_sim_tick(time_service, 1.0)
	ctx.assert_true(state.current_mode == OrbitMode.Kind.NUMERIC_LOCAL,
		"Grace haelt den Body vor der Request-Rueckkehr noch im numerischen Regime")

	var pos_before_return: Vector3 = state.position_parent_frame_m
	var vel_before_return: Vector3 = state.velocity_parent_frame_mps
	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	_emit_sim_tick(time_service, 1.0)

	var expected: Dictionary = _integrator_script().step_velocity_verlet_substepped(
		pos_before_return,
		vel_before_return,
		1.0,
		_compute_parent_mu(reg, def),
		service.numeric_local_target_substep_s,
		service.numeric_local_max_substeps_per_tick
	)
	ctx.assert_true(state.current_mode == OrbitMode.Kind.NUMERIC_LOCAL,
		"Request-Rueckkehr waehrend der Grace behaelt den Body im numerischen Regime")
	ctx.assert_vec_almost(
		state.position_parent_frame_m,
		expected.get("position_parent_frame_m", Vector3.ZERO),
		1.0e-3,
		"Request-Rueckkehr waehrend der Grace fuehrt nicht zu erneutem Kepler-Seeding"
	)
	ctx.assert_true(int(service._last_requested_tick_by_id.get(&"planet_a", -1)) == int(service._sim_tick_index - 1),
		"Rueckkehr-Request aktualisiert den letzten Request-Tick vor dem Folgetick")

	service.free()
	time_service.free()
	reg.free()


static func _test_request_replace_semantics_drop_old_wish_after_grace(ctx) -> void:
	var reg := _make_registry()
	var time_service := _make_time_service()
	var service = _make_orbit_service(reg, time_service)

	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.recompute_all_at_time(0.0)
	_emit_sim_tick(time_service, 1.0)
	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.request_numeric_local_candidates(_ids([&"moon_a"]))

	_emit_sim_tick(time_service, 1.0)
	ctx.assert_true(reg.get_state(&"planet_a").current_mode == OrbitMode.Kind.NUMERIC_LOCAL,
		"Replace-Request mit ineligible Body haelt den alten Wunsch noch genau einen Grace-Tick")

	_emit_sim_tick(time_service, 1.0)

	ctx.assert_true(reg.get_state(&"planet_a").current_mode == OrbitMode.Kind.KEPLER_APPROX,
		"neuer Request ersetzt den alten Wish statt zu akkumulieren und laesst ihn nach Grace auslaufen")

	service.free()
	time_service.free()
	reg.free()


static func _test_identical_request_is_idempotent(ctx) -> void:
	var reg := _make_registry()
	var time_service := _make_time_service()
	var service = _make_orbit_service(reg, time_service)
	var state: BodyState = reg.get_state(&"planet_a")
	var def: BodyDef = reg.get_def(&"planet_a")

	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.recompute_all_at_time(100.0)
	service.recompute_all_at_time(110.0)

	var pos_before: Vector3 = state.position_parent_frame_m
	var vel_before: Vector3 = state.velocity_parent_frame_mps
	var dt: float = 10.0

	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.recompute_all_at_time(120.0)

	var expected: Dictionary = _integrator_script().step_velocity_verlet(
		pos_before,
		vel_before,
		dt,
		_compute_parent_mu(reg, def)
	)
	ctx.assert_true(state.current_mode == OrbitMode.Kind.NUMERIC_LOCAL,
		"identischer Request behaelt den Body im numerischen Regime")
	ctx.assert_vec_almost(
		state.position_parent_frame_m,
		expected.get("position_parent_frame_m", Vector3.ZERO),
		1.0e-3,
		"identischer Request fuehrt nicht zu erneutem Kepler-Seeding"
	)

	service.free()
	time_service.free()
	reg.free()


static func _test_update_order_stays_topological(ctx) -> void:
	var reg := _make_registry()
	var time_service := _make_time_service()
	var service = _make_orbit_service(reg, time_service)

	service.request_numeric_local_candidates(_ids([&"planet_a"]))
	service.recompute_all_at_time(5.0)

	var order: Array[StringName] = reg.get_update_order()
	ctx.assert_true(order.find(&"sol") < order.find(&"planet_a"), "sol bleibt vor planet_a in update_order")
	ctx.assert_true(order.find(&"planet_a") < order.find(&"moon_a"), "planet_a bleibt vor moon_a in update_order")

	service.free()
	time_service.free()
	reg.free()


static func _compute_parent_mu(registry: Node, def: BodyDef) -> float:
	var parent: BodyDef = registry.get_def(def.parent_id)
	if parent == null:
		return 0.0
	return UnitSystem.mu_from_mass(parent.mass_kg)


static func _evaluate_kepler_state(def: BodyDef, profile: OrbitProfile, t_s: float) -> Dictionary:
	var mu: float = UnitSystem.mu_from_mass(UnitSystem.SOLAR_MASS_KG)
	var pos: Vector3 = OrbitMath.kepler_position(
		profile.semi_major_axis_m,
		profile.eccentricity,
		profile.inclination_rad,
		profile.longitude_ascending_node_rad,
		profile.argument_periapsis_rad,
		profile.mean_anomaly_epoch_rad,
		profile.epoch_s,
		mu,
		t_s
	)
	var prev_pos: Vector3 = OrbitMath.kepler_position(
		profile.semi_major_axis_m,
		profile.eccentricity,
		profile.inclination_rad,
		profile.longitude_ascending_node_rad,
		profile.argument_periapsis_rad,
		profile.mean_anomaly_epoch_rad,
		profile.epoch_s,
		mu,
		t_s - TEST_SEED_EPSILON_S
	)
	var next_pos: Vector3 = OrbitMath.kepler_position(
		profile.semi_major_axis_m,
		profile.eccentricity,
		profile.inclination_rad,
		profile.longitude_ascending_node_rad,
		profile.argument_periapsis_rad,
		profile.mean_anomaly_epoch_rad,
		profile.epoch_s,
		mu,
		t_s + TEST_SEED_EPSILON_S
	)
	return {
		"position_parent_frame_m": pos,
		"velocity_parent_frame_mps": (next_pos - prev_pos) / (2.0 * TEST_SEED_EPSILON_S),
	}
