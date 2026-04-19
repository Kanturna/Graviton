class_name DerivedSnapshotCache
extends RefCounted


signal snapshot_refreshed(reason: StringName)

const REASON_CONFIGURE: StringName = &"configure"
const REASON_SIM_TICK: StringName = &"sim_tick"
const REASON_FOCUS_CHANGED: StringName = &"focus_changed"
const REASON_WORLD_RELOAD: StringName = &"world_reload"
const REASON_MANUAL: StringName = &"manual"
const REASON_INTEREST_CHANGED: StringName = &"interest_changed"

var _registry: Node = null
var _time_service: Node = null
var _bubble = null
var _world_loader: Node = null
var _thermal_service: Node = null
var _environment_service: Node = null
var _orbit_service: Node = null

var _focus_id: StringName = &""
var _focus_thermal_desc: Dictionary = {}
var _focus_environment_desc: Dictionary = {}
var _thermal_desc_by_id: Dictionary = {}
var _environment_desc_by_id: Dictionary = {}
var _explicit_interest_ids: Dictionary = {}
var _dirty_interest_ids: Dictionary = {}
var _dirty_all_interest: bool = true
var _revision: int = 0
var _last_refresh_reason: StringName = REASON_MANUAL
var _last_refreshed_body_count: int = 0


func configure(
		registry: Node,
		time_service: Node,
		bubble,
		world_loader: Node,
		thermal_service: Node,
		environment_service: Node,
		orbit_service: Node = null
	) -> void:
	assert(registry != null, "DerivedSnapshotCache.configure: registry is null")
	assert(time_service != null, "DerivedSnapshotCache.configure: time_service is null")
	assert(bubble != null, "DerivedSnapshotCache.configure: bubble is null")
	assert(world_loader != null, "DerivedSnapshotCache.configure: world_loader is null")
	assert(thermal_service != null, "DerivedSnapshotCache.configure: thermal_service is null")
	assert(environment_service != null, "DerivedSnapshotCache.configure: environment_service is null")
	dispose()
	_registry = registry
	_time_service = time_service
	_bubble = bubble
	_world_loader = world_loader
	_thermal_service = thermal_service
	_environment_service = environment_service
	_orbit_service = orbit_service
	if _orbit_service != null and _orbit_service.has_signal("bodies_updated"):
		if not _orbit_service.bodies_updated.is_connected(_on_bodies_updated):
			_orbit_service.bodies_updated.connect(_on_bodies_updated)
	elif not _time_service.sim_tick.is_connected(_on_sim_tick_fallback):
		_time_service.sim_tick.connect(_on_sim_tick_fallback)
	if not _bubble.focus_changed.is_connected(_on_focus_changed):
		_bubble.focus_changed.connect(_on_focus_changed)
	if not _world_loader.world_loaded.is_connected(_on_world_loaded):
		_world_loader.world_loaded.connect(_on_world_loaded)
	_dirty_all_interest = true
	refresh(REASON_CONFIGURE)


func dispose() -> void:
	if _orbit_service != null and _orbit_service.has_signal("bodies_updated") and _orbit_service.bodies_updated.is_connected(_on_bodies_updated):
		_orbit_service.bodies_updated.disconnect(_on_bodies_updated)
	if _time_service != null and _time_service.sim_tick.is_connected(_on_sim_tick_fallback):
		_time_service.sim_tick.disconnect(_on_sim_tick_fallback)
	if _bubble != null and _bubble.focus_changed.is_connected(_on_focus_changed):
		_bubble.focus_changed.disconnect(_on_focus_changed)
	if _world_loader != null and _world_loader.world_loaded.is_connected(_on_world_loaded):
		_world_loader.world_loaded.disconnect(_on_world_loaded)
	_registry = null
	_time_service = null
	_bubble = null
	_world_loader = null
	_thermal_service = null
	_environment_service = null
	_orbit_service = null
	_focus_id = StringName("")
	_focus_thermal_desc.clear()
	_focus_environment_desc.clear()
	_thermal_desc_by_id.clear()
	_environment_desc_by_id.clear()
	_explicit_interest_ids.clear()
	_dirty_interest_ids.clear()
	_dirty_all_interest = true
	_last_refreshed_body_count = 0


