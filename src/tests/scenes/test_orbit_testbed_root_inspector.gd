extends RefCounted

const OrbitTestbedScript = preload("res://scenes/testbeds/orbit_testbed.gd")
const OrbitCameraFramingScript = preload("res://src/tools/rendering/orbit_camera_framing.gd")
const LocalBubbleManagerScript = preload("res://src/runtime/local_bubble/local_bubble_manager.gd")
const OrbitViewRendererScript = preload("res://src/tools/rendering/orbit_view_renderer.gd")
const DebugOverlayScript = preload("res://src/tools/debug/debug_overlay.gd")


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

	func set_focus(body_id: StringName, immediate := false, force_fit := false) -> void:
		focused_ids.append(body_id)
		immediate_flags.append(immediate)
		force_fit_flags.append(force_fit)
		if bubble != null:
			bubble.set_focus(body_id)

	func step(_delta: float, _viewport_size: Vector2) -> void:
		pass

	func get_frame_label() -> StringName:
		return frame_label

	func fit_current_focus() -> void:
		pass


class RootInspectorProbe:
	extends PanelContainer

	var open: bool = false
	var root_id: StringName = &""
	var focused_body_id: StringName = &""
	var auto_open_count: int = 0

	func set_root_context(next_root_id: StringName, next_focused_body_id: StringName, auto_open: bool = false) -> void:
		root_id = next_root_id
		focused_body_id = next_focused_body_id
		if auto_open:
			open = true
			auto_open_count += 1

	func is_open() -> bool:
		return open

	func get_root_id() -> StringName:
		return root_id

	func close_panel() -> void:
		open = false

	func clear_state() -> void:
		open = false
		root_id = StringName("")
		focused_body_id = StringName("")


class DerivedSnapshotCacheProbe:
	extends RefCounted

	var last_interest_ids: Array[StringName] = []

	func set_interest_ids(ids: Array[StringName]) -> void:
		last_interest_ids = []
		last_interest_ids.append_array(ids)

	func get_environment_desc(id: StringName) -> Dictionary:
		return {"present": true} if last_interest_ids.has(id) else {}


class DebugOverlayProbe:
	extends DebugOverlayScript

	func mark_dirty(_immediate: bool = false) -> void:
		pass

	func set_view_context(_is_large_world: bool, _frame_label: StringName) -> void:
		pass


class StreamingControllerProbe:
	extends RefCounted

	var focus_root_id: StringName = &"obsidian"
	var resident_root_ids: Array[StringName] = [&"obsidian"]

	func get_focus_root_id() -> StringName:
		return focus_root_id

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

	func rebuild_from_registry() -> void:
		rebuild_count += 1

	func set_frame_label(_frame_label: StringName) -> void:
		pass


class GalaxyProxyRendererProbe:
	extends Node2D


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_testbed_root_inspector"
	_test_root_inspector_opens_only_explicitly_and_overrides_root_overview_interest(ctx)
	_test_root_inspector_stays_closed_for_focus_and_streaming_events_and_resets_on_world_change(ctx)
	_test_root_inspector_clicks_use_immediate_focus_fit(ctx)
	_test_non_large_world_keeps_root_inspector_hidden(ctx)


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


static func _build_testbed_probe(is_large_world: bool):
	var testbed = OrbitTestbedScript.new()
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
