extends RefCounted


const ScaleupGalaxyCatalogFactoryScript = preload("res://src/sim/world/scaleup_galaxy_catalog_factory.gd")

const DEFAULT_ROOT_COUNT: int = 30


static func build(root_count: int = DEFAULT_ROOT_COUNT):
	return ScaleupGalaxyCatalogFactoryScript.build(&"stress_galaxy", "Stress Galaxy", root_count)
