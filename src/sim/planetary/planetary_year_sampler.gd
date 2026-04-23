class_name PlanetaryYearSampler
extends Node


const ThermalServiceScript = preload("res://src/sim/thermal/thermal_service.gd")
const AtmosphereServiceScript = preload("res://src/sim/atmosphere/atmosphere_service.gd")

const SAMPLE_COUNT: int = 16
const SOUTH_MIDLATITUDE_RAD: float = -PI / 3.0
const EQUATOR_RAD: float = 0.0
const NORTH_MIDLATITUDE_RAD: float = PI / 3.0
const SOUTH_BAND_WEIGHT: float = 0.25
const EQUATOR_BAND_WEIGHT: float = 0.50
const NORTH_BAND_WEIGHT: float = 0.25
const KEY_HAS_SAMPLED_YEAR_BASIS: StringName = &"has_sampled_year_basis"
const KEY_HAS_PRIMARY_SOURCE_ONLY_BASIS: StringName = &"has_primary_source_only_basis"
const KEY_SOUTH_BAND_MIN_SURFACE_TEMPERATURE_K: StringName = &"south_band_min_surface_temperature_k"
const KEY_SOUTH_BAND_MAX_SURFACE_TEMPERATURE_K: StringName = &"south_band_max_surface_temperature_k"
const KEY_SOUTH_BAND_MEAN_SURFACE_TEMPERATURE_K: StringName = &"south_band_mean_surface_temperature_k"
const KEY_EQUATOR_BAND_MIN_SURFACE_TEMPERATURE_K: StringName = &"equator_band_min_surface_temperature_k"
const KEY_EQUATOR_BAND_MAX_SURFACE_TEMPERATURE_K: StringName = &"equator_band_max_surface_temperature_k"
const KEY_EQUATOR_BAND_MEAN_SURFACE_TEMPERATURE_K: StringName = &"equator_band_mean_surface_temperature_k"
const KEY_NORTH_BAND_MIN_SURFACE_TEMPERATURE_K: StringName = &"north_band_min_surface_temperature_k"
const KEY_NORTH_BAND_MAX_SURFACE_TEMPERATURE_K: StringName = &"north_band_max_surface_temperature_k"
const KEY_NORTH_BAND_MEAN_SURFACE_TEMPERATURE_K: StringName = &"north_band_mean_surface_temperature_k"
const KEY_ANNUAL_GLOBAL_MIN_SURFACE_TEMPERATURE_K: StringName = &"annual_global_min_surface_temperature_k"
const KEY_ANNUAL_GLOBAL_MAX_SURFACE_TEMPERATURE_K: StringName = &"annual_global_max_surface_temperature_k"
const KEY_ANNUAL_GLOBAL_MEAN_SURFACE_TEMPERATURE_K: StringName = &"annual_global_mean_surface_temperature_k"
const KEY_ANNUAL_MAX_BAND_SPAN_K: StringName = &"annual_max_band_span_k"
const KEY_ANNUAL_MODERATE_SAMPLE_FRACTION: StringName = &"annual_moderate_sample_fraction"

var _registry: Node = null


func configure(registry: Node) -> void:
	assert(registry != null, "PlanetaryYearSampler.configure: registry is null")
	_registry = registry


func sample_body(id: StringName) -> Dictionary:
	if _registry == null:
		return _default_description()
	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return _default_description()
	return sample_from_def_chain(def, _parent_chain_defs_for_body(id))


