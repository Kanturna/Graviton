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

var _prepared_root_slices_by_cache_key: Dictionary = {}


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
	if registry == null:
		push_error("WorldLoader.materialize_galaxy_roots: registry is null")
		return false

	var target_slices: Array = _prepare_root_slices_for_ids(galaxy, root_ids)
	if target_slices.is_empty():
		push_error("WorldLoader.materialize_galaxy_roots: no valid target roots for %s" % str(root_ids))
		return false

	var target_defs: Array[BodyDef] = _flatten_defs_from_slices(target_slices)
	if not _validate_defs(target_defs, "WorldLoader.materialize_galaxy_roots"):
		return false

	var current_defs_by_root: Dictionary = _collect_registry_defs_by_root(registry)
	var current_signature_by_root: Dictionary = {}
	for root_id_variant in current_defs_by_root.keys():
		var current_root_id: StringName = root_id_variant
		current_signature_by_root[current_root_id] = _defs_signature(current_defs_by_root.get(current_root_id, []))

	var target_slice_by_root: Dictionary = {}
	for slice_variant in target_slices:
		var slice: Dictionary = slice_variant
		var target_root_id: StringName = slice.get("root_id", StringName(""))
		if target_root_id != StringName(""):
			target_slice_by_root[target_root_id] = slice

	var removed_any: bool = false
	for root_id_variant in current_defs_by_root.keys():
		var current_root_id: StringName = root_id_variant
		if not target_slice_by_root.has(current_root_id):
			_unregister_root_defs(current_defs_by_root.get(current_root_id, []), registry)
			removed_any = true
			continue
		if String(current_signature_by_root.get(current_root_id, "")) != String(target_slice_by_root[current_root_id].get("defs_signature", "")):
			_unregister_root_defs(current_defs_by_root.get(current_root_id, []), registry)
			removed_any = true

	var added_any: bool = false
	for slice_variant in target_slices:
		var slice: Dictionary = slice_variant
		var target_root_id: StringName = slice.get("root_id", StringName(""))
		if target_root_id == StringName(""):
			continue
		if current_defs_by_root.has(target_root_id):
			var existing_signature: String = String(current_signature_by_root.get(target_root_id, ""))
			var target_signature: String = String(slice.get("defs_signature", ""))
			if existing_signature == target_signature:
				continue
		_register_root_defs(slice.get("defs", []), registry)
		added_any = true

	if removed_any or added_any:
		world_loaded.emit(loaded_world_id if loaded_world_id != StringName("") else galaxy.galaxy_id)
	return true


func build_defs_for_root_ids(galaxy, root_ids: Array[StringName]) -> Array[BodyDef]:
	return _flatten_defs_from_slices(_prepare_root_slices_for_ids(galaxy, root_ids))


func build_defs_for_root_manifest(manifest) -> Array[BodyDef]:
	var prepared_slice: Dictionary = _prepare_root_slice(manifest)
	var defs: Array[BodyDef] = []
	defs.append_array(prepared_slice.get("defs", []))
	return defs


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
	if not _validate_defs(defs, "WorldLoader.load_defs_into_registry"):
		return false

	registry.clear()
	for def in defs:
		registry.register_body(def)
	world_loaded.emit(loaded_world_id)
	return true


func _prepare_root_slices_for_ids(galaxy, root_ids: Array[StringName]) -> Array:
	var out: Array = []
	if galaxy == null:
		return out
	var ids_seen: Dictionary = {}
	for root_id in root_ids:
		if root_id == StringName("") or ids_seen.has(root_id):
			continue
		ids_seen[root_id] = true
		var manifest = galaxy.get_manifest(root_id)
		if manifest == null:
			continue
		var slice: Dictionary = _prepare_root_slice(manifest)
		if not slice.is_empty():
			out.append(slice)
	return out


