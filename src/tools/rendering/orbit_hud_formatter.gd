extends RefCounted


const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const ThermalServiceScript = preload("res://src/sim/thermal/thermal_service.gd")
const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const ProtoBiosphereSimulationServiceScript = preload("res://src/sim/life/proto_biosphere_simulation_service.gd")
const BiosphereScaleServiceScript = preload("res://src/sim/life/biosphere_scale_service.gd")
const NativeSpeciesServiceScript = preload("res://src/sim/life/native_species_service.gd")
const GeneticSpeciesServiceScript = preload("res://src/sim/life/genetic_species_service.gd")
const OrbitReadoutServiceScript = preload("res://src/sim/orbit/orbit_readout_service.gd")

const MINUTE_S: float = 60.0
const HOUR_S: float = 60.0 * MINUTE_S


static func format_focus(focus_name: String) -> String:
	return "Focus: %s" % focus_name


static func format_environment(environment_desc: Dictionary) -> String:
	if not bool(environment_desc.get(EnvironmentServiceScript.KEY_IS_SUPPORTED_BODY_KIND, false)):
		return "Environment: n/a"
	return "Environment: %s   Climate: %s" % [
		_environment_class_text(environment_desc),
		_ecosystem_text(environment_desc),
	]


static func format_planet_summary(environment_desc: Dictionary) -> String:
	if not bool(environment_desc.get(EnvironmentServiceScript.KEY_IS_SUPPORTED_BODY_KIND, false)):
		return "Summary: n/a"
	return "Summary: %s / %s" % [
		_environment_class_text(environment_desc),
		_ecosystem_text(environment_desc),
	]


static func format_planet_life_summary(biosphere_desc: Dictionary, native_species_desc: Dictionary) -> String:
	if not _biosphere_has_basis(biosphere_desc):
		return "Life: n/a"
	var segments: Array[String] = [
		"Life: %s" % compact_life_stage_text(biosphere_desc),
	]
	var density_text: String = compact_density_text(biosphere_desc)
	if density_text != "":
		segments.append("Density: %s" % density_text)
	var species_text: String = compact_species_text(native_species_desc)
	if species_text != "":
		segments.append("Species: %s" % species_text)
	return "   ".join(segments)


static func format_bands(environment_desc: Dictionary) -> String:
	if not bool(environment_desc.get(EnvironmentServiceScript.KEY_IS_SUPPORTED_BODY_KIND, false)):
		return "Bands: n/a"
	if not bool(environment_desc.get(EnvironmentServiceScript.KEY_HAS_LATITUDINAL_SURFACE_BASIS, false)):
		return "Bands: n/a"
	return "Bands: -60deg %.0f K   Eq %.0f K   +60deg %.0f K" % [
		float(environment_desc.get(EnvironmentServiceScript.KEY_SOUTH_MIDLATITUDE_SURFACE_TEMPERATURE_K, 0.0)),
		float(environment_desc.get(EnvironmentServiceScript.KEY_EQUATOR_SURFACE_TEMPERATURE_K, 0.0)),
		float(environment_desc.get(EnvironmentServiceScript.KEY_NORTH_MIDLATITUDE_SURFACE_TEMPERATURE_K, 0.0)),
	]


static func format_world(planetary_state_desc: Dictionary) -> String:
	if not bool(planetary_state_desc.get(PlanetaryStateServiceScript.KEY_HAS_SAMPLED_YEAR_BASIS, false)):
		return "World: n/a"
	return "World: %s / %s / %s / %s / %s" % [
		_volatile_inventory_text(planetary_state_desc),
		_climate_buffer_text(planetary_state_desc),
		_seasonality_text(planetary_state_desc),
		_stability_text(planetary_state_desc),
		_thermal_extremity_text(planetary_state_desc),
	]


static func format_life_potential(life_potential_desc: Dictionary) -> String:
	if not bool(life_potential_desc.get(LifePotentialServiceScript.KEY_HAS_LIFE_POTENTIAL_BASIS, false)):
		return "Life Potential: n/a"
	return "Life Potential: %s / %s" % [
		_track_text(life_potential_desc),
		_potential_class_text(life_potential_desc),
	]


static func format_life(biosphere_desc: Dictionary) -> String:
	if not _biosphere_has_basis(biosphere_desc):
		return "Life: n/a"
	if _biosphere_has_no_track(biosphere_desc):
		return "Life: %s" % _biosphere_stage_text(biosphere_desc)
	return "Life: %s / %s" % [
		_biosphere_stage_text(biosphere_desc),
		_biosphere_track_text(biosphere_desc),
	]


