extends RefCounted


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


static func run(ctx) -> void:
	ctx.current_suite = "test_native_species_service"
	_test_pure_helper_matches_live_describe_path(ctx)
	_test_species_requires_complex_life_basis(ctx)
	_test_richness_uses_carrying_capacity_and_mobility_uses_complexity_matrix(ctx)
	_test_species_mappings_stay_chemistry_aware(ctx)
	_test_service_ignores_non_planetary_bodies(ctx)


static func _test_pure_helper_matches_live_describe_path(ctx) -> void:
	var registry: Node = _single_planet_registry(&"planet_a")
	var planetary_state_probe := PlanetaryStateProbe.new()
	planetary_state_probe.desc_by_id[&"planet_a"] = _sampled_planetary_state_desc(&"planet_a")
	var life_potential_probe := LifePotentialProbe.new()
	life_potential_probe.desc_by_id[&"planet_a"] = _life_potential_desc(
		&"planet_a",
		LifePotentialServiceScript.Track.WATER_CARBON
	)
	var biosphere_scale_probe := BiosphereScaleProbe.new()
	biosphere_scale_probe.desc_by_id[&"planet_a"] = _biosphere_scale_desc(
		&"planet_a",
		LifePotentialServiceScript.Track.WATER_CARBON,
		BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
		0.80,
		0.45,
		BiosphereScaleServiceScript.BAND_EQUATOR,
		PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
	)
	var service = NativeSpeciesServiceScript.new()
	service.configure(registry, planetary_state_probe, life_potential_probe, biosphere_scale_probe)

	var live_desc: Dictionary = service.describe_body(&"planet_a")
	var pure_desc: Dictionary = NativeSpeciesServiceScript.evaluate_from_descriptions(
		planetary_state_probe.describe_body(&"planet_a"),
		life_potential_probe.describe_body(&"planet_a"),
		biosphere_scale_probe.describe_body(&"planet_a"),
		&"planet_a"
	)

	ctx.assert_true(
		live_desc == pure_desc,
		"NativeSpeciesService.evaluate_from_descriptions liefert fuer dieselben Inputs exakt denselben Desc wie describe_body"
	)

	service.free()
	biosphere_scale_probe.free()
	life_potential_probe.free()
	planetary_state_probe.free()
	registry.free()


static func _test_species_requires_complex_life_basis(ctx) -> void:
	var desc: Dictionary = NativeSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(&"planet_a"),
		_life_potential_desc(&"planet_a", LifePotentialServiceScript.Track.WATER_CARBON),
		_biosphere_scale_desc(
			&"planet_a",
			LifePotentialServiceScript.Track.WATER_CARBON,
			BiosphereScaleServiceScript.Stage.MICROBIAL,
			0.90,
			0.30,
			BiosphereScaleServiceScript.BAND_EQUATOR,
			PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
		),
		&"planet_a"
	)
	ctx.assert_true(
		not bool(desc.get(NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS, true)),
		"Species-Basis startet erst ab COMPLEX_MULTICELLULAR und nicht schon bei MICROBIAL"
	)


static func _test_richness_uses_carrying_capacity_and_mobility_uses_complexity_matrix(ctx) -> void:
	var early_macro_desc: Dictionary = NativeSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(&"planet_a"),
		_life_potential_desc(&"planet_a", LifePotentialServiceScript.Track.WATER_CARBON),
		_biosphere_scale_desc(
			&"planet_a",
			LifePotentialServiceScript.Track.WATER_CARBON,
			BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
			0.80,
			0.35,
			BiosphereScaleServiceScript.BAND_EQUATOR,
			PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
		),
		&"planet_a"
	)
	ctx.assert_true(
		int(early_macro_desc.get(NativeSpeciesServiceScript.KEY_SPECIES_RICHNESS_CLASS, -1))
			== NativeSpeciesServiceScript.RichnessClass.DIVERSE,
		"Richness folgt in v1 dem dominanten Carrying-Capacity-Index statt der bereits realisierten Biomasse"
	)
	ctx.assert_true(
		int(early_macro_desc.get(NativeSpeciesServiceScript.KEY_MOBILITY_CLASS, -1))
			== NativeSpeciesServiceScript.MobilityClass.COLONIAL,
		"EARLY_MACRO plus hohe Nischenbreite darf in v1 hoechstens COLONIAL werden"
	)

	var diverse_macro_patchy_desc: Dictionary = NativeSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(&"gamma_iv"),
		_life_potential_desc(&"gamma_iv", LifePotentialServiceScript.Track.WATER_CARBON),
		_biosphere_scale_desc(
			&"gamma_iv",
			LifePotentialServiceScript.Track.WATER_CARBON,
			BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM,
			0.60,
			0.82,
			BiosphereScaleServiceScript.BAND_EQUATOR,
			PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
		),
		&"gamma_iv"
	)
	ctx.assert_true(
		int(diverse_macro_patchy_desc.get(NativeSpeciesServiceScript.KEY_MOBILITY_CLASS, -1))
			== NativeSpeciesServiceScript.MobilityClass.COLONIAL,
		"DIVERSE_MACRO plus PATCHY-Nischenbreite bleibt in v1 noch COLONIAL"
	)

	var diverse_macro_diverse_desc: Dictionary = NativeSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(&"gamma_iii"),
		_life_potential_desc(&"gamma_iii", LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT),
		_biosphere_scale_desc(
			&"gamma_iii",
			LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
			BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM,
			0.90,
			0.90,
			BiosphereScaleServiceScript.BAND_EQUATOR,
			PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
		),
		&"gamma_iii"
	)
	ctx.assert_true(
		int(diverse_macro_diverse_desc.get(NativeSpeciesServiceScript.KEY_MOBILITY_CLASS, -1))
			== NativeSpeciesServiceScript.MobilityClass.MOTILE,
		"DIVERSE_MACRO plus DIVERSE-Nischenbreite darf in v1 als MOTILE lesen"
	)


