class_name ThermalService
extends Node

# Read-only Derived-Service fuer minimale Thermalableitung.
# Liest BodyState.position_parent_frame_m direkt; der Caller ist dafuer
# verantwortlich, dass die States nach dem letzten OrbitService-Tick
# oder recompute_all_at_time() aktuell und konsistent sind.
# P7 nutzt ein on-demand Null-D-Modell mit uniformer /4-Redistribution
# (Fast-Rotator-Annahme). P11 erweitert das Modell um saisonale
# Insolationsgeometrie im Parent-kompatiblen Frame. source_dir_hat meint
# dabei immer den normierten Vektor von Body -> Quelle; ein fehlender
# saisonaler Basis-Frame liefert bewusst nur 0.0-Werte.

const HALF_PI: float = PI * 0.5
const POLAR_LATITUDE_EPSILON_RAD: float = 1.0e-6

var _registry: Node = null


func configure(registry: Node) -> void:
	assert(registry != null, "ThermalService.configure: registry is null")
	_registry = registry


func compute_insolation_wpm2(id: StringName) -> float:
	return float(describe_body(id).get("insolation_wpm2", 0.0))


func compute_absorbed_flux_wpm2(id: StringName) -> float:
	return float(describe_body(id).get("absorbed_flux_wpm2", 0.0))


func compute_equilibrium_temperature_k(id: StringName) -> float:
	return float(describe_body(id).get("equilibrium_temperature_k", 0.0))


func compute_subsolar_latitude_rad(id: StringName) -> float:
	return float(describe_body(id).get("subsolar_latitude_rad", 0.0))


func compute_daily_mean_insolation_wpm2(id: StringName, latitude_rad: float) -> float:
	if not is_finite(latitude_rad):
		return 0.0
	var radiative_context: Dictionary = _evaluate_radiative_context(id)
	if not bool(radiative_context.get("ok", false)):
		return 0.0
	var seasonal_context: Dictionary = _evaluate_seasonal_context(radiative_context)
	if not bool(seasonal_context.get("ok", false)):
		return 0.0
	return _compute_daily_mean_insolation_from(
		float(radiative_context.get("insolation_wpm2", 0.0)),
		float(seasonal_context.get("subsolar_latitude_rad", 0.0)),
		latitude_rad
	)


func describe_body(id: StringName) -> Dictionary:
	var description: Dictionary = _default_description(id)
	var radiative_context: Dictionary = _evaluate_radiative_context(id)
	if not bool(radiative_context.get("ok", false)):
		return description

	description["source_id"] = radiative_context.get("source_id", StringName(""))
	description["distance_to_source_m"] = float(radiative_context.get("distance_to_source_m", 0.0))
	description["insolation_wpm2"] = float(radiative_context.get("insolation_wpm2", 0.0))
	description["albedo"] = float(radiative_context.get("albedo", 0.0))
	description["absorbed_flux_wpm2"] = float(radiative_context.get("absorbed_flux_wpm2", 0.0))
	description["equilibrium_temperature_k"] = float(radiative_context.get("equilibrium_temperature_k", 0.0))
	description["has_luminous_ancestor"] = true

	var seasonal_context: Dictionary = _evaluate_seasonal_context(radiative_context)
	if not bool(seasonal_context.get("ok", false)):
		return description

	var subsolar_latitude_rad: float = float(seasonal_context.get("subsolar_latitude_rad", 0.0))
	description["subsolar_latitude_rad"] = subsolar_latitude_rad
	description["equator_daily_mean_insolation_wpm2"] = _compute_daily_mean_insolation_from(
		float(radiative_context.get("insolation_wpm2", 0.0)),
		subsolar_latitude_rad,
		0.0
	)
	description["north_pole_daily_mean_insolation_wpm2"] = _compute_daily_mean_insolation_from(
		float(radiative_context.get("insolation_wpm2", 0.0)),
		subsolar_latitude_rad,
		HALF_PI
	)
	description["south_pole_daily_mean_insolation_wpm2"] = _compute_daily_mean_insolation_from(
		float(radiative_context.get("insolation_wpm2", 0.0)),
		subsolar_latitude_rad,
		-HALF_PI
	)
	description["has_seasonal_basis"] = true
	return description


func _find_luminous_ancestor_id(start_id: StringName) -> StringName:
	if _registry == null:
		return StringName("")

	var current_id: StringName = start_id
	while current_id != StringName(""):
		var current_def: BodyDef = _registry.get_def(current_id)
		if current_def == null:
			return StringName("")
		if current_def.luminosity_w > 0.0:
			return current_id
		current_id = current_def.parent_id
	return StringName("")


