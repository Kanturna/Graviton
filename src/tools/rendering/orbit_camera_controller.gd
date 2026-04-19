class_name OrbitCameraController
extends RefCounted


const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")
const OrbitCameraFramingScript = preload("res://src/tools/rendering/orbit_camera_framing.gd")

const VIEW_SMOOTHNESS: float = 10.0
const MIN_ABSOLUTE_ZOOM_FACTOR: float = 0.005
const MAX_ABSOLUTE_ZOOM_FACTOR: float = 100.0
const PAN_SPEED_PX_PER_S: float = 960.0

var _renderer = null
var _bubble = null
var _topology = null

var _absolute_zoom_factor: float = OrbitZoomModelScript.FIT_ZOOM_FACTOR
var _target_view_scale: float = 1.0
var _current_view_scale: float = 1.0
var _manual_pan_ru: Vector2 = Vector2.ZERO
var _current_scope_radius_ru: float = 1.0
var _current_zoom_mode: StringName = OrbitCameraFramingScript.ZOOM_MODE_FIT
var _current_frame_label: StringName = OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK
var _last_viewport_size: Vector2 = Vector2.ZERO

var _current_base_anchor_ru: Vector2 = Vector2.ZERO
var _current_root_lock_phase: float = 0.0
var _last_non_overview_frame_label: StringName = OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK
var _has_non_overview_frame_label: bool = false


func configure(renderer, bubble, registry: Node, topology) -> void:
	_renderer = renderer
	_bubble = bubble
	_topology = topology


func set_focus(body_id: StringName, immediate := false, force_fit := false) -> void:
	if body_id == StringName("") or _bubble == null or _renderer == null:
		return
	_bubble.set_focus(body_id)
	_renderer.set_focus(body_id)
	_renderer.clear_trails()
	_manual_pan_ru = Vector2.ZERO
	_absolute_zoom_factor = OrbitZoomModelScript.FIT_ZOOM_FACTOR
	_refresh_scope_radius(body_id)
	_has_non_overview_frame_label = false
	_last_non_overview_frame_label = OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK
	if force_fit:
		fit_current_focus()
	if _last_viewport_size != Vector2.ZERO:
		_refresh_target_view(_last_viewport_size, 0.0)
		if immediate:
			_apply_view_transform(true, 0.0, _last_viewport_size)


func step(delta: float, viewport_size: Vector2) -> void:
	if _renderer == null or _bubble == null:
		return
	_last_viewport_size = viewport_size
	_refresh_target_view(viewport_size, delta)
	_apply_view_transform(delta <= 0.0, delta, viewport_size)


func handle_zoom_multiplier(factor: float) -> void:
	if not is_finite(factor) or factor <= 0.0:
		return
	_absolute_zoom_factor = clampf(
		_absolute_zoom_factor * factor,
		MIN_ABSOLUTE_ZOOM_FACTOR,
		MAX_ABSOLUTE_ZOOM_FACTOR
	)


func handle_pan_input(input_dir: Vector2, delta: float) -> void:
	if input_dir == Vector2.ZERO:
		return
	_manual_pan_ru += input_dir.normalized() * ((PAN_SPEED_PX_PER_S * delta) / maxf(_current_view_scale, 0.001))


func fit_current_focus() -> void:
	if _bubble == null:
		return
	_manual_pan_ru = Vector2.ZERO
	_refresh_scope_radius(_bubble.get_focus())
	_absolute_zoom_factor = OrbitZoomModelScript.FIT_ZOOM_FACTOR


func get_zoom_factor() -> float:
	return _absolute_zoom_factor


func get_current_view_scale() -> float:
	return _current_view_scale


func get_zoom_mode() -> StringName:
	return _current_zoom_mode


func get_frame_label() -> StringName:
	return _current_frame_label


