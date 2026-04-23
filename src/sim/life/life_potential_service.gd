class_name LifePotentialService
extends Node


const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")

enum Track {
	WATER_CARBON,
	SULFUR_REACTIVE,
	CRYOGENIC_SOLVENT,
}

enum PotentialClass {
	NONE,
	LOW,
	MEDIUM,
	HIGH,
}

const KEY_BODY_ID: StringName = &"body_id"
const KEY_IS_SUPPORTED_BODY_KIND: StringName = &"is_supported_body_kind"
const KEY_HAS_LIFE_POTENTIAL_BASIS: StringName = &"has_life_potential_basis"
const KEY_TRACK_SCORES_BY_ID: StringName = &"track_scores_by_id"
const KEY_TRACK_POTENTIAL_CLASS_BY_ID: StringName = &"track_potential_class_by_id"
const KEY_DOMINANT_TRACK_ID: StringName = &"dominant_track_id"
const KEY_DOMINANT_TRACK_SCORE: StringName = &"dominant_track_score"
const KEY_DOMINANT_POTENTIAL_CLASS: StringName = &"dominant_potential_class"
const KEY_DOMINANT_TRACK_REASONS: StringName = &"dominant_track_reasons"
const KEY_AXIS_CONTRIBUTIONS_BY_TRACK: StringName = &"axis_contributions_by_track"

const TRACK_IDS: Array[int] = [
	Track.WATER_CARBON,
	Track.SULFUR_REACTIVE,
	Track.CRYOGENIC_SOLVENT,
]

const AXIS_THERMAL_EXTREMITY: StringName = &"thermal_extremity_class"
const AXIS_VOLATILE_INVENTORY: StringName = &"volatile_inventory_class"
const AXIS_CLIMATE_BUFFER: StringName = &"climate_buffer_class"
const AXIS_STABILITY: StringName = &"stability_class"
const AXIS_SEASONALITY: StringName = &"seasonality_class"

const AXIS_WEIGHTS := {
	AXIS_THERMAL_EXTREMITY: 0.30,
	AXIS_VOLATILE_INVENTORY: 0.20,
	AXIS_CLIMATE_BUFFER: 0.15,
	AXIS_STABILITY: 0.20,
	AXIS_SEASONALITY: 0.15,
}

const LOOKUP_PREFERRED: float = 1.0
const LOOKUP_TOLERATED: float = 0.6
const LOOKUP_WEAK: float = 0.3
const LOOKUP_INCOMPATIBLE: float = 0.0
const SCORE_EPSILON: float = 0.000001

var _registry: Node = null
var _planetary_state_service: Node = null
var _environment_service: Node = null


func configure(registry: Node, planetary_state_service: Node, environment_service: Node = null) -> void:
	assert(registry != null, "LifePotentialService.configure: registry is null")
	assert(planetary_state_service != null, "LifePotentialService.configure: planetary_state_service is null")
	assert(
		planetary_state_service.has_method("describe_body"),
		"LifePotentialService.configure: planetary_state_service must implement describe_body(id)"
	)
	_registry = registry
	_planetary_state_service = planetary_state_service
	_environment_service = environment_service


func describe_body(id: StringName) -> Dictionary:
	if _registry == null or _planetary_state_service == null:
		return _default_description(id)
	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return _default_description(id)
	if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
		return _default_description(id)

	var planetary_state_desc: Dictionary = _planetary_state_service.describe_body(id)
	return evaluate_from_planetary_desc(planetary_state_desc, id)

