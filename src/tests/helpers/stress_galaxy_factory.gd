extends RefCounted


const GalaxyDefScript = preload("res://src/sim/world/galaxy_def.gd")
const PilotGalaxyWorldScript = preload("res://src/sim/world/pilot_galaxy_world.gd")
const RootSystemManifestScript = preload("res://src/sim/world/root_system_manifest.gd")
const RootStarManifestScript = preload("res://src/sim/world/root_star_manifest.gd")

const DEFAULT_ROOT_COUNT: int = 30


static func build(root_count: int = DEFAULT_ROOT_COUNT):
	var base_galaxy = PilotGalaxyWorldScript.build()
	var galaxy = GalaxyDefScript.new()
	galaxy.galaxy_id = &"stress_galaxy"
	galaxy.display_name = "Stress Galaxy"
	galaxy.focus_root_id = base_galaxy.focus_root_id
	galaxy.default_resident_root_ids = base_galaxy.default_resident_root_ids.duplicate()
	for manifest in base_galaxy.manifests:
		galaxy.manifests.append(manifest.duplicate_manifest())

	var desired_root_count: int = maxi(root_count, galaxy.manifests.size())
	var extra_root_count: int = desired_root_count - galaxy.manifests.size()
	for index in range(extra_root_count):
		var ordinal: int = index + 1
		var root_id: StringName = StringName("shade_%02d" % ordinal)
		var display_name: String = "Shade %02d" % ordinal
		var seed: int = 180001 + ordinal * 9973
		galaxy.manifests.append(_build_generated_manifest(root_id, display_name, seed, ordinal))
	return galaxy


static func _build_generated_manifest(root_id: StringName, display_name: String, seed: int, ordinal: int):
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var manifest = RootSystemManifestScript.new()
	manifest.root_id = root_id
	manifest.display_name = display_name
	manifest.galaxy_position_m = _galaxy_position_for_ordinal(ordinal)
	manifest.seed = seed
	manifest.root_mass_kg = rng.randf_range(0.95, 2.30) * 2.0e33
	manifest.root_radius_m = rng.randf_range(0.80, 1.35) * 3.0e9

	var star_count: int = rng.randi_range(4, 6)
	var current_radius_m: float = rng.randf_range(1.8e11, 2.4e11)
	var max_radius_m: float = 0.0
	for star_index in range(star_count):
		var suffix: String = _star_suffix(star_index)
		var star_mass_scale: float = rng.randf_range(0.22, 4.10)
		var luminosity_scale: float = pow(maxf(star_mass_scale, 0.22), 3.10)
		manifest.star_manifests.append(_make_star_manifest(
			StringName("%s_%s" % [String(root_id), suffix]),
			"%s %s" % [display_name, suffix.to_upper()],
			star_mass_scale,
			1.9e8 * lerpf(0.78, 4.20, clampf(star_mass_scale / 4.10, 0.0, 1.0)),
			rng.randf_range(13.0, 35.0) * UnitSystem.DAY_S,
			luminosity_scale,
			current_radius_m,
			rng.randf_range(4.8e4, 1.7e5),
			rng.randf_range(0.0, TAU),
			rng.randi_range(2, 5)
		))
		max_radius_m = maxf(max_radius_m, current_radius_m)
		current_radius_m *= rng.randf_range(1.30, 1.55)
	manifest.system_extent_m = max_radius_m * 1.18
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


static func _galaxy_position_for_ordinal(ordinal: int) -> Vector3:
	var angle_rad: float = 1.15 + float(ordinal) * 0.71
	var radius_m: float = 9.5e13 + float(ordinal) * 3.4e12
	return Vector3(cos(angle_rad) * radius_m, sin(angle_rad) * radius_m, 0.0)


static func _star_suffix(index: int) -> String:
	var suffixes: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h"]
	if index < 0 or index >= suffixes.size():
		return "x%d" % index
	return suffixes[index]
