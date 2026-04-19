class_name OrbitCameraFraming
extends RefCounted


const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")

const VIEWPORT_RADIUS_FACTOR: float = 0.38

const FIT_PLATEAU_LOW: float = 0.92
const FIT_PLATEAU_HIGH: float = 1.08

const ZOOM_MODE_WIDE: StringName = &"wide"
const ZOOM_MODE_FIT: StringName = &"fit"
const ZOOM_MODE_DETAIL: StringName = &"detail"

const FRAME_LABEL_FOCUS_ANCHOR: StringName = &"focus-anchor"


static func compute_layout(
	focus_center_ru: Vector2,
	_root_center_ru: Vector2,
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

	var zoom_mode: StringName = _zoom_mode(clamped_zoom)
	var min_viewport_dim: float = minf(safe_viewport.x, safe_viewport.y)
	var scope_fit_scale: float = (min_viewport_dim * VIEWPORT_RADIUS_FACTOR) / safe_focus_radius
	var target_view_scale: float = scope_fit_scale * clamped_zoom

	return {
		"target_view_scale": target_view_scale,
		"base_anchor_ru": focus_center_ru,
		"auto_composition_offset_ru": Vector2.ZERO,
		"zoom_mode": zoom_mode,
		"frame_label": FRAME_LABEL_FOCUS_ANCHOR,
	}


static func _zoom_mode(clamped_zoom: float) -> StringName:
	if clamped_zoom < FIT_PLATEAU_LOW:
		return ZOOM_MODE_WIDE
	if clamped_zoom > FIT_PLATEAU_HIGH:
		return ZOOM_MODE_DETAIL
	return ZOOM_MODE_FIT


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
