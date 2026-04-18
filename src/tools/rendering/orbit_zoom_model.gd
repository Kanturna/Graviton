class_name OrbitZoomModel
extends RefCounted


static func target_view_scale(world_base_scale: float, absolute_zoom_factor: float) -> float:
	return maxf(world_base_scale, 0.0001) * maxf(absolute_zoom_factor, 0.0)


static func fit_zoom_factor(
	focus_fit_scale: float,
	world_base_scale: float,
	min_zoom_factor: float,
	max_zoom_factor: float
) -> float:
	var safe_world_base_scale: float = maxf(world_base_scale, 0.0001)
	return clampf(focus_fit_scale / safe_world_base_scale, min_zoom_factor, max_zoom_factor)


static func projected_focus_radius_px(focus_radius_ru: float, target_view_scale: float) -> float:
	return maxf(focus_radius_ru, 0.0) * maxf(target_view_scale, 0.0)


static func should_auto_fit_for_focus(
	projected_focus_radius_px: float,
	viewport_size: Vector2,
	min_viewport_fraction: float = 0.08,
	max_viewport_fraction: float = 0.60
) -> bool:
	var viewport_short_side: float = maxf(minf(viewport_size.x, viewport_size.y), 1.0)
	return (
		projected_focus_radius_px < viewport_short_side * min_viewport_fraction
		or projected_focus_radius_px > viewport_short_side * max_viewport_fraction
	)


static func focus_closeup_ratio(current_view_scale: float, focus_fit_scale: float) -> float:
	return maxf(current_view_scale / maxf(focus_fit_scale, 0.0001), 1.0)
