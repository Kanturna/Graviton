extends RefCounted


const LifeEcologyServiceScript = preload("res://src/sim/life/life_ecology_service.gd")
const GeneticSpeciesServiceScript = preload("res://src/sim/life/genetic_species_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")


class BiosphereScaleProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


class GeneticSpeciesProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


static func run(ctx) -> void:
	ctx.current_suite = "test_life_ecology_service"
	_test_pure_helper_matches_live_describe_path(ctx)
	_test_missing_basis_non_planets_sterile_and_prebiotic_do_not_create_population_profiles(ctx)
	_test_microbial_profiles_create_qualitative_population_while_species_can_stay_na(ctx)
	_test_complex_profile_order_co_dominance_and_role_scaling_are_pinned(ctx)
	_test_pressure_dampens_population_index_and_count_scope_keys_do_not_appear(ctx)


static func _test_pure_helper_matches_live_describe_path(ctx) -> void:
	var registry: Node = _single_body_registry(&"planet_a", BodyType.Kind.PLANET)
	var biosphere_probe := BiosphereScaleProbe.new()
	var genetic_probe := GeneticSpeciesProbe.new()
	biosphere_probe.desc_by_id[&"planet_a"] = _biosphere_desc(
		&"planet_a",
		BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
		0.80
	)
	genetic_probe.desc_by_id[&"planet_a"] = _genetic_desc(&"planet_a", [
		_genetic_profile(
			&"planet_a_producer",
			GeneticSpeciesServiceScript.RoleClass.PRODUCER,
			GeneticSpeciesServiceScript.AbundanceClass.DOMINANT,
			GeneticSpeciesServiceScript.SelectionPressureClass.LOW
		),
	])
	var service = LifeEcologyServiceScript.new()
	service.configure(registry, biosphere_probe, genetic_probe)

	var live_desc: Dictionary = service.describe_body(&"planet_a")
	var pure_desc: Dictionary = LifeEcologyServiceScript.evaluate_from_descriptions(
		biosphere_probe.describe_body(&"planet_a"),
		genetic_probe.describe_body(&"planet_a"),
		&"planet_a"
	)
	ctx.assert_true(
		live_desc == pure_desc,
		"LifeEcologyService.evaluate_from_descriptions liefert fuer dieselben Inputs denselben Desc wie describe_body"
	)

	service.free()
	genetic_probe.free()
	biosphere_probe.free()
	registry.free()


static func _test_missing_basis_non_planets_sterile_and_prebiotic_do_not_create_population_profiles(ctx) -> void:
	var star_registry: Node = _single_body_registry(&"star_a", BodyType.Kind.STAR)
	var service = LifeEcologyServiceScript.new()
	var biosphere_probe := BiosphereScaleProbe.new()
	var genetic_probe := GeneticSpeciesProbe.new()
	biosphere_probe.desc_by_id[&"star_a"] = _biosphere_desc(
		&"star_a",
		BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
		0.80
	)
	genetic_probe.desc_by_id[&"star_a"] = _genetic_desc(&"star_a", [
		_genetic_profile(
			&"star_a_producer",
			GeneticSpeciesServiceScript.RoleClass.PRODUCER,
			GeneticSpeciesServiceScript.AbundanceClass.DOMINANT,
			GeneticSpeciesServiceScript.SelectionPressureClass.LOW
		),
	])
	service.configure(star_registry, biosphere_probe, genetic_probe)
	ctx.assert_true(
		not bool(service.describe_body(&"star_a").get(LifeEcologyServiceScript.KEY_HAS_LIFE_ECOLOGY_BASIS, true)),
		"LifeEcologyService ignoriert nicht-planetare Bodies auch bei scheinbar gueltigen Desc-Inputs"
	)

	var missing_basis_desc: Dictionary = LifeEcologyServiceScript.evaluate_from_descriptions({}, {}, &"planet_a")
	ctx.assert_true(
		not bool(missing_basis_desc.get(LifeEcologyServiceScript.KEY_HAS_LIFE_ECOLOGY_BASIS, true)),
		"Fehlende Derived-Basis erzeugt keine Life-Ecology-Basis"
	)

	for stage in [
		BiosphereScaleServiceScript.Stage.STERILE,
		BiosphereScaleServiceScript.Stage.PREBIOTIC,
	]:
		var desc: Dictionary = LifeEcologyServiceScript.evaluate_from_descriptions(
			_biosphere_desc(&"early_world", stage, 0.0),
			_genetic_desc(&"early_world", [], stage == BiosphereScaleServiceScript.Stage.PREBIOTIC),
			&"early_world"
		)
		ctx.assert_true(
			not bool(desc.get(LifeEcologyServiceScript.KEY_HAS_LIFE_ECOLOGY_BASIS, true)),
			"STERILE/PREBIOTIC erzeugen keine stabile Population-Basis"
		)
		ctx.assert_true(
			Array(desc.get(LifeEcologyServiceScript.KEY_POPULATION_PROFILES, [])).is_empty(),
			"STERILE/PREBIOTIC erzeugen keine Population-Profile"
		)

	service.free()
	genetic_probe.free()
	biosphere_probe.free()
	star_registry.free()


