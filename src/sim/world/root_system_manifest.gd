class_name RootSystemManifest
extends RefCounted


var root_id: StringName = &""
var display_name: String = ""
var galaxy_position_m: Vector3 = Vector3.ZERO
var system_extent_m: float = 0.0
var seed: int = 0
var hero_world_id: StringName = &""
var root_kind: int = BodyType.Kind.BLACK_HOLE
var root_mass_kg: float = 0.0
var root_radius_m: float = 0.0
var star_manifests: Array = []


func is_hero() -> bool:
	return hero_world_id != StringName("")


func is_valid() -> bool:
	if root_id == StringName("") or root_mass_kg <= 0.0 or root_radius_m <= 0.0 or system_extent_m <= 0.0:
		return false
	if star_manifests.is_empty():
		return false
	for star_manifest in star_manifests:
		if star_manifest == null or not star_manifest.is_valid():
			return false
	return true


func duplicate_manifest():
	var out = get_script().new()
	out.root_id = root_id
	out.display_name = display_name
	out.galaxy_position_m = galaxy_position_m
	out.system_extent_m = system_extent_m
	out.seed = seed
	out.hero_world_id = hero_world_id
	out.root_kind = root_kind
	out.root_mass_kg = root_mass_kg
	out.root_radius_m = root_radius_m
	for star_manifest in star_manifests:
		out.star_manifests.append(star_manifest.duplicate_manifest())
	return out
