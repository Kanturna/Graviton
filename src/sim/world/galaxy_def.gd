class_name GalaxyDef
extends RefCounted


var galaxy_id: StringName = &""
var display_name: String = ""
var focus_root_id: StringName = &""
var manifests: Array = []
var default_resident_root_ids: Array[StringName] = []


func get_manifest(root_id: StringName):
	for manifest in manifests:
		if manifest != null and manifest.root_id == root_id:
			return manifest
	return null


func root_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for manifest in manifests:
		if manifest != null:
			out.append(manifest.root_id)
	return out
