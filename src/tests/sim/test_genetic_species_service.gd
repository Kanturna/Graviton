extends RefCounted


const GeneticSpeciesServiceScript = preload("res://src/sim/life/genetic_species_service.gd")
const NativeSpeciesServiceScript = preload("res://src/sim/life/native_species_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")


class PlanetaryStateProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


class LifePotentialProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


class BiosphereScaleProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


class NativeSpeciesProbe:
	extends Node

	var desc_by_id: Dictionary = {}

	func describe_body(id: StringName) -> Dictionary:
		return desc_by_id.get(id, {})


static func run(ctx) -> void:
	ctx.current_suite = "test_genetic_species_service"
	_test_pure_helper_matches_live_describe_path(ctx)
	_test_missing_basis_and_non_planets_do_not_create_profiles(ctx)
	_test_prebiotic_creates_only_proto_summary(ctx)
	_test_microbial_profiles_without_native_species_basis(ctx)
	_test_complex_profile_count_order_and_dominance_are_pinned(ctx)
	_test_track_stress_and_visual_mappings_are_pinned(ctx)


static func _test_pure_helper_matches_live_describe_path(ctx) -> void:
	var registry: Node = _single_body_registry(&"planet_a", BodyType.Kind.PLANET)
	var planetary_state_probe := PlanetaryStateProbe.new()
	var life_potential_probe := LifePotentialProbe.new()
	var biosphere_scale_probe := BiosphereScaleProbe.new()
	var native_species_probe := NativeSpeciesProbe.new()
	planetary_state_probe.desc_by_id[&"planet_a"] = _sampled_planetary_state_desc(&"planet_a")
	life_potential_probe.desc_by_id[&"planet_a"] = _life_potential_desc(&"planet_a", LifePotentialServiceScript.Track.WATER_CARBON)
	biosphere_scale_probe.desc_by_id[&"planet_a"] = _biosphere_scale_desc(
		&"planet_a",
		BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
		LifePotentialServiceScript.Track.WATER_CARBON,
		0.80,
		PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
	)
	native_species_probe.desc_by_id[&"planet_a"] = _native_species_desc(
		&"planet_a",
		NativeSpeciesServiceScript.RichnessClass.DIVERSE,
		NativeSpeciesServiceScript.MetabolismClass.PHOTOTROPHIC,
		NativeSpeciesServiceScript.HabitatClass.TEMPERATE_SURFACE,
		NativeSpeciesServiceScript.MobilityClass.COLONIAL
	)
	var service = GeneticSpeciesServiceScript.new()
	service.configure(registry, planetary_state_probe, life_potential_probe, biosphere_scale_probe, native_species_probe)

	var live_desc: Dictionary = service.describe_body(&"planet_a")
	var pure_desc: Dictionary = GeneticSpeciesServiceScript.evaluate_from_descriptions(
		planetary_state_probe.describe_body(&"planet_a"),
		life_potential_probe.describe_body(&"planet_a"),
		biosphere_scale_probe.describe_body(&"planet_a"),
		native_species_probe.describe_body(&"planet_a"),
		&"planet_a"
	)

	ctx.assert_true(
		live_desc == pure_desc,
		"GeneticSpeciesService.evaluate_from_descriptions liefert fuer dieselben Inputs denselben Desc wie describe_body"
	)

	service.free()
	native_species_probe.free()
	biosphere_scale_probe.free()
	life_potential_probe.free()
	planetary_state_probe.free()
	registry.free()


static func _test_missing_basis_and_non_planets_do_not_create_profiles(ctx) -> void:
	var star_registry: Node = _single_body_registry(&"star_a", BodyType.Kind.STAR)
	var service = GeneticSpeciesServiceScript.new()
	var planetary_state_probe := PlanetaryStateProbe.new()
	var life_potential_probe := LifePotentialProbe.new()
	var biosphere_scale_probe := BiosphereScaleProbe.new()
	var native_species_probe := NativeSpeciesProbe.new()
	service.configure(star_registry, planetary_state_probe, life_potential_probe, biosphere_scale_probe, native_species_probe)
	var star_desc: Dictionary = service.describe_body(&"star_a")
	ctx.assert_true(
		not bool(star_desc.get(GeneticSpeciesServiceScript.KEY_HAS_GENETIC_SPECIES_BASIS, true)),
		"GeneticSpeciesService ignoriert nicht-planetare Bodies"
	)

	var missing_basis_desc: Dictionary = GeneticSpeciesServiceScript.evaluate_from_descriptions({}, {}, {}, {}, &"planet_a")
	ctx.assert_true(
		not bool(missing_basis_desc.get(GeneticSpeciesServiceScript.KEY_HAS_GENETIC_SPECIES_BASIS, true)),
		"Fehlende Derived-Basis erzeugt keine Genetic-Species-Basis"
	)

	service.free()
	native_species_probe.free()
	biosphere_scale_probe.free()
	life_potential_probe.free()
	planetary_state_probe.free()
	star_registry.free()


