class_name GalaxyStreamingController
extends RefCounted


signal residency_changed(resident_root_ids: Array[StringName], focus_root_id: StringName)

var neighbor_enter_zoom: float = 0.55
var neighbor_exit_zoom: float = 0.65
var prewarm_enter_zoom: float = 0.90
var prewarm_exit_zoom: float = 1.00
var neighbor_unload_keepalive_s: float = 1.5

var _galaxy = null
var _world_loader = null
var _registry: Node = null
var _time_service: Node = null
var _orbit_service = null

var _focus_root_id: StringName = &""
var _resident_root_ids: Array[StringName] = []
var _resident_neighbor_root_id: StringName = &""
var _neighbor_unload_remaining_s: float = 0.0
var _prewarm_root_id: StringName = &""
var _prewarmed_defs_by_root: Dictionary = {}
var _last_zoom_factor: float = 1.0


func configure(
		galaxy,
		world_loader,
		registry: Node,
		time_service: Node,
		orbit_service
	) -> void:
	assert(galaxy != null, "GalaxyStreamingController.configure: galaxy is null")
	assert(world_loader != null, "GalaxyStreamingController.configure: world_loader is null")
	assert(registry != null, "GalaxyStreamingController.configure: registry is null")
	assert(time_service != null, "GalaxyStreamingController.configure: time_service is null")
	assert(orbit_service != null, "GalaxyStreamingController.configure: orbit_service is null")
	_galaxy = galaxy
	_world_loader = world_loader
	_registry = registry
	_time_service = time_service
	_orbit_service = orbit_service
	_focus_root_id = galaxy.focus_root_id
	_last_zoom_factor = 1.0
	_resident_neighbor_root_id = StringName("")
	_neighbor_unload_remaining_s = 0.0
	_update_residency_state(0.0, _last_zoom_factor)
	_update_prewarm_state(_focus_root_id, _last_zoom_factor)


func update(delta_s: float, zoom_factor: float) -> void:
	if _galaxy == null:
		return
	_last_zoom_factor = zoom_factor
	_update_residency_state(delta_s, zoom_factor)
	_update_prewarm_state(_focus_root_id, zoom_factor)


func set_focus_root(root_id: StringName) -> void:
	if _galaxy == null or root_id == StringName("") or root_id == _focus_root_id:
		return
	if _galaxy.get_manifest(root_id) == null:
		return
	var previous_focus_root_id: StringName = _focus_root_id
	_focus_root_id = root_id
	_resident_neighbor_root_id = previous_focus_root_id if previous_focus_root_id != StringName("") and previous_focus_root_id != _focus_root_id else StringName("")
	_neighbor_unload_remaining_s = 0.0
	_update_residency_state(0.0, _last_zoom_factor)
	_update_prewarm_state(_focus_root_id, _last_zoom_factor)


func get_galaxy():
	return _galaxy


func get_focus_root_id() -> StringName:
	return _focus_root_id


func get_resident_root_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(_resident_root_ids)
	return out


func get_prewarm_root_id() -> StringName:
	return _prewarm_root_id


func get_focus_manifest():
	return null if _galaxy == null else _galaxy.get_manifest(_focus_root_id)


func _update_residency_state(delta_s: float, zoom_factor: float) -> void:
	var desired_neighbor_id: StringName = _desired_neighbor_root_id(_focus_root_id)
	var clamped_delta_s: float = maxf(delta_s, 0.0)
	if _resident_neighbor_root_id != StringName(""):
		if _resident_neighbor_root_id == _focus_root_id:
			_resident_neighbor_root_id = StringName("")
			_neighbor_unload_remaining_s = 0.0
		elif _neighbor_still_qualified(_resident_neighbor_root_id, desired_neighbor_id, zoom_factor):
			_neighbor_unload_remaining_s = 0.0
		else:
			if _neighbor_unload_remaining_s <= 0.0:
				_neighbor_unload_remaining_s = neighbor_unload_keepalive_s
			_neighbor_unload_remaining_s = maxf(_neighbor_unload_remaining_s - clamped_delta_s, 0.0)
			if _neighbor_unload_remaining_s <= 0.0:
				_resident_neighbor_root_id = StringName("")

	if _resident_neighbor_root_id == StringName("") and zoom_factor <= neighbor_enter_zoom and desired_neighbor_id != StringName(""):
		_resident_neighbor_root_id = desired_neighbor_id
		_neighbor_unload_remaining_s = 0.0

	_apply_residency(_target_resident_roots_from_state())


