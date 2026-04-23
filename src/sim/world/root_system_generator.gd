class_name RootSystemGenerator
extends RefCounted

const STANDARD_PLANET_START_AXIS_MIN_M: float = 1.4e9
const STANDARD_PLANET_START_AXIS_MAX_M: float = 2.1e9
const STANDARD_PLANET_AXIS_GROWTH_MIN: float = 1.55
const STANDARD_PLANET_AXIS_GROWTH_MAX: float = 1.85
const STANDARD_PLANET_AXIS_MAX_M: float = 9.5e9
const PLANET_MASS_MIN_EARTH: float = 0.45
const PLANET_MASS_MAX_EARTH: float = 3.10
const GENERATOR_GREENHOUSE_CEILING_K: float = 58.0


static func build_root_defs(manifest) -> Array[BodyDef]:
	var out: Array[BodyDef] = []
	if manifest == null or not manifest.is_valid():
		return out

	out.append(_build_root_def(manifest))
	for star_index in range(manifest.star_manifests.size()):
		var star_manifest = manifest.star_manifests[star_index]
		out.append(_build_star_def(manifest, star_manifest))
		var star_rng := RandomNumberGenerator.new()
		star_rng.seed = int(manifest.seed + star_index * 7919 + 17)
		out.append_array(_build_planet_defs(manifest, star_manifest, star_rng))
	return out


static func _build_root_def(manifest) -> BodyDef:
	var d := BodyDef.new()
	d.id = manifest.root_id
	d.display_name = manifest.display_name
	d.kind = manifest.root_kind
	d.mass_kg = manifest.root_mass_kg
	d.radius_m = manifest.root_radius_m
	d.rotation_period_s = 0.0
	d.axial_tilt_rad = 0.0
	d.luminosity_w = 0.0
	d.albedo = 0.0
	d.parent_id = &""
	d.orbit_profile = null
	return d


static func _build_star_def(manifest, star_manifest) -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = star_manifest.orbit_radius_m
	prof.authored_period_s = star_manifest.orbit_period_s
	prof.authored_phase_rad = star_manifest.orbit_phase_rad

	var d := BodyDef.new()
	d.id = star_manifest.id
	d.display_name = star_manifest.display_name
	d.kind = BodyType.Kind.STAR
	d.mass_kg = star_manifest.mass_kg
	d.radius_m = star_manifest.radius_m
	d.rotation_period_s = star_manifest.rotation_period_s
	d.axial_tilt_rad = 0.0
	d.luminosity_w = star_manifest.luminosity_w
	d.albedo = 0.0
	d.parent_id = manifest.root_id
	d.orbit_profile = prof
	return d


