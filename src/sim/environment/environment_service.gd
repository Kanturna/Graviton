class_name EnvironmentService
extends Node

# Read-only Derived-Service fuer qualitative Umweltklassifikation.
# Liest Registry + AtmosphereService on-demand; kein Cache, kein Tick-Hook.
# `environment_class` ist nur dann als echte Umwelt-Aussage zu lesen,
# wenn `is_supported_body_kind == true`. Der Default `HOSTILE` im
# Fehlerpfad ist ein Fallback, keine physikalische Aussage ueber
# unbekannte oder nicht unterstuetzte Bodies. `ecosystem_type` ist
# ebenfalls nur fuer unterstuetzte Bodies mit latitudinaler Basis als
# echte Umwelt-Aussage zu lesen.

enum Class {
	HABITABLE,
	MARGINAL,
	HOSTILE,
}

enum EcosystemType {
	FROZEN_WORLD,
	TEMPERATE_WORLD,
	SEASONAL_WORLD,
	HOT_WORLD,
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
	description["has_latitudinal_surface_basis"] = bool(atmosphere_desc.get("has_latitudinal_surface_basis", false))
	description["south_midlatitude_surface_temperature_k"] = float(
		atmosphere_desc.get("south_midlatitude_surface_temperature_k", 0.0)
	)
	description["equator_surface_temperature_k"] = float(
		atmosphere_desc.get("equator_surface_temperature_k", 0.0)
	)
	description["north_midlatitude_surface_temperature_k"] = float(
		atmosphere_desc.get("north_midlatitude_surface_temperature_k", 0.0)
	)
	description["has_luminous_ancestor"] = bool(atmosphere_desc.get("has_luminous_ancestor", false))

	if not _is_supported_body_kind(def.kind):
		return description

	description["is_supported_body_kind"] = true
	var band_temperatures_k: Array[float] = _band_temperatures_from_description(description)
	description["has_habitable_band"] = _has_habitable_band(band_temperatures_k)
	description["has_liquid_water_band"] = _has_liquid_water_band(band_temperatures_k)
	description["environment_class"] = _classify_band_temperatures_k(band_temperatures_k)
	description["ecosystem_type"] = _classify_ecosystem_type(band_temperatures_k)
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


static func to_string_ecosystem(value: int) -> String:
	match value:
		EcosystemType.FROZEN_WORLD:
			return "FROZEN"
		EcosystemType.TEMPERATE_WORLD:
			return "TEMPERATE"
		EcosystemType.SEASONAL_WORLD:
			return "SEASONAL"
		EcosystemType.HOT_WORLD:
			return "HOT"
	return "UNKNOWN"


static func _default_description(id: StringName) -> Dictionary:
	return {
		"body_id": id,
		"source_id": StringName(""),
		"equilibrium_temperature_k": 0.0,
		"greenhouse_delta_k": 0.0,
		"surface_temperature_k": 0.0,
		"has_latitudinal_surface_basis": false,
		"south_midlatitude_surface_temperature_k": 0.0,
		"equator_surface_temperature_k": 0.0,
		"north_midlatitude_surface_temperature_k": 0.0,
		"environment_class": Class.HOSTILE,
		"ecosystem_type": EcosystemType.FROZEN_WORLD,
		"is_supported_body_kind": false,
		"has_habitable_band": false,
		"has_liquid_water_band": false,
		"has_luminous_ancestor": false,
	}


static func _is_supported_body_kind(kind: int) -> bool:
	return kind == BodyType.Kind.PLANET or kind == BodyType.Kind.MOON


static func _band_temperatures_from_description(description: Dictionary) -> Array[float]:
	return [
		float(description.get("south_midlatitude_surface_temperature_k", 0.0)),
		float(description.get("equator_surface_temperature_k", 0.0)),
		float(description.get("north_midlatitude_surface_temperature_k", 0.0)),
	]


static func _classify_band_temperatures_k(band_temperatures_k: Array[float]) -> int:
	if band_temperatures_k.is_empty():
		return Class.HOSTILE
	if _has_habitable_band(band_temperatures_k):
		return Class.HABITABLE
	if _has_marginal_band(band_temperatures_k):
		return Class.MARGINAL
	return Class.HOSTILE


static func _classify_ecosystem_type(band_temperatures_k: Array[float]) -> int:
	if band_temperatures_k.is_empty():
		return EcosystemType.FROZEN_WORLD
	var all_frozen: bool = true
	var all_temperate: bool = true
	var all_hot: bool = true
	for temperature_k in band_temperatures_k:
		if not is_finite(temperature_k) or temperature_k <= 0.0:
			return EcosystemType.FROZEN_WORLD
		if temperature_k >= HABITABLE_MIN_T_K:
			all_frozen = false
		if temperature_k < HABITABLE_MIN_T_K or temperature_k > HABITABLE_MAX_T_K:
			all_temperate = false
		if temperature_k <= HABITABLE_MAX_T_K:
			all_hot = false
	if all_frozen:
		return EcosystemType.FROZEN_WORLD
	if all_temperate:
		return EcosystemType.TEMPERATE_WORLD
	if all_hot:
		return EcosystemType.HOT_WORLD
	return EcosystemType.SEASONAL_WORLD


static func _has_habitable_band(band_temperatures_k: Array[float]) -> bool:
	for temperature_k in band_temperatures_k:
		if not is_finite(temperature_k) or temperature_k <= 0.0:
			continue
		if temperature_k >= HABITABLE_MIN_T_K and temperature_k <= HABITABLE_MAX_T_K:
			return true
	return false


static func _has_liquid_water_band(band_temperatures_k: Array[float]) -> bool:
	for temperature_k in band_temperatures_k:
		if not is_finite(temperature_k) or temperature_k <= 0.0:
			continue
		if temperature_k >= HABITABLE_MIN_T_K and temperature_k <= MARGINAL_MAX_T_K:
			return true
	return false


static func _has_marginal_band(band_temperatures_k: Array[float]) -> bool:
	for temperature_k in band_temperatures_k:
		if not is_finite(temperature_k) or temperature_k <= 0.0:
			continue
		if temperature_k >= MARGINAL_MIN_T_K and temperature_k <= MARGINAL_MAX_T_K:
			return true
	return false
