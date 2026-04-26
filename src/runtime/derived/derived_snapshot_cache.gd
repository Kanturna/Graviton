class_name DerivedSnapshotCache
extends RefCounted


signal snapshot_refreshed(reason: StringName)

const REASON_CONFIGURE: StringName = &"configure"
const REASON_SIM_TICK: StringName = &"sim_tick"
const REASON_FOCUS_CHANGED: StringName = &"focus_changed"
const REASON_WORLD_RELOAD: StringName = &"world_reload"
const REASON_MANUAL: StringName = &"manual"
const REASON_INTEREST_CHANGED: StringName = &"interest_changed"
const SIM_TICK_REFRESH_COOLDOWN_USEC: int = 250_000

var _registry: Node = null
var _time_service: Node = null
var _bubble = null
var _world_loader: Node = null
var _thermal_service: Node = null
var _environment_service: Node = null
var _orbit_service: Node = null
var _planetary_state_service: Node = null
var _life_potential_service: Node = null
var _proto_biosphere_service: Node = null
var _biosphere_scale_service: Node = null
var _orbit_readout_service: Node = null
var _native_species_service: Node = null
var _genetic_species_service: Node = null
var _life_ecology_service: Node = null
var _life_population_estimate_service: Node = null

var _focus_id: StringName = &""
var _focus_thermal_desc: Dictionary = {}
var _focus_environment_desc: Dictionary = {}
var _focus_planetary_state_desc: Dictionary = {}
var _focus_life_potential_desc: Dictionary = {}
var _focus_biosphere_desc: Dictionary = {}
var _focus_biosphere_scale_desc: Dictionary = {}
var _focus_orbit_readout_desc: Dictionary = {}
var _focus_native_species_desc: Dictionary = {}
var _focus_genetic_species_desc: Dictionary = {}
var _focus_life_ecology_desc: Dictionary = {}
var _focus_population_estimate_desc: Dictionary = {}
var _thermal_desc_by_id: Dictionary = {}
var _environment_desc_by_id: Dictionary = {}
var _planetary_state_desc_by_id: Dictionary = {}
var _life_potential_desc_by_id: Dictionary = {}
var _biosphere_desc_by_id: Dictionary = {}
var _biosphere_scale_desc_by_id: Dictionary = {}
var _orbit_readout_desc_by_id: Dictionary = {}
var _native_species_desc_by_id: Dictionary = {}
var _genetic_species_desc_by_id: Dictionary = {}
var _life_ecology_desc_by_id: Dictionary = {}
var _population_estimate_desc_by_id: Dictionary = {}
var _explicit_interest_ids: Dictionary = {}
var _dirty_interest_ids: Dictionary = {}
var _dirty_all_interest: bool = true
var _revision: int = 0
var _last_refresh_reason: StringName = REASON_MANUAL
var _last_refreshed_body_count: int = 0
var _last_sim_tick_refresh_usec: int = 0
var _refresh_call_count_total: int = 0
var _refresh_throttled_count: int = 0
var _last_refresh_us: int = 0
var _refresh_total_us: int = 0


