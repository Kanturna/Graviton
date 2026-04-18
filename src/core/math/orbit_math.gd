class_name OrbitMath
extends RefCounted

# Reine Orbit-Mathematik. Keine Abhaengigkeiten auf Sim-Zustand, Autoloads
# oder Resources. Jede Funktion ist deterministisch und ohne Seiteneffekt
# — das ist die Grundlage fuer Unit-Tests ohne Szene.

const _KEPLER_DEFAULT_TOL: float = 1.0e-10
const _KEPLER_DEFAULT_MAX_ITER: int = 32


# Loest die Kepler-Gleichung M = E - e * sin(E) iterativ per Newton.
# Rueckgabe: exzentrische Anomalie E in Radiant.
# Die Funktion normalisiert signed Winkel auf die kanonische Range
# [-PI, PI). Deshalb wird der Randfall PI als -PI repraesentiert â€” das
# ist eine Darstellungsentscheidung, kein physikalischer Unterschied.
static func solve_kepler(mean_anomaly: float, eccentricity: float,
		tolerance: float = _KEPLER_DEFAULT_TOL,
		max_iter: int = _KEPLER_DEFAULT_MAX_ITER) -> float:
	var m: float = wrapf(mean_anomaly, -PI, PI)
	var e: float = clampf(eccentricity, 0.0, 0.999999)
	var ecc_anom: float = m if e < 0.8 else PI
	for _i in range(max_iter):
		var f: float = ecc_anom - e * sin(ecc_anom) - m
		var fp: float = 1.0 - e * cos(ecc_anom)
		var delta: float = f / fp
		ecc_anom -= delta
		if absf(delta) < tolerance:
			break
	return ecc_anom


# Wahre Anomalie aus exzentrischer Anomalie und Exzentrizitaet.
static func true_anomaly_from_eccentric(ecc_anom: float, eccentricity: float) -> float:
	var e: float = clampf(eccentricity, 0.0, 0.999999)
	var s: float = sqrt(1.0 - e * e) * sin(ecc_anom)
	var c: float = cos(ecc_anom) - e
	return atan2(s, c)


# Position im Orbit-Ebenen-Koordinatensystem (Periapsis entlang +x).
static func position_in_orbit_plane(semi_major_axis_m: float,
		eccentricity: float, true_anomaly: float) -> Vector2:
	var e: float = clampf(eccentricity, 0.0, 0.999999)
	var r: float = semi_major_axis_m * (1.0 - e * e) / (1.0 + e * cos(true_anomaly))
	return Vector2(r * cos(true_anomaly), r * sin(true_anomaly))


# Dreht die planare Position durch die drei Orbit-Winkel in den 3D-Parent-Frame.
# Konvention: z ist "ekliptischer Aufwaerts".
static func rotate_to_3d(pos_plane: Vector2,
		inclination_rad: float,
		longitude_ascending_node_rad: float,
		argument_periapsis_rad: float) -> Vector3:
	var cos_w: float = cos(argument_periapsis_rad)
	var sin_w: float = sin(argument_periapsis_rad)
	var cos_o: float = cos(longitude_ascending_node_rad)
	var sin_o: float = sin(longitude_ascending_node_rad)
	var cos_i: float = cos(inclination_rad)
	var sin_i: float = sin(inclination_rad)

	var xp: float = pos_plane.x
	var yp: float = pos_plane.y

	var x: float = (cos_o * cos_w - sin_o * sin_w * cos_i) * xp \
		+ (-cos_o * sin_w - sin_o * cos_w * cos_i) * yp
	var y: float = (sin_o * cos_w + cos_o * sin_w * cos_i) * xp \
		+ (-sin_o * sin_w + cos_o * cos_w * cos_i) * yp
	var z: float = (sin_w * sin_i) * xp + (cos_w * sin_i) * yp
	return Vector3(x, y, z)


# Dreht einen beliebigen Vektor aus dem lokalen Orbit-Frame in den
# 3D-Parent-Frame. Dieselbe Orbit-Frame-Konvention wie bei
# rotate_to_3d(): +x = Periapsis-/Phase-0-Richtung, +z = Orbit-Normale.
static func rotate_orbit_frame_vector(vector_orbit_frame: Vector3,
		inclination_rad: float,
		longitude_ascending_node_rad: float,
		argument_periapsis_rad: float) -> Vector3:
	var cos_w: float = cos(argument_periapsis_rad)
	var sin_w: float = sin(argument_periapsis_rad)
	var cos_o: float = cos(longitude_ascending_node_rad)
	var sin_o: float = sin(longitude_ascending_node_rad)
	var cos_i: float = cos(inclination_rad)
	var sin_i: float = sin(inclination_rad)

	var x_orbit: float = vector_orbit_frame.x
	var y_orbit: float = vector_orbit_frame.y
	var z_orbit: float = vector_orbit_frame.z

	var x: float = (cos_o * cos_w - sin_o * sin_w * cos_i) * x_orbit \
		+ (-cos_o * sin_w - sin_o * cos_w * cos_i) * y_orbit \
		+ (sin_o * sin_i) * z_orbit
	var y: float = (sin_o * cos_w + cos_o * sin_w * cos_i) * x_orbit \
		+ (-sin_o * sin_w + cos_o * cos_w * cos_i) * y_orbit \
		+ (-cos_o * sin_i) * z_orbit
	var z: float = (sin_w * sin_i) * x_orbit \
		+ (cos_w * sin_i) * y_orbit \
		+ cos_i * z_orbit
	return Vector3(x, y, z)


# Mittlere Bewegung n = sqrt(mu / a^3) in rad/s.
static func mean_motion(semi_major_axis_m: float, parent_mu: float) -> float:
	if semi_major_axis_m <= 0.0 or parent_mu <= 0.0:
		return 0.0
	return sqrt(parent_mu / pow(semi_major_axis_m, 3.0))


static func mean_anomaly_at(t_s: float, mean_anomaly_epoch_rad: float,
		n_rad_per_s: float, epoch_s: float = 0.0) -> float:
	return mean_anomaly_epoch_rad + n_rad_per_s * (t_s - epoch_s)


# Komplette Kepler-Auswertung aus primitiven Parametern. Liefert die
# Position im Parent-Frame (x/y in der Bezugsebene, z entlang Inklination).
static func kepler_position(semi_major_axis_m: float,
		eccentricity: float,
		inclination_rad: float,
		longitude_ascending_node_rad: float,
		argument_periapsis_rad: float,
		mean_anomaly_epoch_rad: float,
		epoch_s: float,
		parent_mu: float,
		t_s: float) -> Vector3:
	var n: float = mean_motion(semi_major_axis_m, parent_mu)
	var m: float = mean_anomaly_at(t_s, mean_anomaly_epoch_rad, n, epoch_s)
	var ecc_anom: float = solve_kepler(m, eccentricity)
	var nu: float = true_anomaly_from_eccentric(ecc_anom, eccentricity)
	var plane: Vector2 = position_in_orbit_plane(semi_major_axis_m, eccentricity, nu)
	return rotate_to_3d(plane, inclination_rad, longitude_ascending_node_rad, argument_periapsis_rad)


# Autorierte Kreisbahn in der xy-Ebene des Parent-Frames.
static func authored_circular_position(radius_m: float, period_s: float,
		phase_rad: float, t_s: float) -> Vector3:
	if period_s <= 0.0:
		return Vector3(radius_m * cos(phase_rad), radius_m * sin(phase_rad), 0.0)
	var omega: float = TAU / period_s
	var angle: float = phase_rad + omega * t_s
	return Vector3(radius_m * cos(angle), radius_m * sin(angle), 0.0)
