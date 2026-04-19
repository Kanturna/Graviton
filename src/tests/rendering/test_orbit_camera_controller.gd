extends RefCounted


const OrbitCameraControllerScript = preload("res://src/tools/rendering/orbit_camera_controller.gd")
const OrbitCameraFramingScript = preload("res://src/tools/rendering/orbit_camera_framing.gd")


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
	_test_force_fit_resets_pan_and_zoom(ctx)
	_test_wide_zoom_keeps_root_centered(ctx)
	_test_fit_plateau_composition_respects_safe_rect(ctx)
	_test_zoom_multiplier_clamps_to_bounds(ctx)
	_test_closeup_zoom_reports_ratio_from_zoom_factor(ctx)
	_test_focus_switch_preserves_zoom_factor_and_mode(ctx)
	_test_explicit_root_focus_uses_root_scope(ctx)
	_test_wide_zoom_falls_back_to_focus_when_root_is_non_finite(ctx)
	_test_detail_assist_clamped_to_85_percent_of_focus_vector(ctx)
	_test_detail_safe_rect_shrinks_with_zoom(ctx)
	_test_fit_wide_transition_is_visually_continuous(ctx)
	_test_manual_pan_bypasses_smoothing(ctx)


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


static func _test_force_fit_resets_pan_and_zoom(ctx) -> void:
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
	ctx.assert_true(
		controller.get_zoom_mode() == OrbitCameraFramingScript.ZOOM_MODE_FIT,
		"force_fit landet im fit-Plateau"
	)
	ctx.assert_almost(renderer.position.x, 200.0, 1.0e-6, "Root-Basisanker liegt im Viewport-Zentrum (x)")
	ctx.assert_almost(renderer.position.y, 100.0, 1.0e-6, "Root-Basisanker liegt im Viewport-Zentrum (y)")
	_teardown_controller_setup(setup)


static func _test_wide_zoom_keeps_root_centered(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(0.005)
	controller.step(0.0, Vector2(400.0, 200.0))
	var root_screen: Vector2 = renderer.positions[&"root"] * renderer.scale.x + renderer.position
	var planet_screen: Vector2 = renderer.positions[&"planet"] * renderer.scale.x + renderer.position
	ctx.assert_almost(controller.get_zoom_factor(), 0.005, 1.0e-9, "Wide-Zoom clamp't auf MIN_ZOOM_FACTOR")
	ctx.assert_true(
		controller.get_zoom_mode() == OrbitCameraFramingScript.ZOOM_MODE_WIDE,
		"Extremes wide setzt zoom_mode auf wide"
	)
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_ROOT_ANCHOR,
		"Wide-Mode meldet root-anchor als frame_label"
	)
	ctx.assert_almost(root_screen.x, 200.0, 1.0e-6, "Root-Anker liegt im Viewport-Zentrum (x)")
	ctx.assert_almost(root_screen.y, 100.0, 1.0e-6, "Root-Anker liegt im Viewport-Zentrum (y)")
	ctx.assert_true(
		not planet_screen.is_equal_approx(Vector2(200.0, 100.0)),
		"Nested Fokus wird in wide nicht kuenstlich im Zentrum gehalten"
	)
	_teardown_controller_setup(setup)


