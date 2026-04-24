extends RefCounted

const OrbitViewRendererScript = preload("res://src/tools/rendering/orbit_view_renderer.gd")


class TimeProbe:
	extends Node

	var paused: bool = false
	var time_scale: float = 1.0
	var last_sim_dt_s: float = 4.0


class RendererProbe:
	extends OrbitViewRendererScript

	var line_width_apply_count: int = 0

	func _apply_line_widths() -> void:
		line_width_apply_count += 1


static func run(ctx) -> void:
	ctx.current_suite = "test_orbit_view_renderer"
	_test_presentation_offset_uses_physics_interpolation_fraction(ctx)
	_test_presentation_offset_is_disabled_when_time_stops(ctx)
	_test_engine_interpolation_fraction_is_safe(ctx)
	_test_world_scale_does_not_reapply_line_widths_when_unchanged(ctx)
	_test_trail_points_update_only_when_history_changes(ctx)


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

	renderer._update_trail(&"planet", Vector2(2.0, 2.0), false)
	ctx.assert_true(
		renderer._trail_update_body_ids.has(&"planet"),
		"Neue Trail-Position aktualisiert die Line-Punkte weiterhin"
	)

	line.free()
	renderer.free()
