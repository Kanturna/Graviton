extends RefCounted

const GalaxyProxyRendererScript = preload("res://src/tools/rendering/galaxy_proxy_renderer.gd")
const OrbitBodyVisualScript = preload("res://src/tools/rendering/orbit_body_visual.gd")


class TimeProbe:
	extends Node

	var sim_time_s: float = 0.0


static func run(ctx) -> void:
	ctx.current_suite = "test_galaxy_proxy_renderer"
	_test_root_proxies_reuse_black_hole_visual_contract(ctx)
	_test_proxy_sizes_counter_scale_against_camera_zoom(ctx)
	_test_star_proxy_tier_uses_hysteresis(ctx)
	_test_root_proxy_culling_uses_envelope_margin(ctx)
	_test_proxy_redraw_is_dirty_driven(ctx)
	_test_hidden_proxy_renderer_is_not_pickable(ctx)


static func _test_root_proxies_reuse_black_hole_visual_contract(ctx) -> void:
	var root_spec: Dictionary = GalaxyProxyRendererScript.root_proxy_visual_spec()
	var black_hole_spec: Dictionary = OrbitBodyVisualScript.black_hole_base_visual_spec()
	ctx.assert_almost(
		float(root_spec.get("ring_radius_px", 0.0)),
		float(black_hole_spec.get("ring_radius_px", 0.0)),
		0.0001,
		"Galaxy-Root-Proxies nutzen dieselbe BH-Ringgroesse wie der Detail-Root"
	)
	ctx.assert_almost(
		float(root_spec.get("outer_glow_radius_px", 0.0)),
		float(black_hole_spec.get("outer_glow_radius_px", 0.0)),
		0.0001,
		"Galaxy-Root-Proxies nutzen denselben aeusseren BH-Footprint wie der Detail-Root"
	)


static func _test_proxy_sizes_counter_scale_against_camera_zoom(ctx) -> void:
	ctx.assert_almost(
		GalaxyProxyRendererScript.screen_px_to_local_units(13.0, 0.5),
		26.0,
		0.0001,
		"Proxy-Radien kompensieren kleinen Kamera-Scale ueber inverse Lokaleinheiten"
	)
	ctx.assert_almost(
		GalaxyProxyRendererScript.screen_px_to_local_units(13.0, 2.0),
		6.5,
		0.0001,
		"Proxy-Radien kompensieren grossen Kamera-Scale ueber inverse Lokaleinheiten"
	)


static func _test_star_proxy_tier_uses_hysteresis(ctx) -> void:
	ctx.assert_true(
		not GalaxyProxyRendererScript.resolve_star_proxy_visibility(false, 95.0),
		"unterhalb der Enter-Schwelle bleiben Roots im BH-only-Tier"
	)
	ctx.assert_true(
		GalaxyProxyRendererScript.resolve_star_proxy_visibility(false, 96.0),
		"ab der Enter-Schwelle wechseln Roots in das Stern-Proxy-Tier"
	)
	ctx.assert_true(
		GalaxyProxyRendererScript.resolve_star_proxy_visibility(true, 80.0),
		"an der Exit-Grenze bleiben bereits sichtbare Stern-Proxies stabil"
	)
	ctx.assert_true(
		not GalaxyProxyRendererScript.resolve_star_proxy_visibility(true, 79.0),
		"unterhalb der Exit-Schwelle fallen Stern-Proxies wieder auf BH-only zurueck"
	)


static func _test_root_proxy_culling_uses_envelope_margin(ctx) -> void:
	var viewport_size_px := Vector2(800.0, 600.0)
	ctx.assert_true(
		not GalaxyProxyRendererScript.should_cull_root_proxy(Vector2(-128.0, 300.0), viewport_size_px, 128.0),
		"ein Root genau auf der negativen Envelope-Grenze bleibt sichtbar"
	)
	ctx.assert_true(
		GalaxyProxyRendererScript.should_cull_root_proxy(Vector2(-129.0, 300.0), viewport_size_px, 128.0),
		"ein Root knapp ausserhalb der negativen Envelope-Grenze wird gecullt"
	)
	ctx.assert_true(
		not GalaxyProxyRendererScript.should_cull_root_proxy(Vector2(928.0, 300.0), viewport_size_px, 128.0),
		"ein Root genau auf der positiven Envelope-Grenze bleibt sichtbar"
	)
	ctx.assert_true(
		GalaxyProxyRendererScript.should_cull_root_proxy(Vector2(929.0, 300.0), viewport_size_px, 128.0),
		"ein Root knapp ausserhalb der positiven Envelope-Grenze wird gecullt"
	)


