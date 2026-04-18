extends RefCounted

# Unit-Tests fuer StarterWorld. Prueft Hierarchie-Invarianten, Orbit-Mathematik
# und Fokus-Stabilitaet. Kein Autoload, kein voll konfigurierter OrbitService.
# Positionen werden direkt ueber OrbitMath getestet, um Autoload-Abhaengigkeit
# zu vermeiden.


static func run(ctx) -> void:
	ctx.current_suite = "test_starter_world"
	_test_body_count(ctx)
	_test_root_is_obsidian(ctx)
	_test_no_other_roots(ctx)
	_test_kind_assignments(ctx)
	_test_parent_chains_valid(ctx)
	_test_topological_order(ctx)
	_test_world_model_fields(ctx)
	_test_bh_star_authored_orbits_unique(ctx)
	_test_planet_semi_major_axes_unique_per_star(ctx)
	_test_gamma_red_dwarf_profile_and_compact_orbits(ctx)
	_test_gamma_iv_stays_within_local_hill_sphere_guardrail(ctx)
	_test_authored_positions_finite(ctx)
	_test_kepler_positions_finite(ctx)
	_test_positions_differ_over_time(ctx)
	_test_focus_stability(ctx)


static func _make_loaded_registry():
	var reg = load("res://src/sim/universe/universe_registry.gd").new()
	var defs: Array[BodyDef] = StarterWorld.build()
	for d in defs:
		reg.register_body(d)
	return reg


static func _defs_by_id() -> Dictionary:
	var out: Dictionary = {}
	for d in StarterWorld.build():
		out[d.id] = d
	return out


static func _expected_order() -> Array[StringName]:
	return [
		&"obsidian",
		&"alpha",
		&"beta",
		&"gamma",
		&"delta",
		&"alpha_i",
		&"alpha_ii",
		&"alpha_iii",
		&"alpha_i_m",
		&"beta_i",
		&"beta_ii",
		&"beta_i_m",
		&"gamma_i",
		&"gamma_ii",
		&"gamma_iii",
		&"gamma_iv",
		&"gamma_ii_m",
		&"delta_i",
	]


static func _planet_ids_for_star(star_id: StringName) -> Array[StringName]:
	match star_id:
		&"alpha":
			return [&"alpha_i", &"alpha_ii", &"alpha_iii"]
		&"beta":
			return [&"beta_i", &"beta_ii"]
		&"gamma":
			return [&"gamma_i", &"gamma_ii", &"gamma_iii", &"gamma_iv"]
		&"delta":
			return [&"delta_i"]
	return []


static func _test_body_count(ctx) -> void:
	var reg = _make_loaded_registry()
	ctx.assert_true(reg.body_count() == 18, "body_count == 18")
	reg.free()


static func _test_root_is_obsidian(ctx) -> void:
	var by_id := _defs_by_id()
	var obs: BodyDef = by_id.get(&"obsidian", null)
	ctx.assert_true(obs != null, "obsidian existiert")
	ctx.assert_true(obs.parent_id == &"", "obsidian.parent_id ist leer (Wurzel)")
	ctx.assert_true(obs.orbit_profile == null, "obsidian hat kein orbit_profile")


static func _test_no_other_roots(ctx) -> void:
	for d in StarterWorld.build():
		if d.id == &"obsidian":
			continue
		ctx.assert_true(d.parent_id != &"", "%s hat parent_id (kein stiller Root)" % d.id)
		ctx.assert_true(d.orbit_profile != null, "%s hat orbit_profile" % d.id)


static func _test_kind_assignments(ctx) -> void:
	var by_id := _defs_by_id()
	ctx.assert_true(by_id[&"obsidian"].kind == BodyType.Kind.BLACK_HOLE, "obsidian ist BLACK_HOLE")
	for id in [&"alpha", &"beta", &"gamma", &"delta"]:
		ctx.assert_true(by_id[id].kind == BodyType.Kind.STAR, "%s ist STAR" % id)
	for id in [
		&"alpha_i",
		&"alpha_ii",
		&"alpha_iii",
		&"beta_i",
		&"beta_ii",
		&"gamma_i",
		&"gamma_ii",
		&"gamma_iii",
		&"gamma_iv",
		&"delta_i",
	]:
		ctx.assert_true(by_id[id].kind == BodyType.Kind.PLANET, "%s ist PLANET" % id)
	for id in [&"alpha_i_m", &"beta_i_m", &"gamma_ii_m"]:
		ctx.assert_true(by_id[id].kind == BodyType.Kind.MOON, "%s ist MOON" % id)