static func evaluate_from_planetary_desc(
		planetary_state_desc: Dictionary,
		body_id: StringName = StringName("")
	) -> Dictionary:
	var resolved_body_id: StringName = body_id
	if resolved_body_id == StringName(""):
		resolved_body_id = StringName(planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_BODY_ID,
			StringName("")
		))
	var description: Dictionary = _default_description(resolved_body_id)
	if not bool(planetary_state_desc.get(PlanetaryStateServiceScript.KEY_IS_SUPPORTED_BODY_KIND, false)):
		return description

	description[KEY_IS_SUPPORTED_BODY_KIND] = true
	if not bool(planetary_state_desc.get(PlanetaryStateServiceScript.KEY_HAS_SAMPLED_YEAR_BASIS, false)):
		return description

	description[KEY_HAS_LIFE_POTENTIAL_BASIS] = true
	var scores_by_track: Dictionary = {}
	var contributions_by_track: Dictionary = {}
	var classes_by_track: Dictionary = {}
	for track_id in TRACK_IDS:
		var contributions: Dictionary = _axis_contributions_for_track(track_id, planetary_state_desc)
		var score: float = _sum_axis_contributions(contributions)
		scores_by_track[track_id] = score
		contributions_by_track[track_id] = contributions
		classes_by_track[track_id] = _potential_class_of(score)

	var dominant_track_id: int = _dominant_track_id(scores_by_track, planetary_state_desc)
	var dominant_score: float = float(scores_by_track.get(dominant_track_id, 0.0))
	description[KEY_TRACK_SCORES_BY_ID] = scores_by_track
	description[KEY_TRACK_POTENTIAL_CLASS_BY_ID] = classes_by_track
	description[KEY_DOMINANT_TRACK_ID] = dominant_track_id
	description[KEY_DOMINANT_TRACK_SCORE] = dominant_score
	description[KEY_DOMINANT_POTENTIAL_CLASS] = _potential_class_of(dominant_score)
	description[KEY_AXIS_CONTRIBUTIONS_BY_TRACK] = contributions_by_track
	description[KEY_DOMINANT_TRACK_REASONS] = _dominant_track_reasons(
		dominant_track_id,
		planetary_state_desc,
		contributions_by_track
	)
	return description


static func to_string_track(value: int) -> String:
	match value:
		Track.WATER_CARBON:
			return "WATER_CARBON"
		Track.SULFUR_REACTIVE:
			return "SULFUR_REACTIVE"
		Track.CRYOGENIC_SOLVENT:
			return "CRYOGENIC_SOLVENT"
	return "UNKNOWN"


static func to_string_potential_class(value: int) -> String:
	match value:
		PotentialClass.NONE:
			return "NONE"
		PotentialClass.LOW:
			return "LOW"
		PotentialClass.MEDIUM:
			return "MEDIUM"
		PotentialClass.HIGH:
			return "HIGH"
	return "UNKNOWN"


static func _axis_contributions_for_track(track_id: int, planetary_state_desc: Dictionary) -> Dictionary:
	var thermal_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_THERMAL_EXTREMITY_CLASS,
		PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
	))
	var volatile_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_VOLATILE_INVENTORY_CLASS,
		PlanetaryStateServiceScript.VolatileInventoryClass.TRACE
	))
	var buffer_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_CLIMATE_BUFFER_CLASS,
		PlanetaryStateServiceScript.ClimateBufferClass.UNBUFFERED
	))
	var stability_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_STABILITY_CLASS,
		PlanetaryStateServiceScript.StabilityClass.FRAGILE
	))
	var seasonality_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_SEASONALITY_CLASS,
		PlanetaryStateServiceScript.SeasonalityClass.LOW
	))
	return {
		AXIS_THERMAL_EXTREMITY: AXIS_WEIGHTS[AXIS_THERMAL_EXTREMITY] * _lookup_value_for_axis(track_id, AXIS_THERMAL_EXTREMITY, thermal_class),
		AXIS_VOLATILE_INVENTORY: AXIS_WEIGHTS[AXIS_VOLATILE_INVENTORY] * _lookup_value_for_axis(track_id, AXIS_VOLATILE_INVENTORY, volatile_class),
		AXIS_CLIMATE_BUFFER: AXIS_WEIGHTS[AXIS_CLIMATE_BUFFER] * _lookup_value_for_axis(track_id, AXIS_CLIMATE_BUFFER, buffer_class),
		AXIS_STABILITY: AXIS_WEIGHTS[AXIS_STABILITY] * _lookup_value_for_axis(track_id, AXIS_STABILITY, stability_class),
		AXIS_SEASONALITY: AXIS_WEIGHTS[AXIS_SEASONALITY] * _lookup_value_for_axis(track_id, AXIS_SEASONALITY, seasonality_class),
	}


