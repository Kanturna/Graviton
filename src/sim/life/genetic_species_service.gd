class_name GeneticSpeciesService
extends Node


const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const NativeSpeciesServiceScript = preload("res://src/sim/life/native_species_service.gd")

enum RoleClass {
	PRODUCER,
	GRAZER_FILTER,
	DECOMPOSER,
	PREDATOR,
	PARASITE_SYMBIONT,
}

enum AbundanceClass {
	TRACE,
	LOCAL,
	COMMON,
	DOMINANT,
}

enum BodyPlanClass {
	MAT_FILM,
	COLONY,
	UNICELLULAR,
	MACRO_SESSILE,
	MACRO_MOTILE,
}

enum ReproductionClass {
	DIVISION,
	SPORE,
	EGG_CLUTCH,
	COMPLEX_BROOD,
}

enum StressToleranceClass {
	BASELINE,
	COLD_HARDY,
	HEAT_HARDY,
	SEASONAL_DORMANT,
	EXTREME_HARDY,
}

enum ColorFamily {
	GREEN_BLUE,
	GREY_BIOLUMEN,
	AMBER_RUST,
	PALE_BLUE_VIOLET,
}

enum MotionStyle {
	ANCHORED,
	SLOW_EXPANDING,
	DRIFTING_OR_CRAWLING,
}

const KEY_BODY_ID: StringName = &"body_id"
const KEY_IS_SUPPORTED_BODY_KIND: StringName = &"is_supported_body_kind"
const KEY_HAS_GENETIC_SPECIES_BASIS: StringName = &"has_genetic_species_basis"
const KEY_LIFEFORM_PROFILES: StringName = &"lifeform_profiles"
const KEY_DOMINANT_LIFEFORM_ID: StringName = &"dominant_lifeform_id"
const KEY_PROTO_FORM_SUMMARY: StringName = &"proto_form_summary"

const KEY_LIFEFORM_ID: StringName = &"lifeform_id"
const KEY_ROLE_CLASS: StringName = &"role_class"
const KEY_ABUNDANCE_CLASS: StringName = &"abundance_class"
const KEY_TRAIT_LOCI: StringName = &"trait_loci"
const KEY_VISUAL_PROFILE: StringName = &"visual_profile"

const KEY_METABOLISM_LOCUS: StringName = &"metabolism_locus"
const KEY_HABITAT_LOCUS: StringName = &"habitat_locus"
const KEY_BODY_PLAN_LOCUS: StringName = &"body_plan_locus"
const KEY_MOBILITY_LOCUS: StringName = &"mobility_locus"
const KEY_REPRODUCTION_LOCUS: StringName = &"reproduction_locus"
const KEY_STRESS_TOLERANCE_LOCUS: StringName = &"stress_tolerance_locus"

const KEY_VISUAL_BODY_PLAN_CLASS: StringName = &"body_plan_class"
const KEY_VISUAL_COLOR_FAMILY: StringName = &"color_family"
const KEY_VISUAL_MOTION_STYLE: StringName = &"motion_style"

const PROTO_FORM_CHEMICAL_PRECURSORS: String = "CHEMICAL_PRECURSORS"

var _registry: Node = null
var _planetary_state_service: Node = null
var _life_potential_service: Node = null
var _biosphere_scale_service: Node = null
var _native_species_service: Node = null


func configure(
		registry: Node,
		planetary_state_service: Node,
		life_potential_service: Node,
		biosphere_scale_service: Node,
		native_species_service: Node
	) -> void:
	assert(registry != null, "GeneticSpeciesService.configure: registry is null")
	assert(planetary_state_service != null, "GeneticSpeciesService.configure: planetary_state_service is null")
	assert(life_potential_service != null, "GeneticSpeciesService.configure: life_potential_service is null")
	assert(biosphere_scale_service != null, "GeneticSpeciesService.configure: biosphere_scale_service is null")
	assert(native_species_service != null, "GeneticSpeciesService.configure: native_species_service is null")
	assert(
		planetary_state_service.has_method("describe_body"),
		"GeneticSpeciesService.configure: planetary_state_service must implement describe_body(id)"
	)
	assert(
		life_potential_service.has_method("describe_body"),
		"GeneticSpeciesService.configure: life_potential_service must implement describe_body(id)"
	)
	assert(
		biosphere_scale_service.has_method("describe_body"),
		"GeneticSpeciesService.configure: biosphere_scale_service must implement describe_body(id)"
	)
	assert(
		native_species_service.has_method("describe_body"),
		"GeneticSpeciesService.configure: native_species_service must implement describe_body(id)"
	)
	_registry = registry
	_planetary_state_service = planetary_state_service
	_life_potential_service = life_potential_service
	_biosphere_scale_service = biosphere_scale_service
	_native_species_service = native_species_service