func _evaluate_radiative_context(id: StringName) -> Dictionary:
	if _registry == null:
		return {"ok": false}

	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return {"ok": false}
	var albedo: float = def.albedo
	if not is_finite(albedo) or albedo < 0.0:
		return {"ok": false}

	var source_id: StringName = _find_luminous_ancestor_id(def.parent_id)
	if source_id == StringName(""):
		return {"ok": false}

	var source_def: BodyDef = _registry.get_def(source_id)
	if source_def == null or source_def.luminosity_w <= 0.0 or not is_finite(source_def.luminosity_w):
		return {"ok": false}

	var source_vector_info: Dictionary = _body_to_ancestor_vector(id, source_id)
	if not bool(source_vector_info.get("ok", false)):
		return {"ok": false}

	var body_to_source_m: Vector3 = source_vector_info.get("body_to_ancestor_m", Vector3.ZERO)
	var distance_to_source_m: float = body_to_source_m.length()
	if distance_to_source_m <= 0.0 or not is_finite(distance_to_source_m):
		return {"ok": false}

	var insolation_wpm2: float = source_def.luminosity_w / (4.0 * PI * distance_to_source_m * distance_to_source_m)
	if not is_finite(insolation_wpm2) or insolation_wpm2 < 0.0:
		return {"ok": false}

	var absorbed_flux_wpm2: float = _compute_absorbed_flux_wpm2_from(insolation_wpm2, albedo)
	var equilibrium_temperature_k: float = _compute_equilibrium_temperature_k_from(absorbed_flux_wpm2)
	return {
		"ok": true,
		"body_def": def,
		"source_id": source_id,
		"distance_to_source_m": distance_to_source_m,
		"body_to_source_m": body_to_source_m,
		"albedo": albedo,
		"insolation_wpm2": insolation_wpm2,
		"absorbed_flux_wpm2": absorbed_flux_wpm2,
		"equilibrium_temperature_k": equilibrium_temperature_k,
	}


func _body_to_ancestor_vector(body_id: StringName, ancestor_id: StringName) -> Dictionary:
	if _registry == null:
		return {"ok": false, "body_to_ancestor_m": Vector3.ZERO}

	var current_id: StringName = body_id
	var x_m: float = 0.0
	var y_m: float = 0.0
	var z_m: float = 0.0

	while current_id != ancestor_id:
		if current_id == StringName(""):
			return {"ok": false, "body_to_ancestor_m": Vector3.ZERO}
		var current_def: BodyDef = _registry.get_def(current_id)
		var current_state: BodyState = _registry.get_state(current_id)
		if current_def == null or current_state == null:
			return {"ok": false, "body_to_ancestor_m": Vector3.ZERO}
		var offset_m: Vector3 = current_state.position_parent_frame_m
		if not _is_finite_vec3(offset_m):
			return {"ok": false, "body_to_ancestor_m": Vector3.ZERO}
		x_m -= offset_m.x
		y_m -= offset_m.y
		z_m -= offset_m.z
		current_id = current_def.parent_id

	return {
		"ok": true,
		"body_to_ancestor_m": Vector3(x_m, y_m, z_m),
	}


func _default_description(id: StringName) -> Dictionary:
	return {
		"body_id": id,
		"source_id": StringName(""),
		"distance_to_source_m": 0.0,
		"insolation_wpm2": 0.0,
		"albedo": 0.0,
		"absorbed_flux_wpm2": 0.0,
		"equilibrium_temperature_k": 0.0,
		"has_luminous_ancestor": false,
		"has_seasonal_basis": false,
		"subsolar_latitude_rad": 0.0,
		"equator_daily_mean_insolation_wpm2": 0.0,
		"north_pole_daily_mean_insolation_wpm2": 0.0,
		"south_pole_daily_mean_insolation_wpm2": 0.0,
	}


func _evaluate_seasonal_context(radiative_context: Dictionary) -> Dictionary:
	var def: BodyDef = radiative_context.get("body_def", null) as BodyDef
	if def == null or def.is_root():
		return {"ok": false}
	var profile: OrbitProfile = def.orbit_profile
	if profile == null:
		return {"ok": false}
	if not is_finite(def.axial_tilt_rad) or not is_finite(def.north_pole_orbit_frame_azimuth_rad):
		return {"ok": false}

	var body_to_source_m: Vector3 = radiative_context.get("body_to_source_m", Vector3.ZERO)
	if not _is_finite_vec3(body_to_source_m) or body_to_source_m.length_squared() <= 0.0:
		return {"ok": false}

	var sin_tilt: float = sin(def.axial_tilt_rad)
	var cos_tilt: float = cos(def.axial_tilt_rad)
	var cos_azimuth: float = cos(def.north_pole_orbit_frame_azimuth_rad)
	var sin_azimuth: float = sin(def.north_pole_orbit_frame_azimuth_rad)
	var spin_axis_orbit_frame := Vector3(
		sin_tilt * cos_azimuth,
		sin_tilt * sin_azimuth,
		cos_tilt
	)
	if not _is_finite_vec3(spin_axis_orbit_frame) or spin_axis_orbit_frame.length_squared() <= 0.0:
		return {"ok": false}

	var spin_axis_parent_frame: Vector3 = _rotate_orbit_frame_vector_to_parent(spin_axis_orbit_frame, profile)
	if not _is_finite_vec3(spin_axis_parent_frame) or spin_axis_parent_frame.length_squared() <= 0.0:
		return {"ok": false}

	var spin_axis_hat: Vector3 = spin_axis_parent_frame.normalized()
	var source_dir_hat: Vector3 = body_to_source_m.normalized()
	var dot_value: float = clampf(spin_axis_hat.dot(source_dir_hat), -1.0, 1.0)
	if not is_finite(dot_value):
		return {"ok": false}
	return {
		"ok": true,
		"subsolar_latitude_rad": asin(dot_value),
	}


