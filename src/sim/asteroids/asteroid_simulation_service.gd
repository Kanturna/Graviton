class_name AsteroidSimulationService
extends Node

const ASTEROID_DEF_SCRIPT := preload("res://src/sim/asteroids/asteroid_def.gd")
const ASTEROID_STATE_SCRIPT := preload("res://src/sim/asteroids/asteroid_state.gd")
const INTEGRATOR_SCRIPT := preload("res://src/sim/asteroids/restricted_gravity_integrator.gd")
const RELATIVE_STATE_RESOLVER_SCRIPT := preload("res://src/sim/topology/relative_state_resolver.gd")

const ASTEROIDS_PER_ROOT: int = 24
const MAX_ATTRACTORS: int = 6
const ATTRACTOR_REPLACE_FACTOR: float = 1.25
const ATTRACTOR_REFRESH_INTERVAL_TICKS: int = 8
const INFLUENCE_EXIT_FACTOR: float = 1.15
const BH_FLYBY_GRAVITY_FACTOR: float = 0.45 # Tuned so asteroid flybys curve visibly without closing into clean BH orbits.
const STAR_INFLUENCE_RADIUS_MULTIPLIER: float = 3.25
const STAR_INFLUENCE_PADDING_M: float = 2.5e11
const STAR_FALLBACK_INFLUENCE_M: float = 1.0e12
const BLACK_HOLE_INFLUENCE_RADIUS_MULTIPLIER: float = 6.0
const BLACK_HOLE_FALLBACK_INFLUENCE_M: float = 3.0e12
const PLANET_RADIUS_INFLUENCE_MULTIPLIER: float = 160.0
const PLANET_MOON_ORBIT_INFLUENCE_MULTIPLIER: float = 3.0
const MOON_RADIUS_INFLUENCE_MULTIPLIER: float = 90.0
const MOON_MIN_INFLUENCE_M: float = 4.0e8
const TARGET_SUBSTEP_S: float = 1800.0
const MAX_SUBSTEPS_PER_TICK: int = 32
const ASTEROID_FAR_RETIRE_RADIUS_M: float = 1.0e16
const FALLBACK_BELT_INNER_M: float = 2.2e11
const FALLBACK_BELT_OUTER_M: float = 5.0e11
const VELOCITY_SEED_EPSILON_S: float = 1.0
const PERF_KEY_ACTIVE_ASTEROIDS: StringName = &"active_asteroids"
const PERF_KEY_ATTRACTOR_CHECKS: StringName = &"attractor_checks"
const PERF_KEY_SUBSTEPS: StringName = &"substeps"
const PERF_KEY_SUBSTEP_CAP_HITS: StringName = &"substep_cap_hits"
const PERF_KEY_SPAWNED: StringName = &"spawned"
const PERF_KEY_DESPAWNED: StringName = &"despawned"
const PERF_KEY_FAR_RETIRED_COUNT: StringName = &"far_retired_count"
const PERF_KEY_ADVANCE_TICKS: StringName = &"advance_ticks"
const PERF_KEY_FREE_DRIFT_COUNT: StringName = &"free_drift_count"
const PERF_KEY_BH_ATTRACTOR_COUNT: StringName = &"bh_attractor_count"
const PERF_KEY_INFLUENCE_ZONE_CHECKS: StringName = &"influence_zone_checks"
const PERF_KEY_INFLUENCE_INDEX_REBUILDS: StringName = &"influence_index_rebuilds"
const PERF_KEY_TOTAL_ACTIVE_ATTRACTORS_PER_TICK: StringName = &"total_active_attractors_per_tick"
const PERF_KEY_ATTRACTOR_SET_CHANGES: StringName = &"attractor_set_changes"

var _registry: Node = null
var _topology: UniverseTopology = UniverseTopology.new()
var _relative_resolver = RELATIVE_STATE_RESOLVER_SCRIPT.new()
var _configured: bool = false
var _scope_id: StringName = &""
var _tracked_root_ids: Array[StringName] = []
var _major_body_resident_root_ids: Array[StringName] = []
var _root_spawn_catalog_scope_id: StringName = &""
var _root_spawn_catalog_by_root: Dictionary = {}
var _defs_by_id: Dictionary = {}
var _states_by_id: Dictionary = {}
var _state_order: Array[StringName] = []
var _influence_zones_by_root: Dictionary = {}
var _relative_state_cache: Dictionary = {}
var _revision: int = 0
var _perf_counters: Dictionary = {
	PERF_KEY_ACTIVE_ASTEROIDS: 0,
	PERF_KEY_ATTRACTOR_CHECKS: 0,
	PERF_KEY_SUBSTEPS: 0,
	PERF_KEY_SUBSTEP_CAP_HITS: 0,
	PERF_KEY_SPAWNED: 0,
	PERF_KEY_DESPAWNED: 0,
	PERF_KEY_FAR_RETIRED_COUNT: 0,
	PERF_KEY_ADVANCE_TICKS: 0,
	PERF_KEY_FREE_DRIFT_COUNT: 0,
	PERF_KEY_BH_ATTRACTOR_COUNT: 0,
	PERF_KEY_INFLUENCE_ZONE_CHECKS: 0,
	PERF_KEY_INFLUENCE_INDEX_REBUILDS: 0,
	PERF_KEY_TOTAL_ACTIVE_ATTRACTORS_PER_TICK: 0,
	PERF_KEY_ATTRACTOR_SET_CHANGES: 0,
}


func configure(registry: Node) -> void:
	assert(registry != null, "AsteroidSimulationService.configure: registry is null")
	_registry = registry
	_topology.configure(registry)
	_relative_resolver.configure(registry)
	_configured = true


