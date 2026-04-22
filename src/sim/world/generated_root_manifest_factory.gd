class_name GeneratedRootManifestFactory
extends RefCounted


const RootSystemManifestScript = preload("res://src/sim/world/root_system_manifest.gd")
const RootStarManifestScript = preload("res://src/sim/world/root_star_manifest.gd")

const STANDARD_ROOT_MASS_KG: float = 2.0e33
const STANDARD_ROOT_RADIUS_M: float = 3.0e9
const STANDARD_SYSTEM_EXTENT_M: float = 5.6e11
const STANDARD_STAR_ORBIT_RADII_M: Array[float] = [1.5e11, 2.5e11, 3.45e11, 4.8e11]
const STANDARD_STAR_ORBIT_PERIODS_S: Array[float] = [4.0e4, 7.0e4, 9.5e4, 1.3e5]


static func build_manifest(
		root_id: StringName,
		display_name: String,
		seed: int,
		galaxy_position_m: Vector3
	):
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var manifest = RootSystemManifestScript.new()
	manifest.root_id = root_id
	manifest.display_name = display_name
	manifest.galaxy_position_m = galaxy_position_m
	manifest.seed = seed
	manifest.root_mass_kg = STANDARD_ROOT_MASS_KG * rng.randf_range(0.92, 1.10)
	manifest.root_radius_m = STANDARD_ROOT_RADIUS_M * rng.randf_range(0.90, 1.12)

	for star_index in range(STANDARD_STAR_ORBIT_RADII_M.size()):
		var suffix: String = _star_suffix(star_index)
		var star_mass_scale: float = rng.randf_range(0.20, 4.10)
		var luminosity_scale: float = pow(maxf(star_mass_scale, 0.20), 3.10)
		manifest.star_manifests.append(_make_star_manifest(
			StringName("%s_%s" % [String(root_id), suffix]),
			"%s %s" % [display_name, suffix.to_upper()],
			star_mass_scale,
			1.9e8 * lerpf(0.76, 4.20, clampf(star_mass_scale / 4.10, 0.0, 1.0)),
			rng.randf_range(13.0, 35.0) * UnitSystem.DAY_S,
			luminosity_scale,
			STANDARD_STAR_ORBIT_RADII_M[star_index],
			STANDARD_STAR_ORBIT_PERIODS_S[star_index],
			rng.randf_range(0.0, TAU),
			rng.randi_range(1, 4)
		))

	manifest.system_extent_m = STANDARD_SYSTEM_EXTENT_M
	return manifest


static func _make_star_manifest(
		id: StringName,
		display_name: String,
		mass_scale_solar: float,
		radius_m: float,
		rotation_period_s: float,
		luminosity_scale_solar: float,
		orbit_radius_m: float,
		orbit_period_s: float,
		orbit_phase_rad: float,
		planet_count: int
	):
	var manifest = RootStarManifestScript.new()
	manifest.id = id
	manifest.display_name = display_name
	manifest.mass_kg = UnitSystem.SOLAR_MASS_KG * mass_scale_solar
	manifest.radius_m = radius_m
	manifest.rotation_period_s = rotation_period_s
	manifest.luminosity_w = UnitSystem.SOLAR_LUMINOSITY_W * luminosity_scale_solar
	manifest.orbit_radius_m = orbit_radius_m
	manifest.orbit_period_s = orbit_period_s
	manifest.orbit_phase_rad = orbit_phase_rad
	manifest.planet_count = planet_count
	return manifest


static func _star_suffix(index: int) -> String:
	var suffixes: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h"]
	if index < 0 or index >= suffixes.size():
		return "x%d" % index
	return suffixes[index]
