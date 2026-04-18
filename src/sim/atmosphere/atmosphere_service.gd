class_name AtmosphereService
extends Node

# Read-only Derived-Service fuer minimale Atmosphaeren-/Greenhouse-Ableitung.
# Liest Registry + ThermalService on-demand; kein Cache, kein Tick-Hook.
# Kein physikalisches Atmosphaerenmodell, sondern nur additive
# Oberflaechenerwaermung auf Basis von `equilibrium_temperature_k`.
# Caller-Contract wie bei ThermalService: Die States muessen nach dem
# letzten OrbitService-Tick oder recompute_all_at_time() aktuell sein.

const MAX_GREENHOUSE_DELTA_K: float = 2000.0

var _registry: Node = null
var _thermal_service: Node = null


func configure(registry: Node, thermal_service: Node) -> void:
	assert(registry != null, "AtmosphereService.configure: registry is null")
	assert(thermal_service != null, "AtmosphereService.configure: thermal_service is null")
	assert(thermal_service.has_method("describe_body"),
		"AtmosphereService.configure: thermal_service must implement describe_body(id)")
	_registry = registry
	_thermal_service = thermal_service


func compute_greenhouse_delta_k(id: StringName) -> float:
	return float(describe_body(id).get("greenhouse_delta_k", 0.0))


func compute_surface_temperature_k(id: StringName) -> float:
	return float(describe_body(id).get("surface_temperature_k", 0.0))


func describe_body(id: StringName) -> Dictionary:
	var description: Dictionary = _default_description(id)
	if _registry == null or _thermal_service == null:
		return description

	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return description

	var greenhouse_delta_k: float = def.greenhouse_delta_k
	if not is_finite(greenhouse_delta_k) or greenhouse_delta_k < 0.0 or greenhouse_delta_k > MAX_GREENHOUSE_DELTA_K:
		return description
	description["greenhouse_delta_k"] = greenhouse_delta_k

	var thermal_desc: Dictionary = _thermal_service.describe_body(id)
	description["source_id"] = thermal_desc.get("source_id", StringName(""))
	description["equilibrium_temperature_k"] = float(thermal_desc.get("equilibrium_temperature_k", 0.0))
	description["has_luminous_ancestor"] = bool(thermal_desc.get("has_luminous_ancestor", false))

	var equilibrium_temperature_k: float = float(description.get("equilibrium_temperature_k", 0.0))
	if not is_finite(equilibrium_temperature_k) or equilibrium_temperature_k <= 0.0:
		return description

	var surface_temperature_k: float = equilibrium_temperature_k + greenhouse_delta_k
	if not is_finite(surface_temperature_k) or surface_temperature_k < 0.0:
		return description

	description["surface_temperature_k"] = surface_temperature_k
	return description


func _default_description(id: StringName) -> Dictionary:
	return {
		"body_id": id,
		"source_id": StringName(""),
		"equilibrium_temperature_k": 0.0,
		"greenhouse_delta_k": 0.0,
		"surface_temperature_k": 0.0,
		"has_luminous_ancestor": false,
	}