func set_root_spawn_catalog(scope_id: StringName, root_defs_by_root: Dictionary) -> void:
	_root_spawn_catalog_scope_id = scope_id
	_root_spawn_catalog_by_root.clear()
	for raw_root_id in root_defs_by_root.keys():
		var root_id: StringName = _to_string_name(raw_root_id)
		if root_id == StringName(""):
			continue
		var raw_defs = root_defs_by_root.get(raw_root_id, [])
		if typeof(raw_defs) != TYPE_ARRAY:
			continue
		var defs: Array[BodyDef] = []
		for raw_def in raw_defs:
			var body_def: BodyDef = raw_def as BodyDef
			if body_def != null:
				defs.append(body_def)
		if not defs.is_empty():
			_root_spawn_catalog_by_root[root_id] = defs


func reset_for_world(scope_id: StringName, root_ids: Array[StringName], t_s: float) -> void:
	_scope_id = scope_id
	_tracked_root_ids = _normalized_root_ids(root_ids)
	_major_body_resident_root_ids = _registry_root_ids_from(_tracked_root_ids)
	_defs_by_id.clear()
	_states_by_id.clear()
	_state_order.clear()
	_influence_zones_by_root.clear()
	_reset_perf_counters()
	for root_id in _tracked_root_ids:
		_spawn_root(root_id, t_s)
	for root_id in _major_body_resident_root_ids:
		_rebuild_influence_index_for_root(root_id)
	_revision += 1
	_update_active_counter()


# Deprecated compatibility wrapper. New scene code must use tracked roots
# for asteroid existence and set_major_body_resident_roots() for streaming.
func sync_resident_roots(scope_id: StringName, root_ids: Array[StringName], t_s: float) -> void:
	sync_tracked_roots(scope_id, root_ids, t_s)
	set_major_body_resident_roots(_registry_root_ids_from(_normalized_root_ids(root_ids)), t_s)


func sync_tracked_roots(scope_id: StringName, root_ids: Array[StringName], t_s: float) -> void:
	if not _configured:
		return
	if scope_id != _scope_id:
		reset_for_world(scope_id, root_ids, t_s)
		return
	var next_roots: Array[StringName] = _normalized_root_ids(root_ids)
	var changed: bool = not _root_id_arrays_equal(_tracked_root_ids, next_roots)
	for root_id in next_roots:
		if _has_root_state(root_id):
			continue
		_spawn_root(root_id, t_s)
		changed = true

	if changed:
		_tracked_root_ids = next_roots
		_major_body_resident_root_ids = _intersection_root_ids(_major_body_resident_root_ids, _tracked_root_ids)
		_revision += 1
		_update_active_counter()


func set_major_body_resident_roots(root_ids: Array[StringName], _t_s: float = 0.0) -> void:
	if not _configured:
		return
	var next_roots: Array[StringName] = _registry_root_ids_from(_normalized_root_ids(root_ids))
	var previous_roots: Array[StringName] = _major_body_resident_root_ids.duplicate()
	var changed: bool = not _root_id_arrays_equal(previous_roots, next_roots)
	_major_body_resident_root_ids = next_roots
	for root_id in _tracked_root_ids:
		if next_roots.has(root_id):
			if not previous_roots.has(root_id) or not _influence_zones_by_root.has(root_id) or _influence_zones_for_root(root_id).is_empty():
				_rebuild_influence_index_for_root(root_id)
		else:
			_influence_zones_by_root[root_id] = []
			_clear_attractor_sets_for_root(root_id)
	if changed:
		_revision += 1
	_update_active_counter()


func advance_to_time(t_s: float, dt_s: float) -> void:
	if not _configured or dt_s <= 0.0:
		return
	_relative_state_cache.clear()
	var tick_index: int = int(_perf_counters.get(PERF_KEY_ADVANCE_TICKS, 0))
	var changed: bool = false
	for id in _state_order:
		var state = _states_by_id.get(id, null)
		if state == null or not state.is_active:
			continue
		if not _tracked_root_ids.has(state.root_id):
			continue
		if _can_fast_linear_drift(state):
			_advance_fast_linear_drift(state, t_s, dt_s)
			changed = true
			continue
		var attractor_ids: Array[StringName] = state.current_attractor_ids
		if _should_refresh_attractors(state, tick_index):
			var previous_attractor_ids: Array[StringName] = attractor_ids.duplicate()
			attractor_ids = _select_attractors_for(state)
			if not _string_name_arrays_equal(previous_attractor_ids, attractor_ids):
				_perf_counters[PERF_KEY_ATTRACTOR_SET_CHANGES] = int(_perf_counters.get(PERF_KEY_ATTRACTOR_SET_CHANGES, 0)) + 1
			state.current_attractor_ids = attractor_ids
		_perf_counters[PERF_KEY_TOTAL_ACTIVE_ATTRACTORS_PER_TICK] = int(_perf_counters.get(PERF_KEY_TOTAL_ACTIVE_ATTRACTORS_PER_TICK, 0)) + attractor_ids.size()
		_perf_counters[PERF_KEY_BH_ATTRACTOR_COUNT] = int(_perf_counters.get(PERF_KEY_BH_ATTRACTOR_COUNT, 0)) + _black_hole_attractor_count(attractor_ids)
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
		if bool(result.get("free_drift", false)):
			_perf_counters[PERF_KEY_FREE_DRIFT_COUNT] = int(_perf_counters.get(PERF_KEY_FREE_DRIFT_COUNT, 0)) + 1
		if bool(result.get("hit_substep_cap", false)):
			_perf_counters[PERF_KEY_SUBSTEP_CAP_HITS] = int(_perf_counters.get(PERF_KEY_SUBSTEP_CAP_HITS, 0)) + 1
		if _is_far_retired(state):
			state.is_active = false
			state.current_attractor_ids.clear()
			_perf_counters[PERF_KEY_FAR_RETIRED_COUNT] = int(_perf_counters.get(PERF_KEY_FAR_RETIRED_COUNT, 0)) + 1
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
		if not _tracked_root_ids.has(state.root_id):
			continue
		var def = _defs_by_id.get(id, null)
		entries.append(state.clone_snapshot(def))
	return {
		"scope_id": _scope_id,
		"tracked_root_ids": _tracked_root_ids.duplicate(),
		"major_body_resident_root_ids": _major_body_resident_root_ids.duplicate(),
		"resident_root_ids": _major_body_resident_root_ids.duplicate(),
		"revision": _revision,
		"count": entries.size(),
		"entries": entries,
	}


