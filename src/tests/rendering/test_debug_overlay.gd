extends RefCounted

const DebugOverlayScript = preload("res://src/tools/debug/debug_overlay.gd")
const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")
const ThermalServiceScript = preload("res://src/sim/thermal/thermal_service.gd")
const OrbitCameraFramingScript = preload("res://src/tools/rendering/orbit_camera_framing.gd")


class BubbleStub:
	extends Node

	func get_focus() -> StringName:
		return &"planet_a"

	func compose_root_local_position_m(_id: StringName) -> Vector3:
		return Vector3.ZERO


class SnapshotCacheStub:
	extends RefCounted

	var thermal_desc_by_id: Dictionary = {}

	func get_thermal_desc(id: StringName) -> Dictionary:
		return thermal_desc_by_id.get(id, {})


class ThermalProbe:
	extends Node

	var describe_calls: int = 0

	func describe_body(_id: StringName) -> Dictionary:
		describe_calls += 1
		return {
			ThermalServiceScript.KEY_SOURCE_ID: &"probe_star",
			ThermalServiceScript.KEY_INSOLATION_WPM2: 1.0,
			ThermalServiceScript.KEY_ABSORBED_FLUX_WPM2: 1.0,
			ThermalServiceScript.KEY_EQUILIBRIUM_TEMPERATURE_K: 1.0,
		}


static func run(ctx) -> void:
	ctx.current_suite = "test_debug_overlay"
	_test_debug_overlay_labels_primary_source_explicitly(ctx)
	_test_debug_overlay_stays_snapshot_only_on_cache_miss(ctx)
	_test_debug_overlay_uses_compact_summary_in_large_world_root_overview(ctx)
	_test_debug_overlay_throttles_rebuilds_but_reacts_immediately_to_view_context_changes(ctx)


static func _test_debug_overlay_labels_primary_source_explicitly(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var overlay = DebugOverlayScript.new()
	var bubble := BubbleStub.new()
	overlay.configure(
		setup[SimTestHarnessScript.HARNESS_KEY_REGISTRY],
		setup[SimTestHarnessScript.HARNESS_KEY_TIME_SERVICE],
		bubble,
		null,
		setup[SimTestHarnessScript.HARNESS_KEY_THERMAL_SERVICE]
	)

	var text: String = overlay._build_text()
	ctx.assert_true(
		text.contains("primary_source=sol"),
		"DebugOverlay weist die Primaerquelle explizit als primary_source aus"
	)

	overlay.free()
	bubble.free()
	SimTestHarnessScript.teardown_context(setup)


static func _test_debug_overlay_stays_snapshot_only_on_cache_miss(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var overlay = DebugOverlayScript.new()
	var bubble := BubbleStub.new()
	var snapshot_cache := SnapshotCacheStub.new()
	var thermal_probe := ThermalProbe.new()
	overlay.configure(
		setup[SimTestHarnessScript.HARNESS_KEY_REGISTRY],
		setup[SimTestHarnessScript.HARNESS_KEY_TIME_SERVICE],
		bubble,
		null,
		thermal_probe,
		snapshot_cache
	)

	var text: String = overlay._build_text()
	ctx.assert_true(
		text.contains("primary_source=n/a"),
		"DebugOverlay zeigt bei Snapshot-Cache-Miss nur snapshot-only n/a statt Live-Derived-Werte"
	)
	ctx.assert_true(
		thermal_probe.describe_calls == 0,
		"DebugOverlay faellt bei vorhandenem Snapshot-Cache nie live auf ThermalService.describe_body zurueck"
	)

	overlay.free()
	bubble.free()
	thermal_probe.free()
	SimTestHarnessScript.teardown_context(setup)


static func _test_debug_overlay_uses_compact_summary_in_large_world_root_overview(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var overlay = DebugOverlayScript.new()
	var label := RichTextLabel.new()
	overlay.add_child(label)
	overlay._label = label
	var bubble := BubbleStub.new()
	overlay.configure(
		setup[SimTestHarnessScript.HARNESS_KEY_REGISTRY],
		setup[SimTestHarnessScript.HARNESS_KEY_TIME_SERVICE],
		bubble,
		null,
		setup[SimTestHarnessScript.HARNESS_KEY_THERMAL_SERVICE]
	)
	overlay.set_view_context(true, OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW)

	var text: String = overlay._build_text()
	ctx.assert_true(
		text.contains("[b]Overview Summary[/b]"),
		"DebugOverlay zeigt im Large-World-ROOT_OVERVIEW eine kompakte Summary"
	)
	ctx.assert_true(
		text.contains("body_counts ="),
		"DebugOverlay fasst im Overview die Body-Typen als Counts zusammen"
	)
	ctx.assert_true(
		not text.contains("[b]Bodies (truth: parent-frame)[/b]"),
		"DebugOverlay blendet die volle Body-Tabelle im Large-World-ROOT_OVERVIEW aus"
	)

	overlay.free()
	bubble.free()
	SimTestHarnessScript.teardown_context(setup)


static func _test_debug_overlay_throttles_rebuilds_but_reacts_immediately_to_view_context_changes(ctx) -> void:
	var setup: Dictionary = SimTestHarnessScript.build_named_world_context(&"sample_system")
	var overlay = DebugOverlayScript.new()
	var label := RichTextLabel.new()
	overlay.add_child(label)
	overlay._label = label
	overlay.visible = true
	var bubble := BubbleStub.new()
	overlay.configure(
		setup[SimTestHarnessScript.HARNESS_KEY_REGISTRY],
		setup[SimTestHarnessScript.HARNESS_KEY_TIME_SERVICE],
		bubble,
		null,
		setup[SimTestHarnessScript.HARNESS_KEY_THERMAL_SERVICE]
	)

	overlay.mark_dirty(true)
	var initial_refresh_count: int = int(overlay.get_debug_snapshot().get("refresh_count", 0))
	ctx.assert_true(initial_refresh_count == 1, "sichtbares Overlay kann sofort einen initialen Rebuild ausloesen")

	overlay._process(0.05)
	ctx.assert_true(
		int(overlay.get_debug_snapshot().get("refresh_count", 0)) == initial_refresh_count,
		"Overlay rebuildet innerhalb der 5-Hz-Cadence nicht erneut"
	)

	overlay._process(0.20)
	ctx.assert_true(
		int(overlay.get_debug_snapshot().get("refresh_count", 0)) == initial_refresh_count + 1,
		"Overlay rebuildet nach Ablauf der 5-Hz-Cadence erneut"
	)

	overlay.set_view_context(true, OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW)
	ctx.assert_true(
		int(overlay.get_debug_snapshot().get("refresh_count", 0)) == initial_refresh_count + 2,
		"View-Context-Wechsel triggert bei sichtbarem Overlay sofort einen Rebuild"
	)

	overlay.free()
	bubble.free()
	SimTestHarnessScript.teardown_context(setup)
