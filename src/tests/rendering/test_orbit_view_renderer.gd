extends RefCounted

const OrbitViewRendererScript = preload("res://src/tools/rendering/orbit_view_renderer.gd")
const OrbitCameraFramingScript = preload("res://src/tools/rendering/orbit_camera_framing.gd")


class TimeProbe:
	extends Node

	var paused: bool = false
	var time_scale: float = 1.0
	var last_sim_dt_s: float = 4.0


class RendererProbe:
	extends OrbitViewRendererScript

	var line_width_apply_count: int = 0
	var sync_visual_positions_count: int = 0

	func _apply_line_widths() -> void:
		line_width_apply_count += 1

	func _sync_visual_positions(_reset_trails: bool = false) -> void:
		sync_visual_positions_count += 1


class RegistryProbe:
	extends Node

	var order: Array[StringName] = []
	var defs: Dictionary = {}
	var states: Dictionary = {}

	func add_body(id: StringName, kind: int, parent_id: StringName, pos_m: Vector3) -> void:
		var def := BodyDef.new()
		def.id = id
		def.display_name = String(id)
		def.kind = kind
		def.mass_kg = 1.0
		def.radius_m = 1.0
		def.parent_id = parent_id
		defs[id] = def
		var state := BodyState.new(id, parent_id)
		state.position_parent_frame_m = pos_m
		states[id] = state
		order.append(id)

	func get_update_order() -> Array[StringName]:
		return order.duplicate()

	func get_update_order_ref() -> Array[StringName]:
		return order

	func get_def(id: StringName) -> BodyDef:
		return defs.get(id, null)

	func get_state(id: StringName) -> BodyState:
		return states.get(id, null)

	func has_body(id: StringName) -> bool:
		return defs.has(id)


class BubbleProbe:
	extends Node

	func compose_view_position_m(id: StringName, _presentation_offset_s: float = 0.0) -> Vector3:
		if id == &"planet":
			return Vector3(1000.0, 0.0, 0.0)
		return Vector3.ZERO


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_view_renderer"
	_test_presentation_offset_uses_physics_interpolation_fraction(ctx)
	_test_presentation_offset_is_disabled_when_time_stops(ctx)
	_test_engine_interpolation_fraction_is_safe(ctx)
	_test_world_scale_does_not_reapply_line_widths_when_unchanged(ctx)
	_test_trail_points_update_only_when_history_changes(ctx)
	_test_trail_points_are_decimated_below_pixel_threshold(ctx)
	_test_render_sync_does_not_write_trail_points_without_sim_tick(ctx)
	_test_root_overview_sim_tick_does_not_write_trail_points(ctx)
	_test_close_zoom_state_has_hysteresis(ctx)
	_test_screen_circle_visibility_helper(ctx)
	_test_sync_visuals_now_skips_redundant_process_sync(ctx)
	_test_forced_sync_visuals_now_overrides_same_frame_guard(ctx)


static func _test_presentation_offset_uses_physics_interpolation_fraction(ctx) -> void:
	var renderer = OrbitViewRendererScript.new()
	var time_probe := TimeProbe.new()
	renderer.set_time_service(time_probe)
	renderer._physics_interpolation_fraction_override = 0.25
	ctx.assert_almost(
		renderer._presentation_offset_s(),
		-3.0,
		1.0e-9,
		"Renderer interpoliert zwischen vorherigem und aktuellem Physics-Tick"
	)
	time_probe.free()
	renderer.free()


static func _test_presentation_offset_is_disabled_when_time_stops(ctx) -> void:
	var renderer = OrbitViewRendererScript.new()
	var time_probe := TimeProbe.new()
	renderer.set_time_service(time_probe)
	renderer._physics_interpolation_fraction_override = 0.5

	time_probe.paused = true
	ctx.assert_almost(renderer._presentation_offset_s(), 0.0, 1.0e-9, "Pause deaktiviert Presentation-Offset")

	time_probe.paused = false
	time_probe.time_scale = 0.0
	ctx.assert_almost(renderer._presentation_offset_s(), 0.0, 1.0e-9, "time_scale 0 deaktiviert Presentation-Offset")

	time_probe.time_scale = 1.0
	time_probe.last_sim_dt_s = 0.0
	ctx.assert_almost(renderer._presentation_offset_s(), 0.0, 1.0e-9, "fehlender letzter Tick deaktiviert Presentation-Offset")

	time_probe.free()
	renderer.free()


static func _test_engine_interpolation_fraction_is_safe(ctx) -> void:
	var renderer = OrbitViewRendererScript.new()
	renderer._physics_interpolation_fraction_override = -1.0
	var fraction: float = renderer._physics_interpolation_fraction()
	ctx.assert_true(
		fraction >= 0.0 and fraction <= 1.0,
		"Engine-Physics-Interpolation-Fraction ist sicher abfragbar und geklemmt"
	)
	renderer.free()