static func sample_from_def_chain(body_def: BodyDef, parent_chain_defs: Array[BodyDef]) -> Dictionary:
	var description: Dictionary = _default_description()
	if body_def == null:
		return description
	if body_def.kind != BodyType.Kind.PLANET and body_def.kind != BodyType.Kind.MOON:
		return description
	if body_def.orbit_profile == null:
		return description

	var def_lookup: Dictionary = _def_lookup_from_chain(body_def, parent_chain_defs)
	var source_def: BodyDef = _find_luminous_ancestor_def(parent_chain_defs)
	if source_def == null or source_def.luminosity_w <= 0.0:
		return description

	var period_s: float = _orbital_period_s_for_def(body_def, def_lookup)
	if period_s <= 0.0 or not is_finite(period_s):
		return description

	var south_samples_raw: Array[float] = []
	var equator_samples_raw: Array[float] = []
	var north_samples_raw: Array[float] = []

	for sample_index in range(SAMPLE_COUNT):
		var t_s: float = _sample_time_s(body_def.orbit_profile, period_s, sample_index)
		var body_to_source_m: Vector3 = _body_to_ancestor_vector_at_from_lookup(
			body_def.id,
			source_def.id,
			t_s,
			def_lookup
		)
		if not _is_finite_vec3(body_to_source_m) or body_to_source_m.length_squared() <= 0.0:
			return description

		var radiative_context: Dictionary = ThermalServiceScript.evaluate_radiative_from_vectors(
			body_def,
			source_def,
			body_to_source_m
		)
		if not bool(radiative_context.get(ThermalServiceScript.CTX_OK, false)):
			return description
		var seasonal_context: Dictionary = ThermalServiceScript.evaluate_seasonal_from_context(
			body_def,
			body_def.orbit_profile,
			body_to_source_m
		)
		if not bool(seasonal_context.get(ThermalServiceScript.CTX_OK, false)):
			return description

		var insolation_wpm2: float = float(radiative_context.get(ThermalServiceScript.KEY_INSOLATION_WPM2, 0.0))
		var subsolar_latitude_rad: float = float(seasonal_context.get(ThermalServiceScript.KEY_SUBSOLAR_LATITUDE_RAD, 0.0))
		south_samples_raw.append(AtmosphereServiceScript.compute_surface_temperature_at_latitude_from_contexts(
			insolation_wpm2,
			subsolar_latitude_rad,
			SOUTH_MIDLATITUDE_RAD,
			body_def.albedo,
			body_def.greenhouse_delta_k
		))
		equator_samples_raw.append(AtmosphereServiceScript.compute_surface_temperature_at_latitude_from_contexts(
			insolation_wpm2,
			subsolar_latitude_rad,
			EQUATOR_RAD,
			body_def.albedo,
			body_def.greenhouse_delta_k
		))
		north_samples_raw.append(AtmosphereServiceScript.compute_surface_temperature_at_latitude_from_contexts(
			insolation_wpm2,
			subsolar_latitude_rad,
			NORTH_MIDLATITUDE_RAD,
			body_def.albedo,
			body_def.greenhouse_delta_k
		))

	if south_samples_raw.size() != SAMPLE_COUNT \
			or equator_samples_raw.size() != SAMPLE_COUNT \
			or north_samples_raw.size() != SAMPLE_COUNT:
		return description

	var south_samples_k: Array[float] = _buffered_samples(body_def.climate_buffer_factor, south_samples_raw)
	var equator_samples_k: Array[float] = _buffered_samples(body_def.climate_buffer_factor, equator_samples_raw)
	var north_samples_k: Array[float] = _buffered_samples(body_def.climate_buffer_factor, north_samples_raw)
	if south_samples_k.is_empty() or equator_samples_k.is_empty() or north_samples_k.is_empty():
		return description

	var all_samples_k: Array[float] = []
	all_samples_k.append_array(south_samples_k)
	all_samples_k.append_array(equator_samples_k)
	all_samples_k.append_array(north_samples_k)

	var south_stats: Dictionary = _sample_stats(south_samples_k)
	var equator_stats: Dictionary = _sample_stats(equator_samples_k)
	var north_stats: Dictionary = _sample_stats(north_samples_k)
	var global_stats: Dictionary = _sample_stats(all_samples_k)
	if not bool(global_stats.get("ok", false)):
		return description
	var annual_global_mean_surface_temperature_k: float = _area_weighted_band_mean(
		float(south_stats.get("mean", 0.0)),
		float(equator_stats.get("mean", 0.0)),
		float(north_stats.get("mean", 0.0))
	)

	return {
		KEY_HAS_SAMPLED_YEAR_BASIS: true,
		KEY_HAS_PRIMARY_SOURCE_ONLY_BASIS: true,
		KEY_SOUTH_BAND_MIN_SURFACE_TEMPERATURE_K: float(south_stats.get("min", 0.0)),
		KEY_SOUTH_BAND_MAX_SURFACE_TEMPERATURE_K: float(south_stats.get("max", 0.0)),
		KEY_SOUTH_BAND_MEAN_SURFACE_TEMPERATURE_K: float(south_stats.get("mean", 0.0)),
		KEY_EQUATOR_BAND_MIN_SURFACE_TEMPERATURE_K: float(equator_stats.get("min", 0.0)),
		KEY_EQUATOR_BAND_MAX_SURFACE_TEMPERATURE_K: float(equator_stats.get("max", 0.0)),
		KEY_EQUATOR_BAND_MEAN_SURFACE_TEMPERATURE_K: float(equator_stats.get("mean", 0.0)),
		KEY_NORTH_BAND_MIN_SURFACE_TEMPERATURE_K: float(north_stats.get("min", 0.0)),
		KEY_NORTH_BAND_MAX_SURFACE_TEMPERATURE_K: float(north_stats.get("max", 0.0)),
		KEY_NORTH_BAND_MEAN_SURFACE_TEMPERATURE_K: float(north_stats.get("mean", 0.0)),
		KEY_ANNUAL_GLOBAL_MIN_SURFACE_TEMPERATURE_K: float(global_stats.get("min", 0.0)),
		KEY_ANNUAL_GLOBAL_MAX_SURFACE_TEMPERATURE_K: float(global_stats.get("max", 0.0)),
		KEY_ANNUAL_GLOBAL_MEAN_SURFACE_TEMPERATURE_K: annual_global_mean_surface_temperature_k,
		KEY_ANNUAL_MAX_BAND_SPAN_K: maxf(
			float(south_stats.get("span", 0.0)),
			maxf(float(equator_stats.get("span", 0.0)), float(north_stats.get("span", 0.0)))
		),
		KEY_ANNUAL_MODERATE_SAMPLE_FRACTION: _moderate_sample_fraction(all_samples_k),
	}


