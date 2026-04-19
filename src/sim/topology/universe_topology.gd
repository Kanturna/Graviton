class_name UniverseTopology
extends RefCounted


const _HOP_LIMIT: int = 64

var _registry: Node = null


func configure(registry: Node) -> void:
	assert(registry != null, "UniverseTopology.configure: registry is null")
	_registry = registry


func root_id_of(id: StringName) -> StringName:
	if _registry == null or id == StringName(""):
		return StringName("")

	var cursor: StringName = id
	var hop_limit: int = _HOP_LIMIT
	while cursor != StringName("") and hop_limit > 0:
		var def: BodyDef = _registry.get_def(cursor)
		if def == null:
			return StringName("")
		if def.is_root():
			return cursor
		cursor = def.parent_id
		hop_limit -= 1
	return StringName("")


func ancestor_path_root_to_leaf(id: StringName) -> Array[StringName]:
	if _registry == null or id == StringName(""):
		return []

	var path: Array[StringName] = []
	var cursor: StringName = id
	var hop_limit: int = _HOP_LIMIT
	while cursor != StringName("") and hop_limit > 0:
		var def: BodyDef = _registry.get_def(cursor)
		if def == null:
			return []
		path.append(cursor)
		cursor = def.parent_id
		hop_limit -= 1

	if cursor != StringName(""):
		return []

	path.reverse()
	return path


func lowest_common_ancestor(a_id: StringName, b_id: StringName) -> StringName:
	var a: Array[StringName] = ancestor_path_root_to_leaf(a_id)
	var b: Array[StringName] = ancestor_path_root_to_leaf(b_id)
	if a.is_empty() or b.is_empty():
		return StringName("")

	var limit: int = mini(a.size(), b.size())
	var last_common: StringName = &""
	for idx in range(limit):
		if a[idx] != b[idx]:
			break
		last_common = a[idx]
	return last_common


func is_descendant_of(candidate_id: StringName, ancestor_id: StringName) -> bool:
	if _registry == null or candidate_id == ancestor_id or ancestor_id == StringName(""):
		return false

	var cursor: StringName = candidate_id
	var hop_limit: int = _HOP_LIMIT
	while cursor != StringName("") and hop_limit > 0:
		var def: BodyDef = _registry.get_def(cursor)
		if def == null:
			return false
		cursor = def.parent_id
		if cursor == ancestor_id:
			return true
		hop_limit -= 1
	return false


func descendants_of(root_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if _registry == null or root_id == StringName(""):
		return out

	for id in _registry.get_update_order():
		if is_descendant_of(id, root_id):
			out.append(id)
	return out
