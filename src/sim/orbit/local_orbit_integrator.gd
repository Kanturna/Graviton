class_name LocalOrbitIntegrator
extends RefCounted

# Reine Mathematik fuer numerische Orbit-Integration.
# Kein Zustand, keine Seiteneffekte — analog zu OrbitMath.
# Verwendet von OrbitService._update_numeric_local().
#
# Integrator: Velocity Verlet (zweite Ordnung, zeitreversibel).
# Nur Parentgravitation; kein N-Body, keine externen Kraefte.


# Gravitationsbeschleunigung am Ort pos_m gegenueber dem Parent-Ursprung.
# Gibt Vector3.ZERO zurueck wenn pos_m nahezu Null (Singularitaetsschutz).
static func gravity_acceleration_mps2(pos_m: Vector3, parent_mu: float) -> Vector3:
	var r2: float = pos_m.length_squared()
	if r2 < 1.0e-6:
		return Vector3.ZERO
	var r: float = sqrt(r2)
	return -(parent_mu / (r2 * r)) * pos_m


# Velocity-Verlet-Schritt.
# Gibt Dictionary {"pos": Vector3, "vel": Vector3} zurueck.
#
# Formel:
#   a0      = gravity(pos, mu)
#   pos_new = pos + vel*dt + 0.5*a0*dt^2
#   a1      = gravity(pos_new, mu)
#   vel_new = vel + 0.5*(a0 + a1)*dt
static func step_velocity_verlet(
		pos_m: Vector3, vel_mps: Vector3,
		parent_mu: float, dt_s: float) -> Dictionary:
	var a0: Vector3 = gravity_acceleration_mps2(pos_m, parent_mu)
	var pos_new: Vector3 = pos_m + vel_mps * dt_s + 0.5 * a0 * (dt_s * dt_s)
	var a1: Vector3 = gravity_acceleration_mps2(pos_new, parent_mu)
	var vel_new: Vector3 = vel_mps + 0.5 * (a0 + a1) * dt_s
	return {"pos": pos_new, "vel": vel_new}