func _parent_chain_defs_for_body(body_id: StringName) -> Array[BodyDef]:
	var chain: Array[BodyDef] = []
	if _registry == null:
		return chain
	var def: BodyDef = _registry.get_def(body_id)
	if def == null:
		return chain
	var current_id: StringName = def.parent_id
	var hop_limit: int = 64
	while current_id != StringName("") and hop_limit > 0:
		var current_def: BodyDef = _registry.get_def(current_id)
		if current_def == null:
			return []
		chain.append(current_def)
		current_id = current_def.parent_id
		hop_limit -= 1
	if current_id != StringName(""):
		return []
	return chain


static func _find_luminous_ancestor_def(parent_chain_defs: Array[BodyDef]) -> BodyDef:
	for def in parent_chain_defs:
		if def != null and def.luminosity_w > 0.0:
			return def
	return null


static func _def_lookup_from_chain(body_def: BodyDef, parent_chain_defs: Array[BodyDef]) -> Dictionary:
	var lookup: Dictionary = {}
	if body_def != null:
		lookup[body_def.id] = body_def
	for parent_def in parent_chain_defs:
		if parent_def != null:
			lookup[parent_def.id] = parent_def
	return lookup


static func _orbital_period_s_for_def(def: BodyDef, def_lookup: Dictionary) -> float:
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


static func _sample_time_s(profile: OrbitProfile, period_s: float, sample_index: int) -> float:
	if profile != null and profile.mode == OrbitMode.Kind.KEPLER_APPROX:
		return profile.epoch_s + period_s * (float(sample_index) / float(SAMPLE_COUNT))
	return period_s * (float(sample_index) / float(SAMPLE_COUNT))


static func _body_to_ancestor_vector_at_from_lookup(
		body_id: StringName,
		ancestor_id: StringName,
		t_s: float,
		def_lookup: Dictionary
	) -> Vector3:
	var current_id: StringName = body_id
	var x_m: float = 0.0
	var y_m: float = 0.0
	var z_m: float = 0.0
	var hop_limit: int = 64

	while current_id != ancestor_id and hop_limit > 0:
		if current_id == StringName(""):
			return Vector3.INF
		var current_def: BodyDef = _lookup_def(def_lookup, current_id)
		if current_def == null or current_def.orbit_profile == null:
			return Vector3.INF
		var offset_m: Vector3 = _position_relative_to_parent_at_from_lookup(current_def, t_s, def_lookup)
		if not _is_finite_vec3(offset_m):
			return Vector3.INF
		x_m -= offset_m.x
		y_m -= offset_m.y
		z_m -= offset_m.z
		current_id = current_def.parent_id
		hop_limit -= 1

	if current_id != ancestor_id:
		return Vector3.INF
	return Vector3(x_m, y_m, z_m)


