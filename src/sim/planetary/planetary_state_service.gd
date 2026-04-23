class_name PlanetaryStateService
extends Node


const PlanetaryYearSamplerScript = preload("res://src/sim/planetary/planetary_year_sampler.gd")

enum VolatileInventoryClass {
	TRACE,
	LIMITED,
	RICH,
}

enum ClimateBufferClass {
	UNBUFFERED,
	MODERATE,
	BUFFERED,
}

enum ThermalExtremityClass {
	FROZEN,
	COLD,
	TEMPERATE,
	HOT,
	EXTREME,
}

enum SeasonalityClass {
	LOW,
	SEASONAL,
	VIOLENT,
}

enum StabilityClass {
	FRAGILE,
	WINDOWED,
	STABLE,
}

const KEY_BODY_ID: StringName = &"body_id"
const KEY_IS_SUPPORTED_BODY_KIND: StringName = &"is_supported_body_kind"
const KEY_HAS_SAMPLED_YEAR_BASIS: StringName = PlanetaryYearSamplerScript.KEY_HAS_SAMPLED_YEAR_BASIS
const KEY_HAS_PRIMARY_SOURCE_ONLY_BASIS: StringName = PlanetaryYearSamplerScript.KEY_HAS_PRIMARY_SOURCE_ONLY_BASIS
const KEY_SOUTH_BAND_MIN_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_SOUTH_BAND_MIN_SURFACE_TEMPERATURE_K
const KEY_SOUTH_BAND_MAX_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_SOUTH_BAND_MAX_SURFACE_TEMPERATURE_K
const KEY_SOUTH_BAND_MEAN_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_SOUTH_BAND_MEAN_SURFACE_TEMPERATURE_K
const KEY_EQUATOR_BAND_MIN_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_EQUATOR_BAND_MIN_SURFACE_TEMPERATURE_K
const KEY_EQUATOR_BAND_MAX_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_EQUATOR_BAND_MAX_SURFACE_TEMPERATURE_K
const KEY_EQUATOR_BAND_MEAN_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_EQUATOR_BAND_MEAN_SURFACE_TEMPERATURE_K
const KEY_NORTH_BAND_MIN_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_NORTH_BAND_MIN_SURFACE_TEMPERATURE_K
const KEY_NORTH_BAND_MAX_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_NORTH_BAND_MAX_SURFACE_TEMPERATURE_K
const KEY_NORTH_BAND_MEAN_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_NORTH_BAND_MEAN_SURFACE_TEMPERATURE_K
const KEY_ANNUAL_GLOBAL_MIN_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_ANNUAL_GLOBAL_MIN_SURFACE_TEMPERATURE_K
const KEY_ANNUAL_GLOBAL_MAX_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_ANNUAL_GLOBAL_MAX_SURFACE_TEMPERATURE_K
const KEY_ANNUAL_GLOBAL_MEAN_SURFACE_TEMPERATURE_K: StringName = PlanetaryYearSamplerScript.KEY_ANNUAL_GLOBAL_MEAN_SURFACE_TEMPERATURE_K
const KEY_ANNUAL_MAX_BAND_SPAN_K: StringName = PlanetaryYearSamplerScript.KEY_ANNUAL_MAX_BAND_SPAN_K
const KEY_ANNUAL_MODERATE_SAMPLE_FRACTION: StringName = PlanetaryYearSamplerScript.KEY_ANNUAL_MODERATE_SAMPLE_FRACTION
const KEY_VOLATILE_INVENTORY_CLASS: StringName = &"volatile_inventory_class"
const KEY_CLIMATE_BUFFER_CLASS: StringName = &"climate_buffer_class"
const KEY_THERMAL_EXTREMITY_CLASS: StringName = &"thermal_extremity_class"
const KEY_SEASONALITY_CLASS: StringName = &"seasonality_class"
const KEY_STABILITY_CLASS: StringName = &"stability_class"

var _registry: Node = null
var _thermal_service: Node = null
var _atmosphere_service: Node = null
var _year_sampler: Node = null
var _annual_profile_cache_by_id: Dictionary = {}


func configure(registry: Node, thermal_service: Node, atmosphere_service: Node, year_sampler: Node) -> void:
	assert(registry != null, "PlanetaryStateService.configure: registry is null")
	assert(thermal_service != null, "PlanetaryStateService.configure: thermal_service is null")
	assert(atmosphere_service != null, "PlanetaryStateService.configure: atmosphere_service is null")
	assert(year_sampler != null, "PlanetaryStateService.configure: year_sampler is null")
	assert(year_sampler.has_method("sample_body"), "PlanetaryStateService.configure: year_sampler must implement sample_body(id)")
	_registry = registry
	_thermal_service = thermal_service
	_atmosphere_service = atmosphere_service
	_year_sampler = year_sampler
	clear_cache()


func clear_cache() -> void:
	_annual_profile_cache_by_id.clear()


func describe_body(id: StringName) -> Dictionary:
	if _registry == null:
		return _default_description(id)
	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return _default_description(id)
	var annual_profile: Dictionary = _annual_profile_for(id)
	return describe_from_def_and_annual_profile(id, def, annual_profile)