func _refresh_target_view(viewport_size: Vector2, _delta: float) -> void:
	var focus_id: StringName = _bubble.get_focus()
	var focus_center: Vector2 = _renderer.get_body_view_position_ru(focus_id)
	if not _is_finite_vec2(focus_center):
		focus_center = Vector2.ZERO
	var root_center: Vector2 = Vector2(INF, INF)
	if _topology != null:
		var root_id: StringName = _topology.root_id_of(focus_id)
		if root_id != StringName("") and root_id != focus_id:
			root_center = _renderer.get_body_view_position_ru(root_id)

	# Manual pan stays a pure additive view offset. Lock state is derived from
	# the unpanned focus/root relation and must not switch because the player pans.
	var layout: Dictionary = OrbitCameraFramingScript.compute_layout(
		focus_center,
		root_center,
		_current_scope_radius_ru,
		_absolute_zoom_factor,
		viewport_size
	)

	_target_view_scale = float(layout.get("target_view_scale", 1.0))
	_current_base_anchor_ru = layout.get("base_anchor_ru", focus_center)
	_current_root_lock_phase = clampf(float(layout.get("root_lock_phase", 0.0)), 0.0, 1.0)
	_current_zoom_mode = layout.get("zoom_mode", OrbitCameraFramingScript.ZOOM_MODE_FIT)
	_current_frame_label = _resolve_frame_label(focus_id)


func _apply_view_transform(immediate: bool, delta: float, viewport_size: Vector2) -> void:
	if immediate:
		_current_view_scale = _target_view_scale
	else:
		var weight: float = 1.0 - exp(-VIEW_SMOOTHNESS * delta)
		_current_view_scale = lerpf(_current_view_scale, _target_view_scale, weight)

	var anchor_ru: Vector2 = _current_base_anchor_ru + _manual_pan_ru
	var world_offset: Vector2 = viewport_size * 0.5 - anchor_ru * _current_view_scale

	_renderer.scale = Vector2.ONE * _current_view_scale
	_renderer.position = world_offset
	_renderer.set_world_scale(_current_view_scale)
	var focus_fit_scale: float = _focus_fit_scale(viewport_size)
	_renderer.set_focus_closeup_ratio(
		OrbitZoomModelScript.focus_closeup_ratio(_current_view_scale, focus_fit_scale)
	)


func _refresh_scope_radius(body_id: StringName) -> void:
	if _renderer == null:
		_current_scope_radius_ru = 1.0
		return
	var frame: Dictionary = _renderer.get_scope_frame(body_id)
	_current_scope_radius_ru = maxf(float(frame.get("radius", 1.0)), 1.0)


func _resolve_frame_label(focus_id: StringName) -> StringName:
	var root_id: StringName = StringName("")
	if _topology != null:
		root_id = _topology.root_id_of(focus_id)
	if root_id != StringName("") and root_id == focus_id:
		return OrbitCameraFramingScript.FRAME_LABEL_ROOT_OVERVIEW
	if _current_root_lock_phase >= 0.60:
		return _remember_non_overview_frame_label(OrbitCameraFramingScript.FRAME_LABEL_ROOT_LOCK)
	if _current_root_lock_phase <= 0.40:
		return _remember_non_overview_frame_label(OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK)
	if _has_non_overview_frame_label:
		return _last_non_overview_frame_label
	if _current_root_lock_phase >= 0.50:
		return _remember_non_overview_frame_label(OrbitCameraFramingScript.FRAME_LABEL_ROOT_LOCK)
	return _remember_non_overview_frame_label(OrbitCameraFramingScript.FRAME_LABEL_FOCUS_LOCK)


func _remember_non_overview_frame_label(label: StringName) -> StringName:
	_last_non_overview_frame_label = label
	_has_non_overview_frame_label = true
	return label


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _focus_fit_scale(viewport_size: Vector2) -> float:
	var safe_viewport: Vector2 = Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))
	var min_viewport_dim: float = minf(safe_viewport.x, safe_viewport.y)
	return (min_viewport_dim * OrbitCameraFramingScript.VIEWPORT_RADIUS_FACTOR) / maxf(_current_scope_radius_ru, 1.0)