static func format_life_summary(biosphere_desc: Dictionary) -> String:
	if not _biosphere_has_basis(biosphere_desc):
		return "Life: n/a"
	if _biosphere_has_no_track(biosphere_desc):
		return "Life: %s" % _biosphere_stage_short_text(biosphere_desc)
	return "Life: %s / %s" % [
		_biosphere_stage_short_text(biosphere_desc),
		_biosphere_track_text(biosphere_desc),
	]


static func format_biomass(biosphere_scale_desc: Dictionary) -> String:
	if not bool(biosphere_scale_desc.get(BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS, false)):
		return "Biomass: n/a"
	return "Biomass: %.2f" % float(biosphere_scale_desc.get(
		BiosphereScaleServiceScript.KEY_DOMINANT_BIOMASS_INDEX,
		0.0
	))


static func format_species(native_species_desc: Dictionary) -> String:
	if not bool(native_species_desc.get(NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS, false)):
		return "Species: n/a"
	return "Species: %s / %s / %s / %s" % [
		_native_species_complexity_text(native_species_desc),
		_native_species_metabolism_text(native_species_desc),
		_native_species_habitat_text(native_species_desc),
		_native_species_mobility_text(native_species_desc),
	]


static func format_species_summary(native_species_desc: Dictionary) -> String:
	if not bool(native_species_desc.get(NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS, false)):
		return "Species: n/a"
	return "Species: %s / %s" % [
		_native_species_metabolism_short_text(native_species_desc),
		_native_species_mobility_text(native_species_desc),
	]


static func format_density(biosphere_desc: Dictionary) -> String:
	var density_text: String = _density_class_text(biosphere_desc)
	if density_text == "":
		return "Density: n/a"
	return "Density: %s" % density_text


static func format_life_detail_species_or_dominant(
		native_species_desc: Dictionary,
		genetic_species_desc: Dictionary,
		biosphere_desc: Dictionary
	) -> String:
	if _genetic_species_should_replace_species_line(genetic_species_desc, biosphere_desc):
		return format_dominant_form(genetic_species_desc)
	return format_species(native_species_desc)


static func format_native_forms(genetic_species_desc: Dictionary) -> String:
	if not bool(genetic_species_desc.get(GeneticSpeciesServiceScript.KEY_HAS_GENETIC_SPECIES_BASIS, false)):
		return "Native forms: n/a"
	var profiles: Array = genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES,
		[]
	)
	if profiles.is_empty():
		var proto_summary: String = String(genetic_species_desc.get(
			GeneticSpeciesServiceScript.KEY_PROTO_FORM_SUMMARY,
			""
		))
		if proto_summary != "":
			return "Native forms: %s" % proto_summary
		return "Native forms: none"
	var parts: Array[String] = []
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		parts.append("%s/%s" % [
			_genetic_role_text(profile),
			_genetic_abundance_text(profile),
		])
	return "Native forms: %s" % " | ".join(parts)


static func format_dominant_form(genetic_species_desc: Dictionary) -> String:
	var profile: Dictionary = _dominant_genetic_profile(genetic_species_desc)
	if profile.is_empty():
		return "Dominant form: n/a"
	return "Dominant form: %s / %s / %s" % [
		_genetic_role_text(profile),
		_genetic_abundance_text(profile),
		_genetic_metabolism_text(profile),
	]


static func format_abundance(genetic_species_desc: Dictionary) -> String:
	var profile: Dictionary = _dominant_genetic_profile(genetic_species_desc)
	if profile.is_empty():
		return "Abundance: n/a"
	return "Abundance: %s" % _genetic_abundance_text(profile)


