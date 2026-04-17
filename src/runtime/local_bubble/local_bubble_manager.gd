class_name LocalBubbleManager
extends Node

# ABGELEITETE Darstellungs-/Lokalisierungsebene.
#
# Wichtige Klarstellung zur Semantik:
#   Die kanonische Wahrheit ueber Koerperpositionen liegt in
#   BodyState.position_parent_frame_m. Dieser Dienst besitzt KEINE
#   autoritativen Zustaende ueber Koerper - er leitet View-Koordinaten
#   aus den Parent-Frame-Wahrheiten ab.
#
# AKTUELLER STAND (Step 2):
#   compose_view_position_m() komponiert fokus-relative Positionen via
#   Lowest Common Ancestor (LCA). Parent-Frame-Ketten werden dabei als
#   drei einzelne float-Werte akkumuliert, damit lokale Deltas bei
#   grossen Root-Abstaenden nicht durch Vector3-Cancellation verloren
#   gehen.
#
#   Bodies ohne gemeinsamen Root mit dem aktuellen Fokus liefern
#   Vector3.INF als bewusstes "in diesem Frame nicht lokalisierbar".
#   Die root-lokale Hilfsfunktion compose_root_local_position_m() ist
#   nur fuer Tests und Debug vorgesehen.

signal focus_changed(new_id: StringName)

const _HOP_LIMIT: int = 64

var _registry: Node = null
var _focus_id: StringName = &""
var _reported_issues: Dictionary = {}


func configure(registry: Node) -> void:
	assert(registry != null, "LocalBubbleManager.configure: registry is null")
	_registry = registry


func set_focus(body_id: StringName) -> void:
	if body_id == _focus_id:
		return
	_focus_id = body_id
	_reported_issues.clear()
	focus_changed.emit(body_id)


func get_focus() -> StringName:
	return _focus_id


# Root-lokale Debug-Hilfe.
# Komponiert Parent-Frame-Offsets bis zum lokalen Root, ist aber nie
# root-uebergreifend vergleichbar und darf nicht im Render-Pfad landen.
func compose_root_local_position_m(id: StringName) -> Vector3:
	if _registry == null:
		_warn_once("bubble_registry_missing_root_local", "compose_root_local_position_m ohne Registry-Konfiguration aufgerufen")
		return Vector3.INF
	var accum: Dictionary = _accumulate_to_ancestor_exclusive(id, &"")
	if not bool(accum.get("ok", false)):
		return Vector3.INF
	return Vector3(
		float(accum.get("x", 0.0)),
		float(accum.get("y", 0.0)),
		float(accum.get("z", 0.0))
	)


# Komfort: komplette Pipeline id -> view_m.
# Rueckgabe ist fokus-relativ, kanonisch im gemeinsamen LCA-Frame.
# Ohne Fokus oder ohne gemeinsamen Root wird bewusst Vector3.INF
# geliefert, damit solche Pfade nicht still plausibel aussehen.
func compose_view_position_m(id: StringName) -> Vector3:
	if _registry == null:
		_warn_once("bubble_registry_missing_view", "compose_view_position_m ohne Registry-Konfiguration aufgerufen")
		return Vector3.INF
	if _focus_id == StringName(""):
		_warn_once("bubble_focus_missing", "compose_view_position_m aufgerufen, bevor ein Fokus gesetzt wurde")
		return Vector3.INF
	if not _registry.has_body(_focus_id):
		_warn_once("bubble_focus_invalid:%s" % String(_focus_id),
			"compose_view_position_m: Fokus '%s' existiert nicht in der Registry" % String(_focus_id))
		return Vector3.INF
	if not _registry.has_body(id):
		_warn_once("bubble_target_invalid:%s" % String(id),
			"compose_view_position_m: Target '%s' existiert nicht in der Registry" % String(id))
		return Vector3.INF

	var focus_path: Array[StringName] = _ancestor_path_root_to_leaf(_focus_id)
	var target_path: Array[StringName] = _ancestor_path_root_to_leaf(id)
	if focus_path.is_empty() or target_path.is_empty():
		return Vector3.INF

	var lca_id: StringName = _find_lowest_common_ancestor(focus_path, target_path)
	if lca_id == StringName(""):
		_warn_once(
			"bubble_no_lca:%s->%s" % [String(_focus_id), String(id)],
			"compose_view_position_m: kein gemeinsamer Root/LCA fuer Fokus '%s' und Target '%s'"
				% [String(_focus_id), String(id)],
			true
		)
		return Vector3.INF

	var target_offset: Dictionary = _accumulate_to_ancestor_exclusive(id, lca_id)
	var focus_offset: Dictionary = _accumulate_to_ancestor_exclusive(_focus_id, lca_id)
	if not bool(target_offset.get("ok", false)) or not bool(focus_offset.get("ok", false)):
		return Vector3.INF

	return Vector3(
		float(target_offset.get("x", 0.0)) - float(focus_offset.get("x", 0.0)),
		float(target_offset.get("y", 0.0)) - float(focus_offset.get("y", 0.0)),
		float(target_offset.get("z", 0.0)) - float(focus_offset.get("z", 0.0))
	)


