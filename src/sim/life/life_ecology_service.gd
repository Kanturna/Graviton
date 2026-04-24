class_name LifeEcologyService
extends Node


const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const GeneticSpeciesServiceScript = preload("res://src/sim/life/genetic_species_service.gd")

enum PopulationClass {
	NONE,
	EMERGING,
	SPARSE,
	STABLE,
	FLOURISHING,
}

const KEY_BODY_ID: StringName = &"body_id"
const KEY_IS_SUPPORTED_BODY_KIND: StringName = &"is_supported_body_kind"
const KEY_HAS_LIFE_ECOLOGY_BASIS: StringName = &"has_life_ecology_basis"
const KEY_POPULATION_PROFILES: StringName = &"population_profiles"
const KEY_DOMINANT_LIFEFORM_ID: StringName = &"dominant_lifeform_id"

const KEY_LIFEFORM_ID: StringName = &"lifeform_id"
const KEY_ROLE_CLASS: StringName = &"role_class"
const KEY_ABUNDANCE_CLASS: StringName = &"abundance_class"
const KEY_SELECTION_PRESSURE_CLASS: StringName = &"selection_pressure_class"
const KEY_POPULATION_INDEX: StringName = &"population_index"
const KEY_POPULATION_CLASS: StringName = &"population_class"

const ABUNDANCE_WEIGHT_TRACE: float = 0.08
const ABUNDANCE_WEIGHT_LOCAL: float = 0.22
const ABUNDANCE_WEIGHT_COMMON: float = 0.55
const ABUNDANCE_WEIGHT_DOMINANT: float = 1.0

const PRESSURE_FACTOR_LOW: float = 1.0
const PRESSURE_FACTOR_MODERATE: float = 0.85
const PRESSURE_FACTOR_HIGH: float = 0.65
const PRESSURE_FACTOR_EXTREME: float = 0.40

const ROLE_FACTOR_PRODUCER: float = 1.0
const ROLE_FACTOR_DECOMPOSER: float = 0.55
const ROLE_FACTOR_GRAZER_FILTER: float = 0.35
const ROLE_FACTOR_PARASITE_SYMBIONT: float = 0.18
const ROLE_FACTOR_PREDATOR: float = 0.08

var _registry: Node = null
var _biosphere_scale_service: Node = null
var _genetic_species_service: Node = null


func configure(
		registry: Node,
		biosphere_scale_service: Node,
		genetic_species_service: Node
	) -> void:
	assert(registry != null, "LifeEcologyService.configure: registry is null")
	assert(biosphere_scale_service != null, "LifeEcologyService.configure: biosphere_scale_service is null")
	assert(genetic_species_service != null, "LifeEcologyService.configure: genetic_species_service is null")
	assert(
		biosphere_scale_service.has_method("describe_body"),
		"LifeEcologyService.configure: biosphere_scale_service must implement describe_body(id)"
	)
	assert(
		genetic_species_service.has_method("describe_body"),
		"LifeEcologyService.configure: genetic_species_service must implement describe_body(id)"
	)
	_registry = registry
	_biosphere_scale_service = biosphere_scale_service
	_genetic_species_service = genetic_species_service


func describe_body(id: StringName) -> Dictionary:
	if _registry == null or _biosphere_scale_service == null or _genetic_species_service == null:
		return _default_description(id)
	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return _default_description(id)
	if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
		return _default_description(id)
	return evaluate_from_descriptions(
		_biosphere_scale_service.describe_body(id),
		_genetic_species_service.describe_body(id),
		id
	)


static func evaluate_from_descriptions(
		biosphere_scale_desc: Dictionary,
		genetic_species_desc: Dictionary,
		body_id: StringName = StringName("")
	) -> Dictionary:
	var resolved_body_id: StringName = _resolved_body_id(
		biosphere_scale_desc,
		genetic_species_desc,
		body_id
	)
	var description: Dictionary = _default_description(resolved_body_id)
	var is_supported_body_kind: bool = bool(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_IS_SUPPORTED_BODY_KIND,
		false
	)) or bool(genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_IS_SUPPORTED_BODY_KIND,
		false
	))
	if not is_supported_body_kind:
		return description

	description[KEY_IS_SUPPORTED_BODY_KIND] = true
	if not bool(biosphere_scale_desc.get(BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS, false)):
		return description
	if not bool(genetic_species_desc.get(GeneticSpeciesServiceScript.KEY_HAS_GENETIC_SPECIES_BASIS, false)):
		return description

	var biosphere_stage: int = int(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE,
		BiosphereScaleServiceScript.Stage.STERILE
	))
	if biosphere_stage < BiosphereScaleServiceScript.Stage.MICROBIAL:
		return description

	var genetic_profiles: Array = genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES,
		[]
	)
	if genetic_profiles.is_empty():
		return description

	var dominant_biomass_index: float = clampf(float(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_DOMINANT_BIOMASS_INDEX,
		0.0
	)), 0.0, 1.0)
	var population_profiles: Array[Dictionary] = []
	for profile_variant in genetic_profiles:
		var genetic_profile: Dictionary = profile_variant
		population_profiles.append(_population_profile_from_genetic_profile(
			genetic_profile,
			dominant_biomass_index
		))

	description[KEY_HAS_LIFE_ECOLOGY_BASIS] = true
	description[KEY_POPULATION_PROFILES] = population_profiles
	description[KEY_DOMINANT_LIFEFORM_ID] = StringName(genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_DOMINANT_LIFEFORM_ID,
		StringName("")
	))
	if description[KEY_DOMINANT_LIFEFORM_ID] == StringName("") and not population_profiles.is_empty():
		description[KEY_DOMINANT_LIFEFORM_ID] = population_profiles[0].get(KEY_LIFEFORM_ID, StringName(""))
	return description