func get_perf_counter_snapshot() -> Dictionary:
	var out: Dictionary = _perf_counters.duplicate(true)
	out["revision"] = _revision
	out["tracked_root_count"] = _tracked_root_ids.size()
	out["resident_root_count"] = _major_body_resident_root_ids.size()
	out["major_body_resident_root_count"] = _major_body_resident_root_ids.size()
	out["catalog_root_count"] = _root_spawn_catalog_by_root.size()
	out["total_state_count"] = _state_order.size()
	out["stored_root_count"] = _stored_root_count()
	out["influence_zone_count"] = _resident_influence_zone_count()
	return out


func get_debug_snapshot() -> Dictionary:
	return {
		"scope_id": _scope_id,
		"tracked_root_ids": _tracked_root_ids.duplicate(),
		"major_body_resident_root_ids": _major_body_resident_root_ids.duplicate(),
		"resident_root_ids": _major_body_resident_root_ids.duplicate(),
		"root_spawn_catalog_scope_id": _root_spawn_catalog_scope_id,
		"root_spawn_catalog_root_count": _root_spawn_catalog_by_root.size(),
		"revision": _revision,
		"state_count": _state_order.size(),
		"perf": get_perf_counter_snapshot(),
	}


func _spawn_root(root_id: StringName, t_s: float) -> void:
	if root_id == StringName("") or not _has_spawn_source_for_root(root_id):
		return
	if not _influence_zones_by_root.has(root_id):
		_influence_zones_by_root[root_id] = []
	var spawn_origins: Array[StringName] = _select_spawn_origins(root_id)
	if spawn_origins.is_empty():
		spawn_origins.append(root_id)
	for idx in range(ASTEROIDS_PER_ROOT):
		var spawn_origin_id: StringName = spawn_origins[idx % spawn_origins.size()]
		var seed: int = _stable_hash("%s/%s/%d" % [str(_scope_id), str(root_id), idx])
		var asteroid_id: StringName = _asteroid_id_for(root_id, idx)
		if _states_by_id.has(asteroid_id):
			continue
		var def = ASTEROID_DEF_SCRIPT.new(asteroid_id, root_id, spawn_origin_id, seed)
		def.radius_m = _range_from_seed(seed, 1, 45.0, 260.0)
		def.mass_kg = 4.0 / 3.0 * PI * def.radius_m * def.radius_m * def.radius_m * 2500.0
		def.visual_class = _visual_class_from_seed(seed)
		var state = _build_initial_state(def, t_s)
		_defs_by_id[asteroid_id] = def
		_states_by_id[asteroid_id] = state
		_state_order.append(asteroid_id)
		_perf_counters[PERF_KEY_SPAWNED] = int(_perf_counters.get(PERF_KEY_SPAWNED, 0)) + 1


func _despawn_root(root_id: StringName) -> void:
	for id in _state_order.duplicate():
		var state = _states_by_id.get(id, null)
		if state == null or state.root_id != root_id:
			continue
		_states_by_id.erase(id)
		_defs_by_id.erase(id)
		_state_order.erase(id)
		_perf_counters[PERF_KEY_DESPAWNED] = int(_perf_counters.get(PERF_KEY_DESPAWNED, 0)) + 1
	_tracked_root_ids.erase(root_id)
	_major_body_resident_root_ids.erase(root_id)


func _has_root_state(root_id: StringName) -> bool:
	for id in _state_order:
		var state = _states_by_id.get(id, null)
		if state != null and state.root_id == root_id:
			return true
	return false


func _stored_root_count() -> int:
	var roots: Dictionary = {}
	for id in _state_order:
		var state = _states_by_id.get(id, null)
		if state != null and state.root_id != StringName(""):
			roots[state.root_id] = true
	return roots.size()


func _resident_influence_zone_count() -> int:
	var count: int = 0
	for root_id in _major_body_resident_root_ids:
		count += _influence_zones_for_root(root_id).size()
	return count