static func _test_prebiotic_creates_only_proto_summary(ctx) -> void:
	var desc: Dictionary = GeneticSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(&"gamma_iv"),
		_life_potential_desc(&"gamma_iv", LifePotentialServiceScript.Track.WATER_CARBON),
		_biosphere_scale_desc(
			&"gamma_iv",
			BiosphereScaleServiceScript.Stage.PREBIOTIC,
			LifePotentialServiceScript.Track.WATER_CARBON,
			0.70,
			PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
		),
		{},
		&"gamma_iv"
	)
	ctx.assert_true(
		bool(desc.get(GeneticSpeciesServiceScript.KEY_HAS_GENETIC_SPECIES_BASIS, false)),
		"PREBIOTIC hat eine Genetic-Species-Basis fuer Proto-/Precursor-Readouts"
	)
	ctx.assert_true(
		Array(desc.get(GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES, [])).is_empty(),
		"PREBIOTIC erzeugt keine stabilen Lifeform-Profile"
	)
	ctx.assert_true(
		String(desc.get(GeneticSpeciesServiceScript.KEY_PROTO_FORM_SUMMARY, ""))
			== GeneticSpeciesServiceScript.PROTO_FORM_CHEMICAL_PRECURSORS,
		"PREBIOTIC rendert nur den stabilen Proto-Form-Summary"
	)


