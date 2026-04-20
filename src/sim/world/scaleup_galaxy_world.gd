class_name ScaleupGalaxyWorld
extends RefCounted


const ScaleupGalaxyCatalogFactoryScript := preload("res://src/sim/world/scaleup_galaxy_catalog_factory.gd")

const GALAXY_ID: StringName = &"scaleup_galaxy_10"
const TOTAL_ROOT_COUNT: int = 10


static func build():
	return ScaleupGalaxyCatalogFactoryScript.build(GALAXY_ID, "Scale-Up Galaxy 10", TOTAL_ROOT_COUNT)
