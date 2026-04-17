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
	_test_authored_positions_finite(ctx)
	_test_kepler_positions_finite(ctx)
	_test_positions_differ_over_time(ctx)
	_test_focus_stability(ctx)


# --- helpers ---

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


# --- tests ---

static func _test_body_count(ctx) -> void:
	var reg = _make_loaded_registry()
	ctx.assert_true(reg.body_count() == 9, "body_count == 9")
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
	ctx.assert_true(by_id[&"alpha"].kind == BodyType.Kind.STAR, "alpha ist STAR")
	ctx.assert_true(by_id[&"beta"].kind == BodyType.Kind.STAR, "beta ist STAR")
	for id in [&"alpha_i", &"alpha_ii", &"beta_i", &"beta_ii"]:
		ctx.assert_true(by_id[id].kind == BodyType.Kind.PLANET, "%s ist PLANET" % id)
	for id in [&"alpha_i_m", &"beta_i_m"]:
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
	var i := {}
	for idx in order.size():
		i[order[idx]] = idx
	ctx.assert_true(i[&"obsidian"] < i[&"alpha"], "obsidian < alpha")
	ctx.assert_true(i[&"obsidian"] < i[&"beta"], "obsidian < beta")
	ctx.assert_true(i[&"alpha"] < i[&"alpha_i"], "alpha < alpha_i")
	ctx.assert_true(i[&"alpha"] < i[&"alpha_ii"], "alpha < alpha_ii")
	ctx.assert_true(i[&"alpha_i"] < i[&"alpha_i_m"], "alpha_i < alpha_i_m")
	ctx.assert_true(i[&"beta"] < i[&"beta_i"], "beta < beta_i")
	ctx.assert_true(i[&"beta_i"] < i[&"beta_i_m"], "beta_i < beta_i_m")
	reg.free()


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
	for id in [&"obsidian", &"alpha", &"beta", &"alpha_i", &"alpha_ii",
			&"alpha_i_m", &"beta_i", &"beta_ii", &"beta_i_m"]:
		bubble.set_focus(id)
		ctx.assert_true(bubble.get_focus() == id, "focus stabil nach set_focus: %s" % id)
		var pos: Vector3 = bubble.compose_view_position_m(id)
		ctx.assert_true(is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z),
			"compose_view_position_m finite bei focus %s" % id)
	bubble.free()
	reg.free()
