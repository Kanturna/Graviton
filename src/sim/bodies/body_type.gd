class_name BodyType
extends RefCounted

# Enum-Namespace fuer Koerperkategorien. Nicht instanziieren.

enum Kind {
	STAR,
	PLANET,
	MOON,
	STATION,
	ASTEROID,
	# Schwarzes Loch. Wahrheit: mass_kg; als Simulationswurzel liegt Position bei ZERO.
	BLACK_HOLE,
	# Steuerbarer Koerper (z. B. Schiff). Bewegungssemantik noch undefiniert — Design-Gate vor Schritt 5.
	CONTROLLED,
}


static func to_string_kind(k: Kind) -> String:
	match k:
		Kind.STAR: return "STAR"
		Kind.PLANET: return "PLANET"
		Kind.MOON: return "MOON"
		Kind.STATION: return "STATION"
		Kind.ASTEROID: return "ASTEROID"
		Kind.BLACK_HOLE: return "BLACK_HOLE"
		Kind.CONTROLLED: return "CONTROLLED"
	return "UNKNOWN"
