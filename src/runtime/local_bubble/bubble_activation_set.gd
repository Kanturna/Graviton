class_name BubbleActivationSet
extends Node

# Read-only Relevanzklassifikation relativ zum aktuellen Bubble-Fokus.
# Diese Klasse leitet Aktivierungszustand ausschliesslich aus der letzten
# Bubble/View-Projektion ab und schreibt niemals BodyState-Felder.

const UniverseTopologyScript := preload("res://src/sim/topology/universe_topology.gd")

enum State {
	ACTIVE,
	INACTIVE_DISTANT,
	INACTIVE_NO_LCA,
}

const KEY_FOCUS_ID: StringName = &"focus_id"
const KEY_ACTIVATION_RADIUS_M: StringName = &"activation_radius_m"
const KEY_ACTIVE_COUNT: StringName = &"active_count"
const KEY_INACTIVE_DISTANT_COUNT: StringName = &"inactive_distant_count"
const KEY_INACTIVE_NO_LCA_COUNT: StringName = &"inactive_no_lca_count"

@export_range(0.0, 1.0e13, 1.0e7, "or_greater") var activation_radius_m: float = 5.0e8

var _registry: Node = null
var _bubble: LocalBubbleManager = null
var _topology = null
var _state_by_id: Dictionary = {}
var _active_ids: Array[StringName] = []
var _active_count: int = 0
var _inactive_distant_count: int = 0
var _inactive_no_lca_count: int = 0

var _root_id_by_id: Dictionary = {}
var _ids_by_root: Dictionary = {}
var _children_by_id: Dictionary = {}
var _focus_root_id: StringName = &""
var _same_root_ids: Array[StringName] = []
var _dirty_ids: Dictionary = {}
var _needs_full_rebuild: bool = true

var _last_rebuild_eval_count: int = 0
var _last_rebuild_was_incremental: bool = false


func configure(registry: Node, bubble: LocalBubbleManager) -> void:
	assert(registry != null, "BubbleActivationSet.configure: registry is null")
	assert(bubble != null, "BubbleActivationSet.configure: bubble is null")
	_disconnect_registry()
	_disconnect_bubble()
	_registry = registry
	_bubble = bubble
	_topology = UniverseTopologyScript.new()
	_topology.configure(registry)
	if not _bubble.focus_changed.is_connected(_on_bubble_focus_changed):
		_bubble.focus_changed.connect(_on_bubble_focus_changed)
	if not _registry.body_registered.is_connected(_on_registry_changed):
		_registry.body_registered.connect(_on_registry_changed)
	if not _registry.body_unregistered.is_connected(_on_registry_changed):
		_registry.body_unregistered.connect(_on_registry_changed)
	_mark_full_rebuild()


func rebuild() -> void:
	_last_rebuild_eval_count = 0
	_last_rebuild_was_incremental = false

	if _registry == null or _bubble == null:
		return

	if _needs_full_rebuild:
		_rebuild_topology_cache()
		_rebuild_all()
		return

	if _dirty_ids.is_empty():
		return

	var impacted_ids: Array[StringName] = _collect_impacted_ids()
	_dirty_ids.clear()
	if impacted_ids.is_empty():
		return

	_last_rebuild_was_incremental = true
	for id in impacted_ids:
		_recompute_state_for_id(id)
	_sync_active_ids_from_same_root()


# Rueckgabe folgt der topologischen Registry-Reihenfolge aus
# get_update_order(), also Parent vor Kind.
func get_active_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(_active_ids)
	return out


# Spiegelt ausschliesslich den Zustand des letzten rebuild() wider.
# Seitdem registrierte oder entfernte Bodies werden erst nach dem
# naechsten rebuild() korrekt klassifiziert.
func classify(id: StringName) -> int:
	if not _state_by_id.has(id):
		return State.INACTIVE_NO_LCA
	return int(_state_by_id[id])


func describe() -> Dictionary:
	return {
		KEY_FOCUS_ID: StringName("") if _bubble == null else _bubble.get_focus(),
		KEY_ACTIVATION_RADIUS_M: activation_radius_m,
		KEY_ACTIVE_COUNT: _active_count,
		KEY_INACTIVE_DISTANT_COUNT: _inactive_distant_count,
		KEY_INACTIVE_NO_LCA_COUNT: _inactive_no_lca_count,
	}


func mark_ids_dirty(ids: Array[StringName]) -> void:
	for id in ids:
		if id == StringName(""):
			continue
		_dirty_ids[id] = true


func get_last_rebuild_eval_count() -> int:
	return _last_rebuild_eval_count


func was_last_rebuild_incremental() -> bool:
	return _last_rebuild_was_incremental


static func to_string_state(state: int) -> String:
	match state:
		State.ACTIVE:
			return "ACTIVE"
		State.INACTIVE_DISTANT:
			return "INACTIVE_DISTANT"
		State.INACTIVE_NO_LCA:
			return "INACTIVE_NO_LCA"
		_:
			return "UNKNOWN"


func _exit_tree() -> void:
	_disconnect_registry()
	_disconnect_bubble()


func _on_bubble_focus_changed(_new_id: StringName) -> void:
	_mark_full_rebuild()
	rebuild()


func _on_registry_changed(_id: StringName) -> void:
	_mark_full_rebuild()


func _disconnect_bubble() -> void:
	if _bubble == null:
		return
	if _bubble.focus_changed.is_connected(_on_bubble_focus_changed):
		_bubble.focus_changed.disconnect(_on_bubble_focus_changed)