func _apply_residency(target_root_ids: Array[StringName]) -> void:
	if _same_root_id_lists(_resident_root_ids, target_root_ids):
		return
	var loaded: bool = _world_loader.materialize_galaxy_roots(_galaxy, target_root_ids, _registry, _galaxy.galaxy_id)
	if not loaded:
		push_error("GalaxyStreamingController: failed to materialize roots %s" % str(target_root_ids))
		return
	_orbit_service.recompute_all_at_time(_time_service.sim_time_s)
	_resident_root_ids.clear()
	_resident_root_ids.append_array(target_root_ids)
	residency_changed.emit(get_resident_root_ids(), _focus_root_id)


func _update_prewarm_state(focus_root_id: StringName, zoom_factor: float) -> void:
	if _galaxy == null:
		_prewarm_root_id = StringName("")
		return
	var candidate_id: StringName = _next_prewarm_candidate_id(focus_root_id)
	if _prewarm_root_id != StringName(""):
		if zoom_factor >= prewarm_exit_zoom or candidate_id == StringName(""):
			_prewarm_root_id = StringName("")
			return
		_prewarm_root_id = candidate_id
		_ensure_prewarmed(candidate_id)
		return
	_prewarm_root_id = StringName("")
	if zoom_factor > prewarm_enter_zoom or candidate_id == StringName(""):
		return
	_prewarm_root_id = candidate_id
	_ensure_prewarmed(candidate_id)


func _ensure_prewarmed(root_id: StringName) -> void:
	if root_id == StringName("") or _prewarmed_defs_by_root.has(root_id):
		return
	var manifest = _galaxy.get_manifest(root_id)
	if manifest != null:
		_prewarmed_defs_by_root[root_id] = _world_loader.build_defs_for_root_manifest(manifest)


func _target_resident_roots_from_state() -> Array[StringName]:
	var out: Array[StringName] = []
	if _focus_root_id == StringName(""):
		return out
	out.append(_focus_root_id)
	if _resident_neighbor_root_id != StringName("") and _resident_neighbor_root_id != _focus_root_id:
		out.append(_resident_neighbor_root_id)
	return out


func _desired_neighbor_root_id(focus_root_id: StringName) -> StringName:
	var neighbors: Array[StringName] = _sorted_neighbor_root_ids(focus_root_id)
	return StringName("") if neighbors.is_empty() else neighbors[0]


func _next_prewarm_candidate_id(focus_root_id: StringName) -> StringName:
	for candidate_id in _sorted_neighbor_root_ids(focus_root_id):
		if _resident_root_ids.has(candidate_id):
			continue
		return candidate_id
	return StringName("")


func _neighbor_still_qualified(current_neighbor_id: StringName, desired_neighbor_id: StringName, zoom_factor: float) -> bool:
	if current_neighbor_id == StringName("") or desired_neighbor_id == StringName(""):
		return false
	if current_neighbor_id != desired_neighbor_id:
		return false
	return zoom_factor < neighbor_exit_zoom


func _sorted_neighbor_root_ids(root_id: StringName) -> Array[StringName]:
	var focus_manifest = _galaxy.get_manifest(root_id)
	var entries: Array = []
	if focus_manifest == null:
		return []
	for manifest in _galaxy.manifests:
		if manifest == null or manifest.root_id == root_id:
			continue
		entries.append({
			"root_id": manifest.root_id,
			"distance_sq": focus_manifest.galaxy_position_m.distance_squared_to(manifest.galaxy_position_m),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance_sq", INF)) < float(b.get("distance_sq", INF))
	)
	var out: Array[StringName] = []
	for entry in entries:
		out.append(entry.get("root_id", StringName("")))
	return out


static func _same_root_id_lists(a: Array[StringName], b: Array[StringName]) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if a[index] != b[index]:
			return false
	return true
