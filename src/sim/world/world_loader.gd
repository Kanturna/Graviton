class_name WorldLoader
extends Node

const StarterWorldScript = preload("res://data/starter_world.gd")
const SampleSystemScript = preload("res://data/sample_system.gd")
const DeterministicWorldGeneratorScript = preload("res://src/sim/world/deterministic_world_generator.gd")
const PilotGalaxyWorldScript = preload("res://src/sim/world/pilot_galaxy_world.gd")
const RootSystemGeneratorScript = preload("res://src/sim/world/root_system_generator.gd")

const STARTER_WORLD_ID: StringName = &"starter_world"
const SAMPLE_SYSTEM_ID: StringName = &"sample_system"
const GENERATED_SYSTEM_ID: StringName = &"generated_system"
const PILOT_GALAXY_ID: StringName = &"pilot_galaxy"

signal world_loaded(world_id: StringName)


func available_world_ids() -> Array[StringName]:
	return [STARTER_WORLD_ID, SAMPLE_SYSTEM_ID, GENERATED_SYSTEM_ID, PILOT_GALAXY_ID]


# Laedt eine benannte Welt nur dann in die Registry, wenn die Welt-ID bekannt ist
# und die daraus erzeugten Defs die komplette Vorvalidierung bestehen.
# Bei Fehlern bleibt die Registry unveraendert.
func load_named_world(world_id: StringName, registry: Node) -> bool:
	var defs: Array[BodyDef] = []
	match world_id:
		STARTER_WORLD_ID:
			defs = StarterWorldScript.build()
		SAMPLE_SYSTEM_ID:
			defs = SampleSystemScript.build()
		GENERATED_SYSTEM_ID:
			defs = DeterministicWorldGeneratorScript.build(DeterministicWorldGeneratorScript.DEFAULT_SEED)
		PILOT_GALAXY_ID:
			var galaxy = load_named_galaxy(world_id)
			if galaxy == null:
				return false
			defs = build_defs_for_root_ids(galaxy, galaxy.default_resident_root_ids)
		_:
			push_error("WorldLoader.load_named_world: unknown world_id '%s'" % world_id)
			return false
	return load_defs_into_registry(defs, registry, world_id)


func load_named_galaxy(world_id: StringName):
	match world_id:
		PILOT_GALAXY_ID:
			return PilotGalaxyWorldScript.build()
		_:
			push_error("WorldLoader.load_named_galaxy: unknown galaxy_id '%s'" % world_id)
			return null


func materialize_galaxy_roots(
		galaxy,
		root_ids: Array[StringName],
		registry: Node,
		loaded_world_id: StringName = StringName("")
	) -> bool:
	if galaxy == null:
		push_error("WorldLoader.materialize_galaxy_roots: galaxy is null")
		return false
	var defs: Array[BodyDef] = build_defs_for_root_ids(galaxy, root_ids)
	return load_defs_into_registry(defs, registry, loaded_world_id if loaded_world_id != StringName("") else galaxy.galaxy_id)


func build_defs_for_root_ids(galaxy, root_ids: Array[StringName]) -> Array[BodyDef]:
	var defs: Array[BodyDef] = []
	if galaxy == null:
		return defs
	var ids_seen: Dictionary = {}
	for root_id in root_ids:
		if root_id == StringName("") or ids_seen.has(root_id):
			continue
		ids_seen[root_id] = true
		var manifest = galaxy.get_manifest(root_id)
		if manifest == null:
			continue
		defs.append_array(build_defs_for_root_manifest(manifest))
	return defs


func build_defs_for_root_manifest(manifest) -> Array[BodyDef]:
	var defs: Array[BodyDef] = []
	if manifest == null or not manifest.is_valid():
		return defs
	if manifest.is_hero():
		match manifest.hero_world_id:
			STARTER_WORLD_ID:
				return StarterWorldScript.build()
			SAMPLE_SYSTEM_ID:
				return SampleSystemScript.build()
			_:
				push_error("WorldLoader.build_defs_for_root_manifest: unknown hero world '%s'" % manifest.hero_world_id)
				return defs
	return RootSystemGeneratorScript.build_root_defs(manifest)


# Mutiert die Registry nur nach vollstaendiger Vorvalidierung.
# Bei Fehlern bleibt der bestehende Registry-Zustand unveraendert.
# Bei Erfolg: registry.clear() + deterministische Registrierung in Array-Reihenfolge.
func load_defs_into_registry(defs: Array[BodyDef], registry: Node, loaded_world_id: StringName = StringName("")) -> bool:
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
	world_loaded.emit(loaded_world_id)
	return true
