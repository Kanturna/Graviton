class_name ScaleupGalaxyWorld
extends RefCounted


const GalaxyDefScript := preload("res://src/sim/world/galaxy_def.gd")
const PilotGalaxyWorldScript := preload("res://src/sim/world/pilot_galaxy_world.gd")
const GeneratedScaleupRootFactoryScript := preload("res://src/sim/world/generated_scaleup_root_factory.gd")

const GALAXY_ID: StringName = &"scaleup_galaxy_10"
const TOTAL_ROOT_COUNT: int = 10


static func build():
	var pilot_galaxy = PilotGalaxyWorldScript.build()
	var galaxy = GalaxyDefScript.new()
	var default_resident_root_ids: Array[StringName] = [&"obsidian"]
	galaxy.galaxy_id = GALAXY_ID
	galaxy.display_name = "Scale-Up Galaxy 10"
	galaxy.focus_root_id = &"obsidian"
	galaxy.default_resident_root_ids = default_resident_root_ids
	for manifest in pilot_galaxy.manifests:
		galaxy.manifests.append(manifest.duplicate_manifest())
	for manifest in GeneratedScaleupRootFactoryScript.build_extra_manifests(
		TOTAL_ROOT_COUNT - pilot_galaxy.manifests.size()
	):
		galaxy.manifests.append(manifest)
	return galaxy