func describe_body(id: StringName) -> Dictionary:
	if _registry == null or _planetary_state_service == null or _life_potential_service == null or _biosphere_scale_service == null or _native_species_service == null:
		return _default_description(id)
	var def: BodyDef = _registry.get_def(id)
	if def == null:
		return _default_description(id)
	if def.kind != BodyType.Kind.PLANET and def.kind != BodyType.Kind.MOON:
		return _default_description(id)
	var planetary_state_desc: Dictionary = _planetary_state_service.describe_body(id)
	var life_potential_desc: Dictionary = _life_potential_service.describe_body(id)
	var biosphere_scale_desc: Dictionary = _biosphere_scale_service.describe_body(id)
	return evaluate_from_descriptions(
		planetary_state_desc,
		life_potential_desc,
		biosphere_scale_desc,
		_native_species_service.describe_body(id),
		id
	)


static func evaluate_from_descriptions(
		planetary_state_desc: Dictionary,
		life_potential_desc: Dictionary,
		biosphere_scale_desc: Dictionary,
		native_species_desc: Dictionary = {},
		body_id: StringName = StringName("")
	) -> Dictionary:
	var resolved_body_id: StringName = _resolved_body_id(
		planetary_state_desc,
		life_potential_desc,
		biosphere_scale_desc,
		body_id
	)
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
	if biosphere_stage < BiosphereScaleServiceScript.Stage.PREBIOTIC:
		return description

	description[KEY_HAS_GENETIC_SPECIES_BASIS] = true
	if biosphere_stage == BiosphereScaleServiceScript.Stage.PREBIOTIC:
		description[KEY_PROTO_FORM_SUMMARY] = PROTO_FORM_CHEMICAL_PRECURSORS
		return description

	var resolved_native_species_desc: Dictionary = native_species_desc
	if resolved_native_species_desc.is_empty():
		resolved_native_species_desc = NativeSpeciesServiceScript.evaluate_from_descriptions(
			planetary_state_desc,
			life_potential_desc,
			biosphere_scale_desc,
			resolved_body_id
		)

	var richness_class: int = _richness_class_for_stage(
		biosphere_stage,
		biosphere_scale_desc,
		resolved_native_species_desc
	)
	if biosphere_stage >= BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR and not bool(resolved_native_species_desc.get(
		NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS,
		false
	)):
		description[KEY_HAS_GENETIC_SPECIES_BASIS] = false
		return description

	var roles: Array[int] = _roles_for_stage_and_richness(
		biosphere_stage,
		richness_class,
		_stress_tolerance_class(planetary_state_desc)
	)
	var profiles: Array[Dictionary] = []
	for role_class in roles:
		profiles.append(_profile_for_role(
			resolved_body_id,
			role_class,
			biosphere_stage,
			richness_class,
			planetary_state_desc,
			biosphere_scale_desc,
			resolved_native_species_desc
		))
	profiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var abundance_a: int = int(a.get(KEY_ABUNDANCE_CLASS, AbundanceClass.TRACE))
		var abundance_b: int = int(b.get(KEY_ABUNDANCE_CLASS, AbundanceClass.TRACE))
		if abundance_a != abundance_b:
			return abundance_a > abundance_b
		return int(a.get(KEY_ROLE_CLASS, RoleClass.PRODUCER)) < int(b.get(KEY_ROLE_CLASS, RoleClass.PRODUCER))
	)

	description[KEY_LIFEFORM_PROFILES] = profiles
	if not profiles.is_empty():
		description[KEY_DOMINANT_LIFEFORM_ID] = profiles[0].get(KEY_LIFEFORM_ID, StringName(""))
	return description


