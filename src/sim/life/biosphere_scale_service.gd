class_name BiosphereScaleService
extends Node


const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const ProtoBiosphereSimulationServiceScript = preload("res://src/sim/life/proto_biosphere_simulation_service.gd")
const LifeTrackLookupScript = preload("res://src/sim/life/life_track_lookup.gd")

enum Stage {
	STERILE,
	PREBIOTIC,
	MICROBIAL,
	COMPLEX_MULTICELLULAR,
	COMPLEX_ECOSYSTEM,
}

const KEY_BODY_ID: StringName = &"body_id"
const KEY_IS_SUPPORTED_BODY_KIND: StringName = &"is_supported_body_kind"
const KEY_HAS_BIOSPHERE_SCALE_BASIS: StringName = &"has_biosphere_scale_basis"
const KEY_CARRYING_CAPACITY_BY_TRACK_BY_BAND: StringName = &"carrying_capacity_by_track_by_band"
const KEY_BIOMASS_BY_TRACK_BY_BAND: StringName = &"biomass_by_track_by_band"
const KEY_CARRYING_CAPACITY_INDEX_BY_TRACK: StringName = &"carrying_capacity_index_by_track"
const KEY_BIOMASS_INDEX_BY_TRACK: StringName = &"biomass_index_by_track"
const KEY_DOMINANT_TRACK_ID: StringName = &"dominant_track_id"
const KEY_BIOSPHERE_STAGE: StringName = &"biosphere_stage"
const KEY_DOMINANT_POTENTIAL_CLASS: StringName = &"dominant_potential_class"
const KEY_DOMINANT_BIOMASS_INDEX: StringName = &"dominant_biomass_index"
const KEY_DOMINANT_BAND_ID: StringName = &"dominant_band_id"
const KEY_DOMINANT_BAND_THERMAL_CLASS: StringName = &"dominant_band_thermal_class"

const BAND_SOUTH: StringName = &"south_band"
const BAND_EQUATOR: StringName = &"equator_band"
const BAND_NORTH: StringName = &"north_band"

const BAND_IDS: Array[StringName] = [
	BAND_SOUTH,
	BAND_EQUATOR,
	BAND_NORTH,
]

const BAND_WEIGHTS := {
	BAND_SOUTH: 0.25,
	BAND_EQUATOR: 0.50,
	BAND_NORTH: 0.25,
}

const TRACK_IDS: Array[int] = LifeTrackLookupScript.TRACK_IDS

const CARRYING_CAPACITY_AXIS_WEIGHTS := {
	LifeTrackLookupScript.AXIS_THERMAL_EXTREMITY: 0.45,
	LifeTrackLookupScript.AXIS_VOLATILE_INVENTORY: 0.20,
	LifeTrackLookupScript.AXIS_CLIMATE_BUFFER: 0.10,
	LifeTrackLookupScript.AXIS_STABILITY: 0.15,
	LifeTrackLookupScript.AXIS_SEASONALITY: 0.10,
}

var _registry: Node = null
var _planetary_state_service: Node = null
var _life_potential_service: Node = null
var _proto_biosphere_service: Node = null


func configure(
		registry: Node,
		planetary_state_service: Node,
		life_potential_service: Node,
		proto_biosphere_service: Node
	) -> void:
	assert(registry != null, "BiosphereScaleService.configure: registry is null")
	assert(planetary_state_service != null, "BiosphereScaleService.configure: planetary_state_service is null")
	assert(life_potential_service != null, "BiosphereScaleService.configure: life_potential_service is null")
	assert(proto_biosphere_service != null, "BiosphereScaleService.configure: proto_biosphere_service is null")
	assert(
		planetary_state_service.has_method("describe_body"),
		"BiosphereScaleService.configure: planetary_state_service must implement describe_body(id)"
	)
	assert(
		life_potential_service.has_method("describe_body"),
		"BiosphereScaleService.configure: life_potential_service must implement describe_body(id)"
	)
	assert(
		proto_biosphere_service.has_method("describe_body"),
		"BiosphereScaleService.configure: proto_biosphere_service must implement describe_body(id)"
	)
	_registry = registry
	_planetary_state_service = planetary_state_service
	_life_potential_service = life_potential_service
	_proto_biosphere_service = proto_biosphere_service


func describe_body(id: StringName) -> Dictionary:
	if _registry == null or _planetary_state_service == null or _life_potential_service == null or _proto_biosphere_service == null:
		return _default_description(id)
	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return _default_description(id)
	if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
		return _default_description(id)
	return evaluate_from_descriptions(
		_planetary_state_service.describe_body(id),
		_life_potential_service.describe_body(id),
		_proto_biosphere_service.describe_body(id),
		id
	)