static func format_visual_profile(genetic_species_desc: Dictionary) -> String:
	var profile: Dictionary = _dominant_genetic_profile(genetic_species_desc)
	if profile.is_empty():
		return "Visual profile: n/a"
	var visual_profile: Dictionary = profile.get(
		GeneticSpeciesServiceScript.KEY_VISUAL_PROFILE,
		{}
	)
	return "Visual profile: %s / %s / %s" % [
		GeneticSpeciesServiceScript.to_string_body_plan_class(int(visual_profile.get(
			GeneticSpeciesServiceScript.KEY_VISUAL_BODY_PLAN_CLASS,
			GeneticSpeciesServiceScript.BodyPlanClass.UNICELLULAR
		))),
		GeneticSpeciesServiceScript.to_string_color_family(int(visual_profile.get(
			GeneticSpeciesServiceScript.KEY_VISUAL_COLOR_FAMILY,
			GeneticSpeciesServiceScript.ColorFamily.GREY_BIOLUMEN
		))),
		GeneticSpeciesServiceScript.to_string_motion_style(int(visual_profile.get(
			GeneticSpeciesServiceScript.KEY_VISUAL_MOTION_STYLE,
			GeneticSpeciesServiceScript.MotionStyle.ANCHORED
		))),
	]


static func compact_life_stage_text(biosphere_desc: Dictionary) -> String:
	if not _biosphere_has_basis(biosphere_desc):
		return ""
	return _biosphere_stage_short_text(biosphere_desc)


static func compact_density_text(biosphere_desc: Dictionary) -> String:
	return _density_class_text(biosphere_desc)


static func compact_species_text(native_species_desc: Dictionary) -> String:
	if not bool(native_species_desc.get(NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS, false)):
		return ""
	return _native_species_metabolism_short_text(native_species_desc)


static func format_season(thermal_desc: Dictionary) -> String:
	if not bool(thermal_desc.get(ThermalServiceScript.KEY_HAS_SEASONAL_BASIS, false)):
		return "Season: n/a"
	var subsolar_latitude_rad: float = float(thermal_desc.get(ThermalServiceScript.KEY_SUBSOLAR_LATITUDE_RAD, 0.0))
	return "Season: subsolar %+.0f deg" % rad_to_deg(subsolar_latitude_rad)


static func format_primary_source(thermal_desc: Dictionary) -> String:
	if not bool(thermal_desc.get(ThermalServiceScript.KEY_HAS_LUMINOUS_ANCESTOR, false)):
		return "Primary source: none"
	var source_id: StringName = thermal_desc.get(ThermalServiceScript.KEY_SOURCE_ID, StringName(""))
	return "Primary source: %s" % [String(source_id)]


static func format_inspector_environment_badge(environment_desc: Dictionary) -> String:
	if not bool(environment_desc.get(EnvironmentServiceScript.KEY_IS_SUPPORTED_BODY_KIND, false)):
		return "n/a"
	return "%s / %s" % [
		_environment_class_text(environment_desc),
		_ecosystem_text(environment_desc),
	]


static func format_inspector_world_line(planetary_state_desc: Dictionary) -> String:
	if not bool(planetary_state_desc.get(PlanetaryStateServiceScript.KEY_HAS_SAMPLED_YEAR_BASIS, false)):
		return "World: n/a"
	var segments: Array[String] = [
		_volatile_inventory_text(planetary_state_desc),
		_climate_buffer_text(planetary_state_desc),
		_stability_text(planetary_state_desc),
		_thermal_extremity_text(planetary_state_desc),
	]
	var seasonality_text: String = _seasonality_text(planetary_state_desc)
	if seasonality_text != "LOW":
		segments.append(seasonality_text)
	return "World: %s" % " / ".join(segments)


static func format_inspector_life_line(biosphere_desc: Dictionary) -> String:
	if not _biosphere_has_basis(biosphere_desc):
		return "Life: n/a"
	if _biosphere_has_no_track(biosphere_desc):
		return "Life: %s" % _biosphere_stage_text(biosphere_desc)
	return "Life: %s / %s / %s" % [
		_biosphere_stage_text(biosphere_desc),
		_biosphere_track_text(biosphere_desc),
		_biosphere_potential_class_text(biosphere_desc),
	]


static func format_inspector_life_badge(biosphere_desc: Dictionary) -> String:
	if not _biosphere_has_basis(biosphere_desc):
		return ""
	return _biosphere_stage_short_text(biosphere_desc)


static func format_inspector_species_line(native_species_desc: Dictionary, biosphere_desc: Dictionary) -> String:
	if not bool(native_species_desc.get(NativeSpeciesServiceScript.KEY_HAS_NATIVE_SPECIES_BASIS, false)):
		return ""
	var density_text: String = _density_class_text(biosphere_desc)
	if density_text == "":
		return "Species: %s" % _native_species_metabolism_short_text(native_species_desc)
	return "Species: %s / %s" % [
		_native_species_metabolism_short_text(native_species_desc),
		density_text,
	]


