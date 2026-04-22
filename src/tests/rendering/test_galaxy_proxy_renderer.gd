extends RefCounted

const GalaxyProxyRendererScript = preload("res://src/tools/rendering/galaxy_proxy_renderer.gd")
const OrbitBodyVisualScript = preload("res://src/tools/rendering/orbit_body_visual.gd")


static func run(ctx) -> void:
	ctx.current_suite = "test_galaxy_proxy_renderer"
	_test_root_proxies_reuse_black_hole_visual_contract(ctx)
	_test_proxy_sizes_counter_scale_against_camera_zoom(ctx)


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