func _rebuild_influence_index_for_root(root_id: StringName) -> void:
	var zones: Array = []
	if _registry == null or root_id == StringName("") or not _registry.has_body(root_id):
		_influence_zones_by_root[root_id] = zones
		return
	for body_id in _registry.get_update_order():
		var def: BodyDef = _registry.get_def(body_id)
		if def == null or not _is_v1_attractor_kind(def.kind):
			continue
		if _topology.root_id_of(body_id) != root_id:
			continue
		var enter_radius_m: float = _influence_radius_m(def)
		if enter_radius_m <= 0.0:
			continue
		zones.append({
			"id": body_id,
			"kind": def.kind,
			"enter_radius_m": enter_radius_m,
			"exit_radius_m": enter_radius_m * INFLUENCE_EXIT_FACTOR,
			"mu_m3ps2": _asteroid_effective_mu_m3ps2(def, enter_radius_m),
			"raw_mu_m3ps2": UnitSystem.mu_from_mass(maxf(def.mass_kg, 0.0)),
			"bh_mu_samples": _black_hole_mu_fit_samples(body_id) if def.kind == BodyType.Kind.BLACK_HOLE else [],
		})
	_influence_zones_by_root[root_id] = zones
	_perf_counters[PERF_KEY_INFLUENCE_INDEX_REBUILDS] = int(_perf_counters.get(PERF_KEY_INFLUENCE_INDEX_REBUILDS, 0)) + 1


func _influence_zones_for_root(root_id: StringName) -> Array:
	return _influence_zones_by_root.get(root_id, [])


func _influence_zone_for_id(root_id: StringName, body_id: StringName) -> Dictionary:
	for zone in _influence_zones_for_root(root_id):
		if typeof(zone) == TYPE_DICTIONARY and zone.get("id", StringName("")) == body_id:
			return zone
	return {}


func _select_spawn_origins(root_id: StringName) -> Array[StringName]:
	var origins: Array[StringName] = []
	if _registry != null:
		for id in _registry.get_update_order():
			var def: BodyDef = _registry.get_def(id)
			if def == null or def.kind != BodyType.Kind.STAR:
				continue
			if _topology.root_id_of(id) == root_id:
				origins.append(id)
	if origins.is_empty():
		for def in _catalog_defs_for_root(root_id):
			if def != null and def.kind == BodyType.Kind.STAR:
				origins.append(def.id)
	if origins.is_empty():
		origins.append(root_id)
	return origins


func _build_initial_state(def, t_s: float):
	var state = ASTEROID_STATE_SCRIPT.new()
	state.id = def.id
	state.root_id = def.root_id
	state.anchor_id = def.root_id
	state.last_update_time_s = t_s
	var bounds: Dictionary = _spawn_radius_bounds(def.spawn_origin_id, def.root_id)
	var inner_m: float = float(bounds.get("inner_m", FALLBACK_BELT_INNER_M))
	var outer_m: float = maxf(float(bounds.get("outer_m", FALLBACK_BELT_OUTER_M)), inner_m * 1.05)
	var radius_m: float = _range_from_seed(def.seed, 2, inner_m, outer_m)
	var phase_rad: float = _range_from_seed(def.seed, 3, 0.0, TAU)
	var z_m: float = _range_from_seed(def.seed, 4, -0.015, 0.015) * radius_m
	var local_x_m: float = cos(phase_rad) * radius_m
	var local_y_m: float = sin(phase_rad) * radius_m
	var local_z_m: float = z_m
	var origin_relative: Dictionary = _resolve_body_relative_to_anchor_cached(def.spawn_origin_id, def.root_id)
	if not bool(origin_relative.get("ok", false)):
		origin_relative = _resolve_catalog_body_relative_to_root(def.spawn_origin_id, def.root_id, t_s)
	if not bool(origin_relative.get("ok", false)):
		if _catalog_def_for_id(def.root_id, def.spawn_origin_id) != null:
			push_warning("AsteroidSimulationService: Catalog-Spawn-Origin '%s' konnte nicht analytisch im Root '%s' aufgeloest werden" % [def.spawn_origin_id, def.root_id])
		origin_relative = {
			"ok": true,
			"x_m": 0.0,
			"y_m": 0.0,
			"z_m": 0.0,
			"vx_mps": 0.0,
			"vy_mps": 0.0,
			"vz_mps": 0.0,
		}
	state.x_m = float(origin_relative.get("x_m", 0.0)) + local_x_m
	state.y_m = float(origin_relative.get("y_m", 0.0)) + local_y_m
	state.z_m = float(origin_relative.get("z_m", 0.0)) + local_z_m

	var origin_def: BodyDef = _body_def_for(def.root_id, def.spawn_origin_id)
	var origin_mass_kg: float = origin_def.mass_kg if origin_def != null and _is_v1_attractor_kind(origin_def.kind) else UnitSystem.SOLAR_MASS_KG
	var mu: float = UnitSystem.mu_from_mass(maxf(origin_mass_kg, 1.0))
	var circular_speed_mps: float = sqrt(mu / maxf(radius_m, 1.0))
	var wanderer_bias: float = _range_from_seed(def.seed, 9, 0.0, 1.0)
	var tangential_speed_mps: float = circular_speed_mps * _range_from_seed(
		def.seed,
		5,
		1.18 if wanderer_bias < 0.24 else 0.96,
		1.65 if wanderer_bias < 0.24 else 1.22
	)
	var radial_speed_mps: float = circular_speed_mps * _range_from_seed(
		def.seed,
		7,
		-0.45 if wanderer_bias < 0.24 else -0.18,
		0.45 if wanderer_bias < 0.24 else 0.18
	)
	var direction: float = -1.0 if _range_from_seed(def.seed, 8, 0.0, 1.0) < 0.18 else 1.0
	var tilt: float = _range_from_seed(def.seed, 6, -0.10, 0.10)
	state.vx_mps = float(origin_relative.get("vx_mps", 0.0)) + cos(phase_rad) * radial_speed_mps - sin(phase_rad) * tangential_speed_mps * direction
	state.vy_mps = float(origin_relative.get("vy_mps", 0.0)) + sin(phase_rad) * radial_speed_mps + cos(phase_rad) * tangential_speed_mps * direction
	state.vz_mps = float(origin_relative.get("vz_mps", 0.0)) + circular_speed_mps * tilt
	return state