static func _test_proxy_redraw_is_dirty_driven(ctx) -> void:
	var renderer = GalaxyProxyRendererScript.new()
	var time_probe := TimeProbe.new()
	renderer._time_service = time_probe
	renderer._process(0.0)
	var first_snapshot: Dictionary = renderer.get_debug_snapshot()
	ctx.assert_true(
		int(first_snapshot.get("redraw_request_count", 0)) == 1,
		"GalaxyProxyRenderer queued beim ersten Dirty-Check genau ein Redraw"
	)

	renderer.recompute_proxy_state()
	var clean_snapshot: Dictionary = renderer.get_debug_snapshot()
	ctx.assert_true(
		not bool(clean_snapshot.get("proxy_state_dirty", true)),
		"recompute_proxy_state markiert den Proxy-State als sauber"
	)

	renderer._process(0.0)
	var stable_snapshot: Dictionary = renderer.get_debug_snapshot()
	ctx.assert_true(
		int(stable_snapshot.get("redraw_request_count", 0)) == int(clean_snapshot.get("redraw_request_count", 0)),
		"stabile Proxy-Signatur queued nicht mehr jedes Frame ein Redraw"
	)

	time_probe.sim_time_s = 10.0
	renderer._process(0.0)
	var bh_only_time_snapshot: Dictionary = renderer.get_debug_snapshot()
	ctx.assert_true(
		int(bh_only_time_snapshot.get("redraw_request_count", 0)) == int(clean_snapshot.get("redraw_request_count", 0)),
		"Sim-Zeit allein queued im BH-only-Proxy-State kein Redraw"
	)

	renderer._last_debug_snapshot["star_proxy_count"] = 1
	renderer._process(0.0)
	var star_time_snapshot: Dictionary = renderer.get_debug_snapshot()
	ctx.assert_true(
		int(star_time_snapshot.get("redraw_request_count", 0)) == int(clean_snapshot.get("redraw_request_count", 0)) + 1,
		"Sim-Zeit queued Redraws erst, wenn Stern-Proxies sichtbar sind"
	)
	renderer.recompute_proxy_state()
	var star_clean_snapshot: Dictionary = renderer.get_debug_snapshot()

	renderer.position = Vector2(12.0, 0.0)
	renderer._process(0.0)
	var moved_snapshot: Dictionary = renderer.get_debug_snapshot()
	ctx.assert_true(
		int(moved_snapshot.get("redraw_request_count", 0)) == int(star_clean_snapshot.get("redraw_request_count", 0)) + 1,
		"Kamera-/Canvas-Aenderung queued wieder genau ein Proxy-Redraw"
	)

	renderer._process(0.0)
	var queued_snapshot: Dictionary = renderer.get_debug_snapshot()
	ctx.assert_true(
		int(queued_snapshot.get("redraw_request_count", 0)) == int(moved_snapshot.get("redraw_request_count", 0)),
		"ein bereits gequeuedes Dirty-Redraw wird nicht pro Frame doppelt angefordert"
	)
	time_probe.free()
	renderer.free()


static func _test_hidden_proxy_renderer_is_not_pickable(ctx) -> void:
	var renderer = GalaxyProxyRendererScript.new()
	renderer._root_local_positions_ru[&"obsidian"] = Vector2.ZERO
	renderer.visible = false
	ctx.assert_true(
		renderer.pick_root_at_screen(Vector2.ZERO) == StringName(""),
		"versteckter GalaxyProxyRenderer liefert keine stale Root-Picks"
	)
	renderer.free()