static func _test_microbial_profiles_create_qualitative_population_while_species_can_stay_na(ctx) -> void:
	var desc: Dictionary = LifeEcologyServiceScript.evaluate_from_descriptions(
		_biosphere_desc(&"microbe_world", BiosphereScaleServiceScript.Stage.MICROBIAL, 0.35),
		_genetic_desc(&"microbe_world", [
			_genetic_profile(
				&"microbe_world_producer",
				GeneticSpeciesServiceScript.RoleClass.PRODUCER,
				GeneticSpeciesServiceScript.AbundanceClass.DOMINANT,
				GeneticSpeciesServiceScript.SelectionPressureClass.LOW
			),
			_genetic_profile(
				&"microbe_world_decomposer",
				GeneticSpeciesServiceScript.RoleClass.DECOMPOSER,
				GeneticSpeciesServiceScript.AbundanceClass.COMMON,
				GeneticSpeciesServiceScript.SelectionPressureClass.LOW
			),
		]),
		&"microbe_world"
	)
	ctx.assert_true(
		bool(desc.get(LifeEcologyServiceScript.KEY_HAS_LIFE_ECOLOGY_BASIS, false)),
		"MICROBIAL darf qualitative Population-Profile aus Genetic-Profilen erzeugen"
	)
	ctx.assert_true(
		_population_classes(desc) == [
			LifeEcologyServiceScript.PopulationClass.STABLE,
			LifeEcologyServiceScript.PopulationClass.SPARSE,
		],
		"MICROBIAL Producer/Decomposer werden deterministisch auf STABLE/SPARSE gemappt"
	)
	_assert_no_count_or_event_scope_keys(ctx, desc)


