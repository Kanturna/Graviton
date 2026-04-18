class_name OrbitService
extends Node

# Einzige Stelle, die BodyState.position_parent_frame_m schreibt.
# Reagiert auf TimeService.sim_tick und iteriert die Bodies in der
# Topologie-Reihenfolge aus UniverseRegistry (Parent vor Kind).
#
# Fuer den Foundation-Slice:
#   - AUTHORED_ORBIT: OrbitMath.authored_circular_position
#   - KEPLER_APPROX:  OrbitMath.kepler_position
#   - NUMERIC_LOCAL:  minimaler Velocity-Verlet-Pfad fuer explizit
#                     gewuenschte KEPLER_APPROX-Bodies.
#
# P10-Guardrails:
#   - Anti-Thrashing lebt bewusst hier im OrbitService, nicht im
#     BubbleActivationSet.
#   - Overspeed-Handling bleibt Cap+Warn als Best-Effort-Policy:
#     ein gecappter Body bleibt numerisch, aber das Warning signalisiert,
#     dass time_scale oder Substep-Budget angepasst werden sollten.
#   - Warning-Dedup ist Absicht: nur der Eintritt in den gecappten
#     Zustand warnt, nicht jeder Folgetick.

const VELOCITY_SEED_EPSILON_S: float = 1.0
# Zentrale finite Differenz fuer das analytische Velocity-Seeding beim
# Eintritt in NUMERIC_LOCAL und beim Rueckwechsel nach KEPLER_APPROX.
const LOCAL_ORBIT_INTEGRATOR_SCRIPT := preload("res://src/sim/orbit/local_orbit_integrator.gd")
const NO_REQUEST_TICK: int = -2147483648

@export_range(0.0, 3600.0, 1.0, "or_greater") var numeric_local_target_substep_s: float = 10.0
@export_range(1, 4096, 1, "or_greater") var numeric_local_max_substeps_per_tick: int = 64
@export_range(0, 64, 1, "or_greater") var numeric_local_missing_request_grace_ticks: int = 1

var _registry: Node = null
var _time: Node = null
var _configured: bool = false
var _requested_numeric_local_ids: Dictionary = {}
var _last_requested_tick_by_id: Dictionary = {}
var _substep_cap_warning_active_by_id: Dictionary = {}
var _sim_tick_index: int = 0


func configure(registry: Node, time_service: Node) -> void:
	assert(registry != null, "OrbitService.configure: registry is null")
	assert(time_service != null, "OrbitService.configure: time_service is null")
	if _time != null and _time.sim_tick.is_connected(_on_sim_tick):
		_time.sim_tick.disconnect(_on_sim_tick)
	_registry = registry
	_time = time_service
	_requested_numeric_local_ids.clear()
	_last_requested_tick_by_id.clear()
	_substep_cap_warning_active_by_id.clear()
	_sim_tick_index = 0
	if not _time.sim_tick.is_connected(_on_sim_tick):
		_time.sim_tick.connect(_on_sim_tick)
	_configured = true


func _exit_tree() -> void:
	if _time != null and _time.sim_tick.is_connected(_on_sim_tick):
		_time.sim_tick.disconnect(_on_sim_tick)


func _on_sim_tick(_dt: float) -> void:
	if not _configured:
		return
	_sim_tick_index += 1
	var t: float = _time.sim_time_s
	for id in _registry.get_update_order():
		var state: BodyState = _registry.get_state(id)
		var def: BodyDef = _registry.get_def(id)
		if state == null or def == null:
			continue
		update_body(state, def, t)


func request_numeric_local_candidates(ids: Array[StringName]) -> void:
	# Ersetzt das gewuenschte Numeric-Set vollstaendig.
	_requested_numeric_local_ids.clear()
	if _registry == null:
		return
	for id in ids:
		if _requested_numeric_local_ids.has(id):
			continue
		var def: BodyDef = _registry.get_def(id)
		if def == null:
			continue
		if not _is_numeric_local_eligible(def):
			continue
		_requested_numeric_local_ids[id] = true
		_last_requested_tick_by_id[id] = _sim_tick_index