func _spawn_radius_bounds(anchor_id: StringName, root_id: StringName = StringName("")) -> Dictionary:
	var min_a: float = INF
	var max_a: float = 0.0
	if _registry != null and _registry.has_body(anchor_id):
		for child_id in _registry.get_children_of(anchor_id):
			var child_def: BodyDef = _registry.get_def(child_id)
			if child_def == null or child_def.orbit_profile == null:
				continue
			if child_def.kind != BodyType.Kind.PLANET and child_def.kind != BodyType.Kind.MOON:
				continue
			var axis_m: float = maxf(_orbit_radius_m(child_def), 1.0)
			min_a = minf(min_a, axis_m)
			max_a = maxf(max_a, axis_m)
	if (not is_finite(min_a) or max_a <= 0.0) and root_id != StringName(""):
		for child_def in _catalog_children_of(root_id, anchor_id):
			if child_def == null or child_def.orbit_profile == null:
				continue
			if child_def.kind != BodyType.Kind.PLANET and child_def.kind != BodyType.Kind.MOON:
				continue
			var axis_m: float = maxf(_orbit_radius_m(child_def), 1.0)
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
	var selected: Array[StringName] = []
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

	var weakest_idx: int = _weakest_optional_index(selected, candidates)
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
	for id in state.current_attractor_ids:
		if id == StringName("") or not _registry.has_body(id):
			return false
		var def: BodyDef = _registry.get_def(id)
		if def == null or not _is_v1_attractor_kind(def.kind):
			return false
		if _topology.root_id_of(id) != state.root_id:
			return false
		if not _candidate_is_within_influence(state, id, true):
			return false
	return true


func _rank_attractor_candidates(state) -> Array:
	var out: Array = []
	for zone in _influence_zones_for_root(state.root_id):
		if typeof(zone) != TYPE_DICTIONARY:
			continue
		var body_id: StringName = zone.get("id", StringName(""))
		var relative: Dictionary = _resolve_body_relative_to_anchor_cached(body_id, state.anchor_id)
		if not bool(relative.get("ok", false)):
			continue
		var dx: float = float(relative.get("x_m", 0.0)) - state.x_m
		var dy: float = float(relative.get("y_m", 0.0)) - state.y_m
		var dz: float = float(relative.get("z_m", 0.0)) - state.z_m
		var distance2_m2: float = maxf(dx * dx + dy * dy + dz * dz, 1.0)
		_perf_counters[PERF_KEY_ATTRACTOR_CHECKS] = int(_perf_counters.get(PERF_KEY_ATTRACTOR_CHECKS, 0)) + 1
		_perf_counters[PERF_KEY_INFLUENCE_ZONE_CHECKS] = int(_perf_counters.get(PERF_KEY_INFLUENCE_ZONE_CHECKS, 0)) + 1
		var active_radius_m: float = float(zone.get("exit_radius_m", 0.0)) if state.current_attractor_ids.has(body_id) else float(zone.get("enter_radius_m", 0.0))
		if distance2_m2 > active_radius_m * active_radius_m:
			continue
		var score: float = _zone_effective_mu_m3ps2(zone, sqrt(distance2_m2)) / distance2_m2
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
		var zone: Dictionary = _influence_zone_for_id(state.root_id, id)
		if zone.is_empty():
			continue
		var relative: Dictionary = _resolve_body_relative_to_anchor_cached(id, state.anchor_id)
		if not bool(relative.get("ok", false)):
			continue
		var dx: float = float(relative.get("x_m", 0.0)) - state.x_m
		var dy: float = float(relative.get("y_m", 0.0)) - state.y_m
		var dz: float = float(relative.get("z_m", 0.0)) - state.z_m
		var distance_m: float = maxf(sqrt(dx * dx + dy * dy + dz * dz), 1.0)
		out.append(float(relative.get("x_m", 0.0)))
		out.append(float(relative.get("y_m", 0.0)))
		out.append(float(relative.get("z_m", 0.0)))
		out.append(_zone_effective_mu_m3ps2(zone, distance_m))
	return out


func _can_fast_linear_drift(state) -> bool:
	return state != null \
		and state.current_attractor_ids.is_empty() \
		and _influence_zones_for_root(state.root_id).is_empty()


func _advance_fast_linear_drift(state, t_s: float, dt_s: float) -> void:
	state.x_m += state.vx_mps * dt_s
	state.y_m += state.vy_mps * dt_s
	state.z_m += state.vz_mps * dt_s
	state.last_update_time_s = t_s
	_perf_counters[PERF_KEY_FREE_DRIFT_COUNT] = int(_perf_counters.get(PERF_KEY_FREE_DRIFT_COUNT, 0)) + 1
	if _is_far_retired(state):
		state.is_active = false
		state.current_attractor_ids.clear()
		_perf_counters[PERF_KEY_FAR_RETIRED_COUNT] = int(_perf_counters.get(PERF_KEY_FAR_RETIRED_COUNT, 0)) + 1


func _zone_effective_mu_m3ps2(zone: Dictionary, distance_m: float) -> float:
	var kind: int = int(zone.get("kind", -1))
	if kind != BodyType.Kind.BLACK_HOLE:
		return float(zone.get("mu_m3ps2", 0.0))
	var fallback_mu: float = float(zone.get("raw_mu_m3ps2", 0.0))
	var samples: Array = zone.get("bh_mu_samples", [])
	var fitted_mu: float = _black_hole_fit_from_samples(samples, distance_m, fallback_mu)
	if fitted_mu <= 0.0:
		return fallback_mu
	return fitted_mu * BH_FLYBY_GRAVITY_FACTOR


