class_name OrbitCameraFraming
extends RefCounted


const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")

const VIEWPORT_RADIUS_FACTOR: float = 0.38

const WIDE_ASSIST_START: float = 0.50
const FIT_PLATEAU_LOW: float = 0.92
const FIT_PLATEAU_HIGH: float = 1.08

const FIT_SAFE_HALF_WIDTH: float = 0.41
const FIT_SAFE_HALF_HEIGHT: float = 0.39

const DETAIL_SAFE_HALF_WIDTH_FIT: float = 0.36
const DETAIL_SAFE_HALF_HEIGHT_FIT: float = 0.34
const DETAIL_SAFE_HALF_WIDTH_MAX: float = 0.23
const DETAIL_SAFE_HALF_HEIGHT_MAX: float = 0.22

const DETAIL_ASSIST_CLAMP_FRACTION: float = 0.85

const ZOOM_MODE_WIDE: StringName = &"wide"
const ZOOM_MODE_FIT: StringName = &"fit"
const ZOOM_MODE_DETAIL: StringName = &"detail"

const FRAME_LABEL_ROOT_ANCHOR: StringName = &"root-anchor"
const FRAME_LABEL_SMART_FIT: StringName = &"smart-fit"
const FRAME_LABEL_ASSIST_DETAIL: StringName = &"assist-detail"
const FRAME_LABEL_FOCUS_ANCHOR: StringName = &"focus-anchor"


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
	var base_anchor_ru: Vector2 = root_center_ru if has_valid_root else focus_center_ru
	var root_distance: float = 0.0
	if has_valid_root:
		root_distance = focus_center_ru.distance_to(base_anchor_ru)

	var zoom_mode: StringName = _zoom_mode(clamped_zoom)
	var detail_weight: float = _detail_weight(clamped_zoom)
	var union_radius: float = maxf(safe_focus_radius, root_distance + safe_focus_radius)
	var effective_radius: float = maxf(lerpf(union_radius, safe_focus_radius, detail_weight), 1.0)

	var min_viewport_dim: float = minf(safe_viewport.x, safe_viewport.y)
	var scope_fit_scale: float = (min_viewport_dim * VIEWPORT_RADIUS_FACTOR) / effective_radius
	var target_view_scale: float = scope_fit_scale * clamped_zoom

	var auto_offset_ru: Vector2 = Vector2.ZERO
	if has_valid_root:
		var assist_amount: float = _assist_ramp(clamped_zoom)
		if assist_amount > 0.0:
			var focus_screen: Vector2 = (focus_center_ru - base_anchor_ru) * target_view_scale
			var half_w: float = 0.0
			var half_h: float = 0.0
			if zoom_mode == ZOOM_MODE_DETAIL:
				half_w = lerpf(
					DETAIL_SAFE_HALF_WIDTH_FIT,
					DETAIL_SAFE_HALF_WIDTH_MAX,
					detail_weight
				) * safe_viewport.x
				half_h = lerpf(
					DETAIL_SAFE_HALF_HEIGHT_FIT,
					DETAIL_SAFE_HALF_HEIGHT_MAX,
					detail_weight
				) * safe_viewport.y
			else:
				var focus_scope_screen_radius: float = safe_focus_radius * target_view_scale
				half_w = maxf(FIT_SAFE_HALF_WIDTH * safe_viewport.x - focus_scope_screen_radius, 0.0)
				half_h = maxf(FIT_SAFE_HALF_HEIGHT * safe_viewport.y - focus_scope_screen_radius, 0.0)

			var desired_screen: Vector2 = Vector2(
				clampf(focus_screen.x, -half_w, half_w),
				clampf(focus_screen.y, -half_h, half_h)
			)
			var anchor_shift_screen: Vector2 = (focus_screen - desired_screen) * assist_amount
			if zoom_mode == ZOOM_MODE_DETAIL:
				var max_shift: float = focus_screen.length() * DETAIL_ASSIST_CLAMP_FRACTION
				var shift_len: float = anchor_shift_screen.length()
				if shift_len > max_shift and shift_len > 0.0:
					anchor_shift_screen = anchor_shift_screen * (max_shift / shift_len)
			auto_offset_ru = anchor_shift_screen / maxf(target_view_scale, 0.0001)

	return {
		"target_view_scale": target_view_scale,
		"base_anchor_ru": base_anchor_ru,
		"auto_composition_offset_ru": auto_offset_ru,
		"zoom_mode": zoom_mode,
		"frame_label": _frame_label(zoom_mode, has_valid_root),
	}


static func _zoom_mode(clamped_zoom: float) -> StringName:
	if clamped_zoom < FIT_PLATEAU_LOW:
		return ZOOM_MODE_WIDE
	if clamped_zoom > FIT_PLATEAU_HIGH:
		return ZOOM_MODE_DETAIL
	return ZOOM_MODE_FIT


static func _frame_label(zoom_mode: StringName, has_valid_root: bool) -> StringName:
	if not has_valid_root:
		return FRAME_LABEL_FOCUS_ANCHOR
	if zoom_mode == ZOOM_MODE_WIDE:
		return FRAME_LABEL_ROOT_ANCHOR
	if zoom_mode == ZOOM_MODE_DETAIL:
		return FRAME_LABEL_ASSIST_DETAIL
	return FRAME_LABEL_SMART_FIT


static func _assist_ramp(clamped_zoom: float) -> float:
	if clamped_zoom <= WIDE_ASSIST_START:
		return 0.0
	if clamped_zoom >= FIT_PLATEAU_LOW:
		return 1.0
	return inverse_lerp(WIDE_ASSIST_START, FIT_PLATEAU_LOW, clamped_zoom)


static func _detail_weight(clamped_zoom: float) -> float:
	if clamped_zoom <= FIT_PLATEAU_HIGH:
		return 0.0
	var log_span: float = log(OrbitZoomModelScript.MAX_ZOOM_FACTOR) - log(FIT_PLATEAU_HIGH)
	return clampf(
		(log(clamped_zoom) - log(FIT_PLATEAU_HIGH)) / maxf(log_span, 0.0001),
		0.0,
		1.0
	)


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