static func _build_planet_defs(
		manifest,
		star_manifest,
		rng: RandomNumberGenerator
	) -> Array[BodyDef]:
	var out: Array[BodyDef] = []
	var planet_count: int = star_manifest.planet_count if star_manifest.planet_count > 0 else rng.randi_range(2, 5)
	var current_axis_m: float = rng.randf_range(
		STANDARD_PLANET_START_AXIS_MIN_M,
		STANDARD_PLANET_START_AXIS_MAX_M
	)

	for planet_index in range(planet_count):
		var planet_id: StringName = StringName("%s_p%d" % [String(star_manifest.id), planet_index + 1])
		var planet_display_name: String = "%s %d" % [star_manifest.display_name, planet_index + 1]
		var profile := OrbitProfile.new()
		profile.mode = OrbitMode.Kind.KEPLER_APPROX
		profile.semi_major_axis_m = current_axis_m
		profile.eccentricity = rng.randf_range(0.01, 0.18)
		profile.inclination_rad = 0.0
		profile.longitude_ascending_node_rad = 0.0
		profile.argument_periapsis_rad = rng.randf_range(0.0, TAU)
		profile.mean_anomaly_epoch_rad = rng.randf_range(0.0, TAU)
		profile.epoch_s = 0.0

		var mass_earth: float = rng.randf_range(PLANET_MASS_MIN_EARTH, PLANET_MASS_MAX_EARTH)
		var greenhouse_delta_k: float = rng.randf_range(0.0, GENERATOR_GREENHOUSE_CEILING_K)
		var axis_norm: float = _normalize_ratio(
			current_axis_m,
			STANDARD_PLANET_START_AXIS_MIN_M,
			STANDARD_PLANET_AXIS_MAX_M
		)
		var mass_norm: float = _normalize_ratio(mass_earth, PLANET_MASS_MIN_EARTH, PLANET_MASS_MAX_EARTH)
		var greenhouse_norm: float = minf(greenhouse_delta_k / GENERATOR_GREENHOUSE_CEILING_K, 1.0)
		var volatile_inventory_ratio: float = clampf(
			0.15 + axis_norm * 0.55 + mass_norm * 0.15 + rng.randf_range(-0.08, 0.08),
			0.0,
			1.0
		)
		var climate_buffer_factor: float = clampf(
			0.15 + volatile_inventory_ratio * 0.45 + mass_norm * 0.25 + greenhouse_norm * 0.10 + rng.randf_range(-0.06, 0.06),
			0.0,
			1.0
		)

		var d := BodyDef.new()
		d.id = planet_id
		d.display_name = planet_display_name
		d.kind = BodyType.Kind.PLANET
		d.mass_kg = UnitSystem.EARTH_MASS_KG * mass_earth
		d.radius_m = UnitSystem.EARTH_RADIUS_M * rng.randf_range(0.72, 1.58)
		d.rotation_period_s = rng.randf_range(0.55, 4.10) * UnitSystem.DAY_S
		d.axial_tilt_rad = rng.randf_range(0.0, 0.72)
		d.north_pole_orbit_frame_azimuth_rad = rng.randf_range(-PI, PI)
		d.luminosity_w = 0.0
		d.albedo = rng.randf_range(0.08, 0.62)
		d.volatile_inventory_ratio = volatile_inventory_ratio
		d.climate_buffer_factor = climate_buffer_factor
		d.greenhouse_delta_k = greenhouse_delta_k
		d.parent_id = star_manifest.id
		d.orbit_profile = profile
		out.append(d)

		if rng.randf() < 0.42:
			out.append(_build_moon_def(
				planet_id,
				planet_display_name,
				volatile_inventory_ratio,
				climate_buffer_factor,
				rng
			))

		current_axis_m *= rng.randf_range(STANDARD_PLANET_AXIS_GROWTH_MIN, STANDARD_PLANET_AXIS_GROWTH_MAX)
		current_axis_m = minf(current_axis_m, STANDARD_PLANET_AXIS_MAX_M)

	return out


static func _build_moon_def(
		planet_id: StringName,
		planet_display_name: String,
		parent_volatile_inventory_ratio: float,
		parent_climate_buffer_factor: float,
		rng: RandomNumberGenerator
	) -> BodyDef:
	var profile := OrbitProfile.new()
	profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	profile.authored_radius_m = rng.randf_range(1.7e8, 4.8e8)
	profile.authored_period_s = rng.randf_range(4.5e5, 1.8e6)
	profile.authored_phase_rad = rng.randf_range(0.0, TAU)

	var d := BodyDef.new()
	d.id = StringName("%s_m" % String(planet_id))
	d.display_name = "%s - Moon" % planet_display_name
	d.kind = BodyType.Kind.MOON
	d.mass_kg = UnitSystem.LUNAR_MASS_KG * rng.randf_range(0.55, 1.85)
	d.radius_m = UnitSystem.LUNAR_RADIUS_M * rng.randf_range(0.75, 1.35)
	d.rotation_period_s = 0.0
	d.axial_tilt_rad = 0.0
	d.luminosity_w = 0.0
	d.albedo = rng.randf_range(0.06, 0.26)
	d.volatile_inventory_ratio = clampf(
		parent_volatile_inventory_ratio * 0.65 + rng.randf_range(-0.05, 0.05),
		0.0,
		1.0
	)
	d.climate_buffer_factor = clampf(
		parent_climate_buffer_factor * 0.55 + rng.randf_range(-0.05, 0.05),
		0.0,
		1.0
	)
	d.parent_id = planet_id
	d.orbit_profile = profile
	return d


static func _normalize_ratio(value: float, min_value: float, max_value: float) -> float:
	if not is_finite(value) or not is_finite(min_value) or not is_finite(max_value):
		return 0.0
	if max_value <= min_value:
		return 0.0
	return clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)