func _asteroid_effective_mu_m3ps2(def: BodyDef, distance_m: float) -> float:
	if def == null:
		return 0.0
	if def.kind != BodyType.Kind.BLACK_HOLE:
		return UnitSystem.mu_from_mass(maxf(def.mass_kg, 0.0))
	var fitted_mu: float = _black_hole_fitted_mu_m3ps2(def, distance_m)
	if fitted_mu <= 0.0:
		return UnitSystem.mu_from_mass(maxf(def.mass_kg, 0.0))
	return fitted_mu * BH_FLYBY_GRAVITY_FACTOR


func _black_hole_fitted_mu_m3ps2(def: BodyDef, distance_m: float) -> float:
	if def == null or def.kind != BodyType.Kind.BLACK_HOLE:
		return 0.0
	var samples: Array = _black_hole_mu_fit_samples(def.id)
	var fallback_mu: float = UnitSystem.mu_from_mass(maxf(def.mass_kg, 0.0))
	return _black_hole_fit_from_samples(samples, distance_m, fallback_mu)


static func _black_hole_fit_from_samples(samples: Array, distance_m: float, fallback_mu: float) -> float:
	if samples.is_empty():
		return fallback_mu
	var clamped_distance_m: float = maxf(distance_m, 1.0)
	if samples.size() == 1:
		return float(samples[0].get("mu_m3ps2", 0.0))
	var first: Dictionary = samples[0]
	var last: Dictionary = samples[samples.size() - 1]
	if clamped_distance_m <= float(first.get("radius_m", 1.0)):
		return float(first.get("mu_m3ps2", 0.0))
	if clamped_distance_m >= float(last.get("radius_m", 1.0)):
		return float(last.get("mu_m3ps2", 0.0))
	for idx in range(samples.size() - 1):
		var left: Dictionary = samples[idx]
		var right: Dictionary = samples[idx + 1]
		var left_r: float = float(left.get("radius_m", 1.0))
		var right_r: float = float(right.get("radius_m", 1.0))
		if clamped_distance_m < left_r or clamped_distance_m > right_r:
			continue
		var log_left_r: float = log(left_r)
		var log_right_r: float = log(right_r)
		var t: float = 0.0 if is_equal_approx(log_left_r, log_right_r) else clampf((log(clamped_distance_m) - log_left_r) / (log_right_r - log_left_r), 0.0, 1.0)
		var log_mu: float = lerpf(log(float(left.get("mu_m3ps2", 1.0))), log(float(right.get("mu_m3ps2", 1.0))), t)
		return exp(log_mu)
	return float(last.get("mu_m3ps2", 0.0))


func _black_hole_mu_fit_samples(black_hole_id: StringName) -> Array:
	var samples: Array = []
	if _registry == null or black_hole_id == StringName(""):
		return samples
	for child_id in _registry.get_children_of(black_hole_id):
		var child_def: BodyDef = _registry.get_def(child_id)
		if child_def == null or child_def.kind != BodyType.Kind.STAR or child_def.parent_id != black_hole_id:
			continue
		var profile: OrbitProfile = child_def.orbit_profile
		if profile == null or profile.authored_radius_m <= 0.0 or profile.authored_period_s <= 0.0:
			continue
		samples.append({
			"id": child_id,
			"radius_m": float(profile.authored_radius_m),
			"mu_m3ps2": _authored_orbit_mu_m3ps2(float(profile.authored_radius_m), float(profile.authored_period_s)),
		})
	samples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("radius_m", 0.0)) < float(b.get("radius_m", 0.0))
	)
	return samples


static func _authored_orbit_mu_m3ps2(radius_m: float, period_s: float) -> float:
	if radius_m <= 0.0 or period_s <= 0.0:
		return 0.0
	return 4.0 * PI * PI * radius_m * radius_m * radius_m / (period_s * period_s)


static func _weakest_optional_index(selected: Array[StringName], candidates: Array) -> int:
	var weakest_idx: int = -1
	var weakest_score: float = INF
	for idx in range(selected.size()):
		var id: StringName = selected[idx]
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


func _black_hole_attractor_count(attractor_ids: Array[StringName]) -> int:
	var count: int = 0
	for id in attractor_ids:
		var def: BodyDef = _registry.get_def(id) if _registry != null and _registry.has_body(id) else null
		if def != null and def.kind == BodyType.Kind.BLACK_HOLE:
			count += 1
	return count


func _resolve_body_relative_to_anchor_cached(body_id: StringName, anchor_id: StringName) -> Dictionary:
	var cache_key: String = "%s|%s" % [str(anchor_id), str(body_id)]
	if _relative_state_cache.has(cache_key):
		return _relative_state_cache[cache_key]
	var resolved: Dictionary = _relative_resolver.resolve_body_relative_to_anchor(body_id, anchor_id)
	_relative_state_cache[cache_key] = resolved
	return resolved


func _candidate_is_within_influence(state, body_id: StringName, use_exit_radius: bool) -> bool:
	var zone: Dictionary = _influence_zone_for_id(state.root_id, body_id)
	if zone.is_empty():
		return false
	var relative: Dictionary = _resolve_body_relative_to_anchor_cached(body_id, state.anchor_id)
	if not bool(relative.get("ok", false)):
		return false
	var dx: float = float(relative.get("x_m", 0.0)) - state.x_m
	var dy: float = float(relative.get("y_m", 0.0)) - state.y_m
	var dz: float = float(relative.get("z_m", 0.0)) - state.z_m
	var radius_m: float = float(zone.get("exit_radius_m", 0.0)) if use_exit_radius else float(zone.get("enter_radius_m", 0.0))
	return dx * dx + dy * dy + dz * dz <= radius_m * radius_m