static func _test_species_mappings_stay_chemistry_aware(ctx) -> void:
	var water_desc: Dictionary = NativeSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(&"planet_a"),
		_life_potential_desc(&"planet_a", LifePotentialServiceScript.Track.WATER_CARBON),
		_biosphere_scale_desc(
			&"planet_a",
			LifePotentialServiceScript.Track.WATER_CARBON,
			BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
			0.80,
			0.45,
			BiosphereScaleServiceScript.BAND_EQUATOR,
			PlanetaryStateServiceScript.ThermalExtremityClass.TEMPERATE
		),
		&"planet_a"
	)
	ctx.assert_true(
		int(water_desc.get(NativeSpeciesServiceScript.KEY_HABITAT_CLASS, -1))
			== NativeSpeciesServiceScript.HabitatClass.TEMPERATE_SURFACE,
		"WATER_CARBON plus temperiertes dominantes Band liest als TEMPERATE_SURFACE"
	)
	ctx.assert_true(
		int(water_desc.get(NativeSpeciesServiceScript.KEY_METABOLISM_CLASS, -1))
			== NativeSpeciesServiceScript.MetabolismClass.PHOTOTROPHIC,
		"WATER_CARBON plus Oberflaechenhabitat liest als PHOTOTROPHIC"
	)

	var sulfur_desc: Dictionary = NativeSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(&"alpha_iii"),
		_life_potential_desc(&"alpha_iii", LifePotentialServiceScript.Track.SULFUR_REACTIVE),
		_biosphere_scale_desc(
			&"alpha_iii",
			LifePotentialServiceScript.Track.SULFUR_REACTIVE,
			BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR,
			0.70,
			0.40,
			BiosphereScaleServiceScript.BAND_EQUATOR,
			PlanetaryStateServiceScript.ThermalExtremityClass.HOT
		),
		&"alpha_iii"
	)
	ctx.assert_true(
		int(sulfur_desc.get(NativeSpeciesServiceScript.KEY_HABITAT_CLASS, -1))
			== NativeSpeciesServiceScript.HabitatClass.VENT_SURFACE,
		"SULFUR_REACTIVE plus hot/extreme liest als VENT_SURFACE"
	)
	ctx.assert_true(
		int(sulfur_desc.get(NativeSpeciesServiceScript.KEY_METABOLISM_CLASS, -1))
			== NativeSpeciesServiceScript.MetabolismClass.SULFUR_CHEMOSYNTHETIC,
		"SULFUR_REACTIVE liest metabolism-seitig als SULFUR_CHEMOSYNTHETIC"
	)

	var cryo_desc: Dictionary = NativeSpeciesServiceScript.evaluate_from_descriptions(
		_sampled_planetary_state_desc(&"gamma_iii"),
		_life_potential_desc(&"gamma_iii", LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT),
		_biosphere_scale_desc(
			&"gamma_iii",
			LifePotentialServiceScript.Track.CRYOGENIC_SOLVENT,
			BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM,
			0.90,
			0.82,
			BiosphereScaleServiceScript.BAND_EQUATOR,
			PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
		),
		&"gamma_iii"
	)
	ctx.assert_true(
		int(cryo_desc.get(NativeSpeciesServiceScript.KEY_HABITAT_CLASS, -1))
			== NativeSpeciesServiceScript.HabitatClass.CRYO_SURFACE,
		"CRYOGENIC_SOLVENT plus frozen/cold liest als CRYO_SURFACE"
	)
	ctx.assert_true(
		int(cryo_desc.get(NativeSpeciesServiceScript.KEY_METABOLISM_CLASS, -1))
			== NativeSpeciesServiceScript.MetabolismClass.CRYOCHEMICAL,
		"CRYOGENIC_SOLVENT liest metabolism-seitig als CRYOCHEMICAL"
	)


