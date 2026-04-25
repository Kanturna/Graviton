extends RefCounted


const LifePopulationEstimateServiceScript = preload("res://src/sim/life/life_population_estimate_service.gd")
const LifeEcologyServiceScript = preload("res://src/sim/life/life_ecology_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const GeneticSpeciesServiceScript = preload("res://src/sim/life/genetic_species_service.gd")


class BiosphereScaleProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


class LifeEcologyProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


static func run(ctx) -> void:
	ctx.current_suite = "test_life_population_estimate_service"
	_test_pure_helper_matches_live_describe_path(ctx)
	_test_missing_basis_non_planets_sterile_and_prebiotic_do_not_create_estimates(ctx)
	_test_microbial_complex_and_ecosystem_stage_ranges_are_pinned(ctx)
	_test_population_index_is_not_role_dampened_twice(ctx)
	_test_profile_order_and_scope_keys_are_pinned(ctx)


static func _test_pure_helper_matches_live_describe_path(ctx) -> void:
	var registry: Node = _single_body_registry(&"planet_a", BodyType.Kind.PLANET)
	var biosphere_probe := BiosphereScaleProbe.new()
	var ecology_probe := LifeEcologyProbe.new()
	biosphere_probe.desc_by_id[&"planet_a"] = _biosphere_desc(
		&"planet_a",
		BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR
	)
	ecology_probe.desc_by_id[&"planet_a"] = _ecology_desc(&"planet_a", [
		_ecology_profile(
			&"planet_a_producer",
			GeneticSpeciesServiceScript.RoleClass.PRODUCER,
			LifeEcologyServiceScript.PopulationClass.STABLE,
			0.42
		),
	])
	var service = LifePopulationEstimateServiceScript.new()
	service.configure(registry, biosphere_probe, ecology_probe)

	var live_desc: Dictionary = service.describe_body(&"planet_a")
	var pure_desc: Dictionary = LifePopulationEstimateServiceScript.evaluate_from_descriptions(
		biosphere_probe.describe_body(&"planet_a"),
		ecology_probe.describe_body(&"planet_a"),
		&"planet_a"
	)
	ctx.assert_true(
		live_desc == pure_desc,
		"LifePopulationEstimateService.evaluate_from_descriptions entspricht dem Live-describe-Pfad"
	)

	service.free()
	ecology_probe.free()
	biosphere_probe.free()
	registry.free()


static func _test_missing_basis_non_planets_sterile_and_prebiotic_do_not_create_estimates(ctx) -> void:
	var star_registry: Node = _single_body_registry(&"star_a", BodyType.Kind.STAR)
	var service = LifePopulationEstimateServiceScript.new()
	var biosphere_probe := BiosphereScaleProbe.new()
	var ecology_probe := LifeEcologyProbe.new()
	biosphere_probe.desc_by_id[&"star_a"] = _biosphere_desc(
		&"star_a",
		BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR
	)
	ecology_probe.desc_by_id[&"star_a"] = _ecology_desc(&"star_a", [
		_ecology_profile(
			&"star_a_producer",
			GeneticSpeciesServiceScript.RoleClass.PRODUCER,
			LifeEcologyServiceScript.PopulationClass.STABLE,
			0.42
		),
	])
	service.configure(star_registry, biosphere_probe, ecology_probe)
	ctx.assert_true(
		not bool(service.describe_body(&"star_a").get(LifePopulationEstimateServiceScript.KEY_HAS_POPULATION_ESTIMATE_BASIS, true)),
		"LifePopulationEstimateService ignoriert nicht-planetare Bodies"
	)

	var missing_basis_desc: Dictionary = LifePopulationEstimateServiceScript.evaluate_from_descriptions({}, {}, &"planet_a")
	ctx.assert_true(
		not bool(missing_basis_desc.get(LifePopulationEstimateServiceScript.KEY_HAS_POPULATION_ESTIMATE_BASIS, true)),
		"Fehlende Derived-Basis erzeugt keine Population-Estimate-Basis"
	)

	for stage in [
		BiosphereScaleServiceScript.Stage.STERILE,
		BiosphereScaleServiceScript.Stage.PREBIOTIC,
	]:
		var desc: Dictionary = LifePopulationEstimateServiceScript.evaluate_from_descriptions(
			_biosphere_desc(&"early_world", stage),
			_ecology_desc(&"early_world", [
				_ecology_profile(
					&"early_world_producer",
					GeneticSpeciesServiceScript.RoleClass.PRODUCER,
					LifeEcologyServiceScript.PopulationClass.STABLE,
					0.42
				),
			]),
			&"early_world"
		)
		ctx.assert_true(
			not bool(desc.get(LifePopulationEstimateServiceScript.KEY_HAS_POPULATION_ESTIMATE_BASIS, true)),
			"STERILE/PREBIOTIC erzeugen keine Estimate-Basis"
		)

	service.free()
	ecology_probe.free()
	biosphere_probe.free()
	star_registry.free()


static func _test_microbial_complex_and_ecosystem_stage_ranges_are_pinned(ctx) -> void:
	var microbial_desc: Dictionary = LifePopulationEstimateServiceScript.evaluate_from_descriptions(
		_biosphere_desc(&"microbe_world", BiosphereScaleServiceScript.Stage.MICROBIAL),
		_ecology_desc(&"microbe_world", [
			_ecology_profile(
				&"microbe_world_producer",
				GeneticSpeciesServiceScript.RoleClass.PRODUCER,
				LifeEcologyServiceScript.PopulationClass.FLOURISHING,
				1.0
			),
		]),
		&"microbe_world"
	)
	ctx.assert_true(
		_estimate_ranges(microbial_desc) == [[1_000_000_000_000, 10_000_000_000_000]],
		"MICROBIAL liest bewusst als sehr grosse mikrobielle Praesenz"
	)

	var multicellular_desc: Dictionary = LifePopulationEstimateServiceScript.evaluate_from_descriptions(
		_biosphere_desc(&"complex_world", BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR),
		_ecology_desc(&"complex_world", [
			_ecology_profile(
				&"complex_world_producer",
				GeneticSpeciesServiceScript.RoleClass.PRODUCER,
				LifeEcologyServiceScript.PopulationClass.FLOURISHING,
				1.0
			),
		]),
		&"complex_world"
	)
	ctx.assert_true(
		_estimate_ranges(multicellular_desc) == [[100_000_000, 1_000_000_000]],
		"COMPLEX_MULTICELLULAR nutzt eine niedrigere organismenartige Stage-Basis"
	)

	var ecosystem_desc: Dictionary = LifePopulationEstimateServiceScript.evaluate_from_descriptions(
		_biosphere_desc(&"ecosystem_world", BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM),
		_ecology_desc(&"ecosystem_world", [
			_ecology_profile(
				&"ecosystem_world_producer",
				GeneticSpeciesServiceScript.RoleClass.PRODUCER,
				LifeEcologyServiceScript.PopulationClass.FLOURISHING,
				1.0
			),
		]),
		&"ecosystem_world"
	)
	ctx.assert_true(
		_estimate_ranges(ecosystem_desc) == [[100_000_000, 1_000_000_000]],
		"COMPLEX_ECOSYSTEM bleibt im selben organismenartigen Magnitudenraum"
	)


static func _test_population_index_is_not_role_dampened_twice(ctx) -> void:
	var desc: Dictionary = LifePopulationEstimateServiceScript.evaluate_from_descriptions(
		_biosphere_desc(&"role_world", BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM),
		_ecology_desc(&"role_world", [
			_ecology_profile(
				&"role_world_producer",
				GeneticSpeciesServiceScript.RoleClass.PRODUCER,
				LifeEcologyServiceScript.PopulationClass.STABLE,
				0.24
			),
			_ecology_profile(
				&"role_world_predator",
				GeneticSpeciesServiceScript.RoleClass.PREDATOR,
				LifeEcologyServiceScript.PopulationClass.STABLE,
				0.24
			),
		]),
		&"role_world"
	)
	ctx.assert_true(
		_estimate_ranges(desc) == [[10_000_000, 100_000_000], [10_000_000, 100_000_000]],
		"Gleicher population_index ergibt gleiche Estimate-Range; Rollen wurden bereits in LifeEcologyService eingerechnet"
	)


static func _test_profile_order_and_scope_keys_are_pinned(ctx) -> void:
	var desc: Dictionary = LifePopulationEstimateServiceScript.evaluate_from_descriptions(
		_biosphere_desc(&"ordered_world", BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM),
		_ecology_desc(&"ordered_world", [
			_ecology_profile(
				&"ordered_world_producer",
				GeneticSpeciesServiceScript.RoleClass.PRODUCER,
				LifeEcologyServiceScript.PopulationClass.FLOURISHING,
				0.80
			),
			_ecology_profile(
				&"ordered_world_grazer_filter",
				GeneticSpeciesServiceScript.RoleClass.GRAZER_FILTER,
				LifeEcologyServiceScript.PopulationClass.STABLE,
				0.24
			),
			_ecology_profile(
				&"ordered_world_predator",
				GeneticSpeciesServiceScript.RoleClass.PREDATOR,
				LifeEcologyServiceScript.PopulationClass.EMERGING,
				0.01
			),
		]),
		&"ordered_world"
	)
	ctx.assert_true(
		_lifeform_ids(desc) == [&"ordered_world_producer", &"ordered_world_grazer_filter", &"ordered_world_predator"],
		"Population Estimates behalten exakt die Life-Ecology-Profilreihenfolge"
	)
	ctx.assert_true(
		not desc.has(&"dominant_lifeform_id"),
		"Estimate-Desc spiegelt keine Dominanz-Wahrheit aus LifeEcology/GeneticSpecies"
	)
	_assert_no_event_or_state_scope_keys(ctx, desc)

	var zero_desc: Dictionary = LifePopulationEstimateServiceScript.evaluate_from_descriptions(
		_biosphere_desc(&"zero_world", BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM),
		_ecology_desc(&"zero_world", [
			_ecology_profile(
				&"zero_world_producer",
				GeneticSpeciesServiceScript.RoleClass.PRODUCER,
				LifeEcologyServiceScript.PopulationClass.NONE,
				0.0
			),
		]),
		&"zero_world"
	)
	ctx.assert_true(
		not bool(zero_desc.get(LifePopulationEstimateServiceScript.KEY_HAS_POPULATION_ESTIMATE_BASIS, true)),
		"Wenn alle Profile 0..0 waeren, setzt der Service keine Estimate-Basis"
	)


static func _biosphere_desc(id: StringName, stage: int) -> Dictionary:
	return {
		BiosphereScaleServiceScript.KEY_BODY_ID: id,
		BiosphereScaleServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: stage,
	}


static func _ecology_desc(id: StringName, profiles: Array, has_ecology_basis: bool = true) -> Dictionary:
	return {
		LifeEcologyServiceScript.KEY_BODY_ID: id,
		LifeEcologyServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		LifeEcologyServiceScript.KEY_HAS_LIFE_ECOLOGY_BASIS: has_ecology_basis,
		LifeEcologyServiceScript.KEY_POPULATION_PROFILES: profiles,
	}


static func _ecology_profile(
		lifeform_id: StringName,
		role_class: int,
		population_class: int,
		population_index: float
	) -> Dictionary:
	return {
		LifeEcologyServiceScript.KEY_LIFEFORM_ID: lifeform_id,
		LifeEcologyServiceScript.KEY_ROLE_CLASS: role_class,
		LifeEcologyServiceScript.KEY_POPULATION_CLASS: population_class,
		LifeEcologyServiceScript.KEY_POPULATION_INDEX: population_index,
	}


static func _estimate_ranges(population_estimate_desc: Dictionary) -> Array:
	var out: Array = []
	var profiles: Array = population_estimate_desc.get(
		LifePopulationEstimateServiceScript.KEY_POPULATION_ESTIMATE_PROFILES,
		[]
	)
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		out.append([
			int(profile.get(LifePopulationEstimateServiceScript.KEY_ESTIMATE_MIN, 0)),
			int(profile.get(LifePopulationEstimateServiceScript.KEY_ESTIMATE_MAX, 0)),
		])
	return out


static func _lifeform_ids(population_estimate_desc: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var profiles: Array = population_estimate_desc.get(
		LifePopulationEstimateServiceScript.KEY_POPULATION_ESTIMATE_PROFILES,
		[]
	)
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		out.append(StringName(profile.get(
			LifePopulationEstimateServiceScript.KEY_LIFEFORM_ID,
			StringName("")
		)))
	return out


static func _assert_no_event_or_state_scope_keys(ctx, population_estimate_desc: Dictionary) -> void:
	for key in [
		&"population_state",
		&"settlement_state",
		&"war_state",
		&"catastrophe_state",
		&"civilization_state",
	]:
		ctx.assert_true(not population_estimate_desc.has(key), "Population-Estimate-Desc fuehrt keinen Scope-Creep-Key %s ein" % [String(key)])
	var profiles: Array = population_estimate_desc.get(
		LifePopulationEstimateServiceScript.KEY_POPULATION_ESTIMATE_PROFILES,
		[]
	)
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		for key in [
			&"population_state",
			&"settlement_state",
			&"war_state",
			&"catastrophe_state",
			&"civilization_state",
		]:
			ctx.assert_true(not profile.has(key), "Population-Estimate-Profil fuehrt keinen Scope-Creep-Key %s ein" % [String(key)])


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
