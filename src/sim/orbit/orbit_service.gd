class_name OrbitService
extends Node

# Einzige Stelle, die BodyState.position_parent_frame_m schreibt.
# Reagiert auf TimeService.sim_tick und iteriert die Bodies in der
# Topologie-Reihenfolge aus UniverseRegistry (Parent vor Kind).
#
# Regime-Dispatch pro Body:
#   - AUTHORED_ORBIT:  OrbitMath.authored_circular_position
#   - KEPLER_APPROX:   OrbitMath.kepler_position
#   - NUMERIC_LOCAL:   LocalOrbitIntegrator.step_velocity_verlet
#
# Regime-Wechsel:
#   request_numeric_local_candidates(ids) — von der Szene nach jedem
#   BubbleActivationSet.rebuild() aufrufen. OrbitService filtert intern
#   auf eligible Bodies (nur KEPLER_APPROX-Profil).

var _registry: Node = null
var _time: Node = null
var _configured: bool = false

# StringName -> true: Bodies, die aktuell numerisch integriert werden.
var _numeric_local_ids: Dictionary = {}


func configure(registry: Node, time_service: Node) -> void:
	assert(registry != null, "OrbitService.configure: registry is null")
	assert(time_service != null, "OrbitService.configure: time_service is null")
	_registry = registry
	_time = time_service
	if not _time.sim_tick.is_connected(_on_sim_tick):
		_time.sim_tick.connect(_on_sim_tick)
	_configured = true


# Wertet alle Bodies zum angegebenen Zeitpunkt aus, ohne einen Tick zu emittieren.
# Intention: initialen konsistenten Zustand herstellen vor dem ersten Render-Frame.
# Kein Simulationsfortschritt — TimeService bleibt alleiniger Zeitbesitzer.
func recompute_all_at_time(t_s: float) -> void:
	if not _configured:
		push_warning("OrbitService.recompute_all_at_time: nicht konfiguriert")
		return
	for id in _registry.get_update_order():
		var state: BodyState = _registry.get_state(id)
		var def: BodyDef = _registry.get_def(id)
		if state == null or def == null:
			continue
		update_body(state, def, t_s)


# Kandidaten-Angebot von der Szene: welche Bodies koennen prinzipiell
# NUMERIC_LOCAL werden? OrbitService filtert intern auf Eligibility.
# Aufruf: nach jedem BubbleActivationSet.rebuild() in _process der Szene.
func request_numeric_local_candidates(candidate_ids: Array[StringName]) -> void:
	if not _configured:
		return
	var t_s: float = _time.sim_time_s

	# Bodies, die neu ins NUMERIC_LOCAL-Set kommen
	for id in candidate_ids:
		if id in _numeric_local_ids:
			continue
		var def: BodyDef = _registry.get_def(id)
		if not _is_numeric_eligible(def):
			continue
		var state: BodyState = _registry.get_state(id)
		if state == null:
			continue
		_enter_numeric_local(state, def, t_s)

	# Bodies, die das NUMERIC_LOCAL-Set verlassen
	var candidate_set: Dictionary = {}
	for id in candidate_ids:
		candidate_set[id] = true
	var to_exit: Array[StringName] = []
	for id in _numeric_local_ids:
		if not candidate_set.has(id):
			to_exit.append(id)
	for id in to_exit:
		var state: BodyState = _registry.get_state(id)
		if state != null:
			_exit_numeric_local(state, id, t_s)


func _exit_tree() -> void:
	if _time != null and _time.sim_tick.is_connected(_on_sim_tick):
		_time.sim_tick.disconnect(_on_sim_tick)


func _on_sim_tick(_dt: float) -> void:
	if not _configured:
		return
	var t: float = _time.sim_time_s
	for id in _registry.get_update_order():
		var state: BodyState = _registry.get_state(id)
		var def: BodyDef = _registry.get_def(id)
		if state == null or def == null:
			continue
		update_body(state, def, t)


func update_body(state: BodyState, def: BodyDef, t_s: float) -> void:
	if def.is_root():
		state.position_parent_frame_m = Vector3.ZERO
		state.velocity_parent_frame_mps = Vector3.ZERO
		state.last_update_time_s = t_s
		return

	var profile: OrbitProfile = def.orbit_profile
	if profile == null:
		return

	# Bodies im NUMERIC_LOCAL-Set bekommen den Integrationspfad,
	# unabhaengig vom statischen Profil-Mode.
	if def.id in _numeric_local_ids:
		_update_numeric_local(state, def, t_s)
		return

	match profile.mode:
		OrbitMode.Kind.AUTHORED_ORBIT:
			_update_authored(state, profile, t_s)
		OrbitMode.Kind.KEPLER_APPROX:
			_update_kepler(state, def, profile, t_s)
		OrbitMode.Kind.NUMERIC_LOCAL:
			# Profil-Mode NUMERIC_LOCAL ohne aktiven Set-Eintrag:
			# body wurde noch nicht per request_numeric_local_candidates aktiviert.
			push_warning("OrbitService: Body '%s' hat NUMERIC_LOCAL-Profil, ist aber nicht im aktiven Set. Kepler-Fallback." % def.id)
			_update_kepler(state, def, profile, t_s)
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


