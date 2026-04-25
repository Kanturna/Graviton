extends RefCounted

const OrbitTestbedScript = preload("res://scenes/testbeds/orbit_testbed.gd")
const OrbitCameraFramingScript = preload("res://src/tools/rendering/orbit_camera_framing.gd")
const LocalBubbleManagerScript = preload("res://src/runtime/local_bubble/local_bubble_manager.gd")
const OrbitViewRendererScript = preload("res://src/tools/rendering/orbit_view_renderer.gd")
const DebugOverlayScript = preload("res://src/tools/debug/debug_overlay.gd")


class OrderTestbedProbe:
	extends OrbitTestbedScript

	var viewport_size: Vector2 = Vector2(1280.0, 720.0)

	func _ready() -> void:
		pass

	func _current_viewport_size() -> Vector2:
		return viewport_size

	func _can_sync_immediate_view_state() -> bool:
		return true

	func _update_hud() -> void:
		pass

	func _sample_perf_probe() -> void:
		pass


class BubbleProbe:
	extends LocalBubbleManagerScript

	var focus_id: StringName = &"obsidian"

	func get_focus() -> StringName:
		return focus_id

	func set_focus(body_id: StringName) -> void:
		focus_id = body_id


class CameraControllerProbe:
	extends RefCounted

	var bubble = null
	var frame_label: StringName = OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW
	var focused_ids: Array[StringName] = []
	var immediate_flags: Array[bool] = []
	var force_fit_flags: Array[bool] = []
	var captured_state: Dictionary = {
		"focus_id": &"alpha_i",
		"zoom_factor": 4.0,
		"manual_pan_ru": Vector2(8.0, -3.0),
	}
	var restored_states: Array[Dictionary] = []
	var restore_immediate_flags: Array[bool] = []
	var order_log: Array = []
	var zoom_factor: float = 1.0
	var current_view_scale: float = 1.0
	var zoom_mode: StringName = &"probe"

	func set_focus(body_id: StringName, immediate := false, force_fit := false) -> void:
		focused_ids.append(body_id)
		immediate_flags.append(immediate)
		force_fit_flags.append(force_fit)
		if bubble != null:
			bubble.set_focus(body_id)

	func handle_pan_input(_pan_dir: Vector2, _delta: float) -> void:
		pass

	func step(_delta: float, _viewport_size: Vector2) -> void:
		order_log.append("camera.step")

	func get_frame_label() -> StringName:
		return frame_label

	func get_zoom_factor() -> float:
		return zoom_factor

	func get_current_view_scale() -> float:
		return current_view_scale

	func get_zoom_mode() -> StringName:
		return zoom_mode

	func fit_current_focus() -> void:
		pass

	func capture_view_state() -> Dictionary:
		return captured_state.duplicate(true)

	func restore_view_state(state: Dictionary, immediate := false) -> void:
		restored_states.append(state.duplicate(true))
		restore_immediate_flags.append(immediate)
		if bubble != null:
			bubble.set_focus(StringName(state.get("focus_id", StringName(""))))


class RootInspectorProbe:
	extends PanelContainer

	var open: bool = false
	var root_id: StringName = &""
	var focused_body_id: StringName = &""
	var auto_open_count: int = 0
	var compact_root_overview: bool = false
	var compact_focus_branch: bool = false

	func set_root_context(next_root_id: StringName, next_focused_body_id: StringName, auto_open: bool = false) -> void:
		root_id = next_root_id
		focused_body_id = next_focused_body_id
		if auto_open:
			open = true
			auto_open_count += 1

	func set_compact_root_overview(value: bool) -> void:
		compact_root_overview = value

	func set_compact_focus_branch(value: bool) -> void:
		compact_focus_branch = value

	func set_compact_display_modes(root_overview: bool, focus_branch: bool) -> void:
		compact_root_overview = root_overview
		compact_focus_branch = focus_branch and not root_overview

	func is_open() -> bool:
		return open

	func get_root_id() -> StringName:
		return root_id

	func close_panel(_emit_close_signal: bool = true) -> void:
		open = false

	func clear_state() -> void:
		open = false
		root_id = StringName("")
		focused_body_id = StringName("")
		compact_root_overview = false
		compact_focus_branch = false