static func describe_from_def_and_annual_profile(
		id: StringName,
		def: BodyDef,
		annual_profile: Dictionary
	) -> Dictionary:
	var description: Dictionary = _default_description(id)
	if def == null:
		return description
	if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
		return description

	description[KEY_IS_SUPPORTED_BODY_KIND] = true
	description[KEY_VOLATILE_INVENTORY_CLASS] = _volatile_inventory_class_of(def.volatile_inventory_ratio)
	description[KEY_CLIMATE_BUFFER_CLASS] = _climate_buffer_class_of(def.climate_buffer_factor)
	for key in annual_profile.keys():
		description[key] = annual_profile[key]
	if not bool(description.get(KEY_HAS_SAMPLED_YEAR_BASIS, false)):
		return description

	var annual_mean_k: float = float(description.get(KEY_ANNUAL_GLOBAL_MEAN_SURFACE_TEMPERATURE_K, 0.0))
	var annual_max_band_span_k: float = float(description.get(KEY_ANNUAL_MAX_BAND_SPAN_K, 0.0))
	var annual_moderate_fraction: float = float(description.get(KEY_ANNUAL_MODERATE_SAMPLE_FRACTION, 0.0))
	description[KEY_THERMAL_EXTREMITY_CLASS] = _thermal_extremity_class_of(annual_mean_k)
	description[KEY_SEASONALITY_CLASS] = _seasonality_class_of(annual_max_band_span_k)
	description[KEY_STABILITY_CLASS] = _stability_class_of(annual_moderate_fraction, annual_max_band_span_k)
	return description



func _annual_profile_for(id: StringName) -> Dictionary:
	if _annual_profile_cache_by_id.has(id):
		return _annual_profile_cache_by_id[id]
	var annual_profile: Dictionary = _year_sampler.sample_body(id)
	_annual_profile_cache_by_id[id] = annual_profile
	return annual_profile


static func to_string_volatile_inventory_class(value: int) -> String:
	match value:
		VolatileInventoryClass.TRACE:
			return "TRACE"
		VolatileInventoryClass.LIMITED:
			return "LIMITED"
		VolatileInventoryClass.RICH:
			return "RICH"
	return "UNKNOWN"


static func to_string_climate_buffer_class(value: int) -> String:
	match value:
		ClimateBufferClass.UNBUFFERED:
			return "UNBUFFERED"
		ClimateBufferClass.MODERATE:
			return "MODERATE"
		ClimateBufferClass.BUFFERED:
			return "BUFFERED"
	return "UNKNOWN"


static func to_string_thermal_extremity_class(value: int) -> String:
	match value:
		ThermalExtremityClass.FROZEN:
			return "FROZEN"
		ThermalExtremityClass.COLD:
			return "COLD"
		ThermalExtremityClass.TEMPERATE:
			return "TEMPERATE"
		ThermalExtremityClass.HOT:
			return "HOT"
		ThermalExtremityClass.EXTREME:
			return "EXTREME"
	return "UNKNOWN"


static func to_string_seasonality_class(value: int) -> String:
	match value:
		SeasonalityClass.LOW:
			return "LOW"
		SeasonalityClass.SEASONAL:
			return "SEASONAL"
		SeasonalityClass.VIOLENT:
			return "VIOLENT"
	return "UNKNOWN"


static func to_string_stability_class(value: int) -> String:
	match value:
		StabilityClass.FRAGILE:
			return "FRAGILE"
		StabilityClass.WINDOWED:
			return "WINDOWED"
		StabilityClass.STABLE:
			return "STABLE"
	return "UNKNOWN"


static func _volatile_inventory_class_of(volatile_inventory_ratio: float) -> int:
	if volatile_inventory_ratio < 0.20:
		return VolatileInventoryClass.TRACE
	if volatile_inventory_ratio < 0.55:
		return VolatileInventoryClass.LIMITED
	return VolatileInventoryClass.RICH


static func _climate_buffer_class_of(climate_buffer_factor: float) -> int:
	if climate_buffer_factor < 0.25:
		return ClimateBufferClass.UNBUFFERED
	if climate_buffer_factor < 0.65:
		return ClimateBufferClass.MODERATE
	return ClimateBufferClass.BUFFERED


static func _thermal_extremity_class_of(annual_global_mean_surface_temperature_k: float) -> int:
	if annual_global_mean_surface_temperature_k < 223.15:
		return ThermalExtremityClass.FROZEN
	if annual_global_mean_surface_temperature_k < 273.15:
		return ThermalExtremityClass.COLD
	if annual_global_mean_surface_temperature_k <= 323.15:
		return ThermalExtremityClass.TEMPERATE
	if annual_global_mean_surface_temperature_k <= 373.15:
		return ThermalExtremityClass.HOT
	return ThermalExtremityClass.EXTREME


static func _seasonality_class_of(annual_max_band_span_k: float) -> int:
	if annual_max_band_span_k < 35.0:
		return SeasonalityClass.LOW
	if annual_max_band_span_k < 90.0:
		return SeasonalityClass.SEASONAL
	return SeasonalityClass.VIOLENT


static func _stability_class_of(annual_moderate_sample_fraction: float, annual_max_band_span_k: float) -> int:
	if annual_moderate_sample_fraction >= 0.70 and annual_max_band_span_k < 60.0:
		return StabilityClass.STABLE
	if annual_moderate_sample_fraction >= 0.20 and annual_max_band_span_k < 160.0:
		return StabilityClass.WINDOWED
	return StabilityClass.FRAGILE


static func _default_description(id: StringName) -> Dictionary:
	return {
		KEY_BODY_ID: id,
		KEY_IS_SUPPORTED_BODY_KIND: false,
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
		KEY_VOLATILE_INVENTORY_CLASS: VolatileInventoryClass.TRACE,
		KEY_CLIMATE_BUFFER_CLASS: ClimateBufferClass.UNBUFFERED,
		KEY_THERMAL_EXTREMITY_CLASS: ThermalExtremityClass.FROZEN,
		KEY_SEASONALITY_CLASS: SeasonalityClass.LOW,
		KEY_STABILITY_CLASS: StabilityClass.FRAGILE,
	}