func _influence_radius_m(def: BodyDef) -> float:
	if def == null:
		return 0.0
	match def.kind:
		BodyType.Kind.BLACK_HOLE:
			var outer_root_m: float = _max_child_orbit_radius_m(def.id)
			if outer_root_m <= 0.0:
				return BLACK_HOLE_FALLBACK_INFLUENCE_M
			return maxf(BLACK_HOLE_FALLBACK_INFLUENCE_M, outer_root_m * BLACK_HOLE_INFLUENCE_RADIUS_MULTIPLIER)
		BodyType.Kind.STAR:
			var outer_m: float = _max_child_orbit_radius_m(def.id)
			if outer_m <= 0.0:
				return STAR_FALLBACK_INFLUENCE_M
			return maxf(outer_m * STAR_INFLUENCE_RADIUS_MULTIPLIER, outer_m + STAR_INFLUENCE_PADDING_M)
		BodyType.Kind.PLANET:
			return maxf(
				maxf(def.radius_m, 1.0) * PLANET_RADIUS_INFLUENCE_MULTIPLIER,
				_max_child_orbit_radius_m(def.id) * PLANET_MOON_ORBIT_INFLUENCE_MULTIPLIER
			)
		BodyType.Kind.MOON:
			return maxf(maxf(def.radius_m, 1.0) * MOON_RADIUS_INFLUENCE_MULTIPLIER, MOON_MIN_INFLUENCE_M)
		_:
			return 0.0


func _max_child_orbit_radius_m(parent_id: StringName) -> float:
	var out: float = 0.0
	if _registry == null:
		return out
	for child_id in _registry.get_children_of(parent_id):
		var child_def: BodyDef = _registry.get_def(child_id)
		if child_def == null:
			continue
		out = maxf(out, _orbit_radius_m(child_def))
	return out


func _has_spawn_source_for_root(root_id: StringName) -> bool:
	if _registry != null and _registry.has_body(root_id):
		return true
	return _root_spawn_catalog_by_root.has(root_id)


func _catalog_defs_for_root(root_id: StringName) -> Array:
	return _root_spawn_catalog_by_root.get(root_id, [])


func _catalog_def_for_id(root_id: StringName, body_id: StringName) -> BodyDef:
	for raw_def in _catalog_defs_for_root(root_id):
		var def: BodyDef = raw_def as BodyDef
		if def != null and def.id == body_id:
			return def
	return null


func _body_def_for(root_id: StringName, body_id: StringName) -> BodyDef:
	if _registry != null and _registry.has_body(body_id):
		return _registry.get_def(body_id)
	return _catalog_def_for_id(root_id, body_id)


func _catalog_children_of(root_id: StringName, parent_id: StringName) -> Array[BodyDef]:
	var out: Array[BodyDef] = []
	for raw_def in _catalog_defs_for_root(root_id):
		var def: BodyDef = raw_def as BodyDef
		if def != null and def.parent_id == parent_id:
			out.append(def)
	return out


func _resolve_catalog_body_relative_to_root(body_id: StringName, root_id: StringName, t_s: float, depth: int = 0) -> Dictionary:
	if body_id == StringName("") or root_id == StringName("") or depth > 64:
		return {"ok": false}
	if body_id == root_id:
		return _zero_relative_state()
	var def: BodyDef = _catalog_def_for_id(root_id, body_id)
	if def == null:
		return {"ok": false}
	if def.parent_id == StringName(""):
		return _zero_relative_state() if def.id == root_id else {"ok": false}
	var parent_relative: Dictionary = _resolve_catalog_body_relative_to_root(def.parent_id, root_id, t_s, depth + 1)
	if not bool(parent_relative.get("ok", false)):
		return {"ok": false}
	var local_state: Dictionary = _evaluate_catalog_orbit_state(def, root_id, t_s)
	if not bool(local_state.get("ok", false)):
		return {"ok": false}
	return {
		"ok": true,
		"x_m": float(parent_relative.get("x_m", 0.0)) + float(local_state.get("x_m", 0.0)),
		"y_m": float(parent_relative.get("y_m", 0.0)) + float(local_state.get("y_m", 0.0)),
		"z_m": float(parent_relative.get("z_m", 0.0)) + float(local_state.get("z_m", 0.0)),
		"vx_mps": float(parent_relative.get("vx_mps", 0.0)) + float(local_state.get("vx_mps", 0.0)),
		"vy_mps": float(parent_relative.get("vy_mps", 0.0)) + float(local_state.get("vy_mps", 0.0)),
		"vz_mps": float(parent_relative.get("vz_mps", 0.0)) + float(local_state.get("vz_mps", 0.0)),
	}