class DerivedSnapshotCacheProbe:
	extends RefCounted

	var last_interest_ids: Array[StringName] = []

	func set_interest_ids(ids: Array[StringName]) -> void:
		last_interest_ids = []
		last_interest_ids.append_array(ids)

	func get_environment_desc(id: StringName) -> Dictionary:
		return {"present": true} if last_interest_ids.has(id) else {}

	func get_life_ecology_desc(id: StringName) -> Dictionary:
		return {"present": true} if last_interest_ids.has(id) else {}


class DebugOverlayProbe:
	extends DebugOverlayScript

	func _process(_delta: float) -> void:
		pass

	func mark_dirty(_immediate: bool = false) -> void:
		pass

	func set_view_context(_is_large_world: bool, _frame_label: StringName) -> void:
		pass


class StreamingControllerProbe:
	extends RefCounted

	var focus_root_id: StringName = &"obsidian"
	var resident_root_ids: Array[StringName] = [&"obsidian"]
	var order_log: Array = []

	func get_focus_root_id() -> StringName:
		return focus_root_id

	func update(_delta: float, _zoom_factor: float) -> void:
		order_log.append("streaming.update")

	func get_resident_root_ids() -> Array[StringName]:
		var out: Array[StringName] = []
		out.append_array(resident_root_ids)
		return out


class TopologyProbe:
	extends RefCounted

	var root_id_by_body_id := {
		&"obsidian": &"obsidian",
		&"alpha": &"obsidian",
		&"alpha_i": &"obsidian",
		&"alpha_i_m": &"obsidian",
		&"onyx": &"onyx",
	}

	func root_id_of(id: StringName) -> StringName:
		return root_id_by_body_id.get(id, StringName(""))


class WorldLoaderProbe:
	extends Node

	signal world_loaded(world_id: StringName)


class RendererProbe:
	extends OrbitViewRendererScript

	var rebuild_count: int = 0
	var order_log: Array = []
	var sync_force_flags: Array[bool] = []

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func rebuild_from_registry() -> void:
		rebuild_count += 1

	func set_frame_label(_frame_label: StringName) -> void:
		order_log.append("view_lod.set_frame_label")

	func sync_visuals_now(force: bool = false) -> void:
		order_log.append("renderer.sync")
		sync_force_flags.append(force)


class GalaxyProxyRendererProbe:
	extends Node2D


class ActivationSetProcessProbe:
	extends BubbleActivationSet

	var active_ids: Array[StringName] = [&"alpha"]

	func rebuild() -> void:
		pass

	func get_active_ids() -> Array[StringName]:
		var out: Array[StringName] = []
		out.append_array(active_ids)
		return out


class OrbitServiceProcessProbe:
	extends OrbitService

	var requested_ids: Array[StringName] = []

	func request_numeric_local_candidates(ids: Array[StringName]) -> void:
		requested_ids = []
		requested_ids.append_array(ids)


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_testbed_root_inspector"
	_test_root_inspector_opens_only_explicitly_and_overrides_root_overview_interest(ctx)
	_test_root_inspector_toggle_is_the_explicit_open_path(ctx)
	_test_root_inspector_tracks_root_overview_compact_mode(ctx)
	_test_root_inspector_stays_closed_for_focus_and_streaming_events_and_resets_on_world_change(ctx)
	_test_root_inspector_clicks_use_immediate_focus_fit(ctx)
	_test_non_large_world_keeps_root_inspector_hidden(ctx)
	_test_galaxy_proxy_visibility_is_root_overview_only(ctx)
	_test_process_syncs_view_lod_before_renderer_and_streaming(ctx)
	_test_immediate_focus_syncs_view_lod_before_forced_renderer(ctx)
	_test_view_bookmark_restore_syncs_view_lod_before_forced_renderer(ctx)
	_test_view_bookmark_shortcuts_route_to_slots(ctx)
	_test_view_bookmark_slots_store_and_restore_camera_state(ctx)
	_test_view_bookmark_restore_ignores_stale_or_cross_world_slots(ctx)
	_test_perf_snapshot_json_safe_converts_godot_variants(ctx)
	_test_perf_snapshot_builds_json_sidecar_dictionary(ctx)