static func evaluate_from_descriptions(
		planetary_state_desc: Dictionary,
		life_potential_desc: Dictionary,
		proto_biosphere_desc: Dictionary,
		body_id: StringName = StringName("")
	) -> Dictionary:
	var resolved_body_id: StringName = body_id
	if resolved_body_id == StringName(""):
		resolved_body_id = StringName(planetary_state_desc.get(PlanetaryStateServiceScript.KEY_BODY_ID, StringName("")))
	if resolved_body_id == StringName(""):
		resolved_body_id = StringName(life_potential_desc.get(LifePotentialServiceScript.KEY_BODY_ID, StringName("")))
	if resolved_body_id == StringName(""):
		resolved_body_id = StringName(proto_biosphere_desc.get(ProtoBiosphereSimulationServiceScript.KEY_BODY_ID, StringName("")))
	var description: Dictionary = _default_description(resolved_body_id)
	var is_supported_body_kind: bool = bool(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_IS_SUPPORTED_BODY_KIND,
		false
	)) or bool(life_potential_desc.get(
		LifePotentialServiceScript.KEY_IS_SUPPORTED_BODY_KIND,
		false
	)) or bool(proto_biosphere_desc.get(
		ProtoBiosphereSimulationServiceScript.KEY_IS_SUPPORTED_BODY_KIND,
		false
	))
	if not is_supported_body_kind:
		return description

	description[KEY_IS_SUPPORTED_BODY_KIND] = true
	if not bool(planetary_state_desc.get(PlanetaryStateServiceScript.KEY_HAS_SAMPLED_YEAR_BASIS, false)):
		return description
	if not bool(life_potential_desc.get(LifePotentialServiceScript.KEY_HAS_LIFE_POTENTIAL_BASIS, false)):
		return description
	if not bool(proto_biosphere_desc.get(ProtoBiosphereSimulationServiceScript.KEY_HAS_BIOSPHERE_BASIS, false)):
		return description

	description[KEY_HAS_BIOSPHERE_SCALE_BASIS] = true
	var carrying_capacity_by_track_by_band: Dictionary = {}
	var biomass_by_track_by_band: Dictionary = {}
	var carrying_capacity_index_by_track: Dictionary = {}
	var biomass_index_by_track: Dictionary = {}
	var progress_by_track: Dictionary = proto_biosphere_desc.get(
		ProtoBiosphereSimulationServiceScript.KEY_TRACK_PROGRESS_BY_ID,
		{}
	)
	var band_thermal_class_by_band: Dictionary = _band_thermal_class_by_band(planetary_state_desc)
	for track_id in TRACK_IDS:
		var progress: float = clampf(float(progress_by_track.get(track_id, 0.0)), 0.0, 1.0)
		var biomass_fraction: float = progress * progress
		var carrying_capacity_by_band: Dictionary = {}
		var biomass_by_band: Dictionary = {}
		var carrying_capacity_index: float = 0.0
		var biomass_index: float = 0.0
		for band_id in BAND_IDS:
			var carrying_capacity: float = _carrying_capacity_for_track_and_band(
				track_id,
				int(band_thermal_class_by_band.get(
					band_id,
					PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
				)),
				planetary_state_desc
			)
			var biomass: float = carrying_capacity * biomass_fraction
			carrying_capacity_by_band[band_id] = carrying_capacity
			biomass_by_band[band_id] = biomass
			var band_weight: float = float(BAND_WEIGHTS.get(band_id, 0.0))
			carrying_capacity_index += band_weight * carrying_capacity
			biomass_index += band_weight * biomass
		carrying_capacity_by_track_by_band[track_id] = carrying_capacity_by_band
		biomass_by_track_by_band[track_id] = biomass_by_band
		carrying_capacity_index_by_track[track_id] = clampf(carrying_capacity_index, 0.0, 1.0)
		biomass_index_by_track[track_id] = clampf(biomass_index, 0.0, 1.0)

	var dominant_track_id: int = int(life_potential_desc.get(
		LifePotentialServiceScript.KEY_DOMINANT_TRACK_ID,
		LifePotentialServiceScript.Track.WATER_CARBON
	))
	var dominant_track_carrying_capacity: float = float(carrying_capacity_index_by_track.get(dominant_track_id, 0.0))
	if is_zero_approx(dominant_track_carrying_capacity):
		var fallback_track_id: int = _dominant_positive_biomass_track_id(biomass_index_by_track)
		if fallback_track_id != -1:
			dominant_track_id = fallback_track_id

	var classes_by_track: Dictionary = life_potential_desc.get(
		LifePotentialServiceScript.KEY_TRACK_POTENTIAL_CLASS_BY_ID,
		{}
	)
	var dominant_potential_class: int = int(classes_by_track.get(
		dominant_track_id,
		life_potential_desc.get(
			LifePotentialServiceScript.KEY_DOMINANT_POTENTIAL_CLASS,
			LifePotentialServiceScript.PotentialClass.NONE
		)
	))
	var dominant_biomass_index: float = float(biomass_index_by_track.get(dominant_track_id, 0.0))
	var dominant_band_id: StringName = _dominant_band_id_for_track(
		dominant_track_id,
		biomass_by_track_by_band
	)
	description[KEY_CARRYING_CAPACITY_BY_TRACK_BY_BAND] = carrying_capacity_by_track_by_band
	description[KEY_BIOMASS_BY_TRACK_BY_BAND] = biomass_by_track_by_band
	description[KEY_CARRYING_CAPACITY_INDEX_BY_TRACK] = carrying_capacity_index_by_track
	description[KEY_BIOMASS_INDEX_BY_TRACK] = biomass_index_by_track
	description[KEY_DOMINANT_TRACK_ID] = dominant_track_id
	description[KEY_BIOSPHERE_STAGE] = _stage_for_biomass_index(dominant_biomass_index)
	description[KEY_DOMINANT_POTENTIAL_CLASS] = dominant_potential_class
	description[KEY_DOMINANT_BIOMASS_INDEX] = dominant_biomass_index
	description[KEY_DOMINANT_BAND_ID] = dominant_band_id
	description[KEY_DOMINANT_BAND_THERMAL_CLASS] = int(band_thermal_class_by_band.get(
		dominant_band_id,
		PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
	))
	return description


