extends RefCounted

const WorldLoaderScript = preload("res://src/sim/world/world_loader.gd")
const GalaxyStreamingControllerScript = preload("res://src/runtime/streaming/galaxy_streaming_controller.gd")
const GalaxyProxyMathScript = preload("res://src/runtime/streaming/galaxy_proxy_math.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_large_world_streaming"
	_test_pilot_galaxy_catalog_and_generated_roots_are_deterministic(ctx)
	_test_streaming_controller_keeps_resident_root_count_bounded(ctx)
	_test_proxy_detail_handoff_matches_position_and_velocity(ctx)


static func _test_pilot_galaxy_catalog_and_generated_roots_are_deterministic(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy_a = loader.load_named_galaxy(&"pilot_galaxy")
	var galaxy_b = loader.load_named_galaxy(&"pilot_galaxy")
	ctx.assert_true(_galaxy_signature(galaxy_a) == _galaxy_signature(galaxy_b), "gleicher Pilot-Catalog bleibt deterministisch")

	var onyx_manifest = galaxy_a.get_manifest(&"onyx")
	var first_defs: Array[BodyDef] = loader.build_defs_for_root_manifest(onyx_manifest)
	var second_defs: Array[BodyDef] = loader.build_defs_for_root_manifest(onyx_manifest)
	ctx.assert_true(first_defs.size() >= 5, "generierter Root baut einen nichttrivialen Detail-Slice")
	ctx.assert_true(_defs_signature(first_defs) == _defs_signature(second_defs), "gleicher Root-Seed erzeugt identische Detail-Defs")
	loader.free()


static func _test_streaming_controller_keeps_resident_root_count_bounded(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var time_service: Node = load("res://src/core/time/time_service.gd").new()
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	orbit_service.configure(registry, time_service)

	var galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	var controller = GalaxyStreamingControllerScript.new()
	controller.configure(galaxy, loader, registry, time_service, orbit_service)

	var initial_roots: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(initial_roots.size() == 1 and initial_roots[0] == &"obsidian", "Pilot startet mit genau einem resident detail root")
	ctx.assert_true(registry.has_body(&"obsidian"), "Hero-Root ist initial materialisiert")
	ctx.assert_true(not registry.has_body(&"onyx") and not registry.has_body(&"umbra"), "Nachbar-Roots bleiben initial Proxies")

	controller.update(0.50)
	var zoomed_out_roots: Array[StringName] = controller.get_resident_root_ids()
	var expected_neighbor: StringName = _nearest_neighbor_root_id(galaxy, &"obsidian")
	ctx.assert_true(zoomed_out_roots.size() == 2, "Zoom-out materialisiert maximal einen Nachbar-Root")
	ctx.assert_true(zoomed_out_roots[0] == &"obsidian", "fokussierter Root bleibt an erster Stelle resident")
	ctx.assert_true(zoomed_out_roots[1] == expected_neighbor, "Zoom-out waehlt den naechsten Root als Nachbarn")
	ctx.assert_true(registry.has_body(expected_neighbor), "materialisierter Nachbar liegt in der Registry")

	controller.update(1.0)
	var collapsed_roots: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(collapsed_roots.size() == 1 and collapsed_roots[0] == &"obsidian", "Zoom-in entlaedt den Nachbar-Root wieder")
	ctx.assert_true(registry.body_count() == 18, "eingeklappter Pilot-Slice bleibt auf einen Detail-Root begrenzt")

	controller = null
	orbit_service.free()
	time_service.free()
	registry.free()
	loader.free()


static func _test_proxy_detail_handoff_matches_position_and_velocity(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var time_service: Node = load("res://src/core/time/time_service.gd").new()
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	orbit_service.configure(registry, time_service)

	var galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	var manifest = galaxy.get_manifest(&"onyx")
	var star_manifest = manifest.star_manifests[0]
	var handoff_time_s: float = 43210.0

	var proxy_state: Dictionary = GalaxyProxyMathScript.star_local_state(star_manifest, handoff_time_s)
	var defs: Array[BodyDef] = loader.build_defs_for_root_manifest(manifest)
	ctx.assert_true(loader.load_defs_into_registry(defs, registry, manifest.root_id), "generated Root laesst sich fuer den Handoff-Test materialisieren")
	orbit_service.recompute_all_at_time(handoff_time_s)

	var detail_state: BodyState = registry.get_state(star_manifest.id)
	ctx.assert_true(detail_state != null, "materialisierter Stern liefert einen BodyState")
	ctx.assert_vec_almost(
		detail_state.position_parent_frame_m,
		proxy_state.get("position_parent_frame_m", Vector3.ZERO),
		1.0e-3,
		"proxy->detail Handoff behaelt die Sternposition"
	)
	ctx.assert_vec_almost(
		detail_state.velocity_parent_frame_mps,
		proxy_state.get("velocity_parent_frame_mps", Vector3.ZERO),
		1.0e-3,
		"proxy->detail Handoff behaelt die abgeleitete Sternvelocity"
	)

	var fallback_proxy_state: Dictionary = GalaxyProxyMathScript.star_local_state(star_manifest, handoff_time_s)
	ctx.assert_vec_almost(
		fallback_proxy_state.get("position_parent_frame_m", Vector3.ZERO),
		detail_state.position_parent_frame_m,
		1.0e-3,
		"detail->proxy Fallback behaelt dieselbe Sternposition"
	)
	ctx.assert_vec_almost(
		fallback_proxy_state.get("velocity_parent_frame_mps", Vector3.ZERO),
		detail_state.velocity_parent_frame_mps,
		1.0e-3,
		"detail->proxy Fallback behaelt dieselbe abgeleitete Sternvelocity"
	)

	orbit_service.free()
	time_service.free()
	registry.free()
	loader.free()


static func _nearest_neighbor_root_id(galaxy, focus_root_id: StringName) -> StringName:
	var focus_manifest = galaxy.get_manifest(focus_root_id)
	var best_id: StringName = StringName("")
	var best_distance_sq: float = INF
	for manifest in galaxy.manifests:
		if manifest == null or manifest.root_id == focus_root_id:
			continue
		var distance_sq: float = focus_manifest.galaxy_position_m.distance_squared_to(manifest.galaxy_position_m)
		if distance_sq < best_distance_sq:
			best_id = manifest.root_id
			best_distance_sq = distance_sq
	return best_id


static func _galaxy_signature(galaxy) -> String:
	var parts: Array[String] = [
		String(galaxy.galaxy_id),
		String(galaxy.focus_root_id),
		str(galaxy.default_resident_root_ids),
	]
	for manifest in galaxy.manifests:
		parts.append(String(manifest.root_id))
		parts.append(str(manifest.seed))
		parts.append(str(manifest.galaxy_position_m))
		parts.append(str(manifest.system_extent_m))
		parts.append(String(manifest.hero_world_id))
		for star_manifest in manifest.star_manifests:
			parts.append("|".join([
				String(star_manifest.id),
				str(star_manifest.mass_kg),
				str(star_manifest.radius_m),
				str(star_manifest.luminosity_w),
				str(star_manifest.orbit_radius_m),
				str(star_manifest.orbit_period_s),
				str(star_manifest.orbit_phase_rad),
				str(star_manifest.planet_count),
			]))
	return "\n".join(parts)


static func _defs_signature(defs: Array[BodyDef]) -> String:
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
				str(profile.authored_period_s),
				str(profile.authored_phase_rad),
			])
		parts.append("|".join([
			String(def.id),
			String(def.parent_id),
			str(def.kind),
			str(def.mass_kg),
			str(def.radius_m),
			str(def.rotation_period_s),
			str(def.axial_tilt_rad),
			str(def.luminosity_w),
			str(def.albedo),
			str(def.greenhouse_delta_k),
			orbit_signature,
		]))
	return "\n".join(parts)
