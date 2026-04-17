extends Node

# Autoload. Schlanker Registry-Dienst.
#
# AUFGABE:
#   - Defs/States/IDs halten
#   - Topologie-Order (Parent vor Kind) bereitstellen
#   - Signale beim Registrieren/Entfernen senden
#
# KEIN SCOPE (bewusst ausgeschlossen, gehoert anderswo hin):
#   - Position/Velocity aktualisieren      -> OrbitService
#   - Kepler-Mathematik                    -> OrbitMath
#   - Welt- oder View-Koordinaten berechnen -> LocalBubbleManager
#   - Zeitfortschritt                      -> TimeService
#
# Diese Trennung ist Architektur, kein Styleguide — bitte erhalten.

signal body_registered(id: StringName)
signal body_unregistered(id: StringName)

var ids: IdRegistry = IdRegistry.new()
var defs_by_id: Dictionary = {}
var states_by_id: Dictionary = {}

var _update_order: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func register_body(def: BodyDef) -> BodyState:
	assert(def != null, "register_body: def is null")
	assert(def.is_valid(), "register_body: def invalid (id=%s)" % def.id)
	assert(not defs_by_id.has(def.id), "register_body: duplicate id %s" % def.id)
	# Diagnostik: Parent zur Zeit der Registrierung noch nicht bekannt.
	# Kein assert — Batch-Registrierung kann valide in Topologie-Reihenfolge laufen.
	if def.parent_id != StringName("") and not defs_by_id.has(def.parent_id):
		push_warning("UniverseRegistry.register_body: parent '%s' noch nicht registriert fuer '%s'" % [def.parent_id, def.id])

	ids.claim_authored(def.id)
	defs_by_id[def.id] = def

	var state := BodyState.new(def.id, def.parent_id)
	if def.orbit_profile != null:
		state.current_mode = def.orbit_profile.mode
	else:
		state.current_mode = OrbitMode.Kind.AUTHORED_ORBIT
	states_by_id[def.id] = state

	_recompute_update_order()
	body_registered.emit(def.id)
	return state


func unregister_body(id: StringName) -> void:
	if not defs_by_id.has(id):
		return
	defs_by_id.erase(id)
	states_by_id.erase(id)
	ids.release(id)
	_recompute_update_order()
	body_unregistered.emit(id)


func get_def(id: StringName) -> BodyDef:
	return defs_by_id.get(id, null) as BodyDef


func get_state(id: StringName) -> BodyState:
	return states_by_id.get(id, null) as BodyState


func get_update_order() -> Array[StringName]:
	return _update_order.duplicate()


func get_children_of(parent: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in defs_by_id.keys():
		var d: BodyDef = defs_by_id[id]
		if d != null and d.parent_id == parent:
			out.append(id)
	return out


func has_body(id: StringName) -> bool:
	return defs_by_id.has(id)


func body_count() -> int:
	return defs_by_id.size()


func clear() -> void:
	var ids_copy: Array = defs_by_id.keys().duplicate()
	defs_by_id.clear()
	states_by_id.clear()
	ids.clear()
	_update_order.clear()
	for id in ids_copy:
		body_unregistered.emit(id)


func load_from_sample_system() -> void:
	if not defs_by_id.is_empty():
		return
	var defs: Array[BodyDef] = SampleSystem.build()
	for d in defs:
		register_body(d)


# Topologischer Sort nach parent_id. Parents landen vor Kindern.
# Wurzeln (parent_id == &"") zuerst. Kleines N, einfache Kahn-Variante.
func _recompute_update_order() -> void:
	var pending: Dictionary = {}
	for id in defs_by_id.keys():
		pending[id] = true

	var order: Array[StringName] = []
	var progress: bool = true
	while progress and not pending.is_empty():
		progress = false
		for id in pending.keys():
			var d: BodyDef = defs_by_id[id]
			var parent: StringName = d.parent_id
			if parent == StringName("") or not pending.has(parent):
				order.append(id)
				pending.erase(id)
				progress = true
	if not pending.is_empty():
		push_error("universe_registry: cyclic or missing parent detected; remaining=%s"
			% str(pending.keys()))
		for id in pending.keys():
			order.append(id)
	_update_order = order
