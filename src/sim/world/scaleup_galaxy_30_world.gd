class_name ScaleupGalaxy30World
extends RefCounted


const ScaleupGalaxyCatalogFactoryScript := preload("res://src/sim/world/scaleup_galaxy_catalog_factory.gd")

const GALAXY_ID: StringName = &"scaleup_galaxy_30"
const TOTAL_ROOT_COUNT: int = 30


static func build():
	return ScaleupGalaxyCatalogFactoryScript.build(GALAXY_ID, "Scale-Up Galaxy 30", TOTAL_ROOT_COUNT)
