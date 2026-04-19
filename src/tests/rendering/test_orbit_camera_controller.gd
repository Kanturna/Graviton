extends RefCounted


const OrbitCameraControllerScript = preload("res://src/tools/rendering/orbit_camera_controller.gd")


class BubbleStub:
	extends RefCounted

	var _focus: StringName = &""

	func set_focus(body_id: StringName) -> void:
		_focus = body_id

	func get_focus() -> StringName:
		return _focus


class RendererStub:
	extends RefCounted

	var positions: Dictionary = {}
	var frames: Dictionary = {}
	var focused_id: StringName = &""
	var cleared_trails: int = 0
	var scale: Vector2 = Vector2.ONE
	var position: Vector2 = Vector2.ZERO
	var last_world_scale: float = 1.0
	var last_focus_closeup_ratio: float = 1.0

	func set_focus(body_id: StringName) -> void:
		focused_id = body_id

	func clear_trails() -> void:
		cleared_trails += 1

	func get_body_view_position_ru(body_id: StringName) -> Vector2:
		return positions.get(body_id, Vector2(INF, INF))

	func get_scope_frame(body_id: StringName) -> Dictionary:
		return frames.get(body_id, {"center": Vector2.ZERO, "radius": 1.0})

	func set_world_scale(value: float) -> void:
		last_world_scale = value

	func set_focus_closeup_ratio(value: float) -> void:
		last_focus_closeup_ratio = value


class TopologyStub:
	extends RefCounted

	var roots: Dictionary = {}

	func root_id_of(body_id: StringName) -> StringName:
		return roots.get(body_id, StringName(""))


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_camera_controller"
	_test_force_fit_centers_on_focus_and_resets_pan(ctx)
	_test_wide_zoom_keeps_focus_centered(ctx)
	_test_zoom_multiplier_clamps_to_bounds(ctx)
	_test_closeup_zoom_updates_focus_ratio(ctx)
	_test_focus_change_resets_to_new_scope_fit(ctx)
	_test_explicit_root_focus_uses_root_scope(ctx)


static func _make_controller() -> Dictionary:
	var controller = OrbitCameraControllerScript.new()
	var renderer := RendererStub.new()
	var bubble := BubbleStub.new()
	var topology := TopologyStub.new()
	var registry := Node.new()
	renderer.positions = {
		&"root": Vector2.ZERO,
		&"planet": Vector2(100.0, 50.0),
	}
	renderer.frames = {
		&"root": {"center": Vector2.ZERO, "radius": 100.0},
		&"planet": {"center": Vector2(100.0, 50.0), "radius": 25.0},
	}
	topology.roots = {
		&"planet": &"root",
		&"root": &"root",
	}
	controller.configure(renderer, bubble, registry, topology)
	return {
		"controller": controller,
		"renderer": renderer,
		"bubble": bubble,
		"registry": registry,
	}


static func _teardown_controller_setup(setup: Dictionary) -> void:
	var registry: Node = setup.get("registry", null)
	if registry != null:
		registry.free()


static func _test_force_fit_centers_on_focus_and_resets_pan(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	var bubble: BubbleStub = setup["bubble"]
	controller.handle_pan_input(Vector2.RIGHT, 1.0)
	controller.set_focus(&"planet", false, true)
	controller.step(0.0, Vector2(400.0, 200.0))
	ctx.assert_true(bubble.get_focus() == &"planet", "set_focus schreibt den Bubble-Fokus")
	ctx.assert_true(renderer.focused_id == &"planet", "set_focus schreibt den Renderer-Fokus")
	ctx.assert_true(renderer.cleared_trails == 1, "Fokuswechsel leert Trails")
	ctx.assert_almost(controller.get_zoom_factor(), 1.0, 1.0e-9, "force_fit setzt Zoom auf FIT")
	ctx.assert_almost(renderer.scale.x, 3.04, 1.0e-6, "FIT-Skala basiert auf dem Scope-Radius")
	ctx.assert_almost(renderer.position.x, -104.0, 1.0e-6, "FIT zentriert den Fokus im Viewport (x)")
	ctx.assert_almost(renderer.position.y, -52.0, 1.0e-6, "FIT zentriert den Fokus im Viewport (y)")
	_teardown_controller_setup(setup)


static func _test_wide_zoom_keeps_focus_centered(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(0.005)
	controller.step(0.0, Vector2(400.0, 200.0))
	var screen_pos: Vector2 = renderer.positions[&"planet"] * renderer.scale.x + renderer.position
	ctx.assert_almost(controller.get_zoom_factor(), 0.005, 1.0e-9, "Wide-Zoom clamp't auf MIN_ZOOM_FACTOR")
	ctx.assert_almost(screen_pos.x, 200.0, 1.0e-6, "Wide-Zoom haelt den Fokuskoerper im Viewportzentrum (x)")
	ctx.assert_almost(screen_pos.y, 100.0, 1.0e-6, "Wide-Zoom haelt den Fokuskoerper im Viewportzentrum (y)")
	_teardown_controller_setup(setup)


static func _test_zoom_multiplier_clamps_to_bounds(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	controller.handle_zoom_multiplier(1000000.0)
	ctx.assert_almost(controller.get_zoom_factor(), 100.0, 1.0e-9, "Zoom nach oben clamp't auf MAX_ZOOM_FACTOR")
	controller.handle_zoom_multiplier(1.0e-12)
	ctx.assert_almost(controller.get_zoom_factor(), 0.005, 1.0e-9, "Zoom nach unten clamp't auf MIN_ZOOM_FACTOR")
	_teardown_controller_setup(setup)


static func _test_closeup_zoom_updates_focus_ratio(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(2.0)
	controller.step(0.0, Vector2(400.0, 200.0))
	ctx.assert_true(controller.get_current_view_scale() > 3.04, "Closeup-Zoom vergroessert die aktuelle View-Skala ueber FIT")
	ctx.assert_true(renderer.last_focus_closeup_ratio > 1.0, "Renderer erhaelt fuer Closeups ein Ratio > 1.0")
	_teardown_controller_setup(setup)


static func _test_focus_change_resets_to_new_scope_fit(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(2.0)
	controller.set_focus(&"root")
	controller.step(0.0, Vector2(400.0, 200.0))
	ctx.assert_almost(controller.get_zoom_factor(), 1.0, 1.0e-9, "Fokuswechsel resetet auf FIT-Zoom")
	ctx.assert_almost(renderer.scale.x, 0.76, 1.0e-6, "neuer Fokus nutzt dessen eigenen Scope-Fit")
	_teardown_controller_setup(setup)


static func _test_explicit_root_focus_uses_root_scope(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"root", false, true)
	controller.step(0.0, Vector2(400.0, 200.0))
	ctx.assert_almost(renderer.scale.x, 0.76, 1.0e-6, "Root-Fokus nutzt den Root-Scope als expliziten Overview")
	ctx.assert_almost(renderer.position.x, 200.0, 1.0e-6, "Root-Fokus zentriert den Root-Anker im Viewport (x)")
	ctx.assert_almost(renderer.position.y, 100.0, 1.0e-6, "Root-Fokus zentriert den Root-Anker im Viewport (y)")
	_teardown_controller_setup(setup)