func _update_kepler(state: BodyState, def: BodyDef, profile: OrbitProfile, t_s: float) -> void:
	var parent: BodyDef = _registry.get_def(def.parent_id)
	var mu: float = 0.0
	if parent != null:
		mu = UnitSystem.mu_from_mass(parent.mass_kg)
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
	var dt: float = t_s - state.last_update_time_s
	if dt > 0.0:
		state.velocity_parent_frame_mps = (pos - state.position_parent_frame_m) / dt
	state.position_parent_frame_m = pos
	state.current_mode = OrbitMode.Kind.KEPLER_APPROX


func _update_numeric_local(state: BodyState, def: BodyDef, t_s: float) -> void:
	var dt_s: float = t_s - state.last_update_time_s
	if dt_s <= 0.0:
		return
	if dt_s > 300.0:
		push_warning("OrbitService: NUMERIC_LOCAL dt=%.0f s > 300 s fuer '%s' — Drift moeglich" % [dt_s, def.id])

	var parent: BodyDef = _registry.get_def(def.parent_id)
	var mu: float = 0.0
	if parent != null:
		mu = UnitSystem.mu_from_mass(parent.mass_kg)

	var result: Dictionary = LocalOrbitIntegrator.step_velocity_verlet(
		state.position_parent_frame_m,
		state.velocity_parent_frame_mps,
		mu,
		dt_s,
	)
	state.position_parent_frame_m = result["pos"]
	state.velocity_parent_frame_mps = result["vel"]
	state.current_mode = OrbitMode.Kind.NUMERIC_LOCAL
	state.last_update_time_s = t_s


func _enter_numeric_local(state: BodyState, def: BodyDef, t_s: float) -> void:
	# Initialen Zustand aus Kepler-Loesung zum Eintrittszeitpunkt berechnen.
	var profile: OrbitProfile = def.orbit_profile
	var parent: BodyDef = _registry.get_def(def.parent_id)
	var mu: float = 0.0
	if parent != null:
		mu = UnitSystem.mu_from_mass(parent.mass_kg)
	var pos: Vector3 = OrbitMath.kepler_position(
		profile.semi_major_axis_m, profile.eccentricity,
		profile.inclination_rad, profile.longitude_ascending_node_rad,
		profile.argument_periapsis_rad, profile.mean_anomaly_epoch_rad,
		profile.epoch_s, mu, t_s,
	)
	var vel: Vector3 = _kepler_velocity_at(def, mu, t_s)
	state.position_parent_frame_m = pos
	state.velocity_parent_frame_mps = vel
	state.current_mode = OrbitMode.Kind.NUMERIC_LOCAL
	state.last_update_time_s = t_s
	_numeric_local_ids[def.id] = true


func _exit_numeric_local(state: BodyState, id: StringName, t_s: float) -> void:
	_numeric_local_ids.erase(id)
	# Sprung explizit loggen — darf nicht mit Bubble-/Render-Fehlern verwechselt werden.
	push_warning("OrbitService: NUMERIC_LOCAL → KEPLER_APPROX Sprung fuer '%s' bei t=%.1f s" % [id, t_s])
	state.current_mode = OrbitMode.Kind.KEPLER_APPROX
	# Kepler-Position wird beim naechsten update_body()-Aufruf korrekt gesetzt.


# Velocity-Schaetzung via finite Differenz (epsilon = 1.0 s).
func _kepler_velocity_at(def: BodyDef, parent_mu: float, t_s: float) -> Vector3:
	const EPSILON_S: float = 1.0
	var profile: OrbitProfile = def.orbit_profile
	var pos0: Vector3 = OrbitMath.kepler_position(
		profile.semi_major_axis_m, profile.eccentricity,
		profile.inclination_rad, profile.longitude_ascending_node_rad,
		profile.argument_periapsis_rad, profile.mean_anomaly_epoch_rad,
		profile.epoch_s, parent_mu, t_s,
	)
	var pos1: Vector3 = OrbitMath.kepler_position(
		profile.semi_major_axis_m, profile.eccentricity,
		profile.inclination_rad, profile.longitude_ascending_node_rad,
		profile.argument_periapsis_rad, profile.mean_anomaly_epoch_rad,
		profile.epoch_s, parent_mu, t_s + EPSILON_S,
	)
	return (pos1 - pos0) / EPSILON_S


func _is_numeric_eligible(def: BodyDef) -> bool:
	if def == null or def.is_root():
		return false
	var profile: OrbitProfile = def.orbit_profile
	if profile == null:
		return false
	return profile.mode == OrbitMode.Kind.KEPLER_APPROX