func _ancestor_path_root_to_leaf(id: StringName) -> Array[StringName]:
	var path: Array[StringName] = []
	var cursor: StringName = id
	var hop_limit: int = _HOP_LIMIT
	while cursor != StringName("") and hop_limit > 0:
		var state: BodyState = _registry.get_state(cursor)
		if state == null:
			_warn_once("bubble_missing_state_path:%s" % String(id),
				"_ancestor_path_root_to_leaf: fehlender BodyState fuer '%s'" % String(cursor))
			return []
		path.append(cursor)
		cursor = state.parent_id
		hop_limit -= 1

	if cursor != StringName(""):
		_warn_once("bubble_hop_limit_path:%s" % String(id),
			"_ancestor_path_root_to_leaf: Hop-Limit bei '%s' erreicht" % String(id),
			true
		)
		return []

	path.reverse()
	return path


func _find_lowest_common_ancestor(a: Array[StringName], b: Array[StringName]) -> StringName:
	var limit: int = mini(a.size(), b.size())
	var last_common: StringName = &""
	for idx in range(limit):
		if a[idx] != b[idx]:
			break
		last_common = a[idx]
	return last_common


func _accumulate_to_ancestor_exclusive(from_id: StringName, stop_id: StringName) -> Dictionary:
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var cursor: StringName = from_id
	var hop_limit: int = _HOP_LIMIT

	while cursor != StringName("") and cursor != stop_id and hop_limit > 0:
		var state: BodyState = _registry.get_state(cursor)
		if state == null:
			_warn_once(
				"bubble_missing_state_acc:%s->%s" % [String(from_id), String(stop_id)],
				"_accumulate_to_ancestor_exclusive: fehlender BodyState fuer '%s'" % String(cursor)
			)
			return {"ok": false}
		x += float(state.position_parent_frame_m.x)
		y += float(state.position_parent_frame_m.y)
		z += float(state.position_parent_frame_m.z)
		cursor = state.parent_id
		hop_limit -= 1

	if hop_limit <= 0:
		_warn_once(
			"bubble_hop_limit_acc:%s->%s" % [String(from_id), String(stop_id)],
			"_accumulate_to_ancestor_exclusive: Hop-Limit bei '%s' erreicht" % String(from_id),
			true
		)
		return {"ok": false}

	if cursor != stop_id:
		_warn_once(
			"bubble_stop_unreached:%s->%s" % [String(from_id), String(stop_id)],
			"_accumulate_to_ancestor_exclusive: Ancestor '%s' von '%s' nicht erreicht"
				% [String(stop_id), String(from_id)],
			true
		)
		return {"ok": false}

	return {
		"ok": true,
		"x": x,
		"y": y,
		"z": z,
	}


func _warn_once(key: String, message: String, is_error: bool = false) -> void:
	if _reported_issues.has(key):
		return
	_reported_issues[key] = true
	if is_error:
		push_error(message)
	else:
		push_warning(message)
