class_name RootStarManifest
extends RefCounted


var id: StringName = &""
var display_name: String = ""
var mass_kg: float = 0.0
var radius_m: float = 0.0
var rotation_period_s: float = 0.0
var luminosity_w: float = 0.0
var orbit_radius_m: float = 0.0
var orbit_period_s: float = 0.0
var orbit_phase_rad: float = 0.0
var planet_count: int = 0


func is_valid() -> bool:
	return (
		id != StringName("")
		and mass_kg > 0.0
		and radius_m > 0.0
		and orbit_radius_m > 0.0
		and orbit_period_s > 0.0
		and luminosity_w >= 0.0
		and planet_count >= 0
	)


func duplicate_manifest():
	var out = get_script().new()
	out.id = id
	out.display_name = display_name
	out.mass_kg = mass_kg
	out.radius_m = radius_m
	out.rotation_period_s = rotation_period_s
	out.luminosity_w = luminosity_w
	out.orbit_radius_m = orbit_radius_m
	out.orbit_period_s = orbit_period_s
	out.orbit_phase_rad = orbit_phase_rad
	out.planet_count = planet_count
	return out
