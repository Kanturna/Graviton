class_name ScaleupGalaxy100World
extends RefCounted


const ScaleupGalaxyCatalogFactoryScript := preload("res://src/sim/world/scaleup_galaxy_catalog_factory.gd")

const GALAXY_ID: StringName = &"scaleup_galaxy_100"
const TOTAL_ROOT_COUNT: int = 100


static func build():
	return ScaleupGalaxyCatalogFactoryScript.build(GALAXY_ID, "Scale-Up Galaxy 100", TOTAL_ROOT_COUNT)