func update_body(state: BodyState, def: BodyDef, t_s: float) -> void:
	if def.is_root():
		state.position_parent_frame_m = Vector3.ZERO
		state.velocity_parent_frame_mps = Vector3.ZERO
		state.last_update_time_s = t_s
		return

	var profile: OrbitProfile = def.orbit_profile
	if profile == null:
		return

	if state.current_mode == OrbitMode.Kind.NUMERIC_LOCAL:
		if _is_numeric_local_requested_or_in_grace(def.id):
			_update_numeric_local(state, def, t_s)
		else:
			_exit_numeric_local_to_kepler(state, def, profile, t_s)
		state.last_update_time_s = t_s
		return

	match profile.mode:
		OrbitMode.Kind.AUTHORED_ORBIT:
			_update_authored(state, profile, t_s)
		OrbitMode.Kind.KEPLER_APPROX:
			if _requested_numeric_local_ids.has(def.id) and _is_numeric_local_eligible(def):
				_enter_numeric_local(state, def, profile, t_s)
			else:
				_update_kepler(state, def, profile, t_s)
		OrbitMode.Kind.NUMERIC_LOCAL:
			push_warning("OrbitService: OrbitProfile.mode NUMERIC_LOCAL wird nicht direkt verwendet fuer %s" % def.id)
		_:
			push_warning("OrbitService: unbekannter Orbit-Mode %d fuer %s"
				% [profile.mode, def.id])
	state.last_update_time_s = t_s


func _update_authored(state: BodyState, profile: OrbitProfile, t_s: float) -> void:
	var pos: Vector3 = OrbitMath.authored_circular_position(
		profile.authored_radius_m,
		profile.authored_period_s,
		profile.authored_phase_rad,
		t_s,
	)
	var dt: float = t_s - state.last_update_time_s
	if dt > 0.0:
		state.velocity_parent_frame_mps = (pos - state.position_parent_frame_m) / dt
	state.position_parent_frame_m = pos
	state.current_mode = OrbitMode.Kind.AUTHORED_ORBIT


func recompute_all_at_time(t_s: float) -> void:
	if not _configured:
		return
	for id in _registry.get_update_order():
		var state: BodyState = _registry.get_state(id)
		var def: BodyDef = _registry.get_def(id)
		if state == null or def == null:
			continue
		update_body(state, def, t_s)


func _update_kepler(state: BodyState, def: BodyDef, profile: OrbitProfile, t_s: float) -> void:
	var evaluated: Dictionary = _evaluate_kepler_state(def, profile, t_s)
	state.position_parent_frame_m = evaluated.get("position_parent_frame_m", Vector3.ZERO)
	state.velocity_parent_frame_mps = evaluated.get("velocity_parent_frame_mps", Vector3.ZERO)
	state.current_mode = OrbitMode.Kind.KEPLER_APPROX


func _is_numeric_local_eligible(def: BodyDef) -> bool:
	if def == null or def.is_root():
		return false
	if def.orbit_profile == null:
		return false
	if def.orbit_profile.mode != OrbitMode.Kind.KEPLER_APPROX:
		return false
	return _compute_parent_mu(def) > 0.0


func _compute_parent_mu(def: BodyDef) -> float:
	if _registry == null or def == null or def.parent_id == StringName(""):
		return 0.0
	var parent: BodyDef = _registry.get_def(def.parent_id)
	if parent == null:
		return 0.0
	return UnitSystem.mu_from_mass(parent.mass_kg)


func _evaluate_kepler_state(def: BodyDef, profile: OrbitProfile, t_s: float) -> Dictionary:
	var mu: float = _compute_parent_mu(def)
	if mu <= 0.0:
		return {
			"position_parent_frame_m": Vector3.ZERO,
			"velocity_parent_frame_mps": Vector3.ZERO,
		}

	var pos: Vector3 = OrbitMath.kepler_position(
		profile.semi_major_axis_m,
		profile.eccentricity,
		profile.inclination_rad,
		profile.longitude_ascending_node_rad,
		profile.argument_periapsis_rad,
		profile.mean_anomaly_epoch_rad,
		profile.epoch_s,
		mu,
		t_s,
	)
	var pos_prev: Vector3 = OrbitMath.kepler_position(
		profile.semi_major_axis_m,
		profile.eccentricity,
		profile.inclination_rad,
		profile.longitude_ascending_node_rad,
		profile.argument_periapsis_rad,
		profile.mean_anomaly_epoch_rad,
		profile.epoch_s,
		mu,
		t_s - VELOCITY_SEED_EPSILON_S,
	)
	var pos_next: Vector3 = OrbitMath.kepler_position(
		profile.semi_major_axis_m,
		profile.eccentricity,
		profile.inclination_rad,
		profile.longitude_ascending_node_rad,
		profile.argument_periapsis_rad,
		profile.mean_anomaly_epoch_rad,
		profile.epoch_s,
		mu,
		t_s + VELOCITY_SEED_EPSILON_S,
	)
	var vel: Vector3 = (pos_next - pos_prev) / (2.0 * VELOCITY_SEED_EPSILON_S)
	return {
		"position_parent_frame_m": pos,
		"velocity_parent_frame_mps": vel,
	}


