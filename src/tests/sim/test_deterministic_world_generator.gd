extends RefCounted

const WorldGeneratorScript = preload("res://src/sim/world/deterministic_world_generator.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_deterministic_world_generator"
	_test_same_seed_builds_identical_world(ctx)
	_test_different_seed_changes_world_signature(ctx)
	_test_generated_world_keeps_parent_before_child_order(ctx)


static func _test_same_seed_builds_identical_world(ctx) -> void:
	var first_defs: Array[BodyDef] = WorldGeneratorScript.build(1337)
	var second_defs: Array[BodyDef] = WorldGeneratorScript.build(1337)
	ctx.assert_true(first_defs.size() >= 4, "deterministischer Generator baut mindestens einen kleinen Weltverbund")
	ctx.assert_true(_world_signature(first_defs) == _world_signature(second_defs), "gleicher Seed erzeugt dieselbe Welt-Signatur")


static func _test_different_seed_changes_world_signature(ctx) -> void:
	var first_defs: Array[BodyDef] = WorldGeneratorScript.build(111)
	var second_defs: Array[BodyDef] = WorldGeneratorScript.build(222)
	ctx.assert_true(_world_signature(first_defs) != _world_signature(second_defs), "unterschiedliche Seeds erzeugen unterschiedliche Welt-Signaturen")


static func _test_generated_world_keeps_parent_before_child_order(ctx) -> void:
	var defs: Array[BodyDef] = WorldGeneratorScript.build(WorldGeneratorScript.DEFAULT_SEED)
	var seen_ids: Dictionary = {}
	for def in defs:
		ctx.assert_true(not seen_ids.has(def.id), "Generator vergibt keine doppelten IDs")
		if def.parent_id != StringName(""):
			ctx.assert_true(seen_ids.has(def.parent_id), "Parent '%s' steht vor Child '%s'" % [String(def.parent_id), String(def.id)])
		seen_ids[def.id] = true


static func _world_signature(defs: Array[BodyDef]) -> String:
	var parts: Array[String] = []
	for def in defs:
		var profile: OrbitProfile = def.orbit_profile
		var orbit_signature: String = "root"
		if profile != null:
			orbit_signature = "|".join([
				str(profile.mode),
				str(profile.semi_major_axis_m),
				str(profile.eccentricity),
				str(profile.argument_periapsis_rad),
				str(profile.mean_anomaly_epoch_rad),
				str(profile.authored_radius_m),
				str(profile.authored_phase_rad),
				str(profile.authored_period_s),
				str(profile.epoch_s),
				str(profile.inclination_rad),
			])
		parts.append("|".join([
			String(def.id),
			String(def.parent_id),
			str(def.kind),
			str(def.mass_kg),
			str(def.radius_m),
			str(def.albedo),
			str(def.greenhouse_delta_k),
			str(def.axial_tilt_rad),
			str(def.north_pole_orbit_frame_azimuth_rad),
			orbit_signature,
		]))
	return "\n".join(parts)