static func _test_microbial_profiles_without_native_species_basis(ctx) -> void:
	var native_species_desc: Dictionary = NativeSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(&"microbe_world"),
		_life_potential_desc(&"microbe_world", LifePotentialServiceScript.Track.WATER_CARBON),
		_biosphere_scale_desc(
			&"microbe_world",
			BiosphereScaleServiceScript.Stage.MICROBIAL,
			LifePotentialServiceScript.Track.WATER_CARBON,
			0.80,
			PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
		),
		&"microbe_world"
	)
	ctx.assert_true(
		not bool(native_species_desc.get(NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS, true)),
		"MICROBIAL behaelt im bestehenden NativeSpeciesService bewusst Species: n/a"
	)

	var desc: Dictionary = GeneticSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(&"microbe_world"),
		_life_potential_desc(&"microbe_world", LifePotentialServiceScript.Track.WATER_CARBON),
		_biosphere_scale_desc(
			&"microbe_world",
			BiosphereScaleServiceScript.Stage.MICROBIAL,
			LifePotentialServiceScript.Track.WATER_CARBON,
			0.80,
			PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
		),
		native_species_desc,
		&"microbe_world"
	)
	ctx.assert_true(
		_role_classes(desc) == [
			GeneticSpeciesServiceScript.RoleClass.PRODUCER,
			GeneticSpeciesServiceScript.RoleClass.DECOMPOSER,
		],
		"MICROBIAL mit DIVERSE-Carrying-Capacity erzeugt PRODUCER plus DECOMPOSER"
	)
	ctx.assert_true(
		_selection_pressure_classes(desc) == [
			GeneticSpeciesServiceScript.SelectionPressureClass.LOW,
			GeneticSpeciesServiceScript.SelectionPressureClass.LOW,
		],
		"MICROBIAL-Profile tragen deterministische Selection-Pressure ohne Native-Species-Basis"
	)
	_assert_no_redundant_scope_keys(ctx, desc)
	var sulfur_desc: Dictionary = _microbial_desc_without_native_basis(
		&"sulfur_microbe",
		LifePotentialServiceScript.Track.SULFUR_REACTIVE,
		PlanetaryStateServiceScript.ThermalExtremityClass.HOT
	)
	var sulfur_trait_loci: Dictionary = _dominant_trait_loci(sulfur_desc)
	var sulfur_visual_profile: Dictionary = _dominant_visual_profile(sulfur_desc)
	ctx.assert_true(
		int(sulfur_trait_loci.get(GeneticSpeciesServiceScript.KEY_METABOLISM_LOCUS, -1))
			== NativeSpeciesServiceScript.MetabolismClass.SULFUR_CHEMOSYNTHETIC,
		"MICROBIAL ohne Native-Species-Basis leitet SULFUR-Reactive-Metabolism aus Track/Thermik ab"
	)
	ctx.assert_true(
		int(sulfur_trait_loci.get(GeneticSpeciesServiceScript.KEY_HABITAT_LOCUS, -1))
			== NativeSpeciesServiceScript.HabitatClass.VENT_SURFACE,
		"MICROBIAL SULFUR/HOT faellt nicht auf den NativeSpecies-Default-Habitat zurueck"
	)
	ctx.assert_true(
		int(sulfur_visual_profile.get(GeneticSpeciesServiceScript.KEY_VISUAL_COLOR_FAMILY, -1))
			== GeneticSpeciesServiceScript.ColorFamily.AMBER_RUST,
		"MICROBIAL SULFUR/HOT rendert AMBER_RUST statt Default-GREY_BIOLUMEN"
	)
	ctx.assert_true(
		_selection_pressure_classes(sulfur_desc) == [
			GeneticSpeciesServiceScript.SelectionPressureClass.MODERATE,
			GeneticSpeciesServiceScript.SelectionPressureClass.MODERATE,
		],
		"MICROBIAL SULFUR/HOT liest als moderater Selection Pressure"
	)

	var cryogenic_desc: Dictionary = _microbial_desc_without_native_basis(
		&"cryo_microbe",
		LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
		PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
	)
	var cryogenic_trait_loci: Dictionary = _dominant_trait_loci(cryogenic_desc)
	var cryogenic_visual_profile: Dictionary = _dominant_visual_profile(cryogenic_desc)
	ctx.assert_true(
		int(cryogenic_trait_loci.get(GeneticSpeciesServiceScript.KEY_METABOLISM_LOCUS, -1))
			== NativeSpeciesServiceScript.MetabolismClass.CRYOCHEMICAL,
		"MICROBIAL ohne Native-Species-Basis leitet CRYOCHEMICAL aus Track/Thermik ab"
	)
	ctx.assert_true(
		int(cryogenic_trait_loci.get(GeneticSpeciesServiceScript.KEY_HABITAT_LOCUS, -1))
			== NativeSpeciesServiceScript.HabitatClass.CRYO_SURFACE,
		"MICROBIAL CRYOGENIC/FROZEN faellt nicht auf den NativeSpecies-Default-Habitat zurueck"
	)
	ctx.assert_true(
		int(cryogenic_visual_profile.get(GeneticSpeciesServiceScript.KEY_VISUAL_COLOR_FAMILY, -1))
			== GeneticSpeciesServiceScript.ColorFamily.PALE_BLUE_VIOLET,
		"MICROBIAL CRYOGENIC/FROZEN rendert PALE_BLUE_VIOLET statt Default-GREY_BIOLUMEN"
	)