static func _test_service_ignores_non_planetary_bodies(ctx) -> void:
	var registry: Node = _single_planet_registry(&"planet_a")
	var planetary_state_probe := PlanetaryStateProbe.new()
	var life_potential_probe := LifePotentialProbe.new()
	var biosphere_scale_probe := BiosphereScaleProbe.new()
	var service = NativeSpeciesServiceScript.new()
	service.configure(registry, planetary_state_probe, life_potential_probe, biosphere_scale_probe)

	var star_desc: Dictionary = service.describe_body(&"sol")
	ctx.assert_true(
		not bool(star_desc.get(NativeSpeciesServiceScript.KEY_IS_SUPPORTED_BODY_KIND, true)),
		"NativeSpeciesService ignoriert STAR-Bodies komplett"
	)
	ctx.assert_true(
		not bool(star_desc.get(NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS, true)),
		"Nicht-planetare Bodies bekommen keine Species-Basis"
	)

	service.free()
	biosphere_scale_probe.free()
	life_potential_probe.free()
	planetary_state_probe.free()
	registry.free()


static func _sampled_planetary_state_desc(body_id: StringName) -> Dictionary:
	return {
		PlanetaryStateServiceScript.KEY_BODY_ID: body_id,
		PlanetaryStateServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		PlanetaryStateServiceScript.KEY_HAS_SAMPLED_YEAR_BASIS: true,
	}


static func _life_potential_desc(body_id: StringName, dominant_track_id: int) -> Dictionary:
	var classes_by_track: Dictionary = {}
	for track_id in LifePotentialServiceScript.TRACK_IDS:
		classes_by_track[track_id] = LifePotentialServiceScript.PotentialClass.NONE
	classes_by_track[dominant_track_id] = LifePotentialServiceScript.PotentialClass.HIGH
	return {
		LifePotentialServiceScript.KEY_BODY_ID: body_id,
		LifePotentialServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		LifePotentialServiceScript.KEY_HAS_LIFE_POTENTIAL_BASIS: true,
		LifePotentialServiceScript.KEY_DOMINANT_TRACK_ID: dominant_track_id,
		LifePotentialServiceScript.KEY_DOMINANT_POTENTIAL_CLASS: LifePotentialServiceScript.PotentialClass.HIGH,
		LifePotentialServiceScript.KEY_TRACK_POTENTIAL_CLASS_BY_ID: classes_by_track,
	}


static func _biosphere_scale_desc(
		body_id: StringName,
		dominant_track_id: int,
		biosphere_stage: int,
		dominant_carrying_capacity_index: float,
		dominant_biomass_index: float,
		dominant_band_id: StringName,
		dominant_band_thermal_class: int
	) -> Dictionary:
	var carrying_capacity_index_by_track: Dictionary = {}
	var biomass_index_by_track: Dictionary = {}
	for track_id in LifePotentialServiceScript.TRACK_IDS:
		carrying_capacity_index_by_track[track_id] = 0.0
		biomass_index_by_track[track_id] = 0.0
	carrying_capacity_index_by_track[dominant_track_id] = dominant_carrying_capacity_index
	biomass_index_by_track[dominant_track_id] = dominant_biomass_index
	return {
		BiosphereScaleServiceScript.KEY_BODY_ID: body_id,
		BiosphereScaleServiceScript.KEY_IS_SUPPORTED_BODY_KIND: true,
		BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS: true,
		BiosphereScaleServiceScript.KEY_CARRYING_CAPACITY_INDEX_BY_TRACK: carrying_capacity_index_by_track,
		BiosphereScaleServiceScript.KEY_BIOMASS_INDEX_BY_TRACK: biomass_index_by_track,
		BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID: dominant_track_id,
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE: biosphere_stage,
		BiosphereScaleServiceScript.KEY_DOMINANT_POTENTIAL_CLASS: LifePotentialServiceScript.PotentialClass.HIGH,
		BiosphereScaleServiceScript.KEY_DOMINANT_BIOMASS_INDEX: dominant_biomass_index,
		BiosphereScaleServiceScript.KEY_DOMINANT_BAND_ID: dominant_band_id,
		BiosphereScaleServiceScript.KEY_DOMINANT_BAND_THERMAL_CLASS: dominant_band_thermal_class,
	}


static func _single_planet_registry(planet_id: StringName) -> Node:
	var registry: Node = load("res://src/sim/universe/universe_registry.gd").new()
	var star := BodyDef.new()
	star.id = &"sol"
	star.display_name = "Sol"
	star.kind = BodyType.Kind.STAR
	star.mass_kg = UnitSystem.SOLAR_MASS_KG
	star.radius_m = 6.957e8
	star.parent_id = &""
	registry.register_body(star)

	var planet := BodyDef.new()
	planet.id = planet_id
	planet.display_name = String(planet_id)
	planet.kind = BodyType.Kind.PLANET
	planet.mass_kg = UnitSystem.EARTH_MASS_KG
	planet.radius_m = UnitSystem.EARTH_RADIUS_M
	planet.parent_id = &"sol"
	planet.orbit_profile = OrbitProfile.new()
	planet.orbit_profile.mode = OrbitMode.Kind.AUTHORED_ORBIT
	planet.orbit_profile.authored_radius_m = 1.0e9
	planet.orbit_profile.authored_period_s = 10.0
	registry.register_body(planet)
	return registry
