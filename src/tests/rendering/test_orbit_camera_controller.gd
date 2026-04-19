extends RefCounted


const OrbitCameraControllerScript = preload("res://src/tools/rendering/orbit_camera_controller.gd")
const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")


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
	_test_wide_zoom_blends_toward_root_for_nested_focus(ctx)
	_test_zoom_multiplier_clamps_to_bounds(ctx)
	_test_closeup_zoom_updates_focus_ratio(ctx)
	_test_focus_change_resets_to_new_scope_fit(ctx)
	_test_explicit_root_focus_uses_root_scope(ctx)
	_test_wide_zoom_falls_back_to_focus_when_root_is_non_finite(ctx)
	_test_moving_root_stays_centered_at_full_wide_without_offset_lag(ctx)
	_test_focus_change_reanchors_immediately_while_scale_continues_to_ramp(ctx)
	_test_partial_wide_positions_follow_current_blend_without_offset_lag(ctx)


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


static func _screen_pos(renderer: RendererStub, body_id: StringName) -> Vector2:
	return renderer.positions[body_id] * renderer.scale.x + renderer.position


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


static func _test_wide_zoom_blends_toward_root_for_nested_focus(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(0.005)
	controller.step(0.0, Vector2(400.0, 200.0))
	var root_screen_pos: Vector2 = _screen_pos(renderer, &"root")
	var planet_screen_pos: Vector2 = _screen_pos(renderer, &"planet")
	ctx.assert_almost(controller.get_zoom_factor(), 0.005, 1.0e-9, "Wide-Zoom clamp't auf MIN_ZOOM_FACTOR")
	ctx.assert_almost(root_screen_pos.x, 200.0, 1.0e-6, "Extremes wide zentriert den Root-Anker wieder (x)")
	ctx.assert_almost(root_screen_pos.y, 100.0, 1.0e-6, "Extremes wide zentriert den Root-Anker wieder (y)")
	ctx.assert_true(
		not is_equal_approx(planet_screen_pos.x, 200.0) or not is_equal_approx(planet_screen_pos.y, 100.0),
		"Extremes wide haelt den nested Fokus nicht mehr kuenstlich im Zentrum"
	)

	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(0.95)
	controller.step(0.0, Vector2(400.0, 200.0))
	planet_screen_pos = _screen_pos(renderer, &"planet")
	root_screen_pos = _screen_pos(renderer, &"root")
	ctx.assert_true(
		root_screen_pos.x < 200.0 and planet_screen_pos.x > 200.0,
		"Leichtes wide zieht den Blickanker nur teilweise Richtung Root, ohne den Fokus hart zu versetzen"
	)
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
	var planet_screen_pos: Vector2 = _screen_pos(renderer, &"planet")
	ctx.assert_true(controller.get_current_view_scale() > 3.04, "Closeup-Zoom vergroessert die aktuelle View-Skala ueber FIT")
	ctx.assert_true(renderer.last_focus_closeup_ratio > 1.0, "Renderer erhaelt fuer Closeups ein Ratio > 1.0")
	ctx.assert_almost(planet_screen_pos.x, 200.0, 1.0e-6, "Detail-Zoom behaelt den Fokuskoerper im Zentrum (x)")
	ctx.assert_almost(planet_screen_pos.y, 100.0, 1.0e-6, "Detail-Zoom behaelt den Fokuskoerper im Zentrum (y)")
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


static func _test_wide_zoom_falls_back_to_focus_when_root_is_non_finite(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	renderer.positions[&"root"] = Vector2(INF, INF)
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(0.005)
	controller.step(0.0, Vector2(400.0, 200.0))
	var planet_screen_pos: Vector2 = _screen_pos(renderer, &"planet")
	ctx.assert_almost(planet_screen_pos.x, 200.0, 1.0e-6, "Nicht-finites root_center faellt auf Fokusanker zurueck (x)")
	ctx.assert_almost(planet_screen_pos.y, 100.0, 1.0e-6, "Nicht-finites root_center faellt auf Fokusanker zurueck (y)")
	_teardown_controller_setup(setup)


static func _test_moving_root_stays_centered_at_full_wide_without_offset_lag(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(0.005)
	controller.step(0.0, Vector2(400.0, 200.0))
	renderer.positions[&"root"] = Vector2(40.0, -20.0)
	renderer.positions[&"planet"] = Vector2(140.0, 30.0)
	controller.step(0.016, Vector2(400.0, 200.0))
	var root_screen_pos: Vector2 = _screen_pos(renderer, &"root")
	ctx.assert_almost(root_screen_pos.x, 200.0, 1.0e-6, "Volles wide haelt bewegten Root ohne Offset-Lag zentriert (x)")
	ctx.assert_almost(root_screen_pos.y, 100.0, 1.0e-6, "Volles wide haelt bewegten Root ohne Offset-Lag zentriert (y)")
	_teardown_controller_setup(setup)


static func _test_focus_change_reanchors_immediately_while_scale_continues_to_ramp(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(2.0)
	controller.step(0.0, Vector2(400.0, 200.0))
	var previous_scale: float = controller.get_current_view_scale()
	controller.set_focus(&"root")
	controller.step(0.016, Vector2(400.0, 200.0))
	var root_screen_pos: Vector2 = _screen_pos(renderer, &"root")
	ctx.assert_almost(root_screen_pos.x, 200.0, 1.0e-6, "Fokuswechsel verankert den neuen Root sofort (x)")
	ctx.assert_almost(root_screen_pos.y, 100.0, 1.0e-6, "Fokuswechsel verankert den neuen Root sofort (y)")
	ctx.assert_true(
		controller.get_current_view_scale() < previous_scale and controller.get_current_view_scale() > 0.76,
		"Fokuswechsel laesst die Scale weiter weich Richtung neuen Scope-Fit rampen"
	)
	_teardown_controller_setup(setup)


static func _test_partial_wide_positions_follow_current_blend_without_offset_lag(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(0.95)
	controller.step(0.0, Vector2(400.0, 200.0))
	renderer.positions[&"root"] = Vector2(20.0, 10.0)
	renderer.positions[&"planet"] = Vector2(120.0, 60.0)
	controller.step(0.016, Vector2(400.0, 200.0))
	var blend: float = OrbitZoomModelScript.wide_anchor_blend(controller.get_zoom_factor())
	var anchor_center: Vector2 = renderer.positions[&"planet"].lerp(renderer.positions[&"root"], blend)
	var viewport_center: Vector2 = Vector2(200.0, 100.0)
	var current_scale: float = controller.get_current_view_scale()
	var expected_root: Vector2 = viewport_center + (renderer.positions[&"root"] - anchor_center) * current_scale
	var expected_planet: Vector2 = viewport_center + (renderer.positions[&"planet"] - anchor_center) * current_scale
	var root_screen_pos: Vector2 = _screen_pos(renderer, &"root")
	var planet_screen_pos: Vector2 = _screen_pos(renderer, &"planet")
	ctx.assert_almost(root_screen_pos.x, expected_root.x, 1.0e-5, "Leichtes wide folgt sofort der aktuellen Root-Blend-Formel (root x)")
	ctx.assert_almost(root_screen_pos.y, expected_root.y, 1.0e-5, "Leichtes wide folgt sofort der aktuellen Root-Blend-Formel (root y)")
	ctx.assert_almost(planet_screen_pos.x, expected_planet.x, 1.0e-5, "Leichtes wide hat keinen zusaetzlichen Offset-Nachlauf fuer den Fokus (x)")
	ctx.assert_almost(planet_screen_pos.y, expected_planet.y, 1.0e-5, "Leichtes wide hat keinen zusaetzlichen Offset-Nachlauf fuer den Fokus (y)")
	_teardown_controller_setup(setup)
