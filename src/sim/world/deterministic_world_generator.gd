class_name DeterministicWorldGenerator
extends RefCounted


const DEFAULT_SEED: int = 424242
const ROOT_ID: StringName = &"genesis"


static func build(seed: int = DEFAULT_SEED) -> Array[BodyDef]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var star_mass_scale: float = rng.randf_range(0.72, 1.18)
	var out: Array[BodyDef] = [_build_root_star(star_mass_scale)]

	var planet_count: int = rng.randi_range(3, 5)
	var current_axis_m: float = rng.randf_range(0.32, 0.46) * UnitSystem.AU_M
	for i in range(planet_count):
		var planet_id: StringName = StringName("gen_%d" % [i + 1])
		var planet_display_name: String = "Gen %d" % [i + 1]
		var planet_mass_scale: float = rng.randf_range(0.55, 2.40)
		var planet_radius_scale: float = rng.randf_range(0.78, 1.45)
		var albedo: float = rng.randf_range(0.10, 0.62)
		var greenhouse_delta_k: float = rng.randf_range(0.0, 62.0)
		var eccentricity: float = rng.randf_range(0.01, 0.16)
		var tilt_rad: float = rng.randf_range(0.0, 0.62)
		var azimuth_rad: float = rng.randf_range(-PI, PI)
		var rotation_period_days: float = rng.randf_range(0.55, 3.60)
		var periapsis_rad: float = rng.randf_range(0.0, TAU)
		var mean_anomaly_rad: float = rng.randf_range(0.0, TAU)

		out.append(_build_planet(
			planet_id,
			planet_display_name,
			current_axis_m,
			eccentricity,
			periapsis_rad,
			mean_anomaly_rad,
			planet_mass_scale,
			planet_radius_scale,
			albedo,
			greenhouse_delta_k,
			tilt_rad,
			azimuth_rad,
			rotation_period_days
		))

		if rng.randf() < 0.55:
			out.append(_build_moon(
				StringName("%s_m" % [String(planet_id)]),
				"%s - Moon" % planet_display_name,
				planet_id,
				rng
			))

		current_axis_m *= rng.randf_range(1.42, 1.88)

	return out


static func _build_root_star(star_mass_scale: float) -> BodyDef:
	var d := BodyDef.new()
	d.id = ROOT_ID
	d.display_name = "Genesis"
	d.kind = BodyType.Kind.STAR
	d.mass_kg = UnitSystem.SOLAR_MASS_KG * star_mass_scale
	d.radius_m = 6.957e8 * lerpf(0.82, 1.18, clampf((star_mass_scale - 0.72) / 0.46, 0.0, 1.0))
	d.rotation_period_s = 22.0 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.0
	d.luminosity_w = UnitSystem.SOLAR_LUMINOSITY_W * pow(star_mass_scale, 3.45)
	d.albedo = 0.0
	d.parent_id = &""
	d.orbit_profile = null
	return d


static func _build_planet(
		id: StringName,
		display_name: String,
		semi_major_axis_m: float,
		eccentricity: float,
		argument_periapsis_rad: float,
		mean_anomaly_epoch_rad: float,
		mass_scale: float,
		radius_scale: float,
		albedo: float,
		greenhouse_delta_k: float,
		tilt_rad: float,
		azimuth_rad: float,
		rotation_period_days: float
	) -> BodyDef:
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.KEPLER_APPROX
	profile.semi_major_axis_m = semi_major_axis_m
	profile.eccentricity = eccentricity
	profile.inclination_rad = 0.0
	profile.longitude_ascending_node_rad = 0.0
	profile.argument_periapsis_rad = argument_periapsis_rad
	profile.mean_anomaly_epoch_rad = mean_anomaly_epoch_rad
	profile.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = id
	d.display_name = display_name
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG * mass_scale
	d.radius_m = UnitSystem.EARTH_RADIUS_M * radius_scale
	d.rotation_period_s = rotation_period_days * UnitSystem.DAY_S
	d.axial_tilt_rad = tilt_rad
	d.north_pole_orbit_frame_azimuth_rad = azimuth_rad
	d.luminosity_w = 0.0
	d.albedo = albedo
	d.greenhouse_delta_k = greenhouse_delta_k
	d.parent_id = ROOT_ID
	d.orbit_profile = profile
	return d


static func _build_moon(id: StringName, display_name: String, parent_id: StringName, rng: RandomNumberGenerator) -> BodyDef:
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = rng.randf_range(1.6e8, 4.2e8)
	profile.authored_period_s = rng.randf_range(5.0e5, 1.4e6)
	profile.authored_phase_rad = rng.randf_range(0.0, TAU)

	var d := BodyDef.new()
	d.id = id
	d.display_name = display_name
	d.kind = BodyType.Kind.MOON
	d.mass_kg = UnitSystem.LUNAR_MASS_KG * rng.randf_range(0.65, 1.75)
	d.radius_m = UnitSystem.LUNAR_RADIUS_M * rng.randf_range(0.75, 1.35)
	d.rotation_period_s = 0.0
	d.axial_tilt_rad = 0.0
	d.luminosity_w = 0.0
	d.albedo = rng.randf_range(0.08, 0.26)
	d.parent_id = parent_id
	d.orbit_profile = profile
	return d
