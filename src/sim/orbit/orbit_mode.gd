class_name OrbitMode
extends RefCounted

# Enum-Namespace fuer Orbit-Regime. Nicht instanziieren.
# AUTHORED_ORBIT  — fest vorgegebene Kreisbahn, deterministisch.
# KEPLER_APPROX   — analytische Kepler-Loesung ums Parent.
# NUMERIC_LOCAL   — reserviert, nicht in diesem Foundation-Slice implementiert.

enum Kind {
	AUTHORED_ORBIT,
	KEPLER_APPROX,
	NUMERIC_LOCAL,
}


static func to_string_kind(k: Kind) -> String:
	match k:
		Kind.AUTHORED_ORBIT: return "AUTHORED_ORBIT"
		Kind.KEPLER_APPROX: return "KEPLER_APPROX"
		Kind.NUMERIC_LOCAL: return "NUMERIC_LOCAL"
	return "UNKNOWN"
