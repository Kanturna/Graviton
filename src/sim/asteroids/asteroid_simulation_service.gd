class_name AsteroidSimulationService
extends Node

const ASTEROID_DEF_SCRIPT := preload("res://src/sim/asteroids/asteroid_def.gd")
const ASTEROID_STATE_SCRIPT := preload("res://src/sim/asteroids/asteroid_state.gd")
const INTEGRATOR_SCRIPT := preload("res://src/sim/asteroids/restricted_gravity_integrator.gd")
const RELATIVE_STATE_RESOLVER_SCRIPT := preload("res://src/sim/topology/relative_state_resolver.gd")

const ASTEROIDS_PER_ROOT: int = 24
const MAX_ATTRACTORS: int = 6
const ATTRACTOR_REPLACE_FACTOR: float = 1.25
const ATTRACTOR_REFRESH_INTERVAL_TICKS: int = 4
const TARGET_SUBSTEP_S: float = 1800.0
const MAX_SUBSTEPS_PER_TICK: int = 32
const OUT_OF_BOUNDS_M: float = 2.0e14
const FALLBACK_BELT_INNER_M: float = 2.2e11
const FALLBACK_BELT_OUTER_M: float = 5.0e11
const PERF_KEY_ACTIVE_ASTEROIDS: StringName = &"active_asteroids"
const PERF_KEY_ATTRACTOR_CHECKS: StringName = &"attractor_checks"
const PERF_KEY_SUBSTEPS: StringName = &"substeps"
const PERF_KEY_SUBSTEP_CAP_HITS: StringName = &"substep_cap_hits"
const PERF_KEY_SPAWNED: StringName = &"spawned"
const PERF_KEY_DESPAWNED: StringName = &"despawned"
const PERF_KEY_OUT_OF_BOUNDS: StringName = &"out_of_bounds"
const PERF_KEY_ADVANCE_TICKS: StringName = &"advance_ticks"

var _registry: Node = null
var _topology: UniverseTopology = UniverseTopology.new()
var _relative_resolver = RELATIVE_STATE_RESOLVER_SCRIPT.new()
var _configured: bool = false
var _scope_id: StringName = &""
var _resident_root_ids: Array[StringName] = []
var _defs_by_id: Dictionary = {}
var _states_by_id: Dictionary = {}
var _state_order: Array[StringName] = []
var _relative_state_cache: Dictionary = {}
var _revision: int = 0
var _perf_counters: Dictionary = {
	PERF_KEY_ACTIVE_ASTEROIDS: 0,
	PERF_KEY_ATTRACTOR_CHECKS: 0,
	PERF_KEY_SUBSTEPS: 0,
	PERF_KEY_SUBSTEP_CAP_HITS: 0,
	PERF_KEY_SPAWNED: 0,
	PERF_KEY_DESPAWNED: 0,
	PERF_KEY_OUT_OF_BOUNDS: 0,
	PERF_KEY_ADVANCE_TICKS: 0,
}


func configure(registry: Node) -> void:
	assert(registry != null, "AsteroidSimulationService.configure: registry is null")
	_registry = registry
	_topology.configure(registry)
	_relative_resolver.configure(registry)
	_configured = true


func reset_for_world(scope_id: StringName, root_ids: Array[StringName], t_s: float) -> void:
	_scope_id = scope_id
	_resident_root_ids = _normalized_root_ids(root_ids)
	_defs_by_id.clear()
	_states_by_id.clear()
	_state_order.clear()
	_reset_perf_counters()
	for root_id in _resident_root_ids:
		_spawn_root(root_id, t_s)
	_revision += 1
	_update_active_counter()


func sync_resident_roots(scope_id: StringName, root_ids: Array[StringName], t_s: float) -> void:
	if not _configured:
		return
	if scope_id != _scope_id:
		reset_for_world(scope_id, root_ids, t_s)
		return
	var next_roots: Array[StringName] = _normalized_root_ids(root_ids)
	var next_lookup: Dictionary = {}
	for root_id in next_roots:
		next_lookup[root_id] = true

	var changed: bool = false
	for existing_id in _resident_root_ids.duplicate():
		if next_lookup.has(existing_id):
			continue
		_despawn_root(existing_id)
		changed = true

	var current_lookup: Dictionary = {}
	for root_id in _resident_root_ids:
		current_lookup[root_id] = true
	for root_id in next_roots:
		if current_lookup.has(root_id):
			continue
		_spawn_root(root_id, t_s)
		changed = true

	if changed:
		_resident_root_ids = next_roots
		_revision += 1
		_update_active_counter()