func _rotate_orbit_frame_vector_to_parent(vector_orbit_frame: Vector3, profile: OrbitProfile) -> Vector3:
	if profile == null:
		return Vector3.ZERO
	match profile.mode:
		OrbitMode.Kind.AUTHORED_ORBIT:
			return vector_orbit_frame
		OrbitMode.Kind.KEPLER_APPROX:
			return OrbitMath.rotate_orbit_frame_vector(
				vector_orbit_frame,
				profile.inclination_rad,
				profile.longitude_ascending_node_rad,
				profile.argument_periapsis_rad
			)
		_:
			return Vector3.ZERO


static func _compute_absorbed_flux_wpm2_from(insolation_wpm2: float, albedo: float) -> float:
	if not is_finite(insolation_wpm2) or insolation_wpm2 <= 0.0:
		return 0.0
	if not is_finite(albedo) or albedo < 0.0:
		return 0.0
	if albedo >= 1.0:
		return 0.0
	var absorbed_flux_wpm2: float = (1.0 - albedo) * insolation_wpm2 / 4.0
	if not is_finite(absorbed_flux_wpm2) or absorbed_flux_wpm2 < 0.0:
		return 0.0
	return absorbed_flux_wpm2


static func _compute_equilibrium_temperature_k_from(absorbed_flux_wpm2: float) -> float:
	if not is_finite(absorbed_flux_wpm2) or absorbed_flux_wpm2 <= 0.0:
		return 0.0
	var equilibrium_temperature_k: float = pow(
		absorbed_flux_wpm2 / UnitSystem.STEFAN_BOLTZMANN_WPM2K4,
		0.25
	)
	if not is_finite(equilibrium_temperature_k) or equilibrium_temperature_k < 0.0:
		return 0.0
	return equilibrium_temperature_k


static func _compute_daily_mean_insolation_from(insolation_wpm2: float,
		subsolar_latitude_rad: float, latitude_rad: float) -> float:
	if not is_finite(insolation_wpm2) or insolation_wpm2 <= 0.0:
		return 0.0
	if not is_finite(subsolar_latitude_rad) or not is_finite(latitude_rad):
		return 0.0
	var delta: float = clampf(subsolar_latitude_rad, -HALF_PI, HALF_PI)
	var phi: float = clampf(latitude_rad, -HALF_PI, HALF_PI)
	var sin_phi: float = sin(phi)
	var sin_delta: float = sin(delta)

	if absf(absf(phi) - HALF_PI) <= POLAR_LATITUDE_EPSILON_RAD:
		var polar_projection: float = sin_phi * sin_delta
		if polar_projection <= 0.0 or not is_finite(polar_projection):
			return 0.0
		var polar_day_wpm2: float = insolation_wpm2 * polar_projection
		if not is_finite(polar_day_wpm2) or polar_day_wpm2 < 0.0:
			return 0.0
		return polar_day_wpm2

	var cos_h0: float = -tan(phi) * tan(delta)
	if not is_finite(cos_h0):
		return 0.0
	if cos_h0 >= 1.0:
		return 0.0
	if cos_h0 <= -1.0:
		var polar_day_wpm2: float = insolation_wpm2 * sin_phi * sin_delta
		if not is_finite(polar_day_wpm2) or polar_day_wpm2 < 0.0:
			return 0.0
		return polar_day_wpm2

	var h0: float = acos(clampf(cos_h0, -1.0, 1.0))
	var daily_mean_wpm2: float = (insolation_wpm2 / PI) * (
		h0 * sin_phi * sin_delta + cos(phi) * cos(delta) * sin(h0)
	)
	if not is_finite(daily_mean_wpm2) or daily_mean_wpm2 < 0.0:
		return 0.0
	return daily_mean_wpm2


static func _is_finite_vec3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
