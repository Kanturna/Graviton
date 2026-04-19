extends RefCounted


const EnvironmentServiceScript = preload("res://src/sim/environment/environment_service.gd")
const ThermalServiceScript = preload("res://src/sim/thermal/thermal_service.gd")


static func format_focus(focus_name: String) -> String:
	return "Focus: %s" % focus_name


static func format_environment(environment_desc: Dictionary) -> String:
	if not bool(environment_desc.get(EnvironmentServiceScript.KEY_IS_SUPPORTED_BODY_KIND, false)):
		return "Environment: n/a"
	return "Environment: %s   Climate: %s" % [
		EnvironmentServiceScript.to_string_class(
			int(environment_desc.get(EnvironmentServiceScript.KEY_ENVIRONMENT_CLASS, EnvironmentServiceScript.Class.HOSTILE))
		),
		EnvironmentServiceScript.to_string_ecosystem(
			int(environment_desc.get(EnvironmentServiceScript.KEY_ECOSYSTEM_TYPE, EnvironmentServiceScript.EcosystemType.FROZEN_WORLD))
		),
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