static func _position_relative_to_parent_at_from_lookup(
		def: BodyDef,
		t_s: float,
		def_lookup: Dictionary
	) -> Vector3:
	if def == null or def.orbit_profile == null:
		return Vector3.INF
	var profile: OrbitProfile = def.orbit_profile
	match profile.mode:
		OrbitMode.Kind.AUTHORED_ORBIT:
			return OrbitMath.authored_circular_position(
				profile.authored_radius_m,
				profile.authored_period_s,
				profile.authored_phase_rad,
				t_s
			)
		OrbitMode.Kind.KEPLER_APPROX:
			var parent_def: BodyDef = _lookup_def(def_lookup, def.parent_id)
			if parent_def == null:
				return Vector3.INF
			return OrbitMath.kepler_position(
				profile.semi_major_axis_m,
				profile.eccentricity,
				profile.inclination_rad,
				profile.longitude_ascending_node_rad,
				profile.argument_periapsis_rad,
				profile.mean_anomaly_epoch_rad,
				profile.epoch_s,
				UnitSystem.mu_from_mass(parent_def.mass_kg),
				t_s
			)
	return Vector3.INF


static func _lookup_def(def_lookup: Dictionary, id: StringName) -> BodyDef:
	return def_lookup.get(id, null) as BodyDef


static func _buffered_samples(climate_buffer_factor: float, raw_samples_k: Array[float]) -> Array[float]:
	if raw_samples_k.is_empty():
		return []
	var mean_raw_k: float = 0.0
	for sample_k in raw_samples_k:
		if not is_finite(sample_k) or sample_k < 0.0:
			return []
		mean_raw_k += sample_k
	mean_raw_k /= float(raw_samples_k.size())
	var buffer_scale: float = lerpf(1.0, 0.45, clampf(climate_buffer_factor, 0.0, 1.0))
	var out: Array[float] = []
	for raw_sample_k in raw_samples_k:
		out.append(mean_raw_k + (raw_sample_k - mean_raw_k) * buffer_scale)
	return out


static func _sample_stats(samples_k: Array[float]) -> Dictionary:
	if samples_k.is_empty():
		return {"ok": false}
	var min_k: float = INF
	var max_k: float = -INF
	var mean_k: float = 0.0
	for sample_k in samples_k:
		if not is_finite(sample_k) or sample_k < 0.0:
			return {"ok": false}
		min_k = minf(min_k, sample_k)
		max_k = maxf(max_k, sample_k)
		mean_k += sample_k
	mean_k /= float(samples_k.size())
	return {
		"ok": true,
		"min": min_k,
		"max": max_k,
		"mean": mean_k,
		"span": max_k - min_k,
	}


static func _moderate_sample_fraction(samples_k: Array[float]) -> float:
	if samples_k.is_empty():
		return 0.0
	var moderate_count: int = 0
	for sample_k in samples_k:
		if sample_k >= 223.15 and sample_k <= 373.15:
			moderate_count += 1
	return float(moderate_count) / float(samples_k.size())


static func _area_weighted_band_mean(south_mean_k: float, equator_mean_k: float, north_mean_k: float) -> float:
	return (
		south_mean_k * SOUTH_BAND_WEIGHT
		+ equator_mean_k * EQUATOR_BAND_WEIGHT
		+ north_mean_k * NORTH_BAND_WEIGHT
	)


static func _default_description() -> Dictionary:
	return {
		KEY_HAS_SAMPLED_YEAR_BASIS: false,
		KEY_HAS_PRIMARY_SOURCE_ONLY_BASIS: false,
		KEY_SOUTH_BAND_MIN_SURFACE_TEMPERATURE_K: 0.0,
		KEY_SOUTH_BAND_MAX_SURFACE_TEMPERATURE_K: 0.0,
		KEY_SOUTH_BAND_MEAN_SURFACE_TEMPERATURE_K: 0.0,
		KEY_EQUATOR_BAND_MIN_SURFACE_TEMPERATURE_K: 0.0,
		KEY_EQUATOR_BAND_MAX_SURFACE_TEMPERATURE_K: 0.0,
		KEY_EQUATOR_BAND_MEAN_SURFACE_TEMPERATURE_K: 0.0,
		KEY_NORTH_BAND_MIN_SURFACE_TEMPERATURE_K: 0.0,
		KEY_NORTH_BAND_MAX_SURFACE_TEMPERATURE_K: 0.0,
		KEY_NORTH_BAND_MEAN_SURFACE_TEMPERATURE_K: 0.0,
		KEY_ANNUAL_GLOBAL_MIN_SURFACE_TEMPERATURE_K: 0.0,
		KEY_ANNUAL_GLOBAL_MAX_SURFACE_TEMPERATURE_K: 0.0,
		KEY_ANNUAL_GLOBAL_MEAN_SURFACE_TEMPERATURE_K: 0.0,
		KEY_ANNUAL_MAX_BAND_SPAN_K: 0.0,
		KEY_ANNUAL_MODERATE_SAMPLE_FRACTION: 0.0,
	}


static func _is_finite_vec3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
