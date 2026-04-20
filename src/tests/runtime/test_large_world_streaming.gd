extends RefCounted

const WorldLoaderScript = preload("res://src/sim/world/world_loader.gd")
const GalaxyStreamingControllerScript = preload("res://src/runtime/streaming/galaxy_streaming_controller.gd")
const GalaxyProxyMathScript = preload("res://src/runtime/streaming/galaxy_proxy_math.gd")
const DerivedSnapshotCacheScript = preload("res://src/runtime/derived/derived_snapshot_cache.gd")
const OrbitViewRendererScript = preload("res://src/tools/rendering/orbit_view_renderer.gd")
const UniverseTopologyScript = preload("res://src/sim/topology/universe_topology.gd")
const StressGalaxyFactoryScript = preload("res://src/tests/helpers/stress_galaxy_factory.gd")


class BubbleProbe:
	extends Node

	var compose_call_ids: Array[StringName] = []
	var return_value_m: Vector3 = Vector3(1000.0, 500.0, 0.0)

	func compose_view_position_m(id: StringName) -> Vector3:
		compose_call_ids.append(id)
		return return_value_m


static func run(ctx) -> void:
	ctx.current_suite = "test_large_world_streaming"
	_test_pilot_galaxy_catalog_and_generated_roots_are_deterministic(ctx)
	_test_streaming_controller_primary_focus_falls_back_to_first_root(ctx)
	_test_streaming_controller_applies_hysteresis_keepalive_and_prewarm(ctx)
	_test_streaming_controller_pins_prewarm_boundaries(ctx)
	_test_focus_ping_pong_keeps_old_focus_resident_when_qualified(ctx)
	_test_proxy_detail_handoff_matches_position_and_velocity(ctx)
	_test_stress_and_pilot_share_manifest_defs_signature(ctx)
	_test_scaleup_galaxy_extra_roots_share_stress_prefix(ctx)
	_test_streaming_controller_debug_snapshot_tracks_recent_events(ctx)
	_test_scaleup_galaxy_streaming_stays_bounded(ctx)
	_test_renderer_shortcuts_cross_root_detail_localization_for_pilot_and_scaleup(ctx)
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


static func _test_renderer_shortcuts_cross_root_detail_localization_for_pilot_and_scaleup(ctx) -> void:
	var cases: Array[Dictionary] = [
		{
			"world_id": &"pilot_galaxy",
			"resident_root_ids": [&"obsidian", &"onyx"],
			"cross_root_id": &"onyx",
			"same_root_id": &"gamma",
		},
		{
			"world_id": &"scaleup_galaxy_10",
			"resident_root_ids": [&"obsidian", &"shade_01"],
			"cross_root_id": &"shade_01",
			"same_root_id": &"gamma",
		},
	]
	for case_data in cases:
		var loader = WorldLoaderScript.new()
		var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
		var galaxy = loader.load_named_galaxy(case_data.get("world_id", StringName("")))
		var resident_root_ids: Array[StringName] = []
		resident_root_ids.append_array(case_data.get("resident_root_ids", []))
		ctx.assert_true(loader.materialize_galaxy_roots(galaxy, resident_root_ids, registry), "Testwelt %s laesst sich fuer den Renderer-Kurzschluss materialisieren" % String(case_data.get("world_id", "")))

		var renderer = OrbitViewRendererScript.new()
		var bubble_probe := BubbleProbe.new()
		var topology = UniverseTopologyScript.new()
		topology.configure(registry)
		renderer._registry = registry
		renderer._bubble = bubble_probe
		renderer._topology = topology
		renderer._focus_id = &"obsidian"

		var cross_root_pos: Vector2 = renderer.get_body_view_position_ru(case_data.get("cross_root_id", StringName("")))
		ctx.assert_true(not is_finite(cross_root_pos.x) and not is_finite(cross_root_pos.y), "Renderer lokalisiert %s cross-root nicht mehr ueber die Bubble" % String(case_data.get("world_id", "")))
		ctx.assert_true(bubble_probe.compose_call_ids.is_empty(), "Renderer ruft fuer %s cross-root keine Bubble-Lokalisierung mehr auf" % String(case_data.get("world_id", "")))

		var same_root_id: StringName = case_data.get("same_root_id", StringName(""))
		var same_root_pos: Vector2 = renderer.get_body_view_position_ru(same_root_id)
		ctx.assert_true(is_finite(same_root_pos.x) and is_finite(same_root_pos.y), "Renderer behaelt same-root Lokalisierung fuer %s bei" % String(case_data.get("world_id", "")))
		ctx.assert_true(bubble_probe.compose_call_ids.size() == 1 and bubble_probe.compose_call_ids[0] == same_root_id,
			"Renderer ruft fuer %s weiterhin genau die same-root Bubble-Lokalisierung auf" % String(case_data.get("world_id", "")))

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


static func _free_if_present(value) -> void:
	if value != null:
		value.free()
