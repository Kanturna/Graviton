extends RefCounted


const OrbitCameraControllerScript = preload("res://src/tools/rendering/orbit_camera_controller.gd")
const OrbitCameraFramingScript = preload("res://src/tools/rendering/orbit_camera_framing.gd")
const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")

const DEFAULT_PLANET_WORLD_POS: Vector2 = Vector2(100.0, 50.0)
const CLOSE_PLANET_WORLD_POS: Vector2 = Vector2(10.0, 5.0)
const PLANET_SCOPE_RADIUS_RU: float = 25.0


class BubbleStub:
	extends RefCounted

	var _focus: StringName = &""

	func set_focus(body_id: StringName) -> void:
		_focus = body_id

	func get_focus() -> StringName:
		return _focus


class RendererStub:
	extends RefCounted

	var world_positions: Dictionary = {}
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
		var raw: Vector2 = world_positions.get(body_id, Vector2(INF, INF))
		if not (is_finite(raw.x) and is_finite(raw.y)):
			return raw
		if focused_id == StringName("") or not world_positions.has(focused_id):
			return raw
		var focus_raw: Vector2 = world_positions[focused_id]
		if not (is_finite(focus_raw.x) and is_finite(focus_raw.y)):
			return raw
		return raw - focus_raw

	func get_scope_frame(body_id: StringName) -> Dictionary:
		return frames.get(body_id, {"center": Vector2.ZERO, "radius": 1.0})

	func set_world_scale(value: float) -> void:
		last_world_scale = value

	func set_focus_closeup_ratio(value: float) -> void:
		last_focus_closeup_ratio = value

	func screen_pos_of(body_id: StringName) -> Vector2:
		return get_body_view_position_ru(body_id) * scale.x + position


class TopologyStub:
	extends RefCounted

	var roots: Dictionary = {}

	func root_id_of(body_id: StringName) -> StringName:
		return roots.get(body_id, StringName(""))


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_camera_controller"
	_test_force_fit_centers_focus_and_resets_pan(ctx)
	_test_visible_root_locks_even_in_fit_mode(ctx)
	_test_zoom_multiplier_clamps_to_bounds(ctx)
	_test_detail_zoom_keeps_focus_centered_when_root_is_not_visible(ctx)
	_test_detail_zoom_closeup_ratio_follows_smoothed_view_scale(ctx)
	_test_focus_change_resets_target_closeup_before_next_render_sync(ctx)
	_test_focus_change_resets_zoom_to_fit(ctx)
	_test_explicit_root_focus_uses_root_overview_label(ctx)
	_test_non_finite_root_falls_back_to_focus_lock(ctx)
	_test_visibility_transition_is_continuous(ctx)
	_test_lock_label_uses_hysteresis(ctx)
	_test_manual_pan_is_additive_and_keeps_lock_state(ctx)
	_test_view_state_restore_preserves_focus_zoom_and_pan(ctx)
	_test_focus_follow_tracks_world_motion_without_drift(ctx)
	_test_root_lock_tracks_world_motion_without_drift(ctx)