static func _test_fit_plateau_composition_respects_safe_rect(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.step(0.0, Vector2(400.0, 200.0))
	var viewport_center: Vector2 = Vector2(200.0, 100.0)
	var focus_frame: Dictionary = renderer.frames[&"planet"]
	var focus_scope_screen_radius: float = float(focus_frame.get("radius", 1.0)) * renderer.scale.x
	var focus_screen: Vector2 = renderer.positions[&"planet"] * renderer.scale.x + renderer.position
	var focus_offset: Vector2 = focus_screen - viewport_center
	var half_w: float = OrbitCameraFramingScript.FIT_SAFE_HALF_WIDTH * 400.0
	var half_h: float = OrbitCameraFramingScript.FIT_SAFE_HALF_HEIGHT * 200.0
	ctx.assert_true(
		abs(focus_offset.x) + focus_scope_screen_radius <= half_w + 1.0e-4,
		"Focus-Scope liegt horizontal in der fit-Safe-Rect"
	)
	ctx.assert_true(
		abs(focus_offset.y) + focus_scope_screen_radius <= half_h + 1.0e-4,
		"Focus-Scope liegt vertikal in der fit-Safe-Rect"
	)
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_SMART_FIT,
		"Fit-Plateau meldet smart-fit als frame_label"
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


static func _test_closeup_zoom_reports_ratio_from_zoom_factor(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(2.0)
	controller.step(0.0, Vector2(400.0, 200.0))
	ctx.assert_true(
		controller.get_zoom_mode() == OrbitCameraFramingScript.ZOOM_MODE_DETAIL,
		"Zoom ueber FIT_PLATEAU_HIGH wechselt in den detail-Mode"
	)
	ctx.assert_almost(
		renderer.last_focus_closeup_ratio,
		2.0,
		1.0e-9,
		"Renderer erhaelt das Closeup-Ratio aus dem Zoom-Factor"
	)
	var viewport_center: Vector2 = Vector2(200.0, 100.0)
	var focus_screen: Vector2 = renderer.positions[&"planet"] * renderer.scale.x + renderer.position
	var focus_offset: Vector2 = focus_screen - viewport_center
	var half_w: float = OrbitCameraFramingScript.DETAIL_SAFE_HALF_WIDTH_FIT * 400.0
	var half_h: float = OrbitCameraFramingScript.DETAIL_SAFE_HALF_HEIGHT_FIT * 200.0
	ctx.assert_true(
		abs(focus_offset.x) <= half_w + 1.0e-4,
		"Detail-Fokus liegt in der detail-Safe-Rect (x)"
	)
	ctx.assert_true(
		abs(focus_offset.y) <= half_h + 1.0e-4,
		"Detail-Fokus liegt in der detail-Safe-Rect (y)"
	)
	_teardown_controller_setup(setup)


static func _test_focus_switch_preserves_zoom_factor_and_mode(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(2.0)
	controller.handle_pan_input(Vector2.RIGHT, 1.0)
	controller.set_focus(&"root")
	controller.step(0.0, Vector2(400.0, 200.0))
	ctx.assert_almost(
		controller.get_zoom_factor(),
		2.0,
		1.0e-9,
		"Fokuswechsel ohne force_fit behaelt den Zoom-Factor"
	)
	ctx.assert_true(
		controller.get_zoom_mode() == OrbitCameraFramingScript.ZOOM_MODE_DETAIL,
		"Fokuswechsel ohne force_fit behaelt den zoom_mode"
	)
	ctx.assert_almost(
		renderer.scale.x,
		0.76 * 2.0,
		1.0e-6,
		"Neuer Fokus nutzt seinen eigenen Scope mit erhaltenem Zoom-Factor"
	)
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
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_FOCUS_ANCHOR,
		"Root-Fokus meldet focus-anchor als frame_label (kein separater Root verfuegbar)"
	)
	_teardown_controller_setup(setup)


static func _test_wide_zoom_falls_back_to_focus_when_root_is_non_finite(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	renderer.positions[&"root"] = Vector2(INF, INF)
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(0.005)
	controller.step(0.0, Vector2(400.0, 200.0))
	var planet_screen: Vector2 = renderer.positions[&"planet"] * renderer.scale.x + renderer.position
	ctx.assert_almost(planet_screen.x, 200.0, 1.0e-6, "Nicht-finites root_center faellt auf Fokusanker zurueck (x)")
	ctx.assert_almost(planet_screen.y, 100.0, 1.0e-6, "Nicht-finites root_center faellt auf Fokusanker zurueck (y)")
	_teardown_controller_setup(setup)


static func _test_detail_assist_clamped_to_85_percent_of_focus_vector(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	renderer.positions[&"planet"] = Vector2(200.0, 0.0)
	renderer.frames[&"planet"] = {"center": Vector2(200.0, 0.0), "radius": 25.0}
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(50.0)
	controller.step(0.0, Vector2(400.0, 200.0))
	var viewport_center: Vector2 = Vector2(200.0, 100.0)
	var root_screen: Vector2 = renderer.positions[&"root"] * renderer.scale.x + renderer.position
	var focus_screen_without_offset: Vector2 = renderer.positions[&"planet"] * renderer.scale.x - renderer.positions[&"root"] * renderer.scale.x
	var actual_offset_screen: Vector2 = (root_screen - viewport_center)
	var focus_screen_length: float = focus_screen_without_offset.length()
	ctx.assert_true(
		actual_offset_screen.length() <= focus_screen_length * OrbitCameraFramingScript.DETAIL_ASSIST_CLAMP_FRACTION + 1.0e-3,
		"Auto-Assist ueberschreitet nie %.0f%% des Root->Focus-Bildschirmvektors"
			% [OrbitCameraFramingScript.DETAIL_ASSIST_CLAMP_FRACTION * 100.0]
	)
	_teardown_controller_setup(setup)


static func _test_detail_safe_rect_shrinks_with_zoom(ctx) -> void:
	ctx.assert_true(
		OrbitCameraFramingScript.DETAIL_SAFE_HALF_WIDTH_FIT > OrbitCameraFramingScript.DETAIL_SAFE_HALF_WIDTH_MAX,
		"Detail-Safe-Rect-Halbbreite schrumpft mit steigendem Zoom"
	)
	ctx.assert_true(
		OrbitCameraFramingScript.DETAIL_SAFE_HALF_HEIGHT_FIT > OrbitCameraFramingScript.DETAIL_SAFE_HALF_HEIGHT_MAX,
		"Detail-Safe-Rect-Halbhoehe schrumpft mit steigendem Zoom"
	)
	ctx.assert_true(
		OrbitCameraFramingScript.DETAIL_SAFE_HALF_WIDTH_FIT < OrbitCameraFramingScript.FIT_SAFE_HALF_WIDTH,
		"Detail-Start-Safe-Rect ist enger als fit-Safe-Rect"
	)

	var layout_at_detail_start: Dictionary = OrbitCameraFramingScript.compute_layout(
		Vector2(100.0, 0.0),
		Vector2.ZERO,
		10.0,
		OrbitCameraFramingScript.FIT_PLATEAU_HIGH + 0.01,
		Vector2(400.0, 200.0)
	)
	var layout_at_max_zoom: Dictionary = OrbitCameraFramingScript.compute_layout(
		Vector2(100.0, 0.0),
		Vector2.ZERO,
		10.0,
		100.0,
		Vector2(400.0, 200.0)
	)
	var auto_offset_start: Vector2 = layout_at_detail_start.get("auto_composition_offset_ru", Vector2.ZERO)
	var auto_offset_max: Vector2 = layout_at_max_zoom.get("auto_composition_offset_ru", Vector2.ZERO)
	ctx.assert_true(
		absf(auto_offset_max.x) >= absf(auto_offset_start.x) - 1.0e-6,
		"Staerkeres Zoomen aktiviert staerkeren Detail-Assist (sofern nicht durch den 85%%-Clamp begrenzt)"
	)


static func _test_fit_wide_transition_is_visually_continuous(ctx) -> void:
	var setup_below := _make_controller()
	var controller_below = setup_below["controller"]
	var renderer_below: RendererStub = setup_below["renderer"]
	controller_below.set_focus(&"planet", false, true)
	controller_below.handle_zoom_multiplier(0.915 / 1.0)
	controller_below.step(0.0, Vector2(400.0, 200.0))
	var focus_below: Vector2 = renderer_below.positions[&"planet"] * renderer_below.scale.x + renderer_below.position
	var scale_below: float = renderer_below.scale.x

	var setup_above := _make_controller()
	var controller_above = setup_above["controller"]
	var renderer_above: RendererStub = setup_above["renderer"]
	controller_above.set_focus(&"planet", false, true)
	controller_above.handle_zoom_multiplier(0.925 / 1.0)
	controller_above.step(0.0, Vector2(400.0, 200.0))
	var focus_above: Vector2 = renderer_above.positions[&"planet"] * renderer_above.scale.x + renderer_above.position
	var scale_above: float = renderer_above.scale.x

	ctx.assert_true(
		focus_below.distance_to(focus_above) < 1.5,
		"Plateau-Grenze wide->fit erzeugt keinen sichtbaren Sprung in der Fokus-Position"
	)
	ctx.assert_true(
		abs(scale_above - scale_below) < 0.02,
		"Plateau-Grenze wide->fit erzeugt keinen sichtbaren Sprung in der View-Skala"
	)
	_teardown_controller_setup(setup_below)
	_teardown_controller_setup(setup_above)


static func _test_manual_pan_bypasses_smoothing(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.step(0.0, Vector2(400.0, 200.0))
	var position_before: Vector2 = renderer.position
	controller.handle_pan_input(Vector2.RIGHT, 0.25)
	controller.step(0.001, Vector2(400.0, 200.0))
	var position_after: Vector2 = renderer.position
	ctx.assert_true(
		position_after.x < position_before.x - 1.0,
		"Manueller Pan wirkt sofort auf den Welt-Offset, ohne Smoothing-Verzoegerung"
	)
	_teardown_controller_setup(setup)
