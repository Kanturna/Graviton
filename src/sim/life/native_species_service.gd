class_name NativeSpeciesService
extends Node


const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")

enum ComplexityClass {
	EARLY_MACRO,
	DIVERSE_MACRO,
}

enum RichnessClass {
	SPARSE,
	PATCHY,
	DIVERSE,
}

enum HabitatClass {
	TEMPERATE_SURFACE,
	COLD_SURFACE,
	SHELTERED_SUBSURFACE,
	VENT_SURFACE,
	CRYO_SURFACE,
}

enum MetabolismClass {
	PHOTOTROPHIC,
	CHEMOTROPHIC,
	SULFUR_CHEMOSYNTHETIC,
	CRYOCHEMICAL,
}

enum MobilityClass {
	SESSILE,
	COLONIAL,
	MOTILE,
}

const KEY_BODY_ID: StringName = &"body_id"
const KEY_IS_SUPPORTED_BODY_KIND: StringName = &"is_supported_body_kind"
const KEY_HAS_NATIVE_SPECIES_BASIS: StringName = &"has_native_species_basis"
const KEY_DOMINANT_TRACK_ID: StringName = &"dominant_track_id"
const KEY_SPECIES_COMPLEXITY_CLASS: StringName = &"species_complexity_class"
const KEY_SPECIES_RICHNESS_CLASS: StringName = &"species_richness_class"
const KEY_HABITAT_CLASS: StringName = &"habitat_class"
const KEY_METABOLISM_CLASS: StringName = &"metabolism_class"
const KEY_MOBILITY_CLASS: StringName = &"mobility_class"

var _registry: Node = null
var _planetary_state_service: Node = null
var _life_potential_service: Node = null
var _biosphere_scale_service: Node = null


func configure(
		registry: Node,
		planetary_state_service: Node,
		life_potential_service: Node,
		biosphere_scale_service: Node
	) -> void:
	assert(registry != null, "NativeSpeciesService.configure: registry is null")
	assert(planetary_state_service != null, "NativeSpeciesService.configure: planetary_state_service is null")
	assert(life_potential_service != null, "NativeSpeciesService.configure: life_potential_service is null")
	assert(biosphere_scale_service != null, "NativeSpeciesService.configure: biosphere_scale_service is null")
	assert(
		planetary_state_service.has_method("describe_body"),
		"NativeSpeciesService.configure: planetary_state_service must implement describe_body(id)"
	)
	assert(
		life_potential_service.has_method("describe_body"),
		"NativeSpeciesService.configure: life_potential_service must implement describe_body(id)"
	)
	assert(
		biosphere_scale_service.has_method("describe_body"),
		"NativeSpeciesService.configure: biosphere_scale_service must implement describe_body(id)"
	)
	_registry = registry
	_planetary_state_service = planetary_state_service
	_life_potential_service = life_potential_service
	_biosphere_scale_service = biosphere_scale_service


func describe_body(id: StringName) -> Dictionary:
	if _registry == null or _planetary_state_service == null or _life_potential_service == null or _biosphere_scale_service == null:
		return _default_description(id)
	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return _default_description(id)
	if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
		return _default_description(id)
	return evaluate_from_descriptions(
		_planetary_state_service.describe_body(id),
		_life_potential_service.describe_body(id),
		_biosphere_scale_service.describe_body(id),
		id
	)


