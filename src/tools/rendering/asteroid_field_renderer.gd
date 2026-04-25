class_name AsteroidFieldRenderer
extends Node2D

const TRAIL_POINT_CAP: int = 10
const MIN_TRAIL_STEP_PX: float = 1.0
const POINT_RADIUS_PX: float = 1.9
const TRAIL_WIDTH_PX: float = 0.9
const SCREEN_DEBUG_MARGIN_PX: float = 96.0

var _snapshot_cache = null
var _entries_by_id: Dictionary = {}
var _trail_histories_by_id: Dictionary = {}
var _anchor_view_by_id: Dictionary = {}
var _last_source_revision: int = -1
var _sync_count: int = 0


func configure(snapshot_cache) -> void:
	_snapshot_cache = snapshot_cache
	clear_state()
	sync_visuals_now(true)


func clear_state() -> void:
	_entries_by_id.clear()
	_trail_histories_by_id.clear()
	_anchor_view_by_id.clear()
	_last_source_revision = -1
	queue_redraw()


func sync_visuals_now(force: bool = false, refresh_snapshot: bool = true) -> void:
	_sync_count += 1
	if _snapshot_cache == null:
		clear_state()
		return
	if refresh_snapshot and _snapshot_cache.has_method("refresh"):
		_snapshot_cache.refresh(&"manual")
	var source_revision: int = _snapshot_cache.get_source_revision() if _snapshot_cache.has_method("get_source_revision") else -1
	var source_changed: bool = force or source_revision != _last_source_revision
	_last_source_revision = source_revision
	var next_entries: Dictionary = {}
	var live_ids: Dictionary = {}
	var next_anchor_view_by_id: Dictionary = {}
	for entry in _snapshot_cache.get_entries():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id: StringName = entry.get("id", StringName(""))
		if id == StringName("") or not bool(entry.get("is_finite", false)):
			continue
		var anchor_id: StringName = entry.get("anchor_id", StringName(""))
		if anchor_id != StringName("") and not next_anchor_view_by_id.has(anchor_id):
			next_anchor_view_by_id[anchor_id] = entry.get("anchor_view_m", Vector3.INF)
		next_entries[id] = entry
		live_ids[id] = true
		if source_changed:
			_append_trail_sample(id, entry)
	for id in _trail_histories_by_id.keys():
		if not live_ids.has(id):
			_trail_histories_by_id.erase(id)
	_entries_by_id = next_entries
	_anchor_view_by_id = next_anchor_view_by_id
	queue_redraw()


func get_debug_snapshot() -> Dictionary:
	var snapshot := {
		"visible_count": _entries_by_id.size(),
		"trail_count": _trail_histories_by_id.size(),
		"trail_point_count": _trail_point_count(),
		"anchor_view_count": _anchor_view_by_id.size(),
		"source_revision": _last_source_revision,
		"sync_count": _sync_count,
	}
	var bounds: Dictionary = _debug_bounds_snapshot()
	for key in bounds.keys():
		snapshot[key] = bounds[key]
	return snapshot


func _draw() -> void:
	var pixel_scale: float = _pixel_scale()
	var trail_width: float = TRAIL_WIDTH_PX * pixel_scale
	var point_radius: float = POINT_RADIUS_PX * pixel_scale
	for id in _trail_histories_by_id.keys():
		var history: Array = _trail_histories_by_id[id]
		if history.size() < 2:
			continue
		var points := PackedVector2Array()
		for sample in history:
			if typeof(sample) != TYPE_DICTIONARY:
				continue
			var point: Vector2 = _sample_position_ru(sample, _anchor_view_by_id)
			if _is_finite_vec2(point):
				points.append(point)
		if points.size() < 2:
			continue
		draw_polyline(points, Color(0.72, 0.78, 0.84, 0.34), trail_width, true)
	for id in _entries_by_id.keys():
		var entry: Dictionary = _entries_by_id[id]
		var color: Color = _color_for(entry.get("visual_class", StringName("")))
		var point: Vector2 = _entry_position_ru(entry)
		if _is_finite_vec2(point):
			draw_circle(point, point_radius, color)


func _append_trail_sample(id: StringName, entry: Dictionary) -> void:
	if not _trail_histories_by_id.has(id):
		_trail_histories_by_id[id] = []
	var history: Array = _trail_histories_by_id[id]
	var sample: Dictionary = _entry_trail_sample(entry)
	if history.is_empty() or _sample_distance_ru(history.back(), sample) >= MIN_TRAIL_STEP_PX * _pixel_scale():
		history.append(sample)
	while history.size() > TRAIL_POINT_CAP:
		history.pop_front()


static func _entry_trail_sample(entry: Dictionary) -> Dictionary:
	return {
		"anchor_id": entry.get("anchor_id", StringName("")),
		"x_m": float(entry.get("x_m", 0.0)),
		"y_m": float(entry.get("y_m", 0.0)),
		"z_m": float(entry.get("z_m", 0.0)),
	}


static func _entry_position_ru(entry: Dictionary) -> Vector2:
	var view_m: Vector3 = entry.get("view_position_m", Vector3.INF)
	return Vector2(view_m.x, view_m.y) / UnitSystem.RENDER_SCALE_M_PER_UNIT


