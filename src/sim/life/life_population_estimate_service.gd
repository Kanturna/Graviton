class_name LifePopulationEstimateService
extends Node


const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const LifeEcologyServiceScript = preload("res://src/sim/life/life_ecology_service.gd")
const GeneticSpeciesServiceScript = preload("res://src/sim/life/genetic_species_service.gd")

const KEY_BODY_ID: StringName = &"body_id"
const KEY_IS_SUPPORTED_BODY_KIND: StringName = &"is_supported_body_kind"
const KEY_HAS_POPULATION_ESTIMATE_BASIS: StringName = &"has_population_estimate_basis"
const KEY_POPULATION_ESTIMATE_PROFILES: StringName = &"population_estimate_profiles"

const KEY_LIFEFORM_ID: StringName = &"lifeform_id"
const KEY_ROLE_CLASS: StringName = &"role_class"
const KEY_POPULATION_CLASS: StringName = &"population_class"
const KEY_POPULATION_INDEX: StringName = &"population_index"
const KEY_ESTIMATE_MIN: StringName = &"estimate_min"
const KEY_ESTIMATE_MAX: StringName = &"estimate_max"

const LOG10_MICROBIAL_BASE: float = 12.0
const LOG10_COMPLEX_MULTICELLULAR_BASE: float = 8.0
const LOG10_COMPLEX_ECOSYSTEM_BASE: float = 8.5
const MIN_LOG10_ESTIMATE: float = 0.0
const MAX_LOG10_ESTIMATE: float = 13.0
const MIN_POPULATION_INDEX_FOR_LOG: float = 0.001
const LOG_10: float = 2.302585092994046

var _registry: Node = null
var _biosphere_scale_service: Node = null
var _life_ecology_service: Node = null


func configure(
		registry: Node,
		biosphere_scale_service: Node,
		life_ecology_service: Node
	) -> void:
	assert(registry != null, "LifePopulationEstimateService.configure: registry is null")
	assert(biosphere_scale_service != null, "LifePopulationEstimateService.configure: biosphere_scale_service is null")
	assert(life_ecology_service != null, "LifePopulationEstimateService.configure: life_ecology_service is null")
	assert(
		biosphere_scale_service.has_method("describe_body"),
		"LifePopulationEstimateService.configure: biosphere_scale_service must implement describe_body(id)"
	)
	assert(
		life_ecology_service.has_method("describe_body"),
		"LifePopulationEstimateService.configure: life_ecology_service must implement describe_body(id)"
	)
	_registry = registry
	_biosphere_scale_service = biosphere_scale_service
	_life_ecology_service = life_ecology_service


func describe_body(id: StringName) -> Dictionary:
	if _registry == null or _biosphere_scale_service == null or _life_ecology_service == null:
		return _default_description(id)
	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return _default_description(id)
	if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
		return _default_description(id)
	return evaluate_from_descriptions(
		_biosphere_scale_service.describe_body(id),
		_life_ecology_service.describe_body(id),
		id
	)


