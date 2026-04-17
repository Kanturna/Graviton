class_name SampleSystem
extends RefCounted

# Factory fuer das Foundation-Testsystem.
# Diff-freundlich, reviewbar: das gesamte System ist in dieser Datei lesbar.
# Keine .tres-Binary, keine Inspector-gepflegte Resource.
#
# Inhalt:
#   sol      — Stern, Wurzel
#   planet_a — Planet, KEPLER_APPROX um sol (~1 AU)
#   moon_a   — Mond,   AUTHORED_ORBIT um planet_a (~Mondbahn)


static func build() -> Array[BodyDef]:
	var out: Array[BodyDef] = []
	out.append(_build_sol())
	out.append(_build_planet_a())
	out.append(_build_moon_a())
	return out


static func _build_sol() -> BodyDef:
	var d := BodyDef.new()
	d.id = &"sol"
	d.display_name = "Sol"
	d.kind = BodyType.Kind.STAR
	d.mass_kg = UnitSystem.SOLAR_MASS_KG
	d.radius_m = 6.957e8
	d.rotation_period_s = 25.0 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.0
	d.luminosity_w = 1.0 * UnitSystem.SOLAR_LUMINOSITY_W
	d.albedo = 0.0
	d.parent_id = &""
	d.orbit_profile = null
	return d


static func _build_planet_a() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.KEPLER_APPROX
	prof.semi_major_axis_m = UnitSystem.AU_M
	prof.eccentricity = 0.0167
	prof.inclination_rad = 0.0
	prof.longitude_ascending_node_rad = 0.0
	prof.argument_periapsis_rad = 0.0
	prof.mean_anomaly_epoch_rad = 0.0
	prof.epoch_s = 0.0

	var d := BodyDef.new()
	d.id = &"planet_a"
	d.display_name = "Planet A"
	d.kind = BodyType.Kind.PLANET
	d.mass_kg = UnitSystem.EARTH_MASS_KG
	d.radius_m = 6.371e6
	d.rotation_period_s = 1.0 * UnitSystem.DAY_S
	d.axial_tilt_rad = 0.4091
	d.luminosity_w = 0.0
	d.albedo = 0.30
	d.parent_id = &"sol"
	d.orbit_profile = prof
	return d


static func _build_moon_a() -> BodyDef:
	var prof := OrbitProfile.new()
	prof.mode = OrbitMode.Kind.AUTHORED_ORBIT
	prof.authored_radius_m = 3.844e8
	prof.authored_period_s = 2.360592e6
	prof.authored_phase_rad = 0.0

	var d := BodyDef.new()
	d.id = &"moon_a"
	d.display_name = "Moon A"
	d.kind = BodyType.Kind.MOON
	d.mass_kg = UnitSystem.LUNAR_MASS_KG
	d.radius_m = 1.7374e6
	d.parent_id = &"planet_a"
	d.orbit_profile = prof
	return d
