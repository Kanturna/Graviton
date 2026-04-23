class_name LifeTrackLookup
extends RefCounted


const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")

const TRACK_WATER_CARBON: int = 0
const TRACK_SULFUR_REACTIVE: int = 1
const TRACK_CRYOGENIC_SOLVENT: int = 2

const TRACK_IDS: Array[int] = [
	TRACK_WATER_CARBON,
	TRACK_SULFUR_REACTIVE,
	TRACK_CRYOGENIC_SOLVENT,
]

const AXIS_THERMAL_EXTREMITY: StringName = &"thermal_extremity_class"
const AXIS_VOLATILE_INVENTORY: StringName = &"volatile_inventory_class"
const AXIS_CLIMATE_BUFFER: StringName = &"climate_buffer_class"
const AXIS_STABILITY: StringName = &"stability_class"
const AXIS_SEASONALITY: StringName = &"seasonality_class"

const LOOKUP_PREFERRED: float = 1.0
const LOOKUP_TOLERATED: float = 0.6
const LOOKUP_WEAK: float = 0.3
const LOOKUP_INCOMPATIBLE: float = 0.0
const SCORE_EPSILON: float = 0.000001


static func to_string_track(value: int) -> String:
	match value:
		TRACK_WATER_CARBON:
			return "WATER_CARBON"
		TRACK_SULFUR_REACTIVE:
			return "SULFUR_REACTIVE"
		TRACK_CRYOGENIC_SOLVENT:
			return "CRYOGENIC_SOLVENT"
	return "UNKNOWN"


static func lookup_value_for_axis(track_id: int, axis_name: StringName, axis_class: int) -> float:
	if _is_preferred(track_id, axis_name, axis_class):
		return LOOKUP_PREFERRED
	if _is_tolerated(track_id, axis_name, axis_class):
		return LOOKUP_TOLERATED
	if _is_weak(track_id, axis_name, axis_class):
		return LOOKUP_WEAK
	return LOOKUP_INCOMPATIBLE


static func dominant_track_id_from_scores(scores_by_track: Dictionary, planetary_state_desc: Dictionary) -> int:
	var best_score: float = -1.0
	var tied_track_ids: Array[int] = []
	for track_id in TRACK_IDS:
		var score: float = float(scores_by_track.get(track_id, 0.0))
		if score > best_score + SCORE_EPSILON:
			best_score = score
			tied_track_ids = [track_id]
		elif is_equal_approx(score, best_score):
			tied_track_ids.append(track_id)
	if tied_track_ids.size() <= 1:
		return tied_track_ids[0] if not tied_track_ids.is_empty() else TRACK_WATER_CARBON

	var thermal_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_THERMAL_EXTREMITY_CLASS,
		PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
	))
	var thermal_tie_break_track_id: int = tie_break_track_id_from_thermal(thermal_class)
	if tied_track_ids.has(thermal_tie_break_track_id):
		return thermal_tie_break_track_id

	var volatile_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_VOLATILE_INVENTORY_CLASS,
		PlanetaryStateServiceScript.VolatileInventoryClass.TRACE
	))
	var volatile_tie_break_track_id: int = tie_break_track_id_from_volatiles(volatile_class)
	if tied_track_ids.has(volatile_tie_break_track_id):
		return volatile_tie_break_track_id

	for fallback_track_id in TRACK_IDS:
		if tied_track_ids.has(fallback_track_id):
			return fallback_track_id
	return tied_track_ids[0]


static func tie_break_track_id_from_thermal(thermal_class: int) -> int:
	match thermal_class:
		PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE:
			return TRACK_WATER_CARBON
		PlanetaryStateServiceScript.ThermalExtremityClass.HOT, PlanetaryStateServiceScript.ThermalExtremityClass.EXTREME:
			return TRACK_SULFUR_REACTIVE
		PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN, PlanetaryStateServiceScript.ThermalExtremityClass.COLD:
			return TRACK_CRYOGENIC_SOLVENT
	return TRACK_WATER_CARBON


static func tie_break_track_id_from_volatiles(volatile_class: int) -> int:
	match volatile_class:
		PlanetaryStateServiceScript.VolatileInventoryClass.RICH:
			return TRACK_WATER_CARBON
		PlanetaryStateServiceScript.VolatileInventoryClass.LIMITED, PlanetaryStateServiceScript.VolatileInventoryClass.TRACE:
			return TRACK_SULFUR_REACTIVE
	return TRACK_WATER_CARBON


static func zero_axis_contributions(axis_names: Array[StringName]) -> Dictionary:
	var out: Dictionary = {}
	for axis_name in axis_names:
		out[axis_name] = 0.0
	return out