static func to_string_stage(value: int) -> String:
	match value:
		Stage.STERILE:
			return "STERILE"
		Stage.PREBIOTIC:
			return "PREBIOTIC"
		Stage.MICROBIAL:
			return "MICROBIAL"
		Stage.COMPLEX_MULTICELLULAR:
			return "COMPLEX_MULTICELLULAR"
		Stage.COMPLEX_ECOSYSTEM:
			return "COMPLEX_ECOSYSTEM"
	return "UNKNOWN"


static func _band_thermal_class_by_band(planetary_state_desc: Dictionary) -> Dictionary:
	return {
		BAND_SOUTH: PlanetaryStateServiceScript.thermal_extremity_class_from_temperature_k(
			float(planetary_state_desc.get(PlanetaryStateServiceScript.KEY_SOUTH_BAND_MEAN_SURFACE_TEMPERATURE_K, 0.0))
		),
		BAND_EQUATOR: PlanetaryStateServiceScript.thermal_extremity_class_from_temperature_k(
			float(planetary_state_desc.get(PlanetaryStateServiceScript.KEY_EQUATOR_BAND_MEAN_SURFACE_TEMPERATURE_K, 0.0))
		),
		BAND_NORTH: PlanetaryStateServiceScript.thermal_extremity_class_from_temperature_k(
			float(planetary_state_desc.get(PlanetaryStateServiceScript.KEY_NORTH_BAND_MEAN_SURFACE_TEMPERATURE_K, 0.0))
		),
	}


static func _carrying_capacity_for_track_and_band(track_id: int, thermal_class: int, planetary_state_desc: Dictionary) -> float:
	var thermal_fit: float = LifeTrackLookupScript.lookup_value_for_axis(
		track_id,
		LifeTrackLookupScript.AXIS_THERMAL_EXTREMITY,
		thermal_class
	)
	if is_zero_approx(thermal_fit):
		return 0.0
	var volatile_fit: float = LifeTrackLookupScript.lookup_value_for_axis(
		track_id,
		LifeTrackLookupScript.AXIS_VOLATILE_INVENTORY,
		int(planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_VOLATILE_INVENTORY_CLASS,
			PlanetaryStateServiceScript.VolatileInventoryClass.TRACE
		))
	)
	var buffer_fit: float = LifeTrackLookupScript.lookup_value_for_axis(
		track_id,
		LifeTrackLookupScript.AXIS_CLIMATE_BUFFER,
		int(planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_CLIMATE_BUFFER_CLASS,
			PlanetaryStateServiceScript.ClimateBufferClass.UNBUFFERED
		))
	)
	var stability_fit: float = LifeTrackLookupScript.lookup_value_for_axis(
		track_id,
		LifeTrackLookupScript.AXIS_STABILITY,
		int(planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_STABILITY_CLASS,
			PlanetaryStateServiceScript.StabilityClass.FRAGILE
		))
	)
	var seasonality_fit: float = LifeTrackLookupScript.lookup_value_for_axis(
		track_id,
		LifeTrackLookupScript.AXIS_SEASONALITY,
		int(planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_SEASONALITY_CLASS,
			PlanetaryStateServiceScript.SeasonalityClass.LOW
		))
	)
	return clampf(
		float(CARRYING_CAPACITY_AXIS_WEIGHTS[LifeTrackLookupScript.AXIS_THERMAL_EXTREMITY]) * thermal_fit
			+ float(CARRYING_CAPACITY_AXIS_WEIGHTS[LifeTrackLookupScript.AXIS_VOLATILE_INVENTORY]) * volatile_fit
			+ float(CARRYING_CAPACITY_AXIS_WEIGHTS[LifeTrackLookupScript.AXIS_CLIMATE_BUFFER]) * buffer_fit
			+ float(CARRYING_CAPACITY_AXIS_WEIGHTS[LifeTrackLookupScript.AXIS_STABILITY]) * stability_fit
			+ float(CARRYING_CAPACITY_AXIS_WEIGHTS[LifeTrackLookupScript.AXIS_SEASONALITY]) * seasonality_fit,
		0.0,
		1.0
	)


