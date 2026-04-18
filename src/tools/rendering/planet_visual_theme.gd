class_name PlanetVisualTheme
extends RefCounted


enum Archetype {
	TEMPERATE_OCEAN,
	FROZEN,
	HOT_SCORCHED,
	BARREN,
}


var archetype: int = Archetype.BARREN
var is_stylized_interpretation: bool = false

var base_color: Color = Color(0.50, 0.62, 0.72)
var secondary_color: Color = Color(0.74, 0.78, 0.82)
var accent_color: Color = Color(0.94, 0.95, 0.98)
var atmo_color: Color = Color(0.70, 0.78, 0.90)

var land_ocean_strength: float = 0.0
var cloud_strength: float = 0.0
var ice_strength: float = 0.0
var lava_strength: float = 0.0
var dryness_strength: float = 0.0
var crater_strength: float = 0.0


static func archetype_to_string(value: int) -> String:
	match value:
		Archetype.TEMPERATE_OCEAN:
			return "TEMPERATE_OCEAN"
		Archetype.FROZEN:
			return "FROZEN"
		Archetype.HOT_SCORCHED:
			return "HOT_SCORCHED"
		Archetype.BARREN:
			return "BARREN"
	return "UNKNOWN"
