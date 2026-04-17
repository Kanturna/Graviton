class_name BubbleActivationSet
extends Node

# Read-only Relevanzklassifikation relativ zum aktuellen Bubble-Fokus.
# Diese Klasse leitet Aktivierungszustand ausschliesslich aus der letzten
# Bubble/View-Projektion ab und schreibt niemals BodyState-Felder.

enum State {
	ACTIVE,
	INACTIVE_DISTANT,
	INACTIVE_NO_LCA,
}

@export_range(0.0, 1.0e13, 1.0e7, "or_greater") var activation_radius_m: float = 5.0e8

var _registry: Node = null
var _bubble: LocalBubbleManager = null
var _state_by_id: Dictionary = {}
var _active_ids: Array[StringName] = []
var _active_count: int = 0
var _inactive_distant_count: int = 0
var _inactive_no_lca_count: int = 0


func configure(registry: Node, bubble: LocalBubbleManager) -> void:
	assert(registry != null, "BubbleActivationSet.configure: registry is null")
	assert(bubble != null, "BubbleActivationSet.configure: bubble is null")
	_disconnect_bubble()
	_registry = registry
	_bubble = bubble
	if not _bubble.focus_changed.is_connected(_on_bubble_focus_changed):
		_bubble.focus_changed.connect(_on_bubble_focus_changed)


func rebuild() -> void:
	_state_by_id.clear()
	_active_ids.clear()
	_active_count = 0
	_inactive_distant_count = 0
	_inactive_no_lca_count = 0

	if _registry == null or _bubble == null:
		return

	for id in _registry.get_update_order():
		var view_pos_m: Vector3 = _bubble.compose_view_position_m(id)
		var state: int = _classify_from_view_position(view_pos_m)
		_state_by_id[id] = state
		match state:
			State.ACTIVE:
				_active_ids.append(id)
				_active_count += 1
			State.INACTIVE_DISTANT:
				_inactive_distant_count += 1
			State.INACTIVE_NO_LCA:
				_inactive_no_lca_count += 1


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
		"focus_id": StringName("") if _bubble == null else _bubble.get_focus(),
		"activation_radius_m": activation_radius_m,
		"active_count": _active_count,
		"inactive_distant_count": _inactive_distant_count,
		"inactive_no_lca_count": _inactive_no_lca_count,
	}


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
	_disconnect_bubble()


func _on_bubble_focus_changed(_new_id: StringName) -> void:
	rebuild()


func _disconnect_bubble() -> void:
	if _bubble == null:
		return
	if _bubble.focus_changed.is_connected(_on_bubble_focus_changed):
		_bubble.focus_changed.disconnect(_on_bubble_focus_changed)


func _classify_from_view_position(view_pos_m: Vector3) -> int:
	if not _is_finite_vec3(view_pos_m):
		return State.INACTIVE_NO_LCA
	if view_pos_m.length() <= activation_radius_m:
		return State.ACTIVE
	return State.INACTIVE_DISTANT


static func _is_finite_vec3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