static func _dominant_positive_biomass_track_id(biomass_index_by_track: Dictionary) -> int:
	var best_track_id: int = -1
	var best_biomass_index: float = 0.0
	for track_id in TRACK_IDS:
		var biomass_index: float = float(biomass_index_by_track.get(track_id, 0.0))
		if biomass_index > best_biomass_index:
			best_biomass_index = biomass_index
			best_track_id = track_id
	return best_track_id


static func _dominant_band_id_for_track(track_id: int, biomass_by_track_by_band: Dictionary) -> StringName:
	var biomass_by_band: Dictionary = biomass_by_track_by_band.get(track_id, {})
	var best_band_id: StringName = BAND_EQUATOR
	var best_biomass: float = -1.0
	for band_id in [BAND_EQUATOR, BAND_SOUTH, BAND_NORTH]:
		var biomass: float = float(biomass_by_band.get(band_id, 0.0))
		if biomass > best_biomass:
			best_biomass = biomass
			best_band_id = band_id
	return best_band_id


static func _stage_for_biomass_index(biomass_index: float) -> int:
	if biomass_index < 0.02:
		return Stage.STERILE
	if biomass_index < 0.10:
		return Stage.PREBIOTIC
	if biomass_index < 0.35:
		return Stage.MICROBIAL
	if biomass_index < 0.80:
		return Stage.COMPLEX_MULTICELLULAR
	return Stage.COMPLEX_ECOSYSTEM


static func _default_description(id: StringName) -> Dictionary:
	var carrying_capacity_by_track_by_band: Dictionary = {}
	var biomass_by_track_by_band: Dictionary = {}
	var carrying_capacity_index_by_track: Dictionary = {}
	var biomass_index_by_track: Dictionary = {}
	for track_id in TRACK_IDS:
		carrying_capacity_by_track_by_band[track_id] = _zero_band_values()
		biomass_by_track_by_band[track_id] = _zero_band_values()
		carrying_capacity_index_by_track[track_id] = 0.0
		biomass_index_by_track[track_id] = 0.0
	return {
		KEY_BODY_ID: id,
		KEY_IS_SUPPORTED_BODY_KIND: false,
		KEY_HAS_BIOSPHERE_SCALE_BASIS: false,
		KEY_CARRYING_CAPACITY_BY_TRACK_BY_BAND: carrying_capacity_by_track_by_band,
		KEY_BIOMASS_BY_TRACK_BY_BAND: biomass_by_track_by_band,
		KEY_CARRYING_CAPACITY_INDEX_BY_TRACK: carrying_capacity_index_by_track,
		KEY_BIOMASS_INDEX_BY_TRACK: biomass_index_by_track,
		KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.WATER_CARBON,
		KEY_BIOSPHERE_STAGE: Stage.STERILE,
		KEY_DOMINANT_POTENTIAL_CLASS: LifePotentialServiceScript.PotentialClass.NONE,
		KEY_DOMINANT_BIOMASS_INDEX: 0.0,
		KEY_DOMINANT_BAND_ID: BAND_EQUATOR,
		KEY_DOMINANT_BAND_THERMAL_CLASS: PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN,
	}


static func _zero_band_values() -> Dictionary:
	return {
		BAND_SOUTH: 0.0,
		BAND_EQUATOR: 0.0,
		BAND_NORTH: 0.0,
	}