static func _test_complex_profile_count_order_and_dominance_are_pinned(ctx) -> void:
	var sparse_desc: Dictionary = _complex_desc_for_richness(NativeSpeciesServiceScript.RichnessClass.SPARSE)
	ctx.assert_true(
		_role_classes(sparse_desc) == [GeneticSpeciesServiceScript.RoleClass.PRODUCER],
		"COMPLEX_MULTICELLULAR SPARSE erzeugt genau PRODUCER"
	)

	var patchy_desc: Dictionary = _complex_desc_for_richness(NativeSpeciesServiceScript.RichnessClass.PATCHY)
	ctx.assert_true(
		_role_classes(patchy_desc) == [
			GeneticSpeciesServiceScript.RoleClass.PRODUCER,
			GeneticSpeciesServiceScript.RoleClass.GRAZER_FILTER,
		],
		"COMPLEX_MULTICELLULAR PATCHY erzeugt PRODUCER plus GRAZER_FILTER"
	)

	var ecosystem_desc: Dictionary = GeneticSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(
			&"ecosystem_world",
			PlanetaryStateServiceScript.ThermalExtremityClass.COLD,
			PlanetaryStateServiceScript.SeasonalityClass.SEASONAL,
			PlanetaryStateServiceScript.StabilityClass.STABLE
		),
		_life_potential_desc(&"ecosystem_world", LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT),
		_biosphere_scale_desc(
			&"ecosystem_world",
			BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM,
			LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
			0.90,
			PlanetaryStateServiceScript.ThermalExtremityClass.COLD
		),
		_native_species_desc(
			&"ecosystem_world",
			NativeSpeciesServiceScript.RichnessClass.DIVERSE,
			NativeSpeciesServiceScript.MetabolismClass.CRYOCHEMICAL,
			NativeSpeciesServiceScript.HabitatClass.CRYO_SURFACE,
			NativeSpeciesServiceScript.MobilityClass.MOTILE
		),
		&"ecosystem_world"
	)
	ctx.assert_true(
		_role_classes(ecosystem_desc) == [
			GeneticSpeciesServiceScript.RoleClass.PRODUCER,
			GeneticSpeciesServiceScript.RoleClass.GRAZER_FILTER,
			GeneticSpeciesServiceScript.RoleClass.DECOMPOSER,
			GeneticSpeciesServiceScript.RoleClass.PREDATOR,
			GeneticSpeciesServiceScript.RoleClass.PARASITE_SYMBIONT,
		],
		"COMPLEX_ECOSYSTEM DIVERSE plus Stress erzeugt die volle v1-Rollenliste in stabiler Reihenfolge"
	)
	ctx.assert_true(
		_abundance_classes(ecosystem_desc) == [
			GeneticSpeciesServiceScript.AbundanceClass.DOMINANT,
			GeneticSpeciesServiceScript.AbundanceClass.DOMINANT,
			GeneticSpeciesServiceScript.AbundanceClass.LOCAL,
			GeneticSpeciesServiceScript.AbundanceClass.LOCAL,
			GeneticSpeciesServiceScript.AbundanceClass.TRACE,
		],
		"COMPLEX_ECOSYSTEM DIVERSE erlaubt PRODUCER und GRAZER_FILTER als Co-Dominants"
	)
	ctx.assert_true(
		_selection_pressure_classes(ecosystem_desc) == [
			GeneticSpeciesServiceScript.SelectionPressureClass.MODERATE,
			GeneticSpeciesServiceScript.SelectionPressureClass.MODERATE,
			GeneticSpeciesServiceScript.SelectionPressureClass.MODERATE,
			GeneticSpeciesServiceScript.SelectionPressureClass.EXTREME,
			GeneticSpeciesServiceScript.SelectionPressureClass.EXTREME,
		],
		"Abhaengige lokale Rollen in diversen Ecosystems steigen bis EXTREME, stabile Co-Dominants bleiben moderat"
	)
	ctx.assert_true(
		StringName(ecosystem_desc.get(GeneticSpeciesServiceScript.KEY_DOMINANT_LIFEFORM_ID, StringName("")))
			== &"ecosystem_world_producer",
		"Das erste sortierte Profil ist deterministisch der dominante Lifeform-Eintrag"
	)
	_assert_no_redundant_scope_keys(ctx, ecosystem_desc)


static func _test_track_stress_and_visual_mappings_are_pinned(ctx) -> void:
	var sulfur_desc: Dictionary = GeneticSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(
			&"sulfur_world",
			PlanetaryStateServiceScript.ThermalExtremityClass.HOT,
			PlanetaryStateServiceScript.SeasonalityClass.LOW,
			PlanetaryStateServiceScript.StabilityClass.STABLE
		),
		_life_potential_desc(&"sulfur_world", LifePotentialServiceScript.Track.SULFUR_REACTIVE),
		_biosphere_scale_desc(
			&"sulfur_world",
			BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
			LifePotentialServiceScript.Track.SULFUR_REACTIVE,
			0.80,
			PlanetaryStateServiceScript.ThermalExtremityClass.HOT
		),
		_native_species_desc(
			&"sulfur_world",
			NativeSpeciesServiceScript.RichnessClass.DIVERSE,
			NativeSpeciesServiceScript.MetabolismClass.SULFUR_CHEMOSYNTHETIC,
			NativeSpeciesServiceScript.HabitatClass.VENT_SURFACE,
			NativeSpeciesServiceScript.MobilityClass.COLONIAL
		),
		&"sulfur_world"
	)
	var dominant_profile: Dictionary = Array(sulfur_desc.get(
		GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES,
		[]
	))[0]
	var trait_loci: Dictionary = dominant_profile.get(GeneticSpeciesServiceScript.KEY_TRAIT_LOCI, {})
	var visual_profile: Dictionary = dominant_profile.get(GeneticSpeciesServiceScript.KEY_VISUAL_PROFILE, {})
	ctx.assert_true(
		int(trait_loci.get(GeneticSpeciesServiceScript.KEY_STRESS_TOLERANCE_LOCUS, -1))
			== GeneticSpeciesServiceScript.StressToleranceClass.HEAT_HARDY,
		"HOT-Thermik mappt auf HEAT_HARDY"
	)
	ctx.assert_true(
		int(visual_profile.get(GeneticSpeciesServiceScript.KEY_VISUAL_COLOR_FAMILY, -1))
			== GeneticSpeciesServiceScript.ColorFamily.AMBER_RUST,
		"SULFUR_CHEMOSYNTHETIC mappt auf AMBER_RUST"
	)
	ctx.assert_true(
		int(visual_profile.get(GeneticSpeciesServiceScript.KEY_VISUAL_MOTION_STYLE, -1))
			== GeneticSpeciesServiceScript.MotionStyle.SLOW_EXPANDING,
		"COLONIAL-Mobility mappt auf SLOW_EXPANDING"
	)
	ctx.assert_true(
		int(dominant_profile.get(GeneticSpeciesServiceScript.KEY_SELECTION_PRESSURE_CLASS, -1))
			== GeneticSpeciesServiceScript.SelectionPressureClass.MODERATE,
		"HOT-Stress mappt auf moderaten Selection Pressure"
	)
	_assert_no_redundant_scope_keys(ctx, sulfur_desc)


