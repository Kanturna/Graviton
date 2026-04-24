extends RefCounted

const WorldLoaderScript = preload("res://src/sim/world/world_loader.gd")
const GalaxyStreamingControllerScript = preload("res://src/runtime/streaming/galaxy_streaming_controller.gd")
const GalaxyProxyMathScript = preload("res://src/runtime/streaming/galaxy_proxy_math.gd")
const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")
const GalaxyProxyRendererScript = preload("res://src/tools/rendering/galaxy_proxy_renderer.gd")
const OrbitViewRendererScript = preload("res://src/tools/rendering/orbit_view_renderer.gd")
const OrbitCameraFramingScript = preload("res://src/tools/rendering/orbit_camera_framing.gd")
const UniverseTopologyScript = preload("res://src/sim/topology/universe_topology.gd")
const StressGalaxyFactoryScript = preload("res://src/tests/helpers/stress_galaxy_factory.gd")
const ScaleupGalaxyCatalogFactoryScript = preload("res://src/sim/world/scaleup_galaxy_catalog_factory.gd")
const GeneratedScaleupRootFactoryScript = preload("res://src/sim/world/generated_scaleup_root_factory.gd")
const GeneratedRootManifestFactoryScript = preload("res://src/sim/world/generated_root_manifest_factory.gd")
const RootSystemGeneratorScript = preload("res://src/sim/world/root_system_generator.gd")

const SCALEUP_GALAXY_10_CONTENT_SIGNATURE_SHA256: String = "65a2506f2bc55a77b49fbe21c47a5e27dbe6fcb96c2030211546ad6ea6d50f58"
const SCALEUP_GALAXY_30_CONTENT_SIGNATURE_SHA256: String = "0fd01d3b0372ece1bafeacdc4ab987f59bb7a37aafd09cdb52a6af44a33944f9"
const SCALEUP_GALAXY_100_CONTENT_SIGNATURE_SHA256: String = "807fba9d535b31b21c699bfa4260d761f2b3703da16bb15759996e28e694838b"


class BubbleProbe:
	extends Node

	var compose_call_ids: Array[StringName] = []
	var return_value_m: Vector3 = Vector3(1000.0, 500.0, 0.0)

	func compose_view_position_m(id: StringName, _presentation_offset_s: float = 0.0) -> Vector3:
		compose_call_ids.append(id)
		return return_value_m


class StatefulBubbleProbe:
	extends Node

	var compose_call_ids: Array[StringName] = []
	var positions_by_id: Dictionary = {}

	func compose_view_position_m(id: StringName, _presentation_offset_s: float = 0.0) -> Vector3:
		compose_call_ids.append(id)
		return positions_by_id.get(id, Vector3.ZERO)


class ProxyRendererProbe:
	extends GalaxyProxyRendererScript

	var probe_viewport_size_px: Vector2 = Vector2(800.0, 600.0)
	var probe_canvas_xform: Transform2D = Transform2D.IDENTITY

	func _viewport_size_px() -> Vector2:
		return probe_viewport_size_px

	func _canvas_xform() -> Transform2D:
		return probe_canvas_xform


class ProxyBubble:
	extends RefCounted

	var focus_id: StringName = &"obsidian"

	func get_focus() -> StringName:
		return focus_id


class ProxyTopology:
	extends RefCounted

	func root_id_of(id: StringName) -> StringName:
		return id


class ProxyTime:
	extends Node

	var sim_time_s: float = 0.0


class ProxyStreaming:
	extends RefCounted

	var resident_root_ids: Array[StringName] = []

	func get_resident_root_ids() -> Array[StringName]:
		var out: Array[StringName] = []
		out.append_array(resident_root_ids)
		return out


class ProxyDetailRenderer:
	extends RefCounted

	var positions_by_id: Dictionary = {}

	func get_body_view_position_ru(id: StringName) -> Vector2:
		return positions_by_id.get(id, Vector2.ZERO)


static func run(ctx) -> void:
	ctx.current_suite = "test_large_world_streaming"
	_test_pilot_galaxy_catalog_and_generated_roots_are_deterministic(ctx)
	_test_streaming_controller_primary_focus_falls_back_to_first_root(ctx)
	_test_streaming_controller_applies_hysteresis_keepalive_and_prewarm(ctx)
	_test_streaming_controller_pins_prewarm_boundaries(ctx)
	_test_prewarm_reuses_loader_scoped_slice_cache(ctx)
	_test_focus_ping_pong_keeps_old_focus_resident_when_qualified(ctx)
	_test_proxy_detail_handoff_matches_position_and_velocity(ctx)
	_test_stress_and_pilot_share_manifest_defs_signature(ctx)
	_test_generated_roots_use_obsidian_root_standard(ctx)
	_test_generated_root_planets_use_obsidian_local_scale(ctx)
	_test_scaleup_galaxy_extra_roots_share_stress_prefix(ctx)
	_test_scaleup_galaxy_10_content_signature_is_pinned(ctx)
	_test_scaleup_galaxy_30_content_signature_is_pinned(ctx)
	_test_scaleup_galaxy_30_matches_stress_catalog_for_all_roots(ctx)
	_test_scaleup_galaxy_30_spacing_guard_covers_all_root_pairs(ctx)
	_test_scaleup_galaxy_100_build_spike_and_neighbor_cache_stays_lazy(ctx)
	_test_scaleup_galaxy_100_content_signature_is_pinned(ctx)
	_test_scaleup_galaxy_100_matches_stress_catalog_for_all_roots(ctx)
	_test_scaleup_galaxy_100_spacing_guard_covers_all_root_pairs(ctx)
	_test_spacing_guard_relaxes_generated_root_radially_without_changing_content(ctx)
	_test_spacing_guard_hard_fails_for_impossible_generated_root(ctx)
	_test_streaming_controller_debug_snapshot_tracks_recent_events(ctx)
	_test_scaleup_galaxy_streaming_stays_bounded(ctx)
	_test_scaleup_galaxy_30_streaming_stays_bounded(ctx)
	_test_scaleup_galaxy_100_streaming_stays_bounded(ctx)
	_test_proxy_renderer_culls_offscreen_roots_for_scaleup_galaxy_100(ctx)
	_test_renderer_shortcuts_cross_root_detail_localization_for_pilot_and_scaleup(ctx)
	_test_root_overview_lod_hides_planetary_descendants_and_tracks_debug_counts(ctx)
	_test_root_overview_trail_resume_avoids_bridge_and_rebuild_clears_pause_state(ctx)
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