static func _make_controller(planet_world_pos: Vector2 = DEFAULT_PLANET_WORLD_POS) -> Dictionary:
	var controller = OrbitCameraControllerScript.new()
	var renderer := RendererStub.new()
	var bubble := BubbleStub.new()
	var topology := TopologyStub.new()
	var registry := Node.new()
	renderer.world_positions = {
		&"root": Vector2.ZERO,
		&"planet": planet_world_pos,
	}
	renderer.frames = {
		&"root": {"center": Vector2.ZERO, "radius": 100.0},
		&"planet": {"center": planet_world_pos, "radius": PLANET_SCOPE_RADIUS_RU},
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


static func _set_zoom_factor(controller, target_zoom_factor: float) -> void:
	var current_zoom_factor: float = maxf(float(controller.get_zoom_factor()), 0.000001)
	controller.handle_zoom_multiplier(target_zoom_factor / current_zoom_factor)


static func _zoom_factor_for_phase(viewport_size: Vector2, planet_world_pos: Vector2, phase: float) -> float:
	var min_viewport_dim: float = minf(viewport_size.x, viewport_size.y)
	var target_root_distance_screen_px: float = _root_distance_screen_px_for_phase(phase, min_viewport_dim)
	var scope_fit_scale: float = (min_viewport_dim * OrbitCameraFramingScript.VIEWPORT_RADIUS_FACTOR) / PLANET_SCOPE_RADIUS_RU
	return target_root_distance_screen_px / maxf(planet_world_pos.length() * scope_fit_scale, 0.0001)


static func _root_distance_screen_px_for_phase(phase: float, min_viewport_dim: float) -> float:
	var low: float = min_viewport_dim * OrbitCameraFramingScript.ROOT_LOCK_IN_VIEWPORT_FRACTION
	var high: float = min_viewport_dim * OrbitCameraFramingScript.ROOT_LOCK_OUT_VIEWPORT_FRACTION
	for _i in range(40):
		var mid: float = (low + high) * 0.5
		var mid_phase: float = OrbitCameraFramingScript.root_lock_phase_for_distance(mid, min_viewport_dim)
		if mid_phase > phase:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


static func _test_force_fit_centers_focus_and_resets_pan(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	var bubble: BubbleStub = setup["bubble"]
	controller.handle_pan_input(Vector2.RIGHT, 1.0)
	controller.set_focus(&"planet", false, true)
	controller.step(0.0, Vector2(400.0, 200.0))
	ctx.assert_true(bubble.get_focus() == &"planet", "set_focus schreibt den Bubble-Fokus")
	ctx.assert_true(renderer.focused_id == &"planet", "set_focus schreibt den Renderer-Fokus")
	ctx.assert_true(renderer.cleared_trails == 0, "Fokuswechsel behaelt Trails bei, da sie jetzt parent-lokal stabil sind")
	ctx.assert_almost(controller.get_zoom_factor(), 1.0, 1.0e-9, "force_fit setzt Zoom auf FIT")
	ctx.assert_almost(renderer.scale.x, 3.04, 1.0e-6, "FIT-Skala basiert auf dem Fokus-Scope")
	var planet_screen: Vector2 = renderer.screen_pos_of(&"planet")
	ctx.assert_almost(planet_screen.x, 200.0, 1.0e-6, "Snap-Step zentriert den Fokus im Viewport (x)")
	ctx.assert_almost(planet_screen.y, 100.0, 1.0e-6, "Snap-Step zentriert den Fokus im Viewport (y)")
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK,
		"Fit-Modus ohne sichtbaren Root meldet focus-lock"
	)
	_teardown_controller_setup(setup)


static func _test_visible_root_locks_even_in_fit_mode(ctx) -> void:
	var setup := _make_controller(CLOSE_PLANET_WORLD_POS)
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.step(0.0, Vector2(400.0, 200.0))
	var root_screen: Vector2 = renderer.screen_pos_of(&"root")
	var planet_screen: Vector2 = renderer.screen_pos_of(&"planet")
	ctx.assert_true(
		controller.get_zoom_mode() == OrbitCameraFramingScript.ZOOM_MODE_FIT,
		"Zoom-Modus bleibt fit; Root-Lock ist nicht mehr wide-exklusiv"
	)
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_ROOT_LOCK,
		"Sichtbarer Root verankert die Kamera auch im fit-Modus am Root"
	)
	ctx.assert_almost(root_screen.x, 200.0, 1.0e-6, "Sichtbarer Root bleibt im Viewport zentriert (x)")
	ctx.assert_almost(root_screen.y, 100.0, 1.0e-6, "Sichtbarer Root bleibt im Viewport zentriert (y)")
	ctx.assert_true(
		planet_screen.distance_to(Vector2(200.0, 100.0)) > 1.0,
		"Der Fokuskoerper bleibt relativ zum Root sichtbar beweglich"
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


static func _test_detail_zoom_keeps_focus_centered_when_root_is_not_visible(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(2.0)
	controller.step(0.0, Vector2(400.0, 200.0))
	var planet_screen: Vector2 = renderer.screen_pos_of(&"planet")
	ctx.assert_true(
		controller.get_zoom_mode() == OrbitCameraFramingScript.ZOOM_MODE_DETAIL,
		"Zoomwerte ueber FIT_PLATEAU_HIGH setzen zoom_mode auf detail"
	)
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK,
		"Unsichtbarer Root faellt im Detailbereich auf focus-lock zurueck"
	)
	ctx.assert_true(
		controller.get_current_view_scale() > 3.04,
		"Detail-Zoom vergroessert die aktuelle View-Skala ueber FIT"
	)
	ctx.assert_almost(
		renderer.last_focus_closeup_ratio,
		2.0,
		1.0e-9,
		"Renderer erhaelt das Closeup-Ratio direkt aus dem Zoom-Factor"
	)
	ctx.assert_almost(planet_screen.x, 200.0, 1.0e-6, "Detail-Zoom behaelt den Fokuskoerper im Zentrum (x)")
	ctx.assert_almost(planet_screen.y, 100.0, 1.0e-6, "Detail-Zoom behaelt den Fokuskoerper im Zentrum (y)")
	_teardown_controller_setup(setup)


static func _test_detail_zoom_closeup_ratio_follows_smoothed_view_scale(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	var viewport: Vector2 = Vector2(400.0, 200.0)
	controller.set_focus(&"planet", false, true)
	controller.step(0.0, viewport)
	controller.handle_zoom_multiplier(4.0)
	controller.step(0.05, viewport)
	var focus_fit_scale: float = (minf(viewport.x, viewport.y) * OrbitCameraFramingScript.VIEWPORT_RADIUS_FACTOR) / PLANET_SCOPE_RADIUS_RU
	var expected_ratio: float = OrbitZoomModelScript.focus_closeup_ratio(
		controller.get_current_view_scale(),
		focus_fit_scale
	)
	ctx.assert_almost(
		renderer.last_focus_closeup_ratio,
		expected_ratio,
		1.0e-6,
		"Closeup-Ratio folgt jetzt dem geglaetteten aktuellen View-Scale statt sofort hart auf den Zielzoom zu springen"
	)
	ctx.assert_true(
		renderer.last_focus_closeup_ratio > 1.0 and renderer.last_focus_closeup_ratio < 4.0,
		"Bei laufender Zoom-Interpolation liegt das Closeup-Ratio sichtbar zwischen Fit und Zielzoom"
	)
	_teardown_controller_setup(setup)


static func _test_focus_change_resets_target_closeup_before_next_render_sync(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	var viewport: Vector2 = Vector2(400.0, 200.0)
	controller.set_focus(&"planet", false, true)
	controller.step(0.0, viewport)
	controller.handle_zoom_multiplier(6.0)
	controller.step(0.0, viewport)
	ctx.assert_true(
		renderer.last_focus_closeup_ratio > 5.9,
		"Vor dem Fokuswechsel liegt ein starker Detail-Closeup-Wert an"
	)

	controller.set_focus(&"root")
	ctx.assert_true(renderer.focused_id == &"root", "Fokuswechsel setzt den Renderer-Fokus sofort")
	ctx.assert_almost(
		renderer.last_focus_closeup_ratio,
		1.0,
		1.0e-9,
		"Fokuswechsel setzt das Ziel-Closeup vor dem naechsten Render-Sync und verhindert einen alten Detail-Frame"
	)
	_teardown_controller_setup(setup)


static func _test_focus_change_resets_zoom_to_fit(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(2.0)
	controller.handle_pan_input(Vector2.RIGHT, 1.0)
	controller.set_focus(&"root")
	controller.step(0.0, Vector2(400.0, 200.0))
	var root_screen: Vector2 = renderer.screen_pos_of(&"root")
	ctx.assert_almost(
		controller.get_zoom_factor(),
		1.0,
		1.0e-9,
		"Fokuswechsel resetet den Zoom-Factor auf FIT"
	)
	ctx.assert_almost(renderer.scale.x, 0.76, 1.0e-6, "Neuer Fokus nutzt seinen eigenen Scope-Fit")
	ctx.assert_almost(root_screen.x, 200.0, 1.0e-6, "Neuer Fokus landet zentriert im Viewport (x)")
	ctx.assert_almost(root_screen.y, 100.0, 1.0e-6, "Neuer Fokus landet zentriert im Viewport (y)")
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW,
		"Root-Fokus nutzt den expliziten root-overview-Label"
	)
	_teardown_controller_setup(setup)


static func _test_explicit_root_focus_uses_root_overview_label(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"root", false, true)
	controller.step(0.0, Vector2(400.0, 200.0))
	var root_screen: Vector2 = renderer.screen_pos_of(&"root")
	ctx.assert_almost(renderer.scale.x, 0.76, 1.0e-6, "Root-Fokus nutzt den Root-Scope als expliziten Overview")
	ctx.assert_almost(root_screen.x, 200.0, 1.0e-6, "Root-Fokus zentriert den Root-Anker im Viewport (x)")
	ctx.assert_almost(root_screen.y, 100.0, 1.0e-6, "Root-Fokus zentriert den Root-Anker im Viewport (y)")
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW,
		"Expliziter Root-Fokus meldet root-overview"
	)
	_teardown_controller_setup(setup)


static func _test_non_finite_root_falls_back_to_focus_lock(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	renderer.world_positions[&"root"] = Vector2(INF, INF)
	controller.set_focus(&"planet", false, true)
	_set_zoom_factor(controller, 0.10)
	controller.step(0.0, Vector2(400.0, 200.0))
	var planet_screen: Vector2 = renderer.screen_pos_of(&"planet")
	ctx.assert_almost(planet_screen.x, 200.0, 1.0e-6, "Nicht-finites root_center faellt auf focus-lock zurueck (x)")
	ctx.assert_almost(planet_screen.y, 100.0, 1.0e-6, "Nicht-finites root_center faellt auf focus-lock zurueck (y)")
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK,
		"Ohne valid root meldet der Controller focus-lock"
	)
	_teardown_controller_setup(setup)


static func _test_visibility_transition_is_continuous(ctx) -> void:
	var viewport: Vector2 = Vector2(100.0, 100.0)

	var setup_root_side := _make_controller()
	var controller_root_side = setup_root_side["controller"]
	var renderer_root_side: RendererStub = setup_root_side["renderer"]
	controller_root_side.set_focus(&"planet", false, true)
	_set_zoom_factor(controller_root_side, _zoom_factor_for_phase(viewport, DEFAULT_PLANET_WORLD_POS, 0.51))
	controller_root_side.step(0.0, viewport)
	var root_side_focus: Vector2 = renderer_root_side.screen_pos_of(&"planet")
	var root_side_root: Vector2 = renderer_root_side.screen_pos_of(&"root")

	var setup_focus_side := _make_controller()
	var controller_focus_side = setup_focus_side["controller"]
	var renderer_focus_side: RendererStub = setup_focus_side["renderer"]
	controller_focus_side.set_focus(&"planet", false, true)
	_set_zoom_factor(controller_focus_side, _zoom_factor_for_phase(viewport, DEFAULT_PLANET_WORLD_POS, 0.49))
	controller_focus_side.step(0.0, viewport)
	var focus_side_focus: Vector2 = renderer_focus_side.screen_pos_of(&"planet")
	var focus_side_root: Vector2 = renderer_focus_side.screen_pos_of(&"root")

	ctx.assert_true(
		root_side_focus.distance_to(focus_side_focus) < 1.0,
		"Nahe der 0.5-Phase bleibt die Fokus-Position stetig"
	)
	ctx.assert_true(
		root_side_root.distance_to(focus_side_root) < 1.0,
		"Nahe der 0.5-Phase bleibt die Root-Position stetig"
	)
	_teardown_controller_setup(setup_root_side)
	_teardown_controller_setup(setup_focus_side)


static func _test_lock_label_uses_hysteresis(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var viewport: Vector2 = Vector2(400.0, 200.0)
	controller.set_focus(&"planet", false, true)

	_set_zoom_factor(controller, _zoom_factor_for_phase(viewport, DEFAULT_PLANET_WORLD_POS, 0.62))
	controller.step(0.0, viewport)
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_ROOT_LOCK,
		"Phase ueber 0.60 setzt root-lock"
	)

	_set_zoom_factor(controller, _zoom_factor_for_phase(viewport, DEFAULT_PLANET_WORLD_POS, 0.50))
	controller.step(0.0, viewport)
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_ROOT_LOCK,
		"Zwischen 0.40 und 0.60 haelt das Label den letzten root-lock-Zustand"
	)

	_set_zoom_factor(controller, _zoom_factor_for_phase(viewport, DEFAULT_PLANET_WORLD_POS, 0.38))
	controller.step(0.0, viewport)
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK,
		"Phase unter 0.40 setzt focus-lock"
	)

	_set_zoom_factor(controller, _zoom_factor_for_phase(viewport, DEFAULT_PLANET_WORLD_POS, 0.50))
	controller.step(0.0, viewport)
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK,
		"Zwischen 0.40 und 0.60 haelt das Label auch den letzten focus-lock-Zustand"
	)
	_teardown_controller_setup(setup)


