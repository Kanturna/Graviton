extends RefCounted


const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const ThermalServiceScript = preload("res://src/sim/thermal/thermal_service.gd")
const PlanetaryStateServiceScript = preload("res://src/sim/planetary/planetary_state_service.gd")
const LifePotentialServiceScript = preload("res://src/sim/life/life_potential_service.gd")
const ProtoBiosphereSimulationServiceScript = preload("res://src/sim/life/proto_biosphere_simulation_service.gd")


static func format_focus(focus_name: String) -> String:
	return "Focus: %s" % focus_name


static func format_environment(environment_desc: Dictionary) -> String:
	if not bool(environment_desc.get(EnvironmentServiceScript.KEY_IS_SUPPORTED_BODY_KIND, false)):
		return "Environment: n/a"
	return "Environment: %s   Climate: %s" % [
		_environment_class_text(environment_desc),
		_ecosystem_text(environment_desc),
	]


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
	if not bool(biosphere_desc.get(ProtoBiosphereSimulationServiceScript.KEY_HAS_BIOSPHERE_BASIS, false)):
		return "Life: n/a"
	if _life_has_no_track(biosphere_desc):
		return "Life: %s" % _biosphere_stage_text(biosphere_desc)
	return "Life: %s / %s" % [
		_biosphere_stage_text(biosphere_desc),
		_biosphere_track_text(biosphere_desc),
	]


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
	if not bool(biosphere_desc.get(ProtoBiosphereSimulationServiceScript.KEY_HAS_BIOSPHERE_BASIS, false)):
		return "Life: n/a"
	if _life_has_no_track(biosphere_desc):
		return "Life: %s" % _biosphere_stage_text(biosphere_desc)
	return "Life: %s / %s / %s" % [
		_biosphere_stage_text(biosphere_desc),
		_biosphere_track_text(biosphere_desc),
		_biosphere_potential_class_text(biosphere_desc),
	]


static func format_time(sim_time_s: float, tick_count: int, fps: int) -> String:
	return "T+ %.2f d   steps %d   FPS %d" % [sim_time_s / UnitSystem.DAY_S, tick_count, fps]


static func format_scale(time_scale: float, preset_label: String, zoom_factor: float, zoom_mode: String, frame_label: String = "") -> String:
	var mode_segment: String = zoom_mode
	if frame_label != "":
		mode_segment = "%s (%s)" % [zoom_mode, frame_label]
	return "Speed x%s   Preset %s   Zoom %s %s" % [
		_stripped_float(time_scale),
		preset_label,
		_zoom_percent_text(zoom_factor),
		mode_segment,
	]


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
	return ProtoBiosphereSimulationServiceScript.to_string_stage(
		int(biosphere_desc.get(
			ProtoBiosphereSimulationServiceScript.KEY_BIOSPHERE_STAGE,
			ProtoBiosphereSimulationServiceScript.Stage.STERILE
		))
	)


static func _biosphere_track_text(biosphere_desc: Dictionary) -> String:
	return LifePotentialServiceScript.to_string_track(
		int(biosphere_desc.get(
			ProtoBiosphereSimulationServiceScript.KEY_DOMINANT_TRACK_ID,
			LifePotentialServiceScript.Track.WATER_CARBON
		))
	)


static func _biosphere_potential_class_text(biosphere_desc: Dictionary) -> String:
	return LifePotentialServiceScript.to_string_potential_class(
		int(biosphere_desc.get(
			ProtoBiosphereSimulationServiceScript.KEY_DOMINANT_POTENTIAL_CLASS,
			LifePotentialServiceScript.PotentialClass.NONE
		))
	)


static func _life_has_no_track(biosphere_desc: Dictionary) -> bool:
	return int(biosphere_desc.get(
		ProtoBiosphereSimulationServiceScript.KEY_DOMINANT_POTENTIAL_CLASS,
		LifePotentialServiceScript.PotentialClass.NONE
	)) == LifePotentialServiceScript.PotentialClass.NONE