static func _test_parent_chains_valid(ctx) -> void:
	var reg = _make_loaded_registry()
	for d in StarterWorld.build():
		if d.parent_id == &"":
			continue
		ctx.assert_true(reg.has_body(d.parent_id),
			"parent '%s' von '%s' existiert in registry" % [d.parent_id, d.id])
	reg.free()


static func _test_topological_order(ctx) -> void:
	var reg = _make_loaded_registry()
	var order: Array[StringName] = reg.get_update_order()
	var expected: Array[StringName] = _expected_order()
	ctx.assert_true(order.size() == expected.size(), "update_order hat erwartete Groesse")
	for i in range(expected.size()):
		ctx.assert_true(order[i] == expected[i], "update_order[%d] == %s" % [i, expected[i]])
	reg.free()


static func _test_world_model_fields(ctx) -> void:
	var by_id := _defs_by_id()
	ctx.assert_almost(by_id[&"obsidian"].luminosity_w, 0.0, 1.0e-9, "obsidian luminosity_w == 0")
	ctx.assert_almost(by_id[&"alpha"].rotation_period_s, 25.0 * UnitSystem.DAY_S, 1.0e-6, "alpha rotation_period_s gesetzt")
	ctx.assert_almost(by_id[&"alpha"].luminosity_w, 3.0 * UnitSystem.SOLAR_LUMINOSITY_W, 1.0e12, "alpha luminosity_w gesetzt")
	ctx.assert_almost(by_id[&"alpha_i"].rotation_period_s, 0.80 * UnitSystem.DAY_S, 1.0e-6, "alpha_i rotation_period_s gesetzt")
	ctx.assert_almost(by_id[&"alpha_i"].axial_tilt_rad, 0.18, 1.0e-9, "alpha_i axial_tilt_rad gesetzt")
	ctx.assert_almost(by_id[&"alpha_i"].albedo, 0.28, 1.0e-9, "alpha_i albedo gesetzt")
	ctx.assert_almost(by_id[&"gamma"].mass_kg, 0.20 * UnitSystem.SOLAR_MASS_KG, 1.0e18, "gamma mass_kg auf Red-Dwarf-Wert gesetzt")
	ctx.assert_almost(by_id[&"gamma"].radius_m, 1.95e8, 1.0e-3, "gamma radius_m auf Red-Dwarf-Wert gesetzt")
	ctx.assert_almost(by_id[&"gamma"].luminosity_w, 0.0036 * UnitSystem.SOLAR_LUMINOSITY_W, 1.0e12, "gamma luminosity_w auf Red-Dwarf-Wert gesetzt")
	ctx.assert_almost(by_id[&"gamma_ii"].north_pole_orbit_frame_azimuth_rad, PI / 3.0, 1.0e-9, "gamma_ii saison-azimut gesetzt")
	ctx.assert_almost(by_id[&"gamma_iv"].greenhouse_delta_k, 35.0, 1.0e-9, "gamma_iv greenhouse_delta_k gesetzt")
	ctx.assert_almost(by_id[&"gamma_iv"].axial_tilt_rad, 0.26, 1.0e-9, "gamma_iv axial_tilt_rad auf habitablem Kandidatenwert gesetzt")
	ctx.assert_almost(by_id[&"gamma_iv"].orbit_profile.semi_major_axis_m, 9.0e9, 1.0e-3, "gamma_iv semi_major_axis_m auf kompakten habitablen Kandidatenorbit gesetzt")
	ctx.assert_almost(by_id[&"delta_i"].north_pole_orbit_frame_azimuth_rad, -PI / 4.0, 1.0e-9, "delta_i saison-azimut gesetzt")
	ctx.assert_almost(by_id[&"beta_ii"].rotation_period_s, 1.60 * UnitSystem.DAY_S, 1.0e-6, "beta_ii rotation_period_s gesetzt")
	ctx.assert_almost(by_id[&"beta_ii"].axial_tilt_rad, 0.61, 1.0e-9, "beta_ii axial_tilt_rad gesetzt")
	ctx.assert_almost(by_id[&"beta_ii"].albedo, 0.42, 1.0e-9, "beta_ii albedo gesetzt")