func _enter_numeric_local(state: BodyState, def: BodyDef, profile: OrbitProfile, t_s: float) -> void:
	var evaluated: Dictionary = _evaluate_kepler_state(def, profile, t_s)
	state.position_parent_frame_m = evaluated.get("position_parent_frame_m", Vector3.ZERO)
	state.velocity_parent_frame_mps = evaluated.get("velocity_parent_frame_mps", Vector3.ZERO)
	state.current_mode = OrbitMode.Kind.NUMERIC_LOCAL


func _update_numeric_local(state: BodyState, def: BodyDef, t_s: float) -> void:
	var dt: float = t_s - state.last_update_time_s
	var integrated: Dictionary = LOCAL_ORBIT_INTEGRATOR_SCRIPT.step_velocity_verlet_substepped(
		state.position_parent_frame_m,
		state.velocity_parent_frame_mps,
		dt,
		_compute_parent_mu(def),
		numeric_local_target_substep_s,
		numeric_local_max_substeps_per_tick
	)
	state.position_parent_frame_m = integrated.get("position_parent_frame_m", state.position_parent_frame_m)
	state.velocity_parent_frame_mps = integrated.get("velocity_parent_frame_mps", state.velocity_parent_frame_mps)
	state.current_mode = OrbitMode.Kind.NUMERIC_LOCAL
	if bool(integrated.get("hit_substep_cap", false)):
		_warn_on_substep_cap(def.id, dt, integrated)
	else:
		_substep_cap_warning_active_by_id.erase(def.id)


func _exit_numeric_local_to_kepler(state: BodyState, def: BodyDef, profile: OrbitProfile, t_s: float) -> void:
	var numeric_pos: Vector3 = state.position_parent_frame_m
	var numeric_vel: Vector3 = state.velocity_parent_frame_mps
	var evaluated: Dictionary = _evaluate_kepler_state(def, profile, t_s)
	var analytical_pos: Vector3 = evaluated.get("position_parent_frame_m", Vector3.ZERO)
	var analytical_vel: Vector3 = evaluated.get("velocity_parent_frame_mps", Vector3.ZERO)
	push_warning(
		"OrbitService: NUMERIC_LOCAL exit fuer %s pos_delta=%s vel_delta=%s"
			% [
				String(def.id),
				str(numeric_pos.distance_to(analytical_pos)),
				str(numeric_vel.distance_to(analytical_vel))
			]
	)
	state.position_parent_frame_m = analytical_pos
	state.velocity_parent_frame_mps = analytical_vel
	state.current_mode = OrbitMode.Kind.KEPLER_APPROX
	_clear_numeric_local_runtime_for(def.id)


func _is_numeric_local_requested_or_in_grace(id: StringName) -> bool:
	if _requested_numeric_local_ids.has(id):
		return true
	var grace_ticks: int = maxi(numeric_local_missing_request_grace_ticks, 0)
	var last_requested_tick: int = int(_last_requested_tick_by_id.get(id, NO_REQUEST_TICK))
	return (_sim_tick_index - last_requested_tick) <= grace_ticks


func _warn_on_substep_cap(id: StringName, dt_s: float, integrated: Dictionary) -> void:
	if bool(_substep_cap_warning_active_by_id.get(id, false)):
		return
	push_warning(
		"OrbitService: NUMERIC_LOCAL capped substeps fuer %s dt=%s substeps=%d substep_dt=%s target_substep=%s"
			% [
				String(id),
				str(dt_s),
				int(integrated.get("substep_count", 0)),
				str(float(integrated.get("substep_dt_s", 0.0))),
				str(numeric_local_target_substep_s),
			]
	)
	_substep_cap_warning_active_by_id[id] = true


func _clear_numeric_local_runtime_for(id: StringName) -> void:
	_last_requested_tick_by_id.erase(id)
	_substep_cap_warning_active_by_id.erase(id)
