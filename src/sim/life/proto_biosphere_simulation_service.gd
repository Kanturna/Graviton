class_name ProtoBiosphereSimulationService
extends Node


const PlanetaryYearSamplerScript = preload("res://src/sim/planetary/planetary_year_sampler.gd")
const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const ProtoBiosphereStateScript = preload("res://src/sim/life/proto_biosphere_state.gd")

enum Stage {
	STERILE,
	PREBIOTIC,
	MICROBIAL,
}

const KEY_BODY_ID: StringName = &"body_id"
const KEY_IS_SUPPORTED_BODY_KIND: StringName = &"is_supported_body_kind"
const KEY_HAS_BIOSPHERE_BASIS: StringName = &"has_biosphere_basis"
const KEY_TRACK_PROGRESS_BY_ID: StringName = &"track_progress_by_id"
const KEY_DOMINANT_TRACK_ID: StringName = &"dominant_track_id"
const KEY_BIOSPHERE_STAGE: StringName = &"biosphere_stage"
const KEY_DOMINANT_POTENTIAL_CLASS: StringName = &"dominant_potential_class"

const BIO_TICK_STEP_S: float = 10.0 * UnitSystem.DAY_S
const TRACK_IDS: Array[int] = LifePotentialServiceScript.TRACK_IDS

var _registry: Node = null
var _time_service: Node = null
var _world_loader: Node = null
var _state_by_id: Dictionary = {}
var _current_world_scope_id: StringName = &""


func configure(registry: Node, time_service: Node, world_loader: Node) -> void:
	assert(registry != null, "ProtoBiosphereSimulationService.configure: registry is null")
	assert(time_service != null, "ProtoBiosphereSimulationService.configure: time_service is null")
	assert(world_loader != null, "ProtoBiosphereSimulationService.configure: world_loader is null")
	_registry = registry
	_time_service = time_service
	_world_loader = world_loader
	clear_state()


func is_configured() -> bool:
	return _registry != null and _time_service != null and _world_loader != null


func clear_state() -> void:
	_state_by_id.clear()
	_current_world_scope_id = StringName("")


func initialize_for_named_world(world_id: StringName) -> void:
	assert(_registry != null, "ProtoBiosphereSimulationService.initialize_for_named_world: service not configured")
	_initialize_from_defs(_registry_defs_in_order(), world_id)


func initialize_for_galaxy(galaxy) -> void:
	assert(_world_loader != null, "ProtoBiosphereSimulationService.initialize_for_galaxy: service not configured")
	if galaxy == null:
		clear_state()
		return
	var defs: Array[BodyDef] = _world_loader.build_defs_for_root_ids(
		galaxy,
		galaxy.root_ids(),
		galaxy.galaxy_id
	)
	_initialize_from_defs(defs, galaxy.galaxy_id)


func describe_body(id: StringName) -> Dictionary:
	var description: Dictionary = _default_description(id)
	var state = _state_by_id.get(id, null)
	if state == null:
		var def: BodyDef = null if _registry == null else _registry.get_def(id)
		if def != null and (def.kind == BodyType.Kind.PLANET or def.kind == BodyType.Kind.MOON):
			description[KEY_IS_SUPPORTED_BODY_KIND] = true
		return description

	description[KEY_IS_SUPPORTED_BODY_KIND] = true
	description[KEY_HAS_BIOSPHERE_BASIS] = true
	var progress_by_id: Dictionary = _track_progress_by_id(state, _current_sim_time_s())
	var dominant_track_id: int = _dominant_track_id_for_progress(progress_by_id)
	var dominant_progress: float = float(progress_by_id.get(dominant_track_id, 0.0))
	description[KEY_TRACK_PROGRESS_BY_ID] = progress_by_id
	description[KEY_DOMINANT_TRACK_ID] = dominant_track_id
	description[KEY_BIOSPHERE_STAGE] = _stage_for_progress(dominant_progress)
	description[KEY_DOMINANT_POTENTIAL_CLASS] = _potential_class_for_seed(
		float(state.track_seed_by_id.get(dominant_track_id, 0.0))
	)
	return description


func get_debug_snapshot() -> Dictionary:
	return {
		"tracked_life_body_count": _state_by_id.size(),
		"current_world_scope_id": _current_world_scope_id,
		"bio_tick_step_s": BIO_TICK_STEP_S,
	}


static func to_string_stage(value: int) -> String:
	match value:
		Stage.STERILE:
			return "STERILE"
		Stage.PREBIOTIC:
			return "PREBIOTIC"
		Stage.MICROBIAL:
			return "MICROBIAL"
	return "UNKNOWN"


func _initialize_from_defs(defs: Array[BodyDef], scope_id: StringName) -> void:
	clear_state()
	_current_world_scope_id = scope_id
	if defs.is_empty():
		return
	var def_lookup: Dictionary = _def_lookup_from_defs(defs)
	var seed_time_s: float = _current_sim_time_s()
	for def in defs:
		if def == null:
			continue
		if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
			continue
		var state = _build_state_for_def(def, def_lookup, seed_time_s)
		if state != null:
			_state_by_id[def.id] = state


