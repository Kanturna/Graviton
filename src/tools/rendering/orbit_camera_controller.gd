class_name OrbitCameraController
extends RefCounted


const OrbitZoomModelScript = preload("res://src/tools/rendering/orbit_zoom_model.gd")

const VIEWPORT_RADIUS_FACTOR: float = 0.38
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
var _target_world_offset: Vector2 = Vector2.ZERO
var _current_world_offset: Vector2 = Vector2.ZERO
var _manual_pan_ru: Vector2 = Vector2.ZERO
var _current_scope_radius_ru: float = 1.0
var _last_viewport_size: Vector2 = Vector2.ZERO


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
	if force_fit:
		fit_current_focus()
	if _last_viewport_size != Vector2.ZERO:
		_refresh_target_view(_last_viewport_size)
		if immediate:
			_apply_view_transform(true, 0.0, _last_viewport_size)


func step(delta: float, viewport_size: Vector2) -> void:
	if _renderer == null or _bubble == null:
		return
	_last_viewport_size = viewport_size
	_refresh_target_view(viewport_size)
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


func _refresh_target_view(viewport_size: Vector2) -> void:
	var focus_id: StringName = _bubble.get_focus()
	var focus_center: Vector2 = _renderer.get_body_view_position_ru(focus_id)
	if not _is_finite_vec2(focus_center):
		focus_center = Vector2.ZERO
	var anchor_center: Vector2 = focus_center
	if _absolute_zoom_factor < OrbitZoomModelScript.FIT_ZOOM_FACTOR and _topology != null:
		var root_id: StringName = _topology.root_id_of(focus_id)
		if root_id != StringName("") and root_id != focus_id:
			var root_center: Vector2 = _renderer.get_body_view_position_ru(root_id)
			if _is_finite_vec2(root_center):
				var blend: float = OrbitZoomModelScript.wide_anchor_blend(_absolute_zoom_factor)
				anchor_center = focus_center.lerp(root_center, blend)

	var scope_fit_scale: float = _current_scope_fit_scale(viewport_size)
	_target_view_scale = OrbitZoomModelScript.target_view_scale(scope_fit_scale, _absolute_zoom_factor)
	_target_world_offset = viewport_size * 0.5 - (anchor_center + _manual_pan_ru) * _target_view_scale


func _apply_view_transform(immediate: bool, delta: float, viewport_size: Vector2) -> void:
	if immediate:
		_current_view_scale = _target_view_scale
		_current_world_offset = _target_world_offset
	else:
		var weight: float = 1.0 - exp(-VIEW_SMOOTHNESS * delta)
		_current_view_scale = lerpf(_current_view_scale, _target_view_scale, weight)
		_current_world_offset = _current_world_offset.lerp(_target_world_offset, weight)

	_renderer.scale = Vector2.ONE * _current_view_scale
	_renderer.position = _current_world_offset
	_renderer.set_world_scale(_current_view_scale)
	_renderer.set_focus_closeup_ratio(_current_focus_closeup_ratio(viewport_size))


func _fit_scale_for_radius(focus_radius: float, viewport_size: Vector2) -> float:
	var safe_radius: float = maxf(focus_radius, 1.0)
	var target_screen_radius: float = minf(viewport_size.x, viewport_size.y) * VIEWPORT_RADIUS_FACTOR
	return target_screen_radius / safe_radius


func _refresh_scope_radius(body_id: StringName) -> void:
	if _renderer == null:
		_current_scope_radius_ru = 1.0
		return
	var frame: Dictionary = _renderer.get_scope_frame(body_id)
	_current_scope_radius_ru = maxf(float(frame.get("radius", 1.0)), 1.0)


func _current_scope_fit_scale(viewport_size: Vector2) -> float:
	return _fit_scale_for_radius(_current_scope_radius_ru, viewport_size)


func _current_focus_closeup_ratio(viewport_size: Vector2) -> float:
	return OrbitZoomModelScript.focus_closeup_ratio(
		_current_view_scale,
		_current_scope_fit_scale(viewport_size)
	)


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