static func _sum_axis_contributions(contributions: Dictionary) -> float:
	var total: float = 0.0
	for axis_name in contributions.keys():
		total += float(contributions[axis_name])
	return total


static func _dominant_track_id(scores_by_track: Dictionary, planetary_state_desc: Dictionary) -> int:
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
		return tied_track_ids[0] if not tied_track_ids.is_empty() else Track.WATER_CARBON

	var thermal_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_THERMAL_EXTREMITY_CLASS,
		PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
	))
	var thermal_tie_break_track_id: int = _tie_break_track_id_from_thermal(thermal_class)
	if tied_track_ids.has(thermal_tie_break_track_id):
		return thermal_tie_break_track_id

	var volatile_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_VOLATILE_INVENTORY_CLASS,
		PlanetaryStateServiceScript.VolatileInventoryClass.TRACE
	))
	var volatile_tie_break_track_id: int = _tie_break_track_id_from_volatiles(volatile_class)
	if tied_track_ids.has(volatile_tie_break_track_id):
		return volatile_tie_break_track_id

	for fallback_track_id in TRACK_IDS:
		if tied_track_ids.has(fallback_track_id):
			return fallback_track_id
	return tied_track_ids[0]


static func _tie_break_track_id_from_thermal(thermal_class: int) -> int:
	match thermal_class:
		PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE:
			return Track.WATER_CARBON
		PlanetaryStateServiceScript.ThermalExtremityClass.HOT, PlanetaryStateServiceScript.ThermalExtremityClass.EXTREME:
			return Track.SULFUR_REACTIVE
		PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN, PlanetaryStateServiceScript.ThermalExtremityClass.COLD:
			return Track.CRYOGENIC_SOLVENT
	return Track.WATER_CARBON


static func _tie_break_track_id_from_volatiles(volatile_class: int) -> int:
	match volatile_class:
		PlanetaryStateServiceScript.VolatileInventoryClass.RICH:
			return Track.WATER_CARBON
		PlanetaryStateServiceScript.VolatileInventoryClass.LIMITED, PlanetaryStateServiceScript.VolatileInventoryClass.TRACE:
			return Track.SULFUR_REACTIVE
	return Track.WATER_CARBON


