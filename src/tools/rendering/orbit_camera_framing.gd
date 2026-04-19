class_name OrbitCameraFraming
extends RefCounted


const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")

const VIEWPORT_RADIUS_FACTOR: float = 0.38
const ROOT_LOCK_IN_VIEWPORT_FRACTION: float = 0.35
const ROOT_LOCK_OUT_VIEWPORT_FRACTION: float = 0.55
const ROOT_LOCK_ANCHOR_BLEND_EXPONENT: float = 1.10

const FIT_PLATEAU_LOW: float = 0.92
const FIT_PLATEAU_HIGH: float = 1.08

const ZOOM_MODE_WIDE: StringName = &"wide"
const ZOOM_MODE_FIT: StringName = &"fit"
const ZOOM_MODE_DETAIL: StringName = &"detail"

const FRAME_LABEL_ROOT_OVERVIEW: StringName = &"root-overview"
const FRAME_LABEL_ROOT_LOCK: StringName = &"root-lock"
const FRAME_LABEL_FOCUS_LOCK: StringName = &"focus-lock"
const FRAME_LABEL_FOCUS_ANCHOR: StringName = FRAME_LABEL_FOCUS_LOCK
const FRAME_LABEL_ROOT_ANCHOR: StringName = FRAME_LABEL_ROOT_LOCK


static func compute_layout(
	focus_center_ru: Vector2,
	root_center_ru: Vector2,
	focus_scope_radius_ru: float,
	zoom_factor: float,
	viewport_size: Vector2
) -> Dictionary:
	var safe_viewport: Vector2 = Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))
	var safe_focus_radius: float = maxf(focus_scope_radius_ru, 1.0)
	var clamped_zoom: float = clampf(
		zoom_factor,
		OrbitZoomModelScript.MIN_ZOOM_FACTOR,
		OrbitZoomModelScript.MAX_ZOOM_FACTOR
	)
	var has_valid_root: bool = (
		_is_finite_vec2(root_center_ru)
		and not root_center_ru.is_equal_approx(focus_center_ru)
	)

	var zoom_mode: StringName = _zoom_mode(clamped_zoom)
	var min_viewport_dim: float = minf(safe_viewport.x, safe_viewport.y)
	var scope_fit_scale: float = (min_viewport_dim * VIEWPORT_RADIUS_FACTOR) / safe_focus_radius
	var target_view_scale: float = scope_fit_scale * clamped_zoom
	var base_anchor_ru: Vector2 = focus_center_ru
	var root_lock_phase: float = 0.0
	if has_valid_root:
		var root_distance_screen_px: float = focus_center_ru.distance_to(root_center_ru) * target_view_scale
		root_lock_phase = root_lock_phase_for_distance(root_distance_screen_px, min_viewport_dim)
		var anchor_blend_phase: float = _anchor_blend_phase(root_lock_phase)
		if anchor_blend_phase > 0.0:
			base_anchor_ru = focus_center_ru.lerp(root_center_ru, anchor_blend_phase)

	return {
		"target_view_scale": target_view_scale,
		"base_anchor_ru": base_anchor_ru,
		"auto_composition_offset_ru": Vector2.ZERO,
		"zoom_mode": zoom_mode,
		"root_lock_phase": root_lock_phase,
	}


static func _zoom_mode(clamped_zoom: float) -> StringName:
	if clamped_zoom < FIT_PLATEAU_LOW:
		return ZOOM_MODE_WIDE
	if clamped_zoom > FIT_PLATEAU_HIGH:
		return ZOOM_MODE_DETAIL
	return ZOOM_MODE_FIT


static func root_lock_phase_for_distance(root_distance_screen_px: float, min_viewport_dim: float) -> float:
	var lock_in_px: float = min_viewport_dim * ROOT_LOCK_IN_VIEWPORT_FRACTION
	var lock_out_px: float = min_viewport_dim * ROOT_LOCK_OUT_VIEWPORT_FRACTION
	return 1.0 - smoothstep(lock_in_px, lock_out_px, root_distance_screen_px)


static func _anchor_blend_phase(root_lock_phase: float) -> float:
	var clamped_phase: float = clampf(root_lock_phase, 0.0, 1.0)
	var centered_phase: float = clamped_phase * 2.0 - 1.0
	if is_zero_approx(centered_phase):
		return 0.5
	var direction: float = -1.0 if centered_phase < 0.0 else 1.0
	var magnitude: float = pow(absf(centered_phase), ROOT_LOCK_ANCHOR_BLEND_EXPONENT)
	return clampf(0.5 + 0.5 * direction * magnitude, 0.0, 1.0)


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