static func format_time(sim_time_s: float, tick_count: int, fps: int) -> String:
	return "T+ %s   steps %d   FPS %d" % [_elapsed_time_text(sim_time_s), tick_count, fps]


static func format_cycle(orbit_readout_desc: Dictionary) -> String:
	var parts: Array[String] = []
	if bool(orbit_readout_desc.get(OrbitReadoutServiceScript.KEY_HAS_ROTATION_BASIS, false)):
		parts.append("rot %s" % _period_text(
			float(orbit_readout_desc.get(OrbitReadoutServiceScript.KEY_ROTATION_PERIOD_S, 0.0))
		))
	if bool(orbit_readout_desc.get(OrbitReadoutServiceScript.KEY_HAS_ORBITAL_PERIOD_BASIS, false)):
		parts.append("orb %s" % _period_text(
			float(orbit_readout_desc.get(OrbitReadoutServiceScript.KEY_ORBITAL_PERIOD_S, 0.0))
		))
	if parts.is_empty():
		return "Cycle: n/a"
	return "Cycle: %s" % " / ".join(parts)


static func format_rotation(orbit_readout_desc: Dictionary) -> String:
	return "Rotation: %s" % _period_text(
		float(orbit_readout_desc.get(OrbitReadoutServiceScript.KEY_ROTATION_PERIOD_S, 0.0))
	)


static func format_orbit(orbit_readout_desc: Dictionary) -> String:
	return "Orbit: %s" % _period_text(
		float(orbit_readout_desc.get(OrbitReadoutServiceScript.KEY_ORBITAL_PERIOD_S, 0.0))
	)


static func format_scale(time_scale: float, preset_label: String, zoom_factor: float, zoom_mode: String, frame_label: String = "") -> String:
	var mode_segment: String = zoom_mode
	if frame_label != "":
		mode_segment = "%s (%s)" % [zoom_mode, frame_label]
	return "Rate: %s   Preset %s   Zoom %s %s" % [
		_time_rate_text(time_scale),
		preset_label,
		_zoom_percent_text(zoom_factor),
		mode_segment,
	]


static func format_cadence(time_scale: float) -> String:
	var safe_time_scale: float = maxf(time_scale, 0.0001)
	var cadence_seconds: float = ProtoBiosphereSimulationServiceScript.BIO_TICK_STEP_S / safe_time_scale
	return "Cadence: Bio tick ~ %s" % _duration_text(cadence_seconds)


static func format_mode(body_count: int, paused: bool) -> String:
	return "Bodies %d   %s" % [body_count, "Paused" if paused else "Running"]


static func _stripped_float(value: float) -> String:
	var rounded: float = roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	return "%.2f" % value


static func _zoom_percent_text(zoom_factor: float) -> String:
	var percent: float = zoom_factor * 100.0
	var rounded: float = roundf(percent)
	if is_equal_approx(percent, rounded):
		return "%d%%" % int(rounded)
	return "%.1f%%" % percent


static func _time_rate_text(time_scale: float) -> String:
	var safe_time_scale: float = maxf(time_scale, 0.0)
	if safe_time_scale >= UnitSystem.DAY_S:
		return "%s d/s" % _rounded_quantity_text(safe_time_scale / UnitSystem.DAY_S)
	if safe_time_scale >= HOUR_S:
		return "%s h/s" % _rounded_quantity_text(safe_time_scale / HOUR_S)
	if safe_time_scale >= MINUTE_S:
		return "%s min/s" % _rounded_quantity_text(safe_time_scale / MINUTE_S)
	return "%s s/s" % _rounded_quantity_text(safe_time_scale)


static func _rounded_quantity_text(value: float) -> String:
	var rounded: float = roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	if value < 10.0:
		return "%.1f" % value
	return str(int(roundf(value)))


static func _duration_text(seconds: float) -> String:
	var total_seconds: int = maxi(int(round(seconds)), 0)
	if total_seconds < 60:
		return "%d s" % total_seconds
	if total_seconds < int(HOUR_S):
		return "%d min" % int(roundf(float(total_seconds) / MINUTE_S))
	if total_seconds < int(UnitSystem.DAY_S):
		var total_minutes: int = int(roundf(float(total_seconds) / MINUTE_S))
		var hours: int = total_minutes / 60
		var minutes: int = total_minutes % 60
		if minutes == 0:
			return "%d h" % hours
		return "%d h %d min" % [hours, minutes]
	var total_hours: int = int(roundf(float(total_seconds) / HOUR_S))
	var days: int = total_hours / 24
	var hours_remainder: int = total_hours % 24
	if hours_remainder == 0:
		return "%d d" % days
	return "%d d %d h" % [days, hours_remainder]