static func _test_root_inspector_opens_only_explicitly_and_overrides_root_overview_interest(ctx) -> void:
	var testbed = _build_testbed_probe(true)
	testbed._refresh_snapshot_interest_ids()
	ctx.assert_true(not testbed._root_inspector.is_open(), "Large-World-Probe startet mit geschlossenem Root-Inspector")
	ctx.assert_true(testbed._derived_snapshot_cache.last_interest_ids.is_empty(), "ROOT_OVERVIEW ohne Inspector bleibt fokus-only und setzt kein planetares Interest")

	testbed._open_root_inspector_for_current_root()
	ctx.assert_true(testbed._root_inspector.is_open(), "Explizites Root-Oeffnen macht den Inspector sichtbar")
	ctx.assert_true(
		testbed._derived_snapshot_cache.last_interest_ids == [&"alpha_i", &"alpha_i_m"],
		"Offener Inspector aktiviert im ROOT_OVERVIEW wieder root-lokales Planet-/Moon-Interest fuer genau den Fokus-Root"
	)

	testbed._root_inspector.close_panel()
	testbed._on_root_inspector_closed()
	ctx.assert_true(not testbed._root_inspector.is_open(), "Schliessen blendet den Inspector wieder aus")
	ctx.assert_true(testbed._derived_snapshot_cache.last_interest_ids.is_empty(), "Nach dem Schliessen faellt ROOT_OVERVIEW sofort auf fokus-only zurueck")
	_destroy_testbed_probe(testbed)


static func _test_root_inspector_toggle_is_the_explicit_open_path(ctx) -> void:
	var testbed = _build_testbed_probe(true)
	testbed._refresh_snapshot_interest_ids()
	ctx.assert_true(not testbed._root_inspector.is_open(), "Root-Inspector startet fuer den Toggle-Test geschlossen")

	testbed._toggle_root_inspector_for_current_root()
	ctx.assert_true(testbed._root_inspector.is_open(), "I-/Toggle-Pfad oeffnet den Root-Inspector explizit")
	ctx.assert_true(
		testbed._derived_snapshot_cache.last_interest_ids == [&"alpha_i", &"alpha_i_m"],
		"Geoeffneter Toggle-Inspector aktiviert denselben root-lokalen Interest wie explizites Oeffnen"
	)

	testbed._toggle_root_inspector_for_current_root()
	ctx.assert_true(not testbed._root_inspector.is_open(), "I-/Toggle-Pfad schliesst den Root-Inspector wieder")
	ctx.assert_true(testbed._derived_snapshot_cache.last_interest_ids.is_empty(), "Geschlossener Toggle-Inspector stellt ROOT_OVERVIEW fokus-only wieder her")
	_destroy_testbed_probe(testbed)


static func _test_root_inspector_tracks_root_overview_compact_mode(ctx) -> void:
	var testbed = _build_testbed_probe(true)
	var bubble: BubbleProbe = testbed._bubble
	var camera: CameraControllerProbe = testbed._camera_controller
	var inspector: RootInspectorProbe = testbed._root_inspector

	camera.frame_label = OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW
	testbed._sync_view_lod_state(true, false)
	ctx.assert_true(inspector.compact_root_overview, "Root-Overview setzt den Inspector in den kompakten Navigator-Modus")
	ctx.assert_true(not inspector.compact_focus_branch, "Root-Overview nutzt nicht gleichzeitig den Focus-Branch-Modus")

	camera.frame_label = OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK
	bubble.set_focus(&"obsidian")
	testbed._sync_view_lod_state(true, false)
	ctx.assert_true(inspector.compact_root_overview, "Root-/BH-Fokus behaelt den kompakten Navigator-Modus")
	ctx.assert_true(not inspector.compact_focus_branch, "Root-/BH-Fokus nutzt keinen lokalen Focus-Branch")

	bubble.set_focus(&"alpha")
	testbed._sync_view_lod_state(true, false)
	ctx.assert_true(not inspector.compact_root_overview, "Lokaler Sternfokus deaktiviert den Root-Overview-Kompaktmodus")
	ctx.assert_true(inspector.compact_focus_branch, "Lokaler Sternfokus nutzt den kompakten fokussierten Teilbaum")
	_destroy_testbed_probe(testbed)