static func evaluate_from_descriptions(
		biosphere_scale_desc: Dictionary,
		life_ecology_desc: Dictionary,
		body_id: StringName = StringName("")
	) -> Dictionary:
	var resolved_body_id: StringName = _resolved_body_id(
		biosphere_scale_desc,
		life_ecology_desc,
		body_id
	)
	var description: Dictionary = _default_description(resolved_body_id)
	var is_supported_body_kind: bool = bool(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_IS_SUPPORTED_BODY_KIND,
		false
	)) or bool(life_ecology_desc.get(
		LifeEcologyServiceScript.KEY_IS_SUPPORTED_BODY_KIND,
		false
	))
	if not is_supported_body_kind:
		return description

	description[KEY_IS_SUPPORTED_BODY_KIND] = true
	if not bool(biosphere_scale_desc.get(BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS, false)):
		return description
	if not bool(life_ecology_desc.get(LifeEcologyServiceScript.KEY_HAS_LIFE_ECOLOGY_BASIS, false)):
		return description

	var biosphere_stage: int = int(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE,
		BiosphereScaleServiceScript.Stage.STERILE
	))
	if biosphere_stage < BiosphereScaleServiceScript.Stage.MICROBIAL:
		return description

	var ecology_profiles: Array = life_ecology_desc.get(
		LifeEcologyServiceScript.KEY_POPULATION_PROFILES,
		[]
	)
	if ecology_profiles.is_empty():
		return description

	var estimate_profiles: Array[Dictionary] = []
	var has_positive_estimate: bool = false
	for profile_variant in ecology_profiles:
		var ecology_profile: Dictionary = profile_variant
		var estimate_profile: Dictionary = _estimate_profile_from_ecology_profile(
			ecology_profile,
			biosphere_stage
		)
		if int(estimate_profile.get(KEY_ESTIMATE_MAX, 0)) > 0:
			has_positive_estimate = true
		estimate_profiles.append(estimate_profile)

	if not has_positive_estimate:
		return description

	description[KEY_HAS_POPULATION_ESTIMATE_BASIS] = true
	description[KEY_POPULATION_ESTIMATE_PROFILES] = estimate_profiles
	return description


static func _estimate_profile_from_ecology_profile(
		ecology_profile: Dictionary,
		biosphere_stage: int
	) -> Dictionary:
	var population_index: float = clampf(float(ecology_profile.get(
		LifeEcologyServiceScript.KEY_POPULATION_INDEX,
		0.0
	)), 0.0, 1.0)
	var estimate_min: int = 0
	var estimate_max: int = 0
	if population_index > 0.0:
		var center_log10: float = clampf(
			_stage_base_log10(biosphere_stage) + _log10(maxf(population_index, MIN_POPULATION_INDEX_FOR_LOG)),
			MIN_LOG10_ESTIMATE,
			MAX_LOG10_ESTIMATE
		)
		var min_exp: int = int(floor(center_log10))
		var max_exp: int = mini(min_exp + 1, int(MAX_LOG10_ESTIMATE))
		estimate_min = int(pow(10.0, float(min_exp)))
		estimate_max = int(pow(10.0, float(max_exp)))

	return {
		KEY_LIFEFORM_ID: StringName(ecology_profile.get(
			LifeEcologyServiceScript.KEY_LIFEFORM_ID,
			StringName("")
		)),
		KEY_ROLE_CLASS: int(ecology_profile.get(
			LifeEcologyServiceScript.KEY_ROLE_CLASS,
			GeneticSpeciesServiceScript.RoleClass.PRODUCER
		)),
		KEY_POPULATION_CLASS: int(ecology_profile.get(
			LifeEcologyServiceScript.KEY_POPULATION_CLASS,
			LifeEcologyServiceScript.PopulationClass.NONE
		)),
		KEY_POPULATION_INDEX: population_index,
		KEY_ESTIMATE_MIN: estimate_min,
		KEY_ESTIMATE_MAX: estimate_max,
	}


static func _stage_base_log10(biosphere_stage: int) -> float:
	match biosphere_stage:
		BiosphereScaleServiceScript.Stage.MICROBIAL:
			return LOG10_MICROBIAL_BASE
		BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR:
			return LOG10_COMPLEX_MULTICELLULAR_BASE
		BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM:
			return LOG10_COMPLEX_ECOSYSTEM_BASE
	return 0.0


static func _log10(value: float) -> float:
	return log(value) / LOG_10


static func _resolved_body_id(
		biosphere_scale_desc: Dictionary,
		life_ecology_desc: Dictionary,
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
	return StringName(life_ecology_desc.get(
		LifeEcologyServiceScript.KEY_BODY_ID,
		StringName("")
	))


static func _default_description(id: StringName) -> Dictionary:
	return {
		KEY_BODY_ID: id,
		KEY_IS_SUPPORTED_BODY_KIND: false,
		KEY_HAS_POPULATION_ESTIMATE_BASIS: false,
		KEY_POPULATION_ESTIMATE_PROFILES: [],
	}