static func _elapsed_time_text(seconds: float) -> String:
	var safe_seconds: float = maxf(seconds, 0.0)
	if safe_seconds < MINUTE_S:
		return "%d s" % int(roundf(safe_seconds))
	if safe_seconds < HOUR_S:
		return "%.1f min" % (safe_seconds / MINUTE_S)
	if safe_seconds < 48.0 * HOUR_S:
		return "%.1f h" % (safe_seconds / HOUR_S)
	if safe_seconds < UnitSystem.YEAR_S:
		return "%.1f d" % (safe_seconds / UnitSystem.DAY_S)
	return "%.1f y" % (safe_seconds / UnitSystem.YEAR_S)


static func _period_text(seconds: float) -> String:
	var safe_seconds: float = maxf(seconds, 0.0)
	if safe_seconds < HOUR_S:
		return "%.1f min" % (safe_seconds / MINUTE_S)
	if safe_seconds < 48.0 * HOUR_S:
		return "%.1f h" % (safe_seconds / HOUR_S)
	if safe_seconds < UnitSystem.YEAR_S:
		return "%.1f d" % (safe_seconds / UnitSystem.DAY_S)
	return "%.1f y" % (safe_seconds / UnitSystem.YEAR_S)


static func _environment_class_text(environment_desc: Dictionary) -> String:
	return EnvironmentServiceScript.to_string_class(
		int(environment_desc.get(EnvironmentServiceScript.KEY_ENVIRONMENT_CLASS, EnvironmentServiceScript.Class.HOSTILE))
	)


static func _ecosystem_text(environment_desc: Dictionary) -> String:
	return EnvironmentServiceScript.to_string_ecosystem(
		int(environment_desc.get(EnvironmentServiceScript.KEY_ECOSYSTEM_TYPE, EnvironmentServiceScript.EcosystemType.FROZEN_WORLD))
	)


static func _volatile_inventory_text(planetary_state_desc: Dictionary) -> String:
	return PlanetaryStateServiceScript.to_string_volatile_inventory_class(
		int(planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_VOLATILE_INVENTORY_CLASS,
			PlanetaryStateServiceScript.VolatileInventoryClass.TRACE
		))
	)


static func _climate_buffer_text(planetary_state_desc: Dictionary) -> String:
	return PlanetaryStateServiceScript.to_string_climate_buffer_class(
		int(planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_CLIMATE_BUFFER_CLASS,
			PlanetaryStateServiceScript.ClimateBufferClass.UNBUFFERED
		))
	)


static func _thermal_extremity_text(planetary_state_desc: Dictionary) -> String:
	return PlanetaryStateServiceScript.to_string_thermal_extremity_class(
		int(planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_THERMAL_EXTREMITY_CLASS,
			PlanetaryStateServiceScript.ThermalExtremityClass.FROZEN
		))
	)


static func _seasonality_text(planetary_state_desc: Dictionary) -> String:
	return PlanetaryStateServiceScript.to_string_seasonality_class(
		int(planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_SEASONALITY_CLASS,
			PlanetaryStateServiceScript.SeasonalityClass.LOW
		))
	)


static func _stability_text(planetary_state_desc: Dictionary) -> String:
	return PlanetaryStateServiceScript.to_string_stability_class(
		int(planetary_state_desc.get(
			PlanetaryStateServiceScript.KEY_STABILITY_CLASS,
			PlanetaryStateServiceScript.StabilityClass.FRAGILE
		))
	)


static func _track_text(life_potential_desc: Dictionary) -> String:
	return LifePotentialServiceScript.to_string_track(
		int(life_potential_desc.get(
			LifePotentialServiceScript.KEY_DOMINANT_TRACK_ID,
			LifePotentialServiceScript.Track.WATER_CARBON
		))
	)


static func _potential_class_text(life_potential_desc: Dictionary) -> String:
	return LifePotentialServiceScript.to_string_potential_class(
		int(life_potential_desc.get(
			LifePotentialServiceScript.KEY_DOMINANT_POTENTIAL_CLASS,
			LifePotentialServiceScript.PotentialClass.NONE
		))
	)