static func _test_root_inspector_stays_closed_for_focus_and_streaming_events_and_resets_on_world_change(ctx) -> void:
	var testbed = _build_testbed_probe(true)
	testbed._focus_index = 2
	testbed._set_focus(&"alpha_i")
	ctx.assert_true(not testbed._root_inspector.is_open(), "Normale Fokuswechsel ueber _set_focus oeffnen den Inspector nicht implizit")

	testbed._focus_index = 0
	testbed._cycle_focus(1)
	ctx.assert_true(not testbed._root_inspector.is_open(), "Cycle-/Tab-artige Fokuswechsel oeffnen den Inspector nicht implizit")

	var resident_root_ids: Array[StringName] = [&"obsidian"]
	testbed._on_streaming_residency_changed(resident_root_ids, &"obsidian")
	ctx.assert_true(not testbed._root_inspector.is_open(), "passive Residency-/Neighbor-Wechsel oeffnen den Inspector nicht")

	testbed._open_root_inspector_for_current_root()
	ctx.assert_true(testbed._root_inspector.is_open(), "Explizites Oeffnen funktioniert weiterhin nach passiven Fokus-/Streaming-Ereignissen")
	testbed._on_world_loader_world_loaded(&"starter_world")
	ctx.assert_true(not testbed._root_inspector.is_open(), "Welt-Wechsel schliesst den Inspector hart")
	ctx.assert_true(testbed._root_inspector.get_root_id() == StringName(""), "Welt-Wechsel loescht den Inspector-Kontext")
	ctx.assert_true(testbed._derived_snapshot_cache.last_interest_ids.is_empty(), "Welt-Wechsel hebt jeden aktiven Interest-Override sofort wieder auf")
	_destroy_testbed_probe(testbed)


static func _test_non_large_world_keeps_root_inspector_hidden(ctx) -> void:
	var testbed = _build_testbed_probe(false)
	testbed._open_root_inspector_for_current_root()
	ctx.assert_true(not testbed._root_inspector.is_open(), "Nicht-Large-World-Pfade ignorieren das Root-Inspector-Oeffnen komplett")
	_destroy_testbed_probe(testbed)


static func _test_galaxy_proxy_visibility_is_root_overview_only(ctx) -> void:
	var testbed = _build_testbed_probe(true)
	var camera: CameraControllerProbe = testbed._camera_controller
	var proxy: Node2D = testbed._galaxy_proxy_renderer

	camera.frame_label = OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW
	proxy.visible = false
	testbed._sync_view_lod_state(false, false)
	ctx.assert_true(proxy.visible, "Galaxy-Proxies bleiben im Root-Overview sichtbar")

	camera.frame_label = OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK
	testbed._sync_view_lod_state(false, false)
	ctx.assert_true(not proxy.visible, "Galaxy-Proxies schlafen im lokalen Fokus-/Detailblick")
	_destroy_testbed_probe(testbed)


static func _test_process_syncs_view_lod_before_renderer_and_streaming(ctx) -> void:
	var testbed = _build_testbed_probe(true, true)
	var order: Array = []
	_attach_order_log(testbed, order)
	var activation := ActivationSetProcessProbe.new()
	var orbit_service := OrbitServiceProcessProbe.new()
	testbed.add_child(activation)
	testbed.add_child(orbit_service)
	testbed._activation_set = activation
	testbed._orbit_service = orbit_service

	testbed._process(0.016)

	_assert_call_before(ctx, order, "camera.step", "view_lod.set_frame_label",
		"_process aktualisiert erst die Kamera und dann den Frame-/LOD-Kontext")
	_assert_call_before(ctx, order, "view_lod.set_frame_label", "renderer.sync",
		"_process spiegelt den Frame-/LOD-Kontext vor dem Renderer-Sync")
	_assert_call_before(ctx, order, "renderer.sync", "streaming.update",
		"_process laesst Streaming nach dem Renderer-Sync")
	_destroy_testbed_probe(testbed)