static func evaluate_from_descriptions(
		planetary_state_desc: Dictionary,
		life_potential_desc: Dictionary,
		biosphere_scale_desc: Dictionary,
		body_id: StringName = StringName("")
	) -> Dictionary:
	var resolved_body_id: StringName = body_id
	if resolved_body_id == StringName(""):
		resolved_body_id = StringName(planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_BODY_ID,
			StringName("")
		))
	if resolved_body_id == StringName(""):
		resolved_body_id = StringName(life_potential_desc.get(
			LifePotentialServiceScript.KEY_BODY_ID,
			StringName("")
		))
	if resolved_body_id == StringName(""):
		resolved_body_id = StringName(biosphere_scale_desc.get(
			BiosphereScaleServiceScript.KEY_BODY_ID,
			StringName("")
		))
	var description: Dictionary = _default_description(resolved_body_id)
	var is_supported_body_kind: bool = bool(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_IS_SUPPORTED_BODY_KIND,
		false
	)) or bool(life_potential_desc.get(
		LifePotentialServiceScript.KEY_IS_SUPPORTED_BODY_KIND,
		false
	)) or bool(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_IS_SUPPORTED_BODY_KIND,
		false
	))
	if not is_supported_body_kind:
		return description

	description[KEY_IS_SUPPORTED_BODY_KIND] = true
	if not bool(planetary_state_desc.get(PlanetaryStateServiceScript.KEY_HAS_SAMPLED_YEAR_BASIS, false)):
		return description
	if not bool(life_potential_desc.get(LifePotentialServiceScript.KEY_HAS_LIFE_POTENTIAL_BASIS, false)):
		return description
	if not bool(biosphere_scale_desc.get(BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS, false)):
		return description

	var biosphere_stage: int = int(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE,
		BiosphereScaleServiceScript.Stage.STERILE
	))
	if biosphere_stage < BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR:
		return description

	var dominant_track_id: int = int(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID,
		LifePotentialServiceScript.Track.WATER_CARBON
	))
	var carrying_capacity_index_by_track: Dictionary = biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_CARRYING_CAPACITY_INDEX_BY_TRACK,
		{}
	)
	var dominant_carrying_capacity_index: float = float(carrying_capacity_index_by_track.get(dominant_track_id, 0.0))
	var species_complexity_class: int = _complexity_class_for_stage(biosphere_stage)
	var species_richness_class: int = _richness_class_for_carrying_capacity(dominant_carrying_capacity_index)
	var dominant_band_thermal_class: int = int(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_DOMINANT_BAND_THERMAL_CLASS,
		PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
	))
	var habitat_class: int = _habitat_class_for_track_and_thermal(
		dominant_track_id,
		dominant_band_thermal_class
	)
	var metabolism_class: int = _metabolism_class_for_track_and_habitat(
		dominant_track_id,
		habitat_class
	)
	var mobility_class: int = _mobility_class_for_complexity_and_richness(
		species_complexity_class,
		species_richness_class
	)

	description[KEY_HAS_NATIVE_SPECIES_BASIS] = true
	description[KEY_DOMINANT_TRACK_ID] = dominant_track_id
	description[KEY_SPECIES_COMPLEXITY_CLASS] = species_complexity_class
	description[KEY_SPECIES_RICHNESS_CLASS] = species_richness_class
	description[KEY_HABITAT_CLASS] = habitat_class
	description[KEY_METABOLISM_CLASS] = metabolism_class
	description[KEY_MOBILITY_CLASS] = mobility_class
	return description


static func to_string_complexity_class(value: int) -> String:
	match value:
		ComplexityClass.EARLY_MACRO:
			return "EARLY_MACRO"
		ComplexityClass.DIVERSE_MACRO:
			return "DIVERSE_MACRO"
	return "UNKNOWN"


static func to_string_richness_class(value: int) -> String:
	match value:
		RichnessClass.SPARSE:
			return "SPARSE"
		RichnessClass.PATCHY:
			return "PATCHY"
		RichnessClass.DIVERSE:
			return "DIVERSE"
	return "UNKNOWN"


static func to_string_habitat_class(value: int) -> String:
	match value:
		HabitatClass.TEMPERATE_SURFACE:
			return "TEMPERATE_SURFACE"
		HabitatClass.COLD_SURFACE:
			return "COLD_SURFACE"
		HabitatClass.SHELTERED_SUBSURFACE:
			return "SHELTERED_SUBSURFACE"
		HabitatClass.VENT_SURFACE:
			return "VENT_SURFACE"
		HabitatClass.CRYO_SURFACE:
			return "CRYO_SURFACE"
	return "UNKNOWN"


static func to_string_metabolism_class(value: int) -> String:
	match value:
		MetabolismClass.PHOTOTROPHIC:
			return "PHOTOTROPHIC"
		MetabolismClass.CHEMOTROPHIC:
			return "CHEMOTROPHIC"
		MetabolismClass.SULFUR_CHEMOSYNTHETIC:
			return "SULFUR_CHEMOSYNTHETIC"
		MetabolismClass.CRYOCHEMICAL:
			return "CRYOCHEMICAL"
	return "UNKNOWN"