static func to_string_role_class(value: int) -> String:
	match value:
		RoleClass.PRODUCER:
			return "PRODUCER"
		RoleClass.GRAZER_FILTER:
			return "GRAZER_FILTER"
		RoleClass.DECOMPOSER:
			return "DECOMPOSER"
		RoleClass.PREDATOR:
			return "PREDATOR"
		RoleClass.PARASITE_SYMBIONT:
			return "PARASITE_SYMBIONT"
	return "UNKNOWN"


static func to_string_abundance_class(value: int) -> String:
	match value:
		AbundanceClass.TRACE:
			return "TRACE"
		AbundanceClass.LOCAL:
			return "LOCAL"
		AbundanceClass.COMMON:
			return "COMMON"
		AbundanceClass.DOMINANT:
			return "DOMINANT"
	return "UNKNOWN"


static func to_string_body_plan_class(value: int) -> String:
	match value:
		BodyPlanClass.MAT_FILM:
			return "MAT_FILM"
		BodyPlanClass.COLONY:
			return "COLONY"
		BodyPlanClass.UNICELLULAR:
			return "UNICELLULAR"
		BodyPlanClass.MACRO_SESSILE:
			return "MACRO_SESSILE"
		BodyPlanClass.MACRO_MOTILE:
			return "MACRO_MOTILE"
	return "UNKNOWN"


static func to_string_reproduction_class(value: int) -> String:
	match value:
		ReproductionClass.DIVISION:
			return "DIVISION"
		ReproductionClass.SPORE:
			return "SPORE"
		ReproductionClass.EGG_CLUTCH:
			return "EGG_CLUTCH"
		ReproductionClass.COMPLEX_BROOD:
			return "COMPLEX_BROOD"
	return "UNKNOWN"


static func to_string_stress_tolerance_class(value: int) -> String:
	match value:
		StressToleranceClass.BASELINE:
			return "BASELINE"
		StressToleranceClass.COLD_HARDY:
			return "COLD_HARDY"
		StressToleranceClass.HEAT_HARDY:
			return "HEAT_HARDY"
		StressToleranceClass.SEASONAL_DORMANT:
			return "SEASONAL_DORMANT"
		StressToleranceClass.EXTREME_HARDY:
			return "EXTREME_HARDY"
	return "UNKNOWN"


static func to_string_color_family(value: int) -> String:
	match value:
		ColorFamily.GREEN_BLUE:
			return "GREEN_BLUE"
		ColorFamily.GREY_BIOLUMEN:
			return "GREY_BIOLUMEN"
		ColorFamily.AMBER_RUST:
			return "AMBER_RUST"
		ColorFamily.PALE_BLUE_VIOLET:
			return "PALE_BLUE_VIOLET"
	return "UNKNOWN"


static func to_string_motion_style(value: int) -> String:
	match value:
		MotionStyle.ANCHORED:
			return "ANCHORED"
		MotionStyle.SLOW_EXPANDING:
			return "SLOW_EXPANDING"
		MotionStyle.DRIFTING_OR_CRAWLING:
			return "DRIFTING_OR_CRAWLING"
	return "UNKNOWN"


static func _resolved_body_id(
		planetary_state_desc: Dictionary,
		life_potential_desc: Dictionary,
		biosphere_scale_desc: Dictionary,
		body_id: StringName
	) -> StringName:
	if body_id != StringName(""):
		return body_id
	var resolved_body_id: StringName = StringName(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_BODY_ID,
		StringName("")
	))
	if resolved_body_id != StringName(""):
		return resolved_body_id
	resolved_body_id = StringName(life_potential_desc.get(
		LifePotentialServiceScript.KEY_BODY_ID,
		StringName("")
	))
	if resolved_body_id != StringName(""):
		return resolved_body_id
	return StringName(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_BODY_ID,
		StringName("")
	))


