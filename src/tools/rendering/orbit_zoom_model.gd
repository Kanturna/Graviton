class_name OrbitZoomModel
extends RefCounted


const MIN_ZOOM_FACTOR: float = 0.005
const FIT_ZOOM_FACTOR: float = 1.0
const MAX_ZOOM_FACTOR: float = 100.0


static func target_view_scale(scope_fit_scale: float, zoom_factor: float) -> float:
	var safe_scope_fit_scale: float = maxf(scope_fit_scale, 0.0001)
	var clamped_zoom_factor: float = clampf(zoom_factor, MIN_ZOOM_FACTOR, MAX_ZOOM_FACTOR)
	return safe_scope_fit_scale * clamped_zoom_factor


static func zoom_mode_label(zoom_factor: float) -> String:
	if zoom_factor < FIT_ZOOM_FACTOR:
		return "wide"
	if is_equal_approx(zoom_factor, FIT_ZOOM_FACTOR):
		return "fit"
	return "detail"


static func focus_closeup_ratio(current_view_scale: float, focus_fit_scale: float) -> float:
	return maxf(current_view_scale / maxf(focus_fit_scale, 0.0001), 1.0)
