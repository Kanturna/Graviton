class_name BubbleActivationSet
extends Node

# ABGELEITETE Runtime-Klassifikationsebene.
#
# Bestimmt, welche Bodies im fokus-relativen View-Space geometrisch
# lokal relevant sind. "Lokal relevant" bedeutet: View-Distanz zum
# Fokus <= activation_radius_m.
#
# Wichtige Semantik:
#   - Fokus (View-Ankerpunkt) != Aktiv-Set (Relevanzmenge).
#     Der Fokus-Body ist automatisch aktiv (Distanz = 0), aber
#     Fokus und Aktiv-Set sind orthogonale Konzepte.
#   - Das Aktiv-Set ist immer abgeleitet — niemals autoritativ gesetzt.
#   - Kein Schreiben von BodyState oder OrbitMode. Das ist Schritt 4.
#
# Klassifikationsgründe:
#   ACTIVE            — fokus-relativ erreichbar, innerhalb Radius
#   INACTIVE_DISTANT  — fokus-relativ erreichbar, außerhalb Radius
#   INACTIVE_NO_LCA   — nicht fokus-relativ vergleichbar (anderer Baum)
#
# Rebuild-Strategie (bewusste Übergangslösung für kleines N):
#   - Auto-Rebuild bei LocalBubbleManager.focus_changed
#   - Explizites rebuild() vom Testbed aus _process
#   Für größere Body-Mengen oder echte Aktivierungsereignisse wird
#   ein signal-basierter oder tick-getriebener Ansatz nötig.

signal active_set_changed(active_ids: Array[StringName])

enum ActivationStatus {
	ACTIVE,
	INACTIVE_DISTANT,
	INACTIVE_NO_LCA,
}

const DEFAULT_ACTIVATION_RADIUS_M: float = 5.0e8

var _registry: Node = null
var _bubble: Node = null
var _activation_radius_m: float = DEFAULT_ACTIVATION_RADIUS_M

# StringName -> ActivationStatus
var _status_map: Dictionary = {}
var _active_ids: Array[StringName] = []


func configure(registry: Node, bubble: Node) -> void:
	assert(registry != null, "BubbleActivationSet.configure: registry is null")
	assert(bubble != null, "BubbleActivationSet.configure: bubble is null")
	_registry = registry
	_bubble = bubble
	if not _bubble.focus_changed.is_connected(_on_focus_changed):
		_bubble.focus_changed.connect(_on_focus_changed)


func _exit_tree() -> void:
	if _bubble != null and _bubble.focus_changed.is_connected(_on_focus_changed):
		_bubble.focus_changed.disconnect(_on_focus_changed)


func set_activation_radius_m(radius_m: float) -> void:
	_activation_radius_m = radius_m
	rebuild()


func get_activation_radius_m() -> float:
	return _activation_radius_m


# Berechnet das Aktiv-Set neu aus dem aktuellen View-Space.
# Aufrufer: Testbed._process (explizit) und _on_focus_changed (auto).
func rebuild() -> void:
	if _registry == null or _bubble == null:
		return
	var focus_id: StringName = _bubble.get_focus()
	_status_map.clear()
	_active_ids.clear()
	if focus_id == &"":
		push_warning("BubbleActivationSet.rebuild: kein Fokus gesetzt — Aktiv-Set leer")
		active_set_changed.emit(_active_ids.duplicate())
		return
	for id in _registry.get_update_order():
		var view_m: Vector3 = _bubble.compose_view_position_m(id)
		var status: ActivationStatus
		if is_inf(view_m.x):
			status = ActivationStatus.INACTIVE_NO_LCA
		elif view_m.length() <= _activation_radius_m:
			status = ActivationStatus.ACTIVE
			_active_ids.append(id)
		else:
			status = ActivationStatus.INACTIVE_DISTANT
		_status_map[id] = status
	active_set_changed.emit(_active_ids.duplicate())


func is_active(id: StringName) -> bool:
	return _status_map.get(id, ActivationStatus.INACTIVE_DISTANT) == ActivationStatus.ACTIVE


func get_active_ids() -> Array[StringName]:
	return _active_ids.duplicate()


# Klassifikationsgrund eines Bodies.
func get_status(id: StringName) -> ActivationStatus:
	return _status_map.get(id, ActivationStatus.INACTIVE_DISTANT)


func describe() -> String:
	if _registry == null or _bubble == null:
		return "BubbleActivationSet: nicht konfiguriert"
	var focus_id: StringName = _bubble.get_focus()
	if focus_id == &"":
		return "BubbleActivationSet: kein Fokus — kein gueltiges Aktiv-Set"
	var total: int = _status_map.size()
	var active_count: int = _active_ids.size()
	var active_list: PackedStringArray = PackedStringArray()
	for id in _active_ids:
		if id == focus_id:
			active_list.append("%s(FOKUS)" % str(id))
		else:
			active_list.append(str(id))
	var no_lca_list: PackedStringArray = PackedStringArray()
	for id in _status_map.keys():
		if _status_map[id] == ActivationStatus.INACTIVE_NO_LCA:
			no_lca_list.append(str(id))
	var result: String = "radius=%.3e m | active=%d/%d [%s]" % [
		_activation_radius_m,
		active_count,
		total,
		", ".join(active_list),
	]
	if no_lca_list.size() > 0:
		result += " | kein-LCA: [%s]" % ", ".join(no_lca_list)
	return result


func _on_focus_changed(_new_id: StringName) -> void:
	rebuild()