static func _test_world_scale_does_not_reapply_line_widths_when_unchanged(ctx) -> void:
	var renderer := RendererProbe.new()
	renderer._world_scale = 1.0
	renderer.set_world_scale(1.0)
	ctx.assert_true(
		renderer.line_width_apply_count == 0,
		"unveraenderter World-Scale schreibt Orbit-/Trail-Line-Widths nicht erneut"
	)
	renderer.set_world_scale(2.0)
	ctx.assert_true(
		renderer.line_width_apply_count == 1,
		"veraenderter World-Scale aktualisiert Orbit-/Trail-Line-Widths weiterhin"
	)
	renderer.free()


static func _test_trail_points_update_only_when_history_changes(ctx) -> void:
	var renderer = OrbitViewRendererScript.new()
	var line := AntialiasedLine2D.new()
	renderer._trail_visuals[&"planet"] = line
	renderer._trail_histories[&"planet"] = []
	renderer._world_scale = 1.0

	renderer._update_trail(&"planet", Vector2(1.0, 2.0), false)
	ctx.assert_true(
		renderer._trail_update_body_ids.has(&"planet"),
		"Erster Trail-Punkt schreibt die Line-Punkte"
	)

	renderer._trail_update_body_ids.clear()
	renderer._update_trail(&"planet", Vector2(1.0, 2.0), false)
	ctx.assert_true(
		renderer._trail_update_body_ids.is_empty(),
		"Unveraenderte Trail-Position schreibt kein neues PackedVector2Array"
	)

	# Delta = 2.0 render units * world_scale 1.0 = 2.0 px -> oberhalb
	# MIN_TRAIL_STEP_PX und wird daher nicht dezimiert.
	renderer._update_trail(&"planet", Vector2(3.0, 2.0), false)
	ctx.assert_true(
		renderer._trail_update_body_ids.has(&"planet"),
		"Neue Trail-Position aktualisiert die Line-Punkte weiterhin"
	)

	line.free()
	renderer.free()


static func _test_trail_points_are_decimated_below_pixel_threshold(ctx) -> void:
	var renderer = OrbitViewRendererScript.new()
	var line := AntialiasedLine2D.new()
	renderer._trail_visuals[&"planet"] = line
	renderer._trail_histories[&"planet"] = []
	renderer._world_scale = 0.1

	renderer._update_trail(&"planet", Vector2(0.0, 0.0), false)
	ctx.assert_true(
		renderer._trail_update_body_ids.has(&"planet"),
		"Erster Trail-Punkt wird auch beim weit rausgezoomten Renderer geschrieben"
	)

	# Delta = 10 render units * world_scale 0.1 = 1.0 px < MIN_TRAIL_STEP_PX
	# -> die Dezimation verwirft den Punkt, Line2D wird nicht remeshed.
	renderer._trail_update_body_ids.clear()
	renderer._update_trail(&"planet", Vector2(10.0, 0.0), false)
	ctx.assert_true(
		renderer._trail_update_body_ids.is_empty(),
		"Sub-Pixel-Bewegung beim Rauszoom wird dezimiert und schreibt keine Line-Punkte"
	)

	# Delta = 20 render units * 0.1 = 2.0 px -> ueber der Schwelle.
	renderer._update_trail(&"planet", Vector2(20.0, 0.0), false)
	ctx.assert_true(
		renderer._trail_update_body_ids.has(&"planet"),
		"Ausreichend grosse Screen-Bewegung uebersteht die Dezimation"
	)

	line.free()
	renderer.free()


static func _test_render_sync_does_not_write_trail_points_without_sim_tick(ctx) -> void:
	var renderer = OrbitViewRendererScript.new()
	var registry := _make_trail_registry_probe()
	var bubble := BubbleProbe.new()
	var line := AntialiasedLine2D.new()
	renderer._registry = registry
	renderer._bubble = bubble
	renderer._focus_id = &"star"
	renderer._trail_visuals[&"planet"] = line
	renderer._trail_histories[&"planet"] = []

	renderer._sync_visual_positions()
	ctx.assert_true(
		renderer._trail_update_body_ids.is_empty() and line.points.size() == 0,
		"Render-Sync positioniert Trail-Lines, schreibt aber ohne sim_tick keine Trail-Punkte"
	)

	renderer._on_sim_tick(1.0 / 60.0)
	ctx.assert_true(
		renderer._trail_update_body_ids.has(&"planet") and line.points.size() == 1,
		"Sim-Tick schreibt die Trail-History fuer sichtbare Trail-Bodies"
	)

	line.free()
	bubble.free()
	registry.free()
	renderer.free()


