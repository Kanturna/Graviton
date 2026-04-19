extends RefCounted

const DebugOverlayScript = preload("res://src/tools/debug/debug_overlay.gd")
const SimTestHarnessScript = preload("res://src/tests/helpers/sim_test_harness.gd")


class BubbleStub:
	extends Node

	func get_focus() -> StringName:
		return &"planet_a"

	func compose_root_local_position_m(_id: StringName) -> Vector3:
		return Vector3.ZERO


static func run(ctx) -> void:
	ctx.current_suite = "test_debug_overlay"
	_test_debug_overlay_labels_primary_source_explicitly(ctx)


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