static func _roles_for_stage_and_richness(
		biosphere_stage: int,
		richness_class: int,
		stress_tolerance_class: int
	) -> Array[int]:
	if biosphere_stage == BiosphereScaleServiceScript.Stage.MICROBIAL:
		if richness_class == NativeSpeciesServiceScript.RichnessClass.SPARSE:
			return [RoleClass.PRODUCER]
		return [RoleClass.PRODUCER, RoleClass.DECOMPOSER]
	if biosphere_stage == BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR:
		match richness_class:
			NativeSpeciesServiceScript.RichnessClass.SPARSE:
				return [RoleClass.PRODUCER]
			NativeSpeciesServiceScript.RichnessClass.PATCHY:
				return [RoleClass.PRODUCER, RoleClass.GRAZER_FILTER]
			NativeSpeciesServiceScript.RichnessClass.DIVERSE:
				return [RoleClass.PRODUCER, RoleClass.GRAZER_FILTER, RoleClass.DECOMPOSER]
	if biosphere_stage >= BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM:
		var roles: Array[int] = [
			RoleClass.PRODUCER,
			RoleClass.GRAZER_FILTER,
			RoleClass.DECOMPOSER,
		]
		if richness_class == NativeSpeciesServiceScript.RichnessClass.PATCHY or richness_class == NativeSpeciesServiceScript.RichnessClass.DIVERSE:
			roles.append(RoleClass.PREDATOR)
		if richness_class == NativeSpeciesServiceScript.RichnessClass.DIVERSE and stress_tolerance_class != StressToleranceClass.BASELINE:
			roles.append(RoleClass.PARASITE_SYMBIONT)
		return roles
	return []


static func _profile_for_role(
		body_id: StringName,
		role_class: int,
		biosphere_stage: int,
		richness_class: int,
		planetary_state_desc: Dictionary,
		biosphere_scale_desc: Dictionary,
		native_species_desc: Dictionary
	) -> Dictionary:
	var trait_loci: Dictionary = _trait_loci_for_role(
		role_class,
		biosphere_stage,
		richness_class,
		planetary_state_desc,
		biosphere_scale_desc,
		native_species_desc
	)
	var visual_profile: Dictionary = _visual_profile_from_trait_loci(trait_loci)
	return {
		KEY_LIFEFORM_ID: StringName("%s_%s" % [
			String(body_id),
			to_string_role_class(role_class).to_lower()
		]),
		KEY_ROLE_CLASS: role_class,
		KEY_ABUNDANCE_CLASS: _abundance_class_for_role(role_class, biosphere_stage),
		KEY_TRAIT_LOCI: trait_loci,
		KEY_VISUAL_PROFILE: visual_profile,
	}


static func _trait_loci_for_role(
		role_class: int,
		biosphere_stage: int,
		richness_class: int,
		planetary_state_desc: Dictionary,
		biosphere_scale_desc: Dictionary,
		native_species_desc: Dictionary
	) -> Dictionary:
	var dominant_track_id: int = int(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID,
		LifePotentialServiceScript.Track.WATER_CARBON
	))
	var thermal_class: int = int(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_DOMINANT_BAND_THERMAL_CLASS,
		planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_THERMAL_EXTREMITY_CLASS,
			PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
		)
	))
	var has_native_basis: bool = bool(native_species_desc.get(
		NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS,
		false
	))
	var fallback_habitat_class: int = NativeSpeciesServiceScript.habitat_class_for_track_and_thermal(
		dominant_track_id,
		thermal_class
	)
	var habitat_class: int = fallback_habitat_class
	if has_native_basis:
		habitat_class = int(native_species_desc.get(
			NativeSpeciesServiceScript.KEY_HABITAT_CLASS,
			fallback_habitat_class
		))
	var fallback_metabolism_class: int = NativeSpeciesServiceScript.metabolism_class_for_track_and_habitat(
		dominant_track_id,
		habitat_class
	)
	var metabolism_class: int = fallback_metabolism_class
	if has_native_basis:
		metabolism_class = int(native_species_desc.get(
			NativeSpeciesServiceScript.KEY_METABOLISM_CLASS,
			fallback_metabolism_class
		))
	var fallback_mobility_class: int = _microbial_mobility_for_role(role_class, richness_class)
	var mobility_class: int = fallback_mobility_class
	if has_native_basis:
		mobility_class = int(native_species_desc.get(
			NativeSpeciesServiceScript.KEY_MOBILITY_CLASS,
			fallback_mobility_class
		))
	return {
		KEY_METABOLISM_LOCUS: metabolism_class,
		KEY_HABITAT_LOCUS: habitat_class,
		KEY_BODY_PLAN_LOCUS: _body_plan_class_for_role(role_class, biosphere_stage),
		KEY_MOBILITY_LOCUS: mobility_class,
		KEY_REPRODUCTION_LOCUS: _reproduction_class_for_role(role_class, biosphere_stage),
		KEY_STRESS_TOLERANCE_LOCUS: _stress_tolerance_class(planetary_state_desc),
	}