static func to_string_mobility_class(value: int) -> String:
	match value:
		MobilityClass.SESSILE:
			return "SESSILE"
		MobilityClass.COLONIAL:
			return "COLONIAL"
		MobilityClass.MOTILE:
			return "MOTILE"
	return "UNKNOWN"


static func _complexity_class_for_stage(biosphere_stage: int) -> int:
	if biosphere_stage >= BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM:
		return ComplexityClass.DIVERSE_MACRO
	return ComplexityClass.EARLY_MACRO


static func _richness_class_for_carrying_capacity(carrying_capacity_index: float) -> int:
	if carrying_capacity_index < 0.50:
		return RichnessClass.SPARSE
	if carrying_capacity_index < 0.75:
		return RichnessClass.PATCHY
	return RichnessClass.DIVERSE


static func _habitat_class_for_track_and_thermal(track_id: int, thermal_class: int) -> int:
	match track_id:
		LifePotentialServiceScript.Track.WATER_CARBON:
			match thermal_class:
				PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE:
					return HabitatClass.TEMPERATE_SURFACE
				PlanetaryStateServiceScript.ThermalExtremityClass.COLD, PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN:
					return HabitatClass.COLD_SURFACE
				PlanetaryStateServiceScript.ThermalExtremityClass.HOT, PlanetaryStateServiceScript.ThermalExtremityClass.EXTREME:
					return HabitatClass.SHELTERED_SUBSURFACE
		LifePotentialServiceScript.Track.SULFUR_REACTIVE:
			match thermal_class:
				PlanetaryStateServiceScript.ThermalExtremityClass.HOT, PlanetaryStateServiceScript.ThermalExtremityClass.EXTREME:
					return HabitatClass.VENT_SURFACE
				_:
					return HabitatClass.SHELTERED_SUBSURFACE
		LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT:
			match thermal_class:
				PlanetaryStateServiceScript.ThermalExtremityClass.COLD, PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN:
					return HabitatClass.CRYO_SURFACE
				_:
					return HabitatClass.SHELTERED_SUBSURFACE
	return HabitatClass.SHELTERED_SUBSURFACE


static func _metabolism_class_for_track_and_habitat(track_id: int, habitat_class: int) -> int:
	match track_id:
		LifePotentialServiceScript.Track.WATER_CARBON:
			match habitat_class:
				HabitatClass.TEMPERATE_SURFACE, HabitatClass.COLD_SURFACE:
					return MetabolismClass.PHOTOTROPHIC
				HabitatClass.SHELTERED_SUBSURFACE:
					return MetabolismClass.CHEMOTROPHIC
		LifePotentialServiceScript.Track.SULFUR_REACTIVE:
			return MetabolismClass.SULFUR_CHEMOSYNTHETIC
		LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT:
			return MetabolismClass.CRYOCHEMICAL
	return MetabolismClass.CHEMOTROPHIC


static func _mobility_class_for_complexity_and_richness(
		species_complexity_class: int,
		species_richness_class: int
	) -> int:
	if species_complexity_class == ComplexityClass.EARLY_MACRO:
		if species_richness_class == RichnessClass.DIVERSE:
			return MobilityClass.COLONIAL
		return MobilityClass.SESSILE
	match species_richness_class:
		RichnessClass.SPARSE:
			return MobilityClass.SESSILE
		RichnessClass.PATCHY:
			return MobilityClass.COLONIAL
		RichnessClass.DIVERSE:
			return MobilityClass.MOTILE
	return MobilityClass.SESSILE


static func _default_description(id: StringName) -> Dictionary:
	return {
		KEY_BODY_ID: id,
		KEY_IS_SUPPORTED_BODY_KIND: false,
		KEY_HAS_NATIVE_SPECIES_BASIS: false,
		KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.WATER_CARBON,
		KEY_SPECIES_COMPLEXITY_CLASS: ComplexityClass.EARLY_MACRO,
		KEY_SPECIES_RICHNESS_CLASS: RichnessClass.SPARSE,
		KEY_HABITAT_CLASS: HabitatClass.SHELTERED_SUBSURFACE,
		KEY_METABOLISM_CLASS: MetabolismClass.CHEMOTROPHIC,
		KEY_MOBILITY_CLASS: MobilityClass.SESSILE,
	}