static func _test_complex_profile_order_co_dominance_and_role_scaling_are_pinned(ctx) -> void:
	var desc: Dictionary = LifeEcologyServiceScript.evaluate_from_descriptions(
		_biosphere_desc(&"ecosystem_world", BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM, 0.80),
		_genetic_desc(&"ecosystem_world", [
			_genetic_profile(
				&"ecosystem_world_producer",
				GeneticSpeciesServiceScript.RoleClass.PRODUCER,
				GeneticSpeciesServiceScript.AbundanceClass.DOMINANT,
				GeneticSpeciesServiceScript.SelectionPressureClass.MODERATE
			),
			_genetic_profile(
				&"ecosystem_world_grazer_filter",
				GeneticSpeciesServiceScript.RoleClass.GRAZER_FILTER,
				GeneticSpeciesServiceScript.AbundanceClass.DOMINANT,
				GeneticSpeciesServiceScript.SelectionPressureClass.MODERATE
			),
			_genetic_profile(
				&"ecosystem_world_decomposer",
				GeneticSpeciesServiceScript.RoleClass.DECOMPOSER,
				GeneticSpeciesServiceScript.AbundanceClass.LOCAL,
				GeneticSpeciesServiceScript.SelectionPressureClass.MODERATE
			),
			_genetic_profile(
				&"ecosystem_world_predator",
				GeneticSpeciesServiceScript.RoleClass.PREDATOR,
				GeneticSpeciesServiceScript.AbundanceClass.LOCAL,
				GeneticSpeciesServiceScript.SelectionPressureClass.EXTREME
			),
			_genetic_profile(
				&"ecosystem_world_parasite_symbiont",
				GeneticSpeciesServiceScript.RoleClass.PARASITE_SYMBIONT,
				GeneticSpeciesServiceScript.AbundanceClass.TRACE,
				GeneticSpeciesServiceScript.SelectionPressureClass.EXTREME
			),
		]),
		&"ecosystem_world"
	)
	ctx.assert_true(
		_role_classes(desc) == [
			GeneticSpeciesServiceScript.RoleClass.PRODUCER,
			GeneticSpeciesServiceScript.RoleClass.GRAZER_FILTER,
			GeneticSpeciesServiceScript.RoleClass.DECOMPOSER,
			GeneticSpeciesServiceScript.RoleClass.PREDATOR,
			GeneticSpeciesServiceScript.RoleClass.PARASITE_SYMBIONT,
		],
		"Life-Ecology behaelt die Genetic-Profil-Reihenfolge fuer direkte Lesbarkeit neben Native forms"
	)
	ctx.assert_true(
		_population_classes(desc) == [
			LifeEcologyServiceScript.PopulationClass.FLOURISHING,
			LifeEcologyServiceScript.PopulationClass.STABLE,
			LifeEcologyServiceScript.PopulationClass.SPARSE,
			LifeEcologyServiceScript.PopulationClass.EMERGING,
			LifeEcologyServiceScript.PopulationClass.EMERGING,
		],
		"Role-Faktoren skalieren komplexe Oekosysteme deterministisch von Producer bis Predator/Parasite"
	)
	ctx.assert_true(
		StringName(desc.get(LifeEcologyServiceScript.KEY_DOMINANT_LIFEFORM_ID, StringName("")))
			== &"ecosystem_world_producer",
		"Dominant-Lifeform-ID bleibt aus GeneticSpeciesService uebernommen"
	)


static func _test_pressure_dampens_population_index_and_count_scope_keys_do_not_appear(ctx) -> void:
	var low_pressure_desc: Dictionary = LifeEcologyServiceScript.evaluate_from_descriptions(
		_biosphere_desc(&"pressure_world", BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR, 0.80),
		_genetic_desc(&"pressure_world", [
			_genetic_profile(
				&"pressure_world_producer",
				GeneticSpeciesServiceScript.RoleClass.PRODUCER,
				GeneticSpeciesServiceScript.AbundanceClass.DOMINANT,
				GeneticSpeciesServiceScript.SelectionPressureClass.LOW
			),
		]),
		&"pressure_world"
	)
	var extreme_pressure_desc: Dictionary = LifeEcologyServiceScript.evaluate_from_descriptions(
		_biosphere_desc(&"pressure_world", BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR, 0.80),
		_genetic_desc(&"pressure_world", [
			_genetic_profile(
				&"pressure_world_producer",
				GeneticSpeciesServiceScript.RoleClass.PRODUCER,
				GeneticSpeciesServiceScript.AbundanceClass.DOMINANT,
				GeneticSpeciesServiceScript.SelectionPressureClass.EXTREME
			),
		]),
		&"pressure_world"
	)
	ctx.assert_true(
		_population_index(extreme_pressure_desc, 0) < _population_index(low_pressure_desc, 0),
		"Selection Pressure daempft den normalisierten Population-Index deterministisch"
	)

	var role_factor_desc: Dictionary = LifeEcologyServiceScript.evaluate_from_descriptions(
		_biosphere_desc(&"role_world", BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM, 0.80),
		_genetic_desc(&"role_world", [
			_genetic_profile(
				&"role_world_producer",
				GeneticSpeciesServiceScript.RoleClass.PRODUCER,
				GeneticSpeciesServiceScript.AbundanceClass.DOMINANT,
				GeneticSpeciesServiceScript.SelectionPressureClass.LOW
			),
			_genetic_profile(
				&"role_world_predator",
				GeneticSpeciesServiceScript.RoleClass.PREDATOR,
				GeneticSpeciesServiceScript.AbundanceClass.DOMINANT,
				GeneticSpeciesServiceScript.SelectionPressureClass.LOW
			),
		]),
		&"role_world"
	)
	ctx.assert_true(
		_population_index(role_factor_desc, 1) < _population_index(role_factor_desc, 0),
		"Predator-Profile bleiben bei gleicher Biomasse/Abundance niedriger skaliert als Producer"
	)
	_assert_no_count_or_event_scope_keys(ctx, role_factor_desc)