static func _visual_profile_from_trait_loci(trait_loci: Dictionary) -> Dictionary:
	var metabolism_class: int = int(trait_loci.get(
		KEY_METABOLISM_LOCUS,
		NativeSpeciesServiceScript.MetabolismClass.CHEMOTROPHIC
	))
	var mobility_class: int = int(trait_loci.get(
		KEY_MOBILITY_LOCUS,
		NativeSpeciesServiceScript.MobilityClass.SESSILE
	))
	return {
		KEY_VISUAL_BODY_PLAN_CLASS: int(trait_loci.get(KEY_BODY_PLAN_LOCUS, BodyPlanClass.UNICELLULAR)),
		KEY_VISUAL_COLOR_FAMILY: _color_family_for_metabolism(metabolism_class),
		KEY_VISUAL_MOTION_STYLE: _motion_style_for_mobility(mobility_class),
	}


static func _richness_class_for_stage(
		biosphere_stage: int,
		biosphere_scale_desc: Dictionary,
		native_species_desc: Dictionary
	) -> int:
	if biosphere_stage >= BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR:
		return int(native_species_desc.get(
			NativeSpeciesServiceScript.KEY_SPECIES_RICHNESS_CLASS,
			NativeSpeciesServiceScript.RichnessClass.SPARSE
		))
	var dominant_track_id: int = int(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID,
		LifePotentialServiceScript.Track.WATER_CARBON
	))
	var carrying_capacity_index_by_track: Dictionary = biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_CARRYING_CAPACITY_INDEX_BY_TRACK,
		{}
	)
	var dominant_carrying_capacity_index: float = float(carrying_capacity_index_by_track.get(dominant_track_id, 0.0))
	if dominant_carrying_capacity_index < 0.50:
		return NativeSpeciesServiceScript.RichnessClass.SPARSE
	if dominant_carrying_capacity_index < 0.75:
		return NativeSpeciesServiceScript.RichnessClass.PATCHY
	return NativeSpeciesServiceScript.RichnessClass.DIVERSE


static func _body_plan_class_for_role(role_class: int, biosphere_stage: int) -> int:
	var is_microbial: bool = biosphere_stage == BiosphereScaleServiceScript.Stage.MICROBIAL
	match role_class:
		RoleClass.PRODUCER:
			return BodyPlanClass.MAT_FILM if is_microbial else BodyPlanClass.MACRO_SESSILE
		RoleClass.GRAZER_FILTER:
			return BodyPlanClass.MACRO_MOTILE
		RoleClass.DECOMPOSER:
			return BodyPlanClass.COLONY
		RoleClass.PREDATOR:
			return BodyPlanClass.MACRO_MOTILE
		RoleClass.PARASITE_SYMBIONT:
			return BodyPlanClass.COLONY
	return BodyPlanClass.UNICELLULAR


static func _reproduction_class_for_role(role_class: int, biosphere_stage: int) -> int:
	var is_microbial: bool = biosphere_stage == BiosphereScaleServiceScript.Stage.MICROBIAL
	match role_class:
		RoleClass.PRODUCER:
			return ReproductionClass.DIVISION if is_microbial else ReproductionClass.SPORE
		RoleClass.GRAZER_FILTER:
			return ReproductionClass.EGG_CLUTCH
		RoleClass.DECOMPOSER:
			return ReproductionClass.SPORE
		RoleClass.PREDATOR:
			return ReproductionClass.COMPLEX_BROOD
		RoleClass.PARASITE_SYMBIONT:
			return ReproductionClass.SPORE
	return ReproductionClass.DIVISION