func advance_to_time(t_s: float, dt_s: float) -> void:
	if not _configured or dt_s <= 0.0:
		return
	_relative_state_cache.clear()
	var tick_index: int = int(_perf_counters.get(PERF_KEY_ADVANCE_TICKS, 0))
	var changed: bool = false
	for id in _state_order.duplicate():
		var state = _states_by_id.get(id, null)
		if state == null or not state.is_active:
			continue
		var attractor_ids: Array[StringName] = state.current_attractor_ids
		if _should_refresh_attractors(state, tick_index):
			attractor_ids = _select_attractors_for(state)
			state.current_attractor_ids = attractor_ids
		var attractors: PackedFloat64Array = _build_attractor_entries(state, attractor_ids)
		var result: Dictionary = INTEGRATOR_SCRIPT.integrate(
			state,
			attractors,
			dt_s,
			TARGET_SUBSTEP_S,
			MAX_SUBSTEPS_PER_TICK
		)
		state.last_update_time_s = t_s
		_perf_counters[PERF_KEY_SUBSTEPS] = int(_perf_counters.get(PERF_KEY_SUBSTEPS, 0)) + int(result.get("substep_count", 0))
		if bool(result.get("hit_substep_cap", false)):
			_perf_counters[PERF_KEY_SUBSTEP_CAP_HITS] = int(_perf_counters.get(PERF_KEY_SUBSTEP_CAP_HITS, 0)) + 1
		if _is_out_of_bounds(state):
			state.is_active = false
			_perf_counters[PERF_KEY_OUT_OF_BOUNDS] = int(_perf_counters.get(PERF_KEY_OUT_OF_BOUNDS, 0)) + 1
		changed = true

	_perf_counters[PERF_KEY_ADVANCE_TICKS] = int(_perf_counters.get(PERF_KEY_ADVANCE_TICKS, 0)) + 1
	if changed:
		_revision += 1
	_update_active_counter()
	_relative_state_cache.clear()


func get_state_snapshot() -> Dictionary:
	var entries: Array = []
	for id in _state_order:
		var state = _states_by_id.get(id, null)
		if state == null or not state.is_active:
			continue
		var def = _defs_by_id.get(id, null)
		entries.append(state.clone_snapshot(def))
	return {
		"scope_id": _scope_id,
		"resident_root_ids": _resident_root_ids.duplicate(),
		"revision": _revision,
		"count": entries.size(),
		"entries": entries,
	}


func get_perf_counter_snapshot() -> Dictionary:
	var out: Dictionary = _perf_counters.duplicate(true)
	out["revision"] = _revision
	out["resident_root_count"] = _resident_root_ids.size()
	out["total_state_count"] = _state_order.size()
	return out


func get_debug_snapshot() -> Dictionary:
	return {
		"scope_id": _scope_id,
		"resident_root_ids": _resident_root_ids.duplicate(),
		"revision": _revision,
		"state_count": _state_order.size(),
		"perf": get_perf_counter_snapshot(),
	}


func _spawn_root(root_id: StringName, t_s: float) -> void:
	if _registry == null or not _registry.has_body(root_id):
		return
	var anchors: Array[StringName] = _select_spawn_anchors(root_id)
	if anchors.is_empty():
		anchors.append(root_id)
	for idx in range(ASTEROIDS_PER_ROOT):
		var anchor_id: StringName = anchors[idx % anchors.size()]
		var seed: int = _stable_hash("%s/%s/%d" % [str(_scope_id), str(root_id), idx])
		var asteroid_id: StringName = _asteroid_id_for(root_id, idx)
		if _states_by_id.has(asteroid_id):
			continue
		var def = ASTEROID_DEF_SCRIPT.new(asteroid_id, root_id, anchor_id, seed)
		def.radius_m = _range_from_seed(seed, 1, 45.0, 260.0)
		def.mass_kg = 4.0 / 3.0 * PI * def.radius_m * def.radius_m * def.radius_m * 2500.0
		def.visual_class = _visual_class_from_seed(seed)
		var state = _build_initial_state(def, t_s)
		_defs_by_id[asteroid_id] = def
		_states_by_id[asteroid_id] = state
		_state_order.append(asteroid_id)
		_perf_counters[PERF_KEY_SPAWNED] = int(_perf_counters.get(PERF_KEY_SPAWNED, 0)) + 1
	if not _resident_root_ids.has(root_id):
		_resident_root_ids.append(root_id)