static func _sample_position_ru(sample: Dictionary, anchor_view_by_id: Dictionary) -> Vector2:
	var anchor_id: StringName = sample.get("anchor_id", StringName(""))
	var anchor_view_m: Vector3 = anchor_view_by_id.get(anchor_id, Vector3.INF)
	if not _is_finite_vec3(anchor_view_m):
		return Vector2(INF, INF)
	var view_m := Vector3(
		anchor_view_m.x + float(sample.get("x_m", 0.0)),
		anchor_view_m.y + float(sample.get("y_m", 0.0)),
		anchor_view_m.z + float(sample.get("z_m", 0.0))
	)
	return Vector2(view_m.x, view_m.y) / UnitSystem.RENDER_SCALE_M_PER_UNIT


static func _sample_distance_ru(a, b: Dictionary) -> float:
	if typeof(a) != TYPE_DICTIONARY or StringName(a.get("anchor_id", StringName(""))) != StringName(b.get("anchor_id", StringName(""))):
		return INF
	var dx_m: float = float(a.get("x_m", 0.0)) - float(b.get("x_m", 0.0))
	var dy_m: float = float(a.get("y_m", 0.0)) - float(b.get("y_m", 0.0))
	return Vector2(dx_m, dy_m).length() / UnitSystem.RENDER_SCALE_M_PER_UNIT


func _pixel_scale() -> float:
	var scale_x: float = absf(get_global_transform().get_scale().x)
	if scale_x <= 0.000001:
		return 1.0
	return 1.0 / scale_x


func _trail_point_count() -> int:
	var total: int = 0
	for id in _trail_histories_by_id.keys():
		var history: Array = _trail_histories_by_id[id]
		total += history.size()
	return total


func _debug_bounds_snapshot() -> Dictionary:
	var finite_count: int = 0
	var screen_visible_count: int = 0
	var view_min := Vector2(INF, INF)
	var view_max := Vector2(-INF, -INF)
	var screen_min := Vector2(INF, INF)
	var screen_max := Vector2(-INF, -INF)
	var viewport_size := Vector2.ZERO
	var has_viewport: bool = is_inside_tree()
	if has_viewport:
		viewport_size = get_viewport_rect().size
		has_viewport = viewport_size.x > 0.0 and viewport_size.y > 0.0
	var canvas_xform: Transform2D = get_global_transform_with_canvas() if is_inside_tree() else get_global_transform()
	for raw_entry in _entries_by_id.values():
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		var view_ru: Vector2 = _entry_position_ru(entry)
		if not _is_finite_vec2(view_ru):
			continue
		var screen_px: Vector2 = canvas_xform * view_ru
		if not _is_finite_vec2(screen_px):
			continue
		finite_count += 1
		view_min.x = minf(view_min.x, view_ru.x)
		view_min.y = minf(view_min.y, view_ru.y)
		view_max.x = maxf(view_max.x, view_ru.x)
		view_max.y = maxf(view_max.y, view_ru.y)
		screen_min.x = minf(screen_min.x, screen_px.x)
		screen_min.y = minf(screen_min.y, screen_px.y)
		screen_max.x = maxf(screen_max.x, screen_px.x)
		screen_max.y = maxf(screen_max.y, screen_px.y)
		if not has_viewport or _screen_point_visible(screen_px, viewport_size, SCREEN_DEBUG_MARGIN_PX):
			screen_visible_count += 1

	var has_bounds: bool = finite_count > 0
	var view_max_abs_ru: float = 0.0
	var screen_max_abs_px: float = 0.0
	if has_bounds:
		view_max_abs_ru = maxf(
			maxf(absf(view_min.x), absf(view_min.y)),
			maxf(absf(view_max.x), absf(view_max.y))
		)
		screen_max_abs_px = maxf(
			maxf(absf(screen_min.x), absf(screen_min.y)),
			maxf(absf(screen_max.x), absf(screen_max.y))
		)
	return {
		"screen_bounds_valid": has_bounds,
		"screen_viewport_valid": has_viewport,
		"screen_visible_count": screen_visible_count,
		"screen_culled_count": max(0, finite_count - screen_visible_count),
		"view_min_x_ru": view_min.x if has_bounds else 0.0,
		"view_max_x_ru": view_max.x if has_bounds else 0.0,
		"view_min_y_ru": view_min.y if has_bounds else 0.0,
		"view_max_y_ru": view_max.y if has_bounds else 0.0,
		"view_max_abs_ru": view_max_abs_ru,
		"screen_min_x_px": screen_min.x if has_bounds else 0.0,
		"screen_max_x_px": screen_max.x if has_bounds else 0.0,
		"screen_min_y_px": screen_min.y if has_bounds else 0.0,
		"screen_max_y_px": screen_max.y if has_bounds else 0.0,
		"screen_max_abs_px": screen_max_abs_px,
	}


static func _is_finite_vec2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


static func _is_finite_vec3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _screen_point_visible(point_px: Vector2, viewport_size: Vector2, margin_px: float) -> bool:
	return point_px.x >= -margin_px \
		and point_px.y >= -margin_px \
		and point_px.x <= viewport_size.x + margin_px \
		and point_px.y <= viewport_size.y + margin_px


static func _color_for(visual_class: StringName) -> Color:
	match visual_class:
		&"carbon":
			return Color(0.68, 0.70, 0.72, 0.92)
		&"metal":
			return Color(0.95, 0.86, 0.62, 0.95)
		_:
			return Color(0.78, 0.76, 0.70, 0.94)