static func _is_preferred(track_id: int, axis_name: StringName, axis_class: int) -> bool:
	match track_id:
		TRACK_WATER_CARBON:
			match axis_name:
				AXIS_THERMAL_EXTREMITY:
					return axis_class == PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
				AXIS_VOLATILE_INVENTORY:
					return axis_class == PlanetaryStateServiceScript.VolatileInventoryClass.RICH
				AXIS_CLIMATE_BUFFER:
					return axis_class == PlanetaryStateServiceScript.ClimateBufferClass.BUFFERED
				AXIS_STABILITY:
					return axis_class == PlanetaryStateServiceScript.StabilityClass.STABLE
				AXIS_SEASONALITY:
					return axis_class == PlanetaryStateServiceScript.SeasonalityClass.LOW
		TRACK_SULFUR_REACTIVE:
			match axis_name:
				AXIS_THERMAL_EXTREMITY:
					return axis_class == PlanetaryStateServiceScript.ThermalExtremityClass.HOT
				AXIS_VOLATILE_INVENTORY:
					return axis_class == PlanetaryStateServiceScript.VolatileInventoryClass.LIMITED
				AXIS_CLIMATE_BUFFER:
					return axis_class == PlanetaryStateServiceScript.ClimateBufferClass.MODERATE
				AXIS_STABILITY:
					return axis_class == PlanetaryStateServiceScript.StabilityClass.WINDOWED
				AXIS_SEASONALITY:
					return axis_class == PlanetaryStateServiceScript.SeasonalityClass.SEASONAL
		TRACK_CRYOGENIC_SOLVENT:
			match axis_name:
				AXIS_THERMAL_EXTREMITY:
					return axis_class == PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN \
						or axis_class == PlanetaryStateServiceScript.ThermalExtremityClass.COLD
				AXIS_VOLATILE_INVENTORY:
					return false
				AXIS_CLIMATE_BUFFER:
					return axis_class == PlanetaryStateServiceScript.ClimateBufferClass.MODERATE
				AXIS_STABILITY:
					return false
				AXIS_SEASONALITY:
					return axis_class == PlanetaryStateServiceScript.SeasonalityClass.LOW
	return false


static func _is_tolerated(track_id: int, axis_name: StringName, axis_class: int) -> bool:
	match track_id:
		TRACK_WATER_CARBON:
			match axis_name:
				AXIS_THERMAL_EXTREMITY:
					return false
				AXIS_VOLATILE_INVENTORY:
					return axis_class == PlanetaryStateServiceScript.VolatileInventoryClass.LIMITED
				AXIS_CLIMATE_BUFFER:
					return axis_class == PlanetaryStateServiceScript.ClimateBufferClass.MODERATE
				AXIS_STABILITY:
					return axis_class == PlanetaryStateServiceScript.StabilityClass.WINDOWED
				AXIS_SEASONALITY:
					return axis_class == PlanetaryStateServiceScript.SeasonalityClass.SEASONAL
		TRACK_SULFUR_REACTIVE:
			match axis_name:
				AXIS_THERMAL_EXTREMITY:
					return axis_class == PlanetaryStateServiceScript.ThermalExtremityClass.EXTREME
				AXIS_VOLATILE_INVENTORY:
					return axis_class == PlanetaryStateServiceScript.VolatileInventoryClass.TRACE
				AXIS_CLIMATE_BUFFER:
					return axis_class == PlanetaryStateServiceScript.ClimateBufferClass.UNBUFFERED
				AXIS_STABILITY:
					return axis_class == PlanetaryStateServiceScript.StabilityClass.FRAGILE
				AXIS_SEASONALITY:
					return axis_class == PlanetaryStateServiceScript.SeasonalityClass.VIOLENT
		TRACK_CRYOGENIC_SOLVENT:
			match axis_name:
				AXIS_THERMAL_EXTREMITY:
					return false
				AXIS_VOLATILE_INVENTORY:
					return axis_class == PlanetaryStateServiceScript.VolatileInventoryClass.RICH
				AXIS_CLIMATE_BUFFER:
					return axis_class == PlanetaryStateServiceScript.ClimateBufferClass.BUFFERED
				AXIS_STABILITY:
					return axis_class == PlanetaryStateServiceScript.StabilityClass.STABLE \
						or axis_class == PlanetaryStateServiceScript.StabilityClass.WINDOWED
				AXIS_SEASONALITY:
					return axis_class == PlanetaryStateServiceScript.SeasonalityClass.SEASONAL
	return false


static func _is_weak(track_id: int, axis_name: StringName, axis_class: int) -> bool:
	match track_id:
		TRACK_WATER_CARBON:
			match axis_name:
				AXIS_THERMAL_EXTREMITY:
					return axis_class == PlanetaryStateServiceScript.ThermalExtremityClass.HOT
				AXIS_VOLATILE_INVENTORY:
					return false
				AXIS_CLIMATE_BUFFER:
					return axis_class == PlanetaryStateServiceScript.ClimateBufferClass.UNBUFFERED
				AXIS_STABILITY:
					return axis_class == PlanetaryStateServiceScript.StabilityClass.FRAGILE
				AXIS_SEASONALITY:
					return false
		TRACK_SULFUR_REACTIVE:
			match axis_name:
				AXIS_THERMAL_EXTREMITY:
					return false
				AXIS_VOLATILE_INVENTORY:
					return axis_class == PlanetaryStateServiceScript.VolatileInventoryClass.RICH
				AXIS_CLIMATE_BUFFER:
					return axis_class == PlanetaryStateServiceScript.ClimateBufferClass.BUFFERED
				AXIS_STABILITY:
					return axis_class == PlanetaryStateServiceScript.StabilityClass.STABLE
				AXIS_SEASONALITY:
					return axis_class == PlanetaryStateServiceScript.SeasonalityClass.LOW
		TRACK_CRYOGENIC_SOLVENT:
			match axis_name:
				AXIS_THERMAL_EXTREMITY:
					return false
				AXIS_VOLATILE_INVENTORY:
					return axis_class == PlanetaryStateServiceScript.VolatileInventoryClass.LIMITED
				AXIS_CLIMATE_BUFFER:
					return false
				AXIS_STABILITY:
					return axis_class == PlanetaryStateServiceScript.StabilityClass.FRAGILE
				AXIS_SEASONALITY:
					return false
	return false