func _despawn_root(root_id: StringName) -> void:
	for id in _state_order.duplicate():
		var state = _states_by_id.get(id, null)
		if state == null or state.root_id != root_id:
			continue
		_states_by_id.erase(id)
		_defs_by_id.erase(id)
		_state_order.erase(id)
		_perf_counters[PERF_KEY_DESPAWNED] = int(_perf_counters.get(PERF_KEY_DESPAWNED, 0)) + 1
	_resident_root_ids.erase(root_id)


func _select_spawn_anchors(root_id: StringName) -> Array[StringName]:
	var anchors: Array[StringName] = []
	for id in _registry.get_update_order():
		var def: BodyDef = _registry.get_def(id)
		if def == null or def.kind != BodyType.Kind.STAR:
			continue
		if _topology.root_id_of(id) == root_id:
			anchors.append(id)
	if anchors.is_empty():
		anchors.append(root_id)
	return anchors


func _build_initial_state(def, t_s: float):
	var state = ASTEROID_STATE_SCRIPT.new()
	state.id = def.id
	state.root_id = def.root_id
	state.anchor_id = def.anchor_id
	state.last_update_time_s = t_s
	var bounds: Dictionary = _spawn_radius_bounds(def.anchor_id)
	var inner_m: float = float(bounds.get("inner_m", FALLBACK_BELT_INNER_M))
	var outer_m: float = maxf(float(bounds.get("outer_m", FALLBACK_BELT_OUTER_M)), inner_m * 1.05)
	var radius_m: float = _range_from_seed(def.seed, 2, inner_m, outer_m)
	var phase_rad: float = _range_from_seed(def.seed, 3, 0.0, TAU)
	var z_m: float = _range_from_seed(def.seed, 4, -0.015, 0.015) * radius_m
	state.x_m = cos(phase_rad) * radius_m
	state.y_m = sin(phase_rad) * radius_m
	state.z_m = z_m

	var anchor_def: BodyDef = _registry.get_def(def.anchor_id)
	var mu: float = INTEGRATOR_SCRIPT.G_M3_PER_KG_S2 * maxf(anchor_def.mass_kg if anchor_def != null else 0.0, 1.0)
	var speed_mps: float = sqrt(mu / maxf(radius_m, 1.0)) * _range_from_seed(def.seed, 5, 0.82, 1.12)
	var tilt: float = _range_from_seed(def.seed, 6, -0.08, 0.08)
	state.vx_mps = -sin(phase_rad) * speed_mps
	state.vy_mps = cos(phase_rad) * speed_mps
	state.vz_mps = speed_mps * tilt
	return state


func _spawn_radius_bounds(anchor_id: StringName) -> Dictionary:
	var min_a: float = INF
	var max_a: float = 0.0
	for child_id in _registry.get_children_of(anchor_id):
		var child_def: BodyDef = _registry.get_def(child_id)
		if child_def == null or child_def.orbit_profile == null:
			continue
		if child_def.kind != BodyType.Kind.PLANET and child_def.kind != BodyType.Kind.MOON:
			continue
		var axis_m: float = maxf(float(child_def.orbit_profile.semi_major_axis_m), 1.0)
		min_a = minf(min_a, axis_m)
		max_a = maxf(max_a, axis_m)
	if not is_finite(min_a) or max_a <= 0.0:
		return {"inner_m": FALLBACK_BELT_INNER_M, "outer_m": FALLBACK_BELT_OUTER_M}
	return {
		"inner_m": maxf(min_a * 0.72, 1.0e7),
		"outer_m": maxf(max_a * 1.35, min_a * 1.2),
	}


