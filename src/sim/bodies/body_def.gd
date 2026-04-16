class_name BodyDef
extends Resource

# Statische Definition eines Koerpers. Zur Laufzeit unveraenderlich.
# Wurzelkoerper: `parent_id == &""` UND `orbit_profile == null`.
# Alle anderen Koerper muessen sowohl parent_id als auch orbit_profile haben.

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: int = BodyType.Kind.PLANET
@export var mass_kg: float = 0.0
@export var radius_m: float = 0.0
@export var parent_id: StringName = &""
@export var orbit_profile: OrbitProfile = null


func is_root() -> bool:
	return parent_id == StringName("")


func is_valid() -> bool:
	if id == StringName(""):
		return false
	if mass_kg <= 0.0:
		return false
	if is_root():
		return orbit_profile == null
	return orbit_profile != null