static func _test_manual_pan_is_additive_and_keeps_lock_state(ctx) -> void:
	var setup := _make_controller(CLOSE_PLANET_WORLD_POS)
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.step(0.0, Vector2(400.0, 200.0))
	var position_before: Vector2 = renderer.position
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_ROOT_LOCK,
		"Der Ausgangszustand ist root-lock"
	)
	controller.handle_pan_input(Vector2.RIGHT, 0.25)
	controller.step(0.001, Vector2(400.0, 200.0))
	var position_after: Vector2 = renderer.position
	ctx.assert_true(
		position_after.x < position_before.x - 1.0,
		"Manueller Pan wirkt weiter sofort als additiver View-Offset"
	)
	ctx.assert_true(
		controller.get_frame_label() == OrbitCameraFramingScript.FRAME_LABEL_ROOT_LOCK,
		"Manual Pan veraendert den Lock-Zustand nicht"
	)
	_teardown_controller_setup(setup)


static func _test_view_state_restore_preserves_focus_zoom_and_pan(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	var bubble: BubbleStub = setup["bubble"]
	var viewport: Vector2 = Vector2(400.0, 200.0)
	controller.set_focus(&"planet", false, true)
	controller.handle_zoom_multiplier(3.0)
	controller.handle_pan_input(Vector2.RIGHT, 0.5)
	controller.step(0.0, viewport)
	var saved_state: Dictionary = controller.capture_view_state()

	controller.set_focus(&"root", false, true)
	controller.step(0.0, viewport)
	controller.restore_view_state(saved_state, true)

	ctx.assert_true(bubble.get_focus() == &"planet", "Restore setzt den gespeicherten Fokus")
	ctx.assert_true(renderer.focused_id == &"planet", "Restore setzt auch den Renderer-Fokus")
	ctx.assert_almost(controller.get_zoom_factor(), 3.0, 1.0e-9, "Restore erhaelt den gespeicherten Zoom")
	ctx.assert_true(
		controller.get_manual_pan_ru().length() > 1.0,
		"Restore erhaelt den gespeicherten manuellen Pan"
	)
	_teardown_controller_setup(setup)


static func _test_focus_follow_tracks_world_motion_without_drift(ctx) -> void:
	var setup := _make_controller()
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.step(0.0, Vector2(400.0, 200.0))
	var planet_centered: Vector2 = renderer.screen_pos_of(&"planet")
	ctx.assert_almost(
		planet_centered.x,
		200.0,
		1.0e-6,
		"Vor Welt-Bewegung ist der Fokus zentriert"
	)

	renderer.world_positions[&"planet"] = Vector2(1000.0, 0.0)
	controller.step(0.05, Vector2(400.0, 200.0))
	var planet_after_motion: Vector2 = renderer.screen_pos_of(&"planet")
	ctx.assert_almost(planet_after_motion.x, 200.0, 1.0e-6, "Focus-Lock haelt den Fokus auch bei schneller Welt-Bewegung zentriert (x)")
	ctx.assert_almost(planet_after_motion.y, 100.0, 1.0e-6, "Focus-Lock haelt den Fokus auch bei schneller Welt-Bewegung zentriert (y)")
	_teardown_controller_setup(setup)


static func _test_root_lock_tracks_world_motion_without_drift(ctx) -> void:
	var setup := _make_controller(CLOSE_PLANET_WORLD_POS)
	var controller = setup["controller"]
	var renderer: RendererStub = setup["renderer"]
	controller.set_focus(&"planet", false, true)
	controller.step(0.0, Vector2(400.0, 200.0))
	var root_centered: Vector2 = renderer.screen_pos_of(&"root")
	var planet_before_motion: Vector2 = renderer.screen_pos_of(&"planet")
	ctx.assert_almost(root_centered.x, 200.0, 1.0e-6, "Vor Welt-Bewegung ist der Root-Anker zentriert (x)")
	ctx.assert_almost(root_centered.y, 100.0, 1.0e-6, "Vor Welt-Bewegung ist der Root-Anker zentriert (y)")

	renderer.world_positions[&"planet"] = Vector2(12.0, 5.0)
	controller.step(0.05, Vector2(400.0, 200.0))
	var root_after_motion: Vector2 = renderer.screen_pos_of(&"root")
	var planet_after_motion: Vector2 = renderer.screen_pos_of(&"planet")
	ctx.assert_almost(root_after_motion.x, 200.0, 1.0e-6, "Root-Lock behaelt den Root auch bei schneller lokaler Bewegung zentriert (x)")
	ctx.assert_almost(root_after_motion.y, 100.0, 1.0e-6, "Root-Lock behaelt den Root auch bei schneller lokaler Bewegung zentriert (y)")
	ctx.assert_true(
		planet_after_motion.distance_to(planet_before_motion) > 1.0,
		"Der Fokuskoerper bleibt im Root-Lock sichtbar in Bewegung"
	)
	_teardown_controller_setup(setup)
