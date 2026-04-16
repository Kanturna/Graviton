class_name BodyType
extends RefCounted

# Enum-Namespace fuer Koerperkategorien. Nicht instanziieren.

enum Kind {
	STAR,
	PLANET,
	MOON,
	STATION,
	ASTEROID,
}


static func to_string_kind(k: Kind) -> String:
	match k:
		Kind.STAR: return "STAR"
		Kind.PLANET: return "PLANET"
		Kind.MOON: return "MOON"
		Kind.STATION: return "STATION"
		Kind.ASTEROID: return "ASTEROID"
	return "UNKNOWN"
