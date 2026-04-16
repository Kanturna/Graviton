class_name OrbitProfile
extends Resource

# Orbit-Parameter eines Koerpers.
# Die aktive Felder-Gruppe haengt von `mode` ab — die jeweils anderen
# werden ignoriert. Die Trennung in eine Resource statt mehrerer Subklassen
# ist bewusst pragmatisch; siehe ADR in docs/ARCHITEKTUR.md.

@export var mode: int = OrbitMode.Kind.KEPLER_APPROX

# AUTHORED_ORBIT — Kreisbahn in der xy-Ebene des Parent-Frames.
@export var authored_radius_m: float = 0.0
@export var authored_period_s: float = 0.0
@export var authored_phase_rad: float = 0.0

# KEPLER_APPROX — klassische Elementenmenge.
@export var semi_major_axis_m: float = 0.0
@export var eccentricity: float = 0.0
@export var inclination_rad: float = 0.0
@export var longitude_ascending_node_rad: float = 0.0
@export var argument_periapsis_rad: float = 0.0
@export var mean_anomaly_epoch_rad: float = 0.0
@export var epoch_s: float = 0.0


func period_from_kepler(parent_mu: float) -> float:
	if semi_major_axis_m <= 0.0 or parent_mu <= 0.0:
		return 0.0
	var n: float = OrbitMath.mean_motion(semi_major_axis_m, parent_mu)
	if n <= 0.0:
		return 0.0
	return TAU / n
