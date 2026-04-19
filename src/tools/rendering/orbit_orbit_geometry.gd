extends RefCounted


static func build_orbit_points(def: BodyDef, sample_count: int = 120) -> PackedVector2Array:
	var profile: OrbitProfile = def.orbit_profile
	if profile == null:
		return PackedVector2Array()

	var points: PackedVector2Array = PackedVector2Array()
	for i in range(sample_count):
		var t: float = float(i) / float(sample_count)
		var point_m: Vector3 = Vector3.ZERO
		match profile.mode:
			OrbitMode.Kind.AUTHORED_ORBIT:
				point_m = OrbitMath.authored_circular_position(
					profile.authored_radius_m,
					1.0,
					t * TAU,
					0.0
				)
			OrbitMode.Kind.KEPLER_APPROX:
				var mean_anomaly: float = t * TAU
				var ecc_anom: float = OrbitMath.solve_kepler(mean_anomaly, profile.eccentricity)
				var nu: float = OrbitMath.true_anomaly_from_eccentric(ecc_anom, profile.eccentricity)
				var plane: Vector2 = OrbitMath.position_in_orbit_plane(
					profile.semi_major_axis_m,
					profile.eccentricity,
					nu
				)
				point_m = OrbitMath.rotate_to_3d(
					plane,
					profile.inclination_rad,
					profile.longitude_ascending_node_rad,
					profile.argument_periapsis_rad
				)
			_:
				point_m = Vector3.ZERO
		points.append(Vector2(point_m.x, point_m.y) / UnitSystem.RENDER_SCALE_M_PER_UNIT)

	if points.size() >= 3:
		return AntialiasedLine2D.construct_closed_line(points)
	return points


static func orbit_extent_ru(def: BodyDef) -> float:
	if def == null or def.orbit_profile == null:
		return 0.0
	var profile: OrbitProfile = def.orbit_profile
	match profile.mode:
		OrbitMode.Kind.AUTHORED_ORBIT:
			return profile.authored_radius_m / UnitSystem.RENDER_SCALE_M_PER_UNIT
		OrbitMode.Kind.KEPLER_APPROX:
			return profile.semi_major_axis_m * (1.0 + clampf(profile.eccentricity, 0.0, 0.999999)) / UnitSystem.RENDER_SCALE_M_PER_UNIT
		_:
			return 0.0
