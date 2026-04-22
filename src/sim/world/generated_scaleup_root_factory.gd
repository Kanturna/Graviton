class_name GeneratedScaleupRootFactory
extends RefCounted


const GeneratedRootManifestFactoryScript = preload("res://src/sim/world/generated_root_manifest_factory.gd")

const BASE_SEED: int = 180001
const SEED_STEP: int = 9973


static func build_extra_manifests(count: int, start_ordinal: int = 1) -> Array:
	var manifests: Array = []
	if count <= 0:
		return manifests
	for offset in range(count):
		manifests.append(build_manifest_for_ordinal(start_ordinal + offset))
	return manifests


static func build_manifest_for_ordinal(ordinal: int):
	var root_id: StringName = StringName("shade_%02d" % ordinal)
	var display_name: String = "Shade %02d" % ordinal
	var seed: int = BASE_SEED + ordinal * SEED_STEP
	return GeneratedRootManifestFactoryScript.build_manifest(
		root_id,
		display_name,
		seed,
		_galaxy_position_for_ordinal(ordinal)
	)


static func _galaxy_position_for_ordinal(ordinal: int) -> Vector3:
	var angle_rad: float = 1.15 + float(ordinal) * 0.71
	var radius_m: float = 9.5e13 + float(ordinal) * 3.4e12
	return Vector3(cos(angle_rad) * radius_m, sin(angle_rad) * radius_m, 0.0)
