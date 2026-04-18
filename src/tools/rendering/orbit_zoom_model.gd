class_name OrbitZoomModel
extends RefCounted


const MIN_ZOOM_FACTOR: float = 0.05
const FIT_ZOOM_FACTOR: float = 1.0
const MAX_ZOOM_FACTOR: float = 100.0


static func world_overview_scale(root_fit_scale: float, overview_ratio: float) -> float:
	return maxf(root_fit_scale, 0.0001) * maxf(overview_ratio, 0.0)


static func target_view_scale(
	root_fit_scale: float,
	focus_fit_scale: float,
	zoom_factor: float,
	overview_ratio: float,
	max_focus_closeup_bias: float
) -> float:
	var safe_root_fit_scale: float = maxf(root_fit_scale, 0.0001)
	var safe_focus_fit_scale: float = maxf(focus_fit_scale, 0.0001)
	var clamped_zoom_factor: float = clampf(zoom_factor, MIN_ZOOM_FACTOR, MAX_ZOOM_FACTOR)
	var overview_scale: float = world_overview_scale(safe_root_fit_scale, overview_ratio)

	if clamped_zoom_factor <= FIT_ZOOM_FACTOR:
		var world_t: float = _log_progress(clamped_zoom_factor, MIN_ZOOM_FACTOR, FIT_ZOOM_FACTOR)
		return _geometric_lerp(overview_scale, safe_focus_fit_scale, world_t)

	return safe_focus_fit_scale * focus_closeup_bias(clamped_zoom_factor, max_focus_closeup_bias)


static func focus_closeup_bias(zoom_factor: float, max_focus_closeup_bias: float) -> float:
	var safe_max_focus_closeup_bias: float = maxf(max_focus_closeup_bias, FIT_ZOOM_FACTOR)
	var clamped_zoom_factor: float = clampf(zoom_factor, FIT_ZOOM_FACTOR, MAX_ZOOM_FACTOR)
	if clamped_zoom_factor <= FIT_ZOOM_FACTOR:
		return FIT_ZOOM_FACTOR
	var focus_t: float = _log_progress(clamped_zoom_factor, FIT_ZOOM_FACTOR, MAX_ZOOM_FACTOR)
	return _geometric_lerp(FIT_ZOOM_FACTOR, safe_max_focus_closeup_bias, focus_t)


static func zoom_mode_label(zoom_factor: float) -> String:
	if zoom_factor < FIT_ZOOM_FACTOR:
		return "world"
	if is_equal_approx(zoom_factor, FIT_ZOOM_FACTOR):
		return "fit"
	return "focus"


static func focus_closeup_ratio(current_view_scale: float, focus_fit_scale: float) -> float:
	return maxf(current_view_scale / maxf(focus_fit_scale, 0.0001), 1.0)


static func _log_progress(value: float, start: float, finish: float) -> float:
	var safe_start: float = maxf(start, 0.0001)
	var safe_finish: float = maxf(finish, safe_start + 0.0001)
	var safe_value: float = clampf(value, safe_start, safe_finish)
	return clampf(
		(log(safe_value) - log(safe_start)) / maxf(log(safe_finish) - log(safe_start), 0.0001),
		0.0,
		1.0
	)


static func _geometric_lerp(start: float, finish: float, weight: float) -> float:
	var safe_start: float = maxf(start, 0.0001)
	var safe_finish: float = maxf(finish, 0.0001)
	var t: float = clampf(weight, 0.0, 1.0)
	return exp(lerpf(log(safe_start), log(safe_finish), t))