func _disconnect_registry() -> void:
	if _registry == null:
		return
	if _registry.body_registered.is_connected(_on_registry_changed):
		_registry.body_registered.disconnect(_on_registry_changed)
	if _registry.body_unregistered.is_connected(_on_registry_changed):
		_registry.body_unregistered.disconnect(_on_registry_changed)


func _mark_full_rebuild() -> void:
	_needs_full_rebuild = true
	_dirty_ids.clear()
	_focus_root_id = StringName("")
	_same_root_ids.clear()


func _rebuild_topology_cache() -> void:
	_root_id_by_id.clear()
	_ids_by_root.clear()
	_children_by_id.clear()
	if _registry == null or _topology == null:
		return
	_topology.configure(_registry)
	for id in _registry.get_update_order():
		var root_id: StringName = _topology.root_id_of(id)
		_root_id_by_id[id] = root_id
		if not _ids_by_root.has(root_id):
			_ids_by_root[root_id] = []
		var root_ids: Array = _ids_by_root[root_id]
		root_ids.append(id)
		_ids_by_root[root_id] = root_ids
		var def: BodyDef = _registry.get_def(id)
		if def == null or def.parent_id == StringName(""):
			continue
		if not _children_by_id.has(def.parent_id):
			_children_by_id[def.parent_id] = []
		var child_ids: Array = _children_by_id[def.parent_id]
		child_ids.append(id)
		_children_by_id[def.parent_id] = child_ids


func _rebuild_all() -> void:
	_needs_full_rebuild = false
	_state_by_id.clear()
	_active_ids.clear()
	_active_count = 0
	_inactive_distant_count = 0
	_inactive_no_lca_count = 0

	var focus_id: StringName = _bubble.get_focus()
	if focus_id == StringName("") or not _registry.has_body(focus_id):
		for id in _registry.get_update_order():
			_state_by_id[id] = State.INACTIVE_NO_LCA
		_inactive_no_lca_count = _registry.body_count()
		_focus_root_id = StringName("")
		_same_root_ids.clear()
		_dirty_ids.clear()
		return

	_focus_root_id = _root_id_by_id.get(focus_id, StringName(""))
	_same_root_ids.clear()
	if _ids_by_root.has(_focus_root_id):
		_same_root_ids.append_array(_ids_by_root[_focus_root_id])

	for id in _registry.get_update_order():
		if _root_id_by_id.get(id, StringName("")) != _focus_root_id:
			_state_by_id[id] = State.INACTIVE_NO_LCA
			_inactive_no_lca_count += 1
			continue
		_recompute_state_for_id(id)
	_sync_active_ids_from_same_root()
	_dirty_ids.clear()


func _collect_impacted_ids() -> Array[StringName]:
	var impacted: Dictionary = {}
	if _bubble == null:
		return []
	var focus_id: StringName = _bubble.get_focus()
	if focus_id == StringName("") or _focus_root_id == StringName(""):
		return []

	for dirty_id_variant in _dirty_ids.keys():
		var dirty_id: StringName = dirty_id_variant
		if _root_id_by_id.get(dirty_id, StringName("")) != _focus_root_id:
			continue
		if dirty_id == focus_id or _is_focus_ancestor_dirty(dirty_id, focus_id):
			return _same_root_ids.duplicate()
		_mark_subtree_ids(dirty_id, impacted)

	var out: Array[StringName] = []
	for id in _same_root_ids:
		if impacted.has(id):
			out.append(id)
	return out


func _is_focus_ancestor_dirty(candidate_id: StringName, focus_id: StringName) -> bool:
	if candidate_id == StringName("") or focus_id == StringName("") or _topology == null:
		return false
	return _topology.is_descendant_of(focus_id, candidate_id)


func _mark_subtree_ids(root_id: StringName, out: Dictionary) -> void:
	var stack: Array[StringName] = [root_id]
	while not stack.is_empty():
		var current: StringName = stack.pop_back()
		if out.has(current):
			continue
		out[current] = true
		var children: Array = _children_by_id.get(current, [])
		for child in children:
			stack.append(child)


func _recompute_state_for_id(id: StringName) -> void:
	var new_state: int = State.INACTIVE_NO_LCA
	if _root_id_by_id.get(id, StringName("")) == _focus_root_id:
		var view_pos_m: Vector3 = _bubble.compose_view_position_m(id)
		new_state = _classify_from_view_position(view_pos_m)
		_last_rebuild_eval_count += 1
	_replace_state(id, new_state)


func _replace_state(id: StringName, new_state: int) -> void:
	var old_state: int = int(_state_by_id.get(id, State.INACTIVE_NO_LCA))
	if _state_by_id.has(id) and old_state == new_state:
		return
	if _state_by_id.has(id):
		_adjust_count_for_state(old_state, -1)
	_state_by_id[id] = new_state
	_adjust_count_for_state(new_state, 1)


func _adjust_count_for_state(state: int, delta: int) -> void:
	match state:
		State.ACTIVE:
			_active_count += delta
		State.INACTIVE_DISTANT:
			_inactive_distant_count += delta
		State.INACTIVE_NO_LCA:
			_inactive_no_lca_count += delta


func _sync_active_ids_from_same_root() -> void:
	_active_ids.clear()
	for id in _same_root_ids:
		if int(_state_by_id.get(id, State.INACTIVE_NO_LCA)) == State.ACTIVE:
			_active_ids.append(id)


func _classify_from_view_position(view_pos_m: Vector3) -> int:
	if not _is_finite_vec3(view_pos_m):
		return State.INACTIVE_NO_LCA
	if view_pos_m.length() <= activation_radius_m:
		return State.ACTIVE
	return State.INACTIVE_DISTANT


static func _is_finite_vec3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