static func _complex_desc_for_richness(richness_class: int) -> Dictionary:
	return GeneticSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(&"complex_world"),
		_life_potential_desc(&"complex_world", LifePotentialServiceScript.Track.WATER_CARBON),
		_biosphere_scale_desc(
			&"complex_world",
			BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
			LifePotentialServiceScript.Track.WATER_CARBON,
			0.80,
			PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
		),
		_native_species_desc(
			&"complex_world",
			richness_class,
			NativeSpeciesServiceScript.MetabolismClass.PHOTOTROPHIC,
			NativeSpeciesServiceScript.HabitatClass.TEMPERATE_SURFACE,
			NativeSpeciesServiceScript.MobilityClass.COLONIAL
		),
		&"complex_world"
	)


static func _microbial_desc_without_native_basis(id: StringName, track_id: int, thermal_class: int) -> Dictionary:
	var planetary_state_desc: Dictionary = _sampled_planetary_state_desc(id, thermal_class)
	var life_potential_desc: Dictionary = _life_potential_desc(id, track_id)
	var biosphere_scale_desc: Dictionary = _biosphere_scale_desc(
		id,
		BiosphereScaleServiceScript.Stage.MICROBIAL,
		track_id,
		0.80,
		thermal_class
	)
	var native_species_desc: Dictionary = NativeSpeciesServiceScript.evaluate_from_descriptions(
		planetary_state_desc,
		life_potential_desc,
		biosphere_scale_desc,
		id
	)
	return GeneticSpeciesServiceScript.evaluate_from_descriptions(
		planetary_state_desc,
		life_potential_desc,
		biosphere_scale_desc,
		native_species_desc,
		id
	)


static func _dominant_trait_loci(genetic_species_desc: Dictionary) -> Dictionary:
	return _dominant_profile(genetic_species_desc).get(
		GeneticSpeciesServiceScript.KEY_TRAIT_LOCI,
		{}
	)


static func _dominant_visual_profile(genetic_species_desc: Dictionary) -> Dictionary:
	return _dominant_profile(genetic_species_desc).get(
		GeneticSpeciesServiceScript.KEY_VISUAL_PROFILE,
		{}
	)


static func _dominant_profile(genetic_species_desc: Dictionary) -> Dictionary:
	var profiles: Array = genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES,
		[]
	)
	if profiles.is_empty():
		return {}
	var profile: Dictionary = profiles[0]
	return profile


static func _role_classes(genetic_species_desc: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var profiles: Array = genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES,
		[]
	)
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		out.append(int(profile.get(
			GeneticSpeciesServiceScript.KEY_ROLE_CLASS,
			GeneticSpeciesServiceScript.RoleClass.PRODUCER
		)))
	return out


static func _abundance_classes(genetic_species_desc: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var profiles: Array = genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES,
		[]
	)
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		out.append(int(profile.get(
			GeneticSpeciesServiceScript.KEY_ABUNDANCE_CLASS,
			GeneticSpeciesServiceScript.AbundanceClass.TRACE
		)))
	return out


