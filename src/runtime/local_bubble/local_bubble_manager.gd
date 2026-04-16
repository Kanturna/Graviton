class_name LocalBubbleManager
extends Node

# ABGELEITETE Darstellungs-/Lokalisierungsebene.
#
# Wichtige Klarstellung zur Semantik:
#   Die kanonische Wahrheit ueber Koerperpositionen liegt in
#   BodyState.position_parent_frame_m. Dieser Dienst besitzt KEINE
#   autoritativen Zustaende ueber Koerper — er leitet Darstellungs-
#   koordinaten aus den Parent-Frame-Wahrheiten ab.
#
# Rueckgabewerte heissen bewusst *_view_m oder *_render_units, nicht
# einfach `position`, damit im Code sichtbar bleibt, dass wir View-Space
# beschreiben, nicht Sim-Space.
#
# FOUNDATION-STAND (bewusster Platzhalter):
#   world_to_view_m und view_to_world_m sind Identitaet. Die eigentliche
#   Bubble-Transformation (Focus-Subtraktion + Skalierung zur Wahrung
#   der Render-Praezision ueber grosse Distanzen) ist der NAECHSTE Schritt
#   nach diesem Foundation-Slice.

signal focus_changed(new_id: StringName)

var _registry: Node = null
var _focus_id: StringName = &""


func configure(registry: Node) -> void:
	assert(registry != null, "LocalBubbleManager.configure: registry is null")
	_registry = registry


func set_focus(body_id: StringName) -> void:
	if body_id == _focus_id:
		return
	_focus_id = body_id
	focus_changed.emit(body_id)


func get_focus() -> StringName:
	return _focus_id


# Abgeleitete Welt-Position (komponiert aus Parent-Frame-Ketten).
# Nicht gecached, nicht gespeichert.
func compose_world_position_m(id: StringName) -> Vector3:
	if _registry == null:
		return Vector3.ZERO
	var accum: Vector3 = Vector3.ZERO
	var cursor: StringName = id
	var hop_limit: int = 64
	while cursor != StringName("") and hop_limit > 0:
		var state: BodyState = _registry.get_state(cursor)
		if state == null:
			break
		accum += state.position_parent_frame_m
		cursor = state.parent_id
		hop_limit -= 1
	return accum


# Welt -> View. Foundation-Identity. Interface steht fuer spaeteren Ausbau.
func world_to_view_m(world_m: Vector3) -> Vector3:
	return world_m


func view_to_world_m(view_m: Vector3) -> Vector3:
	return view_m


# Komfort: komplette Pipeline id -> view_m.
func compose_view_position_m(id: StringName) -> Vector3:
	return world_to_view_m(compose_world_position_m(id))
