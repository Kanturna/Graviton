extends RefCounted


const GalaxyDefScript = preload("res://src/sim/world/galaxy_def.gd")
const GeneratedScaleupRootFactoryScript = preload("res://src/sim/world/generated_scaleup_root_factory.gd")
const PilotGalaxyWorldScript = preload("res://src/sim/world/pilot_galaxy_world.gd")

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
	galaxy.manifests.append_array(
		GeneratedScaleupRootFactoryScript.build_extra_manifests(extra_root_count)
	)
	return galaxy