func refresh(reason: StringName = REASON_MANUAL) -> void:
	_focus_id = StringName("") if _bubble == null else _bubble.get_focus()
	var effective_interest: Dictionary = _effective_interest_set()
	if reason == REASON_MANUAL or reason == REASON_CONFIGURE or reason == REASON_WORLD_RELOAD:
		_dirty_all_interest = true
	if _dirty_all_interest:
		for id in effective_interest.keys():
			_dirty_interest_ids[id] = true
	if _focus_id != StringName(""):
		_dirty_interest_ids[_focus_id] = true

	_last_refreshed_body_count = 0
	for id_variant in _dirty_interest_ids.keys():
		var id: StringName = id_variant
		if not effective_interest.has(id):
			continue
		if _registry == null or not _registry.has_body(id):
			_thermal_desc_by_id.erase(id)
			_environment_desc_by_id.erase(id)
			continue
		_thermal_desc_by_id[id] = _thermal_service.describe_body(id)
		_environment_desc_by_id[id] = _environment_service.describe_body(id)
		_last_refreshed_body_count += 1

	_prune_uninterested_entries(effective_interest)
	_focus_thermal_desc = _thermal_desc_by_id.get(_focus_id, {})
	_focus_environment_desc = _environment_desc_by_id.get(_focus_id, {})
	_dirty_interest_ids.clear()
	_dirty_all_interest = false
	_revision += 1
	_last_refresh_reason = reason
	snapshot_refreshed.emit(reason)


func set_interest_ids(ids: Array[StringName]) -> void:
	var new_interest: Dictionary = {}
	for id in ids:
		if id != StringName(""):
			new_interest[id] = true
	if _dictionaries_have_same_keys(_explicit_interest_ids, new_interest):
		return
	var previous_interest: Dictionary = _explicit_interest_ids.duplicate()
	_explicit_interest_ids = new_interest
	for id in _explicit_interest_ids.keys():
		if not previous_interest.has(id):
			_dirty_interest_ids[id] = true
	_dirty_all_interest = true
	refresh(REASON_INTEREST_CHANGED)


func get_revision() -> int:
	return _revision


func get_last_refresh_reason() -> StringName:
	return _last_refresh_reason


func get_last_refreshed_body_count() -> int:
	return _last_refreshed_body_count


func get_focus_id() -> StringName:
	return _focus_id


func get_focus_thermal_desc() -> Dictionary:
	return _focus_thermal_desc


func get_focus_environment_desc() -> Dictionary:
	return _focus_environment_desc


func get_thermal_desc(id: StringName) -> Dictionary:
	return _thermal_desc_by_id.get(id, {})


func get_environment_desc(id: StringName) -> Dictionary:
	return _environment_desc_by_id.get(id, {})


func _effective_interest_set() -> Dictionary:
	var out: Dictionary = _explicit_interest_ids.duplicate()
	if _focus_id != StringName(""):
		out[_focus_id] = true
	return out


func _prune_uninterested_entries(effective_interest: Dictionary) -> void:
	for id in _thermal_desc_by_id.keys():
		if not effective_interest.has(id):
			_thermal_desc_by_id.erase(id)
	for id in _environment_desc_by_id.keys():
		if not effective_interest.has(id):
			_environment_desc_by_id.erase(id)


func _on_bodies_updated(ids: Array[StringName], reason: StringName) -> void:
	_mark_affected_interest_ids_dirty(ids)
	if _dirty_interest_ids.is_empty():
		return
	var refresh_reason: StringName = REASON_SIM_TICK if reason == StringName("") else reason
	refresh(refresh_reason)


func _on_sim_tick_fallback(_dt: float) -> void:
	var effective_interest: Dictionary = _effective_interest_set()
	for id in effective_interest.keys():
		_dirty_interest_ids[id] = true
	refresh(REASON_SIM_TICK)


func _on_focus_changed(_new_focus_id: StringName) -> void:
	_dirty_interest_ids[_new_focus_id] = true
	refresh(REASON_FOCUS_CHANGED)


func _on_world_loaded(_world_id: StringName) -> void:
	_dirty_all_interest = true
	refresh(REASON_WORLD_RELOAD)


func _mark_affected_interest_ids_dirty(ids: Array[StringName]) -> void:
	if _registry == null:
		return
	var dirty_lookup: Dictionary = {}
	for id in ids:
		if id != StringName(""):
			dirty_lookup[id] = true
	if dirty_lookup.is_empty():
		return
	var effective_interest: Dictionary = _effective_interest_set()
	for interest_id_variant in effective_interest.keys():
		var interest_id: StringName = interest_id_variant
		if _depends_on_dirty_body(interest_id, dirty_lookup):
			_dirty_interest_ids[interest_id] = true


func _depends_on_dirty_body(id: StringName, dirty_lookup: Dictionary) -> bool:
	var cursor: StringName = id
	var hop_limit: int = 64
	while cursor != StringName("") and hop_limit > 0:
		if dirty_lookup.has(cursor):
			return true
		var def: BodyDef = _registry.get_def(cursor)
		if def == null:
			return false
		cursor = def.parent_id
		hop_limit -= 1
	return false


static func _dictionaries_have_same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key):
			return false
	return true