static func _biosphere_stage_text(biosphere_desc: Dictionary) -> String:
	if bool(biosphere_desc.get(BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS, false)):
		return BiosphereScaleServiceScript.to_string_stage(
			int(biosphere_desc.get(
				BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE,
				BiosphereScaleServiceScript.Stage.STERILE
			))
		)
	return ProtoBiosphereSimulationServiceScript.to_string_stage(
		int(biosphere_desc.get(
			ProtoBiosphereSimulationServiceScript.KEY_BIOSPHERE_STAGE,
			ProtoBiosphereSimulationServiceScript.Stage.STERILE
		))
	)


static func _biosphere_stage_short_text(biosphere_desc: Dictionary) -> String:
	var stage_text: String = _biosphere_stage_text(biosphere_desc)
	match stage_text:
		"COMPLEX_MULTICELLULAR":
			return "COMPLEX"
		"COMPLEX_ECOSYSTEM":
			return "ECOSYSTEM"
		_:
			return stage_text


static func _biosphere_track_text(biosphere_desc: Dictionary) -> String:
	var dominant_track_key: StringName = ProtoBiosphereSimulationServiceScript.KEY_DOMINANT_TRACK_ID
	if bool(biosphere_desc.get(BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS, false)):
		dominant_track_key = BiosphereScaleServiceScript.KEY_DOMINANT_TRACK_ID
	return LifePotentialServiceScript.to_string_track(
		int(biosphere_desc.get(
			dominant_track_key,
			LifePotentialServiceScript.Track.WATER_CARBON
		))
	)


static func _biosphere_potential_class_text(biosphere_desc: Dictionary) -> String:
	var dominant_potential_class_key: StringName = ProtoBiosphereSimulationServiceScript.KEY_DOMINANT_POTENTIAL_CLASS
	if bool(biosphere_desc.get(BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS, false)):
		dominant_potential_class_key = BiosphereScaleServiceScript.KEY_DOMINANT_POTENTIAL_CLASS
	return LifePotentialServiceScript.to_string_potential_class(
		int(biosphere_desc.get(
			dominant_potential_class_key,
			LifePotentialServiceScript.PotentialClass.NONE
		))
	)


static func _biosphere_has_basis(biosphere_desc: Dictionary) -> bool:
	return bool(biosphere_desc.get(BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS, false)) \
		or bool(biosphere_desc.get(ProtoBiosphereSimulationServiceScript.KEY_HAS_BIOSPHERE_BASIS, false))


static func _biosphere_has_no_track(biosphere_desc: Dictionary) -> bool:
	var dominant_potential_class_key: StringName = ProtoBiosphereSimulationServiceScript.KEY_DOMINANT_POTENTIAL_CLASS
	if bool(biosphere_desc.get(BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS, false)):
		dominant_potential_class_key = BiosphereScaleServiceScript.KEY_DOMINANT_POTENTIAL_CLASS
	var dominant_potential_class: int = int(biosphere_desc.get(
		dominant_potential_class_key,
		LifePotentialServiceScript.PotentialClass.NONE
	))
	if dominant_potential_class == LifePotentialServiceScript.PotentialClass.NONE:
		return true
	if bool(biosphere_desc.get(BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS, false)):
		return is_zero_approx(float(biosphere_desc.get(
			BiosphereScaleServiceScript.KEY_DOMINANT_BIOMASS_INDEX,
			0.0
		)))
	return false


static func _native_species_complexity_text(native_species_desc: Dictionary) -> String:
	return NativeSpeciesServiceScript.to_string_complexity_class(
		int(native_species_desc.get(
			NativeSpeciesServiceScript.KEY_SPECIES_COMPLEXITY_CLASS,
			NativeSpeciesServiceScript.ComplexityClass.EARLY_MACRO
		))
	)


static func _native_species_habitat_text(native_species_desc: Dictionary) -> String:
	return NativeSpeciesServiceScript.to_string_habitat_class(
		int(native_species_desc.get(
			NativeSpeciesServiceScript.KEY_HABITAT_CLASS,
			NativeSpeciesServiceScript.HabitatClass.SHELTERED_SUBSURFACE
		))
	)