static func _test_root_overview_sim_tick_does_not_write_trail_points(ctx) -> void:
	var renderer = OrbitViewRendererScript.new()
	var registry := _make_trail_registry_probe()
	var bubble := BubbleProbe.new()
	var line := AntialiasedLine2D.new()
	renderer._registry = registry
	renderer._bubble = bubble
	renderer._focus_id = &"star"
	renderer._frame_label = OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW
	renderer._trail_visuals[&"planet"] = line
	renderer._trail_histories[&"planet"] = []

	renderer._sync_visual_positions()
	renderer._on_sim_tick(1.0 / 60.0)
	ctx.assert_true(
		renderer._trail_update_body_ids.is_empty() and line.points.size() == 0,
		"Root-Overview schreibt auch bei sim_tick keine versteckten Trail-Punkte"
	)

	line.free()
	bubble.free()
	registry.free()
	renderer.free()


static func _test_close_zoom_state_has_hysteresis(ctx) -> void:
	var renderer = OrbitViewRendererScript.new()

	renderer._update_close_zoom_state(3.0)
	ctx.assert_true(
		not renderer._close_zoom_active,
		"Kleine effektive Scale unterhalb Enter laesst Close-Zoom inaktiv"
	)

	renderer._update_close_zoom_state(5.5)
	ctx.assert_true(
		not renderer._close_zoom_active,
		"Scale zwischen Exit und Enter loest keinen Enter aus"
	)

	renderer._update_close_zoom_state(6.5)
	ctx.assert_true(
		renderer._close_zoom_active,
		"Scale oberhalb Enter-Schwelle aktiviert Close-Zoom"
	)

	renderer._update_close_zoom_state(5.5)
	ctx.assert_true(
		renderer._close_zoom_active,
		"Hysterese haelt Close-Zoom aktiv, solange Scale ueber Exit bleibt"
	)

	renderer._update_close_zoom_state(4.0)
	ctx.assert_true(
		not renderer._close_zoom_active,
		"Scale unterhalb Exit-Schwelle deaktiviert Close-Zoom"
	)

	renderer.free()


static func _test_screen_circle_visibility_helper(ctx) -> void:
	ctx.assert_true(
		OrbitViewRendererScript._screen_circle_intersects_viewport(
			Vector2(120.0, 120.0),
			10.0,
			Vector2(240.0, 240.0),
			0.0
		),
		"Screen-Culling behaelt Kreise im Viewport sichtbar"
	)
	ctx.assert_true(
		OrbitViewRendererScript._screen_circle_intersects_viewport(
			Vector2(-30.0, 120.0),
			20.0,
			Vector2(240.0, 240.0),
			15.0
		),
		"Screen-Culling nutzt Radius plus Margin gegen Rand-Popping"
	)
	ctx.assert_true(
		not OrbitViewRendererScript._screen_circle_intersects_viewport(
			Vector2(-80.0, 120.0),
			20.0,
			Vector2(240.0, 240.0),
			15.0
		),
		"Screen-Culling verwirft eindeutig ausserhalb liegende Kreise"
	)


static func _test_sync_visuals_now_skips_redundant_process_sync(ctx) -> void:
	var renderer := RendererProbe.new()

	# Explicit external sync markiert den aktuellen Frame als gesynced.
	renderer.sync_visuals_now()
	var guard_frame: int = renderer._synced_frame_number

	ctx.assert_true(
		guard_frame == Engine.get_process_frames(),
		"sync_visuals_now merkt sich den aktuellen Frame"
	)

	# Ein direkter _process-Aufruf im selben Frame darf nicht erneut syncen.
	# (Indirekter Assert: der Guard-Frame bleibt unveraendert.)
	renderer._process(0.016)
	ctx.assert_true(
		renderer._synced_frame_number == guard_frame,
		"_process im selben Frame syncet nicht doppelt, wenn bereits extern getriggert"
	)
	ctx.assert_true(
		renderer.sync_visual_positions_count == 1,
		"_process laesst den bereits extern gesyncten Frame unangetastet"
	)

	renderer.free()


static func _test_forced_sync_visuals_now_overrides_same_frame_guard(ctx) -> void:
	var renderer := RendererProbe.new()

	renderer.sync_visuals_now()
	renderer.sync_visuals_now()
	ctx.assert_true(
		renderer.sync_visual_positions_count == 1,
		"normaler Sync bleibt im selben Frame idempotent"
	)

	renderer.sync_visuals_now(true)
	ctx.assert_true(
		renderer.sync_visual_positions_count == 2,
		"erzwungener Sync kann nach einem sofortigen Fokus-/Kamerawechsel denselben Frame neu schreiben"
	)

	renderer.free()


static func _make_trail_registry_probe() -> RegistryProbe:
	var registry := RegistryProbe.new()
	registry.add_body(&"star", BodyType.Kind.STAR, &"", Vector3.ZERO)
	registry.add_body(&"planet", BodyType.Kind.PLANET, &"star", Vector3(1000.0, 0.0, 0.0))
	return registry