static func _test_immediate_focus_syncs_view_lod_before_forced_renderer(ctx) -> void:
	var testbed = _build_testbed_probe(true, true)
	var order: Array = []
	_attach_order_log(testbed, order)
	var renderer: RendererProbe = testbed._renderer

	testbed._set_focus(&"alpha", true, true)

	_assert_call_before(ctx, order, "camera.step", "view_lod.set_frame_label",
		"Immediate-Fokus aktualisiert erst die Kamera und dann den Frame-/LOD-Kontext")
	_assert_call_before(ctx, order, "view_lod.set_frame_label", "renderer.sync",
		"Immediate-Fokus spiegelt den Frame-/LOD-Kontext vor dem forced Renderer-Sync")
	ctx.assert_true(renderer.sync_force_flags.size() == 1 and renderer.sync_force_flags[0],
		"Immediate-Fokus erzwingt genau einen Renderer-Sync im selben Pfad")
	_destroy_testbed_probe(testbed)


static func _test_view_bookmark_restore_syncs_view_lod_before_forced_renderer(ctx) -> void:
	var testbed = _build_testbed_probe(true, true)
	var order: Array = []
	_attach_order_log(testbed, order)
	var renderer: RendererProbe = testbed._renderer
	testbed._store_view_bookmark_slot(1)
	order.clear()
	renderer.sync_force_flags.clear()

	testbed._restore_view_bookmark_slot(1)

	_assert_call_before(ctx, order, "camera.step", "view_lod.set_frame_label",
		"Bookmark-Restore aktualisiert erst die Kamera und dann den Frame-/LOD-Kontext")
	_assert_call_before(ctx, order, "view_lod.set_frame_label", "renderer.sync",
		"Bookmark-Restore spiegelt den Frame-/LOD-Kontext vor dem forced Renderer-Sync")
	ctx.assert_true(renderer.sync_force_flags.size() == 1 and renderer.sync_force_flags[0],
		"Bookmark-Restore erzwingt genau einen Renderer-Sync im selben Pfad")
	_destroy_testbed_probe(testbed)


static func _test_root_inspector_clicks_use_immediate_focus_fit(ctx) -> void:
	var testbed = _build_testbed_probe(true)
	var camera: CameraControllerProbe = testbed._camera_controller
	testbed._open_root_inspector_for_current_root()
	testbed._on_root_inspector_focus_requested(&"alpha_i")
	ctx.assert_true(camera.focused_ids.back() == &"alpha_i", "Inspector-Klick routed weiter ueber denselben Fokuspfad")
	ctx.assert_true(camera.immediate_flags.back(), "Inspector-Klick fordert jetzt eine sofortige Kamerazentrierung an")
	ctx.assert_true(camera.force_fit_flags.back(), "Inspector-Klick fordert jetzt zusaetzlich einen Fit des Fokus-Scope an")
	ctx.assert_true(testbed._root_inspector.is_open(), "Inspector bleibt nach dem Fokus-Sprung offen")
	_destroy_testbed_probe(testbed)