static func _native_species_metabolism_text(native_species_desc: Dictionary) -> String:
	return NativeSpeciesServiceScript.to_string_metabolism_class(
		int(native_species_desc.get(
			NativeSpeciesServiceScript.KEY_METABOLISM_CLASS,
			NativeSpeciesServiceScript.MetabolismClass.CHEMOTROPHIC
		))
	)


static func _native_species_metabolism_short_text(native_species_desc: Dictionary) -> String:
	match _native_species_metabolism_text(native_species_desc):
		"PHOTOTROPHIC":
			return "PHOTO"
		"CHEMOTROPHIC":
			return "CHEMO"
		"SULFUR_CHEMOSYNTHETIC":
			return "SULFUR"
		"CRYOCHEMICAL":
			return "CRYO"
	return "UNKNOWN"


static func _native_species_mobility_text(native_species_desc: Dictionary) -> String:
	return NativeSpeciesServiceScript.to_string_mobility_class(
		int(native_species_desc.get(
			NativeSpeciesServiceScript.KEY_MOBILITY_CLASS,
			NativeSpeciesServiceScript.MobilityClass.SESSILE
		))
	)


static func _genetic_species_should_replace_species_line(genetic_species_desc: Dictionary, biosphere_desc: Dictionary) -> bool:
	if not bool(genetic_species_desc.get(GeneticSpeciesServiceScript.KEY_HAS_GENETIC_SPECIES_BASIS, false)):
		return false
	if int(biosphere_desc.get(
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE,
		BiosphereScaleServiceScript.Stage.STERILE
	)) < BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM:
		return false
	var profiles: Array = genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES,
		[]
	)
	return profiles.size() > 1


static func _dominant_genetic_profile(genetic_species_desc: Dictionary) -> Dictionary:
	if not bool(genetic_species_desc.get(GeneticSpeciesServiceScript.KEY_HAS_GENETIC_SPECIES_BASIS, false)):
		return {}
	var profiles: Array = genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_LIFEFORM_PROFILES,
		[]
	)
	if profiles.is_empty():
		return {}
	var dominant_id: StringName = StringName(genetic_species_desc.get(
		GeneticSpeciesServiceScript.KEY_DOMINANT_LIFEFORM_ID,
		StringName("")
	))
	if dominant_id != StringName(""):
		for profile_variant in profiles:
			var profile: Dictionary = profile_variant
			if StringName(profile.get(GeneticSpeciesServiceScript.KEY_LIFEFORM_ID, StringName(""))) == dominant_id:
				return profile
	return profiles[0]


static func _genetic_role_text(profile: Dictionary) -> String:
	return GeneticSpeciesServiceScript.to_string_role_class(int(profile.get(
		GeneticSpeciesServiceScript.KEY_ROLE_CLASS,
		GeneticSpeciesServiceScript.RoleClass.PRODUCER
	)))


static func _genetic_abundance_text(profile: Dictionary) -> String:
	return GeneticSpeciesServiceScript.to_string_abundance_class(int(profile.get(
		GeneticSpeciesServiceScript.KEY_ABUNDANCE_CLASS,
		GeneticSpeciesServiceScript.AbundanceClass.TRACE
	)))


static func _genetic_metabolism_text(profile: Dictionary) -> String:
	var trait_loci: Dictionary = profile.get(
		GeneticSpeciesServiceScript.KEY_TRAIT_LOCI,
		{}
	)
	return NativeSpeciesServiceScript.to_string_metabolism_class(int(trait_loci.get(
		GeneticSpeciesServiceScript.KEY_METABOLISM_LOCUS,
		NativeSpeciesServiceScript.MetabolismClass.CHEMOTROPHIC
	)))


static func _density_class_text(biosphere_desc: Dictionary) -> String:
	if not bool(biosphere_desc.get(BiosphereScaleServiceScript.KEY_HAS_BIOSPHERE_SCALE_BASIS, false)):
		return ""
	match int(biosphere_desc.get(
		BiosphereScaleServiceScript.KEY_BIOSPHERE_STAGE,
		BiosphereScaleServiceScript.Stage.STERILE
	)):
		BiosphereScaleServiceScript.Stage.MICROBIAL:
			return "SPARSE"
		BiosphereScaleServiceScript.Stage.COMPLEX_MULTICELLULAR:
			return "THRIVING"
		BiosphereScaleServiceScript.Stage.COMPLEX_ECOSYSTEM:
			return "ABUNDANT"
	return ""