func _select_attractors_for(state) -> Array[StringName]:
	var candidates: Array = _rank_attractor_candidates(state)
	var mandatory: Array[StringName] = []
	for required_id in [state.root_id, state.anchor_id]:
		if required_id != StringName("") and not mandatory.has(required_id) and _registry.has_body(required_id):
			mandatory.append(required_id)
	var strongest_star: StringName = _strongest_star_for_root(state.root_id)
	if strongest_star != StringName("") and not mandatory.has(strongest_star):
		mandatory.append(strongest_star)

	var selected: Array[StringName] = []
	for id in mandatory:
		if selected.size() >= MAX_ATTRACTORS:
			break
		selected.append(id)

	for id in state.current_attractor_ids:
		if selected.size() >= MAX_ATTRACTORS:
			break
		if id == StringName("") or selected.has(id) or not _candidate_id_present(candidates, id):
			continue
		selected.append(id)

	for entry in candidates:
		if selected.size() >= MAX_ATTRACTORS:
			break
		var id: StringName = entry.get("id", StringName(""))
		if id == StringName("") or selected.has(id):
			continue
		selected.append(id)

	if selected.size() < MAX_ATTRACTORS:
		return selected

	var weakest_idx: int = _weakest_optional_index(selected, mandatory, candidates)
	var weakest_score: float = _score_for_candidate(candidates, selected[weakest_idx]) if weakest_idx >= 0 else INF
	var best_outside_id: StringName = &""
	var best_outside_score: float = 0.0
	for entry in candidates:
		var candidate_id: StringName = entry.get("id", StringName(""))
		var score: float = float(entry.get("score", 0.0))
		if selected.has(candidate_id):
			continue
		if score > best_outside_score:
			best_outside_id = candidate_id
			best_outside_score = score
	if weakest_idx >= 0 and best_outside_id != StringName("") and best_outside_score >= weakest_score * ATTRACTOR_REPLACE_FACTOR:
		selected[weakest_idx] = best_outside_id
	return selected


func _should_refresh_attractors(state, tick_index: int) -> bool:
	if state.current_attractor_ids.is_empty():
		return true
	if tick_index % maxi(1, ATTRACTOR_REFRESH_INTERVAL_TICKS) == 0:
		return true
	return not _attractor_ids_still_valid(state)


func _attractor_ids_still_valid(state) -> bool:
	for required_id in [state.root_id, state.anchor_id]:
		if required_id != StringName("") and not state.current_attractor_ids.has(required_id):
			return false
	for id in state.current_attractor_ids:
		if id == StringName("") or not _registry.has_body(id):
			return false
		var def: BodyDef = _registry.get_def(id)
		if def == null or not _is_v1_attractor_kind(def.kind):
			return false
		if _topology.root_id_of(id) != state.root_id:
			return false
	return true


func _rank_attractor_candidates(state) -> Array:
	var out: Array = []
	for body_id in _registry.get_update_order():
		var def: BodyDef = _registry.get_def(body_id)
		if def == null or not _is_v1_attractor_kind(def.kind):
			continue
		if _topology.root_id_of(body_id) != state.root_id:
			continue
		var relative: Dictionary = _resolve_body_relative_to_anchor_cached(body_id, state.anchor_id)
		if not bool(relative.get("ok", false)):
			continue
		var dx: float = float(relative.get("x_m", 0.0)) - state.x_m
		var dy: float = float(relative.get("y_m", 0.0)) - state.y_m
		var dz: float = float(relative.get("z_m", 0.0)) - state.z_m
		var distance2_m2: float = maxf(dx * dx + dy * dy + dz * dz, 1.0)
		var score: float = INTEGRATOR_SCRIPT.G_M3_PER_KG_S2 * maxf(def.mass_kg, 0.0) / distance2_m2
		_perf_counters[PERF_KEY_ATTRACTOR_CHECKS] = int(_perf_counters.get(PERF_KEY_ATTRACTOR_CHECKS, 0)) + 1
		out.append({"id": body_id, "score": score})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: float = float(a.get("score", 0.0))
		var score_b: float = float(b.get("score", 0.0))
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b
		return str(a.get("id", StringName(""))) < str(b.get("id", StringName("")))
	)
	return out


func _build_attractor_entries(state, attractor_ids: Array[StringName]) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for id in attractor_ids:
		var def: BodyDef = _registry.get_def(id)
		if def == null:
			continue
		var relative: Dictionary = _resolve_body_relative_to_anchor_cached(id, state.anchor_id)
		if not bool(relative.get("ok", false)):
			continue
		out.append(float(relative.get("x_m", 0.0)))
		out.append(float(relative.get("y_m", 0.0)))
		out.append(float(relative.get("z_m", 0.0)))
		out.append(INTEGRATOR_SCRIPT.G_M3_PER_KG_S2 * maxf(def.mass_kg, 0.0))
	return out