static func _abundance_class_for_role(role_class: int, biosphere_stage: int) -> int:
	match role_class:
		RoleClass.PRODUCER:
			return AbundanceClass.DOMINANT
		RoleClass.GRAZER_FILTER:
			return AbundanceClass.COMMON
		RoleClass.DECOMPOSER:
			return AbundanceClass.COMMON if biosphere_stage == BiosphereScaleServiceScript.Stage.MICROBIAL else AbundanceClass.LOCAL
		RoleClass.PREDATOR:
			return AbundanceClass.LOCAL
		RoleClass.PARASITE_SYMBIONT:
			return AbundanceClass.TRACE
	return AbundanceClass.TRACE


static func _microbial_mobility_for_role(role_class: int, richness_class: int) -> int:
	if role_class == RoleClass.DECOMPOSER and richness_class != NativeSpeciesServiceScript.RichnessClass.SPARSE:
		return NativeSpeciesServiceScript.MobilityClass.COLONIAL
	return NativeSpeciesServiceScript.MobilityClass.SESSILE


static func _stress_tolerance_class(planetary_state_desc: Dictionary) -> int:
	var thermal_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_THERMAL_EXTREMITY_CLASS,
		PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
	))
	var seasonality_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_SEASONALITY_CLASS,
		PlanetaryStateServiceScript.SeasonalityClass.LOW
	))
	var stability_class: int = int(planetary_state_desc.get(
		PlanetaryStateServiceScript.KEY_STABILITY_CLASS,
		PlanetaryStateServiceScript.StabilityClass.FRAGILE
	))
	if thermal_class == PlanetaryStateServiceScript.ThermalExtremityClass.EXTREME or stability_class == PlanetaryStateServiceScript.StabilityClass.FRAGILE:
		return StressToleranceClass.EXTREME_HARDY
	if thermal_class == PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN or thermal_class == PlanetaryStateServiceScript.ThermalExtremityClass.COLD:
		return StressToleranceClass.COLD_HARDY
	if thermal_class == PlanetaryStateServiceScript.ThermalExtremityClass.HOT:
		return StressToleranceClass.HEAT_HARDY
	if seasonality_class != PlanetaryStateServiceScript.SeasonalityClass.LOW:
		return StressToleranceClass.SEASONAL_DORMANT
	return StressToleranceClass.BASELINE


static func _color_family_for_metabolism(metabolism_class: int) -> int:
	match metabolism_class:
		NativeSpeciesServiceScript.MetabolismClass.PHOTOTROPHIC:
			return ColorFamily.GREEN_BLUE
		NativeSpeciesServiceScript.MetabolismClass.CHEMOTROPHIC:
			return ColorFamily.GREY_BIOLUMEN
		NativeSpeciesServiceScript.MetabolismClass.SULFUR_CHEMOSYNTHETIC:
			return ColorFamily.AMBER_RUST
		NativeSpeciesServiceScript.MetabolismClass.CRYOCHEMICAL:
			return ColorFamily.PALE_BLUE_VIOLET
	return ColorFamily.GREY_BIOLUMEN


static func _motion_style_for_mobility(mobility_class: int) -> int:
	match mobility_class:
		NativeSpeciesServiceScript.MobilityClass.SESSILE:
			return MotionStyle.ANCHORED
		NativeSpeciesServiceScript.MobilityClass.COLONIAL:
			return MotionStyle.SLOW_EXPANDING
		NativeSpeciesServiceScript.MobilityClass.MOTILE:
			return MotionStyle.DRIFTING_OR_CRAWLING
	return MotionStyle.ANCHORED


static func _default_description(id: StringName) -> Dictionary:
	return {
		KEY_BODY_ID: id,
		KEY_IS_SUPPORTED_BODY_KIND: false,
		KEY_HAS_GENETIC_SPECIES_BASIS: false,
		KEY_LIFEFORM_PROFILES: [],
		KEY_DOMINANT_LIFEFORM_ID: StringName(""),
		KEY_PROTO_FORM_SUMMARY: "",
	}
