class_name ThermalService
extends Node

# Read-only Derived-Service fuer minimale Thermalableitung.
# Liest BodyState.position_parent_frame_m direkt; der Caller ist dafuer
# verantwortlich, dass die States nach dem letzten OrbitService-Tick
# oder recompute_all_at_time() aktuell und konsistent sind.
# P7 nutzt ein on-demand Null-D-Modell mit uniformer /4-Redistribution
# (Fast-Rotator-Annahme). rotation_period_s und axial_tilt_rad werden
# bewusst noch ignoriert.

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


func describe_body(id: StringName) -> Dictionary:
	var description: Dictionary = _default_description(id)
	if _registry == null:
		return description

	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return description
	var albedo: float = def.albedo
	if not is_finite(albedo) or albedo < 0.0:
		return description

	var source_id: StringName = _find_luminous_ancestor_id(def.parent_id)
	if source_id == StringName(""):
		return description

	var source_def: BodyDef = _registry.get_def(source_id)
	if source_def == null or source_def.luminosity_w <= 0.0 or not is_finite(source_def.luminosity_w):
		return description

	var distance_info: Dictionary = _distance_to_ancestor(id, source_id)
	if not bool(distance_info.get("ok", false)):
		return description

	var distance_to_source_m: float = float(distance_info.get("distance_to_source_m", 0.0))
	if distance_to_source_m <= 0.0 or not is_finite(distance_to_source_m):
		return description

	var insolation_wpm2: float = source_def.luminosity_w / (4.0 * PI * distance_to_source_m * distance_to_source_m)
	if not is_finite(insolation_wpm2) or insolation_wpm2 < 0.0:
		return description

	var absorbed_flux_wpm2: float = _compute_absorbed_flux_wpm2_from(insolation_wpm2, albedo)
	var equilibrium_temperature_k: float = _compute_equilibrium_temperature_k_from(absorbed_flux_wpm2)

	description["source_id"] = source_id
	description["distance_to_source_m"] = distance_to_source_m
	description["insolation_wpm2"] = insolation_wpm2
	description["albedo"] = albedo
	description["absorbed_flux_wpm2"] = absorbed_flux_wpm2
	description["equilibrium_temperature_k"] = equilibrium_temperature_k
	description["has_luminous_ancestor"] = true
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


func _distance_to_ancestor(body_id: StringName, ancestor_id: StringName) -> Dictionary:
	if _registry == null:
		return {"ok": false, "distance_to_source_m": 0.0}

	var current_id: StringName = body_id
	var x_m: float = 0.0
	var y_m: float = 0.0
	var z_m: float = 0.0

	while current_id != ancestor_id:
		if current_id == StringName(""):
			return {"ok": false, "distance_to_source_m": 0.0}
		var current_def: BodyDef = _registry.get_def(current_id)
		var current_state: BodyState = _registry.get_state(current_id)
		if current_def == null or current_state == null:
			return {"ok": false, "distance_to_source_m": 0.0}
		var offset_m: Vector3 = current_state.position_parent_frame_m
		if not _is_finite_vec3(offset_m):
			return {"ok": false, "distance_to_source_m": 0.0}
		x_m += offset_m.x
		y_m += offset_m.y
		z_m += offset_m.z
		current_id = current_def.parent_id

	return {
		"ok": true,
		"distance_to_source_m": sqrt(x_m * x_m + y_m * y_m + z_m * z_m),
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
	}


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


static func _is_finite_vec3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