func _strongest_star_for_root(root_id: StringName) -> StringName:
	var best_id: StringName = &""
	var best_mass: float = -1.0
	for id in _registry.get_update_order():
		var def: BodyDef = _registry.get_def(id)
		if def == null or def.kind != BodyType.Kind.STAR:
			continue
		if _topology.root_id_of(id) != root_id:
			continue
		if def.mass_kg > best_mass:
			best_id = id
			best_mass = def.mass_kg
	return best_id


static func _weakest_optional_index(selected: Array[StringName], mandatory: Array[StringName], candidates: Array) -> int:
	var weakest_idx: int = -1
	var weakest_score: float = INF
	for idx in range(selected.size()):
		var id: StringName = selected[idx]
		if mandatory.has(id):
			continue
		var score: float = _score_for_candidate(candidates, id)
		if score < weakest_score:
			weakest_idx = idx
			weakest_score = score
	return weakest_idx


static func _score_for_candidate(candidates: Array, id: StringName) -> float:
	for entry in candidates:
		if entry.get("id", StringName("")) == id:
			return float(entry.get("score", 0.0))
	return 0.0


static func _candidate_id_present(candidates: Array, id: StringName) -> bool:
	for entry in candidates:
		if entry.get("id", StringName("")) == id:
			return true
	return false


func _resolve_body_relative_to_anchor_cached(body_id: StringName, anchor_id: StringName) -> Dictionary:
	var cache_key: String = "%s|%s" % [str(anchor_id), str(body_id)]
	if _relative_state_cache.has(cache_key):
		return _relative_state_cache[cache_key]
	var resolved: Dictionary = _relative_resolver.resolve_body_relative_to_anchor(body_id, anchor_id)
	_relative_state_cache[cache_key] = resolved
	return resolved


static func _is_v1_attractor_kind(kind: int) -> bool:
	return (
		kind == BodyType.Kind.BLACK_HOLE
		or kind == BodyType.Kind.STAR
		or kind == BodyType.Kind.PLANET
		or kind == BodyType.Kind.MOON
	)


static func _normalized_root_ids(root_ids: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for root_id in root_ids:
		if root_id == StringName("") or out.has(root_id):
			continue
		out.append(root_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return out


func _asteroid_id_for(root_id: StringName, idx: int) -> StringName:
	return StringName("ast_%s_%s_%02d" % [_sanitize_id(_scope_id), _sanitize_id(root_id), idx])


static func _sanitize_id(id: StringName) -> String:
	var raw: String = str(id)
	var out: String = ""
	for idx in range(raw.length()):
		var code: int = raw.unicode_at(idx)
		var is_alnum: bool = (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		out += raw[idx] if is_alnum else "_"
	return out


static func _stable_hash(text: String) -> int:
	var hash: int = 2166136261
	for idx in range(text.length()):
		hash = int((hash ^ text.unicode_at(idx)) * 16777619) & 0x7fffffff
	return hash


static func _range_from_seed(seed: int, salt: int, min_value: float, max_value: float) -> float:
	var value: int = _stable_hash("%d:%d" % [seed, salt])
	var unit: float = float(value % 1000000) / 999999.0
	return lerpf(min_value, max_value, unit)


static func _visual_class_from_seed(seed: int) -> StringName:
	match seed % 3:
		0:
			return &"carbon"
		1:
			return &"silicate"
		_:
			return &"metal"


static func _is_out_of_bounds(state) -> bool:
	var r2: float = state.x_m * state.x_m + state.y_m * state.y_m + state.z_m * state.z_m
	return r2 > OUT_OF_BOUNDS_M * OUT_OF_BOUNDS_M


func _update_active_counter() -> void:
	var count: int = 0
	for id in _state_order:
		var state = _states_by_id.get(id, null)
		if state != null and state.is_active:
			count += 1
	_perf_counters[PERF_KEY_ACTIVE_ASTEROIDS] = count


func _reset_perf_counters() -> void:
	for key in _perf_counters.keys():
		_perf_counters[key] = 0
