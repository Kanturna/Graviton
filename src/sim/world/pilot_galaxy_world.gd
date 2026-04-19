class_name PilotGalaxyWorld
extends RefCounted


const GalaxyDefScript := preload("res://src/sim/world/galaxy_def.gd")
const RootSystemManifestScript := preload("res://src/sim/world/root_system_manifest.gd")
const RootStarManifestScript := preload("res://src/sim/world/root_star_manifest.gd")

const GALAXY_ID: StringName = &"pilot_galaxy"


static func build():
	var galaxy = GalaxyDefScript.new()
	var resident_root_ids: Array[StringName] = [&"obsidian"]
	galaxy.galaxy_id = GALAXY_ID
	galaxy.display_name = "Pilot Galaxy"
	galaxy.focus_root_id = &"obsidian"
	galaxy.manifests = [
		_build_hero_manifest(),
		_build_generated_manifest(&"onyx", "Onyx", 81173, Vector3(6.4e13, 1.9e13, 0.0)),
		_build_generated_manifest(&"umbra", "Umbra", 99107, Vector3(-5.8e13, -2.8e13, 0.0)),
	]
	galaxy.default_resident_root_ids = resident_root_ids
	return galaxy


static func _build_hero_manifest():
	var manifest = RootSystemManifestScript.new()
	manifest.root_id = &"obsidian"
	manifest.display_name = "Obsidian"
	manifest.galaxy_position_m = Vector3.ZERO
	manifest.system_extent_m = 5.6e11
	manifest.seed = 424242
	manifest.hero_world_id = &"starter_world"
	manifest.root_mass_kg = 2.0e33
	manifest.root_radius_m = 3.0e9
	manifest.star_manifests = [
		_make_star_manifest(&"alpha", "Alpha", 3.0, 6.957e8, 25.0 * UnitSystem.DAY_S, 3.0, 1.5e11, 4.0e4, 0.0, 3),
		_make_star_manifest(&"beta", "Beta", 3.0, 6.957e8, 25.0 * UnitSystem.DAY_S, 3.0, 2.5e11, 7.0e4, PI, 2),
		_make_star_manifest(&"gamma", "Gamma", 0.20, 1.95e8, 18.0 * UnitSystem.DAY_S, 0.0036, 3.45e11, 9.5e4, 4.25, 4),
		_make_star_manifest(&"delta", "Delta", 4.2, 8.1e8, 31.0 * UnitSystem.DAY_S, 5.0, 4.8e11, 1.3e5, 0.95, 1),
	]
	return manifest


static func _build_generated_manifest(
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
	manifest.root_mass_kg = rng.randf_range(0.9, 2.1) * 2.0e33
	manifest.root_radius_m = rng.randf_range(0.85, 1.25) * 3.0e9

	var star_count: int = rng.randi_range(4, 6)
	var current_radius_m: float = rng.randf_range(1.7e11, 2.2e11)
	var max_radius_m: float = 0.0
	for star_index in range(star_count):
		var star_id: StringName = StringName("%s_%s" % [String(root_id), _star_suffix(star_index)])
		var star_display_name: String = "%s %s" % [display_name, _star_suffix(star_index).to_upper()]
		var star_mass_scale: float = rng.randf_range(0.18, 3.9)
		var star_radius_m: float = 1.9e8 * lerpf(0.75, 4.0, clampf(star_mass_scale / 4.0, 0.0, 1.0))
		var rotation_period_s: float = rng.randf_range(14.0, 34.0) * UnitSystem.DAY_S
		var luminosity_scale: float = pow(maxf(star_mass_scale, 0.18), 3.15)
		var orbit_period_s: float = rng.randf_range(4.5e4, 1.55e5)
		var orbit_phase_rad: float = rng.randf_range(0.0, TAU)
		var planet_count: int = rng.randi_range(2, 5)
		manifest.star_manifests.append(_make_star_manifest(
			star_id,
			star_display_name,
			star_mass_scale,
			star_radius_m,
			rotation_period_s,
			luminosity_scale,
			current_radius_m,
			orbit_period_s,
			orbit_phase_rad,
			planet_count
		))
		max_radius_m = maxf(max_radius_m, current_radius_m)
		current_radius_m *= rng.randf_range(1.28, 1.52)
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


static func _star_suffix(index: int) -> String:
	var suffixes: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h"]
	if index < 0 or index >= suffixes.size():
		return "x%d" % index
	return suffixes[index]