func configure(
		registry: Node,
		time_service: Node,
		bubble,
		world_loader: Node,
		thermal_service: Node,
		environment_service: Node,
		orbit_service: Node = null,
		planetary_state_service: Node = null,
		life_potential_service: Node = null,
		proto_biosphere_service: Node = null,
		biosphere_scale_service: Node = null,
		orbit_readout_service: Node = null,
		native_species_service: Node = null,
		genetic_species_service: Node = null,
		life_ecology_service: Node = null,
		life_population_estimate_service: Node = null
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
	_planetary_state_service = planetary_state_service
	_life_potential_service = life_potential_service
	_proto_biosphere_service = proto_biosphere_service
	_biosphere_scale_service = biosphere_scale_service
	_orbit_readout_service = orbit_readout_service
	_native_species_service = native_species_service
	_genetic_species_service = genetic_species_service
	_life_ecology_service = life_ecology_service
	_life_population_estimate_service = life_population_estimate_service
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
	_planetary_state_service = null
	_life_potential_service = null
	_proto_biosphere_service = null
	_biosphere_scale_service = null
	_orbit_readout_service = null
	_native_species_service = null
	_genetic_species_service = null
	_life_ecology_service = null
	_life_population_estimate_service = null
	_focus_id = StringName("")
	_focus_thermal_desc.clear()
	_focus_environment_desc.clear()
	_focus_planetary_state_desc.clear()
	_focus_life_potential_desc.clear()
	_focus_biosphere_desc.clear()
	_focus_biosphere_scale_desc.clear()
	_focus_orbit_readout_desc.clear()
	_focus_native_species_desc.clear()
	_focus_genetic_species_desc.clear()
	_focus_life_ecology_desc.clear()
	_focus_population_estimate_desc.clear()
	_thermal_desc_by_id.clear()
	_environment_desc_by_id.clear()
	_planetary_state_desc_by_id.clear()
	_life_potential_desc_by_id.clear()
	_biosphere_desc_by_id.clear()
	_biosphere_scale_desc_by_id.clear()
	_orbit_readout_desc_by_id.clear()
	_native_species_desc_by_id.clear()
	_genetic_species_desc_by_id.clear()
	_life_ecology_desc_by_id.clear()
	_population_estimate_desc_by_id.clear()
	_explicit_interest_ids.clear()
	_dirty_interest_ids.clear()
	_dirty_all_interest = true
	_last_refreshed_body_count = 0
	_last_sim_tick_refresh_usec = 0
	_refresh_call_count_total = 0
	_refresh_throttled_count = 0
	_last_refresh_us = 0
	_refresh_total_us = 0


func refresh(reason: StringName = REASON_MANUAL) -> void:
	var refresh_start_us: int = Time.get_ticks_usec()
	_refresh_call_count_total += 1
	if reason == REASON_SIM_TICK:
		var now_usec: int = Time.get_ticks_usec()
		if now_usec - _last_sim_tick_refresh_usec < SIM_TICK_REFRESH_COOLDOWN_USEC:
			_refresh_throttled_count += 1
			_record_refresh_elapsed_us(refresh_start_us)
			return
		_last_sim_tick_refresh_usec = now_usec
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
			_planetary_state_desc_by_id.erase(id)
			_life_potential_desc_by_id.erase(id)
			_biosphere_desc_by_id.erase(id)
			_biosphere_scale_desc_by_id.erase(id)
			_orbit_readout_desc_by_id.erase(id)
			_native_species_desc_by_id.erase(id)
			_genetic_species_desc_by_id.erase(id)
			_life_ecology_desc_by_id.erase(id)
			_population_estimate_desc_by_id.erase(id)
			continue
		_thermal_desc_by_id[id] = _thermal_service.describe_body(id)
		_environment_desc_by_id[id] = _environment_service.describe_body(id)
		if _planetary_state_service != null:
			_planetary_state_desc_by_id[id] = _planetary_state_service.describe_body(id)
		else:
			_planetary_state_desc_by_id.erase(id)
		if _life_potential_service != null:
			_life_potential_desc_by_id[id] = _life_potential_service.describe_body(id)
		else:
			_life_potential_desc_by_id.erase(id)
		if _proto_biosphere_service != null:
			_biosphere_desc_by_id[id] = _proto_biosphere_service.describe_body(id)
		else:
			_biosphere_desc_by_id.erase(id)
		if _biosphere_scale_service != null:
			_biosphere_scale_desc_by_id[id] = _biosphere_scale_service.describe_body(id)
		else:
			_biosphere_scale_desc_by_id.erase(id)
		if _orbit_readout_service != null:
			_orbit_readout_desc_by_id[id] = _orbit_readout_service.describe_body(id)
		else:
			_orbit_readout_desc_by_id.erase(id)
		if _native_species_service != null:
			_native_species_desc_by_id[id] = _native_species_service.describe_body(id)
		else:
			_native_species_desc_by_id.erase(id)
		if _genetic_species_service != null:
			_genetic_species_desc_by_id[id] = _genetic_species_service.describe_body(id)
		else:
			_genetic_species_desc_by_id.erase(id)
		if _life_ecology_service != null:
			_life_ecology_desc_by_id[id] = _life_ecology_service.describe_body(id)
		else:
			_life_ecology_desc_by_id.erase(id)
		if _life_population_estimate_service != null:
			_population_estimate_desc_by_id[id] = _life_population_estimate_service.describe_body(id)
		else:
			_population_estimate_desc_by_id.erase(id)
		_last_refreshed_body_count += 1

	_prune_uninterested_entries(effective_interest)
	_focus_thermal_desc = _thermal_desc_by_id.get(_focus_id, {})
	_focus_environment_desc = _environment_desc_by_id.get(_focus_id, {})
	_focus_planetary_state_desc = _planetary_state_desc_by_id.get(_focus_id, {})
	_focus_life_potential_desc = _life_potential_desc_by_id.get(_focus_id, {})
	_focus_biosphere_desc = _biosphere_desc_by_id.get(_focus_id, {})
	_focus_biosphere_scale_desc = _biosphere_scale_desc_by_id.get(_focus_id, {})
	_focus_orbit_readout_desc = _orbit_readout_desc_by_id.get(_focus_id, {})
	_focus_native_species_desc = _native_species_desc_by_id.get(_focus_id, {})
	_focus_genetic_species_desc = _genetic_species_desc_by_id.get(_focus_id, {})
	_focus_life_ecology_desc = _life_ecology_desc_by_id.get(_focus_id, {})
	_focus_population_estimate_desc = _population_estimate_desc_by_id.get(_focus_id, {})
	_dirty_interest_ids.clear()
	_dirty_all_interest = false
	_revision += 1
	_last_refresh_reason = reason
	snapshot_refreshed.emit(reason)
	_record_refresh_elapsed_us(refresh_start_us)


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


func get_refresh_call_count_total() -> int:
	return _refresh_call_count_total


func get_refresh_throttled_count() -> int:
	return _refresh_throttled_count


func get_last_refresh_us() -> int:
	return _last_refresh_us


func get_refresh_total_us() -> int:
	return _refresh_total_us


func get_sim_tick_refresh_cooldown_usec() -> int:
	return SIM_TICK_REFRESH_COOLDOWN_USEC


func get_focus_id() -> StringName:
	return _focus_id


func get_focus_thermal_desc() -> Dictionary:
	return _focus_thermal_desc


func get_focus_environment_desc() -> Dictionary:
	return _focus_environment_desc


func get_focus_planetary_state_desc() -> Dictionary:
	return _focus_planetary_state_desc


func get_focus_life_potential_desc() -> Dictionary:
	return _focus_life_potential_desc


func get_focus_biosphere_desc() -> Dictionary:
	return _focus_biosphere_desc


func get_focus_biosphere_scale_desc() -> Dictionary:
	return _focus_biosphere_scale_desc


func get_focus_orbit_readout_desc() -> Dictionary:
	return _focus_orbit_readout_desc


func get_focus_native_species_desc() -> Dictionary:
	return _focus_native_species_desc


func get_focus_genetic_species_desc() -> Dictionary:
	return _focus_genetic_species_desc


func get_focus_life_ecology_desc() -> Dictionary:
	return _focus_life_ecology_desc


func get_focus_population_estimate_desc() -> Dictionary:
	return _focus_population_estimate_desc


func get_thermal_desc(id: StringName) -> Dictionary:
	return _thermal_desc_by_id.get(id, {})


func get_environment_desc(id: StringName) -> Dictionary:
	return _environment_desc_by_id.get(id, {})


func get_planetary_state_desc(id: StringName) -> Dictionary:
	return _planetary_state_desc_by_id.get(id, {})


func get_life_potential_desc(id: StringName) -> Dictionary:
	return _life_potential_desc_by_id.get(id, {})


func get_biosphere_desc(id: StringName) -> Dictionary:
	return _biosphere_desc_by_id.get(id, {})


func get_biosphere_scale_desc(id: StringName) -> Dictionary:
	return _biosphere_scale_desc_by_id.get(id, {})


func get_orbit_readout_desc(id: StringName) -> Dictionary:
	return _orbit_readout_desc_by_id.get(id, {})


func get_native_species_desc(id: StringName) -> Dictionary:
	return _native_species_desc_by_id.get(id, {})


func get_genetic_species_desc(id: StringName) -> Dictionary:
	return _genetic_species_desc_by_id.get(id, {})


func get_life_ecology_desc(id: StringName) -> Dictionary:
	return _life_ecology_desc_by_id.get(id, {})


func get_population_estimate_desc(id: StringName) -> Dictionary:
	return _population_estimate_desc_by_id.get(id, {})


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
	for id in _planetary_state_desc_by_id.keys():
		if not effective_interest.has(id):
			_planetary_state_desc_by_id.erase(id)
	for id in _life_potential_desc_by_id.keys():
		if not effective_interest.has(id):
			_life_potential_desc_by_id.erase(id)
	for id in _biosphere_desc_by_id.keys():
		if not effective_interest.has(id):
			_biosphere_desc_by_id.erase(id)
	for id in _biosphere_scale_desc_by_id.keys():
		if not effective_interest.has(id):
			_biosphere_scale_desc_by_id.erase(id)
	for id in _orbit_readout_desc_by_id.keys():
		if not effective_interest.has(id):
			_orbit_readout_desc_by_id.erase(id)
	for id in _native_species_desc_by_id.keys():
		if not effective_interest.has(id):
			_native_species_desc_by_id.erase(id)
	for id in _genetic_species_desc_by_id.keys():
		if not effective_interest.has(id):
			_genetic_species_desc_by_id.erase(id)
	for id in _life_ecology_desc_by_id.keys():
		if not effective_interest.has(id):
			_life_ecology_desc_by_id.erase(id)
	for id in _population_estimate_desc_by_id.keys():
		if not effective_interest.has(id):
			_population_estimate_desc_by_id.erase(id)


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
	_last_sim_tick_refresh_usec = 0
	refresh(REASON_WORLD_RELOAD)


func _record_refresh_elapsed_us(start_us: int) -> void:
	_last_refresh_us = maxi(Time.get_ticks_usec() - start_us, 0)
	_refresh_total_us += _last_refresh_us


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
