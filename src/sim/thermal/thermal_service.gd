class_name ThermalService
extends Node

# Read-only Derived-Service fuer minimale Insolation.
# Liest BodyState.position_parent_frame_m direkt; der Caller ist dafuer
# verantwortlich, dass die States nach dem letzten OrbitService-Tick
# oder recompute_all_at_time() aktuell und konsistent sind.

var _registry: Node = null


func configure(registry: Node) -> void:
	assert(registry != null, "ThermalService.configure: registry is null")
	_registry = registry


func compute_insolation_wpm2(id: StringName) -> float:
	return float(describe_body(id).get("insolation_wpm2", 0.0))


func describe_body(id: StringName) -> Dictionary:
	var description: Dictionary = _default_description(id)
	if _registry == null:
		return description

	var def: BodyDef = _registry.get_def(id)
	if def == null:
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

	description["source_id"] = source_id
	description["distance_to_source_m"] = distance_to_source_m
	description["insolation_wpm2"] = insolation_wpm2
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
		"has_luminous_ancestor": false,
	}


static func _is_finite_vec3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