static func _test_view_bookmark_slots_store_and_restore_camera_state(ctx) -> void:
	var testbed = _build_testbed_probe(true)
	var camera: CameraControllerProbe = testbed._camera_controller
	testbed._store_view_bookmark_slot(1)
	camera.captured_state = {
		"focus_id": &"alpha",
		"zoom_factor": 1.5,
		"manual_pan_ru": Vector2.ZERO,
	}
	testbed._restore_view_bookmark_slot(1)

	ctx.assert_true(camera.restored_states.size() == 1, "Bookmark-Restore ruft den Camera-Controller genau einmal")
	var restored_state: Dictionary = camera.restored_states[0]
	var restored_pan: Vector2 = restored_state.get("manual_pan_ru", Vector2.ZERO)
	ctx.assert_true(StringName(restored_state.get("focus_id", StringName(""))) == &"alpha_i", "Slot merkt den gespeicherten Fokus")
	ctx.assert_almost(float(restored_state.get("zoom_factor", 0.0)), 4.0, 1.0e-9, "Slot merkt den gespeicherten Zoom")
	ctx.assert_true(restored_pan == Vector2(8.0, -3.0), "Slot merkt den gespeicherten Pan")
	ctx.assert_true(camera.restore_immediate_flags[0], "Bookmark-Restore snappt die Kamera sofort")
	ctx.assert_true(testbed._focus_index == 2, "Bookmark-Restore aktualisiert den Fokusindex")
	_destroy_testbed_probe(testbed)


static func _test_view_bookmark_shortcuts_route_to_slots(ctx) -> void:
	var testbed = _build_testbed_probe(true)
	var camera: CameraControllerProbe = testbed._camera_controller
	var store_event := _key_press(KEY_1, true)
	ctx.assert_true(testbed._handle_view_bookmark_key_event(store_event), "Ctrl+1 wird als Bookmark-Save behandelt")
	ctx.assert_true(testbed._view_bookmarks.has(1), "Ctrl+1 speichert Slot 1")

	var restore_event := _key_press(KEY_1, false)
	ctx.assert_true(testbed._handle_view_bookmark_key_event(restore_event), "1 wird als Bookmark-Restore behandelt")
	ctx.assert_true(camera.restored_states.size() == 1, "1 restored den gespeicherten Slot")

	var shifted_event := _key_press(KEY_2, false, true)
	ctx.assert_true(not testbed._handle_view_bookmark_key_event(shifted_event), "Shift+2 bleibt frei fuer Tastaturlayout-Zeichen")
	_destroy_testbed_probe(testbed)


static func _test_view_bookmark_restore_ignores_stale_or_cross_world_slots(ctx) -> void:
	var testbed = _build_testbed_probe(true)
	var camera: CameraControllerProbe = testbed._camera_controller
	testbed._view_bookmarks[1] = {
		"focus_id": &"missing_body",
		"zoom_factor": 2.0,
		"manual_pan_ru": Vector2.ZERO,
		"world_scope_id": testbed._active_world_scope_id,
	}
	testbed._restore_view_bookmark_slot(1)
	ctx.assert_true(camera.restored_states.is_empty(), "Stale Bookmark-Foki werden ignoriert")

	testbed._view_bookmarks[2] = {
		"focus_id": &"alpha_i",
		"zoom_factor": 2.0,
		"manual_pan_ru": Vector2.ZERO,
		"world_scope_id": &"other_world",
	}
	testbed._restore_view_bookmark_slot(2)
	ctx.assert_true(camera.restored_states.is_empty(), "Bookmarks aus anderem World-Scope werden ignoriert")
	_destroy_testbed_probe(testbed)


static func _test_perf_snapshot_json_safe_converts_godot_variants(ctx) -> void:
	var safe: Dictionary = OrbitTestbedScript._json_safe({
		"id": &"alpha",
		&"named_key": "named-value",
		"position": Vector2(1.5, -2.0),
		"velocity": Vector3(3.0, 4.0, 5.0),
		"labels": PackedStringArray(["one", "two"]),
		"colors": PackedColorArray([Color(0.1, 0.2, 0.3, 0.4)]),
	})
	ctx.assert_true(safe.get("id", "") == "alpha", "Perf-Snapshot JSON-Safe wandelt StringName in String")
	ctx.assert_true(safe.get("named_key", "") == "named-value", "Perf-Snapshot JSON-Safe wandelt StringName-Keys in Strings")
	ctx.assert_true(safe.get("position", {}).get("x", 0.0) == 1.5, "Perf-Snapshot JSON-Safe wandelt Vector2 in Dictionary")
	ctx.assert_true(safe.get("velocity", {}).get("z", 0.0) == 5.0, "Perf-Snapshot JSON-Safe wandelt Vector3 in Dictionary")
	ctx.assert_true(safe.get("labels", []).size() == 2, "Perf-Snapshot JSON-Safe wandelt PackedStringArray in Array")
	ctx.assert_almost(float(safe.get("colors", [])[0].get("a", 0.0)), 0.4, 1.0e-6, "Perf-Snapshot JSON-Safe wandelt PackedColorArray in Dictionaries")
	ctx.assert_true(JSON.stringify(safe) != "", "Perf-Snapshot JSON-Safe bleibt JSON-stringifizierbar")