static func _biosphere_desc(id: StringName, stage: int, dominant_biomass_index: float) -> Dictionary:
	return {
		BiosphereScaleServiceScript.KEY_BODY_ID: id,
		BiosphereScaleServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: stage,
		BiosphereScaleServiceScript.KEY_DOMINANT_BIOMASS_INDEX: dominant_biomass_index,
	}


static func _genetic_desc(
		id: StringName,
		profiles: Array,
		has_genetic_basis: bool = true
	) -> Dictionary:
	return {
		GeneticSpeciesServiceScript.KEY_BODY_ID: id,
		GeneticSpeciesServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		GeneticSpeciesServiceScript.KEY_HAS_GENETIC_SPECIES_BASIS: has_genetic_basis,
		GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES: profiles,
		GeneticSpeciesServiceScript.KEY_DOMINANT_LIFEFORM_ID: StringName("") if profiles.is_empty() else profiles[0].get(
			GeneticSpeciesServiceScript.KEY_LIFEFORM_ID,
			StringName("")
		),
	}


static func _genetic_profile(
		lifeform_id: StringName,
		role_class: int,
		abundance_class: int,
		selection_pressure_class: int
	) -> Dictionary:
	return {
		GeneticSpeciesServiceScript.KEY_LIFEFORM_ID: lifeform_id,
		GeneticSpeciesServiceScript.KEY_ROLE_CLASS: role_class,
		GeneticSpeciesServiceScript.KEY_ABUNDANCE_CLASS: abundance_class,
		GeneticSpeciesServiceScript.KEY_SELECTION_PRESSURE_CLASS: selection_pressure_class,
	}


static func _role_classes(life_ecology_desc: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var profiles: Array = life_ecology_desc.get(
		LifeEcologyServiceScript.KEY_POPULATION_PROFILES,
		[]
	)
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		out.append(int(profile.get(
			LifeEcologyServiceScript.KEY_ROLE_CLASS,
			GeneticSpeciesServiceScript.RoleClass.PRODUCER
		)))
	return out


static func _population_classes(life_ecology_desc: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var profiles: Array = life_ecology_desc.get(
		LifeEcologyServiceScript.KEY_POPULATION_PROFILES,
		[]
	)
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		out.append(int(profile.get(
			LifeEcologyServiceScript.KEY_POPULATION_CLASS,
			LifeEcologyServiceScript.PopulationClass.NONE
		)))
	return out


static func _population_index(life_ecology_desc: Dictionary, index: int) -> float:
	var profiles: Array = life_ecology_desc.get(
		LifeEcologyServiceScript.KEY_POPULATION_PROFILES,
		[]
	)
	if index < 0 or index >= profiles.size():
		return 0.0
	var profile: Dictionary = profiles[index]
	return float(profile.get(LifeEcologyServiceScript.KEY_POPULATION_INDEX, 0.0))


static func _assert_no_count_or_event_scope_keys(ctx, life_ecology_desc: Dictionary) -> void:
	for key in [
		&"count_estimate_basis",
		&"count_estimate_range",
		&"war_state",
		&"catastrophe_state",
		&"civilization_state",
	]:
		ctx.assert_true(not life_ecology_desc.has(key), "Life-Ecology-Desc fuehrt keinen Scope-Creep-Key %s ein" % [String(key)])
	var profiles: Array = life_ecology_desc.get(
		LifeEcologyServiceScript.KEY_POPULATION_PROFILES,
		[]
	)
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		for key in [
			&"count_estimate",
			&"count_range",
			&"war_state",
			&"catastrophe_state",
			&"civilization_state",
		]:
			ctx.assert_true(not profile.has(key), "Population-Profil fuehrt keinen Scope-Creep-Key %s ein" % [String(key)])


static func _single_body_registry(id: StringName, kind: int) -> Node:
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var def := BodyDef.new()
	def.id = id
	def.display_name = String(id)
	def.kind = kind
	def.mass_kg = 1.0
	def.radius_m = 1.0
	def.parent_id = StringName("")
	registry.register_body(def)
	return registry
