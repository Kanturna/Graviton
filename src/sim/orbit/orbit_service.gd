class_name OrbitService
extends Node

# Einzige Stelle, die BodyState.position_parent_frame_m schreibt.
# Reagiert auf TimeService.sim_tick und iteriert die Bodies in der
# Topologie-Reihenfolge aus UniverseRegistry (Parent vor Kind).
#
# Fuer den Foundation-Slice:
#   - AUTHORED_ORBIT: OrbitMath.authored_circular_position
#   - KEPLER_APPROX:  OrbitMath.kepler_position
#   - NUMERIC_LOCAL:  noch nicht implementiert (wird ignoriert mit Warnung).

var _registry: Node = null
var _time: Node = null
var _configured: bool = false


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

	match profile.mode:
		OrbitMode.Kind.AUTHORED_ORBIT:
			_update_authored(state, profile, t_s)
		OrbitMode.Kind.KEPLER_APPROX:
			_update_kepler(state, def, profile, t_s)
		OrbitMode.Kind.NUMERIC_LOCAL:
			push_warning("OrbitService: NUMERIC_LOCAL nicht implementiert fuer %s" % def.id)
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