static func _test_perf_snapshot_builds_json_sidecar_dictionary(ctx) -> void:
	var testbed = OrbitTestbedScript.new()
	var bubble := BubbleProbe.new()
	var camera := CameraControllerProbe.new()
	var topology := TopologyProbe.new()
	camera.bubble = bubble
	camera.frame_label = OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK
	bubble.focus_id = &"alpha"

	UniverseRegistry.clear()
	_register_probe_body(&"obsidian", BodyType.Kind.BLACK_HOLE, StringName(""))
	_register_probe_body(&"alpha", BodyType.Kind.STAR, &"obsidian")
	_register_probe_body(&"alpha_i", BodyType.Kind.PLANET, &"alpha")

	testbed._bubble = bubble
	testbed._camera_controller = camera
	testbed._topology = topology
	testbed._is_large_world = true
	testbed._active_world_scope_id = &"probe_galaxy"
	var focus_order: Array[StringName] = [&"obsidian", &"alpha", &"alpha_i"]
	testbed._focus_order = focus_order
	testbed._focus_index = 1
	testbed._last_frame_label = OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK

	var snapshot: Dictionary = testbed._build_perf_probe_snapshot("user://perf_probe_probe.csv", 12)
	var safe: Dictionary = OrbitTestbedScript._json_safe(snapshot)
	ctx.assert_true(safe.get("schema", "") == "graviton_perf_probe_snapshot_v1", "Perf-Snapshot Sidecar traegt das Schema")
	ctx.assert_true(int(safe.get("csv_rows", 0)) == 12, "Perf-Snapshot Sidecar referenziert die CSV-Zeilen")
	ctx.assert_true(safe.get("focus", {}).get("id", "") == "alpha", "Perf-Snapshot Sidecar enthaelt den aktuellen Fokus")
	ctx.assert_true(int(safe.get("registry", {}).get("body_count", 0)) == 3, "Perf-Snapshot Sidecar enthaelt Registry-Counts")
	ctx.assert_true(safe.get("camera", {}).get("frame_label", "") == String(OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK), "Perf-Snapshot Sidecar enthaelt Kamera-Kontext")
	ctx.assert_true(JSON.stringify(safe) != "", "Perf-Snapshot Sidecar bleibt JSON-stringifizierbar")
	_destroy_testbed_probe(testbed)