static func to_string_population_class(value: int) -> String:
	match value:
		PopulationClass.NONE:
			return "NONE"
		PopulationClass.EMERGING:
			return "EMERGING"
		PopulationClass.SPARSE:
			return "SPARSE"
		PopulationClass.STABLE:
			return "STABLE"
		PopulationClass.FLOURISHING:
			return "FLOURISHING"
	return "UNKNOWN"


static func _population_profile_from_genetic_profile(
		genetic_profile: Dictionary,
		dominant_biomass_index: float
	) -> Dictionary:
	var role_class: int = int(genetic_profile.get(
		GeneticSpeciesServiceScript.KEY_ROLE_CLASS,
		GeneticSpeciesServiceScript.RoleClass.PRODUCER
	))
	var abundance_class: int = int(genetic_profile.get(
		GeneticSpeciesServiceScript.KEY_ABUNDANCE_CLASS,
		GeneticSpeciesServiceScript.AbundanceClass.TRACE
	))
	var selection_pressure_class: int = int(genetic_profile.get(
		GeneticSpeciesServiceScript.KEY_SELECTION_PRESSURE_CLASS,
		GeneticSpeciesServiceScript.SelectionPressureClass.LOW
	))
	var population_index: float = clampf(
		dominant_biomass_index
			* _abundance_weight(abundance_class)
			* _pressure_factor(selection_pressure_class)
			* _role_factor(role_class),
		0.0,
		1.0
	)
	return {
		KEY_LIFEFORM_ID: StringName(genetic_profile.get(
			GeneticSpeciesServiceScript.KEY_LIFEFORM_ID,
			StringName("")
		)),
		KEY_ROLE_CLASS: role_class,
		KEY_ABUNDANCE_CLASS: abundance_class,
		KEY_SELECTION_PRESSURE_CLASS: selection_pressure_class,
		KEY_POPULATION_INDEX: population_index,
		KEY_POPULATION_CLASS: _population_class_for_index(population_index),
	}


static func _abundance_weight(abundance_class: int) -> float:
	match abundance_class:
		GeneticSpeciesServiceScript.AbundanceClass.TRACE:
			return ABUNDANCE_WEIGHT_TRACE
		GeneticSpeciesServiceScript.AbundanceClass.LOCAL:
			return ABUNDANCE_WEIGHT_LOCAL
		GeneticSpeciesServiceScript.AbundanceClass.COMMON:
			return ABUNDANCE_WEIGHT_COMMON
		GeneticSpeciesServiceScript.AbundanceClass.DOMINANT:
			return ABUNDANCE_WEIGHT_DOMINANT
	return ABUNDANCE_WEIGHT_TRACE


static func _pressure_factor(selection_pressure_class: int) -> float:
	match selection_pressure_class:
		GeneticSpeciesServiceScript.SelectionPressureClass.LOW:
			return PRESSURE_FACTOR_LOW
		GeneticSpeciesServiceScript.SelectionPressureClass.MODERATE:
			return PRESSURE_FACTOR_MODERATE
		GeneticSpeciesServiceScript.SelectionPressureClass.HIGH:
			return PRESSURE_FACTOR_HIGH
		GeneticSpeciesServiceScript.SelectionPressureClass.EXTREME:
			return PRESSURE_FACTOR_EXTREME
	return PRESSURE_FACTOR_LOW


static func _role_factor(role_class: int) -> float:
	match role_class:
		GeneticSpeciesServiceScript.RoleClass.PRODUCER:
			return ROLE_FACTOR_PRODUCER
		GeneticSpeciesServiceScript.RoleClass.GRAZER_FILTER:
			return ROLE_FACTOR_GRAZER_FILTER
		GeneticSpeciesServiceScript.RoleClass.DECOMPOSER:
			return ROLE_FACTOR_DECOMPOSER
		GeneticSpeciesServiceScript.RoleClass.PREDATOR:
			return ROLE_FACTOR_PREDATOR
		GeneticSpeciesServiceScript.RoleClass.PARASITE_SYMBIONT:
			return ROLE_FACTOR_PARASITE_SYMBIONT
	return ROLE_FACTOR_PRODUCER


static func _population_class_for_index(population_index: float) -> int:
	if population_index <= 0.0:
		return PopulationClass.NONE
	if population_index < 0.05:
		return PopulationClass.EMERGING
	if population_index < 0.18:
		return PopulationClass.SPARSE
	if population_index < 0.45:
		return PopulationClass.STABLE
	return PopulationClass.FLOURISHING


static func _resolved_body_id(
		biosphere_scale_desc: Dictionary,
		genetic_species_desc: Dictionary,
		body_id: StringName
	) -> StringName:
	if body_id != StringName(""):
		return body_id
	var resolved_body_id: StringName = StringName(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_BODY_ID,
		StringName("")
	))
	if resolved_body_id != StringName(""):
		return resolved_body_id
	return StringName(genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_BODY_ID,
		StringName("")
	))


static func _default_description(id: StringName) -> Dictionary:
	return {
		KEY_BODY_ID: id,
		KEY_IS_SUPPORTED_BODY_KIND: false,
		KEY_HAS_LIFE_ECOLOGY_BASIS: false,
		KEY_POPULATION_PROFILES: [],
		KEY_DOMINANT_LIFEFORM_ID: StringName(""),
	}
