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

const AtmosphereServiceScript = preload("res://src/sim/atmosphere/atmosphere_service.gd")

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
const KEY_BODY_ID: StringName = &"body_id"
const KEY_SOURCE_ID: StringName = &"source_id"
const KEY_EQUILIBRIUM_TEMPERATURE_K: StringName = &"equilibrium_temperature_k"
const KEY_GREENHOUSE_DELTA_K: StringName = &"greenhouse_delta_k"
const KEY_SURFACE_TEMPERATURE_K: StringName = &"surface_temperature_k"
const KEY_HAS_LATITUDINAL_SURFACE_BASIS: StringName = &"has_latitudinal_surface_basis"
const KEY_SOUTH_MIDLATITUDE_SURFACE_TEMPERATURE_K: StringName = &"south_midlatitude_surface_temperature_k"
const KEY_EQUATOR_SURFACE_TEMPERATURE_K: StringName = &"equator_surface_temperature_k"
const KEY_NORTH_MIDLATITUDE_SURFACE_TEMPERATURE_K: StringName = &"north_midlatitude_surface_temperature_k"
const KEY_ENVIRONMENT_CLASS: StringName = &"environment_class"
const KEY_ECOSYSTEM_TYPE: StringName = &"ecosystem_type"
const KEY_IS_SUPPORTED_BODY_KIND: StringName = &"is_supported_body_kind"
const KEY_HAS_HABITABLE_BAND: StringName = &"has_habitable_band"
const KEY_HAS_LIQUID_WATER_BAND: StringName = &"has_liquid_water_band"
const KEY_HAS_LUMINOUS_ANCESTOR: StringName = &"has_luminous_ancestor"

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
	return int(describe_body(id).get(KEY_ENVIRONMENT_CLASS, Class.HOSTILE))


func describe_body(id: StringName) -> Dictionary:
	var description: Dictionary = _default_description(id)
	if _registry == null or _atmosphere_service == null:
		return description

	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return description

	var atmosphere_desc: Dictionary = _atmosphere_service.describe_body(id)
	description[KEY_SOURCE_ID] = atmosphere_desc.get(AtmosphereServiceScript.KEY_SOURCE_ID, StringName(""))
	description[KEY_EQUILIBRIUM_TEMPERATURE_K] = float(
		atmosphere_desc.get(AtmosphereServiceScript.KEY_EQUILIBRIUM_TEMPERATURE_K, 0.0)
	)
	description[KEY_GREENHOUSE_DELTA_K] = float(
		atmosphere_desc.get(AtmosphereServiceScript.KEY_GREENHOUSE_DELTA_K, 0.0)
	)
	description[KEY_SURFACE_TEMPERATURE_K] = float(
		atmosphere_desc.get(AtmosphereServiceScript.KEY_SURFACE_TEMPERATURE_K, 0.0)
	)
	description[KEY_HAS_LATITUDINAL_SURFACE_BASIS] = bool(
		atmosphere_desc.get(AtmosphereServiceScript.KEY_HAS_LATITUDINAL_SURFACE_BASIS, false)
	)
	description[KEY_SOUTH_MIDLATITUDE_SURFACE_TEMPERATURE_K] = float(
		atmosphere_desc.get(AtmosphereServiceScript.KEY_SOUTH_MIDLATITUDE_SURFACE_TEMPERATURE_K, 0.0)
	)
	description[KEY_EQUATOR_SURFACE_TEMPERATURE_K] = float(
		atmosphere_desc.get(AtmosphereServiceScript.KEY_EQUATOR_SURFACE_TEMPERATURE_K, 0.0)
	)
	description[KEY_NORTH_MIDLATITUDE_SURFACE_TEMPERATURE_K] = float(
		atmosphere_desc.get(AtmosphereServiceScript.KEY_NORTH_MIDLATITUDE_SURFACE_TEMPERATURE_K, 0.0)
	)
	description[KEY_HAS_LUMINOUS_ANCESTOR] = bool(
		atmosphere_desc.get(AtmosphereServiceScript.KEY_HAS_LUMINOUS_ANCESTOR, false)
	)

	if not _is_supported_body_kind(def.kind):
		return description

	description[KEY_IS_SUPPORTED_BODY_KIND] = true
	var band_temperatures_k: Array[float] = _band_temperatures_from_description(description)
	description[KEY_HAS_HABITABLE_BAND] = _has_habitable_band(band_temperatures_k)
	description[KEY_HAS_LIQUID_WATER_BAND] = _has_liquid_water_band(band_temperatures_k)
	description[KEY_ENVIRONMENT_CLASS] = _classify_band_temperatures_k(band_temperatures_k)
	description[KEY_ECOSYSTEM_TYPE] = _classify_ecosystem_type(band_temperatures_k)
	return description


static func to_string_class(value: int) -> String:
	# Bewusste UX-Abweichung: Das Enum bleibt aus P12A/P13-Kompatibilitaetsgruenden
	# `MARGINAL`, aber die Spieler-Sprache nennt diesen Zustand `HARSH`.
	# `MARGINAL` klingt alltagssprachlich nach "knapp drin", waehrend das
	# System tatsaechlich "lebensfeindlich, aber nicht total tot" meint.
	match value:
		Class.HABITABLE:
			return "HABITABLE"
		Class.MARGINAL:
			return "HARSH"
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
		KEY_BODY_ID: id,
		KEY_SOURCE_ID: StringName(""),
		KEY_EQUILIBRIUM_TEMPERATURE_K: 0.0,
		KEY_GREENHOUSE_DELTA_K: 0.0,
		KEY_SURFACE_TEMPERATURE_K: 0.0,
		KEY_HAS_LATITUDINAL_SURFACE_BASIS: false,
		KEY_SOUTH_MIDLATITUDE_SURFACE_TEMPERATURE_K: 0.0,
		KEY_EQUATOR_SURFACE_TEMPERATURE_K: 0.0,
		KEY_NORTH_MIDLATITUDE_SURFACE_TEMPERATURE_K: 0.0,
		KEY_ENVIRONMENT_CLASS: Class.HOSTILE,
		KEY_ECOSYSTEM_TYPE: EcosystemType.FROZEN_WORLD,
		KEY_IS_SUPPORTED_BODY_KIND: false,
		KEY_HAS_HABITABLE_BAND: false,
		KEY_HAS_LIQUID_WATER_BAND: false,
		KEY_HAS_LUMINOUS_ANCESTOR: false,
	}


static func _is_supported_body_kind(kind: int) -> bool:
	return kind == BodyType.Kind.PLANET or kind == BodyType.Kind.MOON


static func _band_temperatures_from_description(description: Dictionary) -> Array[float]:
	return [
		float(description.get(KEY_SOUTH_MIDLATITUDE_SURFACE_TEMPERATURE_K, 0.0)),
		float(description.get(KEY_EQUATOR_SURFACE_TEMPERATURE_K, 0.0)),
		float(description.get(KEY_NORTH_MIDLATITUDE_SURFACE_TEMPERATURE_K, 0.0)),
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