static func _test_bh_star_authored_orbits_unique(ctx) -> void:
	var by_id := _defs_by_id()
	var stars: Array[StringName] = [&"alpha", &"beta", &"gamma", &"delta"]
	var radii := {}
	var periods := {}
	var phases := {}
	for id in stars:
		var prof: OrbitProfile = by_id[id].orbit_profile
		ctx.assert_true(prof != null, "%s hat orbit_profile" % id)
		ctx.assert_true(prof.mode == OrbitMode.Kind.AUTHORED_ORBIT, "%s bleibt AUTHORED_ORBIT" % id)
		ctx.assert_true(not radii.has(prof.authored_radius_m), "%s authored_radius_m einzigartig" % id)
		ctx.assert_true(not periods.has(prof.authored_period_s), "%s authored_period_s einzigartig" % id)
		ctx.assert_true(not phases.has(prof.authored_phase_rad), "%s authored_phase_rad einzigartig" % id)
		radii[prof.authored_radius_m] = true
		periods[prof.authored_period_s] = true
		phases[prof.authored_phase_rad] = true


static func _test_planet_semi_major_axes_unique_per_star(ctx) -> void:
	var by_id := _defs_by_id()
	for star_id in [&"alpha", &"beta", &"gamma", &"delta"]:
		var seen := {}
		for planet_id in _planet_ids_for_star(star_id):
			var prof: OrbitProfile = by_id[planet_id].orbit_profile
			ctx.assert_true(prof != null, "%s hat orbit_profile" % planet_id)
			ctx.assert_true(prof.mode == OrbitMode.Kind.KEPLER_APPROX, "%s bleibt KEPLER_APPROX" % planet_id)
			ctx.assert_true(not seen.has(prof.semi_major_axis_m),
				"%s semi_major_axis_m innerhalb von %s einzigartig" % [planet_id, star_id])
			seen[prof.semi_major_axis_m] = true


static func _test_gamma_red_dwarf_profile_and_compact_orbits(ctx) -> void:
	var by_id := _defs_by_id()
	var gamma: BodyDef = by_id[&"gamma"]
	var gamma_i: BodyDef = by_id[&"gamma_i"]
	var gamma_ii: BodyDef = by_id[&"gamma_ii"]
	var gamma_iii: BodyDef = by_id[&"gamma_iii"]
	var gamma_iv: BodyDef = by_id[&"gamma_iv"]
	ctx.assert_almost(gamma.mass_kg, 0.20 * UnitSystem.SOLAR_MASS_KG, 1.0e18, "gamma bleibt explizit auf kleinem Red-Dwarf-Massenwert gepinnt")
	ctx.assert_almost(gamma.radius_m, 1.95e8, 1.0e-3, "gamma bleibt explizit auf kleinem Red-Dwarf-Radius gepinnt")
	ctx.assert_almost(gamma.luminosity_w, 0.0036 * UnitSystem.SOLAR_LUMINOSITY_W, 1.0e12, "gamma bleibt explizit auf Red-Dwarf-Luminositaet gepinnt")
	ctx.assert_almost(gamma_i.orbit_profile.semi_major_axis_m, 2.0e9, 1.0e-3, "gamma_i semi_major_axis_m gepinnt")
	ctx.assert_almost(gamma_i.orbit_profile.eccentricity, 0.05, 1.0e-9, "gamma_i eccentricity gepinnt")
	ctx.assert_almost(gamma_ii.orbit_profile.semi_major_axis_m, 4.5e9, 1.0e-3, "gamma_ii semi_major_axis_m gepinnt")
	ctx.assert_almost(gamma_ii.orbit_profile.eccentricity, 0.07, 1.0e-9, "gamma_ii eccentricity gepinnt")
	ctx.assert_almost(gamma_iii.orbit_profile.semi_major_axis_m, 7.2e9, 1.0e-3, "gamma_iii semi_major_axis_m gepinnt")
	ctx.assert_almost(gamma_iii.orbit_profile.eccentricity, 0.09, 1.0e-9, "gamma_iii eccentricity gepinnt")
	ctx.assert_almost(gamma_iv.orbit_profile.semi_major_axis_m, 9.0e9, 1.0e-3, "gamma_iv semi_major_axis_m gepinnt")
	ctx.assert_almost(gamma_iv.orbit_profile.eccentricity, 0.03, 1.0e-9, "gamma_iv eccentricity gepinnt")
	ctx.assert_almost(gamma_iv.greenhouse_delta_k, 35.0, 1.0e-9, "gamma_iv greenhouse_delta_k gepinnt")


