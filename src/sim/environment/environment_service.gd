class_name EnvironmentService
extends Node

# Read-only Derived-Service fuer qualitative Umweltklassifikation.
# Liest Registry + AtmosphereService on-demand; kein Cache, kein Tick-Hook.
# `environment_class` ist nur dann als echte Umwelt-Aussage zu lesen,
# wenn `is_supported_body_kind == true`. Der Default `HOSTILE` im
# Fehlerpfad ist ein Fallback, keine physikalische Aussage ueber
# unbekannte oder nicht unterstuetzte Bodies.

enum Class {
	HABITABLE,
	MARGINAL,
	HOSTILE,
}

const HABITABLE_MIN_T_K: float = 273.15
const HABITABLE_MAX_T_K: float = 323.15
const MARGINAL_MIN_T_K: float = 223.15
const MARGINAL_MAX_T_K: float = 373.15

var _registry: Node = null
var _atmosphere_service: Node = null


func configure(registry: Node, atmosphere_service: Node) -> void:
	assert(registry != null, "EnvironmentService.configure: registry is null")
	assert(atmosphere_service != null, "EnvironmentService.configure: atmosphere_service is null")
	assert(atmosphere_service.has_method("describe_body"),
		"EnvironmentService.configure: atmosphere_service must implement describe_body(id)")
	_registry = registry
	_atmosphere_service = atmosphere_service


func classify(id: StringName) -> int:
	return int(describe_body(id).get("environment_class", Class.HOSTILE))


func describe_body(id: StringName) -> Dictionary:
	var description: Dictionary = _default_description(id)
	if _registry == null or _atmosphere_service == null:
		return description

	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return description

	var atmosphere_desc: Dictionary = _atmosphere_service.describe_body(id)
	description["source_id"] = atmosphere_desc.get("source_id", StringName(""))
	description["equilibrium_temperature_k"] = float(atmosphere_desc.get("equilibrium_temperature_k", 0.0))
	description["greenhouse_delta_k"] = float(atmosphere_desc.get("greenhouse_delta_k", 0.0))
	description["surface_temperature_k"] = float(atmosphere_desc.get("surface_temperature_k", 0.0))
	description["has_luminous_ancestor"] = bool(atmosphere_desc.get("has_luminous_ancestor", false))

	if not _is_supported_body_kind(def.kind):
		return description

	description["is_supported_body_kind"] = true
	description["environment_class"] = _classify_temperature_k(
		float(description.get("surface_temperature_k", 0.0))
	)
	return description


static func to_string_class(value: int) -> String:
	match value:
		Class.HABITABLE:
			return "HABITABLE"
		Class.MARGINAL:
			return "MARGINAL"
		Class.HOSTILE:
			return "HOSTILE"
	return "UNKNOWN"


static func _default_description(id: StringName) -> Dictionary:
	return {
		"body_id": id,
		"source_id": StringName(""),
		"equilibrium_temperature_k": 0.0,
		"greenhouse_delta_k": 0.0,
		"surface_temperature_k": 0.0,
		"environment_class": Class.HOSTILE,
		"is_supported_body_kind": false,
		"has_luminous_ancestor": false,
	}


static func _is_supported_body_kind(kind: int) -> bool:
	return kind == BodyType.Kind.PLANET or kind == BodyType.Kind.MOON


static func _classify_temperature_k(teq_k: float) -> int:
	if not is_finite(teq_k) or teq_k <= 0.0:
		return Class.HOSTILE
	if teq_k >= HABITABLE_MIN_T_K and teq_k <= HABITABLE_MAX_T_K:
		return Class.HABITABLE
	if teq_k >= MARGINAL_MIN_T_K and teq_k < HABITABLE_MIN_T_K:
		return Class.MARGINAL
	if teq_k > HABITABLE_MAX_T_K and teq_k <= MARGINAL_MAX_T_K:
		return Class.MARGINAL
	return Class.HOSTILE
