class_name OrbitPeriodHelper
extends RefCounted


static func orbital_period_s_for_def(def: BodyDef, def_lookup: Dictionary) -> float:
	if def == null or def.orbit_profile == null:
		return 0.0
	var profile: OrbitProfile = def.orbit_profile
	match profile.mode:
		OrbitMode.Kind.AUTHORED_ORBIT:
			return profile.authored_period_s if profile.authored_period_s > 0.0 else 0.0
		OrbitMode.Kind.KEPLER_APPROX:
			var parent_def: BodyDef = _lookup_def(def_lookup, def.parent_id)
			if parent_def == null:
				return 0.0
			var mu_parent: float = UnitSystem.mu_from_mass(parent_def.mass_kg)
			if profile.semi_major_axis_m <= 0.0 or mu_parent <= 0.0:
				return 0.0
			return TAU * sqrt(pow(profile.semi_major_axis_m, 3.0) / mu_parent)
		OrbitMode.Kind.NUMERIC_LOCAL:
			return 0.0
	return 0.0


static func _lookup_def(def_lookup: Dictionary, id: StringName) -> BodyDef:
	return def_lookup.get(id, null) as BodyDef
