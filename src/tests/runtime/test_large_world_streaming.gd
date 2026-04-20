extends RefCounted

const WorldLoaderScript = preload("res://src/sim/world/world_loader.gd")
const GalaxyStreamingControllerScript = preload("res://src/runtime/streaming/galaxy_streaming_controller.gd")
const GalaxyProxyMathScript = preload("res://src/runtime/streaming/galaxy_proxy_math.gd")
const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")
const StressGalaxyFactoryScript = preload("res://src/tests/helpers/stress_galaxy_factory.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_large_world_streaming"
	_test_pilot_galaxy_catalog_and_generated_roots_are_deterministic(ctx)
	_test_streaming_controller_applies_hysteresis_keepalive_and_prewarm(ctx)
	_test_focus_ping_pong_keeps_old_focus_resident_when_qualified(ctx)
	_test_proxy_detail_handoff_matches_position_and_velocity(ctx)
	_test_30_root_stress_keeps_resident_count_and_snapshot_refreshes_bounded(ctx)


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


static func _test_streaming_controller_applies_hysteresis_keepalive_and_prewarm(ctx) -> void:
	var setup: Dictionary = _make_streaming_setup()
	var controller = setup.get("controller")
	var registry: Node = setup.get("registry")
	var galaxy = setup.get("galaxy")
	var expected_neighbor: StringName = _nearest_neighbor_root_id(galaxy, &"obsidian")

	ctx.assert_true(controller.get_resident_root_ids().size() == 1, "Pilot startet mit genau einem resident Root")
	ctx.assert_true(controller.get_prewarm_root_id() == StringName(""), "bei Zoom 1.0 startet kein Prewarm")

	controller.update(0.0, 0.60)
	ctx.assert_true(controller.get_resident_root_ids().size() == 1, "Hysterese laedt bei 0.60 noch keinen Neighbor")
	ctx.assert_true(controller.get_prewarm_root_id() == expected_neighbor, "unterhalb der Enter-Schwelle fuer Prewarm wird der naechste Root vorbereitet")

	controller.update(0.0, 0.61)
	ctx.assert_true(controller.get_resident_root_ids().size() == 1, "pendeln um 0.60/0.61 triggert kein Resident-Toggling")
	ctx.assert_true(controller.get_prewarm_root_id() == expected_neighbor, "Prewarm bleibt im Keep-Band stabil")

	controller.update(0.0, 0.95)
	ctx.assert_true(controller.get_prewarm_root_id() == expected_neighbor, "Prewarm bleibt bis knapp unter 1.00 erhalten")
	controller.update(0.0, 1.00)
	ctx.assert_true(controller.get_prewarm_root_id() == StringName(""), "zoom_factor == 1.00 beendet Prewarm deterministisch")

	controller.update(0.0, 0.50)
	var zoomed_out_roots: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(zoomed_out_roots.size() == 2, "unterhalb der Neighbor-Enter-Schwelle materialisiert genau ein Nachbar")
	ctx.assert_true(zoomed_out_roots[0] == &"obsidian" and zoomed_out_roots[1] == expected_neighbor,
		"Resident-Liste bleibt Fokus zuerst plus naechster Nachbar")
	ctx.assert_true(registry.has_body(expected_neighbor), "materialisierter Nachbar liegt in der Registry")

	controller.update(0.0, 0.70)
	ctx.assert_true(controller.get_resident_root_ids().size() == 2, "ueber Exit-Schwelle bleibt der Neighbor zunaechst per Keepalive resident")
	controller.update(1.0, 0.70)
	ctx.assert_true(controller.get_resident_root_ids().size() == 2, "Keepalive laesst den Neighbor vor Ablauf weiter resident")
	controller.update(0.6, 0.70)
	var collapsed_roots: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(collapsed_roots.size() == 1 and collapsed_roots[0] == &"obsidian", "nach Keepalive-Ablauf entlaedt der Neighbor wieder")
	ctx.assert_true(registry.body_count() == 18, "eingeklappter Pilot-Slice bleibt auf einen Detail-Root begrenzt")

	_cleanup_streaming_setup(setup)


static func _test_focus_ping_pong_keeps_old_focus_resident_when_qualified(ctx) -> void:
	var setup: Dictionary = _make_streaming_setup()
	var controller = setup.get("controller")
	var galaxy = setup.get("galaxy")
	var expected_neighbor: StringName = _nearest_neighbor_root_id(galaxy, &"obsidian")

	controller.update(0.0, 0.50)
	controller.set_focus_root(expected_neighbor)
	var after_first_switch: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(after_first_switch.size() == 2, "Fokuswechsel im Wide-Zoom behaelt zwei residente Roots")
	ctx.assert_true(after_first_switch[0] == expected_neighbor and after_first_switch[1] == &"obsidian",
		"alter Fokus bleibt als Neighbor resident, wenn er weiter qualifiziert")

	controller.set_focus_root(&"obsidian")
	var after_second_switch: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(after_second_switch.size() == 2, "Ping-Pong-Fokuswechsel bleibt auf zwei residenten Roots begrenzt")
	ctx.assert_true(after_second_switch[0] == &"obsidian" and after_second_switch[1] == expected_neighbor,
		"zurueckgewechselter Fokus stellt die Resident-Reihenfolge korrekt wieder her")

	controller.update(0.0, 1.0)
	ctx.assert_true(controller.get_resident_root_ids().size() == 2, "alter Fokus bleibt nach Zoom-in erst ueber Keepalive resident")
	controller.update(1.6, 1.0)
	var collapsed_roots: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(collapsed_roots.size() == 1 and collapsed_roots[0] == &"obsidian", "nicht mehr qualifizierter alter Fokus faellt nach Keepalive wieder heraus")

	_cleanup_streaming_setup(setup)


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


static func _test_30_root_stress_keeps_resident_count_and_snapshot_refreshes_bounded(ctx) -> void:
	var galaxy = StressGalaxyFactoryScript.build(30)
	ctx.assert_true(galaxy.root_ids().size() == 30, "Stress-Helper baut genau 30 Roots")

	var setup: Dictionary = _make_streaming_setup(galaxy)
	var controller = setup.get("controller")
	var loader = setup.get("loader")
	var registry: Node = setup.get("registry")
	var time_service: Node = setup.get("time_service")
	var orbit_service = setup.get("orbit_service")

	var bubble: LocalBubbleManager = load("res://src/runtime/local_bubble/local_bubble_manager.gd").new()
	bubble.configure(registry)
	bubble.set_focus(&"gamma_iv")

	var thermal_service = load("res://src/sim/thermal/thermal_service.gd").new()
	thermal_service.configure(registry)
	var atmosphere_service = load("res://src/sim/atmosphere/atmosphere_service.gd").new()
	atmosphere_service.configure(registry, thermal_service)
	var environment_service = load("res://src/sim/environment/environment_service.gd").new()
	environment_service.configure(registry, atmosphere_service)
	var cache = DerivedSnapshotCacheScript.new()
	cache.configure(registry, time_service, bubble, loader, thermal_service, environment_service, orbit_service)

	var interest_ids: Array[StringName] = _planetary_interest_ids_for_root(registry, &"obsidian")
	cache.set_interest_ids(interest_ids)
	var max_interest_refresh_count: int = interest_ids.size()
	ctx.assert_true(max_interest_refresh_count > 0, "Stresspfad hat einen nichtleeren Interest-Slice")

	var zoom_sequence: Array[Dictionary] = [
		{"delta_s": 0.0, "zoom": 0.50},
		{"delta_s": 0.4, "zoom": 0.70},
		{"delta_s": 0.8, "zoom": 0.70},
		{"delta_s": 0.4, "zoom": 0.70},
		{"delta_s": 0.0, "zoom": 0.50},
		{"delta_s": 0.0, "zoom": 0.95},
		{"delta_s": 0.0, "zoom": 1.00},
	]
	for step in zoom_sequence:
		controller.update(float(step.get("delta_s", 0.0)), float(step.get("zoom", 1.0)))
		var resident_count: int = controller.get_resident_root_ids().size()
		ctx.assert_true(resident_count >= 1 and resident_count <= 2, "Stress-Zoom-Zyklus haelt den Resident-Count strikt zwischen 1 und 2")
		ctx.assert_true(cache.get_last_refreshed_body_count() <= max_interest_refresh_count, "DerivedSnapshotCache bleibt auch im 30-Root-Stress auf Fokus/Interest begrenzt")

	cache.dispose()
	environment_service.free()
	atmosphere_service.free()
	thermal_service.free()
	bubble.free()
	_cleanup_streaming_setup(setup)


static func _make_streaming_setup(galaxy = null) -> Dictionary:
	var loader = WorldLoaderScript.new()
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var time_service: Node = load("res://src/core/time/time_service.gd").new()
	var orbit_service = load("res://src/sim/orbit/orbit_service.gd").new()
	orbit_service.configure(registry, time_service)
	var target_galaxy = galaxy if galaxy != null else loader.load_named_galaxy(&"pilot_galaxy")
	var controller = GalaxyStreamingControllerScript.new()
	controller.configure(target_galaxy, loader, registry, time_service, orbit_service)
	return {
		"loader": loader,
		"registry": registry,
		"time_service": time_service,
		"orbit_service": orbit_service,
		"galaxy": target_galaxy,
		"controller": controller,
	}


static func _cleanup_streaming_setup(setup: Dictionary) -> void:
	_free_if_present(setup.get("orbit_service", null))
	_free_if_present(setup.get("time_service", null))
	_free_if_present(setup.get("registry", null))
	_free_if_present(setup.get("loader", null))
	setup.clear()


static func _planetary_interest_ids_for_root(registry: Node, root_id: StringName) -> Array[StringName]:
	var interest_ids: Array[StringName] = []
	var root_id_by_id: Dictionary = {}
	for id in registry.get_update_order():
		var def: BodyDef = registry.get_def(id)
		if def == null:
			continue
		var current_root_id: StringName = def.id if def.is_root() else StringName(root_id_by_id.get(def.parent_id, StringName("")))
		root_id_by_id[id] = current_root_id
		if current_root_id != root_id:
			continue
		if def.kind == BodyType.Kind.PLANET or def.kind == BodyType.Kind.MOON:
			interest_ids.append(id)
	return interest_ids


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


static func _free_if_present(value) -> void:
	if value != null:
		value.free()
