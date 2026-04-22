class_name GalaxyDef
extends RefCounted


var galaxy_id: StringName = &""
var display_name: String = ""
var focus_root_id: StringName = &""
var manifests: Array = []
var default_resident_root_ids: Array[StringName] = []
var _sorted_neighbor_root_ids_by_root: Dictionary = {}


func get_manifest(root_id: StringName):
	for manifest in manifests:
		if manifest != null and manifest.root_id == root_id:
			return manifest
	return null


func root_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for manifest in manifests:
		if manifest != null:
			out.append(manifest.root_id)
	return out


func sorted_neighbor_root_ids(root_id: StringName) -> Array[StringName]:
	if root_id == StringName(""):
		return []
	if not _sorted_neighbor_root_ids_by_root.has(root_id):
		_sorted_neighbor_root_ids_by_root[root_id] = _build_sorted_neighbor_root_ids(root_id)
	var cached_ids: Array[StringName] = _sorted_neighbor_root_ids_by_root.get(root_id, [])
	var out: Array[StringName] = []
	out.append_array(cached_ids)
	return out


func neighbor_order_cache_size() -> int:
	return _sorted_neighbor_root_ids_by_root.size()


func _build_sorted_neighbor_root_ids(root_id: StringName) -> Array[StringName]:
	var focus_manifest = get_manifest(root_id)
	if focus_manifest == null:
		return []
	var entries: Array = []
	for manifest in manifests:
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