static func _key_press(keycode: int, ctrl_pressed: bool, shift_pressed: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	event.ctrl_pressed = ctrl_pressed
	event.shift_pressed = shift_pressed
	return event


static func _assert_call_before(ctx, order: Array, before: String, after: String, message: String) -> void:
	var before_index: int = order.find(before)
	var after_index: int = order.find(after)
	ctx.assert_true(before_index >= 0, "%s: %s wurde aufgezeichnet" % [message, before])
	ctx.assert_true(after_index >= 0, "%s: %s wurde aufgezeichnet" % [message, after])
	ctx.assert_true(before_index >= 0 and after_index >= 0 and before_index < after_index,
		"%s (%s vor %s, order=%s)" % [message, before, after, str(order)])


static func _attach_order_log(testbed, order: Array) -> void:
	var camera: CameraControllerProbe = testbed._camera_controller
	var renderer: RendererProbe = testbed._renderer
	var streaming: StreamingControllerProbe = testbed._streaming_controller
	camera.order_log = order
	renderer.order_log = order
	streaming.order_log = order


static func _build_testbed_probe(is_large_world: bool, order_testbed: bool = false):
	var testbed = OrderTestbedProbe.new() if order_testbed else OrbitTestbedScript.new()
	var bubble := BubbleProbe.new()
	var camera := CameraControllerProbe.new()
	camera.bubble = bubble
	var root_inspector := RootInspectorProbe.new()
	var cache := DerivedSnapshotCacheProbe.new()
	var debug_overlay := DebugOverlayProbe.new()
	var streaming := StreamingControllerProbe.new()
	var topology := TopologyProbe.new()
	var world_loader := WorldLoaderProbe.new()
	var renderer := RendererProbe.new()
	var proxy_renderer := GalaxyProxyRendererProbe.new()

	testbed.add_child(bubble)
	testbed.add_child(root_inspector)
	testbed.add_child(debug_overlay)
	testbed.add_child(world_loader)
	testbed.add_child(renderer)
	testbed.add_child(proxy_renderer)

	testbed._is_large_world = is_large_world
	testbed._bubble = bubble
	testbed._camera_controller = camera
	testbed._root_inspector = root_inspector
	testbed._derived_snapshot_cache = cache
	testbed._debug_overlay = debug_overlay
	testbed._streaming_controller = streaming
	testbed._topology = topology
	testbed._world_loader = world_loader
	testbed._renderer = renderer
	testbed._galaxy_proxy_renderer = proxy_renderer
	var focus_order: Array[StringName] = [&"obsidian", &"alpha", &"alpha_i", &"alpha_i_m"]
	testbed._focus_order = focus_order
	testbed._active_world_scope_id = &"pilot_galaxy"
	testbed._last_frame_label = OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW

	UniverseRegistry.clear()
	_register_probe_body(&"obsidian", BodyType.Kind.BLACK_HOLE, StringName(""))
	_register_probe_body(&"alpha", BodyType.Kind.STAR, &"obsidian")
	_register_probe_body(&"alpha_i", BodyType.Kind.PLANET, &"alpha")
	_register_probe_body(&"alpha_i_m", BodyType.Kind.MOON, &"alpha_i")
	_register_probe_body(&"onyx", BodyType.Kind.BLACK_HOLE, StringName(""))
	return testbed


static func _destroy_testbed_probe(testbed) -> void:
	if testbed != null:
		if testbed._proto_biosphere_service != null:
			testbed._proto_biosphere_service.free()
			testbed._proto_biosphere_service = null
		if testbed._biosphere_scale_service != null:
			testbed._biosphere_scale_service.free()
			testbed._biosphere_scale_service = null
		if testbed._native_species_service != null:
			testbed._native_species_service.free()
			testbed._native_species_service = null
		if testbed._life_ecology_service != null:
			testbed._life_ecology_service.free()
			testbed._life_ecology_service = null
		if testbed._genetic_species_service != null:
			testbed._genetic_species_service.free()
			testbed._genetic_species_service = null
		if testbed._orbit_readout_service != null:
			testbed._orbit_readout_service.free()
			testbed._orbit_readout_service = null
		if testbed._life_potential_service != null:
			testbed._life_potential_service.free()
			testbed._life_potential_service = null
		if testbed._planetary_state_service != null:
			testbed._planetary_state_service.free()
			testbed._planetary_state_service = null
		if testbed._planetary_year_sampler != null:
			testbed._planetary_year_sampler.free()
			testbed._planetary_year_sampler = null
		testbed.free()
	UniverseRegistry.clear()


static func _register_probe_body(id: StringName, kind: int, parent_id: StringName) -> void:
	if UniverseRegistry.has_body(id):
		return
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id).capitalize()
	def.kind = kind
	def.mass_kg = 1.0
	def.radius_m = 1.0
	def.parent_id = parent_id
	if parent_id == StringName(""):
		def.orbit_profile = null
	else:
		var profile := OrbitProfile.new()
		profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
		profile.authored_radius_m = 1.0
		profile.authored_period_s = 1.0
		def.orbit_profile = profile
	UniverseRegistry.register_body(def)