static func _test_streaming_controller_primary_focus_falls_back_to_first_root(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	var empty_root_ids: Array[StringName] = []
	galaxy.focus_root_id = StringName("")
	galaxy.default_resident_root_ids = empty_root_ids

	var setup: Dictionary = _make_streaming_setup(galaxy)
	var controller = setup.get("controller")
	ctx.assert_true(controller.get_focus_root_id() == &"obsidian", "leerer Fokus-/Resident-Default faellt auf den ersten Root zurueck")
	var resident_root_ids: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(resident_root_ids.size() == 1 and resident_root_ids[0] == &"obsidian", "Fallback-Fokus materialisiert genau einen Start-Root")

	_cleanup_streaming_setup(setup)
	loader.free()


static func _test_streaming_controller_applies_hysteresis_keepalive_and_prewarm(ctx) -> void:
	var setup: Dictionary = _make_streaming_setup()
	var controller = setup.get("controller")
	var registry: Node = setup.get("registry")
	var galaxy = setup.get("galaxy")
	var focus_root_id: StringName = _primary_focus_root_id(galaxy)
	var expected_neighbor: StringName = _nearest_neighbor_root_id(galaxy, focus_root_id)

	ctx.assert_true(controller.get_resident_root_ids().size() == 1, "Pilot startet mit genau einem resident Root")
	ctx.assert_true(controller.get_prewarm_root_id() == StringName(""), "bei Zoom 1.0 startet kein Prewarm")
	var initial_snapshot: Dictionary = controller.get_debug_snapshot()
	ctx.assert_true(initial_snapshot.has("desired_neighbor_root_id"), "Debug-Snapshot fuehrt desired_neighbor_root_id immer explizit")
	ctx.assert_true(initial_snapshot.get("desired_neighbor_root_id", StringName("")) == expected_neighbor, "Debug-Snapshot meldet den naechsten gewuenschten Neighbor")

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
	ctx.assert_true(zoomed_out_roots[0] == focus_root_id and zoomed_out_roots[1] == expected_neighbor,
		"Resident-Liste bleibt Fokus zuerst plus naechster Nachbar")
	ctx.assert_true(registry.has_body(expected_neighbor), "materialisierter Nachbar liegt in der Registry")

	controller.update(0.0, 0.70)
	ctx.assert_true(controller.get_resident_root_ids().size() == 2, "ueber Exit-Schwelle bleibt der Neighbor zunaechst per Keepalive resident")
	controller.update(1.0, 0.70)
	ctx.assert_true(controller.get_resident_root_ids().size() == 2, "Keepalive laesst den Neighbor vor Ablauf weiter resident")
	controller.update(0.6, 0.70)
	var collapsed_roots: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(collapsed_roots.size() == 1 and collapsed_roots[0] == focus_root_id, "nach Keepalive-Ablauf entlaedt der Neighbor wieder")
	ctx.assert_true(registry.body_count() == 18, "eingeklappter Pilot-Slice bleibt auf einen Detail-Root begrenzt")

	_cleanup_streaming_setup(setup)


static func _test_streaming_controller_pins_prewarm_boundaries(ctx) -> void:
	var setup: Dictionary = _make_streaming_setup()
	var controller = setup.get("controller")
	var galaxy = setup.get("galaxy")
	var focus_root_id: StringName = _primary_focus_root_id(galaxy)
	var expected_neighbor: StringName = _nearest_neighbor_root_id(galaxy, focus_root_id)

	controller.update(0.0, 0.91)
	ctx.assert_true(controller.get_prewarm_root_id() == StringName(""), "ohne bestehenden Prewarm bleibt 0.91 ausserhalb des Enter-Bands")

	# Der Enter-Contract ist absichtlich <= 0.90, waehrend der Halt-Contract bis < 1.00 geht.
	# Dieser Test pinnt die Asymmetrie explizit, damit spaeter niemand die Operatoren "aufraeumt".
	controller.update(0.0, 0.90)
	ctx.assert_true(controller.get_prewarm_root_id() == expected_neighbor, "0.90 startet Prewarm explizit am unteren Rand des Bands")

	controller.update(0.0, 0.91)
	ctx.assert_true(controller.get_prewarm_root_id() == expected_neighbor, "ein bereits aktiver Prewarm bleibt bei 0.91 im Halt-Band erhalten")

	controller.update(0.0, 1.00)
	ctx.assert_true(controller.get_prewarm_root_id() == StringName(""), "1.00 beendet Prewarm deterministisch am oberen Rand")

	controller.update(0.0, 0.89)
	ctx.assert_true(controller.get_prewarm_root_id() == expected_neighbor, "0.89 liegt klar innerhalb des Enter-Bands")

	_cleanup_streaming_setup(setup)


static func _test_prewarm_reuses_loader_scoped_slice_cache(ctx) -> void:
	var setup: Dictionary = _make_streaming_setup()
	var controller = setup.get("controller")
	var loader = setup.get("loader")
	var galaxy = setup.get("galaxy")
	var baseline_cache_size: int = loader.get_prepared_root_slice_cache_size()

	ctx.assert_true(loader.get_prepared_root_slice_cache_scope_id() == galaxy.galaxy_id, "Streaming-Setup scoped den Loader-Cache an die aktive Galaxy")
	controller.update(0.0, 0.60)
	var cache_size_after_prewarm: int = loader.get_prepared_root_slice_cache_size()
	ctx.assert_true(cache_size_after_prewarm == baseline_cache_size + 1, "Prewarm fuellt genau einen zusaetzlichen vorbereiteten Root-Slice im Loader-Cache")

	controller.update(0.0, 0.61)
	ctx.assert_true(loader.get_prepared_root_slice_cache_size() == cache_size_after_prewarm, "Prewarm dupliziert denselben vorbereiteten Root-Slice im Loader-Cache nicht")

	_cleanup_streaming_setup(setup)


static func _test_focus_ping_pong_keeps_old_focus_resident_when_qualified(ctx) -> void:
	var setup: Dictionary = _make_streaming_setup()
	var controller = setup.get("controller")
	var galaxy = setup.get("galaxy")
	var focus_root_id: StringName = _primary_focus_root_id(galaxy)
	var expected_neighbor: StringName = _nearest_neighbor_root_id(galaxy, focus_root_id)

	controller.update(0.0, 0.50)
	controller.set_focus_root(expected_neighbor)
	var after_first_switch: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(after_first_switch.size() == 2, "Fokuswechsel im Wide-Zoom behaelt zwei residente Roots")
	ctx.assert_true(after_first_switch[0] == expected_neighbor and after_first_switch[1] == focus_root_id,
		"alter Fokus bleibt als Neighbor resident, wenn er weiter qualifiziert")

	controller.set_focus_root(focus_root_id)
	var after_second_switch: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(after_second_switch.size() == 2, "Ping-Pong-Fokuswechsel bleibt auf zwei residenten Roots begrenzt")
	ctx.assert_true(after_second_switch[0] == focus_root_id and after_second_switch[1] == expected_neighbor,
		"zurueckgewechselter Fokus stellt die Resident-Reihenfolge korrekt wieder her")

	controller.update(0.0, 1.0)
	ctx.assert_true(controller.get_resident_root_ids().size() == 2, "alter Fokus bleibt nach Zoom-in erst ueber Keepalive resident")
	controller.update(1.6, 1.0)
	var collapsed_roots: Array[StringName] = controller.get_resident_root_ids()
	ctx.assert_true(collapsed_roots.size() == 1 and collapsed_roots[0] == focus_root_id, "nicht mehr qualifizierter alter Fokus faellt nach Keepalive wieder heraus")

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


static func _test_stress_and_pilot_share_manifest_defs_signature(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var pilot_galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	var stress_galaxy = StressGalaxyFactoryScript.build(30)
	var shared_root_id: StringName = _primary_focus_root_id(pilot_galaxy)

	var pilot_manifest = pilot_galaxy.get_manifest(shared_root_id)
	var stress_manifest = stress_galaxy.get_manifest(shared_root_id)
	ctx.assert_true(pilot_manifest != null and stress_manifest != null, "Pilot-Root ist auch im Stress-Helper als Manifest vorhanden")

	var pilot_defs: Array[BodyDef] = loader.build_defs_for_root_manifest(pilot_manifest)
	var stress_defs: Array[BodyDef] = loader.build_defs_for_root_manifest(stress_manifest)
	ctx.assert_true(_defs_signature(pilot_defs) == _defs_signature(stress_defs), "gemeinsam uebernommener Pilot-Root bleibt ueber dieselbe Produktiv-Pipeline bit-identisch")

	loader.free()


static func _test_generated_roots_use_obsidian_root_standard(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var pilot_galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	var hero_manifest = pilot_galaxy.get_manifest(&"obsidian")
	ctx.assert_true(hero_manifest != null, "Hero-Root obsidian existiert fuer den Root-Standard-Vergleich")

	for root_id in [&"onyx", &"umbra", &"shade_01", &"shade_07"]:
		var manifest = null
		if String(root_id).begins_with("shade_"):
			manifest = GeneratedScaleupRootFactoryScript.build_manifest_for_ordinal(int(String(root_id).trim_prefix("shade_")))
		else:
			manifest = pilot_galaxy.get_manifest(root_id)
		ctx.assert_true(manifest != null, "Generated Root %s existiert fuer den Obsidian-Standard-Vergleich" % String(root_id))
		ctx.assert_true(
			is_equal_approx(float(manifest.system_extent_m), float(hero_manifest.system_extent_m)),
			"Generated Root %s nutzt denselben system_extent wie obsidian" % String(root_id)
		)
		ctx.assert_true(
			manifest.star_manifests.size() == GeneratedRootManifestFactoryScript.STANDARD_STAR_ORBIT_RADII_M.size(),
			"Generated Root %s nutzt dieselbe Standard-Sternanzahl wie obsidian" % String(root_id)
		)
		for star_index in range(manifest.star_manifests.size()):
			var generated_star_manifest = manifest.star_manifests[star_index]
			ctx.assert_true(
				is_equal_approx(
					float(generated_star_manifest.orbit_radius_m),
					float(GeneratedRootManifestFactoryScript.STANDARD_STAR_ORBIT_RADII_M[star_index])
				),
				"Generated Root %s nutzt auf Lane %d denselben Orbit-Radius wie der Obsidian-Standard" % [String(root_id), star_index]
			)
			ctx.assert_true(
				is_equal_approx(
					float(generated_star_manifest.orbit_period_s),
					float(GeneratedRootManifestFactoryScript.STANDARD_STAR_ORBIT_PERIODS_S[star_index])
				),
				"Generated Root %s nutzt auf Lane %d denselben Orbit-Periodenstandard wie obsidian" % [String(root_id), star_index]
			)

	loader.free()


static func _test_generated_root_planets_use_obsidian_local_scale(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var pilot_galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	for root_id in [&"onyx", &"umbra", &"shade_01", &"shade_07"]:
		var manifest = null
		if String(root_id).begins_with("shade_"):
			manifest = GeneratedScaleupRootFactoryScript.build_manifest_for_ordinal(int(String(root_id).trim_prefix("shade_")))
		else:
			manifest = pilot_galaxy.get_manifest(root_id)
		var defs: Array[BodyDef] = loader.build_defs_for_root_manifest(manifest)
		for def in defs:
			if def == null or def.kind != BodyType.Kind.PLANET or def.orbit_profile == null:
				continue
			ctx.assert_true(
				def.orbit_profile.semi_major_axis_m >= RootSystemGeneratorScript.STANDARD_PLANET_START_AXIS_MIN_M,
				"Generated Root %s haelt planetare Innenbahnen auf Obsidian-Skala" % String(root_id)
			)
			ctx.assert_true(
				def.orbit_profile.semi_major_axis_m <= RootSystemGeneratorScript.STANDARD_PLANET_AXIS_MAX_M,
				"Generated Root %s laesst Planeten nicht mehr bis in root-nahe Ausreisserbahnen wachsen" % String(root_id)
			)

	loader.free()


static func _test_scaleup_galaxy_extra_roots_share_stress_prefix(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var scaleup_galaxy = loader.load_named_galaxy(&"scaleup_galaxy_10")
	var stress_galaxy = StressGalaxyFactoryScript.build(30)
	var extra_root_ids: Array[StringName] = []
	for root_id in scaleup_galaxy.root_ids():
		if String(root_id).begins_with("shade_"):
			extra_root_ids.append(root_id)

	ctx.assert_true(extra_root_ids.size() == 7, "scaleup_galaxy_10 traegt genau sieben Shared-Helper-Zusatz-Roots")
	for root_id in extra_root_ids:
		var scaleup_manifest = scaleup_galaxy.get_manifest(root_id)
		var stress_manifest = stress_galaxy.get_manifest(root_id)
		ctx.assert_true(scaleup_manifest != null and stress_manifest != null, "Zusatz-Root %s existiert in Produkt- und Stresspfad" % String(root_id))
		var scaleup_defs: Array[BodyDef] = loader.build_defs_for_root_manifest(scaleup_manifest)
		var stress_defs: Array[BodyDef] = loader.build_defs_for_root_manifest(stress_manifest)
		ctx.assert_true(_defs_signature(scaleup_defs) == _defs_signature(stress_defs), "Zusatz-Root %s bleibt ueber Produkt- und Stresspfad identisch" % String(root_id))

	loader.free()


static func _test_scaleup_galaxy_10_content_signature_is_pinned(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_10")
	var content_signature: String = _catalog_content_signature(loader, galaxy)
	ctx.assert_true(
		_sha256_hex(content_signature) == SCALEUP_GALAXY_10_CONTENT_SIGNATURE_SHA256,
		"scaleup_galaxy_10 bleibt ueber die Factory-Migration inhaltlich bit-identisch gepinnt"
	)
	loader.free()


static func _test_scaleup_galaxy_30_content_signature_is_pinned(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_30")
	var content_signature: String = _catalog_content_signature(loader, galaxy)
	ctx.assert_true(
		_sha256_hex(content_signature) == SCALEUP_GALAXY_30_CONTENT_SIGNATURE_SHA256,
		"scaleup_galaxy_30 bleibt ueber weitere Builder- und Perf-Aenderungen inhaltlich gepinnt"
	)
	loader.free()


static func _test_scaleup_galaxy_30_matches_stress_catalog_for_all_roots(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var scaleup_galaxy = loader.load_named_galaxy(&"scaleup_galaxy_30")
	var stress_galaxy = StressGalaxyFactoryScript.build(30)
	ctx.assert_true(scaleup_galaxy.root_ids().size() == 30, "scaleup_galaxy_30 meldet genau dreissig Roots")

	for root_id in scaleup_galaxy.root_ids():
		var scaleup_manifest = scaleup_galaxy.get_manifest(root_id)
		var stress_manifest = stress_galaxy.get_manifest(root_id)
		ctx.assert_true(scaleup_manifest != null and stress_manifest != null, "Root %s existiert in Produkt- und Stress-Catalog" % String(root_id))
		ctx.assert_true(_manifest_signature(scaleup_manifest) == _manifest_signature(stress_manifest), "Manifest %s bleibt zwischen Produkt- und Stresspfad identisch" % String(root_id))
		var scaleup_defs: Array[BodyDef] = loader.build_defs_for_root_manifest(scaleup_manifest)
		var stress_defs: Array[BodyDef] = loader.build_defs_for_root_manifest(stress_manifest)
		ctx.assert_true(_canonical_defs_signature(scaleup_defs) == _canonical_defs_signature(stress_defs), "Defs fuer %s bleiben ueber Produkt- und Stresspfad identisch" % String(root_id))

	loader.free()


static func _test_scaleup_galaxy_30_spacing_guard_covers_all_root_pairs(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_30")
	var manifests: Array = []
	manifests.append_array(galaxy.manifests)

	for left_index in range(manifests.size()):
		var left_manifest = manifests[left_index]
		for right_index in range(left_index + 1, manifests.size()):
			var right_manifest = manifests[right_index]
			var distance_m: float = left_manifest.galaxy_position_m.distance_to(right_manifest.galaxy_position_m)
			var min_spacing_m: float = ScaleupGalaxyCatalogFactoryScript.minimum_spacing_m(left_manifest, right_manifest)
			ctx.assert_true(distance_m >= min_spacing_m, "Spacing-Guard haelt %s <-> %s im 30-Root-Catalog auseinander" % [
				String(left_manifest.root_id),
				String(right_manifest.root_id),
			])

	loader.free()


static func _test_scaleup_galaxy_100_build_spike_and_neighbor_cache_stays_lazy(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_100")
	ctx.assert_true(galaxy != null, "scaleup_galaxy_100 Build-Spike laeuft ohne Hard-Fail durch")
	ctx.assert_true(galaxy.root_ids().size() == 100, "scaleup_galaxy_100 Build-Spike liefert exakt hundert Roots")
	ctx.assert_true(galaxy.neighbor_order_cache_size() == 0, "Neighbor-Cache startet lazy und leer")

	var obsidian_neighbors: Array[StringName] = galaxy.sorted_neighbor_root_ids(&"obsidian")
	ctx.assert_true(not obsidian_neighbors.is_empty(), "Neighbor-Cache liefert fuer obsidian eine stabile Distanzordnung")
	ctx.assert_true(galaxy.neighbor_order_cache_size() == 1, "Neighbor-Cache baut beim ersten Zugriff genau einen Fokus-Root-Eintrag")

	var repeated_neighbors: Array[StringName] = galaxy.sorted_neighbor_root_ids(&"obsidian")
	ctx.assert_true(obsidian_neighbors == repeated_neighbors, "Neighbor-Cache bleibt fuer denselben Fokus-Root stabil")
	ctx.assert_true(galaxy.neighbor_order_cache_size() == 1, "wiederholter Zugriff baut keinen zweiten Cache-Eintrag")

	var shade_neighbors: Array[StringName] = galaxy.sorted_neighbor_root_ids(&"shade_42")
	ctx.assert_true(not shade_neighbors.is_empty(), "Neighbor-Cache liefert auch fuer einen generierten Root Nachbarn")
	ctx.assert_true(galaxy.neighbor_order_cache_size() == 2, "Neighbor-Cache baut pro Fokus-Root lazy genau einen weiteren Eintrag")

	loader.free()


static func _test_scaleup_galaxy_100_content_signature_is_pinned(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_100")
	var content_signature: String = _catalog_content_signature(loader, galaxy)
	ctx.assert_true(
		_sha256_hex(content_signature) == SCALEUP_GALAXY_100_CONTENT_SIGNATURE_SHA256,
		"scaleup_galaxy_100 bleibt als Produkt-Catalog inhaltlich gepinnt"
	)
	loader.free()


static func _test_scaleup_galaxy_100_matches_stress_catalog_for_all_roots(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var scaleup_galaxy = loader.load_named_galaxy(&"scaleup_galaxy_100")
	var stress_galaxy = StressGalaxyFactoryScript.build(100)
	ctx.assert_true(scaleup_galaxy.root_ids().size() == 100, "scaleup_galaxy_100 meldet genau hundert Roots")

	for root_id in scaleup_galaxy.root_ids():
		var scaleup_manifest = scaleup_galaxy.get_manifest(root_id)
		var stress_manifest = stress_galaxy.get_manifest(root_id)
		ctx.assert_true(scaleup_manifest != null and stress_manifest != null, "Root %s existiert in Produkt- und Stress-Catalog fuer 100 Roots" % String(root_id))
		ctx.assert_true(_manifest_signature(scaleup_manifest) == _manifest_signature(stress_manifest), "Manifest %s bleibt zwischen Produkt- und Stresspfad bei 100 Roots identisch" % String(root_id))
		var scaleup_defs: Array[BodyDef] = loader.build_defs_for_root_manifest(scaleup_manifest)
		var stress_defs: Array[BodyDef] = loader.build_defs_for_root_manifest(stress_manifest)
		ctx.assert_true(_canonical_defs_signature(scaleup_defs) == _canonical_defs_signature(stress_defs), "Defs fuer %s bleiben ueber Produkt- und Stresspfad bei 100 Roots identisch" % String(root_id))

	loader.free()


static func _test_scaleup_galaxy_100_spacing_guard_covers_all_root_pairs(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_100")
	var manifests: Array = []
	manifests.append_array(galaxy.manifests)

	for left_index in range(manifests.size()):
		var left_manifest = manifests[left_index]
		for right_index in range(left_index + 1, manifests.size()):
			var right_manifest = manifests[right_index]
			var distance_m: float = left_manifest.galaxy_position_m.distance_to(right_manifest.galaxy_position_m)
			var min_spacing_m: float = ScaleupGalaxyCatalogFactoryScript.minimum_spacing_m(left_manifest, right_manifest)
			ctx.assert_true(distance_m >= min_spacing_m, "Spacing-Guard haelt %s <-> %s im 100-Root-Catalog auseinander" % [
				String(left_manifest.root_id),
				String(right_manifest.root_id),
			])

	loader.free()


static func _test_spacing_guard_relaxes_generated_root_radially_without_changing_content(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var pilot_galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	var fixed_manifests: Array = []
	for manifest in pilot_galaxy.manifests:
		fixed_manifests.append(manifest.duplicate_manifest())

	var candidate = GeneratedScaleupRootFactoryScript.build_manifest_for_ordinal(1)
	var original_direction: Vector3 = candidate.galaxy_position_m.normalized()
	var original_manifest_signature: String = _manifest_signature_ignoring_position(candidate)
	var original_defs_signature: String = _canonical_defs_signature(loader.build_defs_for_root_manifest(candidate))

	candidate.galaxy_position_m = original_direction * 1.0e11
	var result: Dictionary = ScaleupGalaxyCatalogFactoryScript.apply_spacing_guard(fixed_manifests, [candidate])
	ctx.assert_true(bool(result.get("ok", false)), "Spacing-Guard kann einen zu nahen Zusatz-Root radial entspannen")

	var relaxed_manifest = _find_manifest_by_root_id(result.get("manifests", []), candidate.root_id)
	ctx.assert_true(relaxed_manifest != null, "entspannter Zusatz-Root bleibt im Ergebnis-Catalog erhalten")
	ctx.assert_true(relaxed_manifest.galaxy_position_m.distance_to(candidate.galaxy_position_m) > 0.0, "Spacing-Guard verschiebt den Zusatz-Root sichtbar radial nach aussen")
	ctx.assert_true(_same_direction(original_direction, relaxed_manifest.galaxy_position_m.normalized()), "Spacing-Guard behaelt den urspruenglichen Winkel des Zusatz-Roots bei")
	ctx.assert_true(relaxed_manifest.seed == candidate.seed, "Spacing-Guard aendert den Root-Seed nicht")
	ctx.assert_true(_manifest_signature_ignoring_position(relaxed_manifest) == original_manifest_signature, "Spacing-Guard aendert keine Manifest-Inhalte ausser der Galaxy-Position")
	ctx.assert_true(_canonical_defs_signature(loader.build_defs_for_root_manifest(relaxed_manifest)) == original_defs_signature, "Spacing-Guard aendert den Detail-Slice des Zusatz-Roots nicht")

	var obsidian_manifest = _find_manifest_by_root_id(result.get("manifests", []), &"obsidian")
	var relaxed_distance_m: float = relaxed_manifest.galaxy_position_m.distance_to(obsidian_manifest.galaxy_position_m)
	var min_spacing_m: float = ScaleupGalaxyCatalogFactoryScript.minimum_spacing_m(relaxed_manifest, obsidian_manifest)
	ctx.assert_true(relaxed_distance_m >= min_spacing_m, "entspannter Zusatz-Root erfuellt danach die Mindestabstandsregel gegen den Hero-Root")

	loader.free()


static func _test_spacing_guard_hard_fails_for_impossible_generated_root(ctx) -> void:
	var blocker_template = GeneratedScaleupRootFactoryScript.build_manifest_for_ordinal(27)
	var blocker_extent_m: float = blocker_template.system_extent_m
	var relax_step_m: float = 2.0 * blocker_extent_m
	var fixed_manifests: Array = []
	for index in range(18):
		var blocker = blocker_template.duplicate_manifest()
		blocker.root_id = StringName("blocker_%02d" % index)
		blocker.display_name = "Blocker %02d" % index
		blocker.galaxy_position_m = Vector3.RIGHT * (float(index) * relax_step_m)
		fixed_manifests.append(blocker)

	var candidate = blocker_template.duplicate_manifest()
	candidate.root_id = &"shade_hard_fail"
	candidate.display_name = "Shade Hard Fail"
	candidate.galaxy_position_m = Vector3.RIGHT * (0.10 * blocker_extent_m)

	var result: Dictionary = ScaleupGalaxyCatalogFactoryScript.apply_spacing_guard(fixed_manifests, [candidate])
	ctx.assert_true(not bool(result.get("ok", true)), "unmoegliche Spacing-Konfiguration bricht nach dem Relax-Limit hart ab")
	ctx.assert_true(String(result.get("error", "")).contains("failed spacing guard after 16 attempts"), "Hard-Fail meldet das feste Relax-Limit explizit")
	ctx.assert_true(result.get("root_id", StringName("")) == candidate.root_id, "Hard-Fail meldet den betroffenen Zusatz-Root eindeutig zurueck")


static func _test_streaming_controller_debug_snapshot_tracks_recent_events(ctx) -> void:
	var setup: Dictionary = _make_streaming_setup()
	var controller = setup.get("controller")
	var time_service: Node = setup.get("time_service")
	var galaxy = setup.get("galaxy")
	var focus_root_id: StringName = _primary_focus_root_id(galaxy)
	var expected_neighbor: StringName = _nearest_neighbor_root_id(galaxy, focus_root_id)

	time_service.sim_time_s = 10.0
	controller.update(0.0, 0.89)
	time_service.sim_time_s = 11.0
	controller.update(0.0, 1.00)
	time_service.sim_time_s = 12.0
	controller.update(0.0, 0.50)
	time_service.sim_time_s = 13.0
	controller.update(0.0, 0.70)
	time_service.sim_time_s = 15.0
	controller.update(1.6, 0.70)
	time_service.sim_time_s = 16.0
	controller.set_focus_root(expected_neighbor)

	var baseline_snapshot: Dictionary = controller.get_debug_snapshot()
	ctx.assert_true(baseline_snapshot.has("focus_root_id"), "Debug-Snapshot enthaelt den Fokus-Root")
	ctx.assert_true(baseline_snapshot.has("resident_root_ids"), "Debug-Snapshot enthaelt die Resident-Liste")
	ctx.assert_true(baseline_snapshot.has("desired_neighbor_root_id"), "Debug-Snapshot enthaelt desired_neighbor_root_id verpflichtend")
	ctx.assert_true(baseline_snapshot.has("resident_neighbor_root_id"), "Debug-Snapshot enthaelt den aktuellen Resident-Neighbor")
	ctx.assert_true(baseline_snapshot.has("prewarm_root_id"), "Debug-Snapshot enthaelt den aktuellen Prewarm-Root")
	ctx.assert_true(baseline_snapshot.has("neighbor_keepalive_remaining_s"), "Debug-Snapshot enthaelt den Keepalive-Timer")
	ctx.assert_true(baseline_snapshot.has("last_zoom_factor"), "Debug-Snapshot enthaelt den letzten Zoom-Faktor")
	ctx.assert_true(baseline_snapshot.has("recent_events"), "Debug-Snapshot enthaelt den Ringbuffer der letzten Streaming-Events")
	ctx.assert_true(_event_sequence_contains_subsequence(
		_debug_event_names(baseline_snapshot),
		[
			"prewarm_enter",
			"prewarm_exit",
			"neighbor_enter",
			"keepalive_started",
			"keepalive_expired",
			"neighbor_exit",
			"focus_changed",
		]
	), "Ringbuffer protokolliert die erwarteten Streaming-Uebergaenge in stabiler Reihenfolge")

	for index in range(12):
		time_service.sim_time_s = 20.0 + float(index)
		controller.set_focus_root(focus_root_id if index % 2 == 0 else expected_neighbor)

	var snapshot: Dictionary = controller.get_debug_snapshot()
	var recent_events: Array = snapshot.get("recent_events", [])
	ctx.assert_true(recent_events.size() == 16, "Ringbuffer kappt den Event-Verlauf strikt auf 16 Eintraege")
	ctx.assert_true(_event_times_are_non_decreasing(recent_events), "Ringbuffer behaelt die chronologische Reihenfolge der Events")
	ctx.assert_true(_debug_event_names(snapshot).has("focus_changed"), "Ringbuffer behaelt juengere Fokuswechsel-Events sichtbar")

	_cleanup_streaming_setup(setup)


static func _test_scaleup_galaxy_streaming_stays_bounded(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_10")
	ctx.assert_true(galaxy.root_ids().size() == 10, "scaleup_galaxy_10 meldet zehn Roots")

	var setup: Dictionary = _make_streaming_setup(galaxy)
	var controller = setup.get("controller")
	var focus_candidates: Array[StringName] = [&"obsidian", &"umbra", &"shade_01", &"shade_04"]

	ctx.assert_true(controller.get_resident_root_ids().size() == 1, "scaleup_galaxy_10 startet mit genau einem residenten Fokus-Root")
	for root_id in focus_candidates:
		controller.set_focus_root(root_id)
		controller.update(0.0, 0.50)
		var wide_roots: Array[StringName] = controller.get_resident_root_ids()
		ctx.assert_true(wide_roots.size() >= 1 and wide_roots.size() <= 2, "scaleup-Fokus %s bleibt im Wide-Zoom auf maximal zwei residenten Roots begrenzt" % String(root_id))
		ctx.assert_true(wide_roots[0] == root_id, "scaleup-Fokus %s bleibt als erster residenter Root erhalten" % String(root_id))
		controller.update(0.0, 1.00)
		controller.update(1.6, 1.00)
		var collapsed_roots: Array[StringName] = controller.get_resident_root_ids()
		ctx.assert_true(collapsed_roots.size() == 1 and collapsed_roots[0] == root_id, "scaleup-Fokus %s faellt nach Keepalive wieder auf einen Detail-Root zurueck" % String(root_id))

	_cleanup_streaming_setup(setup)
	loader.free()


static func _test_scaleup_galaxy_30_streaming_stays_bounded(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_30")
	ctx.assert_true(galaxy.root_ids().size() == 30, "scaleup_galaxy_30 meldet dreissig Roots")

	var setup: Dictionary = _make_streaming_setup(galaxy)
	var controller = setup.get("controller")
	var focus_candidates: Array[StringName] = [&"obsidian", &"umbra", &"shade_01", &"shade_09", &"shade_18", &"shade_27"]

	ctx.assert_true(controller.get_resident_root_ids().size() == 1, "scaleup_galaxy_30 startet mit genau einem residenten Fokus-Root")
	for root_id in focus_candidates:
		controller.set_focus_root(root_id)
		controller.update(0.0, 0.50)
		var wide_roots: Array[StringName] = controller.get_resident_root_ids()
		ctx.assert_true(wide_roots.size() >= 1 and wide_roots.size() <= 2, "30er-Fokus %s bleibt im Wide-Zoom auf maximal zwei residenten Roots begrenzt" % String(root_id))
		ctx.assert_true(wide_roots[0] == root_id, "30er-Fokus %s bleibt als erster residenter Root erhalten" % String(root_id))
		controller.update(0.0, 1.00)
		controller.update(1.6, 1.00)
		var collapsed_roots: Array[StringName] = controller.get_resident_root_ids()
		ctx.assert_true(collapsed_roots.size() == 1 and collapsed_roots[0] == root_id, "30er-Fokus %s faellt nach Keepalive wieder auf einen Detail-Root zurueck" % String(root_id))

	_cleanup_streaming_setup(setup)
	loader.free()


static func _test_scaleup_galaxy_100_streaming_stays_bounded(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_100")
	ctx.assert_true(galaxy.root_ids().size() == 100, "scaleup_galaxy_100 meldet hundert Roots")

	var setup: Dictionary = _make_streaming_setup(galaxy)
	var controller = setup.get("controller")
	var focus_candidates: Array[StringName] = [&"obsidian", &"umbra", &"shade_01", &"shade_27", &"shade_54", &"shade_97"]

	ctx.assert_true(controller.get_resident_root_ids().size() == 1, "scaleup_galaxy_100 startet mit genau einem residenten Fokus-Root")
	for root_id in focus_candidates:
		controller.set_focus_root(root_id)
		controller.update(0.0, 0.50)
		var wide_roots: Array[StringName] = controller.get_resident_root_ids()
		ctx.assert_true(wide_roots.size() >= 1 and wide_roots.size() <= 2, "100er-Fokus %s bleibt im Wide-Zoom auf maximal zwei residenten Roots begrenzt" % String(root_id))
		ctx.assert_true(wide_roots[0] == root_id, "100er-Fokus %s bleibt als erster residenter Root erhalten" % String(root_id))
		controller.update(0.0, 1.00)
		controller.update(1.6, 1.00)
		var collapsed_roots: Array[StringName] = controller.get_resident_root_ids()
		ctx.assert_true(collapsed_roots.size() == 1 and collapsed_roots[0] == root_id, "100er-Fokus %s faellt nach Keepalive wieder auf einen Detail-Root zurueck" % String(root_id))

	_cleanup_streaming_setup(setup)
	loader.free()


static func _test_proxy_renderer_culls_offscreen_roots_for_scaleup_galaxy_100(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var galaxy = loader.load_named_galaxy(&"scaleup_galaxy_100")
	ctx.assert_true(galaxy != null and galaxy.root_ids().size() == 100, "scaleup_galaxy_100 steht fuer den Proxy-Culling-Test bereit")

	var renderer := ProxyRendererProbe.new()
	renderer.scale = Vector2(0.003, 0.003)
	renderer.probe_viewport_size_px = Vector2(800.0, 600.0)
	renderer.probe_canvas_xform = Transform2D(Vector2(0.003, 0.0), Vector2(0.0, 0.003), Vector2(400.0, 300.0))

	var registry := Node.new()
	var bubble := ProxyBubble.new()
	bubble.focus_id = &"obsidian"
	var topology := ProxyTopology.new()
	var time_service := ProxyTime.new()
	var streaming := ProxyStreaming.new()
	streaming.resident_root_ids = [&"obsidian", &"shade_97"]
	var detail_renderer := ProxyDetailRenderer.new()
	detail_renderer.positions_by_id[&"obsidian"] = Vector2.ZERO

	renderer.configure(galaxy, registry, bubble, topology, time_service, streaming, detail_renderer)
	var first_state: Dictionary = renderer.recompute_proxy_state()
	var first_snapshot: Dictionary = renderer.get_debug_snapshot()
	ctx.assert_true(int(first_snapshot.get("culled_root_count", 0)) > 0, "100er-Proxy-Culling spart im Fernblick off-screen Roots komplett aus")
	ctx.assert_true(int(first_snapshot.get("visible_root_count", 0)) > 0, "100er-Proxy-Culling behaelt im Fernblick weiterhin eine sichtbare Teilmenge")
	ctx.assert_true(
		int(first_snapshot.get("visible_root_count", 0)) == int(first_snapshot.get("bh_only_root_count", 0)) + int(first_snapshot.get("star_proxy_root_count", 0)),
		"sichtbare Roots zerfallen im Debug-Snapshot weiterhin exakt in BH-only und Stern-Proxy-Tiers"
	)
	ctx.assert_true(
		int(first_snapshot.get("culled_root_count", 0)) + int(first_snapshot.get("visible_root_count", 0)) == galaxy.root_ids().size() - 1,
		"Culling plus sichtbare Roots decken weiterhin alle Non-Focus-Roots ab"
	)

	var visible_entries: Array = first_state.get("entries", [])
	ctx.assert_true(not visible_entries.is_empty(), "Culling-Test liefert mindestens einen sichtbaren Root-Eintrag fuer Picking")
	var picked_entry: Dictionary = visible_entries[0]
	var picked_root_id: StringName = picked_entry.get("root_id", StringName(""))
	var picked_screen_pos: Vector2 = renderer.probe_canvas_xform * Vector2(picked_entry.get("root_pos_ru", Vector2.ZERO))
	ctx.assert_true(renderer.pick_root_at_screen(picked_screen_pos) == picked_root_id, "sichtbare Root-Proxies bleiben auch nach dem Culling pickbar")
	ctx.assert_true(not renderer._root_local_positions_ru.has(&"shade_97"), "ein off-screen residenter Neighbor darf weiterhin unsichtbar und ungepickt bleiben")

	renderer.probe_canvas_xform = Transform2D(Vector2(0.003, 0.0), Vector2(0.0, 0.003), Vector2(400.25, 300.0))
	renderer.recompute_proxy_state()
	var panned_snapshot: Dictionary = renderer.get_debug_snapshot()
	ctx.assert_true(
		abs(int(panned_snapshot.get("visible_root_count", 0)) - int(first_snapshot.get("visible_root_count", 0))) <= 1,
		"kleiner konstanter Pan an der Viewport-Kante erzeugt kein unnoetiges Sichtbarkeits-Chattering"
	)

	renderer.free()
	registry.free()
	loader.free()


static func _test_renderer_shortcuts_cross_root_detail_localization_for_pilot_and_scaleup(ctx) -> void:
	var cases: Array[Dictionary] = [
		{
			"world_id": &"pilot_galaxy",
			"resident_root_ids": [&"obsidian", &"onyx"],
			"cross_root_id": &"onyx_a",
			"same_root_id": &"alpha",
		},
		{
			"world_id": &"scaleup_galaxy_10",
			"resident_root_ids": [&"obsidian", &"shade_01"],
			"cross_root_id": &"shade_01_a",
			"same_root_id": &"alpha",
		},
		{
			"world_id": &"scaleup_galaxy_30",
			"resident_root_ids": [&"obsidian", &"shade_27"],
			"cross_root_id": &"shade_27_a",
			"same_root_id": &"alpha",
		},
	]
	for case_data in cases:
		var loader = WorldLoaderScript.new()
		var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
		var galaxy = loader.load_named_galaxy(case_data.get("world_id", StringName("")))
		var resident_root_ids: Array[StringName] = []
		resident_root_ids.append_array(case_data.get("resident_root_ids", []))
		ctx.assert_true(loader.materialize_galaxy_roots(galaxy, resident_root_ids, registry), "Testwelt %s laesst sich fuer den Renderer-Kurzschluss materialisieren" % String(case_data.get("world_id", "")))

		var bubble_probe := BubbleProbe.new()
		var topology = UniverseTopologyScript.new()
		topology.configure(registry)
		var renderer = _make_renderer_probe(registry, bubble_probe, topology)
		renderer.set_focus(&"obsidian")
		renderer._sync_visual_positions(true)

		var cross_root_id: StringName = case_data.get("cross_root_id", StringName(""))
		var same_root_id: StringName = case_data.get("same_root_id", StringName(""))
		var cross_root_orbit_entry: Dictionary = renderer._orbit_visuals.get(cross_root_id, {})
		var same_root_orbit_entry: Dictionary = renderer._orbit_visuals.get(same_root_id, {})
		var cross_root_orbit_line: CanvasItem = cross_root_orbit_entry.get("line", null)
		var same_root_orbit_line: CanvasItem = same_root_orbit_entry.get("line", null)
		var cross_root_trail: CanvasItem = renderer._trail_visuals.get(cross_root_id, null)
		var same_root_trail: CanvasItem = renderer._trail_visuals.get(same_root_id, null)
		ctx.assert_true(cross_root_orbit_line != null and not cross_root_orbit_line.visible, "Renderer versteckt fuer %s Cross-Root-Orbits explizit" % String(case_data.get("world_id", "")))
		ctx.assert_true(cross_root_trail == null, "Renderer legt fuer %s fuer Sterne keinen Trail an (Cross-Root trivial verborgen)" % String(case_data.get("world_id", "")))
		ctx.assert_true(same_root_orbit_line != null and same_root_orbit_line.visible, "Renderer behaelt fuer %s same-root Orbits sichtbar" % String(case_data.get("world_id", "")))
		ctx.assert_true(same_root_trail == null, "Renderer legt fuer %s fuer same-root Sterne keinen Trail an" % String(case_data.get("world_id", "")))

		bubble_probe.compose_call_ids.clear()
		var cross_root_pos: Vector2 = renderer.get_body_view_position_ru(cross_root_id)
		ctx.assert_true(not is_finite(cross_root_pos.x) and not is_finite(cross_root_pos.y), "Renderer lokalisiert %s cross-root nicht mehr ueber die Bubble" % String(case_data.get("world_id", "")))
		ctx.assert_true(bubble_probe.compose_call_ids.is_empty(), "Renderer ruft fuer %s cross-root keine Bubble-Lokalisierung mehr auf" % String(case_data.get("world_id", "")))

		var same_root_pos: Vector2 = renderer.get_body_view_position_ru(same_root_id)
		ctx.assert_true(is_finite(same_root_pos.x) and is_finite(same_root_pos.y), "Renderer behaelt same-root Lokalisierung fuer %s bei" % String(case_data.get("world_id", "")))
		ctx.assert_true(bubble_probe.compose_call_ids.size() == 1 and bubble_probe.compose_call_ids[0] == same_root_id,
			"Renderer ruft fuer %s weiterhin genau die same-root Bubble-Lokalisierung auf" % String(case_data.get("world_id", "")))

		bubble_probe.free()
		renderer.free()
		registry.free()
		loader.free()


static func _test_root_overview_lod_hides_planetary_descendants_and_tracks_debug_counts(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	ctx.assert_true(loader.materialize_galaxy_roots(galaxy, [&"obsidian"], registry), "Pilot-Root laesst sich fuer den Root-Overview-LOD-Test materialisieren")

	var bubble_probe := StatefulBubbleProbe.new()
	bubble_probe.positions_by_id = {
		&"obsidian": Vector3.ZERO,
		&"alpha": Vector3(1.0e3, 0.0, 0.0),
		&"beta": Vector3(2.0e3, 0.0, 0.0),
		&"gamma": Vector3(3.0e3, 0.0, 0.0),
		&"delta": Vector3(4.0e3, 0.0, 0.0),
	}
	var topology = UniverseTopologyScript.new()
	topology.configure(registry)
	var renderer = _make_renderer_probe(registry, bubble_probe, topology)
	renderer.set_focus(&"obsidian")
	bubble_probe.compose_call_ids.clear()
	renderer.set_frame_label(OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW)
	renderer._sync_visual_positions(true)

	var alpha_visual: CanvasItem = renderer._body_visuals.get(&"alpha", null)
	var alpha_planet_visual: CanvasItem = renderer._body_visuals.get(&"alpha_i", null)
	var alpha_orbit_entry: Dictionary = renderer._orbit_visuals.get(&"alpha", {})
	var alpha_planet_orbit_entry: Dictionary = renderer._orbit_visuals.get(&"alpha_i", {})
	var alpha_orbit_line: CanvasItem = alpha_orbit_entry.get("line", null)
	var alpha_planet_orbit_line: CanvasItem = alpha_planet_orbit_entry.get("line", null)
	var alpha_trail: CanvasItem = renderer._trail_visuals.get(&"alpha", null)
	var alpha_planet_trail: CanvasItem = renderer._trail_visuals.get(&"alpha_i", null)
	var snapshot: Dictionary = renderer.get_debug_snapshot()

	ctx.assert_true(alpha_visual != null and alpha_visual.visible, "ROOT_OVERVIEW behaelt direkte Sterne sichtbar")
	ctx.assert_true(alpha_orbit_line != null and alpha_orbit_line.visible, "ROOT_OVERVIEW behaelt direkte Stern-Orbits sichtbar")
	ctx.assert_true(alpha_planet_visual != null and not alpha_planet_visual.visible, "ROOT_OVERVIEW blendet planetare Descendants aus")
	ctx.assert_true(alpha_planet_orbit_line != null and not alpha_planet_orbit_line.visible, "ROOT_OVERVIEW blendet planetare Orbitlinien aus")
	ctx.assert_true(alpha_trail == null, "Sterne tragen grundsaetzlich keinen Trail; in ROOT_OVERVIEW trivial unsichtbar")
	ctx.assert_true(alpha_planet_trail != null and not alpha_planet_trail.visible, "ROOT_OVERVIEW blendet planetare Trails aus")
	ctx.assert_true(int(snapshot.get("compose_view_position_distinct_body_count", 0)) == 5, "ROOT_OVERVIEW lokalisiert nur BH plus vier direkte Sterne")
	ctx.assert_true(int(snapshot.get("overview_visible_star_count", 0)) == 4, "ROOT_OVERVIEW meldet genau vier sichtbare direkte Sterne fuer obsidian")
	ctx.assert_true(int(snapshot.get("overview_hidden_descendant_count", 0)) > 0, "ROOT_OVERVIEW zaehlt ausgeblendete Descendants explizit mit")
	ctx.assert_true(not bubble_probe.compose_call_ids.has(&"alpha_i"), "ROOT_OVERVIEW ruft fuer ausgeblendete Planeten keine Bubble-Komposition auf")

	bubble_probe.free()
	renderer.free()
	registry.free()
	loader.free()


static func _test_root_overview_trail_resume_avoids_bridge_and_rebuild_clears_pause_state(ctx) -> void:
	var loader = WorldLoaderScript.new()
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var galaxy = loader.load_named_galaxy(&"pilot_galaxy")
	ctx.assert_true(loader.materialize_galaxy_roots(galaxy, [&"obsidian", &"onyx"], registry), "Pilot- und Neighbor-Root lassen sich fuer den Trail-Resume-Test materialisieren")

	var bubble_probe := StatefulBubbleProbe.new()
	bubble_probe.positions_by_id = {
		&"obsidian": Vector3.ZERO,
		&"alpha_i": Vector3(1.0e10, 0.0, 0.0),
		&"onyx": Vector3.ZERO,
		&"onyx_a": Vector3(1.0e11, 0.0, 0.0),
	}
	var topology = UniverseTopologyScript.new()
	topology.configure(registry)
	var renderer = _make_renderer_probe(registry, bubble_probe, topology)
	renderer.set_focus(&"obsidian")
	renderer.set_frame_label(OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK)
	renderer._clear_trail(&"alpha_i")
	registry.get_state(&"alpha_i").position_parent_frame_m = Vector3(1.0e10, 0.0, 0.0)
	renderer._sync_visual_positions(true)
	bubble_probe.positions_by_id[&"alpha_i"] = Vector3(2.5e10, 0.0, 0.0)
	registry.get_state(&"alpha_i").position_parent_frame_m = Vector3(2.5e10, 0.0, 0.0)
	renderer._sync_visual_positions(false)

	var alpha_planet_trail: AntialiasedLine2D = renderer._trail_visuals.get(&"alpha_i", null)
	ctx.assert_true(alpha_planet_trail != null and alpha_planet_trail.points.size() >= 2, "Detailmodus baut zunaechst eine planetare Trail-History auf")

	renderer.set_frame_label(OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW)
	renderer._sync_visual_positions(false)
	ctx.assert_true(renderer._paused_trail_histories.has(&"alpha_i"), "ROOT_OVERVIEW pausiert planetare Trails body-scoped")

	bubble_probe.positions_by_id[&"alpha_i"] = Vector3(4.5e10, 0.0, 0.0)
	registry.get_state(&"alpha_i").position_parent_frame_m = Vector3(4.5e10, 0.0, 0.0)
	renderer.set_frame_label(OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK)
	renderer._sync_visual_positions(false)
	alpha_planet_trail = renderer._trail_visuals.get(&"alpha_i", null)
	ctx.assert_true(alpha_planet_trail != null and alpha_planet_trail.points.size() == 1, "Trail-Resume kehrt ohne Brueckensegment mit einem resynchronisierten Endpunkt zurueck")
	ctx.assert_true(not renderer._paused_trail_histories.has(&"alpha_i"), "Trail-Resume hebt den Pause-Zustand fuer den Body wieder auf")

	renderer.set_frame_label(OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW)
	renderer._sync_visual_positions(false)
	ctx.assert_true(not renderer._paused_trail_histories.is_empty(), "ROOT_OVERVIEW hinterlaesst zunaechst pausierte Trail-Zustaende im Renderer-State")
	renderer.rebuild_from_registry()
	renderer.set_focus(&"onyx")
	renderer.set_frame_label(OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK)
	renderer._sync_visual_positions(true)
	ctx.assert_true(renderer._paused_trail_histories.is_empty(), "Renderer-Rebuild loescht pausierte Trail-Zustaende vor einem Root-Wechsel")

	bubble_probe.free()
	renderer.free()
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
	var focus_root_id: StringName = _primary_focus_root_id(galaxy)
	var focus_body_id: StringName = _first_focus_body_id_for_root(registry, focus_root_id)
	ctx.assert_true(focus_body_id != StringName(""), "Stresspfad kann den Fokus-Body voll aus Manifest-/Registry-Daten ableiten")
	bubble.set_focus(focus_body_id)

	var thermal_service = load("res://src/sim/thermal/thermal_service.gd").new()
	thermal_service.configure(registry)
	var atmosphere_service = load("res://src/sim/atmosphere/atmosphere_service.gd").new()
	atmosphere_service.configure(registry, thermal_service)
	var environment_service = load("res://src/sim/environment/environment_service.gd").new()
	environment_service.configure(registry, atmosphere_service)
	var cache = DerivedSnapshotCacheScript.new()
	cache.configure(registry, time_service, bubble, loader, thermal_service, environment_service, orbit_service)

	var interest_ids: Array[StringName] = _planetary_interest_ids_for_root(registry, focus_root_id)
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


static func _primary_focus_root_id(galaxy) -> StringName:
	if galaxy == null:
		return StringName("")
	if galaxy.focus_root_id != StringName(""):
		return galaxy.focus_root_id
	if not galaxy.default_resident_root_ids.is_empty():
		return galaxy.default_resident_root_ids[0]
	var root_ids: Array[StringName] = galaxy.root_ids()
	return StringName("") if root_ids.is_empty() else root_ids[0]


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


static func _first_focus_body_id_for_root(registry: Node, root_id: StringName) -> StringName:
	var fallback_body_id: StringName = root_id if registry.has_body(root_id) else StringName("")
	var root_id_by_id: Dictionary = {}
	for id in registry.get_update_order():
		var def: BodyDef = registry.get_def(id)
		if def == null:
			continue
		var current_root_id: StringName = def.id if def.is_root() else StringName(root_id_by_id.get(def.parent_id, StringName("")))
		root_id_by_id[id] = current_root_id
		if current_root_id != root_id:
			continue
		if fallback_body_id == StringName(""):
			fallback_body_id = id
		if def.kind == BodyType.Kind.PLANET or def.kind == BodyType.Kind.MOON:
			return id
	return fallback_body_id


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


static func _debug_event_names(snapshot: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for event_variant in snapshot.get("recent_events", []):
		var event: Dictionary = event_variant
		names.append(String(event.get("event", "")))
	return names


static func _event_sequence_contains_subsequence(actual: Array[String], expected: Array[String]) -> bool:
	if expected.is_empty():
		return true
	var expected_index: int = 0
	for event_name in actual:
		if event_name != expected[expected_index]:
			continue
		expected_index += 1
		if expected_index >= expected.size():
			return true
	return false


static func _event_times_are_non_decreasing(events: Array) -> bool:
	var last_time_s: float = -INF
	for event_variant in events:
		var event: Dictionary = event_variant
		var current_time_s: float = float(event.get("sim_time_s", 0.0))
		if current_time_s < last_time_s:
			return false
		last_time_s = current_time_s
	return true


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


static func _manifest_signature(manifest) -> String:
	if manifest == null:
		return "null"
	var parts: Array[String] = [
		String(manifest.root_id),
		manifest.display_name,
		str(manifest.seed),
		str(manifest.galaxy_position_m),
		str(manifest.system_extent_m),
		String(manifest.hero_world_id),
		str(manifest.root_mass_kg),
		str(manifest.root_radius_m),
	]
	for star_manifest in manifest.star_manifests:
		parts.append("|".join([
			String(star_manifest.id),
			star_manifest.display_name,
			str(star_manifest.mass_kg),
			str(star_manifest.radius_m),
			str(star_manifest.rotation_period_s),
			str(star_manifest.luminosity_w),
			str(star_manifest.orbit_radius_m),
			str(star_manifest.orbit_period_s),
			str(star_manifest.orbit_phase_rad),
			str(star_manifest.planet_count),
		]))
	return "\n".join(parts)


static func _manifest_signature_ignoring_position(manifest) -> String:
	if manifest == null:
		return "null"
	var parts: Array[String] = [
		String(manifest.root_id),
		manifest.display_name,
		str(manifest.seed),
		str(manifest.system_extent_m),
		String(manifest.hero_world_id),
		str(manifest.root_mass_kg),
		str(manifest.root_radius_m),
	]
	for star_manifest in manifest.star_manifests:
		parts.append("|".join([
			String(star_manifest.id),
			star_manifest.display_name,
			str(star_manifest.mass_kg),
			str(star_manifest.radius_m),
			str(star_manifest.rotation_period_s),
			str(star_manifest.luminosity_w),
			str(star_manifest.orbit_radius_m),
			str(star_manifest.orbit_period_s),
			str(star_manifest.orbit_phase_rad),
			str(star_manifest.planet_count),
		]))
	return "\n".join(parts)


static func _catalog_content_signature(loader, galaxy) -> String:
	var parts: Array[String] = []
	for root_id in galaxy.root_ids():
		var manifest = galaxy.get_manifest(root_id)
		var defs: Array[BodyDef] = loader.build_defs_for_root_manifest(manifest)
		parts.append(String(root_id))
		parts.append(_canonical_defs_signature(defs))
	return "\n---\n".join(parts)


static func _canonical_defs_signature(defs: Array[BodyDef]) -> String:
	return WorldLoaderScript._defs_signature(defs)


static func _sha256_hex(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


static func _find_manifest_by_root_id(manifests: Array, root_id: StringName):
	for manifest in manifests:
		if manifest != null and manifest.root_id == root_id:
			return manifest
	return null


static func _same_direction(left: Vector3, right: Vector3, tol: float = 1.0e-6) -> bool:
	if left.length() <= 0.0 or right.length() <= 0.0:
		return false
	return left.normalized().distance_to(right.normalized()) <= tol


static func _make_renderer_probe(registry: Node, bubble_probe: Node, topology) -> OrbitViewRenderer:
	var renderer = OrbitViewRendererScript.new()
	var orbit_layer := Node2D.new()
	orbit_layer.name = "OrbitLayer"
	renderer.add_child(orbit_layer)
	renderer._orbit_layer = orbit_layer

	var trail_layer := Node2D.new()
	trail_layer.name = "TrailLayer"
	renderer.add_child(trail_layer)
	renderer._trail_layer = trail_layer

	var body_layer := Node2D.new()
	body_layer.name = "BodyLayer"
	renderer.add_child(body_layer)
	renderer._body_layer = body_layer

	renderer.configure(registry, bubble_probe, topology)
	return renderer


static func _free_if_present(value) -> void:
	if value != null:
		value.free()
