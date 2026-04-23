class_name LifePotentialService
extends Node


const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const LifeTrackLookupScript = preload("res://src/sim/life/life_track_lookup.gd")

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

const AXIS_THERMAL_EXTREMITY: StringName = LifeTrackLookupScript.AXIS_THERMAL_EXTREMITY
const AXIS_VOLATILE_INVENTORY: StringName = LifeTrackLookupScript.AXIS_VOLATILE_INVENTORY
const AXIS_CLIMATE_BUFFER: StringName = LifeTrackLookupScript.AXIS_CLIMATE_BUFFER
const AXIS_STABILITY: StringName = LifeTrackLookupScript.AXIS_STABILITY
const AXIS_SEASONALITY: StringName = LifeTrackLookupScript.AXIS_SEASONALITY

const AXIS_WEIGHTS := {
	AXIS_THERMAL_EXTREMITY: 0.30,
	AXIS_VOLATILE_INVENTORY: 0.20,
	AXIS_CLIMATE_BUFFER: 0.15,
	AXIS_STABILITY: 0.20,
	AXIS_SEASONALITY: 0.15,
}

const LOOKUP_PREFERRED: float = LifeTrackLookupScript.LOOKUP_PREFERRED
const LOOKUP_TOLERATED: float = LifeTrackLookupScript.LOOKUP_TOLERATED
const LOOKUP_WEAK: float = LifeTrackLookupScript.LOOKUP_WEAK
const LOOKUP_INCOMPATIBLE: float = LifeTrackLookupScript.LOOKUP_INCOMPATIBLE
const SCORE_EPSILON: float = LifeTrackLookupScript.SCORE_EPSILON

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
	return LifeTrackLookupScript.to_string_track(value)


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
	return LifeTrackLookupScript.dominant_track_id_from_scores(scores_by_track, planetary_state_desc)


static func _tie_break_track_id_from_thermal(thermal_class: int) -> int:
	return LifeTrackLookupScript.tie_break_track_id_from_thermal(thermal_class)


static func _tie_break_track_id_from_volatiles(volatile_class: int) -> int:
	return LifeTrackLookupScript.tie_break_track_id_from_volatiles(volatile_class)


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
	return LifeTrackLookupScript.lookup_value_for_axis(track_id, axis_name, axis_class)


static func _is_preferred(track_id: int, axis_name: StringName, axis_class: int) -> bool:
	return LifeTrackLookupScript.lookup_value_for_axis(track_id, axis_name, axis_class) == LOOKUP_PREFERRED


static func _is_tolerated(track_id: int, axis_name: StringName, axis_class: int) -> bool:
	return LifeTrackLookupScript.lookup_value_for_axis(track_id, axis_name, axis_class) == LOOKUP_TOLERATED


static func _is_weak(track_id: int, axis_name: StringName, axis_class: int) -> bool:
	return LifeTrackLookupScript.lookup_value_for_axis(track_id, axis_name, axis_class) == LOOKUP_WEAK


static func _default_description(id: StringName) -> Dictionary:
	var track_scores: Dictionary = {}
	var track_classes: Dictionary = {}
	var contributions: Dictionary = {}
	for track_id in TRACK_IDS:
		track_scores[track_id] = 0.0
		track_classes[track_id] = PotentialClass.NONE
		contributions[track_id] = LifeTrackLookupScript.zero_axis_contributions([
			AXIS_THERMAL_EXTREMITY,
			AXIS_VOLATILE_INVENTORY,
			AXIS_CLIMATE_BUFFER,
			AXIS_STABILITY,
			AXIS_SEASONALITY,
		])
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