static func _dominant_track_reasons(track_id: int, planetary_state_desc: Dictionary, contributions_by_track: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	var contributions: Dictionary = contributions_by_track.get(track_id, {})
	var axes: Array = contributions.keys()
	axes.sort_custom(func(a, b): return float(contributions[a]) > float(contributions[b]))
	for axis_name_variant in axes:
		var axis_name: StringName = axis_name_variant
		var contribution: float = float(contributions.get(axis_name, 0.0))
		if contribution <= 0.0:
			continue
		reasons.append("%s %s (%s)" % [
			to_string_track(track_id),
			_axis_reason_label(axis_name, planetary_state_desc),
			_stripped_score(contribution),
		])
		if reasons.size() >= 3:
			break
	return reasons


static func _axis_reason_label(axis_name: StringName, planetary_state_desc: Dictionary) -> String:
	match axis_name:
		AXIS_THERMAL_EXTREMITY:
			return "thermal=" + PlanetaryStateServiceScript.to_string_thermal_extremity_class(int(
				planetary_state_desc.get(
					PlanetaryStateServiceScript.KEY_THERMAL_EXTREMITY_CLASS,
					PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
				)
			))
		AXIS_VOLATILE_INVENTORY:
			return "volatiles=" + PlanetaryStateServiceScript.to_string_volatile_inventory_class(int(
				planetary_state_desc.get(
					PlanetaryStateServiceScript.KEY_VOLATILE_INVENTORY_CLASS,
					PlanetaryStateServiceScript.VolatileInventoryClass.TRACE
				)
			))
		AXIS_CLIMATE_BUFFER:
			return "buffer=" + PlanetaryStateServiceScript.to_string_climate_buffer_class(int(
				planetary_state_desc.get(
					PlanetaryStateServiceScript.KEY_CLIMATE_BUFFER_CLASS,
					PlanetaryStateServiceScript.ClimateBufferClass.UNBUFFERED
				)
			))
		AXIS_STABILITY:
			return "stability=" + PlanetaryStateServiceScript.to_string_stability_class(int(
				planetary_state_desc.get(
					PlanetaryStateServiceScript.KEY_STABILITY_CLASS,
					PlanetaryStateServiceScript.StabilityClass.FRAGILE
				)
			))
		AXIS_SEASONALITY:
			return "seasonality=" + PlanetaryStateServiceScript.to_string_seasonality_class(int(
				planetary_state_desc.get(
					PlanetaryStateServiceScript.KEY_SEASONALITY_CLASS,
					PlanetaryStateServiceScript.SeasonalityClass.LOW
				)
			))
	return String(axis_name)


static func _stripped_score(value: float) -> String:
	return "%.2f" % value


static func _potential_class_of(score: float) -> int:
	if score < 0.20:
		return PotentialClass.NONE
	if score < 0.50:
		return PotentialClass.LOW
	if score < 0.75:
		return PotentialClass.MEDIUM
	return PotentialClass.HIGH


static func _lookup_value_for_axis(track_id: int, axis_name: StringName, axis_class: int) -> float:
	if _is_preferred(track_id, axis_name, axis_class):
		return LOOKUP_PREFERRED
	if _is_tolerated(track_id, axis_name, axis_class):
		return LOOKUP_TOLERATED
	if _is_weak(track_id, axis_name, axis_class):
		return LOOKUP_WEAK
	return LOOKUP_INCOMPATIBLE


static func _is_preferred(track_id: int, axis_name: StringName, axis_class: int) -> bool:
	match track_id:
		Track.WATER_CARBON:
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
		Track.SULFUR_REACTIVE:
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
		Track.CRYOGENIC_SOLVENT:
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
		Track.WATER_CARBON:
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
		Track.SULFUR_REACTIVE:
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
		Track.CRYOGENIC_SOLVENT:
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
		Track.WATER_CARBON:
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
		Track.SULFUR_REACTIVE:
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
		Track.CRYOGENIC_SOLVENT:
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


static func _default_description(id: StringName) -> Dictionary:
	var track_scores: Dictionary = {}
	var track_classes: Dictionary = {}
	var contributions: Dictionary = {}
	for track_id in TRACK_IDS:
		track_scores[track_id] = 0.0
		track_classes[track_id] = PotentialClass.NONE
		contributions[track_id] = {
			AXIS_THERMAL_EXTREMITY: 0.0,
			AXIS_VOLATILE_INVENTORY: 0.0,
			AXIS_CLIMATE_BUFFER: 0.0,
			AXIS_STABILITY: 0.0,
			AXIS_SEASONALITY: 0.0,
		}
	return {
		KEY_BODY_ID: id,
		KEY_IS_SUPPORTED_BODY_KIND: false,
		KEY_HAS_LIFE_POTENTIAL_BASIS: false,
		KEY_TRACK_SCORES_BY_ID: track_scores,
		KEY_TRACK_POTENTIAL_CLASS_BY_ID: track_classes,
		KEY_DOMINANT_TRACK_ID: Track.WATER_CARBON,
		KEY_DOMINANT_TRACK_SCORE: 0.0,
		KEY_DOMINANT_POTENTIAL_CLASS: PotentialClass.NONE,
		KEY_DOMINANT_TRACK_REASONS: [],
		KEY_AXIS_CONTRIBUTIONS_BY_TRACK: contributions,
	}