func _prepare_root_slice(manifest) -> Dictionary:
	if manifest == null or not manifest.is_valid():
		return {}

	var cache_key: String = _prepared_slice_cache_key(manifest)
	if cache_key != "" and _prepared_root_slices_by_cache_key.has(cache_key):
		return _prepared_root_slices_by_cache_key[cache_key]

	var defs: Array[BodyDef] = []
	if manifest.is_hero():
		match manifest.hero_world_id:
			STARTER_WORLD_ID:
				defs = StarterWorldScript.build()
			SAMPLE_SYSTEM_ID:
				defs = SampleSystemScript.build()
			_:
				push_error("WorldLoader.build_defs_for_root_manifest: unknown hero world '%s'" % manifest.hero_world_id)
				return {}
	else:
		defs = RootSystemGeneratorScript.build_root_defs(manifest)

	if defs.is_empty():
		return {}

	var slice := {
		"root_id": manifest.root_id,
		"defs": defs,
		"defs_signature": _defs_signature(defs),
	}
	if cache_key != "":
		_prepared_root_slices_by_cache_key[cache_key] = slice
	return slice


static func _prepared_slice_cache_key(manifest) -> String:
	if manifest == null:
		return ""
	return "%s#%s" % [String(manifest.root_id), str(manifest.get_instance_id())]


static func _flatten_defs_from_slices(slices: Array) -> Array[BodyDef]:
	var defs: Array[BodyDef] = []
	for slice_variant in slices:
		var slice: Dictionary = slice_variant
		defs.append_array(slice.get("defs", []))
	return defs


static func _collect_registry_defs_by_root(registry: Node) -> Dictionary:
	var defs_by_root: Dictionary = {}
	var root_id_by_id: Dictionary = {}
	for id in registry.get_update_order():
		var def: BodyDef = registry.get_def(id)
		if def == null:
			continue
		var root_id: StringName = def.id if def.is_root() else StringName(root_id_by_id.get(def.parent_id, StringName("")))
		root_id_by_id[id] = root_id
		if not defs_by_root.has(root_id):
			defs_by_root[root_id] = []
		var root_defs: Array = defs_by_root[root_id]
		root_defs.append(def)
		defs_by_root[root_id] = root_defs
	return defs_by_root


static func _register_root_defs(defs: Array, registry: Node) -> void:
	for def_variant in defs:
		registry.register_body(def_variant)


static func _unregister_root_defs(defs: Array, registry: Node) -> void:
	for index in range(defs.size() - 1, -1, -1):
		var def: BodyDef = defs[index]
		if def != null:
			registry.unregister_body(def.id)


static func _validate_defs(defs: Array[BodyDef], context: String) -> bool:
	var ids_seen: Dictionary = {}
	var order_indices: Dictionary = {}
	for index in range(defs.size()):
		var def: BodyDef = defs[index]
		if def == null:
			push_error("%s: def at index %d is null" % [context, index])
			return false
		if not def.is_valid():
			push_error("%s: def '%s' is invalid" % [context, def.id])
			return false
		if ids_seen.has(def.id):
			push_error("%s: duplicate id '%s'" % [context, def.id])
			return false
		ids_seen[def.id] = true
		order_indices[def.id] = index

	for index in range(defs.size()):
		var def: BodyDef = defs[index]
		if def.parent_id == StringName(""):
			continue
		if def.parent_id == def.id:
			push_error("%s: '%s' cannot parent itself" % [context, def.id])
			return false
		if not ids_seen.has(def.parent_id):
			push_error("%s: '%s' references missing parent '%s'" % [context, def.id, def.parent_id])
			return false
		var parent_index: int = int(order_indices[def.parent_id])
		if parent_index >= index:
			push_error("%s: parent '%s' must appear before child '%s'" % [context, def.parent_id, def.id])
			return false
	return true


