class_name AsteroidFieldRenderer
extends Node2D

const TRAIL_POINT_CAP: int = 10
const MIN_TRAIL_STEP_PX: float = 1.0
const POINT_RADIUS_PX: float = 1.9
const TRAIL_WIDTH_PX: float = 0.9

var _snapshot_cache = null
var _entries_by_id: Dictionary = {}
var _trail_histories_by_id: Dictionary = {}
var _last_source_revision: int = -1
var _sync_count: int = 0


func configure(snapshot_cache) -> void:
	_snapshot_cache = snapshot_cache
	clear_state()
	sync_visuals_now(true)


func clear_state() -> void:
	_entries_by_id.clear()
	_trail_histories_by_id.clear()
	_last_source_revision = -1
	queue_redraw()


func sync_visuals_now(force: bool = false) -> void:
	_sync_count += 1
	if _snapshot_cache == null:
		clear_state()
		return
	if _snapshot_cache.has_method("refresh"):
		_snapshot_cache.refresh(&"manual")
	var source_revision: int = _snapshot_cache.get_source_revision() if _snapshot_cache.has_method("get_source_revision") else -1
	var source_changed: bool = force or source_revision != _last_source_revision
	_last_source_revision = source_revision
	var next_entries: Dictionary = {}
	var live_ids: Dictionary = {}
	for entry in _snapshot_cache.get_entries():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id: StringName = entry.get("id", StringName(""))
		if id == StringName("") or not bool(entry.get("is_finite", false)):
			continue
		next_entries[id] = entry
		live_ids[id] = true
		if source_changed:
			_append_trail_point(id, _entry_position_ru(entry))
	for id in _trail_histories_by_id.keys():
		if not live_ids.has(id):
			_trail_histories_by_id.erase(id)
	_entries_by_id = next_entries
	queue_redraw()


func get_debug_snapshot() -> Dictionary:
	return {
		"visible_count": _entries_by_id.size(),
		"trail_count": _trail_histories_by_id.size(),
		"trail_point_count": _trail_point_count(),
		"source_revision": _last_source_revision,
		"sync_count": _sync_count,
	}


func _draw() -> void:
	var pixel_scale: float = _pixel_scale()
	var trail_width: float = TRAIL_WIDTH_PX * pixel_scale
	var point_radius: float = POINT_RADIUS_PX * pixel_scale
	for id in _trail_histories_by_id.keys():
		var history: Array = _trail_histories_by_id[id]
		if history.size() < 2:
			continue
		var points := PackedVector2Array()
		for point in history:
			points.append(point)
		draw_polyline(points, Color(0.72, 0.78, 0.84, 0.34), trail_width, true)
	for id in _entries_by_id.keys():
		var entry: Dictionary = _entries_by_id[id]
		var color: Color = _color_for(entry.get("visual_class", StringName("")))
		draw_circle(_entry_position_ru(entry), point_radius, color)


func _append_trail_point(id: StringName, point: Vector2) -> void:
	if not _trail_histories_by_id.has(id):
		_trail_histories_by_id[id] = []
	var history: Array = _trail_histories_by_id[id]
	if history.is_empty() or history.back().distance_to(point) >= MIN_TRAIL_STEP_PX * _pixel_scale():
		history.append(point)
	while history.size() > TRAIL_POINT_CAP:
		history.pop_front()


static func _entry_position_ru(entry: Dictionary) -> Vector2:
	var view_m: Vector3 = entry.get("view_position_m", Vector3.INF)
	return Vector2(view_m.x, view_m.y) / UnitSystem.RENDER_SCALE_M_PER_UNIT


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


static func _color_for(visual_class: StringName) -> Color:
	match visual_class:
		&"carbon":
			return Color(0.68, 0.70, 0.72, 0.92)
		&"metal":
			return Color(0.95, 0.86, 0.62, 0.95)
		_:
			return Color(0.78, 0.76, 0.70, 0.94)
