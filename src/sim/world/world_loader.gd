class_name WorldLoader
extends Node

const STARTER_WORLD_ID: StringName = &"starter_world"
const SAMPLE_SYSTEM_ID: StringName = &"sample_system"


func available_world_ids() -> Array[StringName]:
	return [STARTER_WORLD_ID, SAMPLE_SYSTEM_ID]


# Laedt eine benannte Welt nur dann in die Registry, wenn die Welt-ID bekannt ist
# und die daraus erzeugten Defs die komplette Vorvalidierung bestehen.
# Bei Fehlern bleibt die Registry unveraendert.
func load_named_world(world_id: StringName, registry: Node) -> bool:
	var defs: Array[BodyDef] = []
	match world_id:
		STARTER_WORLD_ID:
			defs = StarterWorld.build()
		SAMPLE_SYSTEM_ID:
			defs = SampleSystem.build()
		_:
			push_error("WorldLoader.load_named_world: unknown world_id '%s'" % world_id)
			return false
	return load_defs_into_registry(defs, registry)


# Mutiert die Registry nur nach vollstaendiger Vorvalidierung.
# Bei Fehlern bleibt der bestehende Registry-Zustand unveraendert.
# Bei Erfolg: registry.clear() + deterministische Registrierung in Array-Reihenfolge.
func load_defs_into_registry(defs: Array[BodyDef], registry: Node) -> bool:
	if registry == null:
		push_error("WorldLoader.load_defs_into_registry: registry is null")
		return false
	if defs.is_empty():
		push_error("WorldLoader.load_defs_into_registry: defs array is empty")
		return false

	var ids_seen: Dictionary = {}
	var order_indices: Dictionary = {}
	for index in range(defs.size()):
		var def: BodyDef = defs[index]
		if def == null:
			push_error("WorldLoader.load_defs_into_registry: def at index %d is null" % index)
			return false
		if not def.is_valid():
			push_error("WorldLoader.load_defs_into_registry: def '%s' is invalid" % def.id)
			return false
		if ids_seen.has(def.id):
			push_error("WorldLoader.load_defs_into_registry: duplicate id '%s'" % def.id)
			return false
		ids_seen[def.id] = true
		order_indices[def.id] = index

	for index in range(defs.size()):
		var def: BodyDef = defs[index]
		if def.parent_id == StringName(""):
			continue
		if def.parent_id == def.id:
			push_error("WorldLoader.load_defs_into_registry: '%s' cannot parent itself" % def.id)
			return false
		if not ids_seen.has(def.parent_id):
			push_error("WorldLoader.load_defs_into_registry: '%s' references missing parent '%s'" % [def.id, def.parent_id])
			return false
		var parent_index: int = int(order_indices[def.parent_id])
		if parent_index >= index:
			push_error("WorldLoader.load_defs_into_registry: parent '%s' must appear before child '%s'" % [def.parent_id, def.id])
			return false

	registry.clear()
	for def in defs:
		registry.register_body(def)
	return true