func _build_state_for_def(
		def: BodyDef,
		def_lookup: Dictionary,
		seed_time_s: float
	):
	var parent_chain_defs: Array[BodyDef] = _parent_chain_defs_for_def(def, def_lookup)
	if def.parent_id != StringName("") and parent_chain_defs.is_empty():
		return null
	var annual_profile: Dictionary = PlanetaryYearSamplerScript.sample_from_def_chain(def, parent_chain_defs)
	var planetary_desc: Dictionary = PlanetaryStateServiceScript.describe_from_def_and_annual_profile(
		def.id,
		def,
		annual_profile
	)
	var life_potential_desc: Dictionary = LifePotentialServiceScript.evaluate_from_planetary_desc(
		planetary_desc,
		def.id
	)
	if not bool(life_potential_desc.get(LifePotentialServiceScript.KEY_HAS_LIFE_POTENTIAL_BASIS, false)):
		return null

	var state = ProtoBiosphereStateScript.new()
	state.body_id = def.id
	state.seed_time_s = seed_time_s
	var classes_by_track: Dictionary = life_potential_desc.get(
		LifePotentialServiceScript.KEY_TRACK_POTENTIAL_CLASS_BY_ID,
		{}
	)
	for track_id in TRACK_IDS:
		var potential_class: int = int(classes_by_track.get(
			track_id,
			LifePotentialServiceScript.PotentialClass.NONE
		))
		state.track_seed_by_id[track_id] = _seed_for_potential_class(potential_class)
		state.track_delta_per_tick_by_id[track_id] = _delta_for_potential_class(potential_class)
	return state


func _registry_defs_in_order() -> Array[BodyDef]:
	var defs: Array[BodyDef] = []
	if _registry == null:
		return defs
	for id in _registry.get_update_order():
		var def: BodyDef = _registry.get_def(id)
		if def != null:
			defs.append(def)
	return defs


static func _def_lookup_from_defs(defs: Array[BodyDef]) -> Dictionary:
	var out: Dictionary = {}
	for def in defs:
		if def != null:
			out[def.id] = def
	return out


static func _parent_chain_defs_for_def(def: BodyDef, def_lookup: Dictionary) -> Array[BodyDef]:
	var chain: Array[BodyDef] = []
	if def == null:
		return chain
	var current_id: StringName = def.parent_id
	var hop_limit: int = 64
	while current_id != StringName("") and hop_limit > 0:
		var current_def: BodyDef = def_lookup.get(current_id, null) as BodyDef
		if current_def == null:
			return []
		chain.append(current_def)
		current_id = current_def.parent_id
		hop_limit -= 1
	if current_id != StringName(""):
		return []
	return chain


func _current_sim_time_s() -> float:
	return 0.0 if _time_service == null else float(_time_service.sim_time_s)


func _ticks_elapsed(seed_time_s: float, sim_time_s: float) -> int:
	if sim_time_s <= seed_time_s:
		return 0
	return maxi(0, int(floor((sim_time_s - seed_time_s) / BIO_TICK_STEP_S)))


func _track_progress_by_id(state, sim_time_s: float) -> Dictionary:
	var out: Dictionary = {}
	if state == null:
		return out
	var ticks_elapsed: int = _ticks_elapsed(state.seed_time_s, sim_time_s)
	for track_id in TRACK_IDS:
		var seed: float = float(state.track_seed_by_id.get(track_id, 0.0))
		var delta: float = float(state.track_delta_per_tick_by_id.get(track_id, 0.0))
		out[track_id] = clampf(seed + delta * float(ticks_elapsed), 0.0, 1.0)
	return out


static func _dominant_track_id_for_progress(progress_by_id: Dictionary) -> int:
	var best_track_id: int = LifePotentialServiceScript.Track.WATER_CARBON
	var best_progress: float = -1.0
	for track_id in TRACK_IDS:
		var progress: float = float(progress_by_id.get(track_id, 0.0))
		if progress > best_progress:
			best_progress = progress
			best_track_id = track_id
	return best_track_id


static func _stage_for_progress(progress: float) -> int:
	if progress < 0.20:
		return Stage.STERILE
	if progress < 0.60:
		return Stage.PREBIOTIC
	return Stage.MICROBIAL


static func _seed_for_potential_class(potential_class: int) -> float:
	match potential_class:
		LifePotentialServiceScript.PotentialClass.HIGH:
			return 0.50
		LifePotentialServiceScript.PotentialClass.MEDIUM:
			return 0.30
		LifePotentialServiceScript.PotentialClass.LOW:
			return 0.10
	return 0.0


static func _delta_for_potential_class(potential_class: int) -> float:
	match potential_class:
		LifePotentialServiceScript.PotentialClass.HIGH:
			return 0.03
		LifePotentialServiceScript.PotentialClass.MEDIUM:
			return 0.01
		LifePotentialServiceScript.PotentialClass.LOW:
			return -0.01
	return -0.03


static func _potential_class_for_seed(seed: float) -> int:
	if is_equal_approx(seed, 0.50):
		return LifePotentialServiceScript.PotentialClass.HIGH
	if is_equal_approx(seed, 0.30):
		return LifePotentialServiceScript.PotentialClass.MEDIUM
	if is_equal_approx(seed, 0.10):
		return LifePotentialServiceScript.PotentialClass.LOW
	return LifePotentialServiceScript.PotentialClass.NONE


static func _default_description(id: StringName) -> Dictionary:
	var progress_by_id: Dictionary = {}
	for track_id in TRACK_IDS:
		progress_by_id[track_id] = 0.0
	return {
		KEY_BODY_ID: id,
		KEY_IS_SUPPORTED_BODY_KIND: false,
		KEY_HAS_BIOSPHERE_BASIS: false,
		KEY_TRACK_PROGRESS_BY_ID: progress_by_id,
		KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.WATER_CARBON,
		KEY_BIOSPHERE_STAGE: Stage.STERILE,
		KEY_DOMINANT_POTENTIAL_CLASS: LifePotentialServiceScript.PotentialClass.NONE,
	}
