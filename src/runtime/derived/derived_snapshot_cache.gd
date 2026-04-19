class_name DerivedSnapshotCache
extends RefCounted


signal snapshot_refreshed(reason: StringName)

const REASON_CONFIGURE: StringName = &"configure"
const REASON_SIM_TICK: StringName = &"sim_tick"
const REASON_FOCUS_CHANGED: StringName = &"focus_changed"
const REASON_WORLD_RELOAD: StringName = &"world_reload"
const REASON_MANUAL: StringName = &"manual"

var _registry: Node = null
var _time_service: Node = null
var _bubble = null
var _world_loader: Node = null
var _thermal_service: Node = null
var _environment_service: Node = null

var _focus_id: StringName = &""
var _focus_thermal_desc: Dictionary = {}
var _focus_environment_desc: Dictionary = {}
var _thermal_desc_by_id: Dictionary = {}
var _environment_desc_by_id: Dictionary = {}
var _revision: int = 0
var _last_refresh_reason: StringName = REASON_MANUAL


func configure(
		registry: Node,
		time_service: Node,
		bubble,
		world_loader: Node,
		thermal_service: Node,
		environment_service: Node
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
	if not _time_service.sim_tick.is_connected(_on_sim_tick):
		_time_service.sim_tick.connect(_on_sim_tick)
	if not _bubble.focus_changed.is_connected(_on_focus_changed):
		_bubble.focus_changed.connect(_on_focus_changed)
	if not _world_loader.world_loaded.is_connected(_on_world_loaded):
		_world_loader.world_loaded.connect(_on_world_loaded)
	refresh(REASON_CONFIGURE)


func dispose() -> void:
	if _time_service != null and _time_service.sim_tick.is_connected(_on_sim_tick):
		_time_service.sim_tick.disconnect(_on_sim_tick)
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
	_focus_id = StringName("")
	_focus_thermal_desc.clear()
	_focus_environment_desc.clear()
	_thermal_desc_by_id.clear()
	_environment_desc_by_id.clear()


func refresh(reason: StringName = REASON_MANUAL) -> void:
	_thermal_desc_by_id.clear()
	_environment_desc_by_id.clear()
	_focus_thermal_desc = {}
	_focus_environment_desc = {}
	_focus_id = StringName("") if _bubble == null else _bubble.get_focus()

	if _registry != null and _thermal_service != null and _environment_service != null:
		for id in _registry.get_update_order():
			_thermal_desc_by_id[id] = _thermal_service.describe_body(id)
			_environment_desc_by_id[id] = _environment_service.describe_body(id)
		_focus_thermal_desc = _thermal_desc_by_id.get(_focus_id, {})
		_focus_environment_desc = _environment_desc_by_id.get(_focus_id, {})

	_revision += 1
	_last_refresh_reason = reason
	snapshot_refreshed.emit(reason)


func get_revision() -> int:
	return _revision


func get_last_refresh_reason() -> StringName:
	return _last_refresh_reason


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


func _on_sim_tick(_dt: float) -> void:
	refresh(REASON_SIM_TICK)


func _on_focus_changed(_new_focus_id: StringName) -> void:
	refresh(REASON_FOCUS_CHANGED)


func _on_world_loaded(_world_id: StringName) -> void:
	refresh(REASON_WORLD_RELOAD)
