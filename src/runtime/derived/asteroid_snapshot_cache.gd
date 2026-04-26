class_name AsteroidSnapshotCache
extends RefCounted

signal snapshot_refreshed(reason: StringName)

const REASON_CONFIGURE: StringName = &"configure"
const REASON_MANUAL: StringName = &"manual"
const REASON_WORLD_RELOAD: StringName = &"world_reload"

var _asteroid_service = null
var _bubble = null
var _registry = null
var _topology: UniverseTopology = null
var _entries: Array = []
var _revision: int = 0
var _source_revision: int = -1
var _last_refresh_reason: StringName = REASON_MANUAL
var _refresh_call_count: int = 0


func configure(asteroid_service, bubble, registry = null, topology: UniverseTopology = null) -> void:
	assert(asteroid_service != null, "AsteroidSnapshotCache.configure: asteroid_service is null")
	assert(bubble != null, "AsteroidSnapshotCache.configure: bubble is null")
	dispose()
	_asteroid_service = asteroid_service
	_bubble = bubble
	_registry = registry
	if topology != null:
		_topology = topology
	elif registry != null:
		_topology = UniverseTopology.new()
		_topology.configure(registry)
	refresh(REASON_CONFIGURE)


func dispose() -> void:
	_asteroid_service = null
	_bubble = null
	_registry = null
	_topology = null
	_entries.clear()
	_revision = 0
	_source_revision = -1
	_last_refresh_reason = REASON_MANUAL
	_refresh_call_count = 0


func refresh(reason: StringName = REASON_MANUAL) -> void:
	_refresh_call_count += 1
	_last_refresh_reason = reason
	_entries.clear()
	if _asteroid_service == null or _bubble == null or not _asteroid_service.has_method("get_state_snapshot"):
		_revision += 1
		snapshot_refreshed.emit(reason)
		return

	var snapshot: Dictionary = _asteroid_service.get_state_snapshot()
	_source_revision = int(snapshot.get("revision", -1))
	var anchor_view_by_id: Dictionary = {}
	for entry in snapshot.get("entries", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var anchor_id: StringName = entry.get("anchor_id", StringName(""))
		var anchor_view_m: Vector3 = _entry_anchor_view_m(entry, anchor_id, anchor_view_by_id)
		var x_m: float = float(entry.get("x_m", 0.0))
		var y_m: float = float(entry.get("y_m", 0.0))
		var z_m: float = float(entry.get("z_m", 0.0))
		var view_m := Vector3(
			anchor_view_m.x + x_m,
			anchor_view_m.y + y_m,
			anchor_view_m.z + z_m
		)
		_entries.append({
			"id": entry.get("id", StringName("")),
			"root_id": entry.get("root_id", StringName("")),
			"anchor_id": anchor_id,
			"spawn_origin_id": entry.get("spawn_origin_id", StringName("")),
			"x_m": x_m,
			"y_m": y_m,
			"z_m": z_m,
			"anchor_view_m": anchor_view_m,
			"view_position_m": view_m,
			"radius_m": float(entry.get("radius_m", 0.0)),
			"visual_class": entry.get("visual_class", StringName("")),
			"is_finite": _is_finite_vec3(view_m),
		})
	_revision += 1
	snapshot_refreshed.emit(reason)


func clear(reason: StringName = REASON_WORLD_RELOAD) -> void:
	_entries.clear()
	_revision += 1
	_last_refresh_reason = reason
	snapshot_refreshed.emit(reason)


func get_entries() -> Array:
	return _entries.duplicate(true)


func get_revision() -> int:
	return _revision


func get_source_revision() -> int:
	return _source_revision


func get_debug_snapshot() -> Dictionary:
	return {
		"revision": _revision,
		"source_revision": _source_revision,
		"entry_count": _entries.size(),
		"last_refresh_reason": _last_refresh_reason,
		"refresh_call_count": _refresh_call_count,
	}


func _anchor_view_m(anchor_id: StringName, anchor_view_by_id: Dictionary) -> Vector3:
	if anchor_view_by_id.has(anchor_id):
		return anchor_view_by_id[anchor_id]
	var view_m: Vector3 = _bubble.compose_view_position_m(anchor_id)
	anchor_view_by_id[anchor_id] = view_m
	return view_m


func _entry_anchor_view_m(entry: Dictionary, anchor_id: StringName, anchor_view_by_id: Dictionary) -> Vector3:
	var focus_root_id: StringName = _focus_root_id()
	var entry_root_id: StringName = _entry_root_id(entry, anchor_id)
	if focus_root_id != StringName("") and entry_root_id != StringName("") and focus_root_id != entry_root_id:
		return Vector3.INF
	return _anchor_view_m(anchor_id, anchor_view_by_id)


func _focus_root_id() -> StringName:
	if _bubble == null or _topology == null or not _bubble.has_method("get_focus"):
		return StringName("")
	var focus_id: StringName = _bubble.get_focus()
	if focus_id == StringName(""):
		return StringName("")
	if _registry != null and _registry.has_method("has_body") and not _registry.has_body(focus_id):
		return StringName("")
	return _topology.root_id_of(focus_id)


func _entry_root_id(entry: Dictionary, anchor_id: StringName) -> StringName:
	var root_id: StringName = entry.get("root_id", StringName(""))
	if root_id != StringName(""):
		return root_id
	if _topology == null or anchor_id == StringName(""):
		return StringName("")
	if _registry != null and _registry.has_method("has_body") and not _registry.has_body(anchor_id):
		return StringName("")
	return _topology.root_id_of(anchor_id)


static func _is_finite_vec3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
