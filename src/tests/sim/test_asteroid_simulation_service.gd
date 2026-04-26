extends RefCounted

const AsteroidSimulationServiceScript = preload("res://src/sim/asteroids/asteroid_simulation_service.gd")
const RelativeStateResolverScript = preload("res://src/sim/topology/relative_state_resolver.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_asteroid_simulation_service"
	_test_spawn_is_deterministic(ctx)
	_test_trajectory_is_deterministic(ctx)
	_test_major_body_states_stay_read_only(ctx)
	_test_anchor_id_stays_stable(ctx)
	_test_black_hole_mu_fit_interpolates_and_clamps(ctx)
	_test_influence_index_uses_asteroid_effective_mu(ctx)
	_test_black_holes_steer_inside_explicit_influence(ctx)
	_test_black_hole_zone_entry_has_no_empty_refresh_delay(ctx)
	_test_black_hole_flyby_curves_without_clean_capture(ctx)
	_test_initial_spawn_has_radial_drift_and_fast_flybys(ctx)
	_test_free_drift_without_attractors_is_linear(ctx)
	_test_influence_radius_and_hysteresis(ctx)
	_test_far_retire_threshold_deactivates(ctx)
	_test_sync_resident_roots_lifecycle_is_idempotent(ctx)
	_test_single_world_spawns_without_streaming_controller(ctx)
	_test_catalog_spawn_creates_states_for_nonresident_roots(ctx)
	_test_nonresident_catalog_asteroids_drift_linearly(ctx)
	_test_catalog_spawn_uses_analytic_origin_geometry(ctx)
	_test_major_body_residency_forces_influence_rebuild(ctx)
	_test_sim_asteroids_imports_no_runtime_tools_or_scenes(ctx)


static func _make_registry() -> Node:
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	for def in [
		_root_def(&"root_a"),
		_star_def(&"star_a", &"root_a", 1.0e10, 0.0),
		_star_def(&"star_b", &"root_a", -1.0e10, 0.8),
		_planet_def(&"planet_a", &"star_a", 0.8e11, 0.0, UnitSystem.EARTH_MASS_KG),
		_planet_def(&"planet_b", &"star_a", 1.0e11, 0.7, UnitSystem.EARTH_MASS_KG * 0.8),
		_planet_def(&"planet_c", &"star_a", 1.2e11, 1.4, UnitSystem.EARTH_MASS_KG * 0.7),
		_planet_def(&"planet_d", &"star_a", 1.4e11, 2.1, UnitSystem.EARTH_MASS_KG * 0.6),
		_planet_def(&"planet_e", &"star_a", 1.6e11, 2.8, UnitSystem.EARTH_MASS_KG * 0.5),
		_moon_def(&"moon_a", &"planet_a"),
	]:
		reg.register_body(def)
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	var time_service = load("res://src/core/time/time_service.gd").new()
	orbit_service.configure(reg, time_service)
	orbit_service.recompute_all_at_time(0.0)
	orbit_service.free()
	time_service.free()
	return reg


static func _make_two_root_registry() -> Node:
	var reg := _make_registry()
	for def in [
		_root_def(&"root_b"),
		_star_def(&"star_c", &"root_b", 1.0e10, 0.1),
		_planet_def(&"planet_f", &"star_c", 0.9e11, 0.3, UnitSystem.EARTH_MASS_KG),
	]:
		reg.register_body(def)
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	var time_service = load("res://src/core/time/time_service.gd").new()
	orbit_service.configure(reg, time_service)
	orbit_service.recompute_all_at_time(0.0)
	orbit_service.free()
	time_service.free()
	return reg


static func _catalog_root_defs(root_id: StringName, star_id: StringName, planet_id: StringName, star_radius_m: float = 2.0e10, planet_axis_m: float = 9.0e10, star_phase_rad: float = 0.0) -> Array[BodyDef]:
	var defs: Array[BodyDef] = []
	defs.append(_root_def(root_id))
	defs.append(_star_def(star_id, root_id, star_radius_m, star_phase_rad, 5.0e6))
	defs.append(_planet_def(planet_id, star_id, planet_axis_m, 0.4, UnitSystem.EARTH_MASS_KG))
	return defs


static func _catalog_for_nonresident_roots() -> Dictionary:
	return {
		&"root_b": _catalog_root_defs(&"root_b", &"star_c", &"planet_f", 2.0e10, 9.0e10, 0.1),
		&"root_c": _catalog_root_defs(&"root_c", &"star_d", &"planet_g", 3.0e10, 1.1e11, 0.3),
	}


static func _make_bh_fit_registry() -> Node:
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	for def in [
		_root_def(&"root_fit"),
		_star_def(&"fit_star_a", &"root_fit", 1.0e11, 0.0, 4.0e4),
		_star_def(&"fit_star_b", &"root_fit", 4.0e11, 1.0, 1.0e5),
		_planet_def(&"fit_planet_ignored", &"fit_star_a", 1.2e11, 0.0, UnitSystem.EARTH_MASS_KG),
	]:
		reg.register_body(def)
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	var time_service = load("res://src/core/time/time_service.gd").new()
	orbit_service.configure(reg, time_service)
	orbit_service.recompute_all_at_time(0.0)
	reg.get_state(&"fit_star_a").position_parent_frame_m = Vector3(9.0e15, 0.0, 0.0)
	reg.get_state(&"fit_star_a").velocity_parent_frame_mps = Vector3.ZERO
	reg.get_state(&"fit_star_b").position_parent_frame_m = Vector3(-9.0e15, 0.0, 0.0)
	reg.get_state(&"fit_star_b").velocity_parent_frame_mps = Vector3.ZERO
	orbit_service.free()
	time_service.free()
	return reg


static func _make_service(registry: Node):
	var service = AsteroidSimulationServiceScript.new()
	service.configure(registry)
	return service


static func _root_def(id: StringName) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.BLACK_HOLE
	def.mass_kg = UnitSystem.SOLAR_MASS_KG * 4.0
	def.radius_m = 2.0e9
	def.parent_id = &""
	def.orbit_profile = null
	return def


static func _star_def(id: StringName, parent_id: StringName, radius_m: float, phase_rad: float, period_s: float = 9.0e6) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.STAR
	def.mass_kg = UnitSystem.SOLAR_MASS_KG
	def.radius_m = 6.957e8
	def.parent_id = parent_id
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = radius_m
	profile.authored_period_s = period_s
	profile.authored_phase_rad = phase_rad
	def.orbit_profile = profile
	return def


static func _planet_def(id: StringName, parent_id: StringName, axis_m: float, phase_rad: float, mass_kg: float) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.PLANET
	def.mass_kg = mass_kg
	def.radius_m = 6.371e6
	def.parent_id = parent_id
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = axis_m
	profile.authored_period_s = 3.0e7
	profile.authored_phase_rad = phase_rad
	def.orbit_profile = profile
	return def


static func _moon_def(id: StringName, parent_id: StringName) -> BodyDef:
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = BodyType.Kind.MOON
	def.mass_kg = UnitSystem.LUNAR_MASS_KG
	def.radius_m = 1.737e6
	def.parent_id = parent_id
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = 4.0e8
	profile.authored_period_s = 2.4e6
	profile.authored_phase_rad = 0.2
	def.orbit_profile = profile
	return def


static func _test_spawn_is_deterministic(ctx) -> void:
	var reg := _make_registry()
	var service_a = _make_service(reg)
	var service_b = _make_service(reg)
	service_a.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	service_b.reset_for_world(&"scope_a", [&"root_a"], 0.0)

	var entries_a: Array = service_a.get_state_snapshot().get("entries", [])
	var entries_b: Array = service_b.get_state_snapshot().get("entries", [])
	ctx.assert_true(entries_a.size() == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT,
		"ein Root spawnt exakt das V1-Budget an Asteroiden")
	ctx.assert_true(entries_a.size() == entries_b.size(), "deterministischer Spawn hat dieselbe Anzahl")
	for idx in range(entries_a.size()):
		var a: Dictionary = entries_a[idx]
		var b: Dictionary = entries_b[idx]
		ctx.assert_true(a.get("id", StringName("")) == b.get("id", StringName("")),
			"deterministischer Spawn haelt IDs stabil")
		ctx.assert_almost(float(a.get("x_m", 0.0)), float(b.get("x_m", 0.0)), 1.0e-6,
			"deterministischer Spawn haelt Positionen stabil")
		ctx.assert_true(StringName(a.get("anchor_id", StringName(""))) == &"root_a",
			"Asteroid nutzt seit v1.1 den Root als stabilen Frame-Anchor")
		var spawn_origin_id: StringName = a.get("spawn_origin_id", StringName(""))
		var spawn_origin_def: BodyDef = reg.get_def(spawn_origin_id)
		ctx.assert_true(spawn_origin_def != null and spawn_origin_def.kind == BodyType.Kind.STAR,
			"AsteroidDef.spawn_origin_id bleibt das deterministische Stern-Spawnzentrum")

	service_a.free()
	service_b.free()
	reg.free()


static func _test_trajectory_is_deterministic(ctx) -> void:
	var reg := _make_registry()
	var service_a = _make_service(reg)
	var service_b = _make_service(reg)
	service_a.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	service_b.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	for dt_s in [600.0, 1200.0, 1800.0]:
		service_a.advance_to_time(dt_s, dt_s)
		service_b.advance_to_time(dt_s, dt_s)

	var entries_a: Array = service_a.get_state_snapshot().get("entries", [])
	var entries_b: Array = service_b.get_state_snapshot().get("entries", [])
	for idx in range(entries_a.size()):
		var a: Dictionary = entries_a[idx]
		var b: Dictionary = entries_b[idx]
		ctx.assert_almost(float(a.get("x_m", 0.0)), float(b.get("x_m", 0.0)), 1.0e-3,
			"gleiche dt-Sequenz erzeugt gleiche x-Position")
		ctx.assert_almost(float(a.get("vy_mps", 0.0)), float(b.get("vy_mps", 0.0)), 1.0e-6,
			"gleiche dt-Sequenz erzeugt gleiche Velocity")

	service_a.free()
	service_b.free()
	reg.free()


static func _test_major_body_states_stay_read_only(ctx) -> void:
	var reg := _make_registry()
	var before: Dictionary = _capture_body_states(reg)
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	service.advance_to_time(3600.0, 3600.0)
	var after: Dictionary = _capture_body_states(reg)

	for id in before.keys():
		var b: Dictionary = before[id]
		var a: Dictionary = after[id]
		ctx.assert_true(b.get("position") == a.get("position"), "Asteroiden mutieren keine Major-Body-Positionen")
		ctx.assert_true(b.get("velocity") == a.get("velocity"), "Asteroiden mutieren keine Major-Body-Velocities")
		ctx.assert_true(int(b.get("mode", -1)) == int(a.get("mode", -2)), "Asteroiden mutieren keinen Major-Body-Orbitmodus")

	service.free()
	reg.free()


static func _test_anchor_id_stays_stable(ctx) -> void:
	var reg := _make_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	var before: Dictionary = _anchors_by_id(service.get_state_snapshot().get("entries", []))
	for id in before.keys():
		ctx.assert_true(before[id] == &"root_a", "V1.1-Anchor ist initial der Root")
	for step in range(8):
		service.advance_to_time(float(step + 1) * 900.0, 900.0)
	var after: Dictionary = _anchors_by_id(service.get_state_snapshot().get("entries", []))

	ctx.assert_true(before.size() == after.size(), "Anchor-Stabilitaet behaelt alle aktiven Test-Asteroiden")
	for id in before.keys():
		ctx.assert_true(before[id] == after[id], "V1 fuehrt keinen Anchor-Switch durch")

	service.free()
	reg.free()


static func _test_black_hole_mu_fit_interpolates_and_clamps(ctx) -> void:
	var reg := _make_bh_fit_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_fit", [&"root_fit"], 0.0)
	var root_def: BodyDef = reg.get_def(&"root_fit")
	var mu_a: float = AsteroidSimulationServiceScript._authored_orbit_mu_m3ps2(1.0e11, 4.0e4)
	var mu_b: float = AsteroidSimulationServiceScript._authored_orbit_mu_m3ps2(4.0e11, 1.0e5)

	ctx.assert_almost(float(service.call("_black_hole_fitted_mu_m3ps2", root_def, 1.0e11)), mu_a, mu_a * 1.0e-6,
		"BH-mu-fit trifft den inneren authored Sternorbit-Samplepunkt")
	ctx.assert_almost(float(service.call("_black_hole_fitted_mu_m3ps2", root_def, 4.0e11)), mu_b, mu_b * 1.0e-6,
		"BH-mu-fit trifft den aeusseren authored Sternorbit-Samplepunkt")
	var mid_mu: float = float(service.call("_black_hole_fitted_mu_m3ps2", root_def, 2.0e11))
	ctx.assert_true(mid_mu > minf(mu_a, mu_b) and mid_mu < maxf(mu_a, mu_b),
		"BH-mu-fit interpoliert zwischen den authored Sternorbit-Samples")
	ctx.assert_almost(float(service.call("_black_hole_fitted_mu_m3ps2", root_def, 1.0e9)), mu_a, mu_a * 1.0e-6,
		"BH-mu-fit klemmt unterhalb der Sample-Spanne")
	ctx.assert_almost(float(service.call("_black_hole_fitted_mu_m3ps2", root_def, 1.0e13)), mu_b, mu_b * 1.0e-6,
		"BH-mu-fit klemmt oberhalb der Sample-Spanne")

	service.free()
	reg.free()


static func _test_influence_index_uses_asteroid_effective_mu(ctx) -> void:
	var reg := _make_bh_fit_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_fit", [&"root_fit"], 0.0)
	var zones: Array = service.call("_influence_zones_for_root", &"root_fit")
	var bh_zone: Dictionary = _zone_by_id(zones, &"root_fit")
	var star_zone: Dictionary = _zone_by_id(zones, &"fit_star_a")
	var planet_zone: Dictionary = _zone_by_id(zones, &"fit_planet_ignored")

	ctx.assert_true(not bh_zone.is_empty(), "Influence-Index enthaelt den Root-BH")
	ctx.assert_true(not star_zone.is_empty(), "Influence-Index enthaelt direkte Sterne")
	ctx.assert_true(not planet_zone.is_empty(), "Influence-Index enthaelt Planeten desselben Roots")
	ctx.assert_true(absf(float(bh_zone.get("mu_m3ps2", 0.0)) - UnitSystem.mu_from_mass(reg.get_def(&"root_fit").mass_kg)) > 1.0,
		"BH-Zone nutzt asteroid-internes effective_mu statt BodyDef.mass_kg")
	var bh_samples: Array = bh_zone.get("bh_mu_samples", [])
	ctx.assert_true(bh_samples.size() == 2,
		"BH-Zone cached nur direkte authored Sternkind-Samples fuer den Fit")
	for sample in bh_samples:
		var sample_id: StringName = sample.get("id", StringName("")) if typeof(sample) == TYPE_DICTIONARY else StringName("")
		var sample_def: BodyDef = reg.get_def(sample_id)
		ctx.assert_true(sample_def != null and sample_def.kind == BodyType.Kind.STAR and sample_def.parent_id == &"root_fit",
			"BH-Fit-Sample stammt von einem direkten Sternkind des Root-BH")
	ctx.assert_almost(float(star_zone.get("mu_m3ps2", 0.0)), UnitSystem.mu_from_mass(reg.get_def(&"fit_star_a").mass_kg), 1.0e-3,
		"STAR-Zone nutzt weiter UnitSystem.mu_from_mass")
	ctx.assert_almost(float(planet_zone.get("mu_m3ps2", 0.0)), UnitSystem.mu_from_mass(reg.get_def(&"fit_planet_ignored").mass_kg), 1.0e-3,
		"PLANET-Zone nutzt weiter UnitSystem.mu_from_mass")
	for zone in zones:
		if typeof(zone) != TYPE_DICTIONARY:
			continue
		var id: StringName = zone.get("id", StringName(""))
		ctx.assert_true(id == StringName("") or _root_id_of(reg, id) == &"root_fit",
			"Influence-Index enthaelt nur Bodies des aktiven Roots")

	service.free()
	reg.free()


static func _test_black_holes_steer_inside_explicit_influence(ctx) -> void:
	var reg := _make_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	var state = service._states_by_id[service._state_order[0]]
	state.root_id = &"root_a"
	state.anchor_id = &"root_a"
	state.current_attractor_ids.clear()
	state.x_m = float(service.call("_influence_radius_m", reg.get_def(&"root_a"))) * 0.5
	state.y_m = 0.0
	state.z_m = 0.0
	service._relative_state_cache.clear()

	var selected: Array[StringName] = service.call("_select_attractors_for", state)
	ctx.assert_true(selected.has(&"root_a"),
		"Schwarze Loecher lenken Asteroiden innerhalb ihres expliziten Einflussradius")

	state.current_attractor_ids.clear()
	state.x_m = float(service.call("_influence_radius_m", reg.get_def(&"root_a"))) * 1.25
	service._relative_state_cache.clear()
	selected = service.call("_select_attractors_for", state)
	ctx.assert_true(not selected.has(&"root_a"),
		"ausserhalb des BH-Einflussradius gibt es keine unbegrenzte Root-Dauerschwerkraft")

	service.free()
	reg.free()


static func _test_black_hole_zone_entry_has_no_empty_refresh_delay(ctx) -> void:
	var reg := _make_bh_fit_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_fit", [&"root_fit"], 0.0)
	var state = service._states_by_id[service._state_order[0]]
	state.root_id = &"root_fit"
	state.anchor_id = &"root_fit"
	state.current_attractor_ids.clear()
	state.x_m = float(service.call("_influence_radius_m", reg.get_def(&"root_fit"))) * 0.5
	state.y_m = 0.0
	state.z_m = 0.0
	state.vx_mps = 0.0
	state.vy_mps = 0.0
	state.vz_mps = 0.0
	service._perf_counters[AsteroidSimulationServiceScript.PERF_KEY_ADVANCE_TICKS] = 3
	service.advance_to_time(1.0, 1.0)

	ctx.assert_true(state.current_attractor_ids.has(&"root_fit"),
		"leeres Attractor-Set aktiviert BH-Zone im naechsten Tick ohne Refresh-Verzoegerung")

	service.free()
	reg.free()


static func _test_black_hole_flyby_curves_without_clean_capture(ctx) -> void:
	var reg := _make_bh_fit_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_fit", [&"root_fit"], 0.0)
	var root_def: BodyDef = reg.get_def(&"root_fit")
	var near_state = service._states_by_id[service._state_order[0]]
	_prepare_bh_flyby_state(near_state, -2.0e11, 6.0e10, 2.5e7)
	var linear_near_y: float = near_state.y_m + near_state.vy_mps * 8000.0
	service.advance_to_time(8000.0, 8000.0)
	var near_deflection: float = absf(near_state.y_m - linear_near_y)
	var near_r: float = sqrt(near_state.x_m * near_state.x_m + near_state.y_m * near_state.y_m + near_state.z_m * near_state.z_m)
	var near_v2: float = near_state.vx_mps * near_state.vx_mps + near_state.vy_mps * near_state.vy_mps + near_state.vz_mps * near_state.vz_mps
	var near_mu: float = float(service.call("_asteroid_effective_mu_m3ps2", root_def, near_r))
	var near_energy: float = 0.5 * near_v2 - near_mu / maxf(near_r, 1.0)

	service.reset_for_world(&"scope_fit_far", [&"root_fit"], 0.0)
	var far_state = service._states_by_id[service._state_order[0]]
	_prepare_bh_flyby_state(far_state, -2.0e11, 3.0e11, 2.5e7)
	var linear_far_y: float = far_state.y_m + far_state.vy_mps * 8000.0
	service.advance_to_time(8000.0, 8000.0)
	var far_deflection: float = absf(far_state.y_m - linear_far_y)

	ctx.assert_true(near_deflection > 1.0e9,
		"naher BH-Flyby weicht sichtbar von linearer Drift ab")
	ctx.assert_true(near_energy > 0.0,
		"schneller BH-Flyby bleibt ungebunden statt eine saubere Kreisbahn zu schliessen")
	ctx.assert_true(near_deflection > far_deflection * 2.0,
		"naeherer BH-Pass erzeugt staerkere Ablenkung als weiter Pass")

	service.free()
	reg.free()


static func _test_initial_spawn_has_radial_drift_and_fast_flybys(ctx) -> void:
	var reg := _make_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)

	var drift_count: int = 0
	var fast_flyby_count: int = 0
	for entry in service.get_state_snapshot().get("entries", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var spawn_origin_id: StringName = entry.get("spawn_origin_id", StringName(""))
		var origin: Dictionary = _resolve_relative(reg, spawn_origin_id, &"root_a")
		ctx.assert_true(bool(origin.get("ok", false)), "Spawn-Origin laesst sich im Root-Frame aufloesen")
		var x: float = float(entry.get("x_m", 0.0)) - float(origin.get("x_m", 0.0))
		var y: float = float(entry.get("y_m", 0.0)) - float(origin.get("y_m", 0.0))
		var vx: float = float(entry.get("vx_mps", 0.0)) - float(origin.get("vx_mps", 0.0))
		var vy: float = float(entry.get("vy_mps", 0.0)) - float(origin.get("vy_mps", 0.0))
		var radius: float = maxf(sqrt(x * x + y * y), 1.0)
		var radial_speed: float = (x * vx + y * vy) / radius
		var local_speed: float = sqrt(vx * vx + vy * vy)
		var origin_def: BodyDef = reg.get_def(spawn_origin_id)
		var circular_speed: float = sqrt(UnitSystem.mu_from_mass(origin_def.mass_kg) / radius) if origin_def != null else INF
		if absf(radial_speed) > 10.0:
			drift_count += 1
		if local_speed > circular_speed * 1.12:
			fast_flyby_count += 1
	ctx.assert_true(drift_count > 0,
		"Initiale Asteroiden-Velocities sind nicht alle perfekte Kreisbahn-Tangenten")
	ctx.assert_true(fast_flyby_count > 0,
		"Initiale Asteroiden enthalten schnellere Flybys statt nur gebundene Kreisbahnen")

	service.free()
	reg.free()


static func _test_free_drift_without_attractors_is_linear(ctx) -> void:
	var reg := _make_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	var state = service._states_by_id[service._state_order[0]]
	state.root_id = &"root_a"
	state.anchor_id = &"root_a"
	state.current_attractor_ids.clear()
	state.x_m = 1.0e13
	state.y_m = -2.0e12
	state.z_m = 7.0e8
	state.vx_mps = 1234.0
	state.vy_mps = -987.0
	state.vz_mps = 55.0

	service.advance_to_time(12.0, 12.0)

	ctx.assert_almost(state.x_m, 1.0e13 + 1234.0 * 12.0, 1.0e-3,
		"Freiflug ohne Attraktoren integriert x linear")
	ctx.assert_almost(state.y_m, -2.0e12 - 987.0 * 12.0, 1.0e-3,
		"Freiflug ohne Attraktoren integriert y linear")
	ctx.assert_almost(state.vx_mps, 1234.0, 1.0e-9,
		"Freiflug laesst Velocity unveraendert")
	ctx.assert_true(state.current_attractor_ids.is_empty(),
		"ausserhalb aller Einflussradien bleibt das Attractor-Set leer")
	ctx.assert_true(int(service.get_perf_counter_snapshot().get(AsteroidSimulationServiceScript.PERF_KEY_FREE_DRIFT_COUNT, 0)) > 0,
		"Freiflug erhoeht den free_drift_count")

	service.free()
	reg.free()


static func _test_influence_radius_and_hysteresis(ctx) -> void:
	var reg := _make_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	var state = service._states_by_id[service._state_order[0]]
	state.root_id = &"root_a"
	state.anchor_id = &"root_a"
	state.current_attractor_ids.clear()
	reg.get_def(&"star_b").mass_kg = 1.0
	var star_state: BodyState = reg.get_state(&"star_a")
	star_state.position_parent_frame_m = Vector3.ZERO
	star_state.velocity_parent_frame_mps = Vector3.ZERO
	var planet_ids: Array[StringName] = [&"planet_a", &"planet_b", &"planet_c", &"planet_d", &"planet_e"]
	for idx in range(5):
		var planet_id: StringName = planet_ids[idx]
		reg.get_def(planet_id).mass_kg = UnitSystem.EARTH_MASS_KG
		var planet_state: BodyState = reg.get_state(planet_id)
		planet_state.position_parent_frame_m = Vector3(1.06e11 + float(idx) * 1.0e8, 0.0, 0.0)
		planet_state.velocity_parent_frame_mps = Vector3.ZERO

	state.x_m = 1.06e11
	state.y_m = 0.0
	state.z_m = 0.0
	service._relative_state_cache.clear()

	var selected: Array[StringName] = service.call("_select_attractors_for", state)
	ctx.assert_true(selected.size() <= AsteroidSimulationServiceScript.MAX_ATTRACTORS,
		"Attractor-Auswahl bleibt auf MAX_ATTRACTORS gecappt")
	ctx.assert_true(selected.has(&"star_a") and selected.has(&"planet_a"),
		"Eintritt in Stern-/Planeten-Einflussradien aktiviert passende Attraktoren")

	var moon_state: BodyState = reg.get_state(&"moon_a")
	moon_state.position_parent_frame_m = Vector3(1.0e8, 0.0, 0.0)
	moon_state.velocity_parent_frame_mps = Vector3.ZERO
	state.current_attractor_ids.clear()
	state.x_m = 1.061e11
	service._relative_state_cache.clear()
	var moon_selected: Array[StringName] = service.call("_select_attractors_for", state)
	ctx.assert_true(moon_selected.has(&"moon_a"),
		"Eintritt in einen Mond-Einflussradius aktiviert den Mond als Attraktor")

	var current_attractors: Array[StringName] = [&"planet_a"]
	state.current_attractor_ids = current_attractors
	state.x_m = 1.06e11 + float(service.call("_influence_radius_m", reg.get_def(&"planet_a"))) * 1.10
	var hysteresis_selected: Array[StringName] = service.call("_select_attractors_for", state)
	ctx.assert_true(hysteresis_selected.has(&"planet_a"),
		"Exit-Hysterese behaelt einen aktuellen Planeten am Einflussrand")

	state.current_attractor_ids = current_attractors
	state.x_m = 1.06e11 + float(service.call("_influence_radius_m", reg.get_def(&"planet_a"))) * 1.20
	var exited: Array[StringName] = service.call("_select_attractors_for", state)
	ctx.assert_true(not exited.has(&"planet_a"),
		"ausserhalb des Exit-Radius faellt der Planet aus dem Attractor-Set")

	state.current_attractor_ids.clear()
	state.x_m = 1.0e13
	state.y_m = 0.0
	state.z_m = 0.0
	var empty_selected: Array[StringName] = service.call("_select_attractors_for", state)
	ctx.assert_true(empty_selected.is_empty(),
		"ausserhalb aller Einflussradien gibt es keine globale Dauerschwerkraft")

	service.free()
	reg.free()


static func _test_far_retire_threshold_deactivates(ctx) -> void:
	var reg := _make_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	var state = service._states_by_id[service._state_order[0]]
	state.root_id = &"root_a"
	state.anchor_id = &"root_a"
	state.current_attractor_ids.clear()
	state.x_m = 5.0e15
	state.y_m = 0.0
	state.z_m = 0.0
	state.vx_mps = 0.0
	state.vy_mps = 0.0
	state.vz_mps = 0.0

	service.advance_to_time(1.0, 1.0)

	ctx.assert_true(state.is_active, "Asteroid bleibt unterhalb der neuen Numerik-Grenze aktiv")
	ctx.assert_true(int(service.get_perf_counter_snapshot().get(AsteroidSimulationServiceScript.PERF_KEY_FAR_RETIRED_COUNT, 0)) == 0,
		"Far-Retire zaehlt nicht unterhalb der Numerik-Grenze")

	state.x_m = 1.5e16
	state.current_attractor_ids.clear()
	service.advance_to_time(2.0, 1.0)

	ctx.assert_true(not state.is_active, "Far-Retire deaktiviert Asteroiden jenseits der Numerik-Grenze")
	ctx.assert_true(int(service.get_perf_counter_snapshot().get(AsteroidSimulationServiceScript.PERF_KEY_FAR_RETIRED_COUNT, 0)) == 1,
		"Far-Retire erhoeht den Counter")
	ctx.assert_true(int(service.get_state_snapshot().get("count", 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT - 1,
		"far-retired Asteroiden verschwinden aus dem State-Snapshot")

	service.free()
	reg.free()


static func _test_sync_resident_roots_lifecycle_is_idempotent(ctx) -> void:
	var reg := _make_two_root_registry()
	var service = _make_service(reg)
	service.reset_for_world(&"scope_a", [&"root_a"], 0.0)
	var initial_revision: int = int(service.get_state_snapshot().get("revision", -1))
	service.sync_resident_roots(&"scope_a", [&"root_a"], 10.0)
	var same_revision: int = int(service.get_state_snapshot().get("revision", -1))
	ctx.assert_true(same_revision == initial_revision,
		"wiederholtes sync_resident_roots mit gleicher Root-Liste ist ein No-op")

	service.sync_resident_roots(&"scope_a", [&"root_a", &"root_b"], 20.0)
	ctx.assert_true(int(service.get_state_snapshot().get("count", 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT * 2,
		"neue residente Roots spawnen eigene Asteroiden")
	var spawned_after_two_roots: int = int(service.get_perf_counter_snapshot().get(AsteroidSimulationServiceScript.PERF_KEY_SPAWNED, 0))
	service.sync_resident_roots(&"scope_a", [&"root_b"], 30.0)
	ctx.assert_true(int(service.get_state_snapshot().get("count", 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT,
		"nicht aktive Roots verschwinden aus dem sichtbaren State-Snapshot")
	var parked_perf: Dictionary = service.get_perf_counter_snapshot()
	ctx.assert_true(int(parked_perf.get("total_state_count", 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT * 2,
		"Root-Wechsel parkt vorhandene Asteroiden statt sie zu loeschen")
	ctx.assert_true(int(parked_perf.get(AsteroidSimulationServiceScript.PERF_KEY_DESPAWNED, 0)) == 0,
		"Fokus-/Root-Wechsel zaehlt nicht als Asteroiden-Despawn")

	service.sync_resident_roots(&"scope_a", [&"root_a"], 40.0)
	ctx.assert_true(int(service.get_perf_counter_snapshot().get(AsteroidSimulationServiceScript.PERF_KEY_SPAWNED, 0)) == spawned_after_two_roots,
		"Rueckkehr zu einem geparkten Root respawnt keine Asteroiden")

	service.free()
	reg.free()


static func _test_single_world_spawns_without_streaming_controller(ctx) -> void:
	var loader = load("res://src/sim/world/world_loader.gd").new()
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	var loaded: bool = loader.load_named_world(WorldLoader.SAMPLE_SYSTEM_ID, reg)
	ctx.assert_true(loaded, "sample_system laedt fuer den Single-World-Spawn-Test")
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	var time_service = load("res://src/core/time/time_service.gd").new()
	orbit_service.configure(reg, time_service)
	orbit_service.recompute_all_at_time(0.0)
	var service = _make_service(reg)
	service.reset_for_world(WorldLoader.SAMPLE_SYSTEM_ID, _root_ids(reg), 0.0)

	ctx.assert_true(int(service.get_state_snapshot().get("count", 0)) > 0,
		"Single-World-Pfad spawnt Asteroiden ohne GalaxyStreamingController")

	service.free()
	orbit_service.free()
	time_service.free()
	reg.free()
	loader.free()


static func _test_catalog_spawn_creates_states_for_nonresident_roots(ctx) -> void:
	var reg := _make_registry()
	var service = _make_service(reg)
	var catalog: Dictionary = _catalog_for_nonresident_roots()
	service.set_root_spawn_catalog(&"scope_catalog", catalog)
	service.reset_for_world(&"scope_catalog", [&"root_a", &"root_b", &"root_c"], 100.0)

	var snapshot: Dictionary = service.get_state_snapshot()
	var counts: Dictionary = _entry_counts_by_root(snapshot.get("entries", []))
	ctx.assert_true(int(snapshot.get("count", 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT * 3,
		"Catalog-tracked Roots erzeugen auch ohne Registry-Residency Asteroiden")
	ctx.assert_true(int(counts.get(&"root_b", 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT,
		"nicht-residenter Catalog-Root root_b hat sein volles Asteroiden-Budget")
	ctx.assert_true(int(counts.get(&"root_c", 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT,
		"nicht-residenter Catalog-Root root_c hat sein volles Asteroiden-Budget")
	var perf: Dictionary = service.get_perf_counter_snapshot()
	ctx.assert_true(int(perf.get(AsteroidSimulationServiceScript.PERF_KEY_ACTIVE_ASTEROIDS, 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT * 3,
		"active_asteroids zaehlt alle getrackten Root-Asteroiden")
	ctx.assert_true(int(perf.get("total_state_count", 0)) == AsteroidSimulationServiceScript.ASTEROIDS_PER_ROOT * 3,
		"total_state_count zaehlt alle gespeicherten Root-Asteroiden")
	ctx.assert_true(service.call("_influence_zones_for_root", &"root_b").is_empty(),
		"nicht-residente Catalog-Roots starten ohne lokale Influence-Zonen")

	service.free()
	reg.free()


static func _test_nonresident_catalog_asteroids_drift_linearly(ctx) -> void:
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	var service = _make_service(reg)
	var catalog: Dictionary = {&"root_b": _catalog_root_defs(&"root_b", &"star_c", &"planet_f", 2.0e10, 9.0e10, 0.1)}
	service.set_root_spawn_catalog(&"scope_catalog", catalog)
	service.reset_for_world(&"scope_catalog", [&"root_b"], 50.0)
	var state = _state_for_root(service, &"root_b")
	ctx.assert_true(state != null, "nicht-residenter Catalog-Root erzeugt einen testbaren State")
	var before_x: float = state.x_m
	var before_y: float = state.y_m
	var before_z: float = state.z_m
	var vx: float = state.vx_mps
	var vy: float = state.vy_mps
	var vz: float = state.vz_mps

	service.advance_to_time(62.0, 12.0)

	ctx.assert_almost(state.x_m, before_x + vx * 12.0, 1.0e-3,
		"nicht-residente Asteroiden driften ohne Influence-Zonen linear in x")
	ctx.assert_almost(state.y_m, before_y + vy * 12.0, 1.0e-3,
		"nicht-residente Asteroiden driften ohne Influence-Zonen linear in y")
	ctx.assert_almost(state.z_m, before_z + vz * 12.0, 1.0e-3,
		"nicht-residente Asteroiden driften ohne Influence-Zonen linear in z")
	ctx.assert_true(state.current_attractor_ids.is_empty(),
		"nicht-residente Asteroiden bauen kein Attractor-Set aus leerem Index")

	service.free()
	reg.free()


static func _test_catalog_spawn_uses_analytic_origin_geometry(ctx) -> void:
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	var service = _make_service(reg)
	var planet_axis_m: float = 1.2e11
	var t_s: float = 1234.0
	var catalog: Dictionary = {&"root_b": _catalog_root_defs(&"root_b", &"star_c", &"planet_f", 3.0e10, planet_axis_m, 0.25)}
	service.set_root_spawn_catalog(&"scope_catalog", catalog)
	service.reset_for_world(&"scope_catalog", [&"root_b"], t_s)
	var entries: Array = service.get_state_snapshot().get("entries", [])
	var entry: Dictionary = entries[0]
	var origin: Dictionary = service.call("_resolve_catalog_body_relative_to_root", &"star_c", &"root_b", t_s)
	ctx.assert_true(bool(origin.get("ok", false)), "Catalog-Spawn-Origin wird analytisch im Root-Frame aufgeloest")
	ctx.assert_true(absf(float(origin.get("vx_mps", 0.0))) > 1.0 or absf(float(origin.get("vy_mps", 0.0))) > 1.0,
		"Catalog-Spawn-Origin hat eine analytische Velocity statt v=0-Fallback")
	ctx.assert_true(entry.get("spawn_origin_id", StringName("")) == &"star_c",
		"Catalog-Spawn nutzt den Stern als Spawn-Origin")
	var dx: float = float(entry.get("x_m", 0.0)) - float(origin.get("x_m", 0.0))
	var dy: float = float(entry.get("y_m", 0.0)) - float(origin.get("y_m", 0.0))
	var dz: float = float(entry.get("z_m", 0.0)) - float(origin.get("z_m", 0.0))
	var radius_m: float = sqrt(dx * dx + dy * dy + dz * dz)
	ctx.assert_true(radius_m >= planet_axis_m * 0.72 and radius_m <= planet_axis_m * 1.35,
		"Catalog-Spawn-Geometrie nutzt Planet-/Moon-Distanzen statt Fallback-Belt")

	service.free()
	reg.free()


static func _test_major_body_residency_forces_influence_rebuild(ctx) -> void:
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	var service = _make_service(reg)
	var root_defs: Array[BodyDef] = _catalog_root_defs(&"root_b", &"star_c", &"planet_f", 2.0e10, 9.0e10, 0.1)
	service.set_root_spawn_catalog(&"scope_catalog", {&"root_b": root_defs})
	service.reset_for_world(&"scope_catalog", [&"root_b"], 0.0)
	ctx.assert_true(service.call("_influence_zones_for_root", &"root_b").is_empty(),
		"initial nicht-residenter Catalog-Root hat einen leeren Influence-Index")

	for def in root_defs:
		reg.register_body(def)
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	var time_service = load("res://src/core/time/time_service.gd").new()
	orbit_service.configure(reg, time_service)
	orbit_service.recompute_all_at_time(0.0)
	service.set_major_body_resident_roots([&"root_b"], 0.0)
	var zones: Array = service.call("_influence_zones_for_root", &"root_b")
	ctx.assert_true(not zones.is_empty(),
		"Major-Body-Residency erzwingt Rebuild auch wenn vorher eine leere Zone-Liste existierte")

	var state = _state_for_root(service, &"root_b")
	state.current_attractor_ids.clear()
	state.x_m = float(service.call("_influence_radius_m", reg.get_def(&"root_b"))) * 0.5
	state.y_m = 0.0
	state.z_m = 0.0
	service._relative_state_cache.clear()
	var selected: Array[StringName] = service.call("_select_attractors_for", state)
	ctx.assert_true(selected.has(&"root_b"),
		"frisch residente Root-Asteroiden sehen nach dem Rebuild wieder lokale Attractor-Kandidaten")

	service.free()
	orbit_service.free()
	time_service.free()
	reg.free()


static func _test_sim_asteroids_imports_no_runtime_tools_or_scenes(ctx) -> void:
	var dir_path: String = "res://src/sim/asteroids"
	for file_name in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".gd"):
			continue
		var file := FileAccess.open("%s/%s" % [dir_path, file_name], FileAccess.READ)
		ctx.assert_true(file != null, "Asteroid-Sim-Datei ist lesbar")
		var text: String = file.get_as_text()
		file.close()
		ctx.assert_true(text.find("res://src/runtime/") < 0, "sim/asteroids importiert kein runtime")
		ctx.assert_true(text.find("res://src/tools/") < 0, "sim/asteroids importiert keine tools")
		ctx.assert_true(text.find("res://scenes/") < 0, "sim/asteroids importiert keine scenes")
		ctx.assert_true(text.find("RigidBody") < 0 and text.find("Area2D") < 0 and text.find("Area3D") < 0,
			"sim/asteroids nutzt keine Physik-Engine")


static func _capture_body_states(registry: Node) -> Dictionary:
	var out: Dictionary = {}
	for id in registry.get_update_order_ref():
		var state: BodyState = registry.get_state(id)
		out[id] = {
			"position": state.position_parent_frame_m,
			"velocity": state.velocity_parent_frame_mps,
			"mode": state.current_mode,
		}
	return out


static func _state_for_root(service, root_id: StringName):
	for id in service._state_order:
		var state = service._states_by_id.get(id, null)
		if state != null and state.root_id == root_id:
			return state
	return null


static func _entry_counts_by_root(entries: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var root_id: StringName = entry.get("root_id", StringName(""))
		out[root_id] = int(out.get(root_id, 0)) + 1
	return out


static func _anchors_by_id(entries: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY:
			out[entry.get("id", StringName(""))] = entry.get("anchor_id", StringName(""))
	return out


static func _root_ids(registry: Node) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in registry.get_update_order_ref():
		var def: BodyDef = registry.get_def(id)
		if def != null and def.is_root():
			out.append(id)
	return out


static func _zone_by_id(zones: Array, id: StringName) -> Dictionary:
	for zone in zones:
		if typeof(zone) == TYPE_DICTIONARY and zone.get("id", StringName("")) == id:
			return zone
	return {}


static func _root_id_of(registry: Node, body_id: StringName) -> StringName:
	var topology := UniverseTopology.new()
	topology.configure(registry)
	return topology.root_id_of(body_id)


static func _prepare_bh_flyby_state(state, x_m: float, y_m: float, vx_mps: float) -> void:
	state.root_id = &"root_fit"
	state.anchor_id = &"root_fit"
	state.current_attractor_ids.clear()
	state.x_m = x_m
	state.y_m = y_m
	state.z_m = 0.0
	state.vx_mps = vx_mps
	state.vy_mps = 0.0
	state.vz_mps = 0.0


static func _resolve_relative(registry: Node, body_id: StringName, anchor_id: StringName) -> Dictionary:
	var resolver = RelativeStateResolverScript.new()
	resolver.configure(registry)
	return resolver.resolve_body_relative_to_anchor(body_id, anchor_id)