static func _test_gamma_iv_stays_within_local_hill_sphere_guardrail(ctx) -> void:
	var by_id := _defs_by_id()
	var obsidian: BodyDef = by_id[&"obsidian"]
	var gamma: BodyDef = by_id[&"gamma"]
	var gamma_iv: BodyDef = by_id[&"gamma_iv"]
	var gamma_bh_profile: OrbitProfile = gamma.orbit_profile
	var gamma_iv_profile: OrbitProfile = gamma_iv.orbit_profile
	var r_hill_gamma: float = gamma_bh_profile.authored_radius_m * pow(
		gamma.mass_kg / (3.0 * obsidian.mass_kg),
		1.0 / 3.0
	)
	var gamma_iv_apoapsis_m: float = gamma_iv_profile.semi_major_axis_m * (1.0 + gamma_iv_profile.eccentricity)
	ctx.assert_true(
		gamma_iv_apoapsis_m <= 0.67 * r_hill_gamma,
		"gamma_iv bleibt mit Apoapsis innerhalb der lokalen Hill-Sphere-Guardrail"
	)


static func _test_authored_positions_finite(ctx) -> void:
	for d in StarterWorld.build():
		if d.orbit_profile == null:
			continue
		if d.orbit_profile.mode != OrbitMode.Kind.AUTHORED_ORBIT:
			continue
		var p := d.orbit_profile
		var pos: Vector3 = OrbitMath.authored_circular_position(
			p.authored_radius_m, p.authored_period_s, p.authored_phase_rad, 1000.0)
		ctx.assert_true(is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z),
			"AUTHORED position finite: %s" % d.id)


static func _test_kepler_positions_finite(ctx) -> void:
	var by_id := _defs_by_id()
	for d in StarterWorld.build():
		if d.orbit_profile == null:
			continue
		if d.orbit_profile.mode != OrbitMode.Kind.KEPLER_APPROX:
			continue
		var parent_def: BodyDef = by_id.get(d.parent_id, null)
		var mu: float = 0.0
		if parent_def != null:
			mu = UnitSystem.mu_from_mass(parent_def.mass_kg)
		var p := d.orbit_profile
		var pos: Vector3 = OrbitMath.kepler_position(
			p.semi_major_axis_m, p.eccentricity, p.inclination_rad,
			p.longitude_ascending_node_rad, p.argument_periapsis_rad,
			p.mean_anomaly_epoch_rad, p.epoch_s, mu, 1000.0)
		ctx.assert_true(is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z),
			"KEPLER position finite: %s" % d.id)


static func _test_positions_differ_over_time(ctx) -> void:
	var by_id := _defs_by_id()
	for d in StarterWorld.build():
		if d.orbit_profile == null:
			continue
		var p := d.orbit_profile
		var pos0: Vector3
		var pos1: Vector3
		if p.mode == OrbitMode.Kind.AUTHORED_ORBIT:
			pos0 = OrbitMath.authored_circular_position(
				p.authored_radius_m, p.authored_period_s, p.authored_phase_rad, 0.0)
			pos1 = OrbitMath.authored_circular_position(
				p.authored_radius_m, p.authored_period_s, p.authored_phase_rad,
				p.authored_period_s * 0.25)
		elif p.mode == OrbitMode.Kind.KEPLER_APPROX:
			var parent_def: BodyDef = by_id.get(d.parent_id, null)
			var mu: float = 0.0
			if parent_def != null:
				mu = UnitSystem.mu_from_mass(parent_def.mass_kg)
			var n: float = OrbitMath.mean_motion(p.semi_major_axis_m, mu)
			var period_s: float = TAU / n if n > 0.0 else 1.0e5
			pos0 = OrbitMath.kepler_position(p.semi_major_axis_m, p.eccentricity,
				p.inclination_rad, p.longitude_ascending_node_rad,
				p.argument_periapsis_rad, p.mean_anomaly_epoch_rad, p.epoch_s, mu, 0.0)
			pos1 = OrbitMath.kepler_position(p.semi_major_axis_m, p.eccentricity,
				p.inclination_rad, p.longitude_ascending_node_rad,
				p.argument_periapsis_rad, p.mean_anomaly_epoch_rad, p.epoch_s, mu,
				period_s * 0.25)
		else:
			continue
		ctx.assert_true(pos0.distance_to(pos1) > 0.0,
			"position aendert sich ueber T/4: %s" % d.id)


static func _test_focus_stability(ctx) -> void:
	var reg = _make_loaded_registry()
	var bubble = load("res://src/runtime/local_bubble/local_bubble_manager.gd").new()
	bubble.configure(reg)
	for id in reg.get_update_order():
		bubble.set_focus(id)
		ctx.assert_true(bubble.get_focus() == id, "focus stabil nach set_focus: %s" % id)
		var pos: Vector3 = bubble.compose_view_position_m(id)
		ctx.assert_true(is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z),
			"compose_view_position_m finite bei focus %s" % id)
	bubble.free()
	reg.free()