static func _selection_pressure_classes(genetic_species_desc: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var profiles: Array = genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES,
		[]
	)
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		out.append(int(profile.get(
			GeneticSpeciesServiceScript.KEY_SELECTION_PRESSURE_CLASS,
			-1
		)))
	return out


static func _assert_no_redundant_scope_keys(ctx, genetic_species_desc: Dictionary) -> void:
	var profiles: Array = genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES,
		[]
	)
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		ctx.assert_true(not profile.has(&"ecology_profile"), "Profile fuehren kein redundantes ecology_profile ein")
		ctx.assert_true(not profile.has(&"niche_class"), "Profile fuehren keine NicheClass-Duplikate ein")
		ctx.assert_true(not profile.has(&"competition_state_class"), "Profile fuehren keine statische CompetitionStateClass ein")
		ctx.assert_true(not profile.has(&"visual_pattern_class"), "Profile fuehren keine VisualPatternClass-Duplikate ein")


static func _sampled_planetary_state_desc(
		id: StringName,
		thermal_class: int = PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE,
		seasonality_class: int = PlanetaryStateServiceScript.SeasonalityClass.LOW,
		stability_class: int = PlanetaryStateServiceScript.StabilityClass.STABLE
	) -> Dictionary:
	return {
		PlanetaryStateServiceScript.KEY_BODY_ID: id,
		PlanetaryStateServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		PlanetaryStateServiceScript.KEY_HAS_SAMPLED_YEAR_BASIS: true,
		PlanetaryStateServiceScript.KEY_THERMAL_EXTREMITY_CLASS: thermal_class,
		PlanetaryStateServiceScript.KEY_SEASONALITY_CLASS: seasonality_class,
		PlanetaryStateServiceScript.KEY_STABILITY_CLASS: stability_class,
	}


static func _life_potential_desc(id: StringName, track_id: int) -> Dictionary:
	return {
		LifePotentialServiceScript.KEY_BODY_ID: id,
		LifePotentialServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		LifePotentialServiceScript.KEY_HAS_LIFE_POTENTIAL_BASIS: true,
		LifePotentialServiceScript.KEY_DOMINANT_TRACK_ID: track_id,
		LifePotentialServiceScript.KEY_DOMINANT_POTENTIAL_CLASS: LifePotentialServiceScript.PotentialClass.HIGH,
	}


static func _biosphere_scale_desc(
		id: StringName,
		stage: int,
		track_id: int,
		carrying_capacity_index: float,
		dominant_band_thermal_class: int
	) -> Dictionary:
	return {
		BiosphereScaleServiceScript.KEY_BODY_ID: id,
		BiosphereScaleServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID: track_id,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: stage,
		BiosphereScaleServiceScript.KEY_DOMINANT_POTENTIAL_CLASS: LifePotentialServiceScript.PotentialClass.HIGH,
		BiosphereScaleServiceScript.KEY_DOMINANT_BIOMASS_INDEX: 0.80,
		BiosphereScaleServiceScript.KEY_DOMINANT_BAND_THERMAL_CLASS: dominant_band_thermal_class,
		BiosphereScaleServiceScript.KEY_CARRYING_CAPACITY_INDEX_BY_TRACK: {
			track_id: carrying_capacity_index,
		},
	}


static func _native_species_desc(
		id: StringName,
		richness_class: int,
		metabolism_class: int,
		habitat_class: int,
		mobility_class: int
	) -> Dictionary:
	return {
		NativeSpeciesServiceScript.KEY_BODY_ID: id,
		NativeSpeciesServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS: true,
		NativeSpeciesServiceScript.KEY_DOMINANT_TRACK_ID: LifePotentialServiceScript.Track.WATER_CARBON,
		NativeSpeciesServiceScript.KEY_SPECIES_COMPLEXITY_CLASS: NativeSpeciesServiceScript.ComplexityClass.DIVERSE_MACRO,
		NativeSpeciesServiceScript.KEY_SPECIES_RICHNESS_CLASS: richness_class,
		NativeSpeciesServiceScript.KEY_HABITAT_CLASS: habitat_class,
		NativeSpeciesServiceScript.KEY_METABOLISM_CLASS: metabolism_class,
		NativeSpeciesServiceScript.KEY_MOBILITY_CLASS: mobility_class,
	}


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