func _evaluate_catalog_orbit_state(def: BodyDef, root_id: StringName, t_s: float) -> Dictionary:
	if def == null or def.orbit_profile == null:
		return {"ok": false}
	var profile: OrbitProfile = def.orbit_profile
	match profile.mode:
		OrbitMode.Kind.AUTHORED_ORBIT:
			var authored_pos: Vector3 = OrbitMath.authored_circular_position(
				profile.authored_radius_m,
				profile.authored_period_s,
				profile.authored_phase_rad,
				t_s
			)
			var authored_pos_prev: Vector3 = OrbitMath.authored_circular_position(
				profile.authored_radius_m,
				profile.authored_period_s,
				profile.authored_phase_rad,
				t_s - VELOCITY_SEED_EPSILON_S
			)
			var authored_pos_next: Vector3 = OrbitMath.authored_circular_position(
				profile.authored_radius_m,
				profile.authored_period_s,
				profile.authored_phase_rad,
				t_s + VELOCITY_SEED_EPSILON_S
			)
			var authored_vel: Vector3 = (authored_pos_next - authored_pos_prev) / (2.0 * VELOCITY_SEED_EPSILON_S)
			return _relative_state_from_vectors(authored_pos, authored_vel)
		OrbitMode.Kind.KEPLER_APPROX:
			var parent_def: BodyDef = _body_def_for(root_id, def.parent_id)
			if parent_def == null:
				return {"ok": false}
			var mu: float = UnitSystem.mu_from_mass(maxf(parent_def.mass_kg, 0.0))
			if mu <= 0.0:
				return {"ok": false}
			var kepler_pos: Vector3 = OrbitMath.kepler_position(
				profile.semi_major_axis_m,
				profile.eccentricity,
				profile.inclination_rad,
				profile.longitude_ascending_node_rad,
				profile.argument_periapsis_rad,
				profile.mean_anomaly_epoch_rad,
				profile.epoch_s,
				mu,
				t_s
			)
			var kepler_pos_prev: Vector3 = OrbitMath.kepler_position(
				profile.semi_major_axis_m,
				profile.eccentricity,
				profile.inclination_rad,
				profile.longitude_ascending_node_rad,
				profile.argument_periapsis_rad,
				profile.mean_anomaly_epoch_rad,
				profile.epoch_s,
				mu,
				t_s - VELOCITY_SEED_EPSILON_S
			)
			var kepler_pos_next: Vector3 = OrbitMath.kepler_position(
				profile.semi_major_axis_m,
				profile.eccentricity,
				profile.inclination_rad,
				profile.longitude_ascending_node_rad,
				profile.argument_periapsis_rad,
				profile.mean_anomaly_epoch_rad,
				profile.epoch_s,
				mu,
				t_s + VELOCITY_SEED_EPSILON_S
			)
			var kepler_vel: Vector3 = (kepler_pos_next - kepler_pos_prev) / (2.0 * VELOCITY_SEED_EPSILON_S)
			return _relative_state_from_vectors(kepler_pos, kepler_vel)
		_:
			return {"ok": false}


static func _relative_state_from_vectors(pos: Vector3, vel: Vector3) -> Dictionary:
	return {
		"ok": true,
		"x_m": pos.x,
		"y_m": pos.y,
		"z_m": pos.z,
		"vx_mps": vel.x,
		"vy_mps": vel.y,
		"vz_mps": vel.z,
	}


static func _zero_relative_state() -> Dictionary:
	return {
		"ok": true,
		"x_m": 0.0,
		"y_m": 0.0,
		"z_m": 0.0,
		"vx_mps": 0.0,
		"vy_mps": 0.0,
		"vz_mps": 0.0,
	}


static func _orbit_radius_m(def: BodyDef) -> float:
	if def == null or def.orbit_profile == null:
		return 0.0
	var profile: OrbitProfile = def.orbit_profile
	if profile.authored_radius_m > 0.0:
		return float(profile.authored_radius_m)
	return maxf(float(profile.semi_major_axis_m), 0.0)


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


func _registry_root_ids_from(root_ids: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	if _registry == null:
		return out
	for root_id in root_ids:
		if root_id == StringName("") or out.has(root_id):
			continue
		if _registry.has_body(root_id):
			out.append(root_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return out


static func _intersection_root_ids(a: Array[StringName], b: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for root_id in a:
		if root_id == StringName("") or out.has(root_id) or not b.has(root_id):
			continue
		out.append(root_id)
	out.sort_custom(func(left: StringName, right: StringName) -> bool: return str(left) < str(right))
	return out


func _clear_attractor_sets_for_root(root_id: StringName) -> void:
	for id in _state_order:
		var state = _states_by_id.get(id, null)
		if state != null and state.root_id == root_id:
			state.current_attractor_ids.clear()


static func _to_string_name(value) -> StringName:
	if typeof(value) == TYPE_STRING_NAME:
		return value
	return StringName(str(value))


static func _root_id_arrays_equal(a: Array[StringName], b: Array[StringName]) -> bool:
	if a.size() != b.size():
		return false
	for idx in range(a.size()):
		if a[idx] != b[idx]:
			return false
	return true


static func _string_name_arrays_equal(a: Array[StringName], b: Array[StringName]) -> bool:
	if a.size() != b.size():
		return false
	for idx in range(a.size()):
		if a[idx] != b[idx]:
			return false
	return true


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


static func _is_far_retired(state) -> bool:
	var r2: float = state.x_m * state.x_m + state.y_m * state.y_m + state.z_m * state.z_m
	return r2 > ASTEROID_FAR_RETIRE_RADIUS_M * ASTEROID_FAR_RETIRE_RADIUS_M


func _update_active_counter() -> void:
	var count: int = 0
	for id in _state_order:
		var state = _states_by_id.get(id, null)
		if state != null and state.is_active and _tracked_root_ids.has(state.root_id):
			count += 1
	_perf_counters[PERF_KEY_ACTIVE_ASTEROIDS] = count


func _reset_perf_counters() -> void:
	for key in _perf_counters.keys():
		_perf_counters[key] = 0