static func _defs_signature(defs: Array) -> String:
	var ordered_defs: Array = []
	ordered_defs.append_array(defs)
	ordered_defs.sort_custom(func(a: BodyDef, b: BodyDef) -> bool:
		return String(a.id) < String(b.id)
	)
	var parts: Array[String] = []
	for def_variant in ordered_defs:
		var def: BodyDef = def_variant
		parts.append(_serialize_body_def(def))
	return "\n".join(parts)


static func _serialize_body_def(def: BodyDef) -> String:
	return "|".join([
		"id=%s" % _canonical_variant(def.id),
		"display_name=%s" % _canonical_variant(def.display_name),
		"kind=%s" % _canonical_variant(def.kind),
		"mass_kg=%s" % _canonical_variant(def.mass_kg),
		"radius_m=%s" % _canonical_variant(def.radius_m),
		"rotation_period_s=%s" % _canonical_variant(def.rotation_period_s),
		"axial_tilt_rad=%s" % _canonical_variant(def.axial_tilt_rad),
		"north_pole_orbit_frame_azimuth_rad=%s" % _canonical_variant(def.north_pole_orbit_frame_azimuth_rad),
		"luminosity_w=%s" % _canonical_variant(def.luminosity_w),
		"albedo=%s" % _canonical_variant(def.albedo),
		"greenhouse_delta_k=%s" % _canonical_variant(def.greenhouse_delta_k),
		"parent_id=%s" % _canonical_variant(def.parent_id),
		"orbit_profile=%s" % _serialize_orbit_profile(def.orbit_profile),
	])


static func _serialize_orbit_profile(profile: OrbitProfile) -> String:
	if profile == null:
		return "null"
	return "{%s}" % ",".join([
		"mode=%s" % _canonical_variant(profile.mode),
		"authored_radius_m=%s" % _canonical_variant(profile.authored_radius_m),
		"authored_period_s=%s" % _canonical_variant(profile.authored_period_s),
		"authored_phase_rad=%s" % _canonical_variant(profile.authored_phase_rad),
		"semi_major_axis_m=%s" % _canonical_variant(profile.semi_major_axis_m),
		"eccentricity=%s" % _canonical_variant(profile.eccentricity),
		"inclination_rad=%s" % _canonical_variant(profile.inclination_rad),
		"longitude_ascending_node_rad=%s" % _canonical_variant(profile.longitude_ascending_node_rad),
		"argument_periapsis_rad=%s" % _canonical_variant(profile.argument_periapsis_rad),
		"mean_anomaly_epoch_rad=%s" % _canonical_variant(profile.mean_anomaly_epoch_rad),
		"epoch_s=%s" % _canonical_variant(profile.epoch_s),
	])


static func _canonical_variant(value) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return "i:%d" % int(value)
		TYPE_FLOAT:
			return "f:%s" % str(float(value))
		TYPE_STRING:
			return "s:%s" % String(value)
		TYPE_STRING_NAME:
			return "sn:%s" % String(value)
		TYPE_VECTOR2:
			var vec2: Vector2 = value
			return "v2(%s,%s)" % [_canonical_variant(vec2.x), _canonical_variant(vec2.y)]
		TYPE_VECTOR3:
			var vec3: Vector3 = value
			return "v3(%s,%s,%s)" % [_canonical_variant(vec3.x), _canonical_variant(vec3.y), _canonical_variant(vec3.z)]
		TYPE_ARRAY:
			var parts: Array[String] = []
			for entry in value:
				parts.append(_canonical_variant(entry))
			return "[%s]" % ",".join(parts)
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var keys: Array = dict.keys()
			keys.sort_custom(func(a, b) -> bool:
				return _canonical_variant(a) < _canonical_variant(b)
			)
			var dict_parts: Array[String] = []
			for key in keys:
				dict_parts.append("%s:%s" % [_canonical_variant(key), _canonical_variant(dict[key])])
			return "{%s}" % ",".join(dict_parts)
		_:
			return "o:%s" % String(value)
